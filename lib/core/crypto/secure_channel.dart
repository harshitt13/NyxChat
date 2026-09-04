import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../protocol/parse.dart';
import 'crypto_utils.dart';

/// Link-layer encryption for a single authenticated connection.
///
/// After the handshake both sides derive one key per direction from the
/// handshake master secret. Every wire frame (including metadata such as
/// message type, sender and timestamps) is sealed with AES-256-GCM under
/// a strictly increasing counter nonce, so an observer on the LAN sees only
/// opaque bytes and cannot replay or reorder frames.
///
/// This is separate from the end-to-end Double Ratchet: the link layer
/// protects a hop, the ratchet protects the message across any number of
/// hops (mesh relays, store-and-forward nodes, internet relays).
class SecureChannel {
  static const String _infoInitiatorToResponder = 'NyxChat-Link-i2r-v3';
  static const String _infoResponderToInitiator = 'NyxChat-Link-r2i-v3';
  static const int maxCounter = 0xFFFFFFFFFFFF; // 48-bit, rekey long before

  final Uint8List _sendKey;
  final Uint8List _recvKey;
  int _sendCounter = 0;
  int _recvCounter = 0;

  SecureChannel._(this._sendKey, this._recvKey);

  static Future<SecureChannel> fromMasterSecret({
    required List<int> masterSecret,
    required bool isInitiator,
  }) async {
    final i2r = await CryptoUtils.hkdf(
        ikm: masterSecret, info: _infoInitiatorToResponder);
    final r2i = await CryptoUtils.hkdf(
        ikm: masterSecret, info: _infoResponderToInitiator);
    return isInitiator ? SecureChannel._(i2r, r2i) : SecureChannel._(r2i, i2r);
  }

  int get framesSent => _sendCounter;
  int get framesReceived => _recvCounter;

  static Uint8List _nonce(int counter) =>
      CryptoUtils.concat([Uint8List(4), CryptoUtils.int64be(counter)]);

  /// Seal one line of plaintext. Returns a single JSON line (no newline).
  Future<String> seal(String plaintext) async {
    if (_sendCounter >= maxCounter) {
      throw StateError('secure channel counter exhausted');
    }
    final counter = _sendCounter++;
    final ct = await CryptoUtils.aesGcmEncrypt(
      key: _sendKey,
      nonce: _nonce(counter),
      plaintext: utf8.encode(plaintext),
      aad: CryptoUtils.int64be(counter),
    );
    return jsonEncode({'e': base64Encode(ct), 'c': counter});
  }

  /// Returns true if [line] looks like a sealed frame.
  static bool isSealedFrame(Map<String, dynamic> json) =>
      json.containsKey('e') && json.containsKey('c');

  /// Open a sealed frame. A malformed frame is a [FormatException]; a
  /// replayed, reordered or tampered frame is a [StateError] (the link is
  /// considered compromised). Nothing else escapes.
  Future<String> open(Map<String, dynamic> frame) async {
    final (counter, ciphertext) = parseOr(() {
      const ctx = 'sealed frame';
      final c = requireInt(frame, 'c', min: 0, max: maxCounter, context: ctx);
      final ct = requireBase64(frame, 'e', context: ctx);
      if (ct.length < CryptoUtils.aesGcmTagLength) {
        throw const FormatException('sealed frame too short');
      }
      return (c, ct);
    }, context: 'sealed frame');
    if (counter != _recvCounter) {
      throw StateError(
          'secure channel replay/reorder: expected $_recvCounter got $counter');
    }
    final Uint8List plain;
    try {
      plain = await CryptoUtils.aesGcmDecrypt(
        key: _recvKey,
        nonce: _nonce(counter),
        ciphertextWithTag: ciphertext,
        aad: CryptoUtils.int64be(counter),
      );
    } on SecretBoxAuthenticationError {
      throw StateError('secure channel authentication failed');
    }
    _recvCounter++;
    return utf8.decode(plain);
  }

  void dispose() {
    CryptoUtils.wipe(_sendKey);
    CryptoUtils.wipe(_recvKey);
  }
}