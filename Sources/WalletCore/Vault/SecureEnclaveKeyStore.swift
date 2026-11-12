import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Secure Enclave 里的一把不可导出的 P-256 密钥。
/// 用途：包裹助记词/私钥，永不导出裸材料。
public enum VaultError: Error, Sendable {
    case secureEnclaveUnavailable
    case keyNotFound
    case wrapFailed
    case unwrapFailed
    case biometricRequired
    case locked(Int)
}

public protocol KeyStore: Sendable {
    func createWrappingKey() throws
    func hasWrappingKey() -> Bool
    func wrap(_ plaintext: Data, context: String) throws -> Data
    func unwrap(_ wrapped: Data, context: String) throws -> Data
}

#if canImport(CryptoKit) && (os(iOS) || os(macOS))
public final class SecureEnclaveKeyStore: KeyStore, @unchecked Sendable {
    private let tag: Data
    private let lock = NSLock()

    public init(tag: String = "com.securewallet.wrapping") {
        self.tag = Data(tag.utf8)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
        ]
    }

    public func hasWrappingKey() -> Bool {
        var q = baseQuery(); q[kSecReturnRef as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        return SecItemCopyMatching(q as CFDictionary, nil) == errSecSuccess
    }

    public func createWrappingKey() throws {
        #if targetEnvironment(simulator)
        throw VaultError.secureEnclaveUnavailable
        #else
        guard SecureEnclave.isAvailable else { throw VaultError.secureEnclaveUnavailable }
        guard !hasWrappingKey() else { return }
        let attrs: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag,
                kSecAttrAccessControl as String: accessControl(),
            ],
        ]
        var err: Unmanaged<CFError>?
        guard SecKeyCreateRandomKey(attrs as CFDictionary, &err) != nil else {
            throw VaultError.wrapFailed
        }
        #endif
    }

    /// 生物识别 + 设备解锁双门禁；ThisDeviceOnly 不进备份、不同步。
    private func accessControl() -> SecAccessControl? {
        #if os(iOS)
        return SecAccessControlCreateWithFlags(nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            [.biometryCurrentSet, .privateKeyUsage], nil)
        #else
        return SecAccessControlCreateWithFlags(nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            [.privateKeyUsage], nil)
        #endif
    }

    private func privateKey() throws -> SecKey {
        var q = baseQuery()
        q[kSecReturnRef as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        guard status == errSecSuccess, let key = item else { throw VaultError.keyNotFound }
        return (key as! SecKey)
    }

    public func wrap(_ plaintext: Data, context: String) throws -> Data {
        lock.lock(); defer { lock.unlock() }
        let key = try privateKey()
        var err: Unmanaged<CFError>?
        guard let pub = SecKeyCopyPublicKey(key),
              let wrapped = SecKeyCreateEncryptedData(pub, .eciesEncryptionCofactorX963SHA256AESGCM,
                                                      plaintext as CFData, &err) else {
            throw VaultError.wrapFailed
        }
        return wrapped as Data
    }

    public func unwrap(_ wrapped: Data, context: String) throws -> Data {
        lock.lock(); defer { lock.unlock() }
        let key = try privateKey()
        var err: Unmanaged<CFError>?
        guard let plain = SecKeyCreateDecryptedData(key, .eciesEncryptionCofactorX963SHA256AESGCM,
                                                    wrapped as CFData, &err) else {
            throw VaultError.unwrapFailed
        }
        return plain as Data
    }
}
#endif

/// 纯软件实现，只用于单元测试与模拟器路径；生产环境禁止使用。
public final class InMemoryKeyStore: KeyStore, @unchecked Sendable {
    private var key = Data(repeating: 0, count: 32)
    public init() {}
    public func createWrappingKey() throws { key = Data((0..<32).map { _ in UInt8.random(in: 0...255) }) }
    public func hasWrappingKey() -> Bool { true }
    public func wrap(_ plaintext: Data, context: String) throws -> Data {
        Data(plaintext.enumerated().map { $0.element ^ key[$0.offset % key.count] })
    }
    public func unwrap(_ wrapped: Data, context: String) throws -> Data {
        Data(wrapped.enumerated().map { $0.element ^ key[$0.offset % key.count] })
    }
}
