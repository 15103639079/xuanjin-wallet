import Foundation

/// 助记词生命周期管理：生成 → Secure Enclave 包裹 → 用后即擦。
/// 约束：明文不落盘、不进日志、不进崩溃报告、不做任何字符串插值。
public final class MnemonicVault: @unchecked Sendable {
    private let store: KeyStore
    private let lock = NSLock()
    private var wrapped: Data?
    private var failedAttempts = 0
    private var _lockedUntil: Date?

    public static let maxAttempts = 5
    public static let lockoutWindow: TimeInterval = 300

    public init(store: KeyStore) { self.store = store }

    public var hasSecret: Bool {
        lock.lock(); defer { lock.unlock() }
        return wrapped != nil
    }

    public var lockedUntil: Date? {
        lock.lock(); defer { lock.unlock() }
        return _lockedUntil
    }

    public func importMnemonic(_ words: [String]) throws {
        _ = try BIP39.entropy(from: words)
        try seal(words.joined(separator: " "))
    }

    public func generate(wordCount: Int = 12) throws -> [String] {
        guard BIP39.wordCounts.contains(wordCount), BIP39.isReady else { throw BIP39Error.notInitialized }
        let entropyBytes = (wordCount * 11 - wordCount / 3) / 8
        var entropy = Data((0..<entropyBytes).map { _ in UInt8.random(in: 0...255) })
        defer { entropy.resetBytes(in: 0..<entropy.count) }
        let words = try BIP39.mnemonic(from: entropy)
        try seal(words.joined(separator: " "))
        return words
    }

    private func seal(_ phrase: String) throws {
        var data = Data(phrase.utf8)
        defer { data.resetBytes(in: 0..<data.count) }
        let w = try store.wrap(data, context: "mnemonic")
        lock.lock(); wrapped = w; lock.unlock()
    }

    /// 仅在签名窗口内短暂解包；出作用域立即擦除明文缓冲区。
    public func withSecret<T>(_ body: (String) throws -> T) throws -> T {
        lock.lock()
        if let until = _lockedUntil, until > .now {
            let remain = Int(until.timeIntervalSinceNow)
            lock.unlock()
            throw VaultError.locked(remain)
        }
        guard let w = wrapped else { lock.unlock(); throw VaultError.keyNotFound }
        lock.unlock()

        var plain = try store.unwrap(w, context: "mnemonic")
        defer { plain.resetBytes(in: 0..<plain.count) }
        let phrase = String(decoding: plain, as: UTF8.self)
        do {
            let out = try body(phrase)
            lock.lock(); failedAttempts = 0; lock.unlock()
            return out
        } catch {
            registerFailure()
            throw error
        }
    }

    private func registerFailure() {
        lock.lock(); defer { lock.unlock() }
        failedAttempts += 1
        if failedAttempts >= Self.maxAttempts {
            _lockedUntil = Date().addingTimeInterval(Self.lockoutWindow)
            failedAttempts = 0
        }
    }

    /// 彻底销毁：抹掉包裹体并重置失败计数。
    public func destroy() {
        lock.lock(); defer { lock.unlock() }
        if var w = wrapped { w.resetBytes(in: 0..<w.count) }
        wrapped = nil
        _lockedUntil = nil
        failedAttempts = 0
    }
}
