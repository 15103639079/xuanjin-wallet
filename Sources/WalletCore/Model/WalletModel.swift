import Foundation

/// 链类型（钱包支持的曲线/派生路径）
public enum ChainKind: String, Codable, CaseIterable, Sendable {
    case ethereum, bnb, polygon, arbitrum
    case tron
    case bitcoin
    case solana
}

/// 单个账户（不含任何私钥材料，只有地址与元数据）
public struct WalletAccount: Codable, Sendable, Identifiable {
    public let id: UUID
    public let chain: ChainKind
    public let address: String
    public let derivationPath: String
    public let label: String
    public let createdAt: Date

    public init(id: UUID = UUID(), chain: ChainKind, address: String,
                derivationPath: String, label: String, createdAt: Date = .now) {
        self.id = id; self.chain = chain; self.address = address
        self.derivationPath = derivationPath; self.label = label; self.createdAt = createdAt
    }
}

/// 交易意图：签名前的唯一入参，禁止携带完整私钥
public struct TransferIntent: Sendable {
    public let from: String
    public let to: String
    public let amountWei: String
    public let chain: ChainKind
    public let nonce: UInt64?
    public let feeCap: String

    public init(from: String, to: String, amountWei: String,
                chain: ChainKind, nonce: UInt64?, feeCap: String) {
        self.from = from; self.to = to; self.amountWei = amountWei
        self.chain = chain; self.nonce = nonce; self.feeCap = feeCap
    }
}
