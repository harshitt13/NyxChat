import 'dart:isolate';
import 'dart:typed_data';

// The package's public entry point also exports a Dilithium module that does
// not compile in this prerelease, so import the Kyber pieces directly.
// ignore_for_file: implementation_imports
import 'package:post_quantum/src/algorithms/kyber/abstractions/pke_cipher.dart';
import 'package:post_quantum/src/kyber.dart';

import 'crypto_utils.dart';

/// Serialisable Kyber-768 key pair.
class KyberKeyPair {
  final Uint8List publicKey;
  final Uint8List privateKey;
  KyberKeyPair({required this.publicKey, required this.privateKey});
}

/// Result of a Kyber encapsulation.
class KyberEncapsulation {
  final Uint8List ciphertext;
  final Uint8List sharedSecret;
  KyberEncapsulation({required this.ciphertext, required this.sharedSecret});
}

/// Post-quantum key encapsulation used by the hybrid handshake.
///
/// Implementation note: `package:post_quantum` implements the CRYSTALS-Kyber
/// round-3 construction (SHAKE-256 KDF over K-bar || H(c)). It is *not* the
/// final FIPS 203 ML-KEM encoding, and it is a pure-Dart, unaudited
/// implementation. NyxChat therefore never relies on it alone: every Kyber
/// secret is combined with X25519 outputs through HKDF, so the session stays
/// secure as long as either primitive holds. All heavy lattice arithmetic
/// runs on a background isolate.
class KyberKem {
  KyberKem._();

  static const int version = 768;

  /// The library's "kyberVersion" parameter is the module rank k
  /// (2 = Kyber-512, 3 = Kyber-768, 4 = Kyber-1024), not the security level.
  static const int _rank = 3;

  static Future<KyberKeyPair> generateKeyPair() async {
    final seed = CryptoUtils.randomBytes(64);
    return Isolate.run(() {
      final kyber = Kyber.kem768();
      final keys = kyber.generateKeys(seed);
      return KyberKeyPair(
        publicKey: keys.$1.serialize(),
        privateKey: keys.$2.serialize(),
      );
    });
  }

  static Future<KyberEncapsulation> encapsulate(
      Uint8List peerPublicKey) async {
    if (peerPublicKey.length != CryptoUtils.kyber768PublicKeyLength) {
      throw FormatException(
          'Kyber-768 public key must be ${CryptoUtils.kyber768PublicKeyLength} bytes');
    }
    final coins = CryptoUtils.randomBytes(32);
    final pkBytes = Uint8List.fromList(peerPublicKey);
    return Isolate.run(() {
      final kyber = Kyber.kem768();
      final pk = KemPublicKey.deserialize(pkBytes, _rank);
      final result = kyber.encapsulate(pk, coins);
      return KyberEncapsulation(
        ciphertext: result.$1.serialize(),
        sharedSecret: Uint8List.fromList(result.$2),
      );
    });
  }

  static Future<Uint8List> decapsulate(
      Uint8List ciphertext, Uint8List privateKey) async {
    if (ciphertext.length != CryptoUtils.kyber768CiphertextLength) {
      throw FormatException(
          'Kyber-768 ciphertext must be ${CryptoUtils.kyber768CiphertextLength} bytes');
    }
    final ct = Uint8List.fromList(ciphertext);
    final sk = Uint8List.fromList(privateKey);
    return Isolate.run(() {
      final kyber = Kyber.kem768();
      final key = KemPrivateKey.deserialize(sk, _rank);
      final cipher = PKECypher.deserialize(ct, _rank);
      return Uint8List.fromList(kyber.decapsulate(cipher, key));
    });
  }
}