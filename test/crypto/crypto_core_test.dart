import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyxchat/core/crypto/crypto_utils.dart';
import 'package:nyxchat/core/crypto/double_ratchet.dart';
import 'package:nyxchat/core/crypto/handshake.dart';
import 'package:nyxchat/core/crypto/hybrid_key_exchange.dart';
import 'package:nyxchat/core/crypto/key_manager.dart';
import 'package:nyxchat/core/crypto/nyx_id.dart';
import 'package:nyxchat/core/crypto/secure_channel.dart';

Future<(KeyManager, String)> _identity() async {
  final keys = await KeyManager.generateEphemeral();
  final id = await NyxId.derive(
    signingPublicKey: keys.signingPublicKey,
    identityPublicKey: keys.identityPublicKey,
  );
  return (keys, id);
}

void main() {
  group('CryptoUtils', () {
    test('hex round trip and validation', () {
      final bytes = CryptoUtils.randomBytes(40);
      expect(CryptoUtils.fromHex(CryptoUtils.toHex(bytes)), bytes);
      expect(() => CryptoUtils.fromHex('abc'), throwsFormatException);
      expect(() => CryptoUtils.fromHex('zz'), throwsFormatException);
      expect(() => CryptoUtils.decodeKey('00', 32, 'k'), throwsFormatException);
    });

    test('constant-time compare', () {
      expect(CryptoUtils.constantTimeEquals([1, 2, 3], [1, 2, 3]), isTrue);
      expect(CryptoUtils.constantTimeEquals([1, 2, 3], [1, 2, 4]), isFalse);
      expect(CryptoUtils.constantTimeEquals([1, 2], [1, 2, 3]), isFalse);
    });

    test('x25519 rejects low-order point', () async {
      final kp = await CryptoUtils.newX25519KeyPair();
      await expectLater(
          CryptoUtils.x25519(kp, Uint8List(32)), throwsA(isA<StateError>()));
    });

    test('AES-GCM round trip with AAD', () async {
      final key = CryptoUtils.randomBytes(32);
      final nonce = CryptoUtils.randomBytes(12);
      final ct = await CryptoUtils.aesGcmEncrypt(
          key: key, nonce: nonce, plaintext: [1, 2, 3], aad: [9]);
      expect(
          await CryptoUtils.aesGcmDecrypt(
              key: key, nonce: nonce, ciphertextWithTag: ct, aad: [9]),
          [1, 2, 3]);
      await expectLater(
          CryptoUtils.aesGcmDecrypt(
              key: key, nonce: nonce, ciphertextWithTag: ct, aad: [8]),
          throwsA(anything));
    });
  });

  group('NyxId', () {
    test('derive, verify, short form', () async {
      final (keys, id) = await _identity();
      expect(NyxId.isModern(id), isTrue);
      expect(id.length, 19);
      expect(
          await NyxId.verify(
              id: id,
              signingPublicKey: keys.signingPublicKey,
              identityPublicKey: keys.identityPublicKey),
          isTrue);
      final other = await KeyManager.generateEphemeral();
      expect(
          await NyxId.verify(
              id: id,
              signingPublicKey: other.signingPublicKey,
              identityPublicKey: other.identityPublicKey),
          isFalse);
      expect(NyxId.shortForm(id), matches(RegExp(r'^NC-[0-9A-F]{4}\.\.\.[0-9A-F]{4}$')));
    });

    test('legacy id verification', () async {
      final keys = await KeyManager.generateEphemeral();
      final legacy = NyxId.legacyDerive(keys.identityPublicKeyHex);
      expect(NyxId.isLegacy(legacy), isTrue);
      expect(
          await NyxId.verify(
              id: legacy,
              signingPublicKey: keys.signingPublicKey,
              identityPublicKey: keys.identityPublicKey),
          isTrue);
    });

    test('safety number is symmetric and 60 digits', () async {
      final a = CryptoUtils.randomBytes(32);
      final b = CryptoUtils.randomBytes(32);
      final s1 = await NyxId.safetyNumber(a, b);
      final s2 = await NyxId.safetyNumber(b, a);
      expect(s1, s2);
      expect(s1.replaceAll(' ', '').length, 60);
    });
  });

  group('KyberKem', () {
    test('encapsulate / decapsulate agree', () async {
      final kp = await KyberKem.generateKeyPair();
      expect(kp.publicKey.length, CryptoUtils.kyber768PublicKeyLength);
      expect(kp.privateKey.length, CryptoUtils.kyber768PrivateKeyLength);
      final enc = await KyberKem.encapsulate(kp.publicKey);
      expect(enc.ciphertext.length, CryptoUtils.kyber768CiphertextLength);
      final dec = await KyberKem.decapsulate(enc.ciphertext, kp.privateKey);
      expect(dec, enc.sharedSecret);
    });

    test('wrong key yields a different secret (implicit rejection)', () async {
      final kp1 = await KyberKem.generateKeyPair();
      final kp2 = await KyberKem.generateKeyPair();
      final enc = await KyberKem.encapsulate(kp1.publicKey);
      final dec = await KyberKem.decapsulate(enc.ciphertext, kp2.privateKey);
      expect(dec, isNot(equals(enc.sharedSecret)));
    });

    test('rejects malformed sizes', () async {
      await expectLater(
          KyberKem.encapsulate(Uint8List(10)), throwsFormatException);
      await expectLater(KyberKem.decapsulate(Uint8List(10), Uint8List(2400)),
          throwsFormatException);
    });
  });

  group('SecureChannel', () {
    test('bidirectional frames, counters, replay detection', () async {
      final master = CryptoUtils.randomBytes(32);
      final a = await SecureChannel.fromMasterSecret(
          masterSecret: master, isInitiator: true);
      final b = await SecureChannel.fromMasterSecret(
          masterSecret: master, isInitiator: false);
      final f1 = await a.seal('hello');
      final f2 = await a.seal('world');
      final j1 = jsonDecode(f1) as Map<String, dynamic>;
      final j2 = jsonDecode(f2) as Map<String, dynamic>;
      expect(SecureChannel.isSealedFrame(j1), isTrue);
      expect(await b.open(j1), 'hello');
      expect(await b.open(j2), 'world');
      await expectLater(b.open(j1), throwsA(isA<StateError>()));
      final r = await b.seal('reply');
      expect(await a.open(jsonDecode(r) as Map<String, dynamic>), 'reply');
    });

    test('tampering is detected', () async {
      final master = CryptoUtils.randomBytes(32);
      final a = await SecureChannel.fromMasterSecret(
          masterSecret: master, isInitiator: true);
      final b = await SecureChannel.fromMasterSecret(
          masterSecret: master, isInitiator: false);
      final j = jsonDecode(await a.seal('x')) as Map<String, dynamic>;
      final bytes = base64Decode(j['e'] as String);
      bytes[0] ^= 1;
      j['e'] = base64Encode(bytes);
      await expectLater(b.open(j), throwsA(isA<StateError>()));
    });
  });

  group('Handshake', () {
    test('full flow yields identical secrets and a working ratchet', () async {
      final (aliceKeys, aliceId) = await _identity();
      final (bobKeys, bobId) = await _identity();

      final state = await Handshake.createInitiatorHello(
        keys: aliceKeys, nyxChatId: aliceId, displayName: 'Alice',
        listeningPort: 42420, capabilities: const ['mesh'],
      );
      // Serialise across the wire.
      final helloWire = HelloMessage.fromJson(
          jsonDecode(jsonEncode(state.hello.toJson())) as Map<String, dynamic>);

      final (response, bobResult) = await Handshake.respond(
        keys: bobKeys, nyxChatId: bobId, displayName: 'Bob',
        listeningPort: 42420, initiatorHello: helloWire,
      );
      final responseWire = HelloMessage.fromJson(
          jsonDecode(jsonEncode(response.toJson())) as Map<String, dynamic>);

      final aliceResult = await Handshake.completeInitiator(
          keys: aliceKeys, state: state, response: responseWire);

      expect(aliceResult.masterSecret, bobResult.masterSecret);
      expect(aliceResult.ratchetRoot, bobResult.ratchetRoot);
      expect(aliceResult.peerId, bobId);
      expect(bobResult.peerId, aliceId);
      expect(bobResult.peerCapabilities, ['mesh']);
      expect(aliceResult.isInitiator, isTrue);
      expect(bobResult.isInitiator, isFalse);

      final alice = await DoubleRatchetSession.initAlice(
        sharedSecret: aliceResult.ratchetRoot,
        bobRatchetPublicKey: aliceResult.peerEphemeralKey,
      );
      final bob = await DoubleRatchetSession.initBob(
        sharedSecret: bobResult.ratchetRoot,
        bobRatchetKeyPair: bobResult.myEphemeralKeyPair,
      );
      final m = await alice.encrypt(utf8.encode('hi bob'));
      expect(utf8.decode(await bob.decrypt(m)), 'hi bob');
      final r = await bob.encrypt(utf8.encode('hi alice'));
      expect(utf8.decode(await alice.decrypt(r)), 'hi alice');
    });

    test('tampered hello is rejected', () async {
      final (aliceKeys, aliceId) = await _identity();
      final (bobKeys, bobId) = await _identity();
      final state = await Handshake.createInitiatorHello(
          keys: aliceKeys, nyxChatId: aliceId, displayName: 'Alice',
          listeningPort: 1);
      final json = state.hello.toJson();
      json['name'] = 'Mallory';
      final forged = HelloMessage.fromJson(json);
      await expectLater(
        Handshake.respond(keys: bobKeys, nyxChatId: bobId, displayName: 'Bob',
            listeningPort: 1, initiatorHello: forged),
        throwsA(isA<HandshakeException>()),
      );
    });

    test('id not bound to keys is rejected', () async {
      final (aliceKeys, _) = await _identity();
      final (_, otherId) = await _identity();
      final (bobKeys, bobId) = await _identity();
      final state = await Handshake.createInitiatorHello(
          keys: aliceKeys, nyxChatId: otherId, displayName: 'Alice',
          listeningPort: 1);
      await expectLater(
        Handshake.respond(keys: bobKeys, nyxChatId: bobId, displayName: 'Bob',
            listeningPort: 1, initiatorHello: state.hello),
        throwsA(isA<HandshakeException>()),
      );
    });

    test('response with wrong nonce is rejected (replay)', () async {
      final (aliceKeys, aliceId) = await _identity();
      final (bobKeys, bobId) = await _identity();
      final s1 = await Handshake.createInitiatorHello(
          keys: aliceKeys, nyxChatId: aliceId, displayName: 'A', listeningPort: 1);
      final s2 = await Handshake.createInitiatorHello(
          keys: aliceKeys, nyxChatId: aliceId, displayName: 'A', listeningPort: 1);
      final (resp1, _) = await Handshake.respond(keys: bobKeys, nyxChatId: bobId,
          displayName: 'B', listeningPort: 1, initiatorHello: s1.hello);
      await expectLater(
        Handshake.completeInitiator(keys: aliceKeys, state: s2, response: resp1),
        throwsA(isA<HandshakeException>()),
      );
    });

    test('async session init agrees on ratchet root', () async {
      final (aliceKeys, _) = await _identity();
      final (bobKeys, _) = await _identity();
      final init = await Handshake.asyncInitiate(
        keys: aliceKeys,
        peerIdentityKey: bobKeys.identityPublicKey,
        peerKyberPublicKey: bobKeys.kyberPublicKey,
      );
      final bobRoot = await Handshake.asyncRespond(
        keys: bobKeys,
        peerIdentityKey: aliceKeys.identityPublicKey,
        peerEphemeralKey: init.ephemeralPublicKey,
        kyberCiphertext: init.kyberCiphertext,
      );
      expect(bobRoot, init.ratchetRoot);
      final alice = await DoubleRatchetSession.initAlice(
          sharedSecret: init.ratchetRoot,
          bobRatchetPublicKey: bobKeys.identityPublicKey);
      final bob = await DoubleRatchetSession.initBob(
          sharedSecret: bobRoot, bobRatchetKeyPair: bobKeys.identityKeyPair);
      final m = await alice.encrypt([5]);
      expect(await bob.decrypt(m), [5]);
      final r = await bob.encrypt([6]);
      expect(await alice.decrypt(r), [6]);
    });
  });
}