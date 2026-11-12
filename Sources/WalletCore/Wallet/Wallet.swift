import Foundation

/// 钱包门面：对外只暴露"开户 / 派生地址 / 签名"三件事，
/// 内部所有明文材料都在 MnemonicVault 的签名窗口内流转。
public final class Wallet: @unchecked Sendable {
    public let vault: MnemonicVault
    public let policy: SpendingPolicy
    private let store: KeyStore

    public init(store: KeyStore = SecureEnclaveKeyStore(), policy: SpendingPolicy = SpendingPolicy()) {
        self.store = store
        self.vault = MnemonicVault(store: store)
        self.policy = policy
    }

    /// 首次使用：创建 Secure Enclave 包裹密钥
    public func bootstrap() throws {
        try store.createWrappingKey()
    }

    public func create(wordCount: Int = 12) throws -> [String] {
        guard ThreatGuard.audit().isTrusted else { throw SigningError.userCancelled }
        return try vault.generate(wordCount: wordCount)
    }

    public func importPhrase(_ words: [String]) throws {
        try vault.importMnemonic(words)
    }

    /// 派生某条链的账户（默认索引 0）
    public func account(chain: ChainKind, index: UInt32 = 0) throws -> WalletAccount {
        try vault.withSecret { phrase in
            try AddressDeriver.derive(mnemonic: phrase, chain: chain, index: index)
        }
    }

    /// 一步到位：派生 + 签名 EIP-1559 交易（需要生物识别已通过）
    public func signETH(_ tx: EthereumTx, chain: ChainKind = .ethereum,
                        approvedByBiometrics: Bool) throws -> Data {
        guard approvedByBiometrics, ThreatGuard.audit().isTrusted else {
            throw SigningError.userCancelled
        }
        guard policy.allows(to: "0x" + tx.to.map { String(format: "%02x", $0) }.joined(),
                            chain: chain) else { throw SigningError.addressMismatch }
        guard policy.withinCap(String(tx.value), chain: chain) else { throw SigningError.amountExceedsCap }
        return try vault.withSecret { phrase in
            let seed = try AddressDeriver.seed(mnemonic: phrase)
            let node = try ExtKey.master(seed: seed).derived(path: AddressDeriver.path(for: chain, index: 0))
            return try tx.signed(privateKey: node.privateKey)
        }
    }
}
