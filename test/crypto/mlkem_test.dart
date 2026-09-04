import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyxchat/core/crypto/crypto_utils.dart';
import 'package:nyxchat/core/crypto/hybrid_key_exchange.dart';
import 'package:nyxchat/core/crypto/mlkem_native.dart';

import 'mlkem_kat_vectors.dart';

Uint8List _hex(String s) => CryptoUtils.fromHex(s);

Uint8List _flip(Uint8List src, int index, [int mask = 0x01]) {
  final out = Uint8List.fromList(src);
  out[index] ^= mask;
  return out;
}

void main() {
  group('MlKem768 native binding', () {
    test('native library loads and identifies itself', () {
      expect(
        MlKem768.isAvailable,
        isTrue,
        reason: 'build/native/nyxpq.* is missing; run tool/build_native.*',
      );
      expect(MlKem768.version, contains('ML-KEM-768'));
      expect(MlKem768.version, contains('PQClean'));
    });

    test('size constants match the protocol constants', () {
      expect(MlKem768.publicKeyLength, CryptoUtils.kyber768PublicKeyLength);
      expect(MlKem768.secretKeyLength, CryptoUtils.kyber768PrivateKeyLength);
      expect(MlKem768.ciphertextLength, CryptoUtils.kyber768CiphertextLength);
      expect(MlKem768.sharedSecretLength, 32);
    });

    test('outputs have FIPS 203 sizes', () {
      final kp = MlKem768.keypair();
      expect(kp.publicKey.length, 1184);
      expect(kp.secretKey.length, 2400);
      final enc = MlKem768.encapsulate(kp.publicKey);
      expect(enc.ciphertext.length, 1088);
      expect(enc.sharedSecret.length, 32);
      expect(MlKem768.decapsulate(enc.ciphertext, kp.secretKey).length, 32);
    });

    test('round trip', () {
      final kp = MlKem768.keypair();
      final enc = MlKem768.encapsulate(kp.publicKey);
      final ss = MlKem768.decapsulate(enc.ciphertext, kp.secretKey);
      expect(ss, enc.sharedSecret);
      expect(CryptoUtils.isAllZero(ss), isFalse);
    });

    test('fresh randomness every call', () {
      final a = MlKem768.keypair();
      final b = MlKem768.keypair();
      expect(a.publicKey, isNot(equals(b.publicKey)));
      final e1 = MlKem768.encapsulate(a.publicKey);
      final e2 = MlKem768.encapsulate(a.publicKey);
      expect(e1.ciphertext, isNot(equals(e2.ciphertext)));
      expect(e1.sharedSecret, isNot(equals(e2.sharedSecret)));
    });

    test('implicit rejection: wrong secret key gives a different secret', () {
      final kp1 = MlKem768.keypair();
      final kp2 = MlKem768.keypair();
      final enc = MlKem768.encapsulate(kp1.publicKey);
      final ss = MlKem768.decapsulate(enc.ciphertext, kp2.secretKey);
      expect(ss.length, 32);
      expect(ss, isNot(equals(enc.sharedSecret)));
    });

    test('implicit rejection: flipped ciphertext byte, no exception', () {
      final kp = MlKem768.keypair();
      final enc = MlKem768.encapsulate(kp.publicKey);
      for (final index in [0, 1, 500, 960, 1087]) {
        final bad = _flip(enc.ciphertext, index);
        final ss = MlKem768.decapsulate(bad, kp.secretKey);
        expect(ss.length, 32);
        expect(ss, isNot(equals(enc.sharedSecret)), reason: 'index $index');
        // The rejection secret is a deterministic PRF of (z, ct).
        expect(MlKem768.decapsulate(bad, kp.secretKey), ss);
      }
    });

    test('rejects wrong lengths with ArgumentError', () {
      final kp = MlKem768.keypair();
      expect(() => MlKem768.encapsulate(Uint8List(1183)), throwsArgumentError);
      expect(
        () => MlKem768.decapsulate(Uint8List(1087), kp.secretKey),
        throwsArgumentError,
      );
      expect(
        () => MlKem768.decapsulate(Uint8List(1088), Uint8List(2399)),
        throwsArgumentError,
      );
      expect(() => MlKem768.keypairDerand(Uint8List(63)), throwsArgumentError);
      expect(
        () => MlKem768.encapsulateDerand(kp.publicKey, Uint8List(31)),
        throwsArgumentError,
      );
    });

    test('FIPS 203 7.2: public key failing the modulus check is rejected', () {
      final kp = MlKem768.keypair();
      // Force the first 12-bit coefficient to q = 3329 = 0x0D01.
      final bad = Uint8List.fromList(kp.publicKey);
      bad[0] = 0x01;
      bad[1] = (bad[1] & 0xF0) | 0x0D;
      expect(() => MlKem768.encapsulate(bad), throwsFormatException);
      expect(
        () => MlKem768.encapsulateDerand(bad, Uint8List(32)),
        throwsFormatException,
      );
      // Coefficient q - 1 is still valid.
      bad[0] = 0x00;
      bad[1] = (bad[1] & 0xF0) | 0x0D;
      expect(MlKem768.encapsulate(bad).ciphertext.length, 1088);
    });

    test('FIPS 203 7.3: secret key failing the hash check is rejected', () {
      final kp = MlKem768.keypair();
      final enc = MlKem768.encapsulate(kp.publicKey);
      // Corrupt the embedded public key (offset 1152) ...
      expect(
        () => MlKem768.decapsulate(enc.ciphertext, _flip(kp.secretKey, 1152)),
        throwsFormatException,
      );
      // ... and the stored H(ek) (offset 2400 - 64).
      expect(
        () => MlKem768.decapsulate(enc.ciphertext, _flip(kp.secretKey, 2336)),
        throwsFormatException,
      );
      // Corrupting z (last 32 bytes) only affects the rejection secret.
      final ss = MlKem768.decapsulate(
        enc.ciphertext,
        _flip(kp.secretKey, 2399),
      );
      expect(ss, enc.sharedSecret);
    });

    test('stress: 200 round trips', () {
      for (var i = 0; i < 200; i++) {
        final kp = MlKem768.keypair();
        final enc = MlKem768.encapsulate(kp.publicKey);
        final ss = MlKem768.decapsulate(enc.ciphertext, kp.secretKey);
        expect(ss, enc.sharedSecret, reason: 'iteration $i');
        if (i % 20 == 0) {
          final other = MlKem768.keypair();
          expect(
            MlKem768.decapsulate(enc.ciphertext, other.secretKey),
            isNot(equals(enc.sharedSecret)),
          );
        }
      }
    });
  });

  group('ML-KEM-768 known-answer tests (NIST ACVP, FIPS 203)', () {
    test('keyGen: (d, z) -> (ek, dk)', () {
      final coins = Uint8List.fromList([
        ..._hex(katKeyGenD),
        ..._hex(katKeyGenZ),
      ]);
      final kp = MlKem768.keypairDerand(coins);
      expect(CryptoUtils.toHex(kp.publicKey), katKeyGenEk);
      expect(CryptoUtils.toHex(kp.secretKey), katKeyGenDk);
    });

    test('encapsulation: (ek, m) -> (c, K)', () {
      final enc = MlKem768.encapsulateDerand(_hex(katEncapEk), _hex(katEncapM));
      expect(CryptoUtils.toHex(enc.ciphertext), katEncapC);
      expect(CryptoUtils.toHex(enc.sharedSecret), katEncapK);
    });

    test('decapsulation: (dk, c) -> K', () {
      final ss = MlKem768.decapsulate(_hex(katDecapC), _hex(katDecapDk));
      expect(CryptoUtils.toHex(ss), katDecapK);
    });

    test('modified ciphertext yields the ACVP implicit-rejection key', () {
      final ss = MlKem768.decapsulate(_hex(katDecapRejC), _hex(katDecapRejDk));
      expect(CryptoUtils.toHex(ss), katDecapRejK);
      expect(ss, isNot(equals(_hex(katDecapK))));
    });
  });

  group('KyberKem facade over MlKem768', () {
    test('round trip through the background isolate', () async {
      final kp = await KyberKem.generateKeyPair();
      expect(kp.publicKey.length, CryptoUtils.kyber768PublicKeyLength);
      expect(kp.privateKey.length, CryptoUtils.kyber768PrivateKeyLength);
      final enc = await KyberKem.encapsulate(kp.publicKey);
      expect(enc.ciphertext.length, CryptoUtils.kyber768CiphertextLength);
      final ss = await KyberKem.decapsulate(enc.ciphertext, kp.privateKey);
      expect(ss, enc.sharedSecret);
      expect(KyberKem.version, 768);
    });

    test('agrees with the direct binding', () async {
      final kp = MlKem768.keypair();
      final enc = await KyberKem.encapsulate(kp.publicKey);
      expect(
        MlKem768.decapsulate(enc.ciphertext, kp.secretKey),
        enc.sharedSecret,
      );
      final ss = await KyberKem.decapsulate(enc.ciphertext, kp.secretKey);
      expect(ss, enc.sharedSecret);
    });

    test('length errors surface as FormatException futures', () async {
      await expectLater(
        KyberKem.encapsulate(Uint8List(10)),
        throwsFormatException,
      );
      await expectLater(
        KyberKem.decapsulate(Uint8List(10), Uint8List(2400)),
        throwsFormatException,
      );
      await expectLater(
        KyberKem.decapsulate(Uint8List(1088), Uint8List(10)),
        throwsFormatException,
      );
    });

    test('native input checks propagate out of the isolate', () async {
      final kp = await KyberKem.generateKeyPair();
      final bad = Uint8List.fromList(kp.publicKey);
      bad[0] = 0x01;
      bad[1] = (bad[1] & 0xF0) | 0x0D;
      await expectLater(KyberKem.encapsulate(bad), throwsFormatException);
    });
  });
}
