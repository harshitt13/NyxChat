import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyxchat/core/crypto/crypto_utils.dart';
import 'package:nyxchat/core/crypto/handshake.dart';
import 'package:nyxchat/core/crypto/key_manager.dart';
import 'package:nyxchat/core/crypto/nyx_id.dart';
import 'package:nyxchat/core/crypto/sender_keys.dart';
import 'package:nyxchat/core/crypto/session_manager.dart';
import 'package:nyxchat/core/protocol/envelope.dart';
import 'package:nyxchat/core/protocol/inner_message.dart';
import 'package:nyxchat/core/storage/key_value_store.dart';
import 'package:nyxchat/core/storage/trust_store.dart';

class _Party {
  final KeyManager keys;
  final String id;
  final MemoryKeyValueStore store = MemoryKeyValueStore();
  late final SessionManager sessions =
      SessionManager(keys: keys, store: store, myId: id);
  _Party(this.keys, this.id);

  static Future<_Party> create() async {
    final keys = await KeyManager.generateEphemeral();
    final id = await NyxId.derive(
        signingPublicKey: keys.signingPublicKey,
        identityPublicKey: keys.identityPublicKey);
    return _Party(keys, id);
  }

  PinnedPeer pinned() => PinnedPeer(
        nyxChatId: id,
        displayName: id,
        identityKey: keys.identityPublicKey,
        signingKey: keys.signingPublicKey,
        kyberPublicKey: keys.kyberPublicKey,
        verified: true,
        firstSeen: DateTime.now(),
        lastSeen: DateTime.now(),
      );
}

Envelope _wire(Envelope e) =>
    Envelope.fromJson(jsonDecode(e.encode()) as Map<String, dynamic>);

Future<void> _handshake(_Party a, _Party b) async {
  final st = await Handshake.createInitiatorHello(
      keys: a.keys, nyxChatId: a.id, displayName: 'A', listeningPort: 1);
  final (resp, bRes) = await Handshake.respond(
      keys: b.keys, nyxChatId: b.id, displayName: 'B', listeningPort: 1,
      initiatorHello: st.hello);
  final aRes = await Handshake.completeInitiator(
      keys: a.keys, state: st, response: resp);
  await a.sessions.establishFromHandshake(aRes);
  await b.sessions.establishFromHandshake(bRes);
}

void main() {
  group('SessionManager (direct handshake)', () {
    test('initiator opens, responder replies, both persist', () async {
      final a = await _Party.create();
      final b = await _Party.create();
      await _handshake(a, b);
      expect(a.sessions.canSend(b.id), isTrue);
      expect(b.sessions.canSend(a.id), isFalse);
      await expectLater(
          b.sessions.encrypt(
              peerId: a.id, message: InnerMessage.sessionOpen(id: 'x')),
          throwsA(isA<SessionNotReadyException>()));

      final open = await a.sessions.encrypt(
          peerId: b.id, message: InnerMessage.sessionOpen(id: 'open1'));
      final got = await b.sessions.decrypt(_wire(open));
      expect(got.type, InnerMessage.typeSessionOpen);
      expect(b.sessions.canSend(a.id), isTrue);

      final reply = await b.sessions.encrypt(
          peerId: a.id, message: InnerMessage.text(id: 'm1', text: 'hello'));
      expect((await a.sessions.decrypt(_wire(reply))).text, 'hello');

      // Reload both from their stores and continue the conversation.
      final a2 = SessionManager(keys: a.keys, store: a.store, myId: a.id);
      await a2.load();
      final b2 = SessionManager(keys: b.keys, store: b.store, myId: b.id);
      await b2.load();
      final m = await a2.encrypt(
          peerId: b.id, message: InnerMessage.text(id: 'm2', text: 'again'));
      expect((await b2.decrypt(_wire(m))).text, 'again');
    });

    test('second handshake keeps existing session unless forced', () async {
      final a = await _Party.create();
      final b = await _Party.create();
      await _handshake(a, b);
      final before = a.sessions.record(b.id)!.createdAt;
      await _handshake(a, b);
      expect(a.sessions.record(b.id)!.createdAt, before);
    });

    test('envelope re-addressing is rejected via associated data', () async {
      final a = await _Party.create();
      final b = await _Party.create();
      await _handshake(a, b);
      final e = await a.sessions.encrypt(
          peerId: b.id, message: InnerMessage.text(id: '1', text: 'x'));
      final json = e.toJson();
      json['from'] = 'NC-0000000000000000';
      await expectLater(
          b.sessions.decrypt(Envelope.fromJson(json), pinned: a.pinned()),
          throwsA(anything));
    });
  });

  group('SessionManager (async / mesh)', () {
    test('initiator with pinned keys, responder bootstraps from init', () async {
      final a = await _Party.create();
      final b = await _Party.create();
      final e1 = await a.sessions.encrypt(
          peerId: b.id,
          message: InnerMessage.text(id: '1', text: 'via mesh'),
          pinned: b.pinned());
      expect(e1.init, isNotNull);
      final e2 = await a.sessions.encrypt(
          peerId: b.id,
          message: InnerMessage.text(id: '2', text: 'second'),
          pinned: b.pinned());
      expect(e2.init, isNotNull); // still pending until B answers

      // Without pinned keys B cannot bootstrap.
      await expectLater(b.sessions.decrypt(_wire(e1)),
          throwsA(isA<NoSessionException>()));

      expect((await b.sessions.decrypt(_wire(e1), pinned: a.pinned())).text,
          'via mesh');
      expect((await b.sessions.decrypt(_wire(e2), pinned: a.pinned())).text,
          'second');

      final r = await b.sessions.encrypt(
          peerId: a.id, message: InnerMessage.text(id: '3', text: 'back'));
      expect((await a.sessions.decrypt(_wire(r))).text, 'back');
      // A heard back: init no longer attached.
      final e3 = await a.sessions.encrypt(
          peerId: b.id, message: InnerMessage.text(id: '4', text: 'done'));
      expect(e3.init, isNull);
      expect((await b.sessions.decrypt(_wire(e3))).text, 'done');
    });

    test('simultaneous initiation resolves by id order', () async {
      final p1 = await _Party.create();
      final p2 = await _Party.create();
      final small = p1.id.compareTo(p2.id) < 0 ? p1 : p2;
      final large = small == p1 ? p2 : p1;

      final fromSmall = await small.sessions.encrypt(
          peerId: large.id,
          message: InnerMessage.text(id: 's', text: 'from small'),
          pinned: large.pinned());
      final fromLarge = await large.sessions.encrypt(
          peerId: small.id,
          message: InnerMessage.text(id: 'l', text: 'from large'),
          pinned: small.pinned());

      // Small wins: ignores large's init.
      await expectLater(
          small.sessions.decrypt(_wire(fromLarge), pinned: large.pinned()),
          throwsA(isA<SessionCollisionException>()));
      // Large adopts small's session.
      expect(
          (await large.sessions.decrypt(_wire(fromSmall), pinned: small.pinned()))
              .text,
          'from small');
      // Large resends its message on the adopted session.
      final resend = await large.sessions.encrypt(
          peerId: small.id, message: InnerMessage.text(id: 'l2', text: 'again'));
      expect((await small.sessions.decrypt(_wire(resend))).text, 'again');
    });

    test('peer that lost its session is re-bootstrapped', () async {
      final a = await _Party.create();
      final b = await _Party.create();
      await _handshake(a, b);
      final open = await a.sessions.encrypt(
          peerId: b.id, message: InnerMessage.sessionOpen(id: 'o'));
      await b.sessions.decrypt(_wire(open));
      // B loses everything.
      await b.sessions.clearAll();
      // A also lost/reset and starts an async session using pinned keys.
      await a.sessions.reset(b.id);
      final e = await a.sessions.encrypt(
          peerId: b.id,
          message: InnerMessage.text(id: '1', text: 'fresh'),
          pinned: b.pinned());
      expect((await b.sessions.decrypt(_wire(e), pinned: a.pinned())).text,
          'fresh');
    });
  });

  group('SenderKeyManager', () {
    test('distribution, ordered and out-of-order decryption, signature', () async {
      final alice = SenderKeyManager();
      final bob = SenderKeyManager();
      const g = 'group-1';
      final dist = await alice.ownDistribution(g);
      bob.processDistribution('alice', SenderKeyDistribution.fromJson(
          jsonDecode(jsonEncode(dist.toJson())) as Map<String, dynamic>));

      final ad = Envelope.associatedDataFor('alice', g, EnvelopeKind.senderKey);
      final m0 = await alice.encrypt(g, [0], ad);
      final m1 = await alice.encrypt(g, [1], ad);
      final m2 = await alice.encrypt(g, [2], ad);
      expect(await bob.decrypt(groupId: g, senderId: 'alice', message: m2, associatedData: ad), [2]);
      expect(await bob.decrypt(groupId: g, senderId: 'alice', message: m0, associatedData: ad), [0]);
      expect(await bob.decrypt(groupId: g, senderId: 'alice', message: m1, associatedData: ad), [1]);
      // Replay
      await expectLater(
          bob.decrypt(groupId: g, senderId: 'alice', message: m1, associatedData: ad),
          throwsA(isA<SenderKeyException>()));
      // Forged signature
      final m3 = await alice.encrypt(g, [3], ad);
      final badSig = SenderKeyMessage(m3.iteration, m3.ciphertext,
          CryptoUtils.randomBytes(64));
      await expectLater(
          bob.decrypt(groupId: g, senderId: 'alice', message: badSig, associatedData: ad),
          throwsA(isA<SenderKeyException>()));
      expect(await bob.decrypt(groupId: g, senderId: 'alice', message: m3, associatedData: ad), [3]);
    });

    test('rotation invalidates old chain and state persists', () async {
      final alice = SenderKeyManager();
      final bob = SenderKeyManager();
      const g = 'g';
      bob.processDistribution('alice', await alice.ownDistribution(g));
      final ad = <int>[];
      await alice.encrypt(g, [1], ad);
      final rotated = await alice.rotateOwn(g);
      final m = await alice.encrypt(g, [2], ad);
      await expectLater(
          bob.decrypt(groupId: g, senderId: 'alice', message: m, associatedData: ad),
          throwsA(isA<SenderKeyException>()));
      bob.processDistribution('alice', rotated);
      expect(await bob.decrypt(groupId: g, senderId: 'alice', message: m, associatedData: ad), [2]);

      final bob2 = SenderKeyManager()
        ..loadJson(jsonDecode(jsonEncode(bob.toJson())) as Map<String, dynamic>);
      final alice2 = SenderKeyManager()
        ..loadJson(jsonDecode(jsonEncode(alice.toJson())) as Map<String, dynamic>);
      final m2 = await alice2.encrypt(g, [3], ad);
      expect(await bob2.decrypt(groupId: g, senderId: 'alice', message: m2, associatedData: ad), [3]);
    });
  });

  group('Envelope / InnerMessage', () {
    test('inner message round trip and limits', () {
      final m = InnerMessage.text(id: 'abc', text: 'hi', replyToId: 'r');
      final back = InnerMessage.fromBytes(m.toBytes());
      expect(back.text, 'hi');
      expect(back.body['replyTo'], 'r');
      expect(() => InnerMessage.fromJson({'t': '', 'id': 'x', 'ts': 'now', 'b': {}}),
          throwsFormatException);
    });

    test('envelope rejects bad versions and kinds', () {
      expect(() => Envelope.fromJson({'v': 2}), throwsFormatException);
      expect(
          () => Envelope.fromJson({
                'v': 3, 'from': 'a', 'to': 'b', 'k': 'zz',
                'c': base64Encode(List.filled(20, 0)),
              }),
          throwsFormatException);
    });
  });
}