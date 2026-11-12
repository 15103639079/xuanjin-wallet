import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

public enum Base58 {
    private static let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")

    public static func encode(_ data: Data) -> String {
        var digits: [UInt8] = [0]
        for byte in data {
            var carry = Int(byte)
            for i in 0..<digits.count {
                carry += Int(digits[i]) << 8
                digits[i] = UInt8(carry % 58)
                carry /= 58
            }
            while carry > 0 { digits.append(UInt8(carry % 58)); carry /= 58 }
        }
        var out = ""
        for byte in data.prefix(while: { $0 == 0 }) { _ = byte; out.append("1") }
        for d in digits.reversed() { out.append(alphabet[Int(d)]) }
        return out
    }

    public static func decode(_ string: String) -> Data? {
        var bytes: [UInt8] = [0]
        for ch in string {
            guard let idx = alphabet.firstIndex(of: ch) else { return nil }
            var carry = idx
            for i in 0..<bytes.count {
                carry += Int(bytes[i]) * 58
                bytes[i] = UInt8(carry & 0xff)
                carry >>= 8
            }
            while carry > 0 { bytes.append(UInt8(carry & 0xff)); carry >>= 8 }
        }
        for ch in string.prefix(while: { $0 == "1" }) { _ = ch; bytes.append(0) }
        return Data(bytes.reversed())
    }

    /// Base58Check：4 字节双 SHA256 校验
    public static func checkEncode(_ payload: Data) -> String {
        let h1 = sha256(payload), h2 = sha256(h1)
        return encode(payload + h2.prefix(4))
    }

    static func sha256(_ d: Data) -> Data {
        #if canImport(CryptoKit)
        return Data(SHA256.hash(data: d))
        #else
        return d
        #endif
    }
}
