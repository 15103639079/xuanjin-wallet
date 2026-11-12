import XCTest
@testable import WalletCore

final class WalletCoreTests: XCTestCase {
    func testWrapUnwrapRoundTrip() throws {
        let store = InMemoryKeyStore()
        try store.createWrappingKey()
        let secret = Data("produce front turtle firm".utf8)
        let wrapped = try store.wrap(secret, context: "t")
        XCTAssertNotEqual(wrapped, secret)
        XCTAssertEqual(try store.unwrap(wrapped, context: "t"), secret)
    }

    func testMnemonicVaultSealAndRead() throws {
        try WordlistLoader.configure()
        let store = InMemoryKeyStore(); try store.createWrappingKey()
        let vault = MnemonicVault(store: store)
        try vault.importMnemonic(["abandon","abandon","abandon","abandon","abandon","abandon",
                                  "abandon","abandon","abandon","abandon","abandon","about"])
        XCTAssertTrue(vault.hasSecret)
        let phrase = try vault.withSecret { $0 }
        XCTAssertTrue(phrase.hasPrefix("abandon"))
        vault.destroy()
        XCTAssertFalse(vault.hasSecret)
    }

    func testSpendingPolicyCaps() {
        let p = SpendingPolicy(whitelist: ["0xabc"], perTxCapWei: [.ethereum: 100],
                               dailyCapWei: [.ethereum: 150])
        XCTAssertTrue(p.allows(to: "0xabc", chain: .ethereum))
        XCTAssertFalse(p.allows(to: "0xdef", chain: .ethereum))
        XCTAssertTrue(p.withinCap("50", chain: .ethereum))
        XCTAssertFalse(p.withinCap("120", chain: .ethereum))
    }

    func testBIP39RoundTrip() throws {
        try WordlistLoader.configure()
        for count in [12, 15, 18, 21, 24] {
            let bytes = (count * 11 - count / 3) / 8
            let entropy = Data((0..<bytes).map { _ in UInt8.random(in: 0...255) })
            let words = try BIP39.mnemonic(from: entropy)
            XCTAssertEqual(words.count, count)
            XCTAssertEqual(try BIP39.entropy(from: words), entropy)
        }
    }

    func testBIP39KnownVector() throws {
        try WordlistLoader.configure()
        // BIP39 官方测试向量：全零 128bit 熵
        let zero = Data(repeating: 0, count: 16)
        let words = try BIP39.mnemonic(from: zero)
        XCTAssertEqual(words, ["abandon","abandon","abandon","abandon","abandon","abandon",
                               "abandon","abandon","abandon","abandon","abandon","about"])
        XCTAssertEqual(try BIP39.entropy(from: words), zero)
    }

    func testThreatAuditShape() {
        let r = ThreatGuard.audit()
        XCTAssertEqual(r.isTrusted, !r.jailbroken && !r.debuggerAttached && r.suspiciousImages.isEmpty)
    }
}
