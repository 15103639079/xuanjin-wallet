import Foundation

/// 签名服务：一次一授权、金额/地址二次校验、禁止批量静默签名。
public protocol Signer: Sendable {
    func sign(intent: TransferIntent, mnemonic: String) throws -> Data
}

public enum SigningError: Error, Sendable {
    case addressMismatch
    case amountExceedsCap
    case chainUnsupported
    case userCancelled
}

public final class SigningService: @unchecked Sendable {
    private let vault: MnemonicVault
    private let signer: Signer
    private let policy: SpendingPolicy

    public init(vault: MnemonicVault, signer: Signer, policy: SpendingPolicy) {
        self.vault = vault; self.signer = signer; self.policy = policy
    }

    /// 每一笔都要过：白名单地址 → 额度上限 → 生物识别 → 解包签名 → 立刻擦除。
    public func authorize(_ intent: TransferIntent, approvedByBiometrics: Bool) throws -> Data {
        guard approvedByBiometrics else { throw SigningError.userCancelled }
        guard policy.allows(to: intent.to, chain: intent.chain) else { throw SigningError.addressMismatch }
        guard policy.withinCap(intent.amountWei, chain: intent.chain) else { throw SigningError.amountExceedsCap }
        return try vault.withSecret { phrase in
            try signer.sign(intent: intent, mnemonic: phrase)
        }
    }
}

/// 出金策略：地址白名单 + 单笔/单日额度，冷启动默认全拒。
public struct SpendingPolicy: Sendable {
    public var whitelist: Set<String>
    public var perTxCapWei: [ChainKind: Decimal]
    public var dailyCapWei: [ChainKind: Decimal]
    public var usedTodayWei: [ChainKind: Decimal] = [:]

    public init(whitelist: Set<String> = [], perTxCapWei: [ChainKind: Decimal] = [:],
                dailyCapWei: [ChainKind: Decimal] = [:]) {
        self.whitelist = whitelist; self.perTxCapWei = perTxCapWei; self.dailyCapWei = dailyCapWei
    }

    public func allows(to: String, chain: ChainKind) -> Bool { whitelist.contains(to) }

    public func withinCap(_ amountWei: String, chain: ChainKind) -> Bool {
        guard let amount = Decimal(string: amountWei) else { return false }
        if let cap = perTxCapWei[chain], amount > cap { return false }
        if let daily = dailyCapWei[chain] {
            let used = usedTodayWei[chain] ?? 0
            if used + amount > daily { return false }
        }
        return true
    }
}
