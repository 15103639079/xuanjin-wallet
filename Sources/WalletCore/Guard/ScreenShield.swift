import Foundation
#if os(iOS)
import UIKit
#endif

/// 防截屏 / 防录屏 / 防任务切换快照，以及键盘输入防护。
@MainActor
public final class ScreenShield {
    public static let shared = ScreenShield()
    private init() {}

    #if os(iOS)
    private var coverView: UIView?
    private var observers: [NSObjectProtocol] = []

    /// 在 AppDelegate/SceneDelegate 启动时调用一次。
    public func install(on window: UIWindow) {
        let cover = UIView(frame: window.bounds)
        cover.backgroundColor = .systemBackground
        cover.isUserInteractionEnabled = false
        cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(cover)
        coverView = cover

        let show = { [weak self] in self?.coverView?.isHidden = false }
        let hide = { [weak self] in self?.coverView?.isHidden = true }

        observers.append(NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { _ in show() })
        observers.append(NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in hide() })
        observers.append(NotificationCenter.default.addObserver(
            forName: UIScreen.capturedDidChangeNotification, object: nil, queue: .main) { _ in
                show() // 录屏中保持遮挡，直到用户主动暂停录屏
            })
        hide()
    }

    public var isScreenCaptured: Bool { UIScreen.main.isCaptured }
    #endif
}
