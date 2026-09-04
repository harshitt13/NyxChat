/*
 * nyxpq - a thin, stable C ABI over PQClean's ML-KEM-768 (FIPS 203) for
 * NyxChat's dart:ffi binding (lib/core/crypto/mlkem_native.dart).
 *
 * Plain C99, no dependencies beyond the C library and the OS random source.
 * Every function returns NYXPQ_OK (0) on success or a negative NYXPQ_ERR_*
 * code; output buffers are only meaningful when 0 is returned.
 */
#ifndef NYXPQ_H
#define NYXPQ_H

#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32) || defined(__CYGWIN__)
#  if defined(NYXPQ_BUILD)
#    define NYXPQ_API __declspec(dllexport)
#  else
#    define NYXPQ_API
#  endif
#elif defined(__GNUC__) && (__GNUC__ >= 4)
#  define NYXPQ_API __attribute__((visibility("default")))
#else
#  define NYXPQ_API
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* FIPS 203 ML-KEM-768 encodings. */
#define NYXPQ_MLKEM768_PUBLICKEYBYTES     1184
#define NYXPQ_MLKEM768_SECRETKEYBYTES     2400
#define NYXPQ_MLKEM768_CIPHERTEXTBYTES    1088
#define NYXPQ_MLKEM768_SHAREDSECRETBYTES  32
#define NYXPQ_MLKEM768_KEYPAIR_COINBYTES  64  /* d || z */
#define NYXPQ_MLKEM768_ENC_COINBYTES      32  /* m */

#define NYXPQ_OK              0
#define NYXPQ_ERR_RNG        -1  /* the OS random source failed */
#define NYXPQ_ERR_PUBLICKEY  -2  /* FIPS 203 section 7.2 modulus check failed */
#define NYXPQ_ERR_SECRETKEY  -3  /* FIPS 203 section 7.3 hash check failed */
#define NYXPQ_ERR_NULL       -4  /* a required pointer was NULL */

/* Human-readable build identifier (algorithm, PQClean commit). */
NYXPQ_API const char *nyxpq_version(void);

/* ML-KEM.KeyGen: pk[1184], sk[2400]. Randomness comes from the OS. */
NYXPQ_API int nyxpq_mlkem768_keypair(uint8_t *pk, uint8_t *sk);

/* ML-KEM.Encaps: ct[1088], ss[32] from pk[1184]. Performs the FIPS 203
 * encapsulation-key (modulus) check before encapsulating. */
NYXPQ_API int nyxpq_mlkem768_enc(uint8_t *ct, uint8_t *ss, const uint8_t *pk);

/* ML-KEM.Decaps: ss[32] from ct[1088] and sk[2400]. Performs the FIPS 203
 * decapsulation-key (hash) check; a ciphertext that does not re-encrypt
 * yields the implicit-rejection secret (still returns NYXPQ_OK). */
NYXPQ_API int nyxpq_mlkem768_dec(uint8_t *ss, const uint8_t *ct, const uint8_t *sk);

/* Deterministic variants (ML-KEM.KeyGen_internal / Encaps_internal) for
 * known-answer tests only. coins are 64 bytes (d || z) and 32 bytes (m). */
NYXPQ_API int nyxpq_mlkem768_keypair_derand(uint8_t *pk, uint8_t *sk, const uint8_t *coins);
NYXPQ_API int nyxpq_mlkem768_enc_derand(uint8_t *ct, uint8_t *ss, const uint8_t *pk, const uint8_t *coins);

#ifdef __cplusplus
}
#endif

#endif /* NYXPQ_H */
