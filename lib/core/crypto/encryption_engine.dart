import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:convert/convert.dart';

/// Handles end-to-end encryption of messages using
/// ECDH key agreement + AES-256-GCM.
class EncryptionEngine {
  final X25519 _keyExchange = X25519();
  final AesGcm _cipher = AesGcm.with256bits();

  /// Perform ECDH key agreement to derive a shared secret
  Future<SecretKey> deriveSharedSecret({
    required SimpleKeyPair ourKeyPair,
    required SimplePublicKey theirPublicKey,
  }) async {
    final sharedSecret = await _keyExchange.sharedSecretKey(
      keyPair: ourKeyPair,
      remotePublicKey: theirPublicKey,
    );
    return sharedSecret;
  }

  /// Encrypt a message using AES-256-GCM with a shared secret
  Future<String> encryptMessage({
    required String plaintext,
    required SecretKey sharedSecret,
  }) async {
    final plaintextBytes = utf8.encode(plaintext);
    final nonce = _cipher.newNonce();

    final secretBox = await _cipher.encrypt(
      plaintextBytes,
      secretKey: sharedSecret,
      nonce: nonce,
    );

    // Encode as: nonce(base64):ciphertext(base64):mac(base64)
    final nonceB64 = base64Encode(secretBox.nonce);
    final cipherB64 = base64Encode(secretBox.cipherText);
    final macB64 = base64Encode(secretBox.mac.bytes);

    return '$nonceB64:$cipherB64:$macB64';
  }

  /// Decrypt a message using AES-256-GCM with a shared secret
  Future<String> decryptMessage({
    required String encryptedData,
    required SecretKey sharedSecret,
  }) async {
    final parts = encryptedData.split(':');
    if (parts.length != 3) {
      throw FormatException('Invalid encrypted message format');
    }

    final nonce = base64Decode(parts[0]);
    final cipherText = base64Decode(parts[1]);
    final macBytes = base64Decode(parts[2]);

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final decrypted = await _cipher.decrypt(
      secretBox,
      secretKey: sharedSecret,
    );

    return utf8.decode(decrypted);
  }

  /// Create a shared secret from a peer's public key hex string
  Future<SecretKey> deriveSharedSecretFromHex({
    required SimpleKeyPair ourKeyPair,
    required String theirPublicKeyHex,
  }) async {
    final theirPublicKey = SimplePublicKey(
      hex.decode(theirPublicKeyHex),
      type: KeyPairType.x25519,
    );

    return deriveSharedSecret(
      ourKeyPair: ourKeyPair,
      theirPublicKey: theirPublicKey,
    );
  }
}
