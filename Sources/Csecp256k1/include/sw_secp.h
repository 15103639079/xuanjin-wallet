#ifndef SW_SECP_H
#define SW_SECP_H
#include <stddef.h>
#include <stdint.h>
/// RIPEMD-160（BTC 地址用），输出 20 字节。成功返回 0。
int sw_ripemd160(const uint8_t *data, size_t len, uint8_t out20[20]);
#ifdef __cplusplus
extern "C" {
#endif

/// 由私钥生成 65 字节未压缩公钥（0x04||X||Y）。成功返回 0。
int sw_pubkey_uncompressed(const uint8_t priv32[32], uint8_t out65[65]);
/// 由私钥生成 33 字节压缩公钥。成功返回 0。
int sw_pubkey_compressed(const uint8_t priv32[32], uint8_t out33[33]);
/// 私钥 + tweak32 相加（BIP32 子密钥），结果写回 out32。成功返回 0。
int sw_privkey_tweak_add(const uint8_t priv32[32], const uint8_t tweak32[32], uint8_t out32[32]);
/// 可恢复签名：输出 64 字节紧凑签名与 recid(0..3)。成功返回 0。
int sw_sign_recoverable(const uint8_t priv32[32], const uint8_t hash32[32],
                        uint8_t out64[64], int *recid);
#ifdef __cplusplus
}
#endif
#endif
