import Foundation
import Csecp256k1

/// libsecp256k1 的薄封装（只做派生与可恢复签名）
public enum Secp256k1 {
    public enum Error: Swift.Error { case badKey, badSign }

    public static func uncompressedPublicKey(_ priv: Data) throws -> Data {
        var out = [UInt8](repeating: 0, count: 65)
        let rc = priv.withUnsafeBytes { p in
            out.withUnsafeMutableBufferPointer { o in
                sw_pubkey_uncompressed(p.bindMemory(to: UInt8.self).baseAddress!, o.baseAddress!)
            }
        }
        guard rc == 0 else { throw Error.badKey }
        return Data(out)
    }

    public static func compressedPublicKey(_ priv: Data) throws -> Data {
        var out = [UInt8](repeating: 0, count: 33)
        let rc = priv.withUnsafeBytes { p in
            out.withUnsafeMutableBufferPointer { o in
                sw_pubkey_compressed(p.bindMemory(to: UInt8.self).baseAddress!, o.baseAddress!)
            }
        }
        guard rc == 0 else { throw Error.badKey }
        return Data(out)
    }

    /// BIP32 子密钥：k_child = (IL + k_par) mod n
    public static func addTweak(_ key: Data, tweak: Data) throws -> Data {
        var out = [UInt8](repeating: 0, count: 32)
        let rc = key.withUnsafeBytes { k in
            tweak.withUnsafeBytes { t in
                out.withUnsafeMutableBufferPointer { o in
                    sw_privkey_tweak_add(k.bindMemory(to: UInt8.self).baseAddress!,
                                         t.bindMemory(to: UInt8.self).baseAddress!,
                                         o.baseAddress!)
                }
            }
        }
        guard rc == 0 else { throw Error.badKey }
        return Data(out)
    }

    public static func signRecoverable(key: Data, hash: Data) throws -> (sig: Data, recid: Int) {
        var sig = [UInt8](repeating: 0, count: 64)
        var recid: Int32 = 0
        let rc = key.withUnsafeBytes { k in
            hash.withUnsafeBytes { h in
                sig.withUnsafeMutableBufferPointer { s in
                    withUnsafeMutablePointer(to: &recid) { r in
                        sw_sign_recoverable(k.bindMemory(to: UInt8.self).baseAddress!,
                                            h.bindMemory(to: UInt8.self).baseAddress!,
                                            s.baseAddress!, r)
                    }
                }
            }
        }
        guard rc == 0 else { throw Error.badSign }
        return (Data(sig), Int(recid))
    }
}
