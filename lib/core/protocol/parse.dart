import 'dart:convert';
import 'dart:typed_data';

import '../crypto/crypto_utils.dart';

/// Helpers for parsing untrusted input: wire frames from peers and relays,
/// and persisted state that may have been corrupted.
///
/// Contract: a parser fed malformed input fails with a [FormatException]
/// (or a domain exception the caller expects, e.g. HandshakeException) and
/// never with a TypeError, RangeError, ArgumentError, StateError or
/// NoSuchMethodError. Those look like programming bugs, are not caught by
/// `on FormatException` handlers and, inside a link handler, can take the
/// whole connection down.
///
/// Rejecting early also bounds the work an attacker can make us do: every
/// accessor enforces a maximum length and integers are range-checked before
/// they reach code that allocates or loops.

/// Largest string accepted by the typed accessors unless the caller says
/// otherwise. Big enough for every legitimate field, small enough that a
/// hostile frame cannot make us copy megabytes around.
const int kDefaultMaxStringLength = 4096;

/// Largest base64 payload accepted by [requireBase64] unless the caller
/// passes a `length` or `maxBytes`. Matches the wire frame cap.
const int kDefaultMaxBase64Bytes = 1024 * 1024;

const int _maxInt = 0x7fffffffffffffff;

/// Runs [body]; crash-style errors raised by hostile input become a
/// [FormatException]. [FormatException] and exceptions that are not in the
/// conversion list (domain exceptions such as HandshakeException) propagate
/// unchanged.
T parseOr<T>(T Function() body, {String context = 'parse'}) {
  try {
    return body();
  } on FormatException {
    rethrow;
  } on TypeError catch (e) {
    throw FormatException('$context: ${_trim(e)}');
  } on ArgumentError catch (e) {
    // Includes RangeError and IndexError.
    throw FormatException('$context: ${_trim(e)}');
  } on StateError catch (e) {
    throw FormatException('$context: ${_trim(e)}');
  } on NoSuchMethodError catch (e) {
    throw FormatException('$context: ${_trim(e)}');
  } on UnsupportedError catch (e) {
    throw FormatException('$context: ${_trim(e)}');
  } on JsonUnsupportedObjectError catch (e) {
    throw FormatException('$context: ${_trim(e)}');
  } on AssertionError catch (e) {
    throw FormatException('$context: ${_trim(e)}');
  }
}

String _trim(Object error) {
  final s = error.toString();
  return s.length > 160 ? '${s.substring(0, 160)}...' : s;
}

/// Short, bounded description of a value for error messages (never echoes
/// a large hostile payload back into logs).
String describeValue(Object? value) {
  if (value == null || value is num || value is bool) return '$value';
  if (value is String) {
    return value.length > 32 ? '"${value.substring(0, 32)}..."' : '"$value"';
  }
  return value.runtimeType.toString();
}

/// Coerces [value] to a `Map<String, dynamic>`. JSON-decoded maps already
/// are one; maps built in code (e.g. `Map<String, int>`) are copied.
Map<String, dynamic> asJsonMap(Object? value, {String context = 'parse'}) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    for (final k in value.keys) {
      if (k is! String) throw FormatException('$context: non-string key');
    }
    return Map<String, dynamic>.from(value);
  }
  throw FormatException('$context: expected an object');
}

/// Decodes [text] as a JSON object; anything else is a [FormatException].
Map<String, dynamic> decodeJsonObject(String text, {String context = 'parse'}) =>
    parseOr(() => asJsonMap(jsonDecode(text), context: context),
        context: context);

String requireString(
  Map<String, dynamic> map,
  String key, {
  int minLength = 0,
  int maxLength = kDefaultMaxStringLength,
  String context = 'parse',
}) {
  final v = map[key];
  if (v is! String) {
    throw FormatException('$context: missing or non-string "$key"');
  }
  if (v.length < minLength || v.length > maxLength) {
    throw FormatException('$context: "$key" has bad length ${v.length}');
  }
  return v;
}

/// Null when the field is absent or null; a non-string value is an error.
String? optionalString(
  Map<String, dynamic> map,
  String key, {
  int minLength = 0,
  int maxLength = kDefaultMaxStringLength,
  String context = 'parse',
}) {
  if (map[key] == null) return null;
  return requireString(map, key,
      minLength: minLength, maxLength: maxLength, context: context);
}

/// Rejects doubles (JSON `1.0`, `1e3`, and integers too large for int64,
/// which the decoder turns into doubles), bools and out-of-range values.
int requireInt(
  Map<String, dynamic> map,
  String key, {
  int min = 0,
  int max = _maxInt,
  String context = 'parse',
}) {
  final v = map[key];
  if (v is! int) {
    throw FormatException('$context: missing or non-integer "$key"');
  }
  if (v < min || v > max) {
    throw FormatException('$context: "$key" out of range ($v)');
  }
  return v;
}

int? optionalInt(
  Map<String, dynamic> map,
  String key, {
  int min = 0,
  int max = _maxInt,
  String context = 'parse',
}) {
  if (map[key] == null) return null;
  return requireInt(map, key, min: min, max: max, context: context);
}

bool requireBool(Map<String, dynamic> map, String key,
    {String context = 'parse'}) {
  final v = map[key];
  if (v is! bool) throw FormatException('$context: missing or non-bool "$key"');
  return v;
}

bool? optionalBool(Map<String, dynamic> map, String key,
    {String context = 'parse'}) {
  if (map[key] == null) return null;
  return requireBool(map, key, context: context);
}

Map<String, dynamic> requireMap(Map<String, dynamic> map, String key,
    {String context = 'parse'}) {
  final v = map[key];
  if (v is! Map) throw FormatException('$context: missing or non-object "$key"');
  return asJsonMap(v, context: context);
}

Map<String, dynamic>? optionalMap(Map<String, dynamic> map, String key,
    {String context = 'parse'}) {
  if (map[key] == null) return null;
  return requireMap(map, key, context: context);
}

List<dynamic> requireList(
  Map<String, dynamic> map,
  String key, {
  int maxLength = 4096,
  String context = 'parse',
}) {
  final v = map[key];
  if (v is! List) throw FormatException('$context: missing or non-list "$key"');
  if (v.length > maxLength) {
    throw FormatException('$context: "$key" has too many items');
  }
  return v;
}

List<dynamic>? optionalList(
  Map<String, dynamic> map,
  String key, {
  int maxLength = 4096,
  String context = 'parse',
}) {
  if (map[key] == null) return null;
  return requireList(map, key, maxLength: maxLength, context: context);
}

List<String> requireStringList(
  Map<String, dynamic> map,
  String key, {
  int maxLength = 4096,
  int maxItemLength = kDefaultMaxStringLength,
  String context = 'parse',
}) {
  final raw = requireList(map, key, maxLength: maxLength, context: context);
  final out = <String>[];
  for (final item in raw) {
    if (item is! String || item.length > maxItemLength) {
      throw FormatException('$context: "$key" contains a bad item');
    }
    out.add(item);
  }
  return out;
}

/// Hex-encoded bytes. With [length] the value must decode to exactly that
/// many bytes (checked on the string length before any decoding work).
Uint8List requireHex(
  Map<String, dynamic> map,
  String key, {
  int? length,
  int maxLength = kDefaultMaxStringLength,
  String context = 'parse',
}) {
  final s = requireString(map, key,
      maxLength: length != null ? length * 2 : maxLength, context: context);
  if (length != null && s.length != length * 2) {
    throw FormatException('$context: "$key" must be $length bytes');
  }
  final bytes = CryptoUtils.fromHex(s);
  if (length != null && bytes.length != length) {
    throw FormatException('$context: "$key" must be $length bytes');
  }
  return bytes;
}

Uint8List? optionalHex(
  Map<String, dynamic> map,
  String key, {
  int? length,
  int maxLength = kDefaultMaxStringLength,
  String context = 'parse',
}) {
  if (map[key] == null) return null;
  return requireHex(map, key,
      length: length, maxLength: maxLength, context: context);
}

/// Base64-encoded bytes. The string length is bounded before decoding so
/// a hostile field cannot make us allocate more than [maxBytes].
Uint8List requireBase64(
  Map<String, dynamic> map,
  String key, {
  int? length,
  int maxBytes = kDefaultMaxBase64Bytes,
  String context = 'parse',
}) {
  final limit = length ?? maxBytes;
  final maxChars = 4 * ((limit + 2) ~/ 3);
  final s = requireString(map, key, maxLength: maxChars, context: context);
  final bytes = base64Decode(s);
  if (length != null && bytes.length != length) {
    throw FormatException('$context: "$key" must be $length bytes');
  }
  if (bytes.length > maxBytes) {
    throw FormatException('$context: "$key" too large');
  }
  return bytes;
}

/// ISO-8601 timestamp (as produced by `DateTime.toIso8601String`).
DateTime requireDateTime(Map<String, dynamic> map, String key,
    {String context = 'parse'}) {
  final s =
      requireString(map, key, minLength: 4, maxLength: 64, context: context);
  return DateTime.parse(s);
}

DateTime? optionalDateTime(Map<String, dynamic> map, String key,
    {String context = 'parse'}) {
  if (map[key] == null) return null;
  return requireDateTime(map, key, context: context);
}
