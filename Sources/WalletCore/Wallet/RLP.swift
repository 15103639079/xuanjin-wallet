import Foundation

/// 最小 RLP 编码器（以太坊交易需要）
public enum RLP {
    public enum Item {
        case bytes(Data)
        case list([Item])
    }

    public static func encode(_ item: Item) -> Data {
        switch item {
        case .bytes(let d): return encodeBytes(d)
        case .list(let items):
            let payload = items.reduce(Data()) { $0 + encode($1) }
            return header(payload.count, offset: 0xc0) + payload
        }
    }

    static func encodeBytes(_ d: Data) -> Data {
        if d.count == 1, let b = d.first, b < 0x80 { return Data([b]) }
        return header(d.count, offset: 0x80) + d
    }

    static func header(_ len: Int, offset: UInt8) -> Data {
        if len < 56 { return Data([offset + UInt8(len)]) }
        let lenBytes = bigEndian(len)
        return Data([offset + 55 + UInt8(lenBytes.count)]) + lenBytes
    }

    static func bigEndian(_ v: Int) -> Data {
        var x = UInt64(v)
        var out = Data()
        while x > 0 { out.insert(UInt8(x & 0xff), at: 0); x >>= 8 }
        return out.isEmpty ? Data([0]) : out
    }

    /// 数值编码：0 → 空字节串
    public static func uint(_ v: UInt64) -> Item {
        if v == 0 { return .bytes(Data()) }
        var x = v, out = Data()
        while x > 0 { out.insert(UInt8(x & 0xff), at: 0); x >>= 8 }
        return .bytes(out)
    }
}
