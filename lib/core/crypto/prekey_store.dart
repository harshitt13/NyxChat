import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../protocol/parse.dart';
import '../storage/key_value_store.dart';
import 'crypto_utils.dart';
import 'hybrid_key_exchange.dart';

/// One-time ML-KEM-768 key pair that we handed to one contact.
///
/// The private half lives only in the encrypted prekey box and is deleted
/// the moment the contact's first message under it has been decrypted, so
/// a later compromise of this device (or of the long-term KEM key) cannot
/// recover the root of an asynchronous session that used it.
class OwnPrekey {
  final String id;
  final Uint8List publicKey;
  final Uint8List privateKey;
  final DateTime createdAt;

  OwnPrekey({
    required this.id,
    required this.publicKey,
    required this.privateKey,
    required this.createdAt,
  });

  Uint8List get idBytes => CryptoUtils.fromHex(id);

  Map<String, dynamic> toJson() => {
        'id': id,
        'pk': base64Encode(publicKey),
        'sk': base64Encode(privateKey),
        'created': createdAt.toIso8601String(),
      };

  factory OwnPrekey.fromJson(Map<String, dynamic> j) => parseOr(() {
        const ctx = 'own prekey';
        return OwnPrekey(
          id: PrekeyStore.requireId(j, 'id', context: ctx),
          publicKey: requireBase64(j, 'pk',
              length: CryptoUtils.kyber768PublicKeyLength, context: ctx),
          privateKey: requireBase64(j, 'sk',
              length: CryptoUtils.kyber768PrivateKeyLength, context: ctx),
          createdAt: requireDateTime(j, 'created', context: ctx),
        );
      }, context: 'own prekey');
}

/// The public half of a contact's one-time prekey that we may consume once
/// when we start an asynchronous session with that contact.
class PeerPrekey {
  final String id;
  final Uint8List publicKey;
  final DateTime receivedAt;

  PeerPrekey({
    required this.id,
    required this.publicKey,
    required this.receivedAt,
  });

  Uint8List get idBytes => CryptoUtils.fromHex(id);

  Map<String, dynamic> toJson() => {
        'id': id,
        'pk': base64Encode(publicKey),
        'recv': receivedAt.toIso8601String(),
      };

  factory PeerPrekey.fromJson(Map<String, dynamic> j) => parseOr(() {
        const ctx = 'peer prekey';
        return PeerPrekey(
          id: PrekeyStore.requireId(j, 'id', context: ctx),
          publicKey: requireBase64(j, 'pk',
              length: CryptoUtils.kyber768PublicKeyLength, context: ctx),
          receivedAt: requireDateTime(j, 'recv', context: ctx),
        );
      }, context: 'peer prekey');
}

/// What we hold from one contact: their current pool, the issue time of
/// the bundle it came from (monotonic, for replay rejection) and the ids
/// we already consumed (never re-admitted from a later bundle).
class _PeerPool {
  int issuedAtMs;
  List<PeerPrekey> keys;
  List<String> used;
  _PeerPool({required this.issuedAtMs, required this.keys, required this.used});

  Map<String, dynamic> toJson() => {
        'iat': issuedAtMs,
        'keys': keys.map((k) => k.toJson()).toList(),
        'used': used,
      };

  factory _PeerPool.fromJson(Map<String, dynamic> j) => parseOr(() {
        const ctx = 'peer prekey pool';
        return _PeerPool(
          issuedAtMs: requireInt(j, 'iat', context: ctx),
          keys: [
            for (final e in requireList(j, 'keys', maxLength: 64, context: ctx))
              PeerPrekey.fromJson(asJsonMap(e, context: ctx))
          ],
          used: requireStringList(j, 'used',
              maxLength: 64, maxItemLength: 16, context: ctx),
        );
      }, context: 'peer prekey pool');
}
/// Per-contact pools of one-time ML-KEM-768 prekeys: the ones we issued to
/// a contact (private half kept until used or expired) and the ones the
/// contact issued to us (public half, consumed when we initiate an
/// asynchronous session). Persisted in the encrypted `prekeys` box.
///
/// A prekey id is the first [idLength] bytes of SHA-256 over the public
/// key, hex encoded. Our private halves are wiped and deleted on use and
/// expire after [maxAge]; a contact's public halves are dropped a little
/// earlier ([peerMaxAge]) so we do not encapsulate to a key the contact has
/// already thrown away. Both pools are topped up on every direct handshake.
class PrekeyStore extends ChangeNotifier {
  static const int poolSize = 8;
  static const int idLength = 8;
  static const Duration maxAge = Duration(days: 30);
  static const Duration peerMaxAge = Duration(days: 28);
  static const int maxUsedRemembered = 32;
  static const String _ownPrefix = 'own:';
  static const String _peerPrefix = 'peer:';
  static final RegExp _idPattern = RegExp(r'^[0-9a-f]{16}$');

  final KeyValueStore _store;
  final DateTime Function() _clock;
  final Map<String, List<OwnPrekey>> _own = {};
  final Map<String, _PeerPool> _peer = {};

  PrekeyStore(this._store, {DateTime Function()? clock})
      : _clock = clock ?? _utcNow;

  static DateTime _utcNow() => DateTime.now().toUtc();

  static Future<Uint8List> idFor(List<int> publicKey) async =>
      (await CryptoUtils.sha256(publicKey)).sublist(0, idLength);

  static Future<String> idHexFor(List<int> publicKey) async =>
      CryptoUtils.toHex(await idFor(publicKey));

  static bool isValidId(String id) => _idPattern.hasMatch(id);

  static String requireId(Map<String, dynamic> j, String key,
      {String context = 'prekey'}) {
    final s = requireString(j, key,
        minLength: 2 * idLength, maxLength: 2 * idLength, context: context);
    if (!isValidId(s)) {
      throw FormatException('$context: "$key" is not a prekey id');
    }
    return s;
  }

  Future<void> load() async {
    _own.clear();
    _peer.clear();
    for (final key in _store.keys) {
      final raw = _store.get(key);
      if (raw == null) continue;
      try {
        if (key.startsWith(_ownPrefix)) {
          final list = parseOr(() => jsonDecode(raw) as List<dynamic>,
              context: 'own prekeys');
          _own[key.substring(_ownPrefix.length)] = [
            for (final e in list) OwnPrekey.fromJson(asJsonMap(e))
          ];
        } else if (key.startsWith(_peerPrefix)) {
          _peer[key.substring(_peerPrefix.length)] =
              _PeerPool.fromJson(decodeJsonObject(raw));
        }
      } catch (e) {
        debugPrint('[Prekeys] dropping corrupt entry $key: $e');
        await _store.delete(key);
      }
    }
    notifyListeners();
  }

  // Prekeys we issued

  /// Unexpired prekeys issued to [peerId] whose private half we still hold.
  List<OwnPrekey> outstanding(String peerId) {
    final now = _clock();
    return (_own[peerId] ?? const <OwnPrekey>[])
        .where((k) => !_expired(k.createdAt, maxAge, now))
        .toList();
  }

  /// Generate key pairs until [peerId]'s pool holds [poolSize] unexpired
  /// entries. Returns only the new ones; [outstanding] gives the full pool.
  Future<List<OwnPrekey>> replenish(String peerId) async {
    final now = _clock();
    final live = outstanding(peerId);
    final fresh = <OwnPrekey>[];
    while (live.length + fresh.length < poolSize) {
      final kp = await KyberKem.generateKeyPair();
      fresh.add(OwnPrekey(
        id: await idHexFor(kp.publicKey),
        publicKey: kp.publicKey,
        privateKey: kp.privateKey,
        createdAt: now,
      ));
    }
    for (final k in _own[peerId] ?? const <OwnPrekey>[]) {
      if (!live.contains(k)) CryptoUtils.wipe(k.privateKey);
    }
    _own[peerId] = [...live, ...fresh];
    await _saveOwn(peerId);
    return fresh;
  }

  /// The unexpired prekey [id] we issued to [peerId], or null if it was
  /// never issued to that contact, already used, expired or wiped.
  OwnPrekey? findOwn(String peerId, String id) {
    for (final k in outstanding(peerId)) {
      if (k.id == id) return k;
    }
    return null;
  }

  /// Wipe and forget the private half of [id]. Returns false if absent.
  Future<bool> deleteOwn(String peerId, String id) async {
    final list = _own[peerId];
    if (list == null) return false;
    final before = list.length;
    for (final k in list) {
      if (k.id == id) CryptoUtils.wipe(k.privateKey);
    }
    list.removeWhere((k) => k.id == id);
    if (list.length == before) return false;
    await _saveOwn(peerId);
    return true;
  }

  /// Drop expired entries from every pool. Returns how many were removed.
  Future<int> expire() async {
    final now = _clock();
    var removed = 0;
    for (final peerId in _own.keys.toList()) {
      final list = _own[peerId]!;
      final dead = list.where((k) => _expired(k.createdAt, maxAge, now)).toList();
      if (dead.isEmpty) continue;
      for (final k in dead) {
        CryptoUtils.wipe(k.privateKey);
      }
      list.removeWhere(dead.contains);
      removed += dead.length;
      await _saveOwn(peerId);
    }
    for (final peerId in _peer.keys.toList()) {
      final pool = _peer[peerId]!;
      final before = pool.keys.length;
      pool.keys.removeWhere((k) => _expired(k.receivedAt, peerMaxAge, now));
      if (pool.keys.length == before) continue;
      removed += before - pool.keys.length;
      await _savePeer(peerId);
    }
    return removed;
  }

  // Prekeys a contact issued to us

  /// Usable prekeys we hold from [peerId].
  int peerPrekeyCount(String peerId) {
    final pool = _peer[peerId];
    if (pool == null) return 0;
    final now = _clock();
    return pool.keys.where((k) => !_expired(k.receivedAt, peerMaxAge, now)).length;
  }

  /// Issue time of the last bundle accepted from [peerId] (ms since epoch).
  int? lastBundleIssuedAt(String peerId) => _peer[peerId]?.issuedAtMs;

  /// Replace the pool we hold from [peerId] with the contents of a bundle
  /// that has already been verified. Ids we consumed before are never
  /// re-admitted, so a bundle that still lists a prekey whose first use is
  /// in flight cannot make us use it twice.
  Future<void> replacePeerBundle(String peerId,
      {required List<PeerPrekey> keys, required int issuedAtMs}) async {
    final pool = _peer[peerId] ?? _PeerPool(issuedAtMs: 0, keys: [], used: []);
    pool.issuedAtMs = issuedAtMs;
    pool.keys = keys.where((k) => !pool.used.contains(k.id)).toList();
    _peer[peerId] = pool;
    await _savePeer(peerId);
  }

  /// Remove and return one usable prekey of [peerId], or null when the
  /// pool is empty (the caller then falls back to the long-term KEM key).
  Future<PeerPrekey?> takePeerPrekey(String peerId) async {
    final pool = _peer[peerId];
    if (pool == null) return null;
    final now = _clock();
    final before = pool.keys.length;
    pool.keys.removeWhere((k) => _expired(k.receivedAt, peerMaxAge, now));
    if (pool.keys.isEmpty) {
      if (before != 0) await _savePeer(peerId);
      return null;
    }
    final k = pool.keys.removeAt(0);
    pool.used.add(k.id);
    while (pool.used.length > maxUsedRemembered) {
      pool.used.removeAt(0);
    }
    await _savePeer(peerId);
    return k;
  }

  /// Forget every prekey we hold from [peerId] (the contact told us it no
  /// longer has the private halves). The next handshake issues a new pool.
  Future<void> discardPeerPrekeys(String peerId) async {
    final pool = _peer[peerId];
    if (pool == null || pool.keys.isEmpty) return;
    pool.keys = [];
    await _savePeer(peerId);
  }

  /// A contact rotated its identity: carry both pools over to the new id.
  Future<void> rename(String oldId, String newId) async {
    if (oldId == newId) return;
    final own = _own.remove(oldId);
    final peer = _peer.remove(oldId);
    await _store.delete('$_ownPrefix$oldId');
    await _store.delete('$_peerPrefix$oldId');
    if (own != null) {
      _own[newId] = own;
      await _saveOwn(newId);
    }
    if (peer != null) {
      _peer[newId] = peer;
      await _savePeer(newId);
    }
  }

  Future<void> forgetPeer(String peerId) async {
    for (final k in _own.remove(peerId) ?? const <OwnPrekey>[]) {
      CryptoUtils.wipe(k.privateKey);
    }
    _peer.remove(peerId);
    await _store.delete('$_ownPrefix$peerId');
    await _store.delete('$_peerPrefix$peerId');
    notifyListeners();
  }

  Future<void> clearAll() async {
    for (final list in _own.values) {
      for (final k in list) {
        CryptoUtils.wipe(k.privateKey);
      }
    }
    _own.clear();
    _peer.clear();
    for (final k in _store.keys.toList()) {
      await _store.delete(k);
    }
    notifyListeners();
  }

  static bool _expired(DateTime at, Duration max, DateTime now) =>
      now.difference(at) > max;

  Future<void> _saveOwn(String peerId) async {
    final list = _own[peerId];
    if (list == null || list.isEmpty) {
      _own.remove(peerId);
      await _store.delete('$_ownPrefix$peerId');
    } else {
      await _store.put('$_ownPrefix$peerId',
          jsonEncode(list.map((k) => k.toJson()).toList()));
    }
    notifyListeners();
  }

  Future<void> _savePeer(String peerId) async {
    final pool = _peer[peerId];
    if (pool == null) {
      await _store.delete('$_peerPrefix$peerId');
    } else {
      await _store.put('$_peerPrefix$peerId', jsonEncode(pool.toJson()));
    }
    notifyListeners();
  }
}