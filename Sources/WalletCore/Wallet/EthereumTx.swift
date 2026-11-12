import Foundation

/// EIP-1559 交易构造与签名（type 0x02）
public struct EthereumTx: Sendable {
    public var chainId: UInt64
    public var nonce: UInt64
    public var maxPriorityFeePerGas: UInt64
    public var maxFeePerGas: UInt64
    public var gasLimit: UInt64
    public var to: Data            // 20B
    public var value: UInt64
    public var data: Data

    public init(chainId: UInt64, nonce: UInt64, maxPriorityFeePerGas: UInt64,
                maxFeePerGas: UInt64, gasLimit: UInt64, to: Data, value: UInt64, data: Data = Data()) {
        self.chainId = chainId; self.nonce = nonce
        self.maxPriorityFeePerGas = maxPriorityFeePerGas; self.maxFeePerGas = maxFeePerGas
        self.gasLimit = gasLimit; self.to = to; self.value = value; self.data = data
    }

    public func signingHash() -> Data {
        let fields: [RLP.Item] = [
            RLP.uint(chainId), RLP.uint(nonce), RLP.uint(maxPriorityFeePerGas), RLP.uint(maxFeePerGas),
            RLP.uint(gasLimit), .bytes(to), RLP.uint(value), .bytes(data), .list([]),
        ]
        return Keccak256.hash(Data([0x02]) + RLP.encode(.list(fields)))
    }

    /// 返回可直接广播的原始交易（0x02 || rlp(...)）
    public func signed(privateKey: Data) throws -> Data {
        let hash = signingHash()
        let (sig, recid) = try Secp256k1.signRecoverable(key: privateKey, hash: hash)
        let r = Data(sig.prefix(32)).trimmedLeadingZeros()
        let s = Data(sig.suffix(32)).trimmedLeadingZeros()
        let fields: [RLP.Item] = [
            RLP.uint(chainId), RLP.uint(nonce), RLP.uint(maxPriorityFeePerGas), RLP.uint(maxFeePerGas),
            RLP.uint(gasLimit), .bytes(to), RLP.uint(value), .bytes(data), .list([]),
            RLP.uint(UInt64(recid)), .bytes(r), .bytes(s),
        ]
        return Data([0x02]) + RLP.encode(.list(fields))
    }
}

extension Data {
    func trimmedLeadingZeros() -> Data {
        var d = self
        while d.count > 0 && d.first == 0 { d.removeFirst() }
        return d.isEmpty ? Data() : d
    }
}
