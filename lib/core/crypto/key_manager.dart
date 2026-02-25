import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:convert/convert.dart';

/// Manages cryptographic key generation, storage, and retrieval.
/// Uses X25519 for key exchange and Ed25519 for signing.
class KeyManager {
  static const _storageKeyExchangePrivate = 'bitchat_kx_private';
  static const _storageKeyExchangePublic = 'bitchat_kx_public';
  static const _storageSigningPrivate = 'bitchat_sign_private';
  static const _storageSigningPublic = 'bitchat_sign_public';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final X25519 _keyExchangeAlgo = X25519();
  final Ed25519 _signingAlgo = Ed25519();

  SimpleKeyPair? _keyExchangeKeyPair;
  SimpleKeyPair? _signingKeyPair;

  /// Check if keys have been generated
  Future<bool> hasKeys() async {
    final kxPrivate = await _storage.read(key: _storageKeyExchangePrivate);
    return kxPrivate != null;
  }

  /// Generate new key pairs for the user
  Future<void> generateKeys() async {
    // Generate X25519 key pair for key exchange
    final kxPair = await _keyExchangeAlgo.newKeyPair();
    final kxPrivate = await kxPair.extractPrivateKeyBytes();
    final kxPublic = await kxPair.extractPublicKey();

    // Generate Ed25519 key pair for signing
    final signPair = await _signingAlgo.newKeyPair();
    final signPrivate = await signPair.extractPrivateKeyBytes();
    final signPublic = await signPair.extractPublicKey();

    // Store keys securely
    await _storage.write(
      key: _storageKeyExchangePrivate,
      value: hex.encode(kxPrivate),
    );
    await _storage.write(
      key: _storageKeyExchangePublic,
      value: hex.encode(kxPublic.bytes),
    );
    await _storage.write(
      key: _storageSigningPrivate,
      value: hex.encode(signPrivate),
    );
    await _storage.write(
      key: _storageSigningPublic,
      value: hex.encode(signPublic.bytes),
    );

    _keyExchangeKeyPair = SimpleKeyPairData(
      kxPrivate,
      publicKey: SimplePublicKey(kxPublic.bytes, type: KeyPairType.x25519),
      type: KeyPairType.x25519,
    );
    _signingKeyPair = SimpleKeyPairData(
      signPrivate,
      publicKey: SimplePublicKey(signPublic.bytes, type: KeyPairType.ed25519),
      type: KeyPairType.ed25519,
    );
  }

  /// Load existing key pairs from secure storage
  Future<void> loadKeys() async {
    final kxPrivateHex = await _storage.read(key: _storageKeyExchangePrivate);
    final kxPublicHex = await _storage.read(key: _storageKeyExchangePublic);
    final signPrivateHex = await _storage.read(key: _storageSigningPrivate);
    final signPublicHex = await _storage.read(key: _storageSigningPublic);

    if (kxPrivateHex == null || kxPublicHex == null ||
        signPrivateHex == null || signPublicHex == null) {
      throw StateError('Keys not found in storage');
    }

    _keyExchangeKeyPair = SimpleKeyPairData(
      hex.decode(kxPrivateHex),
      publicKey: SimplePublicKey(
        hex.decode(kxPublicHex),
        type: KeyPairType.x25519,
      ),
      type: KeyPairType.x25519,
    );

    _signingKeyPair = SimpleKeyPairData(
      hex.decode(signPrivateHex),
      publicKey: SimplePublicKey(
        hex.decode(signPublicHex),
        type: KeyPairType.ed25519,
      ),
      type: KeyPairType.ed25519,
    );
  }

  /// Get public key hex for key exchange (X25519)
  Future<String> getPublicKeyHex() async {
    final stored = await _storage.read(key: _storageKeyExchangePublic);
    return stored ?? '';
  }

  /// Get signing public key hex (Ed25519)
  Future<String> getSigningPublicKeyHex() async {
    final stored = await _storage.read(key: _storageSigningPublic);
    return stored ?? '';
  }

  /// Get the X25519 key pair
  SimpleKeyPair? get keyExchangeKeyPair => _keyExchangeKeyPair;

  /// Get the Ed25519 key pair
  SimpleKeyPair? get signingKeyPair => _signingKeyPair;

  /// Clear all keys (danger zone!)
  Future<void> clearKeys() async {
    await _storage.delete(key: _storageKeyExchangePrivate);
    await _storage.delete(key: _storageKeyExchangePublic);
    await _storage.delete(key: _storageSigningPrivate);
    await _storage.delete(key: _storageSigningPublic);
    _keyExchangeKeyPair = null;
    _signingKeyPair = null;
  }
}
