import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/crypto/key_manager.dart';
import '../core/crypto/key_transition.dart';
import '../core/crypto/nyx_id.dart';
import '../core/storage/local_storage.dart';
import '../core/storage/trust_store.dart';
import '../models/user_identity.dart';

/// Output of [IdentityService.prepareRotation].
class PendingRotation {
  final KeyManager keys;
  final String newId;
  final KeyTransition statement;
  PendingRotation(this.keys, this.newId, this.statement);
}

/// Owns the local identity: long-term keys (secure storage) and the
/// profile record (encrypted database). If the database is ever reset the
/// identity is reconstructed from the keys, so users never re-onboard.
class IdentityService extends ChangeNotifier {
  final KeyManager _keyManager;
  final LocalStorage _storage;
  final FlutterSecureStorage _secure;
  static const String _kDisplayName = 'nyxchat_display_name';
  UserIdentity? _identity;

  IdentityService(this._storage,
      {KeyManager? keyManager, FlutterSecureStorage? secureStorage})
      : _keyManager = keyManager ?? KeyManager(),
        _secure = secureStorage ?? const FlutterSecureStorage();

  UserIdentity? get identity => _identity;
  bool get hasIdentity => _identity != null;
  String get nyxChatId => _identity?.nyxChatId ?? '';
  String get displayName => _identity?.displayName ?? '';
  KeyManager get keyManager => _keyManager;

  /// [decoy] selects the duress profile's independent key set.
  Future<bool> init({bool decoy = false}) async {
    try {
      _keyManager.setProfile(decoy ? '_decoy' : '');
      _identity = null;
      if (!await _keyManager.hasKeys()) {
        notifyListeners();
        return false;
      }
      await _keyManager.loadKeys();

      final stored = await _storage.getUserIdentity();
      if (stored != null) {
        _identity = await _migrateIfNeeded(stored);
        await _secure.write(key: _kDisplayName, value: _identity!.displayName);
        notifyListeners();
        return true;
      }

      debugPrint('[Identity] profile missing, reconstructing from keys');
      final name = await _secure.read(key: _kDisplayName) ?? 'User';
      _identity = await _buildIdentity(name);
      await _storage.saveUserIdentity(_identity!);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[Identity] init failed: $e');
      return false;
    }
  }

  /// Identities created before v3 derived their handle from the X25519
  /// key only. They keep that handle (peers verify legacy handles too) but
  /// gain the missing signing-key field.
  Future<UserIdentity> _migrateIfNeeded(UserIdentity stored) async {
    if (stored.signingPublicKeyHex.isNotEmpty &&
        stored.publicKeyHex == _keyManager.identityPublicKeyHex) {
      return stored;
    }
    final rebuilt = stored.copyWith(
      publicKeyHex: _keyManager.identityPublicKeyHex,
      signingPublicKeyHex: _keyManager.signingPublicKeyHex,
    );
    await _storage.saveUserIdentity(rebuilt);
    return rebuilt;
  }

  Future<UserIdentity> _buildIdentity(String displayName) async {
    final id = await NyxId.derive(
      signingPublicKey: _keyManager.signingPublicKey,
      identityPublicKey: _keyManager.identityPublicKey,
    );
    return UserIdentity(
      nyxChatId: id,
      displayName: displayName,
      publicKeyHex: _keyManager.identityPublicKeyHex,
      signingPublicKeyHex: _keyManager.signingPublicKeyHex,
      createdAt: DateTime.now(),
    );
  }

  Future<UserIdentity> generateIdentity(String displayName) async {
    await _keyManager.generateKeys();
    _identity = await _buildIdentity(displayName);
    await _storage.saveUserIdentity(_identity!);
    await _secure.write(key: _kDisplayName, value: displayName);
    notifyListeners();
    debugPrint('[Identity] generated ${_identity!.nyxChatId}');
    return _identity!;
  }

  Future<void> updateDisplayName(String newName) async {
    if (_identity == null) return;
    _identity = _identity!.copyWith(displayName: newName);
    await _storage.saveUserIdentity(_identity!);
    await _secure.write(key: _kDisplayName, value: newName);
    notifyListeners();
  }

  Future<String> getPublicKeyHex() => _keyManager.getPublicKeyHex();
  Future<String> getSigningPublicKeyHex() => _keyManager.getSigningPublicKeyHex();
  Future<String> getKyberPublicKeyHex() => _keyManager.getKyberPublicKeyHex();

  /// Our fingerprint (for safety numbers and QR contact cards).
  Future<Uint8List> fingerprint() => NyxId.fingerprint(
        signingPublicKey: _keyManager.signingPublicKey,
        identityPublicKey: _keyManager.identityPublicKey,
      );

  /// Contact card to share out of band (QR / copy). Contains only public
  /// material.
  Map<String, dynamic> contactCard() => {
        'nyx': 3,
        'id': nyxChatId,
        'name': displayName,
        'ik': _keyManager.identityPublicKeyHex,
        'sk': _keyManager.signingPublicKeyHex,
        'kpk': _keyManager.kyberPublicKeyHex,
      };

  /// Safety number between us and a pinned peer.
  Future<String> safetyNumberWith(PinnedPeer peer) async =>
      NyxId.safetyNumber(await fingerprint(), await peer.fingerprint());

  /// Step 1 of key rotation: generate the new key set and the signed
  /// transition statement, without switching yet (so the statement can be
  /// delivered over existing sessions first).
  Future<PendingRotation> prepareRotation() async {
    final current = _identity;
    if (current == null) throw StateError('no identity');
    final fresh = await KeyManager.generateEphemeral();
    final newId = await NyxId.derive(
      signingPublicKey: fresh.signingPublicKey,
      identityPublicKey: fresh.identityPublicKey,
    );
    final statement = await KeyTransition.create(
      oldKeys: _keyManager, oldId: current.nyxChatId, newKeys: fresh, newId: newId,
    );
    return PendingRotation(fresh, newId, statement);
  }

  /// Step 2: persist the new keys and profile. The app must restart
  /// afterwards so that every service picks up the new handle.
  Future<void> commitRotation(PendingRotation r) async {
    final current = _identity;
    if (current == null) throw StateError('no identity');
    await _keyManager.replaceWith(r.keys);
    _identity = await _buildIdentity(current.displayName);
    await _storage.saveUserIdentity(_identity!);
    notifyListeners();
    debugPrint('[Identity] rotated ${current.nyxChatId} -> ${r.newId}');
  }

  /// Forget the identity (panic wipe).
  Future<void> destroy() async {
    await _keyManager.clearKeys();
    await _secure.delete(key: _kDisplayName);
    _identity = null;
    notifyListeners();
  }
}