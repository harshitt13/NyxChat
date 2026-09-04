import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Raw FIPS 203 encodings of an ML-KEM-768 key pair.
typedef MlKemKeyPair = ({Uint8List publicKey, Uint8List secretKey});

/// Ciphertext plus the 32-byte shared secret produced by encapsulation.
typedef MlKemEncapsulation = ({Uint8List ciphertext, Uint8List sharedSecret});

typedef _Fn2Native = Int32 Function(Pointer<Uint8>, Pointer<Uint8>);
typedef _Fn2 = int Function(Pointer<Uint8>, Pointer<Uint8>);
typedef _Fn3Native =
    Int32 Function(Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>);
typedef _Fn3 = int Function(Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>);
typedef _Fn4Native =
    Int32 Function(
      Pointer<Uint8>,
      Pointer<Uint8>,
      Pointer<Uint8>,
      Pointer<Uint8>,
    );
typedef _Fn4 =
    int Function(
      Pointer<Uint8>,
      Pointer<Uint8>,
      Pointer<Uint8>,
      Pointer<Uint8>,
    );
typedef _VersionNative = Pointer<Utf8> Function();
typedef _Version = Pointer<Utf8> Function();

class _Bindings {
  factory _Bindings(DynamicLibrary lib) {
    try {
      return _Bindings._(
        keypair: lib.lookupFunction<_Fn2Native, _Fn2>('nyxpq_mlkem768_keypair'),
        enc: lib.lookupFunction<_Fn3Native, _Fn3>('nyxpq_mlkem768_enc'),
        dec: lib.lookupFunction<_Fn3Native, _Fn3>('nyxpq_mlkem768_dec'),
        keypairDerand: lib.lookupFunction<_Fn3Native, _Fn3>(
          'nyxpq_mlkem768_keypair_derand',
        ),
        encDerand: lib.lookupFunction<_Fn4Native, _Fn4>(
          'nyxpq_mlkem768_enc_derand',
        ),
        version: lib.lookupFunction<_VersionNative, _Version>('nyxpq_version'),
      );
    } on ArgumentError catch (e) {
      throw StateError(
        'the loaded nyxpq library is missing a required export: $e',
      );
    }
  }

  _Bindings._({
    required this.keypair,
    required this.enc,
    required this.dec,
    required this.keypairDerand,
    required this.encDerand,
    required this.version,
  });

  final _Fn2 keypair;
  final _Fn3 enc;
  final _Fn3 dec;
  final _Fn3 keypairDerand;
  final _Fn4 encDerand;
  final _Version version;
}

/// ML-KEM-768 (FIPS 203) via PQClean's C implementation, bound with dart:ffi.
///
/// The native library (`nyxpq`) is opened lazily and cached per isolate, so
/// callers may freely use it from `Isolate.run`. All methods are synchronous
/// and copy their inputs into C memory that is zeroed and freed before they
/// return.
///
/// Library lookup order:
///   1. the `NYXPQ_LIB` environment variable (explicit path);
///   2. on Android, `libnyxpq.so` bundled in the APK by the Gradle CMake
///      build of `native/mlkem`;
///   3. `build/native/nyxpq.dll` / `libnyxpq.so` / `libnyxpq.dylib` relative
///      to the current directory, which is what `tool/build_native.ps1` and
///      `tool/build_native.sh` produce for `flutter test`.
class MlKem768 {
  MlKem768._();

  static const int publicKeyLength = 1184;
  static const int secretKeyLength = 2400;
  static const int ciphertextLength = 1088;
  static const int sharedSecretLength = 32;

  /// `d || z` for [keypairDerand].
  static const int keypairCoinsLength = 64;

  /// `m` for [encapsulateDerand].
  static const int encapsCoinsLength = 32;

  static _Bindings? _cached;

  static _Bindings get _b => _cached ??= _Bindings(_open());

  /// Whether the native library can be loaded in this isolate.
  static bool get isAvailable {
    try {
      _b;
      return true;
    } on Object {
      return false;
    }
  }

  /// Build identifier reported by the native library.
  static String get version => _b.version().toDartString();

  static MlKemKeyPair keypair() {
    final b = _b;
    final pk = calloc<Uint8>(publicKeyLength);
    final sk = calloc<Uint8>(secretKeyLength);
    try {
      _check(b.keypair(pk, sk), 'key generation');
      return (
        publicKey: _copyOut(pk, publicKeyLength),
        secretKey: _copyOut(sk, secretKeyLength),
      );
    } finally {
      _wipeAndFree(sk, secretKeyLength);
      calloc.free(pk);
    }
  }

  static MlKemEncapsulation encapsulate(Uint8List publicKey) {
    _requireLength(publicKey, publicKeyLength, 'publicKey');
    final b = _b;
    final pk = calloc<Uint8>(publicKeyLength);
    final ct = calloc<Uint8>(ciphertextLength);
    final ss = calloc<Uint8>(sharedSecretLength);
    try {
      pk.asTypedList(publicKeyLength).setAll(0, publicKey);
      _check(b.enc(ct, ss, pk), 'encapsulation');
      return (
        ciphertext: _copyOut(ct, ciphertextLength),
        sharedSecret: _copyOut(ss, sharedSecretLength),
      );
    } finally {
      _wipeAndFree(ss, sharedSecretLength);
      calloc.free(ct);
      calloc.free(pk);
    }
  }

  static Uint8List decapsulate(Uint8List ciphertext, Uint8List secretKey) {
    _requireLength(ciphertext, ciphertextLength, 'ciphertext');
    _requireLength(secretKey, secretKeyLength, 'secretKey');
    final b = _b;
    final ct = calloc<Uint8>(ciphertextLength);
    final sk = calloc<Uint8>(secretKeyLength);
    final ss = calloc<Uint8>(sharedSecretLength);
    try {
      ct.asTypedList(ciphertextLength).setAll(0, ciphertext);
      sk.asTypedList(secretKeyLength).setAll(0, secretKey);
      _check(b.dec(ss, ct, sk), 'decapsulation');
      return _copyOut(ss, sharedSecretLength);
    } finally {
      _wipeAndFree(ss, sharedSecretLength);
      _wipeAndFree(sk, secretKeyLength);
      calloc.free(ct);
    }
  }

  /// Deterministic ML-KEM.KeyGen_internal(d, z) - known-answer tests only.
  static MlKemKeyPair keypairDerand(Uint8List coins) {
    _requireLength(coins, keypairCoinsLength, 'coins');
    final b = _b;
    final pk = calloc<Uint8>(publicKeyLength);
    final sk = calloc<Uint8>(secretKeyLength);
    final c = calloc<Uint8>(keypairCoinsLength);
    try {
      c.asTypedList(keypairCoinsLength).setAll(0, coins);
      _check(b.keypairDerand(pk, sk, c), 'deterministic key generation');
      return (
        publicKey: _copyOut(pk, publicKeyLength),
        secretKey: _copyOut(sk, secretKeyLength),
      );
    } finally {
      _wipeAndFree(c, keypairCoinsLength);
      _wipeAndFree(sk, secretKeyLength);
      calloc.free(pk);
    }
  }

  /// Deterministic ML-KEM.Encaps_internal(ek, m) - known-answer tests only.
  static MlKemEncapsulation encapsulateDerand(
    Uint8List publicKey,
    Uint8List coins,
  ) {
    _requireLength(publicKey, publicKeyLength, 'publicKey');
    _requireLength(coins, encapsCoinsLength, 'coins');
    final b = _b;
    final pk = calloc<Uint8>(publicKeyLength);
    final ct = calloc<Uint8>(ciphertextLength);
    final ss = calloc<Uint8>(sharedSecretLength);
    final c = calloc<Uint8>(encapsCoinsLength);
    try {
      pk.asTypedList(publicKeyLength).setAll(0, publicKey);
      c.asTypedList(encapsCoinsLength).setAll(0, coins);
      _check(b.encDerand(ct, ss, pk, c), 'deterministic encapsulation');
      return (
        ciphertext: _copyOut(ct, ciphertextLength),
        sharedSecret: _copyOut(ss, sharedSecretLength),
      );
    } finally {
      _wipeAndFree(c, encapsCoinsLength);
      _wipeAndFree(ss, sharedSecretLength);
      calloc.free(ct);
      calloc.free(pk);
    }
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  static void _requireLength(Uint8List bytes, int expected, String name) {
    if (bytes.length != expected) {
      throw ArgumentError.value(
        bytes.length,
        name,
        'must be exactly $expected bytes',
      );
    }
  }

  static Uint8List _copyOut(Pointer<Uint8> p, int length) =>
      Uint8List.fromList(p.asTypedList(length));

  static void _wipeAndFree(Pointer<Uint8> p, int length) {
    p.asTypedList(length).fillRange(0, length, 0);
    calloc.free(p);
  }

  /// Maps nyxpq return codes (see native/mlkem/nyxpq.h) onto exceptions.
  static void _check(int rc, String operation) {
    switch (rc) {
      case 0:
        return;
      case -2:
        throw const FormatException(
          'ML-KEM-768 public key rejected by the FIPS 203 modulus check',
        );
      case -3:
        throw const FormatException(
          'ML-KEM-768 secret key failed the FIPS 203 hash check',
        );
      case -1:
        throw StateError(
          'ML-KEM-768 $operation failed: the system random generator '
          'returned an error',
        );
      default:
        throw StateError('ML-KEM-768 $operation failed with native error $rc');
    }
  }

  static String get _hostLibraryName {
    if (Platform.isWindows) return 'nyxpq.dll';
    if (Platform.isMacOS) return 'libnyxpq.dylib';
    return 'libnyxpq.so';
  }

  static DynamicLibrary _openPath(String path, String origin) {
    try {
      return DynamicLibrary.open(path);
    } on Object catch (e) {
      throw StateError(
        'nyxpq library ($origin) could not be loaded from '
        '"$path": $e',
      );
    }
  }

  static DynamicLibrary _open() {
    final override = Platform.environment['NYXPQ_LIB'];
    if (override != null && override.isNotEmpty) {
      return _openPath(override, 'NYXPQ_LIB');
    }
    if (Platform.isAndroid) {
      return _openPath('libnyxpq.so', 'bundled in the APK');
    }
    final sep = Platform.pathSeparator;
    final candidate =
        '${Directory.current.path}${sep}build${sep}native$sep$_hostLibraryName';
    if (File(candidate).existsSync()) {
      return _openPath(candidate, 'host build');
    }
    throw StateError(
      'The ML-KEM-768 native library ($_hostLibraryName) was not found at '
      '"$candidate". Build it from the repository root with '
      '"pwsh tool/build_native.ps1" (Windows) or "bash tool/build_native.sh" '
      '(Linux/macOS), or point NYXPQ_LIB at an existing build.',
    );
  }
}
