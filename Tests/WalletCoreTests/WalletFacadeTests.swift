import XCTest
@testable import WalletCore

final class WalletFacadeTests: XCTestCase {
    func testDeriveAllChainsFromImportedPhrase() throws {
        try WordlistLoader.configure()
        let store = InMemoryKeyStore(); try store.createWrappingKey()
        let wallet = Wallet(store: store)
        try wallet.importPhrase(["abandon","abandon","abandon","abandon","abandon","abandon",
                                 "abandon","abandon","abandon","abandon","abandon","about"])
        let eth = try wallet.account(chain: .ethereum)
        XCTAssertEqual(eth.address.lowercased(), "0x9858effd232b4033e47d90003d41ec34ecaeda94")
        let btc = try wallet.account(chain: .bitcoin)
        XCTAssertEqual(btc.address, "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu")
        let tron = try wallet.account(chain: .tron)
        XCTAssertEqual(tron.address.count, 34)
    }

    func testSigningRequiresBiometrics() throws {
        try WordlistLoader.configure()
        let store = InMemoryKeyStore(); try store.createWrappingKey()
        let wallet = Wallet(store: store)
        try wallet.importPhrase(["abandon","abandon","abandon","abandon","abandon","abandon",
                                 "abandon","abandon","abandon","abandon","abandon","about"])
        let tx = EthereumTx(chainId: 1, nonce: 0, maxPriorityFeePerGas: 1, maxFeePerGas: 1,
                            gasLimit: 21000,
                            to: Data(hexString: "3535353535353535353535353535353535353535")!,
                            value: 1)
        XCTAssertThrowsError(try wallet.signETH(tx, approvedByBiometrics: false))
        XCTAssertThrowsError(try wallet.signETH(tx, approvedByBiometrics: true)) // 白名单为空，默认拒绝
    }
}
