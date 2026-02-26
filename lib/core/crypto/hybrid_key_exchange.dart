import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:convert/convert.dart';
import 'package:post_quantum/src/kyber.dart';
import 'package:post_quantum/src/algorithms/kyber/abstractions/pke_cipher.dart';

/// Hybrid Key Exchange combining classical X25519 ECDH with post-quantum
/// ML-KEM (Kyber-768) to defend against "Harvest Now, Decrypt Later" attacks.
///
/// The combined shared secret is derived as:
///   HKDF-SHA256(X25519_secret || Kyber_secret)
///
/// Even if one primitive is broken (ECC by quantum computers, or an
/// unforeseen weakness in Kyber), the other still protects the session.
class HybridKeyExchange {
  static const int kyberVersion = 768;

  final X25519 _x25519 = X25519();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  // ──────── Kyber Key Generation ────────

  /// Generate a Kyber-768 keypair from a secure random seed.
  /// Returns (publicKeyBytes, privateKeyBytes).
  Future<KyberKeyPair> generateKyberKeyPair() async {
    return Isolate.run(() {
      final kyber = Kyber.kem768();
      final seed = Uint8List(64);
      final rng = Random.secure();
      for (int i = 0; i < 64; i++) {
        seed[i] = rng.nextInt(256);
      }

      final (pk, sk) = kyber.generateKeys(seed);
      return KyberKeyPair(
        publicKey: pk.serialize(),
        privateKey: sk.serialize(),
      );
    });
  }

  /// Encapsulate: given the peer's Kyber public key, produce a ciphertext
  /// and a shared secret that only the private key holder can recover.
  /// Returns (ciphertextBytes, sharedSecretBytes).
  Future<KyberEncapsulation> encapsulate(Uint8List peerKyberPublicKey) async {
    final pkBytes = peerKyberPublicKey;
    return Isolate.run(() {
      final kyber = Kyber.kem768();
      final pk = KemPublicKey.deserialize(pkBytes, kyberVersion);

      final nonce = Uint8List(32);
      final rng = Random.secure();
      for (int i = 0; i < 32; i++) {
        nonce[i] = rng.nextInt(256);
      }

      final (cipher, sharedSecret) = kyber.encapsulate(pk, nonce);
      return KyberEncapsulation(
        ciphertext: cipher.serialize(),
        sharedSecret: sharedSecret,
      );
    });
  }

  /// Decapsulate: given the ciphertext and our Kyber private key,
  /// recover the shared secret.
  Future<Uint8List> decapsulate(
      Uint8List ciphertext, Uint8List kyberPrivateKey) async {
    final ctBytes = ciphertext;
    final skBytes = kyberPrivateKey;
    return Isolate.run(() {
      final kyber = Kyber.kem768();
      final sk = KemPrivateKey.deserialize(skBytes, kyberVersion);
      final cipher = PKECypher.deserialize(ctBytes, kyberVersion);

      return kyber.decapsulate(cipher, sk);
    });
  }

  // ──────── Hybrid Combination ────────

  /// Perform the full hybrid key exchange (initiator side).
  ///
  /// 1. Run classical X25519 ECDH with our identity keypair + peer's public key
  /// 2. Encapsulate against peer's Kyber public key
  /// 3. Combine both secrets via HKDF
  ///
  /// Returns the combined secret and the Kyber ciphertext to send to the peer.
  Future<HybridInitiatorResult> initiateHybrid({
    required SimpleKeyPair ourX25519KeyPair,
    required String peerX25519PublicKeyHex,
    required Uint8List peerKyberPublicKey,
  }) async {
    // 1. Classical X25519 ECDH
    final peerX25519Pub = SimplePublicKey(
      hex.decode(peerX25519PublicKeyHex),
      type: KeyPairType.x25519,
    );
    final ecdhSecret = await _x25519.sharedSecretKey(
      keyPair: ourX25519KeyPair,
      remotePublicKey: peerX25519Pub,
    );

    // 2. Post-Quantum Kyber KEM encapsulation
    final kyberResult = await encapsulate(peerKyberPublicKey);

    // 3. Combine: HKDF(X25519_secret || Kyber_secret)
    final combinedSecret = await _combineSecrets(
      ecdhSecret,
      kyberResult.sharedSecret,
    );

    return HybridInitiatorResult(
      combinedSecret: combinedSecret,
      kyberCiphertext: kyberResult.ciphertext,
    );
  }

  /// Complete the hybrid key exchange (responder side).
  ///
  /// 1. Run classical X25519 ECDH with our identity keypair + peer's public key
  /// 2. Decapsulate the received Kyber ciphertext with our private key
  /// 3. Combine both secrets via HKDF
  Future<SecretKey> completeHybrid({
    required SimpleKeyPair ourX25519KeyPair,
    required String peerX25519PublicKeyHex,
    required Uint8List kyberCiphertext,
    required Uint8List ourKyberPrivateKey,
  }) async {
    // 1. Classical X25519 ECDH
    final peerX25519Pub = SimplePublicKey(
      hex.decode(peerX25519PublicKeyHex),
      type: KeyPairType.x25519,
    );
    final ecdhSecret = await _x25519.sharedSecretKey(
      keyPair: ourX25519KeyPair,
      remotePublicKey: peerX25519Pub,
    );

    // 2. Post-Quantum Kyber KEM decapsulation
    final kyberSecret = await decapsulate(kyberCiphertext, ourKyberPrivateKey);

    // 3. Combine: HKDF(X25519_secret || Kyber_secret)
    return _combineSecrets(ecdhSecret, kyberSecret);
  }

  /// HKDF combination of two secrets into one 32-byte key.
  Future<SecretKey> _combineSecrets(
      SecretKey ecdhSecret, Uint8List kyberSecret) async {
    final ecdhBytes = await ecdhSecret.extractBytes();

    // Concatenate: ECDH || Kyber
    final combined = Uint8List(ecdhBytes.length + kyberSecret.length);
    combined.setRange(0, ecdhBytes.length, ecdhBytes);
    combined.setRange(ecdhBytes.length, combined.length, kyberSecret);

    // Derive final key via HKDF with domain separation info
    final derived = await _hkdf.deriveKey(
      secretKey: SecretKey(combined),
      nonce: 'NyxChat-Hybrid-KEx-v1'.codeUnits,
    );

    return SecretKey(await derived.extractBytes());
  }
}

// ──────── Data Classes ────────

/// Serializable Kyber keypair.
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

/// Result returned to the hybrid initiator.
class HybridInitiatorResult {
  final SecretKey combinedSecret;
  final Uint8List kyberCiphertext;

  HybridInitiatorResult({
    required this.combinedSecret,
    required this.kyberCiphertext,
  });
}
