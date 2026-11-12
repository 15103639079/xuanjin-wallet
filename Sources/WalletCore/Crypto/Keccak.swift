import Foundation

/// Keccak-256（以太坊用的那个，不是 NIST SHA3-256）。
/// 纯 Swift 实现，无第三方依赖；用于 ETH/TRON 地址推导与 EIP-191 哈希。
public enum Keccak256 {
    private static let rc: [UInt64] = [
        0x0000000000000001, 0x0000000000008082, 0x800000000000808A, 0x8000000080008000,
        0x000000000000808B, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
        0x000000000000008A, 0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
        0x000000008000808B, 0x800000000000008B, 0x8000000000008089, 0x8000000000008003,
        0x8000000000008002, 0x8000000000000080, 0x000000000000800A, 0x800000008000000A,
        0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008,
    ]
    private static let rot: [Int] = [
        0, 1, 62, 28, 27, 36, 44, 6, 55, 20, 3, 10, 43, 25, 39, 41,
        45, 15, 21, 8, 18, 2, 61, 56, 14,
    ]

    public static func hash(_ input: Data) -> Data {
        var state = [UInt64](repeating: 0, count: 25)
        let rate = 136
        var msg = [UInt8](input)
        msg.append(0x01)                       // Keccak padding
        while msg.count % rate != rate - 1 { msg.append(0x00) }
        msg.append(0x80)
        var offset = 0
        while offset < msg.count {
            for i in 0..<(rate / 8) {
                var lane: UInt64 = 0
                for b in 0..<8 { lane |= UInt64(msg[offset + i * 8 + b]) << (8 * UInt64(b)) }
                state[i] ^= lane
            }
            permute(&state)
            offset += rate
        }
        var out = [UInt8]()
        for i in 0..<4 {
            var lane = state[i]
            for _ in 0..<8 { out.append(UInt8(truncatingIfNeeded: lane)); lane >>= 8 }
        }
        return Data(out)
    }

    private static func rol(_ x: UInt64, _ n: Int) -> UInt64 {
        n == 0 ? x : (x << UInt64(n)) | (x >> UInt64(64 - n))
    }

    private static func permute(_ a: inout [UInt64]) {
        var c = [UInt64](repeating: 0, count: 5)
        var b = [UInt64](repeating: 0, count: 25)
        for round in 0..<24 {
            for x in 0..<5 { c[x] = a[x] ^ a[x+5] ^ a[x+10] ^ a[x+15] ^ a[x+20] }
            for x in 0..<5 {
                let d = c[(x + 4) % 5] ^ rol(c[(x + 1) % 5], 1)
                for y in 0..<5 { a[y * 5 + x] ^= d }
            }
            for x in 0..<5 {
                for y in 0..<5 {
                    let idx = y * 5 + x
                    let nx = y
                    let ny = (2 * x + 3 * y) % 5
                    b[ny * 5 + nx] = rol(a[idx], rot[(x + 5 * y) % 25])
                }
            }
            for y in 0..<5 {
                for x in 0..<5 {
                    a[y * 5 + x] = b[y * 5 + x] ^ (~b[y * 5 + (x + 1) % 5] & b[y * 5 + (x + 2) % 5])
                }
            }
            a[0] ^= rc[round]
        }
    }
}
