import XCTest
@testable import WalletCore

final class CryptoVectorTests: XCTestCase {
    let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

    func testKeccakEmpty() {
        XCTAssertEqual(Keccak256.hash(Data()).hex,
                       "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470")
    }

    func testRIPEMDEmpty() {
        XCTAssertEqual(RIPEMD160.hash(Data()).hex,
                       "9c1185a5c5e9fc54612808977ee8f548b2258d31")
    }

    func testEthAddressVector() throws {
        let acc = try AddressDeriver.derive(mnemonic: mnemonic, chain: .ethereum)
        XCTAssertEqual(acc.address.lowercased(), "0x9858effd232b4033e47d90003d41ec34ecaeda94")
    }

    func testBTCBech32Vector() throws {
        let acc = try AddressDeriver.derive(mnemonic: mnemonic, chain: .bitcoin)
        XCTAssertEqual(acc.address, "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu")
    }

    func testTronAndSolanaShape() throws {
        let tron = try AddressDeriver.derive(mnemonic: mnemonic, chain: .tron)
        XCTAssertEqual(tron.address.first, "T")
        XCTAssertEqual(tron.address.count, 34)
        let sol = try AddressDeriver.derive(mnemonic: mnemonic, chain: .solana)
        XCTAssertEqual(sol.address.count, 44)
    }

    func testBIP32PathParse() throws {
        let seed = try AddressDeriver.seed(mnemonic: mnemonic)
        let root = try ExtKey.master(seed: seed)
        let a = try root.derived(path: "m/44'/60'/0'/0/0")
        let b = try root.derived(path: "m/44'/60'/0'/0/0")
        XCTAssertEqual(a.privateKey, b.privateKey)
    }
}
