import XCTest
@testable import WalletCore

/// 与 Python eth_account 交叉比对（EIP-1559 / type 0x02）
final class EthTxVectorTests: XCTestCase {
    func testEIP1559SigningMatchesReference() throws {
        let key = Data(repeating: 0x46, count: 32)
        let tx = EthereumTx(
            chainId: 1, nonce: 9, maxPriorityFeePerGas: 2_000_000_000,
            maxFeePerGas: 30_000_000_000, gasLimit: 21000,
            to: Data(hexString: "3535353535353535353535353535353535353535")!,
            value: 1_000_000_000_000_000_000, data: Data())
        let raw = try tx.signed(privateKey: key)
        let expected = "02f873010984773594008506fc23ac00825208943535353535353535353535353535353535353535880de0b6b3a764000080c080a02b03b67e070f45175ce9d07c4512720168bd468a24edb6997977a53d48c87a12a0733d775fdd689d306e08ac8ab399f34b5a0253b47ed81b8bf2d2a6ea607fcac7"
        XCTAssertEqual(raw.hex, expected)
    }
}

extension Data {
    init?(hexString: String) {
        let s = hexString.hasPrefix("0x") ? String(hexString.dropFirst()) : hexString
        guard s.count % 2 == 0 else { return nil }
        var d = Data(capacity: s.count / 2)
        var i = s.startIndex
        while i < s.endIndex {
            let j = s.index(i, offsetBy: 2)
            guard let b = UInt8(s[i..<j], radix: 16) else { return nil }
            d.append(b); i = j
        }
        self = d
    }
    var hex: String { map { String(format: "%02x", $0) }.joined() }
}
