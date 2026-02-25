
import 'package:cryptography/cryptography.dart';
import 'package:convert/convert.dart';

/// Manages session keys for forward secrecy.
/// Rotates ephemeral X25519 key pairs per session so that
/// compromising one session key doesn't compromise past sessions.
class SessionKeyManager {
  final X25519 _keyExchange = X25519();


  // Current session state per peer
  final Map<String, _SessionState> _sessions = {};
  int _sessionCounter = 0;

  /// Get the current session for a peer, or create a new one
  Future<SessionInfo> getOrCreateSession(String peerId) async {
    if (!_sessions.containsKey(peerId)) {
      await _rotateSession(peerId);
    }
    final session = _sessions[peerId]!;
    return SessionInfo(
      sessionId: session.sessionId,
      sharedSecret: session.sharedSecret!,
      ourPublicKeyHex: session.ourPublicKeyHex,
    );
  }

  /// Rotate to a new ephemeral key pair for a peer
  Future<String> _rotateSession(String peerId) async {
    final newKeyPair = await _keyExchange.newKeyPair();
    final publicKey = await newKeyPair.extractPublicKey();
    final publicKeyHex = hex.encode(publicKey.bytes);

    _sessionCounter++;
    _sessions[peerId] = _SessionState(
      sessionId: _sessionCounter,
      ephemeralKeyPair: newKeyPair,
      ourPublicKeyHex: publicKeyHex,
    );

    return publicKeyHex;
  }

  /// Initiate a key rotation — generate new ephemeral keys
  Future<KeyRotationData> initiateKeyRotation(String peerId) async {
    final newPubKeyHex = await _rotateSession(peerId);
    final session = _sessions[peerId]!;
    return KeyRotationData(
      newPublicKeyHex: newPubKeyHex,
      sessionId: session.sessionId,
    );
  }

  /// Handle received key rotation from a peer
  Future<void> handleKeyRotation({
    required String peerId,
    required String newPeerPublicKeyHex,
    required int sessionId,
  }) async {
    final session = _sessions[peerId];
    if (session == null) {
      // Create a new session with our existing keys
      await _rotateSession(peerId);
    }

    final currentSession = _sessions[peerId]!;
    // Derive new shared secret with peer's new public key
    final peerPublicKey = SimplePublicKey(
      hex.decode(newPeerPublicKeyHex),
      type: KeyPairType.x25519,
    );

    final sharedSecret = await _keyExchange.sharedSecretKey(
      keyPair: currentSession.ephemeralKeyPair,
      remotePublicKey: peerPublicKey,
    );

    currentSession.sharedSecret = sharedSecret;
    currentSession.peerPublicKeyHex = newPeerPublicKeyHex;
  }

  /// Establish a session with a peer given their public key
  Future<void> establishSession({
    required String peerId,
    required String peerPublicKeyHex,
    required SimpleKeyPair ourIdentityKeyPair,
  }) async {
    if (!_sessions.containsKey(peerId)) {
      await _rotateSession(peerId);
    }

    final session = _sessions[peerId]!;
    final peerPublicKey = SimplePublicKey(
      hex.decode(peerPublicKeyHex),
      type: KeyPairType.x25519,
    );

    // Use ephemeral keys for the session
    final sharedSecret = await _keyExchange.sharedSecretKey(
      keyPair: session.ephemeralKeyPair,
      remotePublicKey: peerPublicKey,
    );

    session.sharedSecret = sharedSecret;
    session.peerPublicKeyHex = peerPublicKeyHex;
  }

  /// Get the shared secret for encrypting/decrypting messages
  SecretKey? getSessionSecret(String peerId) {
    return _sessions[peerId]?.sharedSecret;
  }

  /// Check if we have an active session with a peer
  bool hasSession(String peerId) {
    return _sessions.containsKey(peerId) &&
        _sessions[peerId]!.sharedSecret != null;
  }

  /// Get message count and check if rotation is needed
  bool shouldRotate(String peerId, {int threshold = 100}) {
    final session = _sessions[peerId];
    if (session == null) return false;
    session.messageCount++;
    return session.messageCount >= threshold;
  }

  /// Clear session for a peer
  void clearSession(String peerId) {
    _sessions.remove(peerId);
  }

  /// Clear all sessions
  void clearAll() {
    _sessions.clear();
  }
}

class _SessionState {
  final int sessionId;
  final SimpleKeyPair ephemeralKeyPair;
  final String ourPublicKeyHex;
  String? peerPublicKeyHex;
  SecretKey? sharedSecret;
  int messageCount = 0;

  _SessionState({
    required this.sessionId,
    required this.ephemeralKeyPair,
    required this.ourPublicKeyHex,
  });
}

class SessionInfo {
  final int sessionId;
  final SecretKey sharedSecret;
  final String ourPublicKeyHex;

  SessionInfo({
    required this.sessionId,
    required this.sharedSecret,
    required this.ourPublicKeyHex,
  });
}

class KeyRotationData {
  final String newPublicKeyHex;
  final int sessionId;

  KeyRotationData({
    required this.newPublicKeyHex,
    required this.sessionId,
  });
}
