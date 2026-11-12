import Foundation
#if canImport(CommonCrypto)
import CommonCrypto
#endif

/// BIP39 种子：PBKDF2-HMAC-SHA512(mnemonic, "mnemonic"+passphrase, 2048, 64)
public enum PBKDF2 {
    public enum Error: Swift.Error { case failed(Int32) }

    public static func hmacSHA512(password: String, salt: String,
                                  iterations: UInt32 = 2048, keyLength: Int = 64) throws -> Data {
        var out = Data(repeating: 0, count: keyLength)
        let pw = Array(password.utf8)
        let s = Array(salt.utf8)
        let status: Int32 = pw.withUnsafeBufferPointer { p in
            s.withUnsafeBufferPointer { sa in
                out.withUnsafeMutableBytes { o in
                    #if canImport(CommonCrypto)
                    return CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        p.baseAddress?.withMemoryRebound(to: CChar.self, capacity: pw.count) { $0 },
                        pw.count, sa.baseAddress, s.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512),
                        iterations,
                        o.baseAddress?.assumingMemoryBound(to: UInt8.self), keyLength)
                    #else
                    return -1
                    #endif
                }
            }
        }
        guard status == kCCSuccess else { throw Error.failed(status) }
        return out
    }
}
