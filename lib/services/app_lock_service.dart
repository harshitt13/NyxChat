import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart';

import '../core/storage/local_storage.dart';

class AppLockService extends ChangeNotifier {
  final LocalStorage _storage;
  final FlutterSecureStorage _secureStore = const FlutterSecureStorage();
  
  static const String _kIsLockedEnabled = 'app_lock_enabled';
  static const String _kWipeOnFailure = 'wipe_on_failure';
  static const String _kEncryptedMasterKey = 'encrypted_master_key';
  static const String _kArgonSalt = 'argon_salt';
  static const String _kNonce = 'master_key_nonce';

  bool _isLocked = true;
  bool _isLockEnabled = false;
  bool _wipeOnFailure = true;
  int _failedAttempts = 0;
  List<int>? _currentMasterKey; // Track active master key for lock toggle

  bool get isLocked => _isLocked;
  bool get isLockEnabled => _isLockEnabled;
  bool get wipeOnFailure => _wipeOnFailure;
  int get failedAttempts => _failedAttempts;

  AppLockService(this._storage);

  /// Initializes the lock state on app boot
  Future<void> init() async {
    final enabledMap = await _secureStore.read(key: _kIsLockedEnabled);
    _isLockEnabled = enabledMap == 'true';
    
    final wipeMap = await _secureStore.read(key: _kWipeOnFailure);
    _wipeOnFailure = wipeMap != 'false'; // Defaults to true

    // If lock is not enabled, we still need a master key to open the DB.
    // Check the *unwrapped* key (used for no-password users), NOT the
    // encrypted key (which is only written when a password is configured).
    if (!_isLockEnabled) {
       _isLocked = false;
       final hasUnwrappedKey = await _secureStore.read(key: 'unwrapped_master_key') != null;
       if (!hasUnwrappedKey) {
           await _setupMasterKeyWithoutPassword();
       }
       // Auto unlock with the no-password key
       await _unlockWithoutPassword();
    } else {
       // Lock is enabled, wait for user input
       _isLocked = true;
    }
    notifyListeners();
  }

  /// Called when the app goes into the background
  Future<void> lockApp() async {
    if (!_isLockEnabled || _isLocked) return;
    
    // Wipe key from RAM via LocalStorage
    await _storage.closeAll();
    _isLocked = true;
    notifyListeners();
  }

  /// Attempts to unlock the app with the given password
  Future<bool> unlock(String password) async {
    try {
      final encryptedMasterKeyB64 = await _secureStore.read(key: _kEncryptedMasterKey);
      final saltB64 = await _secureStore.read(key: _kArgonSalt);
      final nonceB64 = await _secureStore.read(key: _kNonce);

      if (encryptedMasterKeyB64 == null || saltB64 == null || nonceB64 == null) {
        throw Exception("Lock data corrupted or not set");
      }

      final encryptedMasterKeyWithMac = base64Decode(encryptedMasterKeyB64);
      final salt = base64Decode(saltB64);
      final nonce = base64Decode(nonceB64);

      // Derive wrap key from password
      final wrapKey = await _deriveKeyArgon2(password, salt);

      // Split the stored blob into ciphertext and MAC (last 16 bytes = GCM tag)
      if (encryptedMasterKeyWithMac.length < 16) {
        throw Exception("Lock data corrupted: encrypted key too short");
      }
      final cipherText = encryptedMasterKeyWithMac.sublist(0, encryptedMasterKeyWithMac.length - 16);
      final macBytes = encryptedMasterKeyWithMac.sublist(encryptedMasterKeyWithMac.length - 16);

      // Decrypt master key
      final cipher = AesGcm.with256bits();
      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));
      
      List<int> masterKey;
      try {
        masterKey = await cipher.decrypt(
          secretBox, 
          secretKey: SecretKey(wrapKey),
        );
      } catch (e) {
        // Decryption failed (wrong password)
        _handleFailedAttempt();
        return false;
      }

      // Success
      _currentMasterKey = List<int>.from(masterKey);
      await _storage.openDatabases(masterKey);
      _failedAttempts = 0;
      _isLocked = false;
      notifyListeners();
      return true;

    } catch (e) {
      debugPrint("Unlock error: $e");
      return false;
    }
  }

  /// Sets up a new password, generates a master Hive key, and wraps it.
  Future<void> setupPassword(String password) async {
    // Generate salt
    final rnd = Random.secure();
    final salt = List<int>.generate(32, (_) => rnd.nextInt(256));
    
    // Derive wrap key
    final wrapKey = await _deriveKeyArgon2(password, salt);

    // Generate Hive Master Key
    final masterKey = List<int>.generate(32, (_) => rnd.nextInt(256));

    // Encrypt Master Key
    final cipher = AesGcm.with256bits();
    final secretBox = await cipher.encrypt(
      masterKey,
      secretKey: SecretKey(wrapKey),
    );

    // Persist
    await _secureStore.write(key: _kArgonSalt, value: base64Encode(salt));
    await _secureStore.write(key: _kNonce, value: base64Encode(secretBox.nonce));
    await _secureStore.write(key: _kEncryptedMasterKey, value: base64Encode(secretBox.cipherText + secretBox.mac.bytes));
    
    // Enable Lock
    await setLockEnabled(true);
    
    // Immediately open
    _currentMasterKey = List<int>.from(masterKey);
    await _storage.openDatabases(masterKey);
    _isLocked = false;
    notifyListeners();
  }

  /// Sets up a DB key for users who don't want a lock screen
  Future<void> _setupMasterKeyWithoutPassword() async {
    final rnd = Random.secure();
    final masterKey = List<int>.generate(32, (_) => rnd.nextInt(256));
    // We just store the master key as plain text in the TEE Secure Enclave
    await _secureStore.write(key: 'unwrapped_master_key', value: base64Encode(masterKey));
  }

  Future<void> _unlockWithoutPassword() async {
    final b64 = await _secureStore.read(key: 'unwrapped_master_key');
    if (b64 == null) {
      debugPrint('[AppLock] CRITICAL: unwrapped_master_key missing — cannot open DB');
      return;
    }
    final key = base64Decode(b64);
    _currentMasterKey = List<int>.from(key);
    await _storage.openDatabases(key);
  }

  Future<void> setLockEnabled(bool isEnabled) async {
    _isLockEnabled = isEnabled;
    await _secureStore.write(key: _kIsLockedEnabled, value: isEnabled ? 'true' : 'false');
    
    if (!isEnabled && _currentMasterKey != null) {
      // Store the master key unwrapped so _unlockWithoutPassword() works on next restart
      await _secureStore.write(
        key: 'unwrapped_master_key',
        value: base64Encode(_currentMasterKey!),
      );
    } else if (isEnabled) {
      // Remove the unwrapped key — password is now required
      await _secureStore.delete(key: 'unwrapped_master_key');
    }
    
    notifyListeners();
  }

  Future<void> setWipeOnFailure(bool wipe) async {
    _wipeOnFailure = wipe;
    await _secureStore.write(key: _kWipeOnFailure, value: wipe ? 'true' : 'false');
    notifyListeners();
  }

  Future<void> _handleFailedAttempt() async {
    _failedAttempts++;
    notifyListeners();

    if (_wipeOnFailure && _failedAttempts >= 5) {
      debugPrint("PANIC WIPE TRIGGERED: 5 failed attempts");
      
      // 1. Wipe all Hive data from disk
      await _storage.panicWipe();
      
      // 2. Wipe all secure storage (master key, salt, nonce, crypto keys, flags)
      await _secureStore.deleteAll();
      
      // 3. Reset in-memory state so UI navigates to fresh onboarding
      _failedAttempts = 0;
      _isLockEnabled = false;
      _isLocked = false;
      _wipeOnFailure = true;
      _currentMasterKey = null;
      
      notifyListeners();
    }
  }

  Future<List<int>> _deriveKeyArgon2(String password, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000, 
      bits: 256,
    );
    // Note: The cryptography package doesn't have Argon2id natively yet, 
    // so we use strong PBKDF2 as the KDF fallback since we can't add C FFI plugins easily without testing.
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return await secretKey.extractBytes();
  }
}
