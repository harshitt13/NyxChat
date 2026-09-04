import 'dart:typed_data';

/// Length-hiding padding for end-to-end plaintexts.
///
/// Plaintexts are padded to the next size bucket (256, 512, 1024, 2048, ...
/// bytes) before encryption so that ciphertext length reveals only the
/// bucket, not the exact message size. Layout: 4-byte big-endian length ||
/// plaintext || zeros.
class Padding {
  Padding._();

  static const int minBucket = 256;
  static const int maxPlaintext = 8 * 1024 * 1024;

  static int bucketFor(int length) {
    var bucket = minBucket;
    while (bucket < length + 4) {
      bucket <<= 1;
    }
    return bucket;
  }

  static Uint8List pad(List<int> plaintext) {
    if (plaintext.length > maxPlaintext) {
      throw ArgumentError('plaintext too large to pad');
    }
    final out = Uint8List(bucketFor(plaintext.length));
    final n = plaintext.length;
    out[0] = (n >> 24) & 0xff;
    out[1] = (n >> 16) & 0xff;
    out[2] = (n >> 8) & 0xff;
    out[3] = n & 0xff;
    out.setRange(4, 4 + n, plaintext);
    return out;
  }

  static Uint8List unpad(List<int> padded) {
    if (padded.length < 4) throw const FormatException('padding too short');
    final n = (padded[0] << 24) | (padded[1] << 16) | (padded[2] << 8) | padded[3];
    if (n < 0 || n > padded.length - 4) {
      throw const FormatException('invalid padding length');
    }
    return Uint8List.fromList(padded.sublist(4, 4 + n));
  }
}