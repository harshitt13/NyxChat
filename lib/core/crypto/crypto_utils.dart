import 'dart:math';
import 'dart:typed_data';

import 'package:convert/convert.dart' as convert;
import 'package:cryptography/cryptography.dart';

/// Small, dependency-free helpers shared by every cryptographic module.
///
/// Everything here is deliberately boring: length checks, hex codecs,
/// constant-time comparison and thin wrappers over `package:cryptography`.
class CryptoUtils {
  CryptoUtils._();

  static final Random _rng = Random.secure();

  // Key / ciphertext sizes
  static const int x25519KeyLength = 32;
  static const int ed25519KeyLength = 32;
  static const int ed25519SignatureLength = 64;
  static const int kyber768PublicKeyLength = 1184;
  static const int kyber768CiphertextLength = 1088;
  static const int kyber768PrivateKeyLength = 2400;
  static const int aesGcmNonceLength = 12;
  static const int aesGcmTagLength = 16;
  static const int nonceLength = 16;

  /// Cryptographically secure random bytes.
  static Uint8List randomBytes(int length) {
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = _rng.nextInt(256);
    }
    return out;
  }

  static String toHex(List<int> bytes) => convert.hex.encode(bytes);

  /// Decode hex, rejecting anything that is not well-formed.
  static Uint8List fromHex(String input) {
    if (input.length.isOdd) {
      throw const FormatException('hex string has odd length');
    }
    for (var i = 0; i < input.length; i++) {
      final c = input.codeUnitAt(i);
      final isDigit = c >= 0x30 && c <= 0x39;
      final isLower = c >= 0x61 && c <= 0x66;
      final isUpper = c >= 0x41 && c <= 0x46;
      if (!isDigit && !isLower && !isUpper) {
        throw const FormatException('hex string contains non-hex characters');
      }
    }
    return Uint8List.fromList(convert.hex.decode(input));
  }

  /// Decode a hex-encoded key and enforce its exact length.
  static Uint8List decodeKey(
      String hexValue, int expectedLength, String label) {
    final bytes = fromHex(hexValue);
    if (bytes.length != expectedLength) {
      throw FormatException(
          '$label must be $expectedLength bytes, got ${bytes.length}');
    }
    return bytes;
  }

  /// Constant-time equality (does not leak where the first mismatch is).
  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static bool isAllZero(List<int> bytes) {
    var acc = 0;
    for (final b in bytes) {
      acc |= b;
    }
    return acc == 0;
  }

  static Uint8List concat(List<List<int>> parts) {
    var total = 0;
    for (final p in parts) {
      total += p.length;
    }
    final out = Uint8List(total);
    var offset = 0;
    for (final p in parts) {
      out.setRange(offset, offset + p.length, p);
      offset += p.length;
    }
    return out;
  }

  /// Length-prefixed encoding used for signature transcripts so that field
  /// boundaries are unambiguous.
  static Uint8List lengthPrefixed(List<List<int>> fields) {
    final builder = BytesBuilder(copy: false);
    for (final f in fields) {
      builder.add(int32be(f.length));
      builder.add(f);
    }
    return builder.toBytes();
  }

  static Uint8List int32be(int value) => Uint8List.fromList([
        (value >> 24) & 0xff,
        (value >> 16) & 0xff,
        (value >> 8) & 0xff,
        value & 0xff,
      ]);

  static Uint8List int64be(int value) => Uint8List.fromList([
        (value >> 56) & 0xff,
        (value >> 48) & 0xff,
        (value >> 40) & 0xff,
        (value >> 32) & 0xff,
        (value >> 24) & 0xff,
        (value >> 16) & 0xff,
        (value >> 8) & 0xff,
        value & 0xff,
      ]);

  static int readInt32be(List<int> bytes, int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];

  // Primitive wrappers

  static Future<Uint8List> sha256(List<int> data) async {
    final hash = await Sha256().hash(data);
    return Uint8List.fromList(hash.bytes);
  }

  static Future<Uint8List> hmacSha256(List<int> key, List<int> data) async {
    final mac =
        await Hmac.sha256().calculateMac(data, secretKey: SecretKey(key));
    return Uint8List.fromList(mac.bytes);
  }

  /// HKDF-SHA256 (RFC 5869).
  static Future<Uint8List> hkdf({
    required List<int> ikm,
    List<int> salt = const <int>[],
    required String info,
    int length = 32,
  }) async {
    final kdf = Hkdf(hmac: Hmac.sha256(), outputLength: length);
    final key = await kdf.deriveKey(
      secretKey: SecretKey(ikm),
      nonce: salt,
      info: info.codeUnits,
    );
    return Uint8List.fromList(await key.extractBytes());
  }

  /// X25519 Diffie-Hellman. Rejects the all-zero output produced by
  /// low-order peer points (RFC 7748 section 6.1).
  static Future<Uint8List> x25519(
      SimpleKeyPairData ourKeyPair, List<int> theirPublicKey) async {
    if (theirPublicKey.length != x25519KeyLength) {
      throw const FormatException('X25519 public key must be 32 bytes');
    }
    final shared = await X25519().sharedSecretKey(
      keyPair: ourKeyPair,
      remotePublicKey:
          SimplePublicKey(theirPublicKey, type: KeyPairType.x25519),
    );
    final bytes = Uint8List.fromList(await shared.extractBytes());
    if (isAllZero(bytes)) {
      throw StateError(
          'X25519 produced a zero shared secret (low-order point)');
    }
    return bytes;
  }

  static Future<SimpleKeyPairData> newX25519KeyPair() async {
    final pair = await X25519().newKeyPair();
    return SimpleKeyPairData(
      await pair.extractPrivateKeyBytes(),
      publicKey: await pair.extractPublicKey(),
      type: KeyPairType.x25519,
    );
  }

  static SimpleKeyPairData x25519KeyPairFromBytes(
      List<int> privateKey, List<int> publicKey) {
    return SimpleKeyPairData(
      privateKey,
      publicKey: SimplePublicKey(publicKey, type: KeyPairType.x25519),
      type: KeyPairType.x25519,
    );
  }

  static Future<SimpleKeyPairData> newEd25519KeyPair() async {
    final pair = await Ed25519().newKeyPair();
    return SimpleKeyPairData(
      await pair.extractPrivateKeyBytes(),
      publicKey: await pair.extractPublicKey(),
      type: KeyPairType.ed25519,
    );
  }

  static SimpleKeyPairData ed25519KeyPairFromBytes(
      List<int> privateKey, List<int> publicKey) {
    return SimpleKeyPairData(
      privateKey,
      publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
      type: KeyPairType.ed25519,
    );
  }

  static Uint8List publicKeyBytes(SimpleKeyPairData keyPair) =>
      Uint8List.fromList(keyPair.publicKey.bytes);

  static Future<Uint8List> ed25519Sign(
      SimpleKeyPairData signingKeyPair, List<int> message) async {
    final sig = await Ed25519().sign(message, keyPair: signingKeyPair);
    return Uint8List.fromList(sig.bytes);
  }

  static Future<bool> ed25519Verify({
    required List<int> publicKey,
    required List<int> message,
    required List<int> signature,
  }) async {
    if (publicKey.length != ed25519KeyLength ||
        signature.length != ed25519SignatureLength) {
      return false;
    }
    try {
      return await Ed25519().verify(
        message,
        signature: Signature(
          signature,
          publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// AES-256-GCM seal. Output = ciphertext || 16-byte tag.
  static Future<Uint8List> aesGcmEncrypt({
    required List<int> key,
    required List<int> nonce,
    required List<int> plaintext,
    List<int> aad = const <int>[],
  }) async {
    final box = await AesGcm.with256bits().encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: nonce,
      aad: aad,
    );
    return concat([box.cipherText, box.mac.bytes]);
  }

  /// AES-256-GCM open. Throws [SecretBoxAuthenticationError] on failure.
  static Future<Uint8List> aesGcmDecrypt({
    required List<int> key,
    required List<int> nonce,
    required List<int> ciphertextWithTag,
    List<int> aad = const <int>[],
  }) async {
    if (ciphertextWithTag.length < aesGcmTagLength) {
      throw const FormatException('ciphertext shorter than GCM tag');
    }
    final split = ciphertextWithTag.length - aesGcmTagLength;
    final box = SecretBox(
      ciphertextWithTag.sublist(0, split),
      nonce: nonce,
      mac: Mac(ciphertextWithTag.sublist(split)),
    );
    final plain = await AesGcm.with256bits().decrypt(
      box,
      secretKey: SecretKey(key),
      aad: aad,
    );
    return Uint8List.fromList(plain);
  }

  /// Best-effort wipe of a mutable byte buffer.
  static void wipe(List<int> bytes) {
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }
}