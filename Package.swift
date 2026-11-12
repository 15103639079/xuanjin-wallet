// swift-tools-version:6.0
import PackageDescription

#if arch(arm64)
let brewPrefix = "/opt/homebrew"
#else
let brewPrefix = "/usr/local"
#endif

let package = Package(
    name: "SecureWallet",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "WalletCore", targets: ["WalletCore"]),
        .executable(name: "WalletDesktop", targets: ["WalletDesktop"]),
    ],
    targets: [
        .target(name: "Csecp256k1", path: "Sources/Csecp256k1",
                publicHeadersPath: "include",
                cSettings: [.headerSearchPath("include"), .unsafeFlags(["-I\(brewPrefix)/opt/secp256k1/include", "-I\(brewPrefix)/opt/openssl/include"])],
                linkerSettings: [
                    .unsafeFlags(["-L\(brewPrefix)/opt/secp256k1/lib", "-L\(brewPrefix)/opt/openssl/lib", "-lsecp256k1", "-lcrypto"]),
                ]),
        .target(
            name: "WalletCore",
            dependencies: ["Csecp256k1"],
            path: "Sources/WalletCore",
            resources: [.copy("Resources/bip39-english.txt")]
        ),
        .executableTarget(name: "WalletDesktop", dependencies: ["WalletCore"],
                          resources: [.copy("Resources")]),
        .testTarget(name: "WalletCoreTests", dependencies: ["WalletCore"], path: "Tests/WalletCoreTests"),
    ]
)
