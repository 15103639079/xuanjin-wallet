import Foundation

#if canImport(SwiftUI)
import SwiftUI

/// 最小可运行外壳：只暴露"创建/导入 → 查看地址 → 授权转账"三步。
/// 生产版在这里接生物识别与硬件钱包；当前为可编译骨架。
@MainActor
public final class WalletViewModel: ObservableObject {
    @Published public private(set) var accounts: [WalletAccount] = []
    @Published public private(set) var threat: ThreatReport?
    @Published public var status: String = "未初始化"

    private let vault: MnemonicVault
    private let policy = SpendingPolicy()

    public init(store: KeyStore) {
        self.vault = MnemonicVault(store: store)
    }

    public func boot() {
        let report = ThreatGuard.audit()
        threat = report
        status = report.isTrusted ? "环境可信" : "环境异常：敏感操作已禁用"
    }

    public func createWallet(wordCount: Int = 12) {
        guard threat?.isTrusted == true else { status = "环境不可信，拒绝创建"; return }
        do {
            let words = try vault.generate(wordCount: wordCount)
            // 生产：立刻让用户抄写并二次校验；这里只保留占位
            status = "已生成 \(words.count) 词助记词（示意）"
        } catch {
            status = "生成失败"
        }
    }
}

public struct WalletHomeView: View {
    @StateObject private var vm: WalletViewModel
    public init(vm: WalletViewModel) { _vm = StateObject(wrappedValue: vm) }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Secure Wallet").font(.largeTitle.bold())
            Text(vm.status).foregroundStyle(.secondary)
            HStack {
                Button("初始化环境检查") { vm.boot() }
                Button("生成钱包") { vm.createWallet() }
            }
            List(vm.accounts) { acc in
                VStack(alignment: .leading) {
                    Text(acc.label).font(.headline)
                    Text(acc.address).font(.caption).monospaced()
                }
            }
        }.padding()
    }
}
#endif
