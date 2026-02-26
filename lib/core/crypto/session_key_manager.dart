import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:convert/convert.dart';

/// Implements the Double Ratchet Algorithm for perfect forward/future secrecy.
/// Rotate keys deterministically on every single message via KDF chains,
/// and step the D-H ratchet whenever a new ephemeral public key is received.
class SessionKeyManager {
  final X25519 _keyExchange = X25519();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  // Current session state per peer
  final Map<String, _RatchetState> _sessions = {};

  /// Get the current message secret and step the SENDING ratchet forward
  Future<RatchetStepResult> getNextSendingKeyAndStep(String peerId) async {
    final state = _sessions[peerId];
    if (state == null) {
      throw StateError('Ratchet not initialized! Call establishSession first.');
    }
    
    // 1. Derive the MessageKey from current sending ChainKey
    final messageKeyBytes = await _hkdf.deriveKey(
      secretKey: state.sendingChainKey!,
      nonce: [0x01], // 1 for Message Key
    );
    final messageKey = SecretKey(await messageKeyBytes.extractBytes());

    // 2. Step the sending ChainKey forward
    final nextChainKeyBytes = await _hkdf.deriveKey(
      secretKey: state.sendingChainKey!,
      nonce: [0x02], // 2 for next Chain Key
    );
    state.sendingChainKey = SecretKey(await nextChainKeyBytes.extractBytes());

    return RatchetStepResult(
      messageKey: messageKey,
      dhPubKeyHex: state.ourDhPublicKeyHex,
    );
  }

  /// Get the message secret and step the RECEIVING ratchet forward
  /// Updates the DH Ratchet if a new public key is provided in the message.
  Future<SecretKey> getNextReceivingKeyAndStep({
    required String peerId,
    required String incomingDhPubKeyHex,
  }) async {
    final state = _sessions[peerId];
    if (state == null) {
      throw StateError('Ratchet not initialized for receiving! Call establishSession first.');
    }

    // DH Ratchet Step: Did they send a new Public Key?
    if (incomingDhPubKeyHex != state.peerDhPublicKeyHex) {
      // 1. Compute new Shared Secret using our CURRENT private key and THEIR NEW public key
      final peerPublicKey = SimplePublicKey(
        hex.decode(incomingDhPubKeyHex),
        type: KeyPairType.x25519,
      );
      final sharedSecret1 = await _keyExchange.sharedSecretKey(
        keyPair: state.ourDhKeyPair,
        remotePublicKey: peerPublicKey,
      );

      // 2. Derive new RootKey & ReceivingChainKey
      var newKeys = await _kdfRoot(state.rootKey, sharedSecret1);
      state.rootKey = newKeys[0];
      state.receivingChainKey = newKeys[1];

      // 3. Generate slightly newer Ephemeral KeyPair for OUR next messages
      state.ourDhKeyPair = await _keyExchange.newKeyPair();
      final ourNewPub = await state.ourDhKeyPair.extractPublicKey();
      state.ourDhPublicKeyHex = hex.encode(ourNewPub.bytes);
      state.peerDhPublicKeyHex = incomingDhPubKeyHex;

      // 4. Compute second Shared Secret using OUR NEW private key and THEIR NEW public key
      final sharedSecret2 = await _keyExchange.sharedSecretKey(
        keyPair: state.ourDhKeyPair,
        remotePublicKey: peerPublicKey,
      );

      // 5. Derive newer RootKey & SendingChainKey
      newKeys = await _kdfRoot(state.rootKey, sharedSecret2);
      state.rootKey = newKeys[0];
      state.sendingChainKey = newKeys[1];
    }

    // Symmetric Ratchet Step (Receiving)
    // 1. Derive the MessageKey from current receiving ChainKey
    final messageKeyBytes = await _hkdf.deriveKey(
      secretKey: state.receivingChainKey!,
      nonce: [0x01], 
    );
    final messageKey = SecretKey(await messageKeyBytes.extractBytes());

    // 2. Step the receiving ChainKey forward
    final nextChainKeyBytes = await _hkdf.deriveKey(
      secretKey: state.receivingChainKey!,
      nonce: [0x02], 
    );
    state.receivingChainKey = SecretKey(await nextChainKeyBytes.extractBytes());

    return messageKey;
  }

  /// Initialize Ratchet Root Key via static ECDH using Identity Keys.
  /// When [kyberSharedSecret] is provided, the root key is derived as
  /// HKDF(ECDH || Kyber) for post-quantum hybrid security.
  Future<void> establishSession({
    required String peerId,
    required String peerPublicKeyHex,
    required SimpleKeyPair ourIdentityKeyPair,
    Uint8List? kyberSharedSecret,
  }) async {
    if (_sessions.containsKey(peerId)) return;

    final peerPublicKey = SimplePublicKey(
      hex.decode(peerPublicKeyHex),
      type: KeyPairType.x25519,
    );
    
    final sharedSecret = await _keyExchange.sharedSecretKey(
      keyPair: ourIdentityKeyPair,
      remotePublicKey: peerPublicKey,
    );

    final Uint8List rootKeyBytes;
    if (kyberSharedSecret != null && kyberSharedSecret.isNotEmpty) {
      // Hybrid root key: HKDF(ECDH || Kyber)
      final ecdhBytes = Uint8List.fromList(await sharedSecret.extractBytes());
      final combined = Uint8List(ecdhBytes.length + kyberSharedSecret.length);
      combined.setRange(0, ecdhBytes.length, ecdhBytes);
      combined.setRange(ecdhBytes.length, combined.length, kyberSharedSecret);

      final derived = await _hkdf.deriveKey(
        secretKey: SecretKey(combined),
        nonce: 'NyxChat-Hybrid-Session-v1'.codeUnits,
      );
      rootKeyBytes = Uint8List.fromList(await derived.extractBytes());
    } else {
      // Classical ECDH-only root key (backward compatible)
      rootKeyBytes = Uint8List.fromList(await sharedSecret.extractBytes());
    }

    final newKeyPair = await _keyExchange.newKeyPair();
    final publicKeyHex = hex.encode((await newKeyPair.extractPublicKey()).bytes);

    _sessions[peerId] = _RatchetState(
      rootKey: SecretKey(rootKeyBytes),
      ourDhKeyPair: newKeyPair,
      ourDhPublicKeyHex: publicKeyHex,
      peerDhPublicKeyHex: peerPublicKeyHex, // fallback initial
      sendingChainKey: SecretKey(rootKeyBytes),
      receivingChainKey: SecretKey(rootKeyBytes),
    );
  }

  /// Root KDF - returns [NextRootKey, NextChainKey]
  Future<List<SecretKey>> _kdfRoot(SecretKey rootKey, SecretKey dhOut) async {
    final prk = await _hkdf.deriveKey(secretKey: rootKey, nonce: await dhOut.extractBytes());
    final out1 = await _hkdf.deriveKey(secretKey: SecretKey(await prk.extractBytes()), nonce: [0x01]);
    final out2 = await _hkdf.deriveKey(secretKey: SecretKey(await prk.extractBytes()), nonce: [0x02]);
    return [SecretKey(await out1.extractBytes()), SecretKey(await out2.extractBytes())];
  }

  bool hasSession(String peerId) => _sessions.containsKey(peerId);
  void clearSession(String peerId) => _sessions.remove(peerId);
  void clearAll() => _sessions.clear();
}

class _RatchetState {
  SecretKey rootKey;
  SimpleKeyPair ourDhKeyPair;
  String ourDhPublicKeyHex;
  String? peerDhPublicKeyHex;
  SecretKey? sendingChainKey;
  SecretKey? receivingChainKey;

  _RatchetState({
    required this.rootKey,
    required this.ourDhKeyPair,
    required this.ourDhPublicKeyHex,
    this.peerDhPublicKeyHex,
    required this.sendingChainKey,
    required this.receivingChainKey,
  });
}

class RatchetStepResult {
  final SecretKey messageKey;
  final String dhPubKeyHex;

  RatchetStepResult({
    required this.messageKey,
    required this.dhPubKeyHex,
  });
}
