// Cryptographic micro-benchmarks for the protocol core.
//
// Run:  flutter test benchmark/crypto_bench_test.dart
// Output: build/crypto_bench.csv  (operation, iterations, mean_ms, p95_ms)
//         build/crypto_sizes.csv  (object, bytes)
//
// These run on the host VM (pure Dart); phone numbers are slower by a
// device-dependent factor but the relative costs are representative.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyxchat/core/crypto/crypto_utils.dart';
import 'package:nyxchat/core/crypto/double_ratchet.dart';
import 'package:nyxchat/core/crypto/handshake.dart';
import 'package:nyxchat/core/crypto/hybrid_key_exchange.dart';
import 'package:nyxchat/core/crypto/key_manager.dart';
import 'package:nyxchat/core/crypto/nyx_id.dart';
import 'package:nyxchat/core/crypto/secure_channel.dart';
import 'package:nyxchat/core/crypto/sender_keys.dart';
import 'package:nyxchat/core/protocol/envelope.dart';
import 'package:nyxchat/core/protocol/inner_message.dart';
import 'package:nyxchat/services/app_lock_service.dart';

class Bench {
  final String name;
  final List<double> samplesMs = [];
  Bench(this.name);
  double get mean => samplesMs.reduce((a, b) => a + b) / samplesMs.length;
  double get p95 {
    final s = List.of(samplesMs)..sort();
    return s[(s.length * 0.95).floor().clamp(0, s.length - 1)];
  }
  String csv() =>
      '$name,${samplesMs.length},${mean.toStringAsFixed(3)},${p95.toStringAsFixed(3)}';
}

Future<Bench> time(String name, int iterations, Future<void> Function(int i) body) async {
  final b = Bench(name);
  for (var i = 0; i < iterations; i++) {
    final sw = Stopwatch()..start();
    await body(i);
    sw.stop();
    b.samplesMs.add(sw.elapsedMicroseconds / 1000.0);
  }
  return b;
}

void main() {
  test('crypto micro-benchmarks', () async {
    final results = <Bench>[];

    results.add(await time('x25519_keygen', 50, (_) async => CryptoUtils.newX25519KeyPair()));
    final kp = await CryptoUtils.newX25519KeyPair();
    final kp2 = await CryptoUtils.newX25519KeyPair();
    results.add(await time('x25519_dh', 50,
        (_) async => CryptoUtils.x25519(kp, CryptoUtils.publicKeyBytes(kp2))));
    final sk = await CryptoUtils.newEd25519KeyPair();
    final msg = CryptoUtils.randomBytes(256);
    results.add(await time('ed25519_sign_256B', 50, (_) async => CryptoUtils.ed25519Sign(sk, msg)));
    final sig = await CryptoUtils.ed25519Sign(sk, msg);
    results.add(await time('ed25519_verify_256B', 50, (_) async => CryptoUtils.ed25519Verify(
        publicKey: CryptoUtils.publicKeyBytes(sk), message: msg, signature: sig)));

    results.add(await time('kyber768_keygen', 20, (_) async => KyberKem.generateKeyPair()));
    final kyber = await KyberKem.generateKeyPair();
    results.add(await time('kyber768_encaps', 20, (_) async => KyberKem.encapsulate(kyber.publicKey)));
    final enc = await KyberKem.encapsulate(kyber.publicKey);
    results.add(await time('kyber768_decaps', 20,
        (_) async => KyberKem.decapsulate(enc.ciphertext, kyber.privateKey)));

    final a = await KeyManager.generateEphemeral();
    final b = await KeyManager.generateEphemeral();
    final aId = await NyxId.derive(signingPublicKey: a.signingPublicKey, identityPublicKey: a.identityPublicKey);
    final bId = await NyxId.derive(signingPublicKey: b.signingPublicKey, identityPublicKey: b.identityPublicKey);
    results.add(await time('handshake_full_both_sides', 20, (_) async {
      final st = await Handshake.createInitiatorHello(keys: a, nyxChatId: aId, displayName: 'A', listeningPort: 1);
      final (resp, _) = await Handshake.respond(
          keys: b, nyxChatId: bId, displayName: 'B', listeningPort: 1, initiatorHello: st.hello);
      await Handshake.completeInitiator(keys: a, state: st, response: resp);
    }));
    results.add(await time('async_session_init', 20, (_) async => Handshake.asyncInitiate(
        keys: a, peerIdentityKey: b.identityPublicKey, peerKyberPublicKey: b.kyberPublicKey)));

    final shared = CryptoUtils.randomBytes(32);
    final bobKeys = await CryptoUtils.newX25519KeyPair();
    final alice = await DoubleRatchetSession.initAlice(
        sharedSecret: shared, bobRatchetPublicKey: CryptoUtils.publicKeyBytes(bobKeys));
    final bob = await DoubleRatchetSession.initBob(sharedSecret: shared, bobRatchetKeyPair: bobKeys);
    final plain = InnerMessage.text(id: 'x', text: 'a' * 200).toBytes();
    final adAB = Envelope.associatedDataFor(aId, bId, EnvelopeKind.ratchet);
    final adBA = Envelope.associatedDataFor(bId, aId, EnvelopeKind.ratchet);
    final chain = <RatchetMessage>[];
    results.add(await time('ratchet_encrypt_same_chain', 200,
        (_) async => chain.add(await alice.encrypt(plain, associatedData: adAB))));
    results.add(await time('ratchet_decrypt_same_chain', 200,
        (i) async => bob.decrypt(chain[i], associatedData: adAB)));
    results.add(await time('ratchet_pingpong_roundtrip', 50, (_) async {
      final m = await alice.encrypt(plain, associatedData: adAB);
      await bob.decrypt(m, associatedData: adAB);
      final r = await bob.encrypt(plain, associatedData: adBA);
      await alice.decrypt(r, associatedData: adBA);
    }));

    final chan = await SecureChannel.fromMasterSecret(masterSecret: shared, isInitiator: true);
    final chan2 = await SecureChannel.fromMasterSecret(masterSecret: shared, isInitiator: false);
    final line = jsonEncode({'t': 'envelope', 'p': {'c': base64Encode(CryptoUtils.randomBytes(400))}});
    final sealedFrames = <String>[];
    results.add(await time('link_seal_500B', 200, (_) async => sealedFrames.add(await chan.seal(line))));
    results.add(await time('link_open_500B', 200,
        (i) async => chan2.open(jsonDecode(sealedFrames[i]) as Map<String, dynamic>)));

    final skm = SenderKeyManager();
    final skm2 = SenderKeyManager();
    skm2.processDistribution('a', await skm.ownDistribution('g'));
    final gad = Envelope.associatedDataFor(aId, 'g', EnvelopeKind.senderKey);
    final groupMsgs = <SenderKeyMessage>[];
    results.add(await time('senderkey_encrypt', 200,
        (_) async => groupMsgs.add(await skm.encrypt('g', plain, gad))));
    results.add(await time('senderkey_decrypt', 200, (i) async =>
        skm2.decrypt(groupId: 'g', senderId: 'a', message: groupMsgs[i], associatedData: gad)));

    results.add(await time('argon2id_32MiB_2pass', 3,
        (_) async => AppLockService.deriveArgon2id('correct horse', CryptoUtils.randomBytes(32))));

    final fpA = await NyxId.fingerprint(signingPublicKey: a.signingPublicKey, identityPublicKey: a.identityPublicKey);
    final fpB = await NyxId.fingerprint(signingPublicKey: b.signingPublicKey, identityPublicKey: b.identityPublicKey);
    results.add(await time('safety_number', 5, (_) async => NyxId.safetyNumber(fpA, fpB)));

    // Wire sizes
    final helloJson = jsonEncode((await Handshake.createInitiatorHello(
            keys: a, nyxChatId: aId, displayName: 'A', listeningPort: 1)).hello.toJson());
    final envPlain = Envelope.ratchet(from: aId, to: bId, message: await alice.encrypt(plain, associatedData: adAB)).encode();
    final init = await Handshake.asyncInitiate(keys: a, peerIdentityKey: b.identityPublicKey, peerKyberPublicKey: b.kyberPublicKey);
    final envInit = Envelope.ratchet(
      from: aId, to: bId,
      message: await alice.encrypt(plain, associatedData: adAB),
      init: SessionInitBlock(ephemeralKey: init.ephemeralPublicKey, kyberCiphertext: init.kyberCiphertext),
    ).encode();
    final gm = await skm.encrypt('g', plain, gad);
    final envGroup = Envelope.senderKey(from: aId, groupId: 'g', iteration: gm.iteration,
        ciphertext: gm.ciphertext, signature: gm.signature).encode();
    final sealedEnv = await chan.seal(jsonEncode({'t': 'envelope', 'p': jsonDecode(envPlain)}));
    final sizes = <String>[
      'object,bytes',
      'inner_text_200B,${plain.length}',
      'hello_signed,${helloJson.length}',
      'envelope_ratchet,${envPlain.length}',
      'envelope_ratchet_with_init,${envInit.length}',
      'envelope_senderkey,${envGroup.length}',
      'sealed_frame_envelope,${sealedEnv.length}',
    ];

    final lines = ['operation,iterations,mean_ms,p95_ms', ...results.map((r) => r.csv())];
    await Directory('build').create(recursive: true);
    await File('build/crypto_bench.csv').writeAsString('${lines.join('\n')}\n');
    await File('build/crypto_sizes.csv').writeAsString('${sizes.join('\n')}\n');
    for (final l in [...lines, ...sizes]) {
      // ignore: avoid_print
      print(l);
    }
    expect(results, isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 30)));
}