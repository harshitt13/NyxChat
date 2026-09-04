import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyxchat/core/crypto/crypto_utils.dart';
import 'package:nyxchat/core/crypto/secure_channel.dart';

import 'fuzz_support.dart';

Future<(SecureChannel, SecureChannel)> _pair() async {
  final master = CryptoUtils.randomBytes(32);
  final a = await SecureChannel.fromMasterSecret(
      masterSecret: master, isInitiator: true);
  final b = await SecureChannel.fromMasterSecret(
      masterSecret: master, isInitiator: false);
  return (a, b);
}

void main() {
  final seed = fuzzSeed();

  test('SecureChannel.open survives fuzzed frames', () async {
    printOnFailure('FUZZ_SEED=$seed');
    final f = Fuzzer(seed);
    final (a, b) = await _pair();
    var accepted = 0;
    for (var i = 0; i < kMutationIterations; i++) {
      // Lone surrogates are (correctly) replaced by U+FFFD on the wire, so
      // compare against the UTF-8 round trip of the random text.
      final line =
          utf8.decode(utf8.encode('frame $i ${f.randomString(max: 200)}'));
      final frame = jsonDecode(await a.seal(line)) as Map<String, dynamic>;
      final hostile = switch (i % 3) {
        0 => f.randomJsonMap(),
        1 => f.mutate(frame),
        _ => f.deepCopy(f.mutate(frame)),
      };
      final sw = Stopwatch()..start();
      var ok = false;
      try {
        final out = await b.open(hostile);
        ok = true;
        // Only a byte-identical frame can authenticate.
        expect(out, line, reason: 'seed=$seed iteration=$i');
      } catch (e, st) {
        if (e is TestFailure) rethrow;
        if (e is! StateError && e is! FormatException) {
          fail('seed=$seed iteration=$i: open threw ${e.runtimeType}: $e\n'
              'input: ${describeInput(hostile)}\n$st');
        }
      }
      sw.stop();
      expect(sw.elapsed, lessThan(kMaxCryptoTime),
          reason: 'seed=$seed iteration=$i: open took '
              '${sw.elapsedMilliseconds}ms');
      if (ok) {
        accepted++;
      } else {
        // A rejected frame must not consume the counter: the genuine frame
        // still opens right after it.
        expect(await b.open(frame), line,
            reason: 'seed=$seed iteration=$i: genuine frame no longer opens '
                'after a hostile one');
      }
    }
    expect(b.framesReceived, a.framesSent);
    printOnFailure('accepted=$accepted');
  });

  test('SecureChannel.open error classes', () async {
    final (a, b) = await _pair();
    final frame = jsonDecode(await a.seal('x')) as Map<String, dynamic>;
    final e = frame['e'] as String;
    // Malformed frames are FormatException.
    await expectLater(b.open({'c': 'zero', 'e': e}), throwsFormatException);
    await expectLater(b.open({'c': -1, 'e': e}), throwsFormatException);
    await expectLater(b.open({'c': 0.0, 'e': e}), throwsFormatException);
    await expectLater(
        b.open({'c': 0, 'e': 'not base64!'}), throwsFormatException);
    await expectLater(b.open({'c': 0, 'e': base64Encode([1, 2, 3])}),
        throwsFormatException);
    await expectLater(b.open({'c': 0}), throwsFormatException);
    await expectLater(
        b.open({'c': 0, 'e': <String>[e]}), throwsFormatException);
    // Reorder, tamper and replay are StateError.
    await expectLater(b.open({'c': 1, 'e': e}), throwsA(isA<StateError>()));
    final tampered =
        base64Encode(base64Decode(e).map((x) => x ^ 1).toList());
    await expectLater(
        b.open({'c': 0, 'e': tampered}), throwsA(isA<StateError>()));
    expect(await b.open(frame), 'x');
    await expectLater(b.open(frame), throwsA(isA<StateError>()));
  });
}
