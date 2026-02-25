import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/crypto/key_manager.dart';
import '../core/storage/local_storage.dart';
import '../models/user_identity.dart';

/// Manages user identity: generation, storage, and retrieval.
class IdentityService extends ChangeNotifier {
  final KeyManager _keyManager = KeyManager();
  final LocalStorage _storage;
  UserIdentity? _identity;

  IdentityService(this._storage);

  UserIdentity? get identity => _identity;
  bool get hasIdentity => _identity != null;
  String get nyxChatId => _identity?.nyxChatId ?? '';
  String get displayName => _identity?.displayName ?? '';

  /// Initialize: Load existing identity or return null
  Future<bool> init() async {
    try {
      final hasKeys = await _keyManager.hasKeys();
      if (hasKeys) {
        await _keyManager.loadKeys();
        _identity = await _storage.getUserIdentity();
        if (_identity != null) {
          notifyListeners();
          return true;
        }
      }
      return false;
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

    // Save to storage
    await _storage.saveUserIdentity(identity);
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
    notifyListeners();
  }

  /// Get the key manager for crypto operations
  KeyManager get keyManager => _keyManager;

  /// Get public key hex
  Future<String> getPublicKeyHex() => _keyManager.getPublicKeyHex();

  /// Get signing public key hex
  Future<String> getSigningPublicKeyHex() =>
      _keyManager.getSigningPublicKeyHex();
}
