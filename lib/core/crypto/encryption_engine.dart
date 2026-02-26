import 'dart:convert';
import 'dart:isolate';
import 'package:cryptography/cryptography.dart';
import 'package:convert/convert.dart';

/// Handles end-to-end encryption of messages using
/// ECDH key agreement + AES-256-GCM.
/// Operations are routed through a background Isolate to prevent UI blockages.
class EncryptionEngine {
  /// Perform ECDH key agreement to derive a shared secret
  Future<SecretKey> deriveSharedSecret({
    required SimpleKeyPair ourKeyPair,
    required SimplePublicKey theirPublicKey,
  }) async {
    // Extract key data before isolate boundary (SimpleKeyPair may not be sendable)
    final ourPrivateKeyData = await ourKeyPair.extractPrivateKeyBytes();
    final ourPublicKeyData = (await ourKeyPair.extractPublicKey()).bytes;
    final theirPublicKeyData = theirPublicKey.bytes;
    
    return Isolate.run(() async {
      final keyExchange = X25519();
      final reconstructedKeyPair = SimpleKeyPairData(
        ourPrivateKeyData,
        publicKey: SimplePublicKey(ourPublicKeyData, type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      );
      return await keyExchange.sharedSecretKey(
        keyPair: reconstructedKeyPair,
        remotePublicKey: SimplePublicKey(theirPublicKeyData, type: KeyPairType.x25519),
      );
    });
  }

  /// Encrypt a message using AES-256-GCM with a shared secret
  Future<String> encryptMessage({
    required String plaintext,
    required SecretKey sharedSecret,
  }) async {
    // Extract key bytes before isolate boundary (SecretKey may not be sendable)
    final keyBytes = await sharedSecret.extractBytes();
    
    return Isolate.run(() async {
      final cipher = AesGcm.with256bits();
      final plaintextBytes = utf8.encode(plaintext);
      final nonce = cipher.newNonce();

      final secretBox = await cipher.encrypt(
        plaintextBytes,
        secretKey: SecretKey(keyBytes),
        nonce: nonce,
      );

      // Encode as: nonce(base64):ciphertext(base64):mac(base64)
      final nonceB64 = base64Encode(secretBox.nonce);
      final cipherB64 = base64Encode(secretBox.cipherText);
      final macB64 = base64Encode(secretBox.mac.bytes);

      return '$nonceB64:$cipherB64:$macB64';
    });
  }

  /// Decrypt a message using AES-256-GCM with a shared secret
  Future<String> decryptMessage({
    required String encryptedData,
    required SecretKey sharedSecret,
  }) async {
    // Extract key bytes before isolate boundary (SecretKey may not be sendable)
    final keyBytes = await sharedSecret.extractBytes();

    return Isolate.run(() async {
      final cipher = AesGcm.with256bits();
      final parts = encryptedData.split(':');
      if (parts.length != 3) {
        throw const FormatException('Invalid encrypted message format');
      }

      final nonce = base64Decode(parts[0]);
      final cipherText = base64Decode(parts[1]);
      final macBytes = base64Decode(parts[2]);

      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(macBytes),
      );

      final decrypted = await cipher.decrypt(
        secretBox,
        secretKey: SecretKey(keyBytes),
      );

      return utf8.decode(decrypted);
    });
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
