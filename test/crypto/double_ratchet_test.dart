import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyxchat/core/crypto/crypto_utils.dart';
import 'package:nyxchat/core/crypto/double_ratchet.dart';

Future<(DoubleRatchetSession, DoubleRatchetSession)> _pair() async {
  final shared = CryptoUtils.randomBytes(32);
  final bobKeys = await CryptoUtils.newX25519KeyPair();
  final alice = await DoubleRatchetSession.initAlice(
    sharedSecret: shared,
    bobRatchetPublicKey: CryptoUtils.publicKeyBytes(bobKeys),
  );
  final bob = await DoubleRatchetSession.initBob(
    sharedSecret: shared,
    bobRatchetKeyPair: bobKeys,
  );
  return (alice, bob);
}

void main() {
  group('DoubleRatchetSession', () {
    test('Bob cannot send before receiving', () async {
      final (alice, bob) = await _pair();
      expect(alice.canSend, isTrue);
      expect(bob.canSend, isFalse);
      expect(() => bob.encrypt([1, 2, 3]), throwsA(isA<RatchetException>()));
    });

    test('ping-pong conversation with DH ratchet steps', () async {
      final (alice, bob) = await _pair();
      for (var round = 0; round < 6; round++) {
        final m1 = await alice.encrypt('a$round'.codeUnits);
        expect(String.fromCharCodes(await bob.decrypt(m1)), 'a$round');
        final m2 = await bob.encrypt('b$round'.codeUnits);
        expect(String.fromCharCodes(await alice.decrypt(m2)), 'b$round');
      }
      // Every round rotates the ratchet keys.
      expect(alice.sentCount, 0);
      expect(alice.receivedCount, 1);
    });

    test('several messages in one direction then reply', () async {
      final (alice, bob) = await _pair();
      final msgs = [for (var i = 0; i < 5; i++) await alice.encrypt([i])];
      for (var i = 0; i < 5; i++) {
        expect(await bob.decrypt(msgs[i]), [i]);
      }
      final reply = await bob.encrypt([42]);
      expect(await alice.decrypt(reply), [42]);
    });

    test('out-of-order delivery uses skipped keys', () async {
      final (alice, bob) = await _pair();
      final m0 = await alice.encrypt([0]);
      final m1 = await alice.encrypt([1]);
      final m2 = await alice.encrypt([2]);
      expect(await bob.decrypt(m2), [2]);
      expect(bob.skippedKeyCount, 2);
      expect(await bob.decrypt(m0), [0]);
      expect(await bob.decrypt(m1), [1]);
      expect(bob.skippedKeyCount, 0);
    });

    test('out-of-order across a DH ratchet boundary', () async {
      final (alice, bob) = await _pair();
      final a0 = await alice.encrypt([0]);
      final a1 = await alice.encrypt([1]);
      expect(await bob.decrypt(a0), [0]);
      final b0 = await bob.encrypt([10]);
      expect(await alice.decrypt(b0), [10]);
      final a2 = await alice.encrypt([2]); // new chain
      expect(await bob.decrypt(a2), [2]);
      expect(await bob.decrypt(a1), [1]); // from previous chain
    });

    test('replayed message is rejected', () async {
      final (alice, bob) = await _pair();
      final m = await alice.encrypt([7]);
      expect(await bob.decrypt(m), [7]);
      await expectLater(bob.decrypt(m), throwsA(isA<RatchetException>()));
    });

    test('tampered ciphertext leaves state untouched', () async {
      final (alice, bob) = await _pair();
      final m = await alice.encrypt([1, 2, 3]);
      final tampered = Uint8List.fromList(m.ciphertext);
      tampered[0] ^= 0xFF;
      await expectLater(
        bob.decrypt(RatchetMessage(m.header, tampered)),
        throwsA(isA<RatchetException>()),
      );
      // Original still decrypts: the failed attempt did not advance state.
      expect(await bob.decrypt(m), [1, 2, 3]);
    });

    test('associated data is authenticated', () async {
      final (alice, bob) = await _pair();
      final m = await alice.encrypt([1], associatedData: 'to:bob'.codeUnits);
      await expectLater(
        bob.decrypt(m, associatedData: 'to:eve'.codeUnits),
        throwsA(isA<RatchetException>()),
      );
      expect(await bob.decrypt(m, associatedData: 'to:bob'.codeUnits), [1]);
    });

    test('too many skipped messages is refused', () async {
      final (alice, bob) = await _pair();
      RatchetMessage? last;
      for (var i = 0; i <= DoubleRatchetSession.maxSkip + 1; i++) {
        last = await alice.encrypt([i & 0xff]);
      }
      await expectLater(bob.decrypt(last!), throwsA(isA<RatchetException>()));
    });

    test('state survives JSON round trip', () async {
      final (alice, bob) = await _pair();
      final m0 = await alice.encrypt([0]);
      expect(await bob.decrypt(m0), [0]);
      final b0 = await bob.encrypt([1]);
      final alice2 = DoubleRatchetSession.fromJson(alice.toJson());
      final bob2 = DoubleRatchetSession.fromJson(bob.toJson());
      expect(await alice2.decrypt(b0), [1]);
      final a1 = await alice2.encrypt([2]);
      expect(await bob2.decrypt(a1), [2]);
    });

    test('header rejects malformed values', () {
      expect(() => RatchetHeader.fromJson({'dh': 'zz', 'pn': 0, 'n': 0}),
          throwsA(isA<FormatException>()));
      expect(
          () => RatchetHeader.fromJson(
              {'dh': CryptoUtils.toHex(Uint8List(32)), 'pn': -1, 'n': 0}),
          throwsA(isA<FormatException>()));
    });
  });
}