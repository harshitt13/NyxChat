// One-time ML-KEM prekeys for asynchronous sessions: the store, the signed
// bundle and notice, the handshake variants and their KDF separation, and
// the SessionManager paths that consume, delete, fall back and report.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyxchat/core/crypto/crypto_utils.dart';
import 'package:nyxchat/core/crypto/handshake.dart';
import 'package:nyxchat/core/crypto/hybrid_key_exchange.dart';
import 'package:nyxchat/core/crypto/key_manager.dart';
import 'package:nyxchat/core/crypto/nyx_id.dart';
import 'package:nyxchat/core/crypto/prekey_bundle.dart';
import 'package:nyxchat/core/crypto/prekey_store.dart';
import 'package:nyxchat/core/crypto/session_manager.dart';
import 'package:nyxchat/core/protocol/envelope.dart';
import 'package:nyxchat/core/protocol/inner_message.dart';
import 'package:nyxchat/core/storage/key_value_store.dart';
import 'package:nyxchat/core/storage/trust_store.dart';

/// Adjustable clock shared by every store in a test.
class _Clock {
  DateTime now = DateTime.utc(2026, 9, 1, 12);
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

class _Party {
  final KeyManager keys;
  final String id;
  final _Clock clock;
  final MemoryKeyValueStore sessionStore = MemoryKeyValueStore();
  final MemoryKeyValueStore prekeyStoreBacking = MemoryKeyValueStore();
  late final PrekeyStore prekeys =
      PrekeyStore(prekeyStoreBacking, clock: clock.call);
  late final SessionManager sessions = SessionManager(
      keys: keys, store: sessionStore, myId: id, prekeys: prekeys);
  _Party(this.keys, this.id, this.clock);

  static Future<_Party> create(_Clock clock) async {
    final keys = await KeyManager.generateEphemeral();
    final id = await NyxId.derive(
        signingPublicKey: keys.signingPublicKey,
        identityPublicKey: keys.identityPublicKey);
    return _Party(keys, id, clock);
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

/// [issuer] tops up its pool for [holder] and hands it over as a signed
/// bundle, verified by [holder] exactly as PrekeyExchange does after a
/// handshake. Returns the bundle as parsed from the wire.
Future<PrekeyBundle> _issue(_Party issuer, _Party holder,
    {DateTime? at}) async {
  await issuer.prekeys.replenish(holder.id);
  final pool = issuer.prekeys
      .outstanding(holder.id)
      .map((k) => PublicPrekey(id: k.id, publicKey: k.publicKey))
      .toList();
  final bundle = await PrekeyBundle.create(
      keys: issuer.keys,
      from: issuer.id,
      to: holder.id,
      prekeys: pool,
      issuedAt: at ?? issuer.clock.now);
  final wire = PrekeyBundle.fromJson(
      jsonDecode(jsonEncode(bundle.toJson())) as Map<String, dynamic>);
  final problem = await wire.validate(
      pinnedSigningKey: issuer.keys.signingPublicKey,
      myId: holder.id,
      fromId: issuer.id,
      lastIssuedAtMs: holder.prekeys.lastBundleIssuedAt(issuer.id),
      now: holder.clock.now);
  expect(problem, isNull);
  await holder.prekeys.replacePeerBundle(issuer.id,
      keys: [
        for (final k in wire.keys)
          PeerPrekey(id: k.id, publicKey: k.publicKey, receivedAt: holder.clock.now)
      ],
      issuedAtMs: wire.issuedAtMs);
  return wire;
}

void main() {
  group('PrekeyStore', () {
    test('issues a pool with SHA-256 ids, persists and reloads', () async {
      final clock = _Clock();
      final b = await _Party.create(clock);
      const peer = 'NC-0000000000000001';
      final fresh = await b.prekeys.replenish(peer);
      expect(fresh.length, PrekeyStore.poolSize);
      expect(b.prekeys.outstanding(peer).length, PrekeyStore.poolSize);
      for (final k in fresh) {
        expect(k.id, hasLength(16));
        expect(k.id, await PrekeyStore.idHexFor(k.publicKey));
        expect(k.privateKey.length, CryptoUtils.kyber768PrivateKeyLength);
      }
      expect(fresh.map((k) => k.id).toSet().length, PrekeyStore.poolSize);
      // Already full: nothing new.
      expect(await b.prekeys.replenish(peer), isEmpty);
      // Reload from the backing store.
      final again = PrekeyStore(b.prekeyStoreBacking, clock: clock.call);
      await again.load();
      expect(again.outstanding(peer).map((k) => k.id).toSet(),
          fresh.map((k) => k.id).toSet());
      expect(again.findOwn(peer, fresh.first.id)!.privateKey,
          fresh.first.privateKey);
    });

    test('consume deletes the private half; unknown ids stay unknown', () async {
      final clock = _Clock();
      final b = await _Party.create(clock);
      const peer = 'NC-0000000000000001';
      const other = 'NC-0000000000000002';
      final fresh = await b.prekeys.replenish(peer);
      final id = fresh[3].id;
      expect(b.prekeys.findOwn(peer, id), isNotNull);
      // A prekey issued to one contact is not valid from another.
      expect(b.prekeys.findOwn(other, id), isNull);
      expect(await b.prekeys.deleteOwn(peer, id), isTrue);
      expect(b.prekeys.findOwn(peer, id), isNull);
      expect(CryptoUtils.isAllZero(fresh[3].privateKey), isTrue,
          reason: 'wiped in memory');
      expect(await b.prekeys.deleteOwn(peer, id), isFalse);
      expect(b.prekeys.findOwn(peer, 'ffffffffffffffff'), isNull);
      expect(b.prekeys.outstanding(peer).length, PrekeyStore.poolSize - 1);
      // Top-up replaces exactly the consumed one.
      expect((await b.prekeys.replenish(peer)).length, 1);
      final reloaded = PrekeyStore(b.prekeyStoreBacking, clock: clock.call);
      await reloaded.load();
      expect(reloaded.findOwn(peer, id), isNull);
    });

    test('own prekeys expire after 30 days, held ones after 28', () async {
      final clock = _Clock();
      final a = await _Party.create(clock);
      final b = await _Party.create(clock);
      await _issue(b, a);
      expect(a.prekeys.peerPrekeyCount(b.id), PrekeyStore.poolSize);
      clock.advance(const Duration(days: 27));
      expect(a.prekeys.peerPrekeyCount(b.id), PrekeyStore.poolSize);
      expect(b.prekeys.outstanding(a.id).length, PrekeyStore.poolSize);
      clock.advance(const Duration(days: 2)); // day 29
      expect(a.prekeys.peerPrekeyCount(b.id), 0, reason: 'holder stops first');
      expect(await a.prekeys.takePeerPrekey(b.id), isNull);
      expect(b.prekeys.outstanding(a.id).length, PrekeyStore.poolSize);
      clock.advance(const Duration(days: 2)); // day 31
      final id = (await PrekeyStore.idHexFor(Uint8List(1184)));
      expect(b.prekeys.findOwn(a.id, id), isNull);
      expect(b.prekeys.outstanding(a.id), isEmpty);
      expect(await b.prekeys.expire(), PrekeyStore.poolSize);
      expect(b.prekeyStoreBacking.keys, isEmpty, reason: 'nothing left on disk');
    });

    test('taking removes the key and it is never re-admitted', () async {
      final clock = _Clock();
      final a = await _Party.create(clock);
      final b = await _Party.create(clock);
      await _issue(b, a);
      final taken = (await a.prekeys.takePeerPrekey(b.id))!;
      expect(a.prekeys.peerPrekeyCount(b.id), PrekeyStore.poolSize - 1);
      // B has not heard from A yet, so its next bundle still lists the
      // same pool; A must not use the taken key twice.
      clock.advance(const Duration(seconds: 1));
      await _issue(b, a);
      expect(a.prekeys.peerPrekeyCount(b.id), PrekeyStore.poolSize - 1);
      final ids = <String>{};
      PeerPrekey? k;
      while ((k = await a.prekeys.takePeerPrekey(b.id)) != null) {
        ids.add(k!.id);
      }
      expect(ids, isNot(contains(taken.id)));
      expect(ids.length, PrekeyStore.poolSize - 1);
      await a.prekeys.discardPeerPrekeys(b.id);
      expect(a.prekeys.peerPrekeyCount(b.id), 0);
    });

    test('rename carries both pools to a rotated handle', () async {
      final clock = _Clock();
      final a = await _Party.create(clock);
      final b = await _Party.create(clock);
      await _issue(b, a);
      await a.prekeys.replenish(b.id);
      const rotated = 'NC-ffffffffffffffff';
      await a.prekeys.rename(b.id, rotated);
      expect(a.prekeys.peerPrekeyCount(b.id), 0);
      expect(a.prekeys.outstanding(b.id), isEmpty);
      expect(a.prekeys.peerPrekeyCount(rotated), PrekeyStore.poolSize);
      expect(a.prekeys.outstanding(rotated).length, PrekeyStore.poolSize);
      await a.prekeys.forgetPeer(rotated);
      expect(a.prekeys.peerPrekeyCount(rotated), 0);
      expect(a.prekeyStoreBacking.keys, isEmpty);
    });

    test('corrupt entries are dropped on load, not fatal', () async {
      final store = MemoryKeyValueStore();
      await store.put('own:NC-1', '{not json');
      await store.put('peer:NC-2', jsonEncode({'iat': 'x', 'keys': [], 'used': []}));
      final s = PrekeyStore(store);
      await s.load();
      expect(store.keys, isEmpty);
      expect(s.outstanding('NC-1'), isEmpty);
    });
  });
  group('PrekeyBundle / PrekeyUnknownNotice', () {
    test('signed bundle round-trips and is bound to signer and recipient', () async {
      final clock = _Clock();
      final a = await _Party.create(clock);
      final b = await _Party.create(clock);
      final eve = await _Party.create(clock);
      final wire = await _issue(b, a);
      expect(wire.keys.length, PrekeyStore.poolSize);
      // Same bundle, wrong recipient.
      expect(
          await wire.validate(
              pinnedSigningKey: b.keys.signingPublicKey,
              myId: eve.id,
              fromId: b.id,
              now: clock.now),
          contains('addressed to'));
      // Claimed from someone else than the link peer.
      expect(
          await wire.validate(
              pinnedSigningKey: eve.keys.signingPublicKey,
              myId: a.id,
              fromId: eve.id,
              now: clock.now),
          contains('names sender'));
      // Wrong signer: Eve signs a bundle in B's name.
      final forged = await PrekeyBundle.create(
          keys: eve.keys, from: b.id, to: a.id, prekeys: wire.keys, issuedAt: clock.now);
      expect(
          await forged.validate(
              pinnedSigningKey: b.keys.signingPublicKey,
              myId: a.id,
              fromId: b.id,
              now: clock.now),
          'bad signature');
      // Tampered key material: id no longer matches, or signature fails.
      final tampered = PrekeyBundle.fromJson(wire.toJson()
        ..['keys'] = [
          ...(wire.toJson()['keys'] as List).cast<Map<String, dynamic>>().map(
              (k) => Map<String, dynamic>.from(k)
                ..['pk'] = base64Encode(CryptoUtils.randomBytes(1184)))
        ]);
      expect(
          await tampered.validate(
              pinnedSigningKey: b.keys.signingPublicKey,
              myId: a.id,
              fromId: b.id,
              now: clock.now),
          isNotNull);
      final dup = await PrekeyBundle.create(
          keys: b.keys, from: b.id, to: a.id,
          prekeys: [wire.keys.first, wire.keys.first], issuedAt: clock.now);
      expect(
          await dup.validate(
              pinnedSigningKey: b.keys.signingPublicKey, myId: a.id, fromId: b.id, now: clock.now),
          'duplicate prekey id');
    });

    test('replayed or stale bundles are rejected by the monotonic issue time', () async {
      final clock = _Clock();
      final a = await _Party.create(clock);
      final b = await _Party.create(clock);
      final first = await _issue(b, a);
      clock.advance(const Duration(seconds: 1));
      final second = await _issue(b, a);
      expect(second.issuedAtMs, greaterThan(first.issuedAtMs));
      expect(a.prekeys.lastBundleIssuedAt(b.id), second.issuedAtMs);
      // The older bundle again, and the current one again.
      for (final replay in [first, second]) {
        expect(
            await replay.validate(
                pinnedSigningKey: b.keys.signingPublicKey,
                myId: a.id,
                fromId: b.id,
                lastIssuedAtMs: a.prekeys.lastBundleIssuedAt(b.id),
                now: clock.now),
            contains('replay'));
      }
      // An old capture, even with no bundle on file.
      final old = await PrekeyBundle.create(
          keys: b.keys, from: b.id, to: a.id, prekeys: first.keys,
          issuedAt: clock.now.subtract(const Duration(days: 8)));
      expect(
          await old.validate(
              pinnedSigningKey: b.keys.signingPublicKey, myId: a.id, fromId: b.id, now: clock.now),
          contains('too far'));
      final future = await PrekeyBundle.create(
          keys: b.keys, from: b.id, to: a.id, prekeys: first.keys,
          issuedAt: clock.now.add(const Duration(days: 8)));
      expect(
          await future.validate(
              pinnedSigningKey: b.keys.signingPublicKey, myId: a.id, fromId: b.id, now: clock.now),
          contains('too far'));
    });

    test('parser rejects malformed bundles with FormatException', () async {
      final clock = _Clock();
      final a = await _Party.create(clock);
      final b = await _Party.create(clock);
      final good = (await _issue(b, a)).toJson();
      expect(() => PrekeyBundle.fromJson(Map.of(good)..['v'] = 2), throwsFormatException);
      expect(() => PrekeyBundle.fromJson(Map.of(good)..remove('sig')), throwsFormatException);
      expect(() => PrekeyBundle.fromJson(Map.of(good)..['iat'] = 'now'), throwsFormatException);
      expect(
          () => PrekeyBundle.fromJson(Map.of(good)
            ..['keys'] = List.filled(PrekeyBundle.maxKeys + 1, (good['keys'] as List).first)),
          throwsFormatException);
      expect(
          () => PrekeyBundle.fromJson(Map.of(good)
            ..['keys'] = [
              {'id': 'zz', 'pk': (good['keys'] as List).first['pk']}
            ]),
          throwsFormatException);
    });

    test('unknown-prekey notice: control envelope, signature, addressing', () async {
      final clock = _Clock();
      final a = await _Party.create(clock);
      final b = await _Party.create(clock);
      final eve = await _Party.create(clock);
      final eph = CryptoUtils.toHex(CryptoUtils.randomBytes(32));
      const pk = '0011223344556677';
      final notice = await PrekeyUnknownNotice.create(
          keys: b.keys, from: b.id, to: a.id, ephemeralHex: eph, prekeyId: pk, issuedAt: clock.now);
      final env = _wire(notice.toEnvelope());
      expect(env.kind, EnvelopeKind.control);
      expect(env.isControl, isTrue);
      expect(env.from, b.id);
      expect(env.to, a.id);
      final parsed = PrekeyUnknownNotice.fromEnvelope(env);
      expect(parsed.ephemeralHex, eph);
      expect(parsed.prekeyId, pk);
      expect(
          await parsed.validate(
              pinnedSigningKey: b.keys.signingPublicKey, myId: a.id, fromId: b.id, now: clock.now),
          isNull);
      expect(
          await parsed.validate(
              pinnedSigningKey: eve.keys.signingPublicKey, myId: a.id, fromId: b.id, now: clock.now),
          'bad signature');
      expect(
          await parsed.validate(
              pinnedSigningKey: b.keys.signingPublicKey, myId: eve.id, fromId: b.id, now: clock.now),
          contains('addressed to'));
      // A relay re-addressing the envelope is caught by the body check.
      final rerouted = Envelope.fromJson(env.toJson()..['to'] = eve.id);
      expect(() => PrekeyUnknownNotice.fromEnvelope(rerouted), throwsFormatException);
      // A ratchet envelope is not a notice; an oversize control body is refused.
      expect(() => Envelope.fromJson(env.toJson()..['c'] = base64Encode(Uint8List(Envelope.maxControlBytes + 1))),
          throwsFormatException);
    });
  });

  group('Handshake: asynchronous agreement with a one-time prekey', () {
    test('initiator and responder derive the same root; fallback unchanged', () async {
      final a = await KeyManager.generateEphemeral();
      final b = await KeyManager.generateEphemeral();
      final opk = await KyberKem.generateKeyPair();
      final id = await PrekeyStore.idFor(opk.publicKey);
      final init = await Handshake.asyncInitiate(
          keys: a, peerIdentityKey: b.identityPublicKey, peerKyberPublicKey: b.kyberPublicKey,
          prekeyId: id, prekeyPublicKey: opk.publicKey);
      expect(init.prekeyId, id);
      final root = await Handshake.asyncRespond(
          keys: b, peerIdentityKey: a.identityPublicKey, peerEphemeralKey: init.ephemeralPublicKey,
          kyberCiphertext: init.kyberCiphertext, prekeyId: id, prekeyPrivateKey: opk.privateKey);
      expect(root, init.ratchetRoot);
      // The long-term key cannot open a prekey ciphertext (implicit
      // rejection: a different root, never an error).
      final wrong = await Handshake.asyncRespond(
          keys: b, peerIdentityKey: a.identityPublicKey, peerEphemeralKey: init.ephemeralPublicKey,
          kyberCiphertext: init.kyberCiphertext);
      expect(wrong, isNot(init.ratchetRoot));
      // Fallback path still agrees.
      final lt = await Handshake.asyncInitiate(
          keys: a, peerIdentityKey: b.identityPublicKey, peerKyberPublicKey: b.kyberPublicKey);
      expect(lt.prekeyId, isNull);
      expect(
          await Handshake.asyncRespond(
              keys: b, peerIdentityKey: a.identityPublicKey, peerEphemeralKey: lt.ephemeralPublicKey,
              kyberCiphertext: lt.kyberCiphertext),
          lt.ratchetRoot);
      expect(
          () => Handshake.asyncInitiate(
              keys: a, peerIdentityKey: b.identityPublicKey, peerKyberPublicKey: b.kyberPublicKey,
              prekeyId: id),
          throwsArgumentError);
    });

    test('KDF domain separation: same secrets, different label, different root', () async {
      final dh1 = CryptoUtils.randomBytes(32);
      final dh2 = CryptoUtils.randomBytes(32);
      final kem = CryptoUtils.randomBytes(32);
      final id = CryptoUtils.randomBytes(8);
      final longTerm = await Handshake.asyncRoot(dh1: dh1, dh2: dh2, kem: kem);
      final withPrekey = await Handshake.asyncRoot(dh1: dh1, dh2: dh2, kem: kem, prekeyId: id);
      final otherId = await Handshake.asyncRoot(
          dh1: dh1, dh2: dh2, kem: kem, prekeyId: CryptoUtils.randomBytes(8));
      expect(withPrekey, isNot(longTerm));
      expect(withPrekey, isNot(otherId));
      expect(await Handshake.asyncRoot(dh1: dh1, dh2: dh2, kem: kem, prekeyId: id), withPrekey);
      expect(await Handshake.asyncRoot(dh1: dh1, dh2: dh2, kem: kem), longTerm);
      expect(() => Handshake.asyncRoot(dh1: dh1, dh2: dh2, kem: kem, prekeyId: Uint8List(7)),
          throwsArgumentError);
    });
  });
  group('SessionManager with one-time prekeys', () {
    test('async session consumes a prekey on both sides and persists it', () async {
      final clock = _Clock();
      final a = await _Party.create(clock);
      final b = await _Party.create(clock);
      await _issue(b, a);
      final e1 = await a.sessions.encrypt(
          peerId: b.id, message: InnerMessage.text(id: '1', text: 'pq'), pinned: b.pinned());
      final id = e1.init!.prekeyIdHex;
      expect(id, isNotNull);
      expect(_wire(e1).init!.prekeyIdHex, id);
      expect(a.sessions.record(b.id)!.prekeyId, id);
      expect(a.sessions.record(b.id)!.isAsyncFallback, isFalse);
      expect(a.prekeys.peerPrekeyCount(b.id), PrekeyStore.poolSize - 1);
      expect(b.prekeys.findOwn(a.id, id!), isNotNull);

      expect((await b.sessions.decrypt(_wire(e1), pinned: a.pinned())).text, 'pq');
      expect(b.sessions.record(a.id)!.prekeyId, id);
      expect(b.prekeys.findOwn(a.id, id), isNull, reason: 'deleted on use');
      expect(b.prekeys.outstanding(a.id).length, PrekeyStore.poolSize - 1);

      // A repeat of the same init (mesh duplicate) is served by the
      // accepted-init fast path and needs no prekey.
      final e2 = await a.sessions.encrypt(
          peerId: b.id, message: InnerMessage.text(id: '2', text: 'again'), pinned: b.pinned());
      expect(e2.init!.prekeyIdHex, id);
      expect((await b.sessions.decrypt(_wire(e2), pinned: a.pinned())).text, 'again');
      final r = await b.sessions.encrypt(peerId: a.id, message: InnerMessage.text(id: '3', text: 'back'));
      expect((await a.sessions.decrypt(_wire(r))).text, 'back');

      // Both records survive a reload with the prekey id.
      final a2 = SessionManager(keys: a.keys, store: a.sessionStore, myId: a.id, prekeys: a.prekeys);
      await a2.load();
      final b2 = SessionManager(keys: b.keys, store: b.sessionStore, myId: b.id, prekeys: b.prekeys);
      await b2.load();
      expect(a2.record(b.id)!.prekeyId, id);
      expect(b2.record(a.id)!.prekeyId, id);
      expect(a2.record(b.id)!.origin, 'async');
    });

    test('the prekey is deleted only after the first message decrypts', () async {
      final clock = _Clock();
      final a = await _Party.create(clock);
      final b = await _Party.create(clock);
      await _issue(b, a);
      final e1 = await a.sessions.encrypt(
          peerId: b.id, message: InnerMessage.text(id: '1', text: 'pq'), pinned: b.pinned());
      final id = e1.init!.prekeyIdHex!;
      final json = e1.toJson();
      final bad = base64Decode(json['c'] as String);
      bad[bad.length - 1] ^= 0x01;
      json['c'] = base64Encode(bad);
      await expectLater(
          b.sessions.decrypt(Envelope.fromJson(json), pinned: a.pinned()), throwsA(anything));
      expect(b.prekeys.findOwn(a.id, id), isNotNull, reason: 'kept: nothing was decrypted');
      expect(b.sessions.hasSession(a.id), isFalse);
      expect((await b.sessions.decrypt(_wire(e1), pinned: a.pinned())).text, 'pq');
      expect(b.prekeys.findOwn(a.id, id), isNull);
    });

    test('an unknown prekey id is reported, never guessed', () async {
      final clock = _Clock();
      final a = await _Party.create(clock);
      final b = await _Party.create(clock);
      final c = await _Party.create(clock);
      await _issue(b, a);
      final e1 = await a.sessions.encrypt(
          peerId: b.id, message: InnerMessage.text(id: '1', text: 'pq'), pinned: b.pinned());
      // B lost its prekey store (fresh install, restore without the box).
      await b.prekeys.clearAll();
      await expectLater(
          b.sessions.decrypt(_wire(e1), pinned: a.pinned()),
          throwsA(isA<UnknownPrekeyException>()
              .having((e) => e.peerId, 'peerId', a.id)
              .having((e) => e.prekeyId, 'prekeyId', e1.init!.prekeyIdHex)
              .having((e) => e.ephemeralHex, 'eph', e1.init!.ephemeralHex)));
      expect(b.sessions.hasSession(a.id), isFalse);
      // A prekey B issued to A cannot be used by C, even if C learned it.
      clock.advance(const Duration(seconds: 1));
      await _issue(b, a);
      final leaked = (await a.prekeys.takePeerPrekey(b.id))!;
      await c.prekeys.replacePeerBundle(b.id,
          keys: [leaked], issuedAtMs: clock.now.millisecondsSinceEpoch);
      final fromC = await c.sessions.encrypt(
          peerId: b.id, message: InnerMessage.text(id: 'c', text: 'hi'), pinned: b.pinned());
      expect(fromC.init!.prekeyIdHex, leaked.id);
      await expectLater(
          b.sessions.decrypt(_wire(fromC), pinned: c.pinned()),
          throwsA(isA<UnknownPrekeyException>()));
      // Without a store at all, every prekey init is unknown.
      final bare = SessionManager(keys: b.keys, store: MemoryKeyValueStore(), myId: b.id);
      await expectLater(bare.decrypt(_wire(e1), pinned: a.pinned()),
          throwsA(isA<UnknownPrekeyException>()));
    });

    test('empty pool falls back to the long-term key and is flagged', () async {
      final clock = _Clock();
      final a = await _Party.create(clock);
      final b = await _Party.create(clock);
      final e1 = await a.sessions.encrypt(
          peerId: b.id, message: InnerMessage.text(id: '1', text: 'lt'), pinned: b.pinned());
      expect(e1.init!.prekeyId, isNull);
      expect(_wire(e1).toJson()['i'], isNot(contains('pk')));
      expect(a.sessions.record(b.id)!.isAsyncFallback, isTrue);
      expect((await b.sessions.decrypt(_wire(e1), pinned: a.pinned())).text, 'lt');
      expect(b.sessions.record(a.id)!.prekeyId, isNull);
      expect(b.sessions.record(a.id)!.isAsyncFallback, isTrue);
      // Later, with a pool, a fresh session uses a prekey.
      await _issue(b, a);
      await a.sessions.reset(b.id);
      final e2 = await a.sessions.encrypt(
          peerId: b.id, message: InnerMessage.text(id: '2', text: 'pq'), pinned: b.pinned());
      expect(e2.init!.prekeyId, isNotNull);
      expect((await b.sessions.decrypt(_wire(e2), pinned: a.pinned())).text, 'pq');
    });

    test('a lost collision leaves the consumed prekeys gone but sessions agree', () async {
      final clock = _Clock();
      final p1 = await _Party.create(clock);
      final p2 = await _Party.create(clock);
      final small = p1.id.compareTo(p2.id) < 0 ? p1 : p2;
      final large = small == p1 ? p2 : p1;
      await _issue(small, large);
      await _issue(large, small);
      final fromSmall = await small.sessions.encrypt(
          peerId: large.id, message: InnerMessage.text(id: 's', text: 'from small'), pinned: large.pinned());
      final fromLarge = await large.sessions.encrypt(
          peerId: small.id, message: InnerMessage.text(id: 'l', text: 'from large'), pinned: small.pinned());
      final usedBySmall = fromSmall.init!.prekeyIdHex!;
      final usedByLarge = fromLarge.init!.prekeyIdHex!;
      await expectLater(small.sessions.decrypt(_wire(fromLarge), pinned: large.pinned()),
          throwsA(isA<SessionCollisionException>()));
      // Small ignored the init: its private half stays until it expires.
      expect(small.prekeys.findOwn(large.id, usedByLarge), isNotNull);
      expect(large.prekeys.peerPrekeyCount(small.id), PrekeyStore.poolSize - 1);
      // Large adopts small's session and consumes the prekey small used.
      expect((await large.sessions.decrypt(_wire(fromSmall), pinned: small.pinned())).text, 'from small');
      expect(large.prekeys.findOwn(small.id, usedBySmall), isNull);
      expect(large.sessions.record(small.id)!.prekeyId, usedBySmall);
      expect(small.sessions.record(large.id)!.prekeyId, usedBySmall);
      final resend = await large.sessions.encrypt(
          peerId: small.id, message: InnerMessage.text(id: 'l2', text: 'again'));
      expect((await small.sessions.decrypt(_wire(resend))).text, 'again');
    });
  });
}