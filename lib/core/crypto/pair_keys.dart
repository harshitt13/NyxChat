import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../storage/trust_store.dart';
import 'crypto_utils.dart';
import 'key_manager.dart';

/// Keys shared by exactly one pair of contacts, derived from the static
/// X25519 agreement between their identity keys. Both sides compute the
/// same values; nobody else can. They drive everything that must be
/// recognisable to a contact but opaque to strangers and relays:
///
/// * discovery tokens (private presence beacons, 15-minute slots)
/// * mesh recipient tokens (rotating addresses, 1-hour epochs)
/// * Nostr recipient tokens (1-day epochs)
/// * the outer "sealed sender" wrapper around envelopes on the mesh and
///   on internet relays
///
/// Tokens include the *recipient's* handle so that the two directions of a
/// pair never share a token.
class PairKeys {
  static const int discoverySlotSeconds = 15 * 60;
  static const int meshEpochSeconds = 60 * 60;
  static const int nostrEpochSeconds = 24 * 60 * 60;

  final String peerId;
  final Uint8List _discoveryKey;
  final Uint8List _meshKey;
  final Uint8List _wrapKey;
  final Uint8List _nostrKey;

  PairKeys._(this.peerId, this._discoveryKey, this._meshKey, this._wrapKey,
      this._nostrKey);

  static Future<PairKeys> derive(KeyManager keys, PinnedPeer peer) =>
      deriveFromKey(peer.nyxChatId, keys, peer.identityKey);

  static Future<PairKeys> deriveFromKey(
      String peerId, KeyManager keys, List<int> peerIdentityKey) async {
    final dh = await CryptoUtils.x25519(keys.identityKeyPair, peerIdentityKey);
    Future<Uint8List> k(String info) =>
        CryptoUtils.hkdf(ikm: dh, salt: Uint8List(32), info: info);
    final out = PairKeys._(
      peerId,
      await k('NyxChat-Discovery-v4'),
      await k('NyxChat-MeshAddr-v4'),
      await k('NyxChat-MeshWrap-v4'),
      await k('NyxChat-Nostr-v4'),
    );
    CryptoUtils.wipe(dh);
    return out;
  }

  static int discoverySlot([DateTime? now]) =>
      (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch ~/ 1000 ~/
      discoverySlotSeconds;
  static int meshEpoch([DateTime? now]) =>
      (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch ~/ 1000 ~/
      meshEpochSeconds;
  static int nostrEpoch([DateTime? now]) =>
      (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch ~/ 1000 ~/
      nostrEpochSeconds;

  static Uint8List _tokenInput(String label, int period, String subject) =>
      CryptoUtils.lengthPrefixed([
        label.codeUnits,
        CryptoUtils.int64be(period),
        utf8.encode(subject),
      ]);

  /// 8-byte presence token that [advertiserId] shows to this contact
  /// during [slot].
  Future<Uint8List> discoveryToken(int slot, String advertiserId) async {
    final mac = await CryptoUtils.hmacSha256(
        _discoveryKey, _tokenInput('disc', slot, advertiserId));
    return mac.sublist(0, 8);
  }

  /// 16-byte mesh address under which [recipientId] receives during [epoch].
  Future<Uint8List> meshToken(int epoch, String recipientId) async {
    final mac = await CryptoUtils.hmacSha256(
        _meshKey, _tokenInput('mesh', epoch, recipientId));
    return mac.sublist(0, 16);
  }

  /// 32-byte (64 hex) relay token under which [recipientId] receives.
  Future<String> nostrToken(int epoch, String recipientId) async {
    final mac = await CryptoUtils.hmacSha256(
        _nostrKey, _tokenInput('nostr', epoch, recipientId));
    return CryptoUtils.toHex(mac);
  }

  static const _wrapAad = 'NyxChat-SealedSender-v4';

  /// Seal bytes so that only this pair can read or even recognise them.
  /// Output: 12-byte random nonce || AES-256-GCM ciphertext || tag.
  Future<Uint8List> wrap(List<int> plaintext) async {
    final nonce = CryptoUtils.randomBytes(12);
    final ct = await CryptoUtils.aesGcmEncrypt(
        key: _wrapKey, nonce: nonce, plaintext: plaintext, aad: _wrapAad.codeUnits);
    return CryptoUtils.concat([nonce, ct]);
  }

  /// Returns null if the blob was not sealed for this pair.
  Future<Uint8List?> unwrap(List<int> blob) async {
    if (blob.length < 12 + CryptoUtils.aesGcmTagLength) return null;
    try {
      return await CryptoUtils.aesGcmDecrypt(
        key: _wrapKey,
        nonce: blob.sublist(0, 12),
        ciphertextWithTag: blob.sublist(12),
        aad: _wrapAad.codeUnits,
      );
    } on SecretBoxAuthenticationError {
      return null;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    for (final k in [_discoveryKey, _meshKey, _wrapKey, _nostrKey]) {
      CryptoUtils.wipe(k);
    }
  }
}

/// Lazily derives and caches [PairKeys] for pinned contacts.
class PairKeyCache {
  final KeyManager _keys;
  final TrustStore _trust;
  final Map<String, PairKeys> _cache = {};
  final Map<String, String> _cacheKeyHex = {};

  PairKeyCache(this._keys, this._trust);

  /// Keys for [peerId], or null if the peer is not pinned.
  Future<PairKeys?> forPeer(String peerId) async {
    final peer = _trust.get(peerId);
    if (peer == null) return null;
    final cached = _cache[peerId];
    if (cached != null && _cacheKeyHex[peerId] == peer.identityKeyHex) {
      return cached;
    }
    cached?.dispose();
    final fresh = await PairKeys.derive(_keys, peer);
    _cache[peerId] = fresh;
    _cacheKeyHex[peerId] = peer.identityKeyHex;
    return fresh;
  }

  Future<List<PairKeys>> all() async {
    final out = <PairKeys>[];
    for (final p in _trust.all) {
      final k = await forPeer(p.nyxChatId);
      if (k != null) out.add(k);
    }
    return out;
  }

  void invalidate(String peerId) {
    _cache.remove(peerId)?.dispose();
    _cacheKeyHex.remove(peerId);
  }

  void clear() {
    for (final k in _cache.values) {
      k.dispose();
    }
    _cache.clear();
    _cacheKeyHex.clear();
  }
}