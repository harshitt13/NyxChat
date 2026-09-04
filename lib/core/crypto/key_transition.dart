import 'dart:convert';
import 'dart:typed_data';

import 'crypto_utils.dart';
import 'key_manager.dart';
import 'nyx_id.dart';

/// Signed statement that one identity has been replaced by another.
///
/// Signed by the *old* signing key (proves the holder of the pinned
/// identity authorised the change) and by the *new* signing key (proves
/// possession of the new keys). A contact that has the old keys pinned
/// can merge the new identity into the existing conversation without any
/// "safety number changed" alarm, and inherits the verified status.
///
/// Because the NyxChat handle is derived from the keys, a rotated identity
/// otherwise looks like a stranger; the statement is what links the two.
class KeyTransition {
  static const String _label = 'NyxChat-KeyTransition-v4';
  static const Duration maxAge = Duration(days: 180);

  final String oldId;
  final String newId;
  final Uint8List oldSigningKey;
  final Uint8List newIdentityKey;
  final Uint8List newSigningKey;
  final Uint8List newKyberKey;
  final DateTime issuedAt;
  final Uint8List signatureOld;
  final Uint8List signatureNew;

  KeyTransition({
    required this.oldId,
    required this.newId,
    required this.oldSigningKey,
    required this.newIdentityKey,
    required this.newSigningKey,
    required this.newKyberKey,
    required this.issuedAt,
    required this.signatureOld,
    required this.signatureNew,
  });

  static Uint8List transcriptFor({
    required String oldId,
    required String newId,
    required List<int> oldSigningKey,
    required List<int> newIdentityKey,
    required List<int> newSigningKey,
    required List<int> newKyberKey,
    required DateTime issuedAt,
  }) =>
      CryptoUtils.lengthPrefixed([
        _label.codeUnits,
        utf8.encode(oldId),
        utf8.encode(newId),
        oldSigningKey,
        newIdentityKey,
        newSigningKey,
        newKyberKey,
        CryptoUtils.int64be(issuedAt.toUtc().millisecondsSinceEpoch),
      ]);

  Uint8List transcript() => transcriptFor(
        oldId: oldId, newId: newId, oldSigningKey: oldSigningKey, newIdentityKey: newIdentityKey,
        newSigningKey: newSigningKey, newKyberKey: newKyberKey, issuedAt: issuedAt,
      );

  /// Sign a transition from the currently loaded [oldKeys] to [newKeys].
  static Future<KeyTransition> create({
    required KeyManager oldKeys,
    required String oldId,
    required KeyManager newKeys,
    required String newId,
  }) async {
    final issuedAt = DateTime.now().toUtc();
    final t = transcriptFor(
      oldId: oldId, newId: newId, oldSigningKey: oldKeys.signingPublicKey,
      newIdentityKey: newKeys.identityPublicKey, newSigningKey: newKeys.signingPublicKey,
      newKyberKey: newKeys.kyberPublicKey, issuedAt: issuedAt,
    );
    return KeyTransition(
      oldId: oldId,
      newId: newId,
      oldSigningKey: oldKeys.signingPublicKey,
      newIdentityKey: newKeys.identityPublicKey,
      newSigningKey: newKeys.signingPublicKey,
      newKyberKey: newKeys.kyberPublicKey,
      issuedAt: issuedAt,
      signatureOld: await oldKeys.sign(t),
      signatureNew: await newKeys.sign(t),
    );
  }

  /// Verify against the signing key we have pinned for [oldId].
  Future<bool> verify({required List<int> pinnedOldSigningKey}) async {
    if (!CryptoUtils.constantTimeEquals(pinnedOldSigningKey, oldSigningKey)) return false;
    if (oldId == newId) return false;
    final age = DateTime.now().toUtc().difference(issuedAt);
    if (age > maxAge || age < -const Duration(days: 1)) return false;
    if (!await NyxId.verify(id: newId, signingPublicKey: newSigningKey, identityPublicKey: newIdentityKey)) {
      return false;
    }
    final t = transcript();
    final okOld = await CryptoUtils.ed25519Verify(publicKey: oldSigningKey, message: t, signature: signatureOld);
    final okNew = await CryptoUtils.ed25519Verify(publicKey: newSigningKey, message: t, signature: signatureNew);
    return okOld && okNew;
  }

  Map<String, dynamic> toJson() => {
        'v': 4,
        'old': oldId,
        'new': newId,
        'osk': CryptoUtils.toHex(oldSigningKey),
        'ik': CryptoUtils.toHex(newIdentityKey),
        'sk': CryptoUtils.toHex(newSigningKey),
        'kpk': CryptoUtils.toHex(newKyberKey),
        'iat': issuedAt.toUtc().toIso8601String(),
        'so': CryptoUtils.toHex(signatureOld),
        'sn': CryptoUtils.toHex(signatureNew),
      };

  factory KeyTransition.fromJson(Map<String, dynamic> j) {
    try {
      if (j['v'] != 4) throw const FormatException('unsupported transition version');
      final oldId = j['old'] as String;
      final newId = j['new'] as String;
      if (!NyxId.isValidFormat(oldId) || !NyxId.isModern(newId)) {
        throw const FormatException('bad transition ids');
      }
      return KeyTransition(
        oldId: oldId,
        newId: newId,
        oldSigningKey: CryptoUtils.decodeKey(j['osk'] as String, 32, 'old signing key'),
        newIdentityKey: CryptoUtils.decodeKey(j['ik'] as String, 32, 'identity key'),
        newSigningKey: CryptoUtils.decodeKey(j['sk'] as String, 32, 'signing key'),
        newKyberKey: CryptoUtils.decodeKey(j['kpk'] as String, CryptoUtils.kyber768PublicKeyLength, 'kyber key'),
        issuedAt: DateTime.parse(j['iat'] as String),
        signatureOld: CryptoUtils.decodeKey(j['so'] as String, 64, 'old signature'),
        signatureNew: CryptoUtils.decodeKey(j['sn'] as String, 64, 'new signature'),
      );
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('malformed key transition: $e');
    }
  }
}