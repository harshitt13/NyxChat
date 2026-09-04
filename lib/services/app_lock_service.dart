import 'dart:convert';
import 'dart:isolate';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/crypto/crypto_utils.dart';
import '../core/storage/local_storage.dart';

/// Database lock.
///
/// * No password: the 256-bit master key sits in the platform keystore.
/// * Password: the master key is wrapped with AES-256-GCM under a key
///   derived with Argon2id (memory-hard). Older installs that used PBKDF2
///   are transparently re-wrapped with Argon2id on their next unlock.
/// * Duress password: opens a separate decoy profile and, if configured,
///   destroys the real one.
/// * Wipe after N failed attempts.
class AppLockService extends ChangeNotifier {
  final LocalStorage _storage;
  final FlutterSecureStorage _secure;

  static const String _kLockEnabled = 'app_lock_enabled';
  static const String _kWipeOnFailure = 'wipe_on_failure';
  static const String _kEncryptedMasterKey = 'encrypted_master_key';
  static const String _kSalt = 'argon_salt';
  static const String _kNonce = 'master_key_nonce';
  static const String _kKdf = 'master_key_kdf'; // 'argon2id' | 'pbkdf2'
  static const String _kUnwrapped = 'unwrapped_master_key';
  static const String _kDuressSalt = 'duress_salt';
  static const String _kDuressHash = 'duress_hash';
  static const String _kDuressWipes = 'duress_wipes_real';
  static const String _kDecoyKey = 'decoy_master_key';
  static const String _kFailed = 'failed_attempts';

  static const int maxFailedAttempts = 5;

  // Argon2id parameters (tuned for pure-Dart on mid-range phones: ~1 s).
  static const int argonMemoryKiB = 32 * 1024;
  static const int argonIterations = 2;
  static const int argonParallelism = 2;

  bool _isLocked = true;
  bool _isLockEnabled = false;
  bool _wipeOnFailure = true;
  bool _hasDuress = false;
  bool _duressWipesReal = false;
  bool _isDecoyProfile = false;
  int _failedAttempts = 0;
  List<int>? _masterKey;

  bool get isLocked => _isLocked;
  bool get isLockEnabled => _isLockEnabled;
  bool get wipeOnFailure => _wipeOnFailure;
  bool get hasDuressPassword => _hasDuress;
  bool get duressWipesReal => _duressWipesReal;
  bool get isDecoyProfile => _isDecoyProfile;
  int get failedAttempts => _failedAttempts;
  int get attemptsRemaining => maxFailedAttempts - _failedAttempts;

  AppLockService(this._storage, {FlutterSecureStorage? secureStorage})
      : _secure = secureStorage ?? const FlutterSecureStorage();

  Future<void> init() async {
    _isLockEnabled = await _secure.read(key: _kLockEnabled) == 'true';
    _wipeOnFailure = await _secure.read(key: _kWipeOnFailure) != 'false';
    _hasDuress = await _secure.read(key: _kDuressHash) != null;
    _duressWipesReal = await _secure.read(key: _kDuressWipes) == 'true';
    _failedAttempts =
        int.tryParse(await _secure.read(key: _kFailed) ?? '0') ?? 0;

    if (!_isLockEnabled) {
      if (await _secure.read(key: _kUnwrapped) == null) {
        await _secure.write(
            key: _kUnwrapped,
            value: base64Encode(CryptoUtils.randomBytes(32)));
      }
      await _unlockWithoutPassword();
    } else {
      _isLocked = true;
    }
    notifyListeners();
  }

  /// Lock when the app goes to the background.
  Future<void> lockApp() async {
    if (!_isLockEnabled || _isLocked) return;
    await _storage.closeAll();
    if (_masterKey != null) CryptoUtils.wipe(_masterKey!);
    _masterKey = null;
    _isLocked = true;
    notifyListeners();
  }

  /// Try the real password first, then the duress password.
  Future<bool> unlock(String password) async {
    try {
      if (await _tryRealPassword(password)) return true;
      if (_hasDuress && await _tryDuressPassword(password)) return true;
      await _handleFailedAttempt();
      return false;
    } catch (e) {
      debugPrint('[AppLock] unlock error: $e');
      return false;
    }
  }

  Future<bool> _tryRealPassword(String password) async {
    final encryptedB64 = await _secure.read(key: _kEncryptedMasterKey);
    final saltB64 = await _secure.read(key: _kSalt);
    final nonceB64 = await _secure.read(key: _kNonce);
    if (encryptedB64 == null || saltB64 == null || nonceB64 == null) {
      throw StateError('lock data missing');
    }
    final kdf = await _secure.read(key: _kKdf) ?? 'pbkdf2';
    final salt = base64Decode(saltB64);
    final wrapKey = kdf == 'argon2id'
        ? await deriveArgon2id(password, salt)
        : await _derivePbkdf2(password, salt);
    final Uint8List masterKey;
    try {
      masterKey = await CryptoUtils.aesGcmDecrypt(
        key: wrapKey,
        nonce: base64Decode(nonceB64),
        ciphertextWithTag: base64Decode(encryptedB64),
      );
    } on SecretBoxAuthenticationError {
      return false;
    }
    CryptoUtils.wipe(wrapKey);

    if (kdf != 'argon2id') {
      debugPrint('[AppLock] migrating wrap KDF to Argon2id');
      await _wrapAndStore(password, masterKey);
    }
    await _openPrimary(masterKey);
    return true;
  }

  Future<bool> _tryDuressPassword(String password) async {
    final saltB64 = await _secure.read(key: _kDuressSalt);
    final hashB64 = await _secure.read(key: _kDuressHash);
    if (saltB64 == null || hashB64 == null) return false;
    final derived = await deriveArgon2id(password, base64Decode(saltB64));
    final ok = CryptoUtils.constantTimeEquals(derived, base64Decode(hashB64));
    CryptoUtils.wipe(derived);
    if (!ok) return false;

    debugPrint('[AppLock] duress password accepted');
    if (_duressWipesReal) {
      await _storage.panicWipe();
      for (final k in const [_kEncryptedMasterKey, _kSalt, _kNonce, _kKdf]) {
        await _secure.delete(key: k);
      }
    }
    var decoyB64 = await _secure.read(key: _kDecoyKey);
    if (decoyB64 == null) {
      decoyB64 = base64Encode(CryptoUtils.randomBytes(32));
      await _secure.write(key: _kDecoyKey, value: decoyB64);
    }
    _isDecoyProfile = true;
    _masterKey = base64Decode(decoyB64);
    await _storage.openDatabases(_masterKey!, profileSuffix: '_decoy');
    _failedAttempts = 0;
    await _secure.write(key: _kFailed, value: '0');
    _isLocked = false;
    notifyListeners();
    return true;
  }

  Future<void> _openPrimary(List<int> masterKey) async {
    _isDecoyProfile = false;
    _masterKey = List<int>.from(masterKey);
    await _storage.openDatabases(masterKey);
    _failedAttempts = 0;
    await _secure.write(key: _kFailed, value: '0');
    _isLocked = false;
    notifyListeners();
  }

  /// Enable the lock with a password. Wraps the current master key (or a
  /// fresh one if none exists yet).
  Future<void> setupPassword(String password) async {
    final current = _masterKey ??
        (await _secure.read(key: _kUnwrapped)).let(base64Decode) ??
        CryptoUtils.randomBytes(32);
    await _wrapAndStore(password, current);
    _isLockEnabled = true;
    await _secure.write(key: _kLockEnabled, value: 'true');
    await _secure.delete(key: _kUnwrapped);
    if (!_storage.isDatabasesOpen) await _openPrimary(current);
    _masterKey = List<int>.from(current);
    _isLocked = false;
    notifyListeners();
  }

  Future<void> _wrapAndStore(String password, List<int> masterKey) async {
    final salt = CryptoUtils.randomBytes(32);
    final nonce = CryptoUtils.randomBytes(12);
    final wrapKey = await deriveArgon2id(password, salt);
    final sealed = await CryptoUtils.aesGcmEncrypt(
        key: wrapKey, nonce: nonce, plaintext: masterKey);
    CryptoUtils.wipe(wrapKey);
    await _secure.write(key: _kSalt, value: base64Encode(salt));
    await _secure.write(key: _kNonce, value: base64Encode(nonce));
    await _secure.write(key: _kEncryptedMasterKey, value: base64Encode(sealed));
    await _secure.write(key: _kKdf, value: 'argon2id');
  }

  Future<void> setDuressPassword(String? password, {bool wipesReal = false}) async {
    if (password == null || password.isEmpty) {
      await _secure.delete(key: _kDuressSalt);
      await _secure.delete(key: _kDuressHash);
      _hasDuress = false;
    } else {
      final salt = CryptoUtils.randomBytes(32);
      final hash = await deriveArgon2id(password, salt);
      await _secure.write(key: _kDuressSalt, value: base64Encode(salt));
      await _secure.write(key: _kDuressHash, value: base64Encode(hash));
      _hasDuress = true;
    }
    _duressWipesReal = wipesReal;
    await _secure.write(key: _kDuressWipes, value: wipesReal ? 'true' : 'false');
    notifyListeners();
  }

  Future<void> _unlockWithoutPassword() async {
    final b64 = await _secure.read(key: _kUnwrapped);
    if (b64 == null) {
      debugPrint('[AppLock] CRITICAL: master key missing');
      return;
    }
    await _openPrimary(base64Decode(b64));
  }

  Future<void> setLockEnabled(bool enabled) async {
    if (!enabled) {
      final key = _masterKey;
      if (key == null) return;
      await _secure.write(key: _kUnwrapped, value: base64Encode(key));
      for (final k in const [_kEncryptedMasterKey, _kSalt, _kNonce, _kKdf]) {
        await _secure.delete(key: k);
      }
      _isLockEnabled = false;
      await _secure.write(key: _kLockEnabled, value: 'false');
      notifyListeners();
    }
    // Enabling requires setupPassword().
  }

  Future<void> setWipeOnFailure(bool wipe) async {
    _wipeOnFailure = wipe;
    await _secure.write(key: _kWipeOnFailure, value: wipe ? 'true' : 'false');
    notifyListeners();
  }

  Future<void> _handleFailedAttempt() async {
    _failedAttempts++;
    await _secure.write(key: _kFailed, value: '$_failedAttempts');
    notifyListeners();
    if (_wipeOnFailure && _failedAttempts >= maxFailedAttempts) {
      debugPrint('[AppLock] PANIC WIPE: too many failed attempts');
      await panicWipe();
    }
  }

  /// Destroy everything: databases of both profiles and all secure storage.
  Future<void> panicWipe() async {
    await _storage.wipeAllProfiles();
    await _secure.deleteAll();
    _failedAttempts = 0;
    _isLockEnabled = false;
    _isLocked = false;
    _wipeOnFailure = true;
    _hasDuress = false;
    _isDecoyProfile = false;
    _masterKey = null;
    notifyListeners();
  }

  // KDFs

  static Future<Uint8List> deriveArgon2id(String password, List<int> salt) {
    final pw = utf8.encode(password);
    final saltCopy = Uint8List.fromList(salt);
    return Isolate.run(() async {
      final argon = DartArgon2id(
        parallelism: argonParallelism,
        memory: argonMemoryKiB,
        iterations: argonIterations,
        hashLength: 32,
      );
      final key = await argon.deriveKey(
          secretKey: SecretKey(pw), nonce: saltCopy);
      return Uint8List.fromList(await key.extractBytes());
    });
  }

  static Future<Uint8List> _derivePbkdf2(String password, List<int> salt) async {
    final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 100000, bits: 256);
    final key = await pbkdf2.deriveKey(
        secretKey: SecretKey(utf8.encode(password)), nonce: salt);
    return Uint8List.fromList(await key.extractBytes());
  }
}

extension _Let<T> on T? {
  R? let<R>(R Function(T) f) {
    final v = this;
    return v == null ? null : f(v);
  }
}