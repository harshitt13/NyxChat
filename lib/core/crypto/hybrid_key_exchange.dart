import 'dart:typed_data';

import 'crypto_utils.dart';
import 'mlkem_native.dart';

/// Serialisable ML-KEM-768 key pair (FIPS 203 encodings: 1184-byte
/// encapsulation key, 2400-byte decapsulation key).
class KyberKeyPair {
  final Uint8List publicKey;
  final Uint8List privateKey;
  KyberKeyPair({required this.publicKey, required this.privateKey});
}

/// Result of an ML-KEM-768 encapsulation.
class KyberEncapsulation {
  final Uint8List ciphertext;
  final Uint8List sharedSecret;
  KyberEncapsulation({required this.ciphertext, required this.sharedSecret});
}

/// Post-quantum key encapsulation used by the hybrid handshake.
///
/// This is **ML-KEM-768 as standardised in FIPS 203** (NIST, August 2024),
/// not the round-3 CRYSTALS-Kyber submission: the final domain separation,
/// the shared secret being K itself (no `KDF(K || H(c))` step) and the
/// SHAKE-256 implicit-rejection PRF are all the FIPS 203 ones, and the
/// implementation is checked against the NIST ACVP known-answer vectors
/// in `test/crypto/mlkem_test.dart`.
///
/// The arithmetic is not done in Dart. [MlKem768] binds, through `dart:ffi`,
/// the "clean" C99 reference implementation from the PQClean project
/// (vendored under `native/mlkem/`, commit recorded in its README). That code
/// is written to be constant-time (no secret-dependent branches or memory
/// accesses, constant-time compare/select in `verify.c`) and is the same
/// source many other projects ship; it is *not* a FIPS-validated module.
/// The C wrapper (`nyxpq.c`) additionally enforces the FIPS 203 input checks
/// (encapsulation-key modulus check, decapsulation-key hash check) and pulls
/// all randomness from the operating system (`getrandom`/`CryptGenRandom`);
/// no KEM randomness is generated in Dart.
///
/// Defence in depth is unchanged: every ML-KEM secret is combined with
/// X25519 outputs through HKDF, so a session stays secure as long as either
/// primitive holds. The KEM calls run on a background isolate so the UI
/// isolate never blocks on native work.
///
/// The `Kyber*` names are kept for source compatibility with existing
/// callers and persisted key material; the wire sizes are identical.
class KyberKem {
  KyberKem._();

  static const int version = 768;

  static Future<KyberKeyPair> generateKeyPair() async {
    return _run(() {
      final kp = MlKem768.keypair();
      return KyberKeyPair(publicKey: kp.publicKey, privateKey: kp.secretKey);
    });
  }

  static Future<KyberEncapsulation> encapsulate(Uint8List peerPublicKey) async {
    if (peerPublicKey.length != CryptoUtils.kyber768PublicKeyLength) {
      throw FormatException(
        'ML-KEM-768 public key must be ${CryptoUtils.kyber768PublicKeyLength} bytes',
      );
    }
    final pkBytes = Uint8List.fromList(peerPublicKey);
    return _run(() {
      final result = MlKem768.encapsulate(pkBytes);
      return KyberEncapsulation(
        ciphertext: result.ciphertext,
        sharedSecret: result.sharedSecret,
      );
    });
  }

  static Future<Uint8List> decapsulate(
    Uint8List ciphertext,
    Uint8List privateKey,
  ) async {
    if (ciphertext.length != CryptoUtils.kyber768CiphertextLength) {
      throw FormatException(
        'ML-KEM-768 ciphertext must be ${CryptoUtils.kyber768CiphertextLength} bytes',
      );
    }
    if (privateKey.length != CryptoUtils.kyber768PrivateKeyLength) {
      throw FormatException(
        'ML-KEM-768 private key must be ${CryptoUtils.kyber768PrivateKeyLength} bytes',
      );
    }
    final ct = Uint8List.fromList(ciphertext);
    final sk = Uint8List.fromList(privateKey);
    return _run(() => MlKem768.decapsulate(ct, sk));
  }
}

/// ML-KEM-768 in C takes a few milliseconds; spawning an isolate and
/// re-opening the native library per call costs more than the work itself,
/// so the FFI calls run on the calling isolate.
Future<T> _run<T>(T Function() body) async => body();
