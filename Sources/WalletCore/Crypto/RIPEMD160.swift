import Foundation
import Csecp256k1

/// RIPEMD-160：走 OpenSSL（libcrypto），避免自实现出错。
public enum RIPEMD160 {
    public static func hash(_ data: Data) -> Data {
        var out = [UInt8](repeating: 0, count: 20)
        let rc = data.withUnsafeBytes { p in
            out.withUnsafeMutableBufferPointer { o in
                sw_ripemd160(p.bindMemory(to: UInt8.self).baseAddress, data.count, o.baseAddress!)
            }
        }
        precondition(rc == 0, "ripemd160 failed")
        return Data(out)
    }
}
