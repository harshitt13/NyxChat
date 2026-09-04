# native/mlkem - ML-KEM-768 (FIPS 203) for NyxChat

This directory holds the post-quantum KEM used by NyxChat's hybrid
X25519 + ML-KEM-768 handshake. It replaces the earlier pure-Dart
`package:post_quantum` (round-3 Kyber) with the **PQClean** C implementation
of **ML-KEM-768 as specified in FIPS 203**, reached from Dart through
`dart:ffi` (`lib/core/crypto/mlkem_native.dart`).

## Provenance

| Item | Value |
| --- | --- |
| Upstream | https://github.com/PQClean/PQClean |
| Commit | `0586a824fc0d49df0b6b6e9179d8d15d06d0974f` |
| Vendored on | 2026-09-05 |
| Implementation | `crypto_kem/ml-kem-768/clean` (portable C99 reference) |
| Also vendored | `common/fips202.[ch]` (SHA3/SHAKE), `common/randombytes.[ch]` (OS RNG), `common/compat.h` |
| Upstream claims (META.yml) | ML-KEM-768, NIST level 3, IND-CCA2, pk 1184 / sk 2400 / ct 1088 / ss 32 bytes |

Files under `pqclean/` are copied **verbatim**; do not edit them. To update,
clone PQClean, copy the same files, and bump the commit hash here, in
`LICENSE`, and in `NYXPQ_VERSION_STRING` (`nyxpq.c`).

## What `nyxpq.c` adds

`nyxpq.h` is the only ABI Dart uses (`nyxpq_mlkem768_keypair / enc / dec`,
`*_derand` for known-answer tests, `nyxpq_version`). The wrapper:

* draws randomness through PQClean's `randombytes()` and **checks its return
  value** (PQClean's own `crypto_kem_keypair/enc` ignore it), then calls the
  deterministic `*_derand` functions and wipes the coins;
* enforces the FIPS 203 input checks the reference leaves to callers: the
  encapsulation-key **modulus check** (section 7.2) and the decapsulation-key
  **hash check** (section 7.3). Failures return `NYXPQ_ERR_PUBLICKEY` /
  `NYXPQ_ERR_SECRETKEY`, surfaced in Dart as `FormatException`;
* exports only the `nyxpq_*` symbols (`__declspec(dllexport)` on Windows,
  default visibility on ELF/Mach-O with everything else hidden).

Randomness sources: Linux/Android `getrandom(2)`; Windows `CryptGenRandom`;
BSD/macOS `arc4random_buf`.

## Security claims (what to say, and what not to say)

* Algorithm: ML-KEM-768, FIPS 203 (final, August 2024). Verified against the
  NIST ACVP `ML-KEM-keyGen-FIPS203` / `ML-KEM-encapDecap-FIPS203` vectors in
  `test/crypto/mlkem_test.dart` (including an implicit-rejection case).
* Implementation: PQClean "clean" C reference - written to be constant-time
  (no secret-dependent branches or memory indices; constant-time compare and
  select in `verify.c`), tested by PQClean with sanitisers and Valgrind
  secret-independence checks. It uses no CPU-specific code.
* It is **not** a FIPS 140-3 validated module and has not been formally
  certified; the wrapper and the Dart binding are NyxChat code.
* NyxChat never relies on the KEM alone: its secret is always combined with
  X25519 via HKDF (see `lib/core/crypto/handshake.dart`).

## Building

* Android: `android/app/build.gradle.kts` points `externalNativeBuild` at
  `CMakeLists.txt`; Gradle builds `libnyxpq.so` for `arm64-v8a`,
  `armeabi-v7a` and `x86_64` and packs it into the APK.
* Host (for `flutter test`): `pwsh tool/build_native.ps1` (Windows, x64 only;
  uses an x86_64 gcc or MSVC) or `bash tool/build_native.sh` (Linux/macOS).
  Output goes to `build/native/`, which the Dart binding loads relative to the
  repository root. `NYXPQ_LIB=/path/to/lib` overrides the lookup.
