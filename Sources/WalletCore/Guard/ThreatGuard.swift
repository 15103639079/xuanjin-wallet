import Foundation
import Darwin

/// 运行环境体检：越狱 / 调试器 / 注入 / Hook / VPN+代理 / 时间回拨。
/// 设计原则：只做"降级或拒绝敏感操作"，不做显式弹窗提示原因（避免被引导绕过）。
public struct ThreatReport: Sendable {
    public let jailbroken: Bool
    public let debuggerAttached: Bool
    public let suspiciousImages: [String]
    public let proxyEnabled: Bool
    public let timeSkew: TimeInterval?

    public var isTrusted: Bool {
        !jailbroken && !debuggerAttached && suspiciousImages.isEmpty
    }
}

public enum ThreatGuard {

    // MARK: 越狱痕迹
    private static let jailbreakPaths = [
        "/Applications/Cydia.app", "/Applications/Sileo.app", "/Applications/Zebra.app",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/Library/MobileSubstrate/DynamicLibraries",
        "/var/jb", "/var/lib/dpkg/status", "/private/var/lib/apt",
        "/usr/sbin/frida-server", "/usr/bin/cycript", "/usr/lib/libcycript.dylib",
        "/bin/bash", "/bin/sh", "/usr/sbin/sshd", "/etc/apt",
        "/private/var/lib/dpkg/info/com.opa334.trollstore.list",
    ]

    public static func isJailbroken() -> Bool {
        for p in jailbreakPaths where FileManager.default.fileExists(atPath: p) { return true }
        // 沙盒逃逸探测：能写到沙盒外即视为越狱
        let probe = "/private/var/mobile/.sw_probe"
        if (try? "x".write(toFile: probe, atomically: true, encoding: .utf8)) != nil {
            try? FileManager.default.removeItem(atPath: probe)
            return true
        }
        // 可执行 shell（越狱环境常见）
        if access("/bin/sh", X_OK) == 0 || access("/usr/bin/ssh", X_OK) == 0 { return true }
        return false
    }

    // MARK: 调试器
    public static func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    // MARK: 注入的 dylib / Hook 框架
    private static let suspiciousNameFragments = [
        "frida", "cycript", "substrate", "libhooker", "ellekit",
        "klog", "xpf", "grabkernel", "kfd", "weightbufs", "dopamine",
        "trollstore", "palerain", "unc0ver",
    ]

    public static func suspiciousImages() -> [String] {
        var names: [String] = []
        let count = _dyld_image_count()
        for i in 0..<count {
            guard let cname = _dyld_get_image_name(i) else { continue }
            let name = String(cString: cname).lowercased()
            if suspiciousNameFragments.contains(where: { name.contains($0) }) { names.append(name) }
        }
        return names
    }

    // MARK: 网络环境
    public static func proxyEnabled() -> Bool {
        let env = ProcessInfo.processInfo.environment
        return env["HTTP_PROXY"] != nil || env["HTTPS_PROXY"] != nil
    }

    /// 与可信时间源偏差（可选，联网后校准）；超出 5 分钟视为异常。
    public static func timeSkew(against trusted: Date) -> TimeInterval {
        abs(Date().timeIntervalSince(trusted))
    }

    public static func audit(trustedTime: Date? = nil) -> ThreatReport {
        ThreatReport(
            jailbroken: isJailbroken(),
            debuggerAttached: isDebuggerAttached(),
            suspiciousImages: suspiciousImages(),
            proxyEnabled: proxyEnabled(),
            timeSkew: trustedTime.map { timeSkew(against: $0) }
        )
    }
}
