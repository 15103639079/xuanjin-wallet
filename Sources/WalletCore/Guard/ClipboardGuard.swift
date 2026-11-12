import Foundation
#if os(iOS)
import UIKit
#endif

/// 剪贴板：默认禁止写入；必须写入时 60 秒后自动清空，且标记为本地私密内容。
public final class ClipboardGuard: @unchecked Sendable {
    public static let shared = ClipboardGuard()
    private var clearTask: Task<Void, Never>?
    private init() {}

    public enum Policy {
        case never
        case allowWithAutoClear(seconds: TimeInterval)
    }

    public func copy(_ text: String, policy: Policy = .allowWithAutoClear(seconds: 60)) {
        switch policy {
        case .never: return
        case .allowWithAutoClear(let seconds):
            #if os(iOS)
            UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: text]],
                                          options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(seconds)])
            #else
            _ = text
            #endif
            clearTask?.cancel()
            clearTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(seconds))
                guard !Task.isCancelled else { return }
                self?.clear()
            }
        }
    }

    public func clear() {
        #if os(iOS)
        UIPasteboard.general.items = []
        #endif
    }
}
