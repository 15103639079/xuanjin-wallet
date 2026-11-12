import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// BIP39 骨架：只暴露必要 API，词表通过资源注入，避免打进二进制被静态提取。
public enum BIP39Error: Error, Sendable { case badWordCount, badChecksum, unknownWord(String), notInitialized }

public struct BIP39 {
    public static let wordCounts = [12, 15, 18, 21, 24]
    nonisolated(unsafe) private static var wordlist: [String] = []
    nonisolated(unsafe) private static var wordIndex: [String: Int] = [:]

    /// 词表应从加密资源加载（见 WordlistLoader），不硬编码在源码里。
    public static func configure(wordlist words: [String]) {
        precondition(words.count == 2048, "BIP39 词表必须 2048 条")
        wordlist = words
        wordIndex = Dictionary(uniqueKeysWithValues: words.enumerated().map { ($1, $0) })
    }

    public static var isReady: Bool { wordlist.count == 2048 }

    public static func entropy(from mnemonic: [String]) throws -> Data {
        guard isReady else { throw BIP39Error.notInitialized }
        guard wordCounts.contains(mnemonic.count) else { throw BIP39Error.badWordCount }
        var bits = ""
        for w in mnemonic {
            guard let idx = wordIndex[w] else { throw BIP39Error.unknownWord(w) }
            bits += String(idx, radix: 2).padLeft(to: 11, with: "0")
        }
        let csLen = mnemonic.count / 3
        let entropyBits = bits.count - csLen
        let entropyStr = String(bits.prefix(entropyBits))
        let checksumStr = String(bits.suffix(csLen))
        let entropy = Data(binToBytes(entropyStr))
        let expect = checksumBits(for: entropy, bits: csLen)
        guard expect == checksumStr else { throw BIP39Error.badChecksum }
        return entropy
    }

    public static func mnemonic(from entropy: Data) throws -> [String] {
        guard isReady else { throw BIP39Error.notInitialized }
        guard [16, 20, 24, 28, 32].contains(entropy.count) else { throw BIP39Error.badWordCount }
        let csLen = entropy.count / 4
        var bits = entropy.map { String($0, radix: 2).padLeft(to: 8, with: "0") }.joined()
        bits += checksumBits(for: entropy, bits: csLen)
        var words: [String] = []
        var i = bits.startIndex
        while i < bits.endIndex {
            let j = bits.index(i, offsetBy: 11)
            let idx = Int(bits[i..<j], radix: 2)!
            words.append(wordlist[idx])
            i = j
        }
        return words
    }

    static func checksumBits(for entropy: Data, bits: Int) -> String {
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: entropy)
        let first = Array(digest).first ?? 0
        return String(first, radix: 2).padLeft(to: 8, with: "0").prefix(bits).description
        #else
        return String(repeating: "0", count: bits)
        #endif
    }

    static func binToBytes(_ s: String) -> [UInt8] {
        stride(from: 0, to: s.count, by: 8).map { off in
            let start = s.index(s.startIndex, offsetBy: off)
            let end = s.index(start, offsetBy: min(8, s.count - off))
            return UInt8(s[start..<end], radix: 2) ?? 0
        }
    }
}

extension String {
    func padLeft(to n: Int, with ch: Character) -> String {
        count >= n ? self : String(repeating: ch, count: n - count) + self
    }
}
