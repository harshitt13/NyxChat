import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyxchat/core/crypto/crypto_utils.dart';
import 'package:nyxchat/core/crypto/double_ratchet.dart';
import 'package:nyxchat/core/crypto/handshake.dart';
import 'package:nyxchat/core/crypto/key_manager.dart';
import 'package:nyxchat/core/crypto/nyx_id.dart';
import 'package:nyxchat/core/crypto/sender_keys.dart';
import 'package:nyxchat/core/network/dht_node.dart';
import 'package:nyxchat/core/network/file_transfer_manager.dart';
import 'package:nyxchat/core/network/message_protocol.dart';
import 'package:nyxchat/core/protocol/envelope.dart';
import 'package:nyxchat/core/protocol/inner_message.dart';
import 'package:nyxchat/core/storage/key_value_store.dart';
import 'package:nyxchat/core/storage/outbox.dart';
import 'package:nyxchat/core/storage/trust_store.dart';

import 'fuzz_support.dart';

bool _formatOrHandshake(Object e) =>
    e is FormatException || e is HandshakeException;

/// One parser under test: a valid object produced by the real constructors
/// and the parse function that must accept it and reject everything else
/// with an allowed exception.
class _Case {
  final Map<String, dynamic> valid;
  final FutureOr<void> Function(Map<String, dynamic> json) parse;
  final bool Function(Object error) allowed;
  _Case(this.valid, this.parse, {this.allowed = isFormat});
}

const List<String> _caseNames = [
  'HelloMessage.fromJson (initiator)',
  'HelloMessage.fromJson (response)',
  'Envelope.fromJson (ratchet)',
  'Envelope.fromJson (sender key)',
  'SessionInitBlock.fromJson',
  'InnerMessage.fromJson (text)',
  'InnerMessage.fromJson (file)',
  'ProtocolMessage.fromJson (envelope)',
  'ProtocolMessage.fromJson (dht announce)',
  'FileChunkFrame.fromJson',
  'FileDescriptor.fromInnerBody',
  'RatchetHeader.fromJson',
  'DoubleRatchetSession.fromJson',
  'SenderKeyDistribution.fromJson',
  'SenderKeyState.fromJson (own)',
  'SenderKeyState.fromJson (peer)',
  'PinnedPeer.fromJson',
  'TrustStore.pinFromContactCard',
  'OutboxItem.fromJson',
  'DHTEntry.fromJson',
  'DHTNode.validateAnnounce',
];

final Map<String, _Case> _cases = {};
late Map<String, dynamic> _ratchetEnvelopeJson;
late Map<String, dynamic> _innerJson;

Future<(KeyManager, String)> _identity() async {
  final keys = await KeyManager.generateEphemeral();
  final id = await NyxId.derive(
      signingPublicKey: keys.signingPublicKey,
      identityPublicKey: keys.identityPublicKey);
  return (keys, id);
}

/// Mirrors DHTNode's announce transcript so the fuzzer can start from an
/// announce that genuinely verifies.
Future<Map<String, dynamic>> _signedAnnounce(
    KeyManager keys, String id) async {
  final iat = DateTime.now().toUtc().millisecondsSinceEpoch;
  final sig = await keys.sign(CryptoUtils.lengthPrefixed([
    'NyxChat-DHT-Announce-v3'.codeUnits,
    utf8.encode(id),
    keys.identityPublicKey,
    keys.signingPublicKey,
    keys.kyberPublicKey,
    utf8.encode('Fuzz'),
    CryptoUtils.int32be(4444),
    CryptoUtils.int64be(iat),
  ]));
  return ProtocolMessage.dhtAnnounce(
    senderId: id,
    identityKeyHex: keys.identityPublicKeyHex,
    signingKeyHex: keys.signingPublicKeyHex,
    kyberKeyHex: keys.kyberPublicKeyHex,
    displayName: 'Fuzz',
    port: 4444,
    issuedAtMs: iat,
    signatureHex: CryptoUtils.toHex(sig),
  ).payload;
}

Future<void> _buildCases() async {
  final (alice, aliceId) = await _identity();
  final (bob, bobId) = await _identity();

  // Handshake hellos: initiator, and the response carrying kct / pn.
  final st = await Handshake.createInitiatorHello(
      keys: alice,
      nyxChatId: aliceId,
      displayName: 'Alice',
      listeningPort: 4444,
      capabilities: const ['mesh', 'files']);
  final (resp, _) = await Handshake.respond(
      keys: bob,
      nyxChatId: bobId,
      displayName: 'Bob',
      listeningPort: 4445,
      initiatorHello: st.hello);
  _cases['HelloMessage.fromJson (initiator)'] = _Case(st.hello.toJson(), (m) {
    HelloMessage.fromJson(m);
  }, allowed: _formatOrHandshake);
  _cases['HelloMessage.fromJson (response)'] = _Case(resp.toJson(), (m) {
    HelloMessage.fromJson(m);
  }, allowed: _formatOrHandshake);

  // Double Ratchet: a real session (Bob holds skipped keys), a ratchet
  // message wrapped in an envelope with an async session-init block.
  final shared = CryptoUtils.randomBytes(32);
  final bobRatchet = await CryptoUtils.newX25519KeyPair();
  final a = await DoubleRatchetSession.initAlice(
      sharedSecret: shared,
      bobRatchetPublicKey: CryptoUtils.publicKeyBytes(bobRatchet));
  final b = await DoubleRatchetSession.initBob(
      sharedSecret: shared, bobRatchetKeyPair: bobRatchet);
  final inner = InnerMessage.text(
      id: 'msg-1',
      text: 'hello \u2713',
      replyToId: 'msg-0',
      disappearAfterSeconds: 60);
  _innerJson = inner.toJson();
  final ad = Envelope.associatedDataFor(aliceId, bobId, EnvelopeKind.ratchet);
  final m0 = await a.encrypt(inner.toBytes(), associatedData: ad);
  await a.encrypt([1], associatedData: ad);
  final m2 = await a.encrypt([2], associatedData: ad);
  expect(await b.decrypt(m2, associatedData: ad), [2]);
  final init = await Handshake.asyncInitiate(
      keys: alice,
      peerIdentityKey: bob.identityPublicKey,
      peerKyberPublicKey: bob.kyberPublicKey);
  final initBlock = SessionInitBlock(
      ephemeralKey: init.ephemeralPublicKey,
      kyberCiphertext: init.kyberCiphertext);
  final ratchetEnvelope =
      Envelope.ratchet(from: aliceId, to: bobId, message: m0, init: initBlock);
  _ratchetEnvelopeJson = ratchetEnvelope.toJson();
  _cases['Envelope.fromJson (ratchet)'] = _Case(_ratchetEnvelopeJson, (m) {
    Envelope.fromJson(m);
  });
  _cases['SessionInitBlock.fromJson'] = _Case(initBlock.toJson(), (m) {
    SessionInitBlock.fromJson(m);
  });
  _cases['RatchetHeader.fromJson'] = _Case(m0.header.toJson(), (m) {
    RatchetHeader.fromJson(m);
  });
  _cases['DoubleRatchetSession.fromJson'] = _Case(b.toJson(), (m) {
    DoubleRatchetSession.fromJson(m);
  });

  // Sender keys: own state (with signing key), distribution, peer state
  // and a group envelope.
  final skm = SenderKeyManager();
  final dist = await skm.ownDistribution('group-1');
  final groupAd =
      Envelope.associatedDataFor(aliceId, 'group-1', EnvelopeKind.senderKey);
  final skMsg = await skm.encrypt('group-1', inner.toBytes(), groupAd);
  final peerSkm = SenderKeyManager()..processDistribution(aliceId, dist);
  _cases['Envelope.fromJson (sender key)'] = _Case(
      Envelope.senderKey(
              from: aliceId,
              groupId: 'group-1',
              iteration: skMsg.iteration,
              ciphertext: skMsg.ciphertext,
              signature: skMsg.signature)
          .toJson(), (m) {
    Envelope.fromJson(m);
  });
  _cases['SenderKeyDistribution.fromJson'] = _Case(dist.toJson(), (m) {
    SenderKeyDistribution.fromJson(m);
  });
  _cases['SenderKeyState.fromJson (own)'] = _Case(
      (skm.toJson()['own'] as Map<String, dynamic>)['group-1']
          as Map<String, dynamic>, (m) {
    SenderKeyState.fromJson(m);
  });
  _cases['SenderKeyState.fromJson (peer)'] = _Case(
      (peerSkm.toJson()['peers'] as Map<String, dynamic>)['group-1|$aliceId']
          as Map<String, dynamic>, (m) {
    SenderKeyState.fromJson(m);
  });

  // Inner messages and file transfer.
  final fileKey = CryptoUtils.randomBytes(32);
  final fileNonce = CryptoUtils.randomBytes(8);
  final fileBytes = CryptoUtils.randomBytes(1000);
  final fileMsg = InnerMessage.file(
      id: 'msg-2',
      fileId: 'file-1',
      fileName: 'photo.jpg',
      mimeType: 'image/jpeg',
      fileSize: fileBytes.length,
      fileKey: fileKey,
      fileNonce: fileNonce,
      totalChunks: 1,
      chunkSize: FileTransferManager.chunkSize,
      sha256Hex: CryptoUtils.toHex(await CryptoUtils.sha256(fileBytes)),
      caption: 'look');
  _cases['InnerMessage.fromJson (text)'] = _Case(_innerJson, (m) {
    InnerMessage.fromJson(m);
  });
  _cases['InnerMessage.fromJson (file)'] = _Case(fileMsg.toJson(), (m) {
    InnerMessage.fromJson(m);
  });
  _cases['FileDescriptor.fromInnerBody'] = _Case(fileMsg.body, (m) {
    FileDescriptor.fromInnerBody(m);
  });
  final chunkCiphertext = await CryptoUtils.aesGcmEncrypt(
      key: fileKey,
      nonce: FileTransferManager.chunkNonce(fileNonce, 0),
      plaintext: fileBytes,
      aad: FileTransferManager.chunkAad('file-1', 0, 1));
  _cases['FileChunkFrame.fromJson'] =
      _Case(FileChunkFrame('file-1', 0, 1, chunkCiphertext).toJson(), (m) {
    FileChunkFrame.fromJson(m);
  });

  // Link frames and DHT.
  _cases['ProtocolMessage.fromJson (envelope)'] =
      _Case(ProtocolMessage.envelope(ratchetEnvelope).toJson(), (m) {
    ProtocolMessage.fromJson(m);
  });
  final announce = await _signedAnnounce(bob, bobId);
  _cases['ProtocolMessage.fromJson (dht announce)'] = _Case(
      ProtocolMessage(type: ProtocolMessageType.dhtAnnounce, payload: announce)
          .toJson(), (m) {
    ProtocolMessage.fromJson(m);
  });
  _cases['DHTNode.validateAnnounce'] = _Case(announce, (m) async {
    await DHTNode.validateAnnounce(m, '10.0.0.2');
  }, allowed: (_) => false);
  final now = DateTime.now().toUtc();
  _cases['DHTEntry.fromJson'] = _Case(
      DHTEntry(
              nodeId: bobId,
              address: '10.0.0.2',
              port: 4444,
              dhtPort: 4445,
              identityKeyHex: bob.identityPublicKeyHex,
              signingKeyHex: bob.signingPublicKeyHex,
              kyberKeyHex: bob.kyberPublicKeyHex,
              displayName: 'Bob',
              lastSeen: now)
          .toJson(), (m) {
    DHTEntry.fromJson(m);
  });

  // Storage.
  final pinned = PinnedPeer(
      nyxChatId: bobId,
      displayName: 'Bob',
      identityKey: bob.identityPublicKey,
      signingKey: bob.signingPublicKey,
      kyberPublicKey: bob.kyberPublicKey,
      verified: true,
      firstSeen: now,
      lastSeen: now,
      keyChangedAt: now);
  _cases['PinnedPeer.fromJson'] = _Case(pinned.toJson(), (m) {
    PinnedPeer.fromJson(m);
  });
  _cases['TrustStore.pinFromContactCard'] =
      _Case(pinned.toContactCard(), (m) async {
    await TrustStore(MemoryKeyValueStore()).pinFromContactCard(m);
  });
  _cases['OutboxItem.fromJson'] =
      _Case(OutboxItem.inner(peerId: bobId, message: inner).toJson(), (m) {
    OutboxItem.fromJson(m);
  });
}

void main() {
  final seed = fuzzSeed();
  setUpAll(_buildCases);

  test('every listed parser has a case', () {
    expect(_cases.keys.toSet(), _caseNames.toSet());
  });

  for (final name in _caseNames) {
    test(name, () async {
      printOnFailure('FUZZ_SEED=$seed');
      final c = _cases[name]!;
      final f = Fuzzer(seed);
      // The genuine object parses.
      await c.parse(c.valid);
      await runFuzz<Map<String, dynamic>>('$name/random', f,
          iterations: kRandomIterations,
          gen: (_) => f.randomJsonMap(),
          parse: c.parse,
          allowed: c.allowed);
      await runFuzz<Map<String, dynamic>>('$name/mutation', f,
          iterations: kMutationIterations,
          gen: (i) {
            final m = f.mutate(c.valid);
            // Odd iterations go through JSON, as they would on the wire.
            return i.isOdd ? f.deepCopy(m) : m;
          },
          parse: c.parse,
          allowed: c.allowed);
      // Nothing above corrupted shared state: it still parses afterwards.
      await c.parse(c.valid);
    });
  }

  test('DHTNode.validateAnnounce accepts the genuine announce only', () async {
    final c = _cases['DHTNode.validateAnnounce']!;
    expect(await DHTNode.validateAnnounce(c.valid, '10.0.0.2'), isNotNull);
    final unsigned = Fuzzer(seed).deepCopy(c.valid)..remove('sig');
    expect(await DHTNode.validateAnnounce(unsigned, '10.0.0.2'), isNull);
    final renamed = Fuzzer(seed).deepCopy(c.valid)..['displayName'] = 'Eve';
    expect(await DHTNode.validateAnnounce(renamed, '10.0.0.2'), isNull);
  });

  group('wire decoders', () {
    test('Envelope.decode / Envelope.fromBytes', () async {
      printOnFailure('FUZZ_SEED=$seed');
      final f = Fuzzer(seed);
      final env = Envelope.fromJson(_ratchetEnvelopeJson);
      final text = env.encode();
      final bytes = env.toBytes();
      expect(Envelope.decode(text).from, env.from);
      expect(Envelope.fromBytes(bytes).to, env.to);
      await runFuzz<String>('Envelope.decode/random', f,
          iterations: kRandomIterations,
          gen: (i) => i.isEven ? f.randomString(max: 512) : f.jsonish(),
          parse: (s) {
            Envelope.decode(s);
          },
          allowed: isFormat);
      await runFuzz<Uint8List>('Envelope.fromBytes/random', f,
          iterations: kRandomIterations,
          gen: (i) => i.isEven ? f.randomBytes(max: 2048) : f.flipBytes(bytes),
          parse: (b) {
            Envelope.fromBytes(b);
          },
          allowed: isFormat);
      await runFuzz<String>('Envelope.decode/mutation', f,
          iterations: kMutationIterations,
          gen: (_) => jsonEncode(f.mutate(_ratchetEnvelopeJson)),
          parse: (s) {
            Envelope.decode(s);
          },
          allowed: isFormat);
      expect(() => Envelope.decode('{' * (Envelope.maxEncodedBytes + 1)),
          throwsFormatException);
      expect(() => Envelope.fromBytes(Uint8List(Envelope.maxEncodedBytes + 1)),
          throwsFormatException);
    });

    test('InnerMessage.fromBytes', () async {
      printOnFailure('FUZZ_SEED=$seed');
      final f = Fuzzer(seed);
      final original = InnerMessage.fromJson(_innerJson);
      final bytes = original.toBytes();
      expect(InnerMessage.fromBytes(bytes).text, original.text);
      await runFuzz<Uint8List>('InnerMessage.fromBytes/random', f,
          iterations: kRandomIterations,
          gen: (i) => i.isEven
              ? f.randomBytes(max: 2048)
              : Uint8List.fromList(utf8.encode(f.jsonish())),
          parse: (b) {
            InnerMessage.fromBytes(b);
          },
          allowed: isFormat);
      await runFuzz<Uint8List>('InnerMessage.fromBytes/mutation', f,
          iterations: kMutationIterations,
          gen: (i) => i % 3 == 0
              ? f.flipBytes(bytes)
              : Uint8List.fromList(
                  utf8.encode(jsonEncode(f.mutate(_innerJson)))),
          parse: (b) {
            InnerMessage.fromBytes(b);
          },
          allowed: isFormat);
      expect(
          () => InnerMessage.fromBytes(
              Uint8List(InnerMessage.maxEncodedBytes + 1)),
          throwsFormatException);
    });

    test('ProtocolMessage.decode', () async {
      printOnFailure('FUZZ_SEED=$seed');
      final f = Fuzzer(seed);
      final frame =
          ProtocolMessage.envelope(Envelope.fromJson(_ratchetEnvelopeJson));
      final line = frame.encode();
      final lineBytes = Uint8List.fromList(utf8.encode(line));
      expect(ProtocolMessage.decode(line).type, ProtocolMessageType.envelope);
      await runFuzz<String>('ProtocolMessage.decode/random', f,
          iterations: kRandomIterations,
          gen: (i) => i.isEven ? f.randomString(max: 512) : f.jsonish(),
          parse: (s) {
            ProtocolMessage.decode(s);
          },
          allowed: isFormat);
      await runFuzz<String>('ProtocolMessage.decode/mutation', f,
          iterations: kMutationIterations,
          gen: (i) => i % 3 == 0
              ? utf8.decode(f.flipBytes(lineBytes), allowMalformed: true)
              : jsonEncode(f.mutate(frame.toJson())),
          parse: (s) {
            ProtocolMessage.decode(s);
          },
          allowed: isFormat);
      expect(
          () => ProtocolMessage.decode('[' * (ProtocolMessage.maxFrameBytes + 1)),
          throwsFormatException);
    });
  });
}
