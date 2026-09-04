import 'package:flutter_test/flutter_test.dart';
import 'package:nyxchat/core/crypto/crypto_utils.dart';
import 'package:nyxchat/core/crypto/double_ratchet.dart';

import 'fuzz_support.dart';

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

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _sameHeader(RatchetHeader a, RatchetHeader b) =>
    a.pn == b.pn && a.n == b.n && _sameBytes(a.dh, b.dh);

bool _ratchetOrFormat(Object e) =>
    e is RatchetException || e is FormatException;

void main() {
  final seed = fuzzSeed();

  test('DoubleRatchetSession.decrypt survives fuzzed headers and ciphertext',
      () async {
    printOnFailure('FUZZ_SEED=$seed');
    final f = Fuzzer(seed);
    final (alice, bob) = await _pair();
    final ad = 'fuzz-associated-data'.codeUnits;

    // Warm up: a few round trips so Bob has a receiving chain, a DH key
    // history and some skipped message keys that must survive the fuzzing.
    final heldBack = <RatchetMessage>[];
    for (var r = 0; r < 3; r++) {
      final first = await alice.encrypt([r, 0], associatedData: ad);
      heldBack.add(await alice.encrypt([r, 1], associatedData: ad));
      final third = await alice.encrypt([r, 2], associatedData: ad);
      expect(await bob.decrypt(first, associatedData: ad), [r, 0]);
      expect(await bob.decrypt(third, associatedData: ad), [r, 2]);
      final reply = await bob.encrypt([r, 3], associatedData: ad);
      expect(await alice.decrypt(reply, associatedData: ad), [r, 3]);
    }
    expect(bob.skippedKeyCount, 3);

    var rejected = 0;
    var identical = 0;
    for (var i = 0; i < kMutationIterations; i++) {
      final plaintext = [i & 0xff, (i >> 8) & 0xff];
      final genuine = await alice.encrypt(plaintext, associatedData: ad);
      var header = genuine.header;
      var ciphertext = genuine.ciphertext;
      switch (f.nextInt(6)) {
        case 0:
          try {
            header = RatchetHeader.fromJson(f.mutate(genuine.header.toJson()));
          } on FormatException {
            // Rejected before the ratchet saw it; fuzz the ciphertext instead.
            ciphertext = f.flipBytes(ciphertext);
          }
        case 1:
          // Unknown ratchet key with arbitrary counters (forces a DH step).
          header = RatchetHeader(
              dh: f.bytes(32), pn: f.nextInt(600), n: f.nextInt(600));
        case 2:
          // Known key, shifted counters (skipped-key bookkeeping).
          header = RatchetHeader(
              dh: genuine.header.dh,
              pn: genuine.header.pn,
              n: (genuine.header.n + f.nextInt(600) - 300).clamp(0, 1 << 30));
        case 3:
          // A key Bob holds skipped keys for, with a bad ciphertext.
          header = heldBack[f.nextInt(heldBack.length)].header;
          ciphertext = f.randomBytes(max: 64);
        case 4:
          ciphertext = f.randomBytes(max: 256);
        default:
          ciphertext = f.flipBytes(ciphertext);
      }
      final same = _sameHeader(header, genuine.header) &&
          _sameBytes(ciphertext, genuine.ciphertext);
      final sw = Stopwatch()..start();
      var ok = false;
      try {
        final plain = await bob.decrypt(RatchetMessage(header, ciphertext),
            associatedData: ad);
        ok = true;
        expect(same, isTrue,
            reason: 'seed=$seed iteration=$i: a modified message decrypted');
        expect(plain, plaintext);
      } catch (e, st) {
        if (e is TestFailure) rethrow;
        if (!_ratchetOrFormat(e)) {
          fail('seed=$seed iteration=$i: decrypt threw ${e.runtimeType}: '
              '$e\n$st');
        }
        rejected++;
      }
      sw.stop();
      expect(sw.elapsed, lessThan(kMaxCryptoTime),
          reason: 'seed=$seed iteration=$i: decrypt took '
              '${sw.elapsedMilliseconds}ms');
      if (ok) {
        identical++;
      } else {
        // The rejected attempt must not have touched the session state.
        expect(await bob.decrypt(genuine, associatedData: ad), plaintext,
            reason: 'seed=$seed iteration=$i: genuine message no longer '
                'decrypts after a rejected one');
      }
      if (i % 100 == 99) {
        // Turn the DH ratchet in both directions now and then.
        final reply = await bob.encrypt([9, 9], associatedData: ad);
        expect(await alice.decrypt(reply, associatedData: ad), [9, 9]);
      }
    }
    // Skipped keys from the warm-up are still intact.
    expect(bob.skippedKeyCount, 3);
    for (var r = 0; r < heldBack.length; r++) {
      expect(await bob.decrypt(heldBack[r], associatedData: ad), [r, 1]);
    }
    expect(bob.skippedKeyCount, 0);
    expect(rejected, greaterThan(kMutationIterations ~/ 2));
    printOnFailure('rejected=$rejected identical=$identical');
  });

  test('a persisted session survives fuzzing of its own JSON', () async {
    final f = Fuzzer(seed);
    final (alice, bob) = await _pair();
    final m = await alice.encrypt([1]);
    expect(await bob.decrypt(m), [1]);
    final json = bob.toJson();
    for (var i = 0; i < kRandomIterations; i++) {
      try {
        DoubleRatchetSession.fromJson(f.mutate(json));
      } on FormatException {
        // Expected for anything that is no longer a valid state.
      } catch (e) {
        fail('seed=$seed iteration=$i: fromJson threw ${e.runtimeType}: $e');
      }
    }
    final restored = DoubleRatchetSession.fromJson(json);
    final reply = await restored.encrypt([2]);
    expect(await alice.decrypt(reply), [2]);
  });
}
