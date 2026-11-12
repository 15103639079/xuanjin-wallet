import Foundation

/// 词表加载：优先从包资源读，其次从应用自带加密资源注入。
/// 词表不进日志、不进崩溃报告；缺失时抛错而不是退回空表。
public enum WordlistLoader {
    public static func loadBundledEnglish() throws -> [String] {
        guard let url = Bundle.module.url(forResource: "bip39-english", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw BIP39Error.notInitialized
        }
        let words = text.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard words.count == 2048 else { throw BIP39Error.badWordCount }
        return words
    }

    public static func configure() throws {
        BIP39.configure(wordlist: try loadBundledEnglish())
    }
}
