import AppKit
import SwiftUI
import WalletCore

@main
struct WalletDesktop: App {
    var body: some Scene {
        WindowGroup("玄金钱包") {
            Group {
                if ProcessInfo.processInfo.arguments.contains("--offline-lab") {
                    TabView {
                        AddressLookup().tabItem { Label("地址查询", systemImage: "magnifyingglass") }
                        Dashboard().tabItem { Label("离线实验室", systemImage: "lock.shield") }
                    }
                } else {
                    AddressLookup()
                }
            }
            .frame(minWidth: 760, minHeight: 560)
            .preferredColorScheme(.dark)
        }
        .defaultSize(width: 880, height: 660)
    }
}

private struct Dashboard: View {
    private static let gold = Color(red: 0.91, green: 0.79, blue: 0.57)
    private static let background = Color(red: 0.045, green: 0.064, blue: 0.086)
    private static let networks: [(ChainKind, String, String)] = [
        (.bitcoin, "比特币", "BTC"),
        (.ethereum, "以太坊", "ETH"),
        (.bnb, "BNB Smart Chain", "BNB"),
        (.polygon, "Polygon", "POL"),
        (.arbitrum, "Arbitrum One", "ARB"),
    ]
    private static let logo: NSImage? = {
        guard let url = Bundle.module.url(forResource: "WalletLogo", withExtension: "png",
                                           subdirectory: "Resources") else { return nil }
        return NSImage(contentsOf: url)
    }()

    private enum Panel: String, Identifiable {
        case importPhrase, backup
        var id: Self { self }
    }

    @State private var panel: Panel?
    @State private var accounts: [WalletAccount] = []
    @State private var phrase = ""
    @State private var backup: [String] = []
    @State private var origin = ""
    @State private var error = ""
    @State private var copied: UUID?
    @State private var ready = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                introduction
                addressBook
            }
            .padding(32)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
        .background(Self.background)
        .tint(Self.gold)
        .task {
            guard !ready else { return }
            do {
                try WordlistLoader.configure()
                ready = true
            } catch {
                self.error = "无法加载 BIP39 词表，请重新构建应用。"
            }
        }
        .sheet(item: $panel, onDismiss: clearPanel) { item in
            sheet(item)
                .padding(28)
                .frame(width: 475)
                .background(Self.background)
                .tint(Self.gold)
        }
    }

    private var header: some View {
        HStack(spacing: 13) {
            Group {
                if let logo = Self.logo {
                    Image(nsImage: logo).resizable().scaledToFit()
                } else {
                    Image(systemName: "lock.shield.fill").font(.title2).foregroundStyle(Self.gold)
                }
            }
            .frame(width: 46, height: 46)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)
            Text("玄金钱包").font(.system(size: 21, weight: .semibold, design: .serif))
            Spacer()
            Label("离线预览", systemImage: "circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(Self.gold)
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("本地钱包工作台")
                .font(.system(size: 36, weight: .medium, design: .serif))
            Text("在本机生成或校验 BIP39 助记词，查看五条网络的首个账户地址。")
                .foregroundStyle(.secondary)
            Text("当前仅用于测试。请勿导入持有资产的助记词或向这些地址转账。")
                .font(.callout)
                .foregroundStyle(Self.gold)
            HStack(spacing: 12) {
                Button("加载演示") { loadDemo() }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(Self.background)
                Button("创建测试钱包") { create() }
                Button("导入测试助记词") {
                    clearPanel()
                    error = ""
                    panel = .importPhrase
                }
            }
            .controlSize(.large)
            .disabled(!ready)
            if !error.isEmpty && panel == nil {
                Text(error).font(.callout).foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 17)
                .fill(LinearGradient(colors: [Color(red: 0.13, green: 0.15, blue: 0.18),
                                              Color(red: 0.08, green: 0.10, blue: 0.13)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .strokeBorder(Self.gold.opacity(0.24))
        }
    }

    private var addressBook: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("账户地址").font(.title3.weight(.semibold))
                Spacer()
                Text(origin.isEmpty ? "尚未载入" : origin).font(.callout).foregroundStyle(.secondary)
            }
            if accounts.isEmpty {
                Label("加载公开示例即可查看各网络的地址和派生路径。", systemImage: "tray")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            } else {
                VStack(spacing: 0) {
                    ForEach(accounts) { account in
                        if account.id != accounts.first?.id { Divider() }
                        accountRow(account)
                    }
                }
                .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func accountRow(_ account: WalletAccount) -> some View {
        let network = Self.networks.first { $0.0 == account.chain }
        return HStack(spacing: 13) {
            Text(network?.2 ?? "")
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(Self.gold)
                .frame(width: 45, height: 36)
                .background(Self.gold.opacity(0.09), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 4) {
                Text(network?.1 ?? account.label).font(.callout.weight(.semibold))
                Text(account.address).font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Text(account.derivationPath).font(.caption2.monospaced()).foregroundStyle(.secondary)
            }
            Spacer()
            Button(copied == account.id ? "已复制" : "复制地址") {
                let clipboard = NSPasteboard.general
                clipboard.clearContents()
                if clipboard.setString(account.address, forType: .string) {
                    copied = account.id
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
    }

    private func sheet(_ item: Panel) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            switch item {
            case .importPhrase:
                Text("导入测试助记词").font(.title2.bold())
                Text("仅支持 BIP39 英文词表。测试助记词只用于本次派生。")
                    .foregroundStyle(.secondary)
                SecureField("输入用空格分隔的助记词", text: $phrase)
                    .onSubmit(importPhrase)
                if !error.isEmpty { Text(error).foregroundStyle(.orange) }
                HStack {
                    Button("取消") { panel = nil }
                    Spacer()
                    Button("校验并查看地址", action: importPhrase)
                        .buttonStyle(.borderedProminent)
                        .foregroundStyle(Self.background)
                        .disabled(phrase.split(whereSeparator: \.isWhitespace).isEmpty)
                }
            case .backup:
                Text("测试助记词").font(.title2.bold())
                Text("关闭后会清除界面中的助记词。退出应用后，本次会话不会保留。")
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 9) {
                    ForEach(backup.indices, id: \.self) { index in
                        Text("\(index + 1). \(backup[index])")
                            .font(.callout.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                Button("关闭") { panel = nil }
                    .keyboardShortcut(.defaultAction)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func clearPanel() {
        phrase = ""
        backup = []
    }

    private func loadDemo() {
        let words = Array(repeating: "abandon", count: 11) + ["about"]
        do { try load(words, origin: "公开演示 · 禁止转账") }
        catch { self.error = "无法载入演示地址。" }
    }

    private func create() {
        do {
            var random = SystemRandomNumberGenerator()
            var entropy = Data((0..<16).map { _ in UInt8.random(in: .min ... .max, using: &random) })
            defer { entropy.resetBytes(in: 0..<entropy.count) }
            let words = try BIP39.mnemonic(from: entropy)
            try load(words, origin: "本次创建")
            backup = words
            panel = .backup
        } catch {
            self.error = "无法创建测试钱包。"
        }
    }

    private func importPhrase() {
        let words = phrase.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        do {
            try load(words, origin: "本次导入")
            panel = nil
        } catch BIP39Error.badWordCount {
            error = "助记词必须包含 12、15、18、21 或 24 个单词。"
        } catch BIP39Error.unknownWord {
            error = "有单词不在 BIP39 英文词表中。"
        } catch BIP39Error.badChecksum {
            error = "助记词校验失败，请检查拼写和顺序。"
        } catch {
            self.error = "无法派生地址。"
        }
    }

    private func load(_ words: [String], origin: String) throws {
        var entropy = try BIP39.entropy(from: words)
        defer { entropy.resetBytes(in: 0..<entropy.count) }
        let mnemonic = words.joined(separator: " ")
        let derived = try Self.networks.map { try AddressDeriver.derive(mnemonic: mnemonic, chain: $0.0) }
        accounts = derived
        self.origin = origin
        copied = nil
        error = ""
    }
}
