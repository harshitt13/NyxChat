import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyxchat/core/crypto/crypto_utils.dart';

/// Seed for the deterministic fuzz runs. Override with `FUZZ_SEED=1234` (or
/// `FUZZ_SEED=random`) to explore new inputs; the seed is printed on failure.
int fuzzSeed() {
  final env = Platform.environment['FUZZ_SEED'];
  if (env != null) {
    if (env == 'random') {
      return DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    }
    final v = int.tryParse(env);
    if (v != null) return v;
  }
  return 0x5eed2026;
}

const int kRandomIterations = 500;
const int kMutationIterations = 1500;
const Duration kMaxParseTime = Duration(milliseconds: 200);

/// Bound for operations that legitimately do real cryptography (a ratchet
/// decrypt may derive hundreds of message keys in pure Dart); generous so
/// that concurrent test isolates do not make it flaky, still tight enough
/// to catch unbounded work.
const Duration kMaxCryptoTime = Duration(seconds: 1);

bool isFormat(Object e) => e is FormatException;

final String _backslash = String.fromCharCode(0x5c);

/// Seeded generator of random and structure-aware hostile inputs.
class Fuzzer {
  final int seed;
  final Random rng;
  Fuzzer(this.seed) : rng = Random(seed);

  static const String _alphabet =
      'abcdefghijklmnopqrstuvwxyzABCDEF0123456789 _-:.,/+=';
  static const List<int> _interestingInts = [
    0, 1, -1, 2, 255, 256, 65535, 65536, 1 << 20, (1 << 20) + 1, 1 << 30,
    (1 << 30) + 1, 1 << 31, 1 << 32, 1 << 40, 1 << 53, 1 << 62,
    9223372036854775807, -9223372036854775808, -(1 << 31),
  ];
  static const List<double> _interestingDoubles = [
    0.0, 1.0, -1.0, 3.0, 1e3, 1e300, -1e300, 0.5, 1.5e-10,
    9223372036854775808.0,
  ];
  static const List<String> _knownKeys = [
    'v', 'id', 'name', 'ik', 'sk', 'kpk', 'eph', 'nonce', 'port', 'caps',
    'kct', 'pn', 'sig', 'from', 'to', 'k', 'h', 'i', 'it', 's', 'c', 'e',
    't', 'p', 'ts', 'b', 'dh', 'n', 'fileId', 'd', 'key', 'size', 'chunks',
    'chunkSize', 'sha256', 'mime', 'g', 'ck', 'spk', 'ssk', 'skipped',
    'dhsPriv', 'dhsPub', 'dhr', 'rk', 'cks', 'ckr', 'ns', 'nr', 'verified',
    'first', 'last', 'changed', 'peerId', 'kind', 'payload', 'messageId',
    'attempts', 'created', 'next', 'nodeId', 'address', 'dhtPort',
    'displayName', 'lastSeen', 'senderId', 'iat', 'nyx',
  ];
  static const List<String> _oddStrings = [
    '', ' ', '\u0000', '\ufeff', '\u202e\u202e', 'NC-', 'null', '{}', '[]',
    '\u00e9', '\u4e2d\u6587', '\ud83d\ude00', 'true', '0x10', '1e999',
  ];

  int nextInt(int max) => rng.nextInt(max);
  bool chance(double p) => rng.nextDouble() < p;
  T pick<T>(List<T> items) => items[rng.nextInt(items.length)];

  Uint8List bytes(int length) {
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = rng.nextInt(256);
    }
    return out;
  }

  /// Length-biased random bytes: mostly short, sometimes up to [max].
  Uint8List randomBytes({int max = 4096}) =>
      bytes(chance(0.7) ? rng.nextInt(64) : rng.nextInt(max + 1));

  /// Random text mixing ASCII, control characters, non-ASCII code points
  /// and the occasional lone surrogate.
  String randomString({int max = 64}) {
    final len = chance(0.7) ? rng.nextInt(16) : rng.nextInt(max + 1);
    final sb = StringBuffer();
    for (var i = 0; i < len; i++) {
      switch (rng.nextInt(12)) {
        case 0:
          sb.writeCharCode(rng.nextInt(32));
        case 1:
          sb.writeCharCode(0x80 + rng.nextInt(0xd7ff - 0x80));
        case 2:
          sb.write(pick(_oddStrings));
        case 3:
          if (chance(0.2)) {
            sb.writeCharCode(0xd800 + rng.nextInt(0x800));
          } else {
            sb.write(_backslash);
          }
        default:
          sb.write(_alphabet[rng.nextInt(_alphabet.length)]);
      }
    }
    return sb.toString();
  }

  String hexString(int byteLength) => CryptoUtils.toHex(bytes(byteLength));
  String base64String(int byteLength) => base64Encode(bytes(byteLength));

  int randomInt() {
    if (chance(0.5)) return pick(_interestingInts);
    final v = rng.nextInt(1 << 32);
    return chance(0.5) ? v : -v;
  }

  double randomDouble() => pick(_interestingDoubles);

  /// A random JSON value, nesting at most [depth] levels.
  Object? randomValue(int depth) {
    switch (rng.nextInt(depth <= 0 ? 8 : 10)) {
      case 0:
        return null;
      case 1:
        return chance(0.5);
      case 2:
        return randomInt();
      case 3:
        return randomDouble();
      case 4:
        return randomString();
      case 5:
        return hexString(rng.nextInt(80));
      case 6:
        return base64String(rng.nextInt(80));
      case 7:
        return chance(0.5) ? pick(_oddStrings) : randomString(max: 2048);
      case 8:
        return List<Object?>.generate(
            rng.nextInt(6), (_) => randomValue(depth - 1));
      default:
        return randomMap(depth - 1);
    }
  }

  /// A random object using a mix of real field names and random keys.
  Map<String, dynamic> randomMap([int depth = 2]) {
    final m = <String, dynamic>{};
    final n = rng.nextInt(8);
    for (var i = 0; i < n; i++) {
      final key = chance(0.6) ? pick(_knownKeys) : randomString(max: 8);
      m[key] = randomValue(depth);
    }
    return m;
  }

  /// Like [randomMap], but half the time it is whatever a random JSON-ish
  /// string decodes to (when that happens to be an object).
  Map<String, dynamic> randomJsonMap() {
    if (chance(0.5)) return randomMap();
    try {
      final v = jsonDecode(jsonish());
      if (v is Map<String, dynamic>) return v;
    } on FormatException {
      // Not valid JSON: fall through to a synthetic map.
    }
    return randomMap();
  }

  Map<String, dynamic> deepMap(int depth) {
    Map<String, dynamic> m = <String, dynamic>{'x': 1};
    for (var i = 0; i < depth; i++) {
      m = <String, dynamic>{'a': m};
    }
    return m;
  }

  List<Object?> deepList(int depth) {
    List<Object?> l = <Object?>[1];
    for (var i = 0; i < depth; i++) {
      l = <Object?>[l];
    }
    return l;
  }

  /// A string that looks like JSON: real JSON of a random value, truncated
  /// JSON, or a soup of JSON tokens and escapes.
  String jsonish({int max = 512}) {
    switch (rng.nextInt(4)) {
      case 0:
        return jsonEncode(randomValue(3));
      case 1:
        return jsonEncode(randomMap(3));
      case 2:
        final s = jsonEncode(randomMap(2));
        return s.substring(0, rng.nextInt(s.length + 1));
      default:
        final tokens = <String>[
          '{', '}', '[', ']', '"', ':', ',', 'null', 'true', 'false', '1',
          '-', '1e999', 'NaN', 'a', ' ', '\n', '\t', _backslash,
          '${_backslash}u', '$_backslash"', '"v":3', '"k":"dr"',
          '"t":"envelope"', '"p":{}', '\u0000', '\u00e9', '\ud83d\ude00',
        ];
        final n = rng.nextInt(max ~/ 4);
        final sb = StringBuffer();
        for (var i = 0; i < n; i++) {
          sb.write(pick(tokens));
        }
        return sb.toString();
    }
  }

  /// Byte-level corruption of a valid encoding.
  Uint8List flipBytes(Uint8List src) {
    var out = Uint8List.fromList(src);
    switch (rng.nextInt(4)) {
      case 0:
        final flips = 1 + rng.nextInt(4);
        for (var k = 0; k < flips && out.isNotEmpty; k++) {
          out[rng.nextInt(out.length)] ^= 1 << rng.nextInt(8);
        }
      case 1:
        out = out.sublist(0, rng.nextInt(out.length + 1));
      case 2:
        final at = rng.nextInt(out.length + 1);
        out = Uint8List.fromList([
          ...out.sublist(0, at),
          ...bytes(1 + rng.nextInt(8)),
          ...out.sublist(at),
        ]);
      default:
        if (out.isNotEmpty) {
          out[rng.nextInt(out.length)] =
              pick(const [0, 0x22, 0x5c, 0x7b, 0x7d, 0xff, 0xc0, 0x0a]);
        }
    }
    return out;
  }

  Map<String, dynamic> deepCopy(Map<String, dynamic> m) =>
      jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

  /// Structure-aware mutation: one to three random edits of a valid object.
  Map<String, dynamic> mutate(Map<String, dynamic> valid) {
    final m = deepCopy(valid);
    final edits = 1 + rng.nextInt(3);
    for (var i = 0; i < edits; i++) {
      mutateInPlace(m);
    }
    return m;
  }

  void mutateInPlace(Map<String, dynamic> m) {
    final keys = m.keys.toList();
    if (keys.isEmpty) {
      m[randomString(max: 6)] = randomValue(1);
      return;
    }
    final key = pick(keys);
    final value = m[key];
    switch (rng.nextInt(12)) {
      case 0:
        m.remove(key);
      case 1:
        m[key] = null;
      case 2:
        m[key] = randomValue(1);
      case 3:
        m[chance(0.5) ? pick(_knownKeys) : randomString(max: 8)] =
            randomValue(2);
      case 4:
        m[key] = chance(0.5)
            ? deepMap(20 + rng.nextInt(400))
            : deepList(20 + rng.nextInt(400));
      case 5:
        m[key] = randomInt();
      case 6:
        m[key] = randomDouble();
      case 7:
        m[key] = pick(_oddStrings);
      case 8:
        m[key] = value is String ? mutateString(value) : randomString();
      case 9:
        m[key] = value is int ? mutateInt(value) : randomInt();
      case 10:
        if (value is Map<String, dynamic>) {
          mutateInPlace(value);
        } else if (value is List) {
          mutateList(value);
        } else {
          m[key] = <Object?>[value];
        }
      default:
        final other = pick(keys);
        m[key] = m[other];
        m[other] = value;
    }
  }

  void mutateList(List<dynamic> l) {
    switch (rng.nextInt(5)) {
      case 0:
        l.add(randomValue(1));
      case 1:
        if (l.isNotEmpty) l.removeAt(rng.nextInt(l.length));
      case 2:
        if (l.isNotEmpty) l[rng.nextInt(l.length)] = randomValue(1);
      case 3:
        l.addAll(
            List<Object?>.filled(rng.nextInt(5000), l.isEmpty ? 0 : l.first));
      default:
        if (l.isEmpty) return;
        final at = rng.nextInt(l.length);
        final item = l[at];
        if (item is Map<String, dynamic>) {
          mutateInPlace(item);
        } else if (item is List) {
          mutateList(item);
        } else if (item is String) {
          l[at] = mutateString(item);
        } else if (item is int) {
          l[at] = mutateInt(item);
        } else {
          l[at] = randomValue(1);
        }
    }
  }

  /// Mutations aimed at hex, base64, ids and free text.
  String mutateString(String s) {
    switch (rng.nextInt(11)) {
      case 0:
        return '';
      case 1:
        return s.substring(0, rng.nextInt(s.length + 1));
      case 2:
        return s + pick(const ['0', '=', 'z', 'Z', '\u00e9', ' ', '\u0000', '.']);
      case 3:
        if (s.isEmpty) return 'z';
        final at = rng.nextInt(s.length);
        return s.replaceRange(at, at + 1,
            pick(const ['z', 'G', '!', '=', ' ', '\u00e9', '\ud800', '-']));
      case 4:
        return s.toUpperCase();
      case 5:
        return s * (2 + rng.nextInt(4));
      case 6:
        return s + 'A' * (1 << (10 + rng.nextInt(7)));
      case 7:
        return hexString(rng.nextInt(1300));
      case 8:
        return base64String(rng.nextInt(1200));
      case 9:
        return pick(_oddStrings);
      default:
        return randomString(max: 512);
    }
  }

  int mutateInt(int v) {
    switch (rng.nextInt(8)) {
      case 0:
        return v + 1;
      case 1:
        return v - 1;
      case 2:
        return -v;
      case 3:
        return 0;
      case 4:
        return v * 1000;
      case 5:
        return v ^ 1;
      default:
        return pick(_interestingInts);
    }
  }
}

class FuzzStats {
  final int accepted;
  final int rejected;
  const FuzzStats(this.accepted, this.rejected);
}

String describeInput(Object? input) {
  String s;
  if (input is Uint8List) {
    s = 'bytes[${input.length}] ${CryptoUtils.toHex(input.take(64).toList())}';
  } else {
    try {
      s = jsonEncode(input);
    } catch (_) {
      s = input.toString();
    }
  }
  return s.length > 600 ? '${s.substring(0, 600)}...' : s;
}

/// Runs [parse] on [iterations] inputs from [gen]. Every call must either
/// succeed or throw an exception accepted by [allowed], and must finish
/// within [maxTime]. Failures report the seed and iteration so the exact
/// input can be regenerated.
Future<FuzzStats> runFuzz<I>(
  String name,
  Fuzzer f, {
  required int iterations,
  required I Function(int i) gen,
  required FutureOr<void> Function(I input) parse,
  required bool Function(Object error) allowed,
  Duration maxTime = kMaxParseTime,
}) async {
  var accepted = 0;
  var rejected = 0;
  for (var i = 0; i < iterations; i++) {
    final input = gen(i);
    final sw = Stopwatch()..start();
    try {
      await parse(input);
      accepted++;
    } catch (e, st) {
      if (!allowed(e)) {
        fail('[$name] seed=${f.seed} iteration=$i threw ${e.runtimeType}: '
            '$e\ninput: ${describeInput(input)}\n$st');
      }
      rejected++;
    }
    sw.stop();
    if (sw.elapsed > maxTime) {
      fail('[$name] seed=${f.seed} iteration=$i took '
          '${sw.elapsedMilliseconds}ms\ninput: ${describeInput(input)}');
    }
  }
  printOnFailure('[$name] seed=${f.seed}: $accepted accepted, '
      '$rejected rejected');
  return FuzzStats(accepted, rejected);
}
