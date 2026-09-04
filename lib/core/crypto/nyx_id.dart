import 'dart:typed_data';

import 'crypto_utils.dart';

/// NyxChat identifiers, fingerprints and safety numbers.
///
/// A NyxChat ID is a short routing handle. Trust is never based on the
/// handle alone: peers pin the full identity keys (see TrustStore) and can
/// compare safety numbers out of band. The v3 handle is derived from both
/// long-term public keys so that a peer can check the binding cheaply.
class NyxId {
  NyxId._();

  static const String prefix = 'NC-';
  static const String _idInfo = 'NyxChat-ID-v3';

  static final RegExp _modern = RegExp(r'^NC-[0-9A-F]{16}$');
  static final RegExp _legacy = RegExp(r'^NC-[0-9A-F]{4}\.\.\.[0-9A-F]{4}$');

  /// Derive the v3 handle: NC- + first 64 bits of
  /// SHA-256("NyxChat-ID-v3" || signingKey || identityKey), upper-case hex.
  static Future<String> derive({
    required List<int> signingPublicKey,
    required List<int> identityPublicKey,
  }) async {
    final digest = await CryptoUtils.sha256(CryptoUtils.lengthPrefixed([
      _idInfo.codeUnits,
      signingPublicKey,
      identityPublicKey,
    ]));
    return prefix + CryptoUtils.toHex(digest.sublist(0, 8)).toUpperCase();
  }

  /// The pre-v3 handle: first and last four hex characters of the X25519 key.
  static String legacyDerive(String identityPublicKeyHex) {
    if (identityPublicKeyHex.length < 8) return '';
    final p = identityPublicKeyHex.substring(0, 4).toUpperCase();
    final s = identityPublicKeyHex
        .substring(identityPublicKeyHex.length - 4)
        .toUpperCase();
    return '$prefix$p...$s';
  }

  static bool isModern(String id) => _modern.hasMatch(id);
  static bool isLegacy(String id) => _legacy.hasMatch(id);
  static bool isValidFormat(String id) => isModern(id) || isLegacy(id);

  /// Verify that [id] is bound to the given public keys.
  static Future<bool> verify({
    required String id,
    required List<int> signingPublicKey,
    required List<int> identityPublicKey,
  }) async {
    if (isModern(id)) {
      final expected = await derive(
        signingPublicKey: signingPublicKey,
        identityPublicKey: identityPublicKey,
      );
      return expected == id;
    }
    if (isLegacy(id)) {
      return legacyDerive(CryptoUtils.toHex(identityPublicKey)) == id;
    }
    return false;
  }

  /// Compact display form, e.g. NC-1A2B...9F0E.
  static String shortForm(String id) {
    if (isModern(id)) {
      final body = id.substring(3);
      return '$prefix${body.substring(0, 4)}...${body.substring(12)}';
    }
    return id;
  }

  /// Full identity fingerprint: SHA-256(signingKey || identityKey).
  static Future<Uint8List> fingerprint({
    required List<int> signingPublicKey,
    required List<int> identityPublicKey,
  }) {
    return CryptoUtils.sha256(CryptoUtils.lengthPrefixed([
      'NyxChat-Fingerprint-v3'.codeUnits,
      signingPublicKey,
      identityPublicKey,
    ]));
  }

  /// Human-comparable 60-digit safety number for a pair of fingerprints.
  /// Symmetric: both parties compute the same string regardless of order.
  static Future<String> safetyNumber(
      Uint8List fingerprintA, Uint8List fingerprintB) async {
    final a = CryptoUtils.toHex(fingerprintA);
    final b = CryptoUtils.toHex(fingerprintB);
    final ordered = a.compareTo(b) <= 0 ? [fingerprintA, fingerprintB]
                                         : [fingerprintB, fingerprintA];
    // Stretch: 5120 iterations of SHA-256 to make brute forcing a matching
    // safety number for a chosen key more expensive (mirrors Signal's design).
    var digest = await CryptoUtils.sha256(
        CryptoUtils.concat([ordered[0], ordered[1]]));
    for (var i = 0; i < 5119; i++) {
      digest = await CryptoUtils.sha256(
          CryptoUtils.concat([digest, ordered[0], ordered[1]]));
    }
    final groups = <String>[];
    for (var i = 0; i < 12; i++) {
      final chunk = digest.sublist((i * 5) % 30, (i * 5) % 30 + 5);
      var value = 0;
      for (final byte in chunk) {
        value = (value * 256 + byte) % 100000;
      }
      groups.add(value.toString().padLeft(5, '0'));
    }
    return groups.join(' ');
  }

  /// Fingerprint formatted as 8 groups of 8 hex characters.
  static String formatFingerprint(Uint8List fingerprint) {
    final hex = CryptoUtils.toHex(fingerprint).toUpperCase();
    final parts = <String>[];
    for (var i = 0; i + 8 <= hex.length; i += 8) {
      parts.add(hex.substring(i, i + 8));
    }
    return parts.join(' ');
  }
}