import Foundation

/// BIP173 Bech32（用于 BTC 原生隔离见证地址）
public enum Bech32 {
    public enum Error: Swift.Error { case invalid }
    private static let charset = Array("qpzry9x8gf2tvdw0s3jn54khce6mua7l")

    private static func polymod(_ values: [Int]) -> Int {
        let gen = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]
        var chk = 1
        for v in values {
            let b = chk >> 25
            chk = (chk & 0x1ffffff) << 5 ^ v
            for i in 0..<5 where (b >> i) & 1 == 1 { chk ^= gen[i] }
        }
        return chk
    }

    private static func hrpExpand(_ hrp: String) -> [Int] {
        let c = Array(hrp.unicodeScalars.map { Int($0.value) })
        return c.map { $0 >> 5 } + [0] + c.map { $0 & 31 }
    }

    public static func encode(hrp: String, version: UInt8, program: Data) -> String {
        var data: [Int] = [Int(version)]
        var acc = 0, bits = 0
        for byte in program {
            acc = (acc << 8) | Int(byte); bits += 8
            while bits >= 5 { bits -= 5; data.append((acc >> bits) & 31) }
        }
        if bits > 0 { data.append((acc << (5 - bits)) & 31) }
        let values = hrpExpand(hrp) + data + [0, 0, 0, 0, 0, 0]
        let mod = polymod(values) ^ 1
        var checksum: [Int] = []
        for i in 0..<6 { checksum.append((mod >> (5 * (5 - i))) & 31) }
        return hrp + "1" + (data + checksum).map { String(charset[$0]) }.joined()
    }
}
