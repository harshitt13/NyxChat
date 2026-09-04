import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bip340/bip340.dart' as bip340;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyxchat/core/crypto/crypto_utils.dart';
import 'package:nyxchat/core/relay/nostr_transport.dart';

const Duration _fastReconnect = Duration(milliseconds: 200);

String _randomToken() => CryptoUtils.toHex(CryptoUtils.randomBytes(32));

Uint8List _payload(int length, [int seed = 0]) => Uint8List.fromList(
  List<int>.generate(length, (i) => (i * 7 + seed) & 0xff),
);

int _nowSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

/// NIP-01 event construction written from the spec, independent of the
/// transport's code, so the tests can cross-check it (and forge odd events).
Future<Map<String, dynamic>> _independentEvent({
  required int kind,
  required List<List<String>> tags,
  required String content,
}) async {
  final privateKey = CryptoUtils.toHex(CryptoUtils.randomBytes(32));
  final pubkey = bip340.getPublicKey(privateKey);
  final createdAt = _nowSeconds();
  final tagJson = tags
      .map((t) => '[${t.map((v) => '"$v"').join(',')}]')
      .join(',');
  final canonical = '[0,"$pubkey",$createdAt,$kind,[$tagJson],"$content"]';
  final digest = await Sha256().hash(utf8.encode(canonical));
  final id = CryptoUtils.toHex(digest.bytes);
  final aux = CryptoUtils.toHex(CryptoUtils.randomBytes(32));
  return <String, dynamic>{
    'id': id,
    'pubkey': pubkey,
    'created_at': createdAt,
    'kind': kind,
    'tags': tags,
    'content': content,
    'sig': bip340.sign(privateKey, id, aux),
  };
}

Future<void> _waitUntil(
  bool Function() condition, {
  required String reason,
  Duration timeout = const Duration(seconds: 8),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out waiting for $reason');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

/// Long enough for anything in flight on loopback to have arrived.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 400));

/// Minimal in-process NIP-01 relay: stores EVENTs, answers OK, replays stored
/// events matching a REQ filter followed by EOSE, and forwards live events to
/// matching subscriptions. Also has hooks to misbehave on purpose.
class MockNostrRelay {
  MockNostrRelay._(this._server);

  final HttpServer _server;
  final Map<String, Map<String, dynamic>> _events = {};
  final List<_MockClient> _clients = [];
  bool _closed = false;

  /// When false, every EVENT is answered with `OK false`.
  bool acceptEvents = true;

  int get port => _server.port;
  String get url => 'ws://127.0.0.1:$port';
  int get clientCount => _clients.length;
  int get storedCount => _events.length;
  List<Map<String, dynamic>> get storedEvents => _events.values.toList();
  int get subscriptionCount =>
      _clients.fold(0, (n, c) => n + c.subscriptions.length);

  static Future<MockNostrRelay> start({int port = 0}) async {
    HttpServer? server;
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (server == null) {
      try {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      } on SocketException {
        if (DateTime.now().isAfter(deadline)) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    final relay = MockNostrRelay._(server);
    server.listen((request) async {
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
        return;
      }
      relay._accept(await WebSocketTransformer.upgrade(request));
    });
    return relay;
  }

  void _accept(WebSocket socket) {
    if (_closed) {
      // The upgrade raced with close(): refuse the late connection.
      socket.close();
      return;
    }
    final client = _MockClient(socket);
    _clients.add(client);
    socket.listen(
      (dynamic data) => _handle(client, data),
      onDone: () => _clients.remove(client),
      onError: (Object _) => _clients.remove(client),
    );
  }

  void _handle(_MockClient client, dynamic data) {
    final message = jsonDecode(data as String) as List<dynamic>;
    switch (message[0] as String) {
      case 'EVENT':
        final event = Map<String, dynamic>.from(message[1] as Map);
        final id = event['id'] as String;
        if (!acceptEvents) {
          client.send(<Object>['OK', id, false, 'blocked: read-only']);
          return;
        }
        final isNew = !_events.containsKey(id);
        _events[id] = event;
        client.send(<Object>['OK', id, true, '']);
        if (isNew) _forward(event);
      case 'REQ':
        final subId = message[1] as String;
        final filter = Map<String, dynamic>.from(message[2] as Map);
        client.subscriptions[subId] = filter;
        for (final event in _events.values) {
          if (_matches(filter, event)) {
            client.send(<Object>['EVENT', subId, event]);
          }
        }
        client.send(<Object>['EOSE', subId]);
      case 'CLOSE':
        client.subscriptions.remove(message[1] as String);
    }
  }

  void _forward(Map<String, dynamic> event) {
    for (final client in _clients) {
      for (final entry in client.subscriptions.entries) {
        if (_matches(entry.value, event)) {
          client.send(<Object>['EVENT', entry.key, event]);
        }
      }
    }
  }

  /// Stores [event] and forwards it to matching subscriptions, as if another
  /// client had published it.
  void inject(Map<String, dynamic> event) {
    final id = event['id'] as String;
    final isNew = !_events.containsKey(id);
    _events[id] = event;
    if (isNew) _forward(event);
  }

  /// Pushes [event] to every subscription regardless of its filter (a leaky
  /// or replaying relay).
  void pushToSubscribers(Map<String, dynamic> event) =>
      sendToSubscribers((subId) => <Object>['EVENT', subId, event]);

  void sendToSubscribers(Object Function(String subId) build) {
    for (final client in _clients) {
      for (final subId in client.subscriptions.keys) {
        client.send(build(subId));
      }
    }
  }

  /// Sends a raw text frame to every client.
  void sendRaw(String frame) {
    for (final client in _clients) {
      client.sendText(frame);
    }
  }

  Future<void> close() async {
    _closed = true;
    for (final client in _clients.toList()) {
      client.closed = true;
      try {
        await client.socket.close().timeout(const Duration(seconds: 2));
      } catch (_) {
        // Peer already gone.
      }
    }
    await _server.close(force: true);
  }

  static bool _matches(
    Map<String, dynamic> filter,
    Map<String, dynamic> event,
  ) {
    final kinds = filter['kinds'];
    if (kinds is List && !kinds.contains(event['kind'])) return false;
    final since = filter['since'];
    if (since is int && (event['created_at'] as int) < since) return false;
    final recipients = filter['#p'];
    if (recipients is List) {
      final tags = (event['tags'] as List<dynamic>).cast<List<dynamic>>();
      final addressed = tags.any(
        (t) => t.length >= 2 && t[0] == 'p' && recipients.contains(t[1]),
      );
      if (!addressed) return false;
    }
    return true;
  }
}

class _MockClient {
  _MockClient(this.socket);

  final WebSocket socket;
  final Map<String, Map<String, dynamic>> subscriptions = {};
  bool closed = false;

  void send(Object message) => sendText(jsonEncode(message));

  /// A frame may still be handled after the socket started closing; a real
  /// relay would just drop it.
  void sendText(String frame) {
    if (closed) return;
    try {
      socket.add(frame);
    } on StateError {
      closed = true;
    }
  }
}

void main() {
  group('NostrTransport events', () {
    test(
      'buildEvent yields a verifiable NIP-01 event with canonical id',
      () async {
        final token = _randomToken();
        final payload = _payload(300);
        final when = DateTime.utc(2026, 9, 1, 12);
        final event = await NostrTransport.buildEvent(
          recipientTokenHex: token,
          payload: payload,
          createdAt: when,
        );
        expect(event['kind'], 1059);
        expect(event['created_at'], when.millisecondsSinceEpoch ~/ 1000);
        expect(event['tags'], [
          ['p', token],
        ]);
        expect(base64.decode(event['content'] as String), payload);
        expect((event['pubkey'] as String).length, 64);
        expect((event['sig'] as String).length, 128);

        // Independently computed id over the canonical serialisation.
        final canonical =
            '[0,"${event['pubkey']}",${event['created_at']},1059,'
            '[["p","$token"]],"${event['content']}"]';
        final digest = await Sha256().hash(utf8.encode(canonical));
        expect(event['id'], CryptoUtils.toHex(digest.bytes));
        expect(
          bip340.verify(
            event['pubkey'] as String,
            event['id'] as String,
            event['sig'] as String,
          ),
          isTrue,
        );
        expect(await NostrTransport.verifyEvent(event), isTrue);

        // What a relay hands back after a JSON round trip still verifies.
        final decoded = jsonDecode(jsonEncode(event)) as Map<String, dynamic>;
        expect(await NostrTransport.verifyEvent(decoded), isTrue);
      },
    );

    test('default created_at is randomised into the past two days', () async {
      final before = _nowSeconds();
      final event = await NostrTransport.buildEvent(
        recipientTokenHex: _randomToken(),
        payload: _payload(4),
      );
      final createdAt = event['created_at'] as int;
      expect(createdAt, lessThanOrEqualTo(_nowSeconds()));
      expect(createdAt, greaterThanOrEqualTo(before - 2 * 24 * 3600));
    });

    test('every event is signed with a fresh key', () async {
      final token = _randomToken();
      final payload = _payload(16);
      final a = await NostrTransport.buildEvent(
        recipientTokenHex: token,
        payload: payload,
      );
      final b = await NostrTransport.buildEvent(
        recipientTokenHex: token,
        payload: payload,
      );
      expect(a['pubkey'], isNot(b['pubkey']));
      expect(a['id'], isNot(b['id']));
    });

    test('tampering and malformed events fail verification', () async {
      final event = await NostrTransport.buildEvent(
        recipientTokenHex: _randomToken(),
        payload: _payload(32),
      );
      Map<String, dynamic> altered(String key, Object? value) =>
          <String, dynamic>{...event, key: value};

      expect(
        await NostrTransport.verifyEvent(altered('content', 'AAAA')),
        isFalse,
      );
      expect(
        await NostrTransport.verifyEvent(
          altered('tags', [
            ['p', _randomToken()],
          ]),
        ),
        isFalse,
      );
      expect(await NostrTransport.verifyEvent(altered('kind', 1)), isFalse);
      expect(
        await NostrTransport.verifyEvent(
          altered('created_at', (event['created_at'] as int) + 1),
        ),
        isFalse,
      );
      final sig = event['sig'] as String;
      final flipped = '${sig[0] == '0' ? '1' : '0'}${sig.substring(1)}';
      expect(
        await NostrTransport.verifyEvent(altered('sig', flipped)),
        isFalse,
      );
      final other = await NostrTransport.buildEvent(
        recipientTokenHex: _randomToken(),
        payload: _payload(1),
      );
      expect(
        await NostrTransport.verifyEvent(altered('pubkey', other['pubkey'])),
        isFalse,
      );

      // Garbage shapes are rejected without throwing.
      expect(await NostrTransport.verifyEvent(<String, dynamic>{}), isFalse);
      expect(await NostrTransport.verifyEvent(altered('sig', 'zz')), isFalse);
      expect(
        await NostrTransport.verifyEvent(altered('tags', 'nope')),
        isFalse,
      );
      expect(
        await NostrTransport.verifyEvent(altered('created_at', '1')),
        isFalse,
      );
      expect(
        await NostrTransport.verifyEvent(
          altered('id', (event['id'] as String).toUpperCase()),
        ),
        isFalse,
      );
    });

    test('events built independently from the spec verify', () async {
      final event = await _independentEvent(
        kind: 1059,
        tags: [
          ['p', _randomToken()],
        ],
        content: base64.encode(_payload(5)),
      );
      expect(await NostrTransport.verifyEvent(event), isTrue);
    });

    test(
      'buildEvent rejects malformed tokens and oversized payloads',
      () async {
        await expectLater(
          NostrTransport.buildEvent(
            recipientTokenHex: 'abc',
            payload: _payload(1),
          ),
          throwsArgumentError,
        );
        await expectLater(
          NostrTransport.buildEvent(
            recipientTokenHex: _randomToken(),
            payload: _payload(NostrTransport.maxPayloadBytes + 1),
          ),
          throwsArgumentError,
        );
        final event = await NostrTransport.buildEvent(
          recipientTokenHex: _randomToken(),
          payload: _payload(NostrTransport.maxPayloadBytes),
        );
        expect(
          (event['content'] as String).length,
          NostrTransport.maxInboundContentChars,
        );
      },
    );
  });
  group('NostrTransport over a mock relay', () {
    late MockNostrRelay relay;
    final transports = <NostrTransport>[];

    NostrTransport make(List<String> urls) {
      final transport = NostrTransport(
        relays: urls,
        useTor: false,
        reconnectDelay: _fastReconnect,
      );
      transports.add(transport);
      return transport;
    }

    setUp(() async {
      relay = await MockNostrRelay.start();
    });

    tearDown(() async {
      for (final transport in transports) {
        await transport.stop();
      }
      transports.clear();
      await relay.close();
    });

    test(
      'store-and-forward, live delivery, dedupe, token filter and stop',
      () async {
        final token = _randomToken();
        final other = _randomToken();
        final a = make([relay.url]);
        await a.start();
        expect(a.isEnabled, isTrue);
        expect(a.isConnected, isTrue);
        expect(a.connectedRelayCount, 1);
        expect(a.relays, [relay.url]);

        final first = _payload(1000, 1);
        expect(
          await a.publish(recipientTokenHex: token, payload: first),
          isTrue,
        );
        expect(a.published, 1);
        expect(relay.storedCount, 1);

        // B subscribes only after the publish: it must get the stored event.
        final b = make([relay.url]);
        final inbox = <NostrInbound>[];
        final subscription = b.onInbound.listen(inbox.add);
        b.setTokens([token.toUpperCase()]);
        expect(b.tokens, [token]);
        b.setTokens([token]); // unchanged: no-op
        await b.start();
        await _waitUntil(() => inbox.length == 1, reason: 'stored event');
        expect(inbox[0].payload, first);
        expect(inbox[0].token, token);
        expect(inbox[0].relay, relay.url);
        expect(inbox[0].eventId.length, 64);
        expect(b.received, 1);

        // Live forwarding while both are connected.
        final second = _payload(2000, 2);
        expect(
          await a.publish(recipientTokenHex: token, payload: second),
          isTrue,
        );
        await _waitUntil(() => inbox.length == 2, reason: 'live event');
        expect(inbox[1].payload, second);

        // The same events replayed by the relay are dropped.
        relay.pushToSubscribers(relay.storedEvents[0]);
        relay.pushToSubscribers(relay.storedEvents[1]);
        await _settle();
        expect(inbox.length, 2);
        expect(b.received, 2);

        // An event for another token is filtered by the relay, and rejected
        // client-side even when the relay leaks it.
        final third = _payload(50, 3);
        expect(
          await a.publish(recipientTokenHex: other, payload: third),
          isTrue,
        );
        relay.pushToSubscribers(relay.storedEvents[2]);
        await _settle();
        expect(inbox.length, 2);

        // Changing tokens re-issues the REQ and pulls the stored event.
        b.setTokens([token, other]);
        await _waitUntil(
          () => inbox.length == 3,
          reason: 'event after retoken',
        );
        expect(inbox[2].token, other);
        expect(inbox[2].payload, third);

        // stop() closes the socket and stays down.
        await b.stop();
        expect(b.isEnabled, isFalse);
        expect(b.isConnected, isFalse);
        expect(b.connectedRelayCount, 0);
        await _waitUntil(() => relay.clientCount == 1, reason: 'B closed');
        await _settle();
        expect(relay.clientCount, 1);
        expect(
          await a.publish(recipientTokenHex: token, payload: _payload(3)),
          isTrue,
        );
        await _settle();
        expect(inbox.length, 3);
        await subscription.cancel();

        await a.stop();
        await _waitUntil(() => relay.clientCount == 0, reason: 'A closed');
      },
    );

    test('deduplicates the same event across relays', () async {
      final relay2 = await MockNostrRelay.start();
      try {
        final token = _randomToken();
        final event = await NostrTransport.buildEvent(
          recipientTokenHex: token,
          payload: _payload(64),
        );
        relay.inject(event);
        relay2.inject(event);
        final b = make([relay.url, relay2.url]);
        final inbox = <NostrInbound>[];
        b.onInbound.listen(inbox.add);
        b.setTokens([token]);
        await b.start();
        await _waitUntil(() => b.connectedRelayCount == 2, reason: 'relays');
        await _waitUntil(() => inbox.isNotEmpty, reason: 'event');
        await _settle();
        expect(inbox.length, 1);
        expect(b.received, 1);
        expect(inbox.single.eventId, event['id']);
        expect(inbox.single.relay, anyOf(relay.url, relay2.url));
      } finally {
        await relay2.close();
      }
    });

    test(
      'publish reports rejections, size limits and missing relays',
      () async {
        final token = _randomToken();
        final a = make([relay.url]);
        // Not started: nothing to send to.
        expect(
          await a.publish(recipientTokenHex: token, payload: _payload(1)),
          isFalse,
        );
        await a.start();
        expect(
          await a.publish(recipientTokenHex: 'nothex', payload: _payload(1)),
          isFalse,
        );
        expect(
          await a.publish(
            recipientTokenHex: token,
            payload: _payload(NostrTransport.maxPayloadBytes + 1),
          ),
          isFalse,
        );
        relay.acceptEvents = false;
        expect(
          await a.publish(recipientTokenHex: token, payload: _payload(1)),
          isFalse,
        );
        expect(a.published, 0);
        relay.acceptEvents = true;

        final b = make([relay.url]);
        final inbox = <NostrInbound>[];
        b.onInbound.listen(inbox.add);
        b.setTokens([token]);
        await b.start();
        final big = _payload(NostrTransport.maxPayloadBytes, 9);
        expect(await a.publish(recipientTokenHex: token, payload: big), isTrue);
        expect(a.published, 1);
        await _waitUntil(() => inbox.length == 1, reason: 'max-size payload');
        expect(inbox.single.payload, big);
      },
    );

    test('ignores malformed, unsigned and misaddressed relay frames', () async {
      final token = _randomToken();
      final b = make([relay.url]);
      final inbox = <NostrInbound>[];
      b.onInbound.listen(inbox.add);
      b.setTokens([token]);
      await b.start();
      await _waitUntil(() => relay.subscriptionCount == 1, reason: 'REQ');

      final good = await NostrTransport.buildEvent(
        recipientTokenHex: token,
        payload: _payload(8),
      );
      final tampered = <String, dynamic>{
        ...good,
        'content': base64.encode(_payload(9)),
      };
      final pTag = [
        ['p', token],
      ];
      final wrongKind = await _independentEvent(
        kind: 1,
        tags: pTag,
        content: 'aGk=',
      );
      final notBase64 = await _independentEvent(
        kind: 1059,
        tags: pTag,
        content: 'not base64!',
      );
      final oversized = await _independentEvent(
        kind: 1059,
        tags: pTag,
        content: 'A' * (NostrTransport.maxInboundContentChars + 4),
      );
      final misaddressed = await NostrTransport.buildEvent(
        recipientTokenHex: _randomToken(),
        payload: _payload(8),
      );

      relay.sendRaw('this is not json');
      relay.sendRaw('{"not":"a list"}');
      relay.sendRaw('[]');
      relay.sendRaw('[42]');
      relay.sendRaw('["EVENT"]');
      relay.sendRaw('["OK"]');
      relay.sendRaw('["NOTICE","rate limited"]');
      relay.sendRaw('["AUTH","challenge"]');
      relay.sendRaw('["WHATEVER",1,2]');
      relay.sendToSubscribers((s) => ['CLOSED', s, 'auth-required: nope']);
      relay.sendToSubscribers((s) => ['EVENT', s, 'not a map']);
      relay.sendToSubscribers((s) => ['EVENT', s, tampered]);
      relay.sendToSubscribers((s) => ['EVENT', s, wrongKind]);
      relay.sendToSubscribers((s) => ['EVENT', s, notBase64]);
      relay.sendToSubscribers((s) => ['EVENT', s, oversized]);
      relay.sendToSubscribers((s) => ['EVENT', s, misaddressed]);
      relay.sendToSubscribers((_) => ['EVENT', 'someone-elses-sub', good]);
      await _settle();
      expect(inbox, isEmpty);
      expect(b.received, 0);
      expect(b.isConnected, isTrue);

      // The connection is still healthy: a valid event gets through.
      relay.sendToSubscribers((s) => ['EVENT', s, good]);
      await _waitUntil(() => inbox.length == 1, reason: 'valid event');
      expect(inbox.single.payload, _payload(8));
      expect(
        inbox.single.createdAt.millisecondsSinceEpoch ~/ 1000,
        good['created_at'],
      );
    });

    test('reconnects with backoff after the relay goes away', () async {
      final token = _randomToken();
      final b = make([relay.url]);
      final inbox = <NostrInbound>[];
      b.onInbound.listen(inbox.add);
      b.setTokens([token]);
      await b.start();
      await _waitUntil(() => relay.subscriptionCount == 1, reason: 'REQ');
      final port = relay.port;
      await relay.close();
      await _waitUntil(() => !b.isConnected, reason: 'disconnect');
      expect(b.isEnabled, isTrue);

      // A relay comes back on the same port; the transport must find it and
      // re-issue its subscription (tearDown closes this instance).
      relay = await MockNostrRelay.start(port: port);
      await _waitUntil(() => b.isConnected, reason: 'reconnect');
      await _waitUntil(() => relay.subscriptionCount == 1, reason: 'REQ again');
      final event = await NostrTransport.buildEvent(
        recipientTokenHex: token,
        payload: _payload(4),
      );
      relay.inject(event);
      await _waitUntil(
        () => inbox.length == 1,
        reason: 'event after reconnect',
      );
    });
  });
}
