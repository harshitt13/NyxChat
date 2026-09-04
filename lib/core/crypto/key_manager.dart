import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'crypto_utils.dart';
import 'hybrid_key_exchange.dart';

/// Long-term identity keys.
///
/// * X25519  - identity key used in the handshake and async session setup
/// * Ed25519 - signing key used to authenticate handshakes, group sender
///             keys and DHT announcements
/// * Kyber-768 - post-quantum KEM key used in the hybrid handshake
///
/// Private keys are stored only in the platform keystore-backed
/// [FlutterSecureStorage]. They are loaded into memory once per launch.
class KeyManager {
  /// Profile suffix ('' for the real profile, '_decoy' for the duress
  /// profile) so that each profile has independent identity keys.
  String _profile = '';

  String get _storageKeyExchangePrivate => 'nyxchat_kx_private$_profile';
  String get _storageKeyExchangePublic => 'nyxchat_kx_public$_profile';
  String get _storageSigningPrivate => 'nyxchat_sign_private$_profile';
  String get _storageSigningPublic => 'nyxchat_sign_public$_profile';
  String get _storageKyberPrivate => 'nyxchat_kyber_private$_profile';
  String get _storageKyberPublic => 'nyxchat_kyber_public$_profile';

  final FlutterSecureStorage _storage;

  String get profile => _profile;

  /// Switch storage namespace. Clears loaded keys.
  void setProfile(String suffix) {
    if (_profile == suffix) return;
    _profile = suffix;
    _identityKeyPair = null;
    _signingKeyPair = null;
    _kyberKeyPair = null;
  }

  SimpleKeyPairData? _identityKeyPair;
  SimpleKeyPairData? _signingKeyPair;
  KyberKeyPair? _kyberKeyPair;

  KeyManager({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Construct from in-memory keys (used by tests and the mesh simulator).
  KeyManager.fromKeys({
    required SimpleKeyPairData identityKeyPair,
    required SimpleKeyPairData signingKeyPair,
    required KyberKeyPair kyberKeyPair,
    FlutterSecureStorage? storage,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _identityKeyPair = identityKeyPair,
        _signingKeyPair = signingKeyPair,
        _kyberKeyPair = kyberKeyPair;

  /// Generate a complete in-memory key set without touching storage.
  static Future<KeyManager> generateEphemeral() async {
    return KeyManager.fromKeys(
      identityKeyPair: await CryptoUtils.newX25519KeyPair(),
      signingKeyPair: await CryptoUtils.newEd25519KeyPair(),
      kyberKeyPair: await KyberKem.generateKeyPair(),
    );
  }

  bool get isLoaded =>
      _identityKeyPair != null && _signingKeyPair != null && _kyberKeyPair != null;

  Future<bool> hasKeys() async =>
      await _storage.read(key: _storageKeyExchangePrivate) != null;

  /// Generate and persist a fresh key set.
  Future<void> generateKeys() async {
    final identity = await CryptoUtils.newX25519KeyPair();
    final signing = await CryptoUtils.newEd25519KeyPair();
    final kyber = await KyberKem.generateKeyPair();

    await _storage.write(
        key: _storageKeyExchangePrivate,
        value: CryptoUtils.toHex(identity.bytes));
    await _storage.write(
        key: _storageKeyExchangePublic,
        value: CryptoUtils.toHex(identity.publicKey.bytes));
    await _storage.write(
        key: _storageSigningPrivate, value: CryptoUtils.toHex(signing.bytes));
    await _storage.write(
        key: _storageSigningPublic,
        value: CryptoUtils.toHex(signing.publicKey.bytes));
    await _storage.write(
        key: _storageKyberPrivate, value: CryptoUtils.toHex(kyber.privateKey));
    await _storage.write(
        key: _storageKyberPublic, value: CryptoUtils.toHex(kyber.publicKey));

    _identityKeyPair = identity;
    _signingKeyPair = signing;
    _kyberKeyPair = kyber;
  }

  /// Load keys from secure storage. Older installs without a Kyber key get
  /// one generated on first launch.
  Future<void> loadKeys() async {
    final kxPrivate = await _storage.read(key: _storageKeyExchangePrivate);
    final kxPublic = await _storage.read(key: _storageKeyExchangePublic);
    final signPrivate = await _storage.read(key: _storageSigningPrivate);
    final signPublic = await _storage.read(key: _storageSigningPublic);
    if (kxPrivate == null ||
        kxPublic == null ||
        signPrivate == null ||
        signPublic == null) {
      throw StateError('Keys not found in storage');
    }

    _identityKeyPair = CryptoUtils.x25519KeyPairFromBytes(
      CryptoUtils.decodeKey(kxPrivate, 32, 'X25519 private key'),
      CryptoUtils.decodeKey(kxPublic, 32, 'X25519 public key'),
    );
    _signingKeyPair = CryptoUtils.ed25519KeyPairFromBytes(
      CryptoUtils.decodeKey(signPrivate, 32, 'Ed25519 private key'),
      CryptoUtils.decodeKey(signPublic, 32, 'Ed25519 public key'),
    );

    final kyberPrivate = await _storage.read(key: _storageKyberPrivate);
    final kyberPublic = await _storage.read(key: _storageKyberPublic);
    if (kyberPrivate != null && kyberPublic != null) {
      _kyberKeyPair = KyberKeyPair(
        publicKey: CryptoUtils.fromHex(kyberPublic),
        privateKey: CryptoUtils.fromHex(kyberPrivate),
      );
    } else {
      final kyber = await KyberKem.generateKeyPair();
      await _storage.write(
          key: _storageKyberPrivate,
          value: CryptoUtils.toHex(kyber.privateKey));
      await _storage.write(
          key: _storageKyberPublic, value: CryptoUtils.toHex(kyber.publicKey));
      _kyberKeyPair = kyber;
    }
  }

  SimpleKeyPairData get identityKeyPair =>
      _identityKeyPair ?? (throw StateError('identity key not loaded'));
  SimpleKeyPairData get signingKeyPair =>
      _signingKeyPair ?? (throw StateError('signing key not loaded'));
  KyberKeyPair get kyberKeyPair =>
      _kyberKeyPair ?? (throw StateError('kyber key not loaded'));

  Uint8List get identityPublicKey =>
      CryptoUtils.publicKeyBytes(identityKeyPair);
  Uint8List get signingPublicKey => CryptoUtils.publicKeyBytes(signingKeyPair);
  Uint8List get kyberPublicKey => kyberKeyPair.publicKey;

  String get identityPublicKeyHex => CryptoUtils.toHex(identityPublicKey);
  String get signingPublicKeyHex => CryptoUtils.toHex(signingPublicKey);
  String get kyberPublicKeyHex => CryptoUtils.toHex(kyberPublicKey);

  // Compatibility accessors used by older call sites.
  Future<String> getPublicKeyHex() async =>
      isLoaded ? identityPublicKeyHex
               : (await _storage.read(key: _storageKeyExchangePublic) ?? '');
  Future<String> getSigningPublicKeyHex() async =>
      isLoaded ? signingPublicKeyHex
               : (await _storage.read(key: _storageSigningPublic) ?? '');
  Future<String> getKyberPublicKeyHex() async =>
      isLoaded ? kyberPublicKeyHex
               : (await _storage.read(key: _storageKyberPublic) ?? '');

  /// Persist a freshly generated key set as the current profile's keys
  /// (identity rotation). The caller must have created any transition
  /// statement with the old keys before calling this.
  Future<void> replaceWith(KeyManager fresh) async {
    await importSecrets(await fresh.exportSecrets());
  }

  /// All private and public key material (hex) for an encrypted backup.
  Future<Map<String, String>> exportSecrets() async => {
        'kx_private': CryptoUtils.toHex(identityKeyPair.bytes),
        'kx_public': identityPublicKeyHex,
        'sign_private': CryptoUtils.toHex(signingKeyPair.bytes),
        'sign_public': signingPublicKeyHex,
        'kyber_private': CryptoUtils.toHex(kyberKeyPair.privateKey),
        'kyber_public': kyberPublicKeyHex,
      };

  /// Restore key material from a backup (overwrites the current profile).
  Future<void> importSecrets(Map<String, dynamic> m) async {
    String s(String k) => m[k] as String;
    CryptoUtils.decodeKey(s('kx_private'), 32, 'kx_private');
    CryptoUtils.decodeKey(s('sign_private'), 32, 'sign_private');
    await _storage.write(key: _storageKeyExchangePrivate, value: s('kx_private'));
    await _storage.write(key: _storageKeyExchangePublic, value: s('kx_public'));
    await _storage.write(key: _storageSigningPrivate, value: s('sign_private'));
    await _storage.write(key: _storageSigningPublic, value: s('sign_public'));
    await _storage.write(key: _storageKyberPrivate, value: s('kyber_private'));
    await _storage.write(key: _storageKyberPublic, value: s('kyber_public'));
    await loadKeys();
  }

  /// Ed25519 signature with the long-term signing key.
  Future<Uint8List> sign(List<int> message) =>
      CryptoUtils.ed25519Sign(signingKeyPair, message);

  /// Remove every key from storage and memory.
  Future<void> clearKeys() async {
    for (final k in [
      _storageKeyExchangePrivate,
      _storageKeyExchangePublic,
      _storageSigningPrivate,
      _storageSigningPublic,
      _storageKyberPrivate,
      _storageKyberPublic,
    ]) {
      await _storage.delete(key: k);
    }
    _identityKeyPair = null;
    _signingKeyPair = null;
    _kyberKeyPair = null;
  }
}