import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// 从助记词派生各链地址。全程不缓存明文，调用方负责擦除入参。
public enum AddressDeriver {
    public enum Error: Swift.Error { case invalidMnemonic, deriveFailed }

    /// BIP39 → 64B seed（passphrase 默认空）
    public static func seed(mnemonic: String, passphrase: String = "") throws -> Data {
        try PBKDF2.hmacSHA512(password: mnemonic, salt: "mnemonic" + passphrase)
    }

    public static func derive(mnemonic: String, chain: ChainKind, index: UInt32 = 0) throws -> WalletAccount {
        let s = try seed(mnemonic: mnemonic)
        let path = path(for: chain, index: index)
        let root = try ExtKey.master(seed: s)
        let node = try root.derived(path: path)
        let address = try address(for: chain, key: node.privateKey)
        return WalletAccount(chain: chain, address: address, derivationPath: path,
                             label: chain.rawValue.capitalized)
    }

    public static func path(for chain: ChainKind, index: UInt32) -> String {
        switch chain {
        case .ethereum, .bnb, .polygon, .arbitrum, .tron:
            return "m/44'/60'/0'/0/\(index)"
        case .bitcoin:
            return "m/84'/0'/0'/0/\(index)"
        case .solana:
            return "m/44'/501'/\(index)'/0'"
        }
    }

    static func address(for chain: ChainKind, key: Data) throws -> String {
        switch chain {
        case .ethereum, .bnb, .polygon, .arbitrum:
            let pub = try Secp256k1.uncompressedPublicKey(key).dropFirst()   // 去 0x04
            let h = Keccak256.hash(Data(pub)).suffix(20)
            return "0x" + h.map { String(format: "%02x", $0) }.joined()
        case .tron:
            let pub = try Secp256k1.uncompressedPublicKey(key).dropFirst()
            let h = Keccak256.hash(Data(pub)).suffix(20)
            return Base58.checkEncode(Data([0x41]) + h)
        case .bitcoin:
            let pub = try Secp256k1.compressedPublicKey(key)
            let h160 = ripemd160(sha256(pub))
            return Bech32.encode(hrp: "bc", version: 0, program: h160)
        case .solana:
            // SLIP-0010 ed25519：由 32B 种子直接生成
            let sk = try Curve25519.Signing.PrivateKey(rawRepresentation: key.prefix(32))
            return Base58.encode(sk.publicKey.rawRepresentation)
        }
    }

    static func sha256(_ d: Data) -> Data {
        #if canImport(CryptoKit)
        return Data(SHA256.hash(data: d))
        #else
        return d
        #endif
    }

    /// RIPEMD160（BTC 地址需要；CommonCrypto 无此算法，用 CryptoKit 的 SHA256 打底再走 OpenSSL？）
    /// 这里用 Apple 内置的 RIPEMD160 缺失，因此走 Security 框架不现实 → 用纯 Swift 实现见 RIPEMD160.swift
    static func ripemd160(_ d: Data) -> Data { RIPEMD160.hash(d) }
}
