import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/crypto/key_manager.dart';
import '../core/storage/local_storage.dart';
import '../models/user_identity.dart';

/// Manages user identity: generation, storage, and retrieval.
class IdentityService extends ChangeNotifier {
  final KeyManager _keyManager = KeyManager();
  final LocalStorage _storage;
  final FlutterSecureStorage _secureStore = const FlutterSecureStorage();
  static const String _kDisplayName = 'nyxchat_display_name';
  UserIdentity? _identity;

  IdentityService(this._storage);

  UserIdentity? get identity => _identity;
  bool get hasIdentity => _identity != null;
  String get nyxChatId => _identity?.nyxChatId ?? '';
  String get displayName => _identity?.displayName ?? '';

  /// Initialize: Load existing identity from Hive.
  /// If Hive was reset (key mismatch) but crypto keys still exist in
  /// secure storage, the identity is automatically reconstructed so the
  /// user never has to re-onboard.
  Future<bool> init() async {
    try {
      final hasKeys = await _keyManager.hasKeys();
      if (!hasKeys) return false;

      await _keyManager.loadKeys();

      // Try loading from Hive first (fast path)
      _identity = await _storage.getUserIdentity();

      if (_identity != null) {
        // Ensure display name is synced to secure storage for future recovery
        await _secureStore.write(key: _kDisplayName, value: _identity!.displayName);
        notifyListeners();
        return true;
      }

      // Hive was empty (corrupted / reset) — reconstruct from keys
      debugPrint('[Identity] Hive identity missing — reconstructing from crypto keys');
      final publicKeyHex = await _keyManager.getPublicKeyHex();
      final signingPublicKeyHex = await _keyManager.getSigningPublicKeyHex();

      if (publicKeyHex.isEmpty) return false;

      // Recover display name from secure storage (set during generate/update)
      final savedName = await _secureStore.read(key: _kDisplayName) ?? 'User';

      final recovered = UserIdentity(
        nyxChatId: UserIdentity.generateNyxChatId(publicKeyHex),
        displayName: savedName,
        publicKeyHex: publicKeyHex,
        signingPublicKeyHex: signingPublicKeyHex,
        createdAt: DateTime.now(),
      );

      // Persist back to Hive so next load is fast
      await _storage.saveUserIdentity(recovered);
      _identity = recovered;
      notifyListeners();

      debugPrint('[Identity] Recovered identity: ${recovered.nyxChatId}');
      return true;
    } catch (e) {
      debugPrint('Failed to load identity: $e');
      return false;
    }
  }

  /// Generate a new identity
  Future<UserIdentity> generateIdentity(String displayName) async {
    // Generate cryptographic keys
    await _keyManager.generateKeys();
    await _keyManager.loadKeys();

    final publicKeyHex = await _keyManager.getPublicKeyHex();
    final signingPublicKeyHex = await _keyManager.getSigningPublicKeyHex();

    final identity = UserIdentity(
      nyxChatId: UserIdentity.generateNyxChatId(publicKeyHex),
      displayName: displayName,
      publicKeyHex: publicKeyHex,
      signingPublicKeyHex: signingPublicKeyHex,
      createdAt: DateTime.now(),
    );

    // Save to Hive and persist display name in secure storage for recovery
    await _storage.saveUserIdentity(identity);
    await _secureStore.write(key: _kDisplayName, value: displayName);
    _identity = identity;
    notifyListeners();

    debugPrint('Identity generated: ${identity.nyxChatId}');
    return identity;
  }

  /// Update display name
  Future<void> updateDisplayName(String newName) async {
    if (_identity == null) return;
    _identity = _identity!.copyWith(displayName: newName);
    await _storage.saveUserIdentity(_identity!);
    await _secureStore.write(key: _kDisplayName, value: newName);
    notifyListeners();
  }

  /// Get the key manager for crypto operations
  KeyManager get keyManager => _keyManager;

  /// Get public key hex
  Future<String> getPublicKeyHex() => _keyManager.getPublicKeyHex();

  /// Get signing public key hex
  Future<String> getSigningPublicKeyHex() =>
      _keyManager.getSigningPublicKeyHex();

  /// Get Kyber-768 public key hex (ML-KEM / post-quantum)
  Future<String> getKyberPublicKeyHex() =>
      _keyManager.getKyberPublicKeyHex();
}
