#include "sw_secp.h"
#include <secp256k1.h>
#include <secp256k1_recovery.h>
#include <string.h>
#include <openssl/evp.h>

static secp256k1_context *ctx(void) {
    static secp256k1_context *c = NULL;
    if (!c) c = secp256k1_context_create(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY);
    return c;
}

int sw_pubkey_uncompressed(const uint8_t priv32[32], uint8_t out65[65]) {
    secp256k1_pubkey pk;
    if (!secp256k1_ec_pubkey_create(ctx(), &pk, priv32)) return -1;
    size_t len = 65;
    if (!secp256k1_ec_pubkey_serialize(ctx(), out65, &len, &pk, SECP256K1_EC_UNCOMPRESSED)) return -2;
    return 0;
}

int sw_pubkey_compressed(const uint8_t priv32[32], uint8_t out33[33]) {
    secp256k1_pubkey pk;
    if (!secp256k1_ec_pubkey_create(ctx(), &pk, priv32)) return -1;
    size_t len = 33;
    if (!secp256k1_ec_pubkey_serialize(ctx(), out33, &len, &pk, SECP256K1_EC_COMPRESSED)) return -2;
    return 0;
}

int sw_privkey_tweak_add(const uint8_t priv32[32], const uint8_t tweak32[32], uint8_t out32[32]) {
    memcpy(out32, priv32, 32);
    if (!secp256k1_ec_seckey_tweak_add(ctx(), out32, tweak32)) return -1;
    return 0;
}

int sw_sign_recoverable(const uint8_t priv32[32], const uint8_t hash32[32],
                        uint8_t out64[64], int *recid) {
    secp256k1_ecdsa_recoverable_signature sig;
    if (!secp256k1_ecdsa_sign_recoverable(ctx(), &sig, hash32, priv32, NULL, NULL)) return -1;
    if (!secp256k1_ecdsa_recoverable_signature_serialize_compact(ctx(), out64, recid, &sig)) return -2;
    return 0;
}

int sw_ripemd160(const uint8_t *data, size_t len, uint8_t out20[20]) {
    unsigned int outlen = 0;
    EVP_MD_CTX *c = EVP_MD_CTX_new();
    if (!c) return -1;
    int ok = EVP_DigestInit_ex(c, EVP_ripemd160(), NULL) == 1
          && EVP_DigestUpdate(c, data, len) == 1
          && EVP_DigestFinal_ex(c, out20, &outlen) == 1;
    EVP_MD_CTX_free(c);
    return ok ? 0 : -2;
}
