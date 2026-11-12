import Foundation

/// 备份隔离：任何含密钥材料的文件都标记为不备份；
/// 关键记录同时禁止 iCloud 同步（kSecAttrSynchronizable = false）。
public enum BackupExclusion {

    public static func markExcluded(_ url: URL) throws {
        var u = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try u.setResourceValues(values)
    }

    /// 钱包数据目录：一次建好并排除备份。
    public static func secureDataDirectory() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory,
                                               in: .userDomainMask,
                                               appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent("SecureWallet", isDirectory: true)
        #if os(iOS)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        #else
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        #endif
        try markExcluded(dir)
        return dir
    }

    /// Keychain 查询模板：ThisDeviceOnly + 不同步 + 不经备份。
    public static func keychainBaseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            kSecAttrSynchronizable as String: false,
        ]
    }
}
