import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// BIP32 扩展密钥（只实现私钥派生，够钱包用）
public struct ExtKey: Sendable {
    public let privateKey: Data      // 32B
    public let chainCode: Data       // 32B

    public init(privateKey: Data, chainCode: Data) {
        self.privateKey = privateKey; self.chainCode = chainCode
    }

    public static func master(seed: Data) throws -> ExtKey {
        let I = hmacSHA512(key: Data("Bitcoin seed".utf8), data: seed)
        return ExtKey(privateKey: I.prefix(32), chainCode: I.suffix(32))
    }

    public func derived(index: UInt32) throws -> ExtKey {
        let hardened = index >= 0x8000_0000
        var data = Data()
        if hardened {
            data.append(0x00); data.append(privateKey)
        } else {
            data.append(try Secp256k1.compressedPublicKey(privateKey))
        }
        var be = index.bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
        let I = ExtKey.hmacSHA512(key: chainCode, data: data)
        let IL = I.prefix(32), IR = I.suffix(32)
        let child = try Secp256k1.addTweak(privateKey, tweak: Data(IL))
        return ExtKey(privateKey: child, chainCode: Data(IR))
    }

    /// 解析 "m/44'/60'/0'/0/0"
    public func derived(path: String) throws -> ExtKey {
        var node = self
        let comps = path.split(separator: "/").dropFirst()   // 丢掉 m
        for c in comps {
            let hardened = c.hasSuffix("'") || c.hasSuffix("h")
            let numStr = hardened ? c.dropLast() : c
            guard let n = UInt32(numStr), n < 0x8000_0000 else { throw Secp256k1.Error.badKey }
            node = try node.derived(index: hardened ? n + 0x8000_0000 : n)
        }
        return node
    }

    static func hmacSHA512(key: Data, data: Data) -> Data {
        #if canImport(CryptoKit)
        let mac = HMAC<SHA512>.authenticationCode(for: data, using: SymmetricKey(data: key))
        return Data(mac)
        #else
        return Data()
        #endif
    }
}
