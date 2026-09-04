import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/crypto/crypto_utils.dart';
import '../core/crypto/key_manager.dart';
import '../core/storage/local_storage.dart';
import 'app_lock_service.dart';

/// Encrypted, passphrase-protected backup of the whole profile: identity
/// keys, contacts (pinned keys), ratchet sessions, group keys, messages,
/// rooms and settings.
///
/// File layout: "NYXBK1" || salt(32) || nonce(12) || AES-256-GCM(payload)
/// where the key is Argon2id(passphrase, salt) with the app-lock
/// parameters and the payload is JSON.
///
/// Restoring on a second device while the first keeps running forks the
/// Double Ratchet sessions; the old device should be wiped after a move.
class BackupService {
  static const List<int> magic = [0x4E, 0x59, 0x58, 0x42, 0x4B, 0x31]; // NYXBK1
  static const String _aad = 'NyxChat-Backup-v1';

  final LocalStorage _storage;
  final KeyManager _keys;
  final FlutterSecureStorage _secure;

  BackupService(this._storage, this._keys, {FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  Future<Uint8List> export(String passphrase) async {
    if (passphrase.length < 8) throw ArgumentError('passphrase too short');
    final payload = jsonEncode({
      'v': 1,
      'created': DateTime.now().toUtc().toIso8601String(),
      'keys': await _keys.exportSecrets(),
      'displayName': await _secure.read(key: 'nyxchat_display_name'),
      'boxes': _storage.exportAll(),
    });
    final salt = CryptoUtils.randomBytes(32);
    final nonce = CryptoUtils.randomBytes(12);
    final key = await AppLockService.deriveArgon2id(passphrase, salt);
    final ct = await CryptoUtils.aesGcmEncrypt(
        key: key, nonce: nonce, plaintext: utf8.encode(payload), aad: _aad.codeUnits);
    CryptoUtils.wipe(key);
    return CryptoUtils.concat([magic, salt, nonce, ct]);
  }

  /// Decrypt and validate a backup without applying it.
  Future<Map<String, dynamic>> inspect(Uint8List bytes, String passphrase) async {
    if (bytes.length < magic.length + 32 + 12 + 16 ||
        !CryptoUtils.constantTimeEquals(bytes.sublist(0, magic.length), magic)) {
      throw const FormatException('not a NyxChat backup');
    }
    var o = magic.length;
    final salt = bytes.sublist(o, o += 32);
    final nonce = bytes.sublist(o, o += 12);
    final key = await AppLockService.deriveArgon2id(passphrase, salt);
    final Uint8List plain;
    try {
      plain = await CryptoUtils.aesGcmDecrypt(
          key: key, nonce: nonce, ciphertextWithTag: bytes.sublist(o), aad: _aad.codeUnits);
    } catch (_) {
      throw const FormatException('wrong passphrase or corrupted backup');
    } finally {
      CryptoUtils.wipe(key);
    }
    final json = jsonDecode(utf8.decode(plain));
    if (json is! Map<String, dynamic> || json['v'] != 1) {
      throw const FormatException('unsupported backup version');
    }
    return json;
  }

  /// Apply a backup: overwrites identity keys and every database box.
  Future<void> restore(Map<String, dynamic> backup) async {
    await _keys.importSecrets(backup['keys'] as Map<String, dynamic>);
    final name = backup['displayName'];
    if (name is String) await _secure.write(key: 'nyxchat_display_name', value: name);
    await _storage.importAll(backup['boxes'] as Map<String, dynamic>);
    debugPrint('[Backup] restored profile from ${backup['created']}');
  }
}