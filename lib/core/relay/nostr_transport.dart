import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bip340/bip340.dart' as bip340;
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../crypto/crypto_utils.dart';
import '../network/tor_manager.dart';

/// A sealed envelope received from a Nostr relay for one of our tokens.
///
/// [payload] is the opaque, already-encrypted blob the sender published; this
/// module never inspects it. [token] is the 64-hex recipient token it was
/// addressed to and [relay] the URL of the relay that delivered it first.
@immutable
class NostrInbound {
  const NostrInbound({
    required this.token,
    required this.payload,
    required this.createdAt,
    required this.eventId,
    required this.relay,
  });

  final String token;
  final Uint8List payload;
  final DateTime createdAt;
  final String eventId;
  final String relay;

  @override
  String toString() =>
      'NostrInbound(event: $eventId, relay: $relay, ${payload.length} bytes)';
}

/// Zero-infrastructure internet delivery over public Nostr relays (NIP-01).
///
/// Sealed envelopes are posted as kind 1059 ("gift wrap") events addressed to
/// a recipient token through the `p` tag. Every event is signed with a fresh
/// random secp256k1 key so relays cannot link publications to each other or
/// to any long-term identity, and `created_at` is randomised into the past
/// two days (as NIP-59 does) to blur timing. Relays only ever see ciphertext.
///
/// The transport keeps one WebSocket per relay, reconnects with exponential
/// backoff while enabled, and maintains a single subscription (one id per
/// instance) for the tokens given to [setTokens]. Inbound events are verified
/// (id recomputation + BIP-340 signature), filtered to our tokens, decoded and
/// deduplicated by event id across relays before being emitted on [onInbound].
class NostrTransport extends ChangeNotifier {
  NostrTransport({
    List<String>? relays,
    bool useTor = false,
    Duration reconnectDelay = const Duration(seconds: 10),
  }) : _relays = List<String>.unmodifiable(
         (relays == null || relays.isEmpty ? defaultRelays : relays).toSet(),
       ),
       _useTor = useTor,
       _reconnectDelay = reconnectDelay,
       _subscriptionId =
           'nyx-${CryptoUtils.toHex(CryptoUtils.randomBytes(8))}' {
    for (final url in _relays) {
      _connections[url] = _RelayConnection(url);
    }
  }

  static const List<String> defaultRelays = [
    'wss://relay.damus.io',
    'wss://nos.lol',
    'wss://relay.primal.net',
  ];

  /// NIP-59 gift wrap kind: stored by most public relays, indexed by `p`.
  static const int giftWrapKind = 1059;

  /// Largest payload accepted by [publish]. Base64 grows it to exactly
  /// 64 KiB of `content`, the most common relay message limit.
  static const int maxPayloadBytes = 48 * 1024;

  /// Inbound events with longer `content` are dropped before any decoding.
  static const int maxInboundContentChars = 64 * 1024;

  /// How long [publish] waits for a relay to acknowledge an event.
  static const Duration publishTimeout = Duration(seconds: 10);

  static const Duration _connectTimeout = Duration(seconds: 20);
  static const Duration _subscriptionWindow = Duration(days: 7);
  static const int _createdAtJitterSeconds = 2 * 24 * 3600;
  static const int _dedupeCapacity = 5000;
  static const int _maxFrameChars = 256 * 1024;
  static const int _maxBackoffExponent = 5;

  static final Random _rng = Random.secure();

  /// Order of the secp256k1 group; private scalars must lie in [1, n - 1].
  static final BigInt _curveOrder = BigInt.parse(
    'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
    radix: 16,
  );

  final List<String> _relays;
  final bool _useTor;
  final Duration _reconnectDelay;
  final String _subscriptionId;
  final Map<String, _RelayConnection> _connections = {};
  final Map<String, _PendingPublish> _pending = {};
  final _LruSet _seen = _LruSet(_dedupeCapacity);
  final StreamController<NostrInbound> _inbound =
      StreamController<NostrInbound>.broadcast();

  List<String> _tokens = const [];
  Set<String> _tokenSet = const {};
  bool _enabled = false;
  bool _disposed = false;
  int _published = 0;
  int _received = 0;

  List<String> get relays => _relays;
  bool get isEnabled => _enabled;
  bool get isConnected => _connections.values.any((c) => c.isOpen);
  int get connectedRelayCount =>
      _connections.values.where((c) => c.isOpen).length;
  int get published => _published;
  int get received => _received;

  /// Tokens currently subscribed to (normalised to lowercase hex).
  List<String> get tokens => _tokens;

  /// Verified, deduplicated envelopes addressed to one of our tokens. This is
  /// a broadcast stream: listen before [start] so nothing is missed.
  Stream<NostrInbound> get onInbound => _inbound.stream;

  @visibleForTesting
  String get subscriptionId => _subscriptionId;

  /// Connects to every relay and (re)issues the subscription for the current
  /// tokens. Completes as soon as one relay is open, or once every initial
  /// attempt has failed; reconnects keep running in the background either way.
  Future<void> start() async {
    if (_disposed) throw StateError('NostrTransport has been disposed');
    if (_enabled) {
      for (final conn in _connections.values) {
        if (conn.isOpen) {
          _sendSubscription(conn);
        } else {
          unawaited(_connect(conn));
        }
      }
      return;
    }
    _enabled = true;
    _notify();
    debugPrint(
      '[Nostr] Starting with ${_relays.length} relay(s)'
      '${_useTor ? ' via Tor' : ''}',
    );
    final firstOpen = Completer<void>();
    var outstanding = _connections.length;
    for (final conn in _connections.values) {
      unawaited(
        _connect(conn).then((ok) {
          outstanding--;
          if ((ok || outstanding == 0) && !firstOpen.isCompleted) {
            firstOpen.complete();
          }
        }),
      );
    }
    if (outstanding == 0) return;
    await firstOpen.future;
  }

  /// Closes every relay connection and stops reconnecting. Pending
  /// [publish] calls resolve to `false`.
  Future<void> stop() async {
    _enabled = false;
    for (final conn in _connections.values) {
      conn.reconnectTimer?.cancel();
      conn.reconnectTimer = null;
      conn.failures = 0;
      conn.subscribed = false;
      final channel = conn.channel;
      conn.channel = null;
      if (channel != null) {
        try {
          await channel.sink
              .close(WebSocketStatus.normalClosure, 'bye')
              .timeout(const Duration(seconds: 3));
        } catch (e) {
          debugPrint('[Nostr] Close ${conn.url}: $e');
        }
      }
      await conn.subscription?.cancel();
      conn.subscription = null;
    }
    for (final pending in _pending.values.toList()) {
      pending.resolve(false);
    }
    _pending.clear();
    _notify();
    debugPrint('[Nostr] Stopped');
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    unawaited(_inbound.close());
    super.dispose();
  }

  /// Sets the 64-hex recipient tokens to subscribe to; malformed entries are
  /// dropped. Re-issues the REQ on every open relay. No-op if unchanged.
  void setTokens(List<String> tokensHex) {
    final cleaned = <String>{};
    for (final raw in tokensHex) {
      final token = raw.trim().toLowerCase();
      if (_isHex(token, 64)) {
        cleaned.add(token);
      } else {
        debugPrint('[Nostr] Ignoring malformed token (${raw.length} chars)');
      }
    }
    if (setEquals(cleaned, _tokenSet)) return;
    _tokenSet = Set<String>.unmodifiable(cleaned);
    _tokens = List<String>.unmodifiable(cleaned);
    debugPrint('[Nostr] Subscribing to ${_tokens.length} token(s)');
    for (final conn in _connections.values) {
      if (conn.isOpen) _sendSubscription(conn);
    }
  }

  /// Publishes [payload] (an already-sealed envelope of at most
  /// [maxPayloadBytes]) to [recipientTokenHex] on every open relay.
  ///
  /// Returns `true` once at least one relay acknowledges the event with
  /// `["OK", id, true]`; `false` if every relay rejects it, no relay is
  /// reachable, or nothing is acknowledged within [publishTimeout].
  Future<bool> publish({
    required String recipientTokenHex,
    required Uint8List payload,
  }) async {
    final token = recipientTokenHex.trim().toLowerCase();
    if (!_isHex(token, 64)) {
      debugPrint('[Nostr] publish: malformed recipient token');
      return false;
    }
    if (payload.length > maxPayloadBytes) {
      debugPrint(
        '[Nostr] publish: payload of ${payload.length} bytes exceeds '
        '$maxPayloadBytes',
      );
      return false;
    }
    // Give a (re)connecting transport a moment to come up before giving up.
    final deadline = DateTime.now().add(publishTimeout);
    while (_enabled && !isConnected && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    final open = _connections.values.where((c) => c.isOpen).toList();
    if (open.isEmpty) {
      debugPrint('[Nostr] publish: no relay connected');
      return false;
    }

    final event = await buildEvent(recipientTokenHex: token, payload: payload);
    final id = event['id'] as String;
    final frame = jsonEncode(<Object>['EVENT', event]);
    final pending = _PendingPublish();
    _pending[id] = pending;
    var sent = 0;
    for (final conn in open) {
      if (_sendFrame(conn, frame)) sent++;
    }
    if (sent == 0) {
      _pending.remove(id);
      debugPrint('[Nostr] publish: could not send to any relay');
      return false;
    }
    pending.expected = sent;
    final timer = Timer(publishTimeout, () => pending.resolve(false));
    final ok = await pending.future;
    timer.cancel();
    _pending.remove(id);
    final shortId = id.substring(0, 12);
    if (ok) {
      _published++;
      _notify();
      debugPrint('[Nostr] Published $shortId to $sent relay(s)');
    } else {
      debugPrint('[Nostr] Publish $shortId was not acknowledged');
    }
    return ok;
  }

  /// Builds and signs a kind 1059 event carrying [payload] for
  /// [recipientTokenHex] under a fresh random key. [createdAt] defaults to
  /// now minus a random 0..2 days. Exposed for tests and tooling.
  static Future<Map<String, dynamic>> buildEvent({
    required String recipientTokenHex,
    required Uint8List payload,
    DateTime? createdAt,
  }) async {
    final token = recipientTokenHex.trim().toLowerCase();
    if (!_isHex(token, 64)) {
      throw ArgumentError.value(
        recipientTokenHex,
        'recipientTokenHex',
        'must be 64 hex characters',
      );
    }
    if (payload.length > maxPayloadBytes) {
      throw ArgumentError.value(
        payload.length,
        'payload',
        'exceeds $maxPayloadBytes bytes',
      );
    }
    final privateKey = _randomPrivateKeyHex();
    final pubkey = bip340.getPublicKey(privateKey);
    final timestamp = createdAt != null
        ? createdAt.millisecondsSinceEpoch ~/ 1000
        : _nowSeconds() - _rng.nextInt(_createdAtJitterSeconds + 1);
    final tags = <List<String>>[
      <String>['p', token],
    ];
    final content = base64.encode(payload);
    final id = await _computeId(
      pubkey: pubkey,
      createdAt: timestamp,
      kind: giftWrapKind,
      tags: tags,
      content: content,
    );
    final aux = CryptoUtils.toHex(CryptoUtils.randomBytes(32));
    final sig = bip340.sign(privateKey, id, aux);
    return <String, dynamic>{
      'id': id,
      'pubkey': pubkey,
      'created_at': timestamp,
      'kind': giftWrapKind,
      'tags': tags,
      'content': content,
      'sig': sig,
    };
  }

  /// Checks that [event] is well-formed, that `id` is the SHA-256 of the
  /// NIP-01 canonical serialisation, and that `sig` is a valid BIP-340
  /// signature over `id` by `pubkey`. Never throws.
  static Future<bool> verifyEvent(Map<String, dynamic> event) async {
    try {
      final id = event['id'];
      final pubkey = event['pubkey'];
      final createdAt = event['created_at'];
      final kind = event['kind'];
      final content = event['content'];
      final sig = event['sig'];
      if (id is! String || !_isHex(id, 64)) return false;
      if (pubkey is! String || !_isHex(pubkey, 64)) return false;
      if (createdAt is! int || createdAt < 0) return false;
      if (kind is! int || kind < 0) return false;
      if (content is! String) return false;
      if (sig is! String || !_isHex(sig, 128)) return false;
      final tags = _normalizeTags(event['tags']);
      if (tags == null) return false;
      final expectedId = await _computeId(
        pubkey: pubkey,
        createdAt: createdAt,
        kind: kind,
        tags: tags,
        content: content,
      );
      if (expectedId != id) return false;
      return bip340.verify(pubkey, id, sig);
    } catch (e) {
      debugPrint('[Nostr] verifyEvent error: $e');
      return false;
    }
  }

  static Future<String> _computeId({
    required String pubkey,
    required int createdAt,
    required int kind,
    required List<List<String>> tags,
    required String content,
  }) async {
    final canonical = jsonEncode(<Object>[
      0,
      pubkey,
      createdAt,
      kind,
      tags,
      content,
    ]);
    return CryptoUtils.toHex(await CryptoUtils.sha256(utf8.encode(canonical)));
  }

  static List<List<String>>? _normalizeTags(Object? raw) {
    if (raw is! List) return null;
    final out = <List<String>>[];
    for (final tag in raw) {
      if (tag is! List) return null;
      final values = <String>[];
      for (final value in tag) {
        if (value is! String) return null;
        values.add(value);
      }
      out.add(values);
    }
    return out;
  }

  static String _randomPrivateKeyHex() {
    while (true) {
      final candidate = CryptoUtils.toHex(CryptoUtils.randomBytes(32));
      final scalar = BigInt.parse(candidate, radix: 16);
      if (scalar >= BigInt.one && scalar < _curveOrder) return candidate;
    }
  }

  /// Lowercase hex of exactly [length] characters, as NIP-01 requires.
  static bool _isHex(String value, int length) {
    if (value.length != length) return false;
    for (var i = 0; i < length; i++) {
      final c = value.codeUnitAt(i);
      final ok = (c >= 0x30 && c <= 0x39) || (c >= 0x61 && c <= 0x66);
      if (!ok) return false;
    }
    return true;
  }

  static int _nowSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  // ---------------------------------------------------------------------------
  // Connections
  // ---------------------------------------------------------------------------

  Future<bool> _connect(_RelayConnection conn) async {
    if (!_enabled || conn.isOpen || conn.connecting) return conn.isOpen;
    conn.connecting = true;
    conn.reconnectTimer?.cancel();
    conn.reconnectTimer = null;
    final client = _useTor
        ? TorManager.createTorHttpClient()
        : (HttpClient()..findProxy = (_) => 'DIRECT');
    try {
      final attempt = WebSocket.connect(conn.url, customClient: client);
      final ws = await attempt.timeout(
        _connectTimeout,
        onTimeout: () {
          // Make sure a late success does not leak a socket.
          unawaited(
            attempt
                .then<void>((late) => late.close())
                .catchError((Object _) {}),
          );
          throw TimeoutException('connect timed out', _connectTimeout);
        },
      );
      if (!_enabled) {
        await ws.close();
        return false;
      }
      final channel = IOWebSocketChannel(ws);
      conn.channel = channel;
      conn.failures = 0;
      conn.subscribed = false;
      conn.subscription = channel.stream.listen(
        (dynamic data) => _handleFrame(conn, channel, data),
        onError: (Object e) => _onClosed(conn, channel, 'error: $e'),
        onDone: () => _onClosed(conn, channel, 'closed by peer'),
        cancelOnError: true,
      );
      debugPrint('[Nostr] Connected to ${conn.url}');
      _sendSubscription(conn);
      _notify();
      return true;
    } catch (e) {
      conn.failures++;
      debugPrint(
        '[Nostr] Connect to ${conn.url} failed '
        '(attempt ${conn.failures}): $e',
      );
      _scheduleReconnect(conn);
      return false;
    } finally {
      conn.connecting = false;
      // The WebSocket detaches from the client on upgrade, so this only
      // releases idle resources.
      client.close();
    }
  }

  void _onClosed(_RelayConnection conn, WebSocketChannel channel, String why) {
    if (!identical(conn.channel, channel)) return; // stale callback
    conn.channel = null;
    conn.subscribed = false;
    unawaited(conn.subscription?.cancel());
    conn.subscription = null;
    debugPrint('[Nostr] ${conn.url} disconnected ($why)');
    _notify();
    if (_enabled) {
      conn.failures++;
      _scheduleReconnect(conn);
    }
  }

  void _scheduleReconnect(_RelayConnection conn) {
    if (!_enabled || conn.reconnectTimer != null || conn.isOpen) return;
    final exponent = (conn.failures - 1).clamp(0, _maxBackoffExponent);
    final base = _reconnectDelay * (1 << exponent);
    final jitterMs = (base.inMilliseconds * 0.2 * _rng.nextDouble()).round();
    final delay = base + Duration(milliseconds: jitterMs);
    debugPrint('[Nostr] Reconnecting to ${conn.url} in ${delay.inSeconds}s');
    conn.reconnectTimer = Timer(delay, () {
      conn.reconnectTimer = null;
      unawaited(_connect(conn));
    });
  }

  void _sendSubscription(_RelayConnection conn) {
    if (!conn.isOpen) return;
    if (_tokens.isEmpty) {
      if (conn.subscribed) {
        _send(conn, <Object>['CLOSE', _subscriptionId]);
        conn.subscribed = false;
      }
      return;
    }
    final since = _nowSeconds() - _subscriptionWindow.inSeconds;
    final filter = <String, Object>{
      'kinds': <int>[giftWrapKind],
      '#p': _tokens,
      'since': since,
    };
    if (_send(conn, <Object>['REQ', _subscriptionId, filter])) {
      conn.subscribed = true;
    }
  }

  bool _send(_RelayConnection conn, Object message) =>
      _sendFrame(conn, jsonEncode(message));

  bool _sendFrame(_RelayConnection conn, String frame) {
    final channel = conn.channel;
    if (channel == null) return false;
    try {
      channel.sink.add(frame);
      return true;
    } catch (e) {
      debugPrint('[Nostr] Send to ${conn.url} failed: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Inbound frames
  // ---------------------------------------------------------------------------

  void _handleFrame(
    _RelayConnection conn,
    WebSocketChannel channel,
    dynamic data,
  ) {
    if (!identical(conn.channel, channel)) return;
    if (data is! String) return; // binary frames are not part of NIP-01
    if (data.length > _maxFrameChars) {
      debugPrint(
        '[Nostr] ${conn.url}: dropping oversized frame '
        '(${data.length} chars)',
      );
      return;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(data);
    } catch (_) {
      debugPrint('[Nostr] ${conn.url}: ignoring non-JSON frame');
      return;
    }
    if (decoded is! List || decoded.isEmpty || decoded.first is! String) {
      debugPrint('[Nostr] ${conn.url}: ignoring malformed frame');
      return;
    }
    try {
      switch (decoded.first as String) {
        case 'EVENT':
          if (decoded.length >= 3 &&
              decoded[1] == _subscriptionId &&
              decoded[2] is Map) {
            unawaited(
              _handleEvent(
                conn.url,
                Map<String, dynamic>.from(decoded[2] as Map),
              ),
            );
          }
        case 'OK':
          if (decoded.length >= 3 && decoded[1] is String) {
            final accepted = decoded[2] == true;
            final reason = decoded.length > 3 ? '${decoded[3]}' : '';
            _handleOk(conn.url, decoded[1] as String, accepted, reason);
          }
        case 'EOSE':
          debugPrint('[Nostr] ${conn.url}: end of stored events');
        case 'NOTICE':
          final notice = decoded.length > 1 ? '${decoded[1]}' : '';
          debugPrint('[Nostr] ${conn.url} notice: $notice');
        case 'CLOSED':
          final reason = decoded.length > 2 ? '${decoded[2]}' : '';
          debugPrint('[Nostr] ${conn.url} closed subscription: $reason');
          if (decoded.length > 1 && decoded[1] == _subscriptionId) {
            conn.subscribed = false;
          }
          if (reason.startsWith('auth-required')) {
            debugPrint(
              '[Nostr] ${conn.url} requires NIP-42 auth, '
              'which is not supported',
            );
          }
        case 'AUTH':
          debugPrint(
            '[Nostr] ${conn.url} requested NIP-42 auth '
            '(unsupported); continuing unauthenticated',
          );
        default:
          debugPrint(
            '[Nostr] ${conn.url}: unknown message type '
            '"${decoded.first}"',
          );
      }
    } catch (e, st) {
      debugPrint('[Nostr] ${conn.url}: frame handler error: $e\n$st');
    }
  }

  void _handleOk(String relay, String eventId, bool accepted, String reason) {
    final pending = _pending[eventId];
    if (pending == null) return;
    if (accepted) {
      pending.resolve(true);
    } else {
      debugPrint('[Nostr] $relay rejected event: $reason');
      pending.reject();
    }
  }

  Future<void> _handleEvent(String relay, Map<String, dynamic> event) async {
    try {
      if (event['kind'] != giftWrapKind) return;
      final content = event['content'];
      if (content is! String || content.length > maxInboundContentChars) {
        return;
      }
      final id = event['id'];
      if (id is! String || !_isHex(id, 64)) return;
      final token = _matchingRecipient(event['tags']);
      if (token == null) return;
      if (_seen.contains(id)) return;
      if (!await verifyEvent(event)) {
        debugPrint('[Nostr] $relay: dropping event with bad id/signature');
        return;
      }
      final Uint8List payload;
      try {
        payload = base64.decode(content);
      } on FormatException {
        debugPrint('[Nostr] $relay: dropping event with non-base64 content');
        return;
      }
      if (!_seen.add(id)) return; // duplicate arrived while verifying
      final createdAt = DateTime.fromMillisecondsSinceEpoch(
        (event['created_at'] as int) * 1000,
        isUtc: true,
      );
      _received++;
      _inbound.add(
        NostrInbound(
          token: token,
          payload: payload,
          createdAt: createdAt,
          eventId: id,
          relay: relay,
        ),
      );
      _notify();
    } catch (e, st) {
      debugPrint('[Nostr] $relay: inbound handler error: $e\n$st');
    }
  }

  /// First `p` tag that names one of our tokens, or null.
  String? _matchingRecipient(Object? tags) {
    if (tags is! List) return null;
    for (final tag in tags) {
      if (tag is List && tag.length >= 2 && tag[0] == 'p' && tag[1] is String) {
        final value = (tag[1] as String).toLowerCase();
        if (_tokenSet.contains(value)) return value;
      }
    }
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}

class _RelayConnection {
  _RelayConnection(this.url);

  final String url;
  WebSocketChannel? channel;
  StreamSubscription<dynamic>? subscription;
  Timer? reconnectTimer;
  bool connecting = false;
  bool subscribed = false;
  int failures = 0;

  bool get isOpen => channel != null;
}

class _PendingPublish {
  final Completer<bool> _completer = Completer<bool>();
  int expected = 0;
  int _rejections = 0;

  Future<bool> get future => _completer.future;

  void resolve(bool ok) {
    if (!_completer.isCompleted) _completer.complete(ok);
  }

  /// Counts one relay rejection; fails the publish once every relay we sent
  /// to has rejected it.
  void reject() {
    _rejections++;
    if (expected > 0 && _rejections >= expected) resolve(false);
  }
}

/// Bounded set of event ids with least-recently-used eviction.
class _LruSet {
  _LruSet(this.capacity);

  final int capacity;
  final Set<String> _items = <String>{};

  /// True if [value] is present; refreshes its recency.
  bool contains(String value) {
    if (!_items.remove(value)) return false;
    _items.add(value);
    return true;
  }

  /// Inserts [value]; returns false if it was already present.
  bool add(String value) {
    if (contains(value)) return false;
    _items.add(value);
    if (_items.length > capacity) _items.remove(_items.first);
    return true;
  }
}
