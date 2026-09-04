import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyxchat/core/crypto/crypto_utils.dart';
import 'package:nyxchat/core/crypto/key_manager.dart';
import 'package:nyxchat/core/crypto/key_transition.dart';
import 'package:nyxchat/core/crypto/nyx_id.dart';

Future<(KeyManager, String)> _identity() async {
  final k = await KeyManager.generateEphemeral();
  final id = await NyxId.derive(signingPublicKey: k.signingPublicKey, identityPublicKey: k.identityPublicKey);
  return (k, id);
}

void main() {
  group('KeyTransition', () {
    test('valid statement verifies against the pinned old key and round-trips', () async {
      final (oldKeys, oldId) = await _identity();
      final (newKeys, newId) = await _identity();
      final t = await KeyTransition.create(oldKeys: oldKeys, oldId: oldId, newKeys: newKeys, newId: newId);
      final wire = KeyTransition.fromJson(jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>);
      expect(await wire.verify(pinnedOldSigningKey: oldKeys.signingPublicKey), isTrue);
      expect(wire.newId, newId);
    });

    test('rejects wrong pinned key, tampering, and mismatched new id', () async {
      final (oldKeys, oldId) = await _identity();
      final (newKeys, newId) = await _identity();
      final (other, _) = await _identity();
      final t = await KeyTransition.create(oldKeys: oldKeys, oldId: oldId, newKeys: newKeys, newId: newId);
      expect(await t.verify(pinnedOldSigningKey: other.signingPublicKey), isFalse);

      final j = t.toJson();
      j['ik'] = CryptoUtils.toHex(other.identityPublicKey);
      expect(await KeyTransition.fromJson(j).verify(pinnedOldSigningKey: oldKeys.signingPublicKey), isFalse);

      final j2 = t.toJson();
      j2['new'] = 'NC-0000000000000000';
      expect(await KeyTransition.fromJson(j2).verify(pinnedOldSigningKey: oldKeys.signingPublicKey), isFalse);

      // An attacker holding only the new keys cannot forge the old signature.
      final forged = KeyTransition(
        oldId: oldId, newId: newId, oldSigningKey: oldKeys.signingPublicKey,
        newIdentityKey: newKeys.identityPublicKey, newSigningKey: newKeys.signingPublicKey,
        newKyberKey: newKeys.kyberPublicKey, issuedAt: DateTime.now().toUtc(),
        signatureOld: CryptoUtils.randomBytes(64), signatureNew: t.signatureNew,
      );
      expect(await forged.verify(pinnedOldSigningKey: oldKeys.signingPublicKey), isFalse);
      expect(() => KeyTransition.fromJson({'v': 3}), throwsFormatException);
    });
  });
}