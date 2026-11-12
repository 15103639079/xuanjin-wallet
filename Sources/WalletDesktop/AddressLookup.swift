import Foundation
import SwiftUI
import WalletCore

private enum LookupNetwork: String, CaseIterable, Identifiable, Sendable {
    case bitcoin = "比特币"
    case ethereum = "以太坊"

    var id: Self { self }
    var symbol: String { self == .bitcoin ? "BTC" : "ETH" }
    var host: String { self == .bitcoin ? "blockstream.info" : "eth.blockscout.com" }
    var example: String {
        switch self {
        case .bitcoin: "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"
        case .ethereum: "0x000000000000000000000000000000000000dEaD"
        }
    }

    func validatedAddress(_ input: String) -> String? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern: String
        switch self {
        case .bitcoin:
            pattern = #"^(?:[13][1-9A-HJ-NP-Za-km-z]{25,34}|bc1[ac-hj-np-z02-9]{11,87}|BC1[AC-HJ-NP-Z02-9]{11,87})$"#
        case .ethereum:
            pattern = #"^0x[0-9a-fA-F]{40}$"#
        }
        guard value.utf8.count <= 90,
              value.range(of: pattern, options: .regularExpression) == value.startIndex..<value.endIndex else {
            return nil
        }
        return value.hasPrefix("BC1") ? value.lowercased() : value
    }
}

private struct AddressResult: Sendable {
    let balance: String
    let balanceLabel: String
    let transactions: [Transaction]?
    let queriedAt = Date()

    struct Transaction: Identifiable, Sendable {
        let id: String
        let state: String
        let block: Int?
    }
}

private final class NoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? { nil }
}

private enum AddressAPI {
    private struct BitcoinAddress: Decodable {
        let chain_stats: Stats
        struct Stats: Decodable {
            let funded_txo_sum: Int64
            let spent_txo_sum: Int64
        }
    }

    private struct BitcoinTransaction: Decodable {
        let txid: String
        let status: Status
        struct Status: Decodable {
            let confirmed: Bool
            let block_height: Int?
        }
    }

    private struct EthereumAddress: Decodable {
        let coin_balance: String?
    }

    private struct EthereumTransactions: Decodable {
        let items: [Item]
        struct Item: Decodable {
            let hash: String
            let status: String?
            let block_number: Int?
        }
    }

    private enum QueryError: LocalizedError {
        case status(Int)
        case invalidResponse
        case balanceUnavailable

        var errorDescription: String? {
            switch self {
            case .status(400), .status(422): "查询服务拒绝了地址，请核对地址和网络。"
            case .status(429): "查询太频繁，请稍后重试。"
            case .status(let code): "查询服务暂不可用（HTTP \(code)）。"
            case .invalidResponse: "查询服务返回了无法识别的数据。"
            case .balanceUnavailable: "服务暂未提供此地址的余额。"
            }
        }
    }

    private static let session = NetworkPolicy.strictSession()

    static func fetch(_ network: LookupNetwork, address: String) async throws -> AddressResult {
        switch network {
        case .bitcoin:
            let url = URL(string: "https://\(network.host)/api/address/\(address)")!
            async let history = try? read([BitcoinTransaction].self, at: url.appendingPathComponent("txs"))
            let stats = try await read(BitcoinAddress.self, at: url).chain_stats
            guard stats.spent_txo_sum >= 0, stats.funded_txo_sum >= stats.spent_txo_sum else {
                throw QueryError.invalidResponse
            }
            let balance = try decimalUnits(String(stats.funded_txo_sum - stats.spent_txo_sum), places: 8)
            let transactions = await history?.prefix(10).map {
                AddressResult.Transaction(id: $0.txid, state: $0.status.confirmed ? "已入块" : "待确认",
                                          block: $0.status.block_height)
            }
            return AddressResult(balance: balance, balanceLabel: "已确认 BTC 余额", transactions: transactions)
        case .ethereum:
            let url = URL(string: "https://\(network.host)/api/v2/addresses/\(address)")!
            async let history = try? read(EthereumTransactions.self, at: url.appendingPathComponent("transactions"))
            let snapshot = try await read(EthereumAddress.self, at: url)
            guard let wei = snapshot.coin_balance else { throw QueryError.balanceUnavailable }
            let balance = try decimalUnits(wei, places: 18)
            let transactions = await history?.items.prefix(10).map {
                let state: String
                switch $0.status {
                case "ok": state = "成功"
                case "error": state = "失败"
                default: state = $0.block_number == nil ? "待确认" : "已入块"
                }
                return AddressResult.Transaction(id: $0.hash, state: state, block: $0.block_number)
            }
            return AddressResult(balance: balance, balanceLabel: "ETH 余额", transactions: transactions)
        }
    }

    private static func read<T: Decodable>(_ type: T.Type, at url: URL) async throws -> T {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request, delegate: NoRedirects())
        guard let http = response as? HTTPURLResponse else { throw QueryError.invalidResponse }
        guard http.statusCode == 200 else { throw QueryError.status(http.statusCode) }
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw QueryError.invalidResponse }
    }

    private static func decimalUnits(_ digits: String, places: Int) throws -> String {
        guard !digits.isEmpty, digits.utf8.count <= 78,
              digits.utf8.allSatisfy({ (48...57).contains($0) }) else { throw QueryError.invalidResponse }
        let padded = String(repeating: "0", count: max(0, places + 1 - digits.count)) + digits
        let whole = padded.dropLast(places).drop(while: { $0 == "0" })
        let fraction = String(padded.suffix(places).reversed().drop(while: { $0 == "0" }).reversed())
        let integer = whole.isEmpty ? "0" : String(whole)
        return fraction.isEmpty ? integer : integer + "." + fraction
    }
}

struct AddressLookup: View {
    @State private var network: LookupNetwork = .bitcoin
    @State private var input = ""
    @State private var result: AddressResult?
    @State private var error: String?
    @State private var task: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("地址查询").font(.system(size: 32, weight: .medium, design: .serif))
                Text("输入主网公开地址。查询会将该地址发送给 \(network.host)。")
                    .foregroundStyle(.secondary)
                Picker("网络", selection: $network) {
                    ForEach(LookupNetwork.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                HStack {
                    TextField("粘贴公开地址", text: $input)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(query)
                    Button("查询", action: query)
                        .buttonStyle(.borderedProminent)
                        .disabled(task != nil || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("填入公开示例") { input = network.example }
                }
                if task != nil { ProgressView("正在查询…").controlSize(.small) }
                if let error { Text(error).foregroundStyle(.orange) }
                if let result { resultView(result) }
                Spacer(minLength: 0)
            }
            .padding(32)
            .frame(maxWidth: 950, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(red: 0.045, green: 0.064, blue: 0.086))
        .onChange(of: network) {
            input = ""
            reset()
        }
        .onChange(of: input) { reset() }
        .onDisappear { reset() }
    }

    private func resultView(_ result: AddressResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(result.balanceLabel).foregroundStyle(.secondary)
            Text("\(result.balance) \(network.symbol)")
                .font(.system(size: 30, weight: .medium, design: .monospaced))
                .textSelection(.enabled)
            Text("查询时间 \(result.queriedAt.formatted(date: .omitted, time: .standard))")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Text("近期交易").font(.headline)
            if let transactions = result.transactions {
                if transactions.isEmpty { Text("暂无近期交易。").foregroundStyle(.secondary) }
                ForEach(transactions) { transaction in
                    HStack {
                        Text(transaction.id).font(.caption.monospaced()).textSelection(.enabled)
                        Spacer()
                        if let block = transaction.block {
                            Text("区块 \(block.formatted(.number.grouping(.never)))")
                                .foregroundStyle(.secondary)
                        }
                        Text(transaction.state)
                    }
                    .font(.caption)
                }
            } else {
                Text("交易列表查询失败，可以重新查询。").foregroundStyle(.orange)
            }
            if network == .ethereum {
                Text("仅显示 ETH 与普通交易。").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func reset() {
        task?.cancel()
        task = nil
        result = nil
        error = nil
    }

    private func query() {
        guard task == nil else { return }
        reset()
        guard let address = network.validatedAddress(input) else {
            error = "请输入所选网络的主网公开地址。"
            return
        }
        let selected = network
        task = Task {
            do {
                let snapshot = try await AddressAPI.fetch(selected, address: address)
                guard !Task.isCancelled else { return }
                result = snapshot
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error is URLError ? "无法连接查询服务，请检查网络后重试。" : error.localizedDescription
            }
            task = nil
        }
    }
}
