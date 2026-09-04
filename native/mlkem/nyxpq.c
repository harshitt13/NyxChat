/*
 * nyxpq - thin C ABI over PQClean's ML-KEM-768 (FIPS 203). See nyxpq.h.
 *
 * Design notes
 *  - Randomness is drawn here through PQClean's randombytes() and its return
 *    value is checked (PQClean's own crypto_kem_keypair/enc ignore it), then
 *    the deterministic *_derand entry points are called. Coins are wiped.
 *  - FIPS 203 input checks that the PQClean reference leaves to the caller
 *    are enforced here: the encapsulation-key modulus check (section 7.2)
 *    and the decapsulation-key hash check (section 7.3).
 */
#ifndef NYXPQ_BUILD
#define NYXPQ_BUILD 1
#endif
#include "nyxpq.h"

#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "fips202.h"
#include "kem.h"
#include "params.h"
#include "randombytes.h"

#define NYXPQ_VERSION_STRING \
    "nyxpq 1.0.0; ML-KEM-768 (FIPS 203); PQClean clean @ 0586a824fc0d49df0b6b6e9179d8d15d06d0974f"

/* The sizes promised by nyxpq.h must be exactly PQClean's. */
typedef char nyxpq_assert_pk[(NYXPQ_MLKEM768_PUBLICKEYBYTES == PQCLEAN_MLKEM768_CLEAN_CRYPTO_PUBLICKEYBYTES) ? 1 : -1];
typedef char nyxpq_assert_sk[(NYXPQ_MLKEM768_SECRETKEYBYTES == PQCLEAN_MLKEM768_CLEAN_CRYPTO_SECRETKEYBYTES) ? 1 : -1];
typedef char nyxpq_assert_ct[(NYXPQ_MLKEM768_CIPHERTEXTBYTES == PQCLEAN_MLKEM768_CLEAN_CRYPTO_CIPHERTEXTBYTES) ? 1 : -1];
typedef char nyxpq_assert_ss[(NYXPQ_MLKEM768_SHAREDSECRETBYTES == PQCLEAN_MLKEM768_CLEAN_CRYPTO_BYTES) ? 1 : -1];
typedef char nyxpq_assert_kc[(NYXPQ_MLKEM768_KEYPAIR_COINBYTES == 2 * KYBER_SYMBYTES) ? 1 : -1];
typedef char nyxpq_assert_ec[(NYXPQ_MLKEM768_ENC_COINBYTES == KYBER_SYMBYTES) ? 1 : -1];

static void nyxpq_wipe(volatile uint8_t *p, size_t n) {
    while (n--) {
        *p++ = 0;
    }
}

/*
 * FIPS 203 section 7.2, "encapsulation key check": every 12-bit coefficient
 * of the encoded t-hat must be < q. This is equivalent to the standard's
 * ByteEncode12(ByteDecode12(ek)) == ek test. The trailing 32-byte seed rho
 * is not subject to any check.
 */
static int nyxpq_pk_modulus_check(const uint8_t *pk) {
    size_t i;
    for (i = 0; i < KYBER_POLYVECBYTES; i += 3) {
        uint16_t a = (uint16_t)(pk[i] | ((uint16_t)(pk[i + 1] & 0x0F) << 8));
        uint16_t b = (uint16_t)((pk[i + 1] >> 4) | ((uint16_t)pk[i + 2] << 4));
        if (a >= KYBER_Q || b >= KYBER_Q) {
            return NYXPQ_ERR_PUBLICKEY;
        }
    }
    return NYXPQ_OK;
}

/*
 * FIPS 203 section 7.3, "decapsulation key hash check": the H(ek) stored in
 * dk must match the ek embedded in dk. Layout: dk = dk_pke || ek || H(ek) || z.
 */
static int nyxpq_sk_hash_check(const uint8_t *sk) {
    uint8_t h[KYBER_SYMBYTES];
    const uint8_t *pk = sk + KYBER_INDCPA_SECRETKEYBYTES;
    const uint8_t *stored = sk + KYBER_SECRETKEYBYTES - 2 * KYBER_SYMBYTES;
    unsigned int diff = 0;
    size_t i;
    sha3_256(h, pk, KYBER_PUBLICKEYBYTES);
    for (i = 0; i < KYBER_SYMBYTES; i++) {
        diff |= (unsigned int)(h[i] ^ stored[i]);
    }
    return diff == 0 ? NYXPQ_OK : NYXPQ_ERR_SECRETKEY;
}

NYXPQ_API const char *nyxpq_version(void) {
    return NYXPQ_VERSION_STRING;
}

NYXPQ_API int nyxpq_mlkem768_keypair_derand(uint8_t *pk, uint8_t *sk, const uint8_t *coins) {
    if (pk == NULL || sk == NULL || coins == NULL) {
        return NYXPQ_ERR_NULL;
    }
    return PQCLEAN_MLKEM768_CLEAN_crypto_kem_keypair_derand(pk, sk, coins);
}

NYXPQ_API int nyxpq_mlkem768_keypair(uint8_t *pk, uint8_t *sk) {
    uint8_t coins[NYXPQ_MLKEM768_KEYPAIR_COINBYTES];
    int rc;
    if (pk == NULL || sk == NULL) {
        return NYXPQ_ERR_NULL;
    }
    if (randombytes(coins, sizeof coins) != 0) {
        nyxpq_wipe(coins, sizeof coins);
        return NYXPQ_ERR_RNG;
    }
    rc = PQCLEAN_MLKEM768_CLEAN_crypto_kem_keypair_derand(pk, sk, coins);
    nyxpq_wipe(coins, sizeof coins);
    return rc;
}

NYXPQ_API int nyxpq_mlkem768_enc_derand(uint8_t *ct, uint8_t *ss, const uint8_t *pk, const uint8_t *coins) {
    int rc;
    if (ct == NULL || ss == NULL || pk == NULL || coins == NULL) {
        return NYXPQ_ERR_NULL;
    }
    rc = nyxpq_pk_modulus_check(pk);
    if (rc != NYXPQ_OK) {
        return rc;
    }
    return PQCLEAN_MLKEM768_CLEAN_crypto_kem_enc_derand(ct, ss, pk, coins);
}

NYXPQ_API int nyxpq_mlkem768_enc(uint8_t *ct, uint8_t *ss, const uint8_t *pk) {
    uint8_t coins[NYXPQ_MLKEM768_ENC_COINBYTES];
    int rc;
    if (ct == NULL || ss == NULL || pk == NULL) {
        return NYXPQ_ERR_NULL;
    }
    rc = nyxpq_pk_modulus_check(pk);
    if (rc != NYXPQ_OK) {
        return rc;
    }
    if (randombytes(coins, sizeof coins) != 0) {
        nyxpq_wipe(coins, sizeof coins);
        return NYXPQ_ERR_RNG;
    }
    rc = PQCLEAN_MLKEM768_CLEAN_crypto_kem_enc_derand(ct, ss, pk, coins);
    nyxpq_wipe(coins, sizeof coins);
    return rc;
}

NYXPQ_API int nyxpq_mlkem768_dec(uint8_t *ss, const uint8_t *ct, const uint8_t *sk) {
    int rc;
    if (ss == NULL || ct == NULL || sk == NULL) {
        return NYXPQ_ERR_NULL;
    }
    rc = nyxpq_sk_hash_check(sk);
    if (rc != NYXPQ_OK) {
        return rc;
    }
    return PQCLEAN_MLKEM768_CLEAN_crypto_kem_dec(ss, ct, sk);
}
