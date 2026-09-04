import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../crypto/crypto_utils.dart';
import '../crypto/nyx_id.dart';
import '../protocol/parse.dart';
import 'key_value_store.dart';

/// A peer's pinned long-term keys.
class PinnedPeer {
  final String nyxChatId;
  final String displayName;
  final Uint8List identityKey;
  final Uint8List signingKey;
  final Uint8List kyberPublicKey;
  final bool verified;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final DateTime? keyChangedAt;

  PinnedPeer({
    required this.nyxChatId,
    required this.displayName,
    required this.identityKey,
    required this.signingKey,
    required this.kyberPublicKey,
    required this.verified,
    required this.firstSeen,
    required this.lastSeen,
    this.keyChangedAt,
  });

  String get identityKeyHex => CryptoUtils.toHex(identityKey);
  String get signingKeyHex => CryptoUtils.toHex(signingKey);
  String get kyberPublicKeyHex => CryptoUtils.toHex(kyberPublicKey);

  Future<Uint8List> fingerprint() => NyxId.fingerprint(
      signingPublicKey: signingKey, identityPublicKey: identityKey);

  bool sameKeys({
    required List<int> identityKey,
    required List<int> signingKey,
  }) =>
      CryptoUtils.constantTimeEquals(this.identityKey, identityKey) &&
      CryptoUtils.constantTimeEquals(this.signingKey, signingKey);

  PinnedPeer copyWith({
    String? displayName,
    Uint8List? identityKey,
    Uint8List? signingKey,
    Uint8List? kyberPublicKey,
    bool? verified,
    DateTime? lastSeen,
    DateTime? keyChangedAt,
  }) =>
      PinnedPeer(
        nyxChatId: nyxChatId,
        displayName: displayName ?? this.displayName,
        identityKey: identityKey ?? this.identityKey,
        signingKey: signingKey ?? this.signingKey,
        kyberPublicKey: kyberPublicKey ?? this.kyberPublicKey,
        verified: verified ?? this.verified,
        firstSeen: firstSeen,
        lastSeen: lastSeen ?? this.lastSeen,
        keyChangedAt: keyChangedAt ?? this.keyChangedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': nyxChatId,
        'name': displayName,
        'ik': identityKeyHex,
        'sk': signingKeyHex,
        'kpk': kyberPublicKeyHex,
        'verified': verified,
        'first': firstSeen.toIso8601String(),
        'last': lastSeen.toIso8601String(),
        if (keyChangedAt != null) 'changed': keyChangedAt!.toIso8601String(),
      };

  factory PinnedPeer.fromJson(Map<String, dynamic> j) => parseOr(() {
        const ctx = 'pinned peer';
        return PinnedPeer(
          nyxChatId:
              requireString(j, 'id', minLength: 1, maxLength: 64, context: ctx),
          displayName: requireString(j, 'name', maxLength: 256, context: ctx),
          identityKey: requireHex(j, 'ik',
              length: CryptoUtils.x25519KeyLength, context: ctx),
          signingKey: requireHex(j, 'sk',
              length: CryptoUtils.ed25519KeyLength, context: ctx),
          kyberPublicKey: requireHex(j, 'kpk',
              length: CryptoUtils.kyber768PublicKeyLength, context: ctx),
          verified: optionalBool(j, 'verified', context: ctx) ?? false,
          firstSeen: requireDateTime(j, 'first', context: ctx),
          lastSeen: requireDateTime(j, 'last', context: ctx),
          keyChangedAt: optionalDateTime(j, 'changed', context: ctx),
        );
      }, context: 'pinned peer');

  /// A shareable contact card (what a QR code contains).
  Map<String, dynamic> toContactCard() => {
        'nyx': 3,
        'id': nyxChatId,
        'name': displayName,
        'ik': identityKeyHex,
        'sk': signingKeyHex,
        'kpk': kyberPublicKeyHex,
      };
}

enum TrustDecision { firstContact, unchanged, keyChanged }

class TrustCheck {
  final TrustDecision decision;
  final PinnedPeer peer;
  TrustCheck(this.decision, this.peer);
  bool get isKeyChange => decision == TrustDecision.keyChanged;
}

/// Trust-on-first-use store with explicit key-change detection.
///
/// A peer's handle is only a routing hint. The first time we meet a peer we
/// pin their keys; afterwards any handshake presenting different keys for
/// the same handle is refused until the user explicitly accepts the change
/// (after comparing safety numbers).
class TrustStore extends ChangeNotifier {
  final KeyValueStore _store;
  final Map<String, PinnedPeer> _cache = {};
  bool _loaded = false;

  TrustStore(this._store);

  Future<void> load() async {
    _cache.clear();
    for (final key in _store.keys) {
      final raw = _store.get(key);
      if (raw == null) continue;
      try {
        final peer = PinnedPeer.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        _cache[peer.nyxChatId] = peer;
      } catch (e) {
        debugPrint('[Trust] dropping corrupt entry $key: $e');
      }
    }
    _loaded = true;
    notifyListeners();
  }

  bool get isLoaded => _loaded;
  PinnedPeer? get(String nyxChatId) => _cache[nyxChatId];
  List<PinnedPeer> get all => _cache.values.toList();
  bool isVerified(String nyxChatId) => _cache[nyxChatId]?.verified ?? false;

  /// Compare presented keys against the pinned record. Never mutates a
  /// pinned key on its own: a change must be accepted via [acceptNewKeys].
  Future<TrustCheck> check({
    required String nyxChatId,
    required String displayName,
    required Uint8List identityKey,
    required Uint8List signingKey,
    required Uint8List kyberPublicKey,
  }) async {
    final now = DateTime.now().toUtc();
    final existing = _cache[nyxChatId];
    if (existing == null) {
      final peer = PinnedPeer(
        nyxChatId: nyxChatId,
        displayName: displayName,
        identityKey: identityKey,
        signingKey: signingKey,
        kyberPublicKey: kyberPublicKey,
        verified: false,
        firstSeen: now,
        lastSeen: now,
      );
      await _save(peer);
      return TrustCheck(TrustDecision.firstContact, peer);
    }
    if (existing.sameKeys(identityKey: identityKey, signingKey: signingKey)) {
      final updated = existing.copyWith(
        displayName: displayName,
        lastSeen: now,
        kyberPublicKey: kyberPublicKey,
      );
      await _save(updated);
      return TrustCheck(TrustDecision.unchanged, updated);
    }
    return TrustCheck(
      TrustDecision.keyChanged,
      PinnedPeer(
        nyxChatId: nyxChatId,
        displayName: displayName,
        identityKey: identityKey,
        signingKey: signingKey,
        kyberPublicKey: kyberPublicKey,
        verified: false,
        firstSeen: existing.firstSeen,
        lastSeen: now,
        keyChangedAt: now,
      ),
    );
  }

  /// Pin a contact obtained out of band (QR code / contact card).
  Future<PinnedPeer> pinFromContactCard(Map<String, dynamic> card,
      {bool verified = true}) async {
    const ctx = 'contact card';
    final (id, name, ik, sk, kpk) = parseOr(() {
      if (card['nyx'] != 3) throw const FormatException('unsupported card');
      final id =
          requireString(card, 'id', minLength: 1, maxLength: 64, context: ctx);
      if (!NyxId.isValidFormat(id)) {
        throw const FormatException('contact card: malformed id');
      }
      return (
        id,
        optionalString(card, 'name', maxLength: 64, context: ctx),
        requireHex(card, 'ik', length: 32, context: ctx),
        requireHex(card, 'sk', length: 32, context: ctx),
        requireHex(card, 'kpk',
            length: CryptoUtils.kyber768PublicKeyLength, context: ctx),
      );
    }, context: ctx);
    final bound = await NyxId.verify(
        id: id, signingPublicKey: sk, identityPublicKey: ik);
    if (!bound) throw const FormatException('card id does not match keys');
    final now = DateTime.now().toUtc();
    final existing = _cache[id];
    final peer = PinnedPeer(
      nyxChatId: id,
      displayName: name ?? existing?.displayName ?? id,
      identityKey: ik,
      signingKey: sk,
      kyberPublicKey: kpk,
      verified: verified,
      firstSeen: existing?.firstSeen ?? now,
      lastSeen: now,
    );
    await _save(peer);
    return peer;
  }

  /// User explicitly accepted a key change (or re-pinned after a reset).
  Future<void> acceptNewKeys(PinnedPeer peer) => _save(peer);

  Future<void> setVerified(String nyxChatId, bool verified) async {
    final p = _cache[nyxChatId];
    if (p != null) await _save(p.copyWith(verified: verified));
  }

  Future<void> remove(String nyxChatId) async {
    _cache.remove(nyxChatId);
    await _store.delete(nyxChatId);
    notifyListeners();
  }

  Future<void> clear() async {
    for (final k in _store.keys.toList()) {
      await _store.delete(k);
    }
    _cache.clear();
    notifyListeners();
  }

  Future<void> _save(PinnedPeer peer) async {
    _cache[peer.nyxChatId] = peer;
    await _store.put(peer.nyxChatId, jsonEncode(peer.toJson()));
    notifyListeners();
  }
}