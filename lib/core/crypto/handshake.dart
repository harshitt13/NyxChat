import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'crypto_utils.dart';
import 'hybrid_key_exchange.dart';
import 'key_manager.dart';
import 'nyx_id.dart';

class HandshakeException implements Exception {
  final String message;
  HandshakeException(this.message);
  @override
  String toString() => 'HandshakeException: $message';
}

/// Signed hello exchanged on every direct connection (protocol v3).
///
/// Both parties send one. The responder additionally echoes the initiator's
/// nonce (freshness / anti-replay) and includes the Kyber ciphertext for
/// the initiator's Kyber public key.
class HelloMessage {
  static const int protocolVersion = 3;
  static const int maxDisplayNameLength = 64;
  static const int maxCapabilities = 16;

  final String nyxChatId;
  final String displayName;
  final Uint8List identityKey;
  final Uint8List signingKey;
  final Uint8List kyberPublicKey;
  final Uint8List ephemeralKey;
  final Uint8List nonce;
  final int listeningPort;
  final List<String> capabilities;
  final Uint8List? kyberCiphertext;
  final Uint8List? peerNonce;
  final Uint8List signature;

  HelloMessage({
    required this.nyxChatId,
    required this.displayName,
    required this.identityKey,
    required this.signingKey,
    required this.kyberPublicKey,
    required this.ephemeralKey,
    required this.nonce,
    required this.listeningPort,
    required this.capabilities,
    required this.signature,
    this.kyberCiphertext,
    this.peerNonce,
  });

  bool get isResponse => peerNonce != null;

  /// Bytes covered by the Ed25519 signature.
  Uint8List transcript() => HelloMessage.transcriptFor(
        isResponse: isResponse,
        nyxChatId: nyxChatId,
        displayName: displayName,
        identityKey: identityKey,
        signingKey: signingKey,
        kyberPublicKey: kyberPublicKey,
        ephemeralKey: ephemeralKey,
        nonce: nonce,
        listeningPort: listeningPort,
        capabilities: capabilities,
        peerNonce: peerNonce,
        kyberCiphertext: kyberCiphertext,
      );

  static Uint8List transcriptFor({
    required bool isResponse,
    required String nyxChatId,
    required String displayName,
    required List<int> identityKey,
    required List<int> signingKey,
    required List<int> kyberPublicKey,
    required List<int> ephemeralKey,
    required List<int> nonce,
    required int listeningPort,
    required List<String> capabilities,
    List<int>? peerNonce,
    List<int>? kyberCiphertext,
  }) {
    return CryptoUtils.lengthPrefixed([
      'NyxChat-Hello-v3'.codeUnits,
      [isResponse ? 2 : 1],
      utf8.encode(nyxChatId),
      utf8.encode(displayName),
      identityKey,
      signingKey,
      kyberPublicKey,
      ephemeralKey,
      nonce,
      CryptoUtils.int32be(listeningPort),
      utf8.encode(capabilities.join(',')),
      peerNonce ?? const <int>[],
      kyberCiphertext ?? const <int>[],
    ]);
  }

  Map<String, dynamic> toJson() => {
        'v': protocolVersion,
        'id': nyxChatId,
        'name': displayName,
        'ik': CryptoUtils.toHex(identityKey),
        'sk': CryptoUtils.toHex(signingKey),
        'kpk': CryptoUtils.toHex(kyberPublicKey),
        'eph': CryptoUtils.toHex(ephemeralKey),
        'nonce': CryptoUtils.toHex(nonce),
        'port': listeningPort,
        'caps': capabilities,
        if (kyberCiphertext != null) 'kct': CryptoUtils.toHex(kyberCiphertext!),
        if (peerNonce != null) 'pn': CryptoUtils.toHex(peerNonce!),
        'sig': CryptoUtils.toHex(signature),
      };

  factory HelloMessage.fromJson(Map<String, dynamic> json) {
    if (json['v'] != protocolVersion) {
      throw HandshakeException('unsupported hello version ${json['v']}');
    }
    final id = json['id'];
    final name = json['name'];
    final port = json['port'];
    if (id is! String || !NyxId.isValidFormat(id)) {
      throw HandshakeException('malformed NyxChat ID');
    }
    if (name is! String || name.isEmpty || name.length > maxDisplayNameLength) {
      throw HandshakeException('malformed display name');
    }
    if (port is! int || port < 1 || port > 65535) {
      throw HandshakeException('malformed port');
    }
    final capsRaw = json['caps'];
    final caps = <String>[];
    if (capsRaw is List) {
      if (capsRaw.length > maxCapabilities) {
        throw HandshakeException('too many capabilities');
      }
      for (final c in capsRaw) {
        if (c is! String || c.length > 32 || c.contains(',')) {
          throw HandshakeException('malformed capability');
        }
        caps.add(c);
      }
    }
    String str(String key) {
      final v = json[key];
      if (v is! String) throw HandshakeException('missing field $key');
      return v;
    }
    return HelloMessage(
      nyxChatId: id,
      displayName: name,
      identityKey: CryptoUtils.decodeKey(
          str('ik'), CryptoUtils.x25519KeyLength, 'identity key'),
      signingKey: CryptoUtils.decodeKey(
          str('sk'), CryptoUtils.ed25519KeyLength, 'signing key'),
      kyberPublicKey: CryptoUtils.decodeKey(
          str('kpk'), CryptoUtils.kyber768PublicKeyLength, 'kyber key'),
      ephemeralKey: CryptoUtils.decodeKey(
          str('eph'), CryptoUtils.x25519KeyLength, 'ephemeral key'),
      nonce: CryptoUtils.decodeKey(
          str('nonce'), CryptoUtils.nonceLength, 'nonce'),
      listeningPort: port,
      capabilities: caps,
      kyberCiphertext: json['kct'] == null
          ? null
          : CryptoUtils.decodeKey(str('kct'),
              CryptoUtils.kyber768CiphertextLength, 'kyber ciphertext'),
      peerNonce: json['pn'] == null
          ? null
          : CryptoUtils.decodeKey(
              str('pn'), CryptoUtils.nonceLength, 'peer nonce'),
      signature: CryptoUtils.decodeKey(
          str('sig'), CryptoUtils.ed25519SignatureLength, 'signature'),
    );
  }
}

/// Everything a completed handshake yields.
class HandshakeResult {
  final String peerId;
  final String peerDisplayName;
  final Uint8List peerIdentityKey;
  final Uint8List peerSigningKey;
  final Uint8List peerKyberPublicKey;
  final Uint8List peerEphemeralKey;
  final SimpleKeyPairData myEphemeralKeyPair;
  final Uint8List masterSecret;
  final Uint8List ratchetRoot;
  final bool isInitiator;
  final int peerListeningPort;
  final List<String> peerCapabilities;

  HandshakeResult({
    required this.peerId,
    required this.peerDisplayName,
    required this.peerIdentityKey,
    required this.peerSigningKey,
    required this.peerKyberPublicKey,
    required this.peerEphemeralKey,
    required this.myEphemeralKeyPair,
    required this.masterSecret,
    required this.ratchetRoot,
    required this.isInitiator,
    required this.peerListeningPort,
    required this.peerCapabilities,
  });
}

/// State the initiator keeps between sending its hello and receiving the
/// response.
class InitiatorState {
  final SimpleKeyPairData ephemeral;
  final Uint8List nonce;
  final HelloMessage hello;
  InitiatorState(this.ephemeral, this.nonce, this.hello);
}

/// Result of starting an asynchronous (store-and-forward) session.
class AsyncSessionInit {
  final Uint8List ephemeralPublicKey;
  final Uint8List kyberCiphertext;
  final Uint8List ratchetRoot;
  AsyncSessionInit({
    required this.ephemeralPublicKey,
    required this.kyberCiphertext,
    required this.ratchetRoot,
  });
}

/// NyxChat v3 handshake: mutually authenticated, hybrid post-quantum,
/// forward secret.
///
/// Master secret (X3DH-style, both sides compute the same value):
///
///   dh1 = X25519(IK_me,  IK_peer)      authentication
///   dh2 = X25519(EK_A,   IK_B)         forward secrecy vs. IK_A compromise
///   dh3 = X25519(IK_A,   EK_B)         forward secrecy vs. IK_B compromise
///   dh4 = X25519(EK_A,   EK_B)         forward secrecy vs. both
///   kem = Kyber-768 shared secret      post-quantum confidentiality
///   master = HKDF(salt = nonce_A || nonce_B,
///                 ikm  = 0xFF*32 || dh1 || dh2 || dh3 || dh4 || kem,
///                 info = "NyxChat-Handshake-v3")
///
/// Both hellos are signed with the long-term Ed25519 key over a transcript
/// that includes every field; the responder also signs the initiator's
/// nonce, so a response cannot be replayed.
class Handshake {
  Handshake._();

  static const String _masterInfo = 'NyxChat-Handshake-v3';
  static const String _ratchetInfo = 'NyxChat-Ratchet-Root-v3';
  static const String _asyncInfo = 'NyxChat-Async-Session-v3';

  static Future<InitiatorState> createInitiatorHello({
    required KeyManager keys,
    required String nyxChatId,
    required String displayName,
    required int listeningPort,
    List<String> capabilities = const <String>[],
  }) async {
    final ephemeral = await CryptoUtils.newX25519KeyPair();
    final nonce = CryptoUtils.randomBytes(CryptoUtils.nonceLength);
    final hello = await _buildHello(
      keys: keys,
      nyxChatId: nyxChatId,
      displayName: displayName,
      listeningPort: listeningPort,
      capabilities: capabilities,
      ephemeral: ephemeral,
      nonce: nonce,
    );
    return InitiatorState(ephemeral, nonce, hello);
  }

  static Future<(HelloMessage, HandshakeResult)> respond({
    required KeyManager keys,
    required String nyxChatId,
    required String displayName,
    required int listeningPort,
    required HelloMessage initiatorHello,
    List<String> capabilities = const <String>[],
  }) async {
    await _verifyHello(initiatorHello, expectResponse: false);
    if (initiatorHello.nyxChatId == nyxChatId) {
      throw HandshakeException('peer claims our own identity');
    }
    final ephemeral = await CryptoUtils.newX25519KeyPair();
    final nonce = CryptoUtils.randomBytes(CryptoUtils.nonceLength);
    final kem = await KyberKem.encapsulate(initiatorHello.kyberPublicKey);

    final derived = await _derive(
      keys: keys,
      myEphemeral: ephemeral,
      peerIdentityKey: initiatorHello.identityKey,
      peerEphemeralKey: initiatorHello.ephemeralKey,
      kemSecret: kem.sharedSecret,
      isInitiator: false,
      initiatorNonce: initiatorHello.nonce,
      responderNonce: nonce,
    );
    CryptoUtils.wipe(kem.sharedSecret);

    final response = await _buildHello(
      keys: keys,
      nyxChatId: nyxChatId,
      displayName: displayName,
      listeningPort: listeningPort,
      capabilities: capabilities,
      ephemeral: ephemeral,
      nonce: nonce,
      peerNonce: initiatorHello.nonce,
      kyberCiphertext: kem.ciphertext,
    );

    return (
      response,
      HandshakeResult(
        peerId: initiatorHello.nyxChatId,
        peerDisplayName: initiatorHello.displayName,
        peerIdentityKey: initiatorHello.identityKey,
        peerSigningKey: initiatorHello.signingKey,
        peerKyberPublicKey: initiatorHello.kyberPublicKey,
        peerEphemeralKey: initiatorHello.ephemeralKey,
        myEphemeralKeyPair: ephemeral,
        masterSecret: derived.$1,
        ratchetRoot: derived.$2,
        isInitiator: false,
        peerListeningPort: initiatorHello.listeningPort,
        peerCapabilities: initiatorHello.capabilities,
      )
    );
  }

  static Future<HandshakeResult> completeInitiator({
    required KeyManager keys,
    required InitiatorState state,
    required HelloMessage response,
  }) async {
    await _verifyHello(response, expectResponse: true);
    if (!CryptoUtils.constantTimeEquals(response.peerNonce!, state.nonce)) {
      throw HandshakeException('response does not echo our nonce');
    }
    if (response.nyxChatId == state.hello.nyxChatId) {
      throw HandshakeException('peer claims our own identity');
    }
    final kemSecret = await KyberKem.decapsulate(
        response.kyberCiphertext!, keys.kyberKeyPair.privateKey);
    final derived = await _derive(
      keys: keys,
      myEphemeral: state.ephemeral,
      peerIdentityKey: response.identityKey,
      peerEphemeralKey: response.ephemeralKey,
      kemSecret: kemSecret,
      isInitiator: true,
      initiatorNonce: state.nonce,
      responderNonce: response.nonce,
    );
    CryptoUtils.wipe(kemSecret);
    return HandshakeResult(
      peerId: response.nyxChatId,
      peerDisplayName: response.displayName,
      peerIdentityKey: response.identityKey,
      peerSigningKey: response.signingKey,
      peerKyberPublicKey: response.kyberPublicKey,
      peerEphemeralKey: response.ephemeralKey,
      myEphemeralKeyPair: state.ephemeral,
      masterSecret: derived.$1,
      ratchetRoot: derived.$2,
      isInitiator: true,
      peerListeningPort: response.listeningPort,
      peerCapabilities: response.capabilities,
    );
  }

  // Asynchronous (store-and-forward) session establishment. Used when a
  // message must be sent through the mesh to a peer we are not directly
  // connected to but whose identity keys we have pinned.
  //
  //   dh1 = X25519(IK_A, IK_B), dh2 = X25519(EK_A, IK_B), kem = Kyber(KPK_B)
  //   root = HKDF(ikm = 0xFF*32 || dh1 || dh2 || kem, info = async)
  //
  // Bob uses his identity X25519 key pair as the initial ratchet key pair;
  // the Double Ratchet replaces it after his first reply.

  static Future<AsyncSessionInit> asyncInitiate({
    required KeyManager keys,
    required Uint8List peerIdentityKey,
    required Uint8List peerKyberPublicKey,
  }) async {
    final ephemeral = await CryptoUtils.newX25519KeyPair();
    final dh1 = await CryptoUtils.x25519(keys.identityKeyPair, peerIdentityKey);
    final dh2 = await CryptoUtils.x25519(ephemeral, peerIdentityKey);
    final kem = await KyberKem.encapsulate(peerKyberPublicKey);
    final root = await _asyncRoot(dh1, dh2, kem.sharedSecret);
    CryptoUtils.wipe(kem.sharedSecret);
    return AsyncSessionInit(
      ephemeralPublicKey: CryptoUtils.publicKeyBytes(ephemeral),
      kyberCiphertext: kem.ciphertext,
      ratchetRoot: root,
    );
  }

  static Future<Uint8List> asyncRespond({
    required KeyManager keys,
    required Uint8List peerIdentityKey,
    required Uint8List peerEphemeralKey,
    required Uint8List kyberCiphertext,
  }) async {
    final dh1 = await CryptoUtils.x25519(keys.identityKeyPair, peerIdentityKey);
    final dh2 = await CryptoUtils.x25519(keys.identityKeyPair, peerEphemeralKey);
    final kem = await KyberKem.decapsulate(
        kyberCiphertext, keys.kyberKeyPair.privateKey);
    final root = await _asyncRoot(dh1, dh2, kem);
    CryptoUtils.wipe(kem);
    return root;
  }

  static Future<Uint8List> _asyncRoot(
      Uint8List dh1, Uint8List dh2, Uint8List kem) {
    final ikm = CryptoUtils.concat([
      Uint8List.fromList(List.filled(32, 0xFF)),
      dh1,
      dh2,
      kem,
    ]);
    return CryptoUtils.hkdf(ikm: ikm, salt: Uint8List(32), info: _asyncInfo);
  }

  // Internals

  static Future<HelloMessage> _buildHello({
    required KeyManager keys,
    required String nyxChatId,
    required String displayName,
    required int listeningPort,
    required List<String> capabilities,
    required SimpleKeyPairData ephemeral,
    required Uint8List nonce,
    Uint8List? peerNonce,
    Uint8List? kyberCiphertext,
  }) async {
    final ephPub = CryptoUtils.publicKeyBytes(ephemeral);
    final transcript = HelloMessage.transcriptFor(
      isResponse: peerNonce != null,
      nyxChatId: nyxChatId,
      displayName: displayName,
      identityKey: keys.identityPublicKey,
      signingKey: keys.signingPublicKey,
      kyberPublicKey: keys.kyberPublicKey,
      ephemeralKey: ephPub,
      nonce: nonce,
      listeningPort: listeningPort,
      capabilities: capabilities,
      peerNonce: peerNonce,
      kyberCiphertext: kyberCiphertext,
    );
    final signature = await keys.sign(transcript);
    return HelloMessage(
      nyxChatId: nyxChatId,
      displayName: displayName,
      identityKey: keys.identityPublicKey,
      signingKey: keys.signingPublicKey,
      kyberPublicKey: keys.kyberPublicKey,
      ephemeralKey: ephPub,
      nonce: nonce,
      listeningPort: listeningPort,
      capabilities: capabilities,
      signature: signature,
      kyberCiphertext: kyberCiphertext,
      peerNonce: peerNonce,
    );
  }

  static Future<void> _verifyHello(HelloMessage hello,
      {required bool expectResponse}) async {
    if (hello.isResponse != expectResponse) {
      throw HandshakeException('unexpected hello role');
    }
    if (expectResponse && hello.kyberCiphertext == null) {
      throw HandshakeException('response lacks Kyber ciphertext');
    }
    final idOk = await NyxId.verify(
      id: hello.nyxChatId,
      signingPublicKey: hello.signingKey,
      identityPublicKey: hello.identityKey,
    );
    if (!idOk) {
      throw HandshakeException('NyxChat ID is not bound to the presented keys');
    }
    final sigOk = await CryptoUtils.ed25519Verify(
      publicKey: hello.signingKey,
      message: hello.transcript(),
      signature: hello.signature,
    );
    if (!sigOk) {
      throw HandshakeException('hello signature invalid');
    }
  }

  static Future<(Uint8List, Uint8List)> _derive({
    required KeyManager keys,
    required SimpleKeyPairData myEphemeral,
    required Uint8List peerIdentityKey,
    required Uint8List peerEphemeralKey,
    required Uint8List kemSecret,
    required bool isInitiator,
    required Uint8List initiatorNonce,
    required Uint8List responderNonce,
  }) async {
    final ik = keys.identityKeyPair;
    final dh1 = await CryptoUtils.x25519(ik, peerIdentityKey);
    final Uint8List dh2;
    final Uint8List dh3;
    if (isInitiator) {
      dh2 = await CryptoUtils.x25519(myEphemeral, peerIdentityKey);
      dh3 = await CryptoUtils.x25519(ik, peerEphemeralKey);
    } else {
      dh2 = await CryptoUtils.x25519(ik, peerEphemeralKey);
      dh3 = await CryptoUtils.x25519(myEphemeral, peerIdentityKey);
    }
    final dh4 = await CryptoUtils.x25519(myEphemeral, peerEphemeralKey);
    final ikm = CryptoUtils.concat([
      Uint8List.fromList(List.filled(32, 0xFF)),
      dh1,
      dh2,
      dh3,
      dh4,
      kemSecret,
    ]);
    final salt = CryptoUtils.concat([initiatorNonce, responderNonce]);
    final master =
        await CryptoUtils.hkdf(ikm: ikm, salt: salt, info: _masterInfo);
    final root = await CryptoUtils.hkdf(ikm: master, info: _ratchetInfo);
    for (final b in [dh1, dh2, dh3, dh4, ikm]) {
      CryptoUtils.wipe(b);
    }
    return (master, root);
  }
}