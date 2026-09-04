import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyxchat/core/crypto/crypto_utils.dart';
import 'package:nyxchat/core/crypto/key_manager.dart';
import 'package:nyxchat/core/crypto/nyx_id.dart';
import 'package:nyxchat/core/crypto/pair_keys.dart';
import 'package:nyxchat/core/mesh/mesh_packet.dart';
import 'package:nyxchat/core/mesh/mesh_router.dart';
import 'package:nyxchat/core/mesh/mesh_store.dart';
import 'package:nyxchat/core/network/discovery_beacon.dart';
import 'package:nyxchat/core/protocol/padding.dart';
import 'package:nyxchat/core/storage/key_value_store.dart';
import 'package:nyxchat/core/storage/trust_store.dart';

Future<(KeyManager, String, PinnedPeer)> _identity(String name) async {
  final keys = await KeyManager.generateEphemeral();
  final id = await NyxId.derive(signingPublicKey: keys.signingPublicKey, identityPublicKey: keys.identityPublicKey);
  final pinned = PinnedPeer(
    nyxChatId: id, displayName: name,
    identityKey: keys.identityPublicKey, signingKey: keys.signingPublicKey,
    kyberPublicKey: keys.kyberPublicKey, verified: true,
    firstSeen: DateTime.now(), lastSeen: DateTime.now(),
  );
  return (keys, id, pinned);
}

void main() {
  group('PairKeys', () {
    test('both sides derive identical tokens; directions differ; strangers differ', () async {
      final (ka, ida, pa) = await _identity('a');
      final (kb, idb, pb) = await _identity('b');
      final (kc, _, _) = await _identity('c');
      final ab = await PairKeys.derive(ka, pb);
      final ba = await PairKeys.derive(kb, pa);
      final cb = await PairKeys.derive(kc, pb);
      expect(await ab.meshToken(5, idb), await ba.meshToken(5, idb));
      expect(await ab.meshToken(5, idb), isNot(equals(await ab.meshToken(5, ida))));
      expect(await ab.meshToken(5, idb), isNot(equals(await ab.meshToken(6, idb))));
      expect(await ab.discoveryToken(9, ida), await ba.discoveryToken(9, ida));
      expect(await cb.discoveryToken(9, ida), isNot(equals(await ab.discoveryToken(9, ida))));
      expect(await ab.nostrToken(1, idb), await ba.nostrToken(1, idb));
      expect((await ab.nostrToken(1, idb)).length, 64);
    });

    test('sealed wrapper round trip and rejection', () async {
      final (ka, _, pa) = await _identity('a');
      final (kb, _, pb) = await _identity('b');
      final (kc, _, _) = await _identity('c');
      final ab = await PairKeys.derive(ka, pb);
      final ba = await PairKeys.derive(kb, pa);
      final cb = await PairKeys.derive(kc, pb);
      final blob = await ab.wrap([1, 2, 3]);
      expect(await ba.unwrap(blob), [1, 2, 3]);
      expect(await cb.unwrap(blob), isNull);
      blob[20] ^= 1;
      expect(await ba.unwrap(blob), isNull);
      expect(await ba.unwrap([1, 2]), isNull);
    });
  });

  group('DiscoveryBeacon', () {
    test('bloom filter contains inserted tokens and rejects most others', () {
      final tokens = List.generate(10, (_) => CryptoUtils.randomBytes(8));
      final bloom = DiscoveryBeacon.buildBloom(tokens);
      for (final t in tokens) {
        expect(DiscoveryBeacon.bloomContains(bloom, t), isTrue);
      }
      var fp = 0;
      for (var i = 0; i < 1000; i++) {
        if (DiscoveryBeacon.bloomContains(bloom, CryptoUtils.randomBytes(8))) fp++;
      }
      expect(fp, lessThan(100)); // ~2% expected at 10 entries / 128 bits
    });

    test('BLE and TXT encodings round trip', () {
      final pub = DiscoveryBeacon.public('NC-0123456789ABCDEF');
      final decodedPub = DiscoveryBeacon.decodeBle(pub.encodeBle())!;
      expect(decodedPub.isPublic, isTrue);
      expect(decodedPub.nyxId, 'NC-0123456789ABCDEF');
      expect(pub.encodeBle().length, lessThanOrEqualTo(24));

      final bloom = DiscoveryBeacon.buildBloom([CryptoUtils.randomBytes(8)]);
      final priv = DiscoveryBeacon.private(bloom, slot: PairKeys.discoverySlot());
      final ble = priv.encodeBle();
      expect(ble.length, lessThanOrEqualTo(24));
      final decodedPriv = DiscoveryBeacon.decodeBle(ble)!;
      expect(decodedPriv.isPublic, isFalse);
      expect(decodedPriv.bloom, bloom);
      expect(decodedPriv.slot, priv.slot);

      final txt = priv.toTxt();
      final fromTxt = DiscoveryBeacon.fromTxt(txt)!;
      expect(fromTxt.bloom, bloom);
      expect(DiscoveryBeacon.fromTxt(pub.toTxt(displayName: 'x'))!.nyxId, pub.nyxId);
      expect(DiscoveryBeacon.decodeBle([1, 2]), isNull);
    });

    test('matcher recognises contacts and ignores strangers', () async {
      final (ka, ida, pa) = await _identity('a');
      final (kb, idb, pb) = await _identity('b');
      final (kc, idc, pc) = await _identity('c');
      final trustA = TrustStore(MemoryKeyValueStore());
      await trustA.acceptNewKeys(pb);
      final trustB = TrustStore(MemoryKeyValueStore());
      await trustB.acceptNewKeys(pa);
      final trustC = TrustStore(MemoryKeyValueStore());
      await trustC.acceptNewKeys(pa);
      final matcherA = DiscoveryMatcher(myId: ida, pairKeys: PairKeyCache(ka, trustA));
      final matcherB = DiscoveryMatcher(myId: idb, pairKeys: PairKeyCache(kb, trustB));
      final matcherC = DiscoveryMatcher(myId: idc, pairKeys: PairKeyCache(kc, trustC));
      final slot = PairKeys.discoverySlot();
      final bloomA = await matcherA.buildPrivateBloom(slot: slot);
      expect(await matcherB.match(bloomA, slot), [ida]);
      // C pinned A but A did not pin C, so A's beacon says nothing to C.
      expect(await matcherC.match(bloomA, slot), isEmpty);
      // B's beacon is recognised by A.
      final bloomB = await matcherB.buildPrivateBloom(slot: slot);
      expect(await matcherA.match(bloomB, slot), [idb]);
    });
  });

  group('Padding', () {
    test('buckets and round trip', () {
      expect(Padding.bucketFor(0), 256);
      expect(Padding.bucketFor(252), 256);
      expect(Padding.bucketFor(253), 512);
      final data = List.generate(700, (i) => i & 0xff);
      final padded = Padding.pad(data);
      expect(padded.length, 1024);
      expect(Padding.unpad(padded), data);
      expect(() => Padding.unpad([0, 0, 9, 9, 1]), throwsFormatException);
    });
  });

  group('MeshPacket v2', () {
    test('binary encode/decode round trip and limits', () {
      final p = MeshPacket.create(
        type: MeshPacket.typeMessage,
        to: CryptoUtils.randomBytes(16),
        replyTo: CryptoUtils.randomBytes(16),
        payload: Uint8List.fromList([9, 8, 7]),
      ).forward(CryptoUtils.randomBytes(8));
      final d = MeshPacket.decode(p.encode());
      expect(d.id, p.id);
      expect(d.to, p.to);
      expect(d.replyTo, p.replyTo);
      expect(d.ttl, p.ttl);
      expect(d.routePath.length, 1);
      expect(d.payload, [9, 8, 7]);
      expect(MeshPacket.fromJson(p.toJson()).id, p.id);
      expect(() => MeshPacket.decode([1, 2, 3]), throwsFormatException);
      expect(() => MeshPacket.decode(Uint8List(61)..[0] = 9), throwsFormatException);
    });

    test('router delivers by token, acks, and purges relays', () async {
      final storeA = MeshStore(), storeR = MeshStore(), storeB = MeshStore();
      final a = MeshRouter(store: storeA), r = MeshRouter(store: storeR), b = MeshRouter(store: storeB);
      await a.init('A');
      await r.init('R');
      await b.init('B');
      final toB = CryptoUtils.randomBytes(16);
      final toA = CryptoUtils.randomBytes(16);
      a.isForMe = (p) => CryptoUtils.constantTimeEquals(p.to, toA);
      b.isForMe = (p) => CryptoUtils.constantTimeEquals(p.to, toB);
      r.isForMe = (_) => false;
      // Wire: A <-> R <-> B, synchronous hops.
      a.onForwardPacket = (p, _) => r.handlePacket(p);
      r.onForwardPacket = (p, _) {
        a.handlePacket(p);
        b.handlePacket(p);
      };
      b.onForwardPacket = (p, _) => r.handlePacket(p);
      MeshPacket? delivered;
      b.onPacketForMe = (p) => delivered = p;
      String? acked;
      a.onAckReceived = (id) => acked = id;

      final sent = await a.send(to: toB, replyTo: toA, payload: Uint8List.fromList([42]));
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      expect(delivered, isNotNull);
      expect(delivered!.payload, [42]);
      expect(storeR.packetCount, 1); // relay holds it until acked
      expect(r.knownRoutes, 1); // learned route to A's reply token

      await b.sendAck(delivered!);
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      expect(acked, sent.id);
      expect(storeR.packetCount, 0); // purged by the ack
      a.dispose();
      r.dispose();
      b.dispose();
    });
  });
}