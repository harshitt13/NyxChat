#!/usr/bin/env bash
# Builds the ML-KEM-768 (FIPS 203) host library from native/mlkem so that
# `flutter test` can load it:
#   Linux   -> build/native/libnyxpq.so
#   macOS   -> build/native/libnyxpq.dylib
#   MSYS/Git Bash on Windows (needs an x86_64 gcc) -> build/native/nyxpq.dll
# Works from any directory:  bash tool/build_native.sh
# Override the compiler with CC=... (or NYXPQ_CC=...).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/native/mlkem"
CLEAN="$SRC/pqclean/crypto_kem/ml-kem-768/clean"
COMMON="$SRC/pqclean/common"
OUT="$ROOT/build/native"
mkdir -p "$OUT"

CC="${CC:-${NYXPQ_CC:-}}"
if [ -z "$CC" ]; then
  for candidate in gcc cc clang; do
    if command -v "$candidate" >/dev/null 2>&1; then CC="$candidate"; break; fi
  done
fi
if [ -z "$CC" ]; then
  echo "nyxpq: no C compiler found (install gcc or clang, or set CC)" >&2
  exit 1
fi

EXTRA_LDFLAGS=""
case "$(uname -s)" in
  Darwin)
    LIB="$OUT/libnyxpq.dylib"; SHARED_FLAG="-dynamiclib" ;;
  MINGW*|MSYS*|CYGWIN*)
    LIB="$OUT/nyxpq.dll"; SHARED_FLAG="-shared"; EXTRA_LDFLAGS="-ladvapi32 -static-libgcc" ;;
  *)
    LIB="$OUT/libnyxpq.so"; SHARED_FLAG="-shared" ;;
esac

echo "nyxpq: building $LIB with $CC"
# shellcheck disable=SC2086
"$CC" -std=c99 -O2 -Wall -Wextra -fPIC -fvisibility=hidden -DNYXPQ_BUILD=1 \
  -I"$SRC" -I"$COMMON" -I"$CLEAN" \
  $SHARED_FLAG -o "$LIB" \
  "$SRC/nyxpq.c" "$COMMON/fips202.c" "$COMMON/randombytes.c" "$CLEAN"/*.c \
  $EXTRA_LDFLAGS
echo "nyxpq: built $LIB"
