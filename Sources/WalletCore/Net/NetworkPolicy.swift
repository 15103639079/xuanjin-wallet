import Foundation

/// 网络策略：只允许固定节点，强制 TLS1.2+，禁止明文与代理，禁止 WebView。
public struct NetworkPolicy: Sendable {
    public let allowedHosts: Set<String>
    public let pinnedSPKI: [String: Data]      // host -> SPKI SHA256

    public init(allowedHosts: Set<String>, pinnedSPKI: [String: Data]) {
        self.allowedHosts = allowedHosts
        self.pinnedSPKI = pinnedSPKI
    }

    public func allows(_ url: URL) -> Bool {
        guard url.scheme == "https", let host = url.host else { return false }
        return allowedHosts.contains(host)
    }

    /// 生产环境必须用本回调做证书固定；示例只校验主机白名单。
    public func validate(host: String, spkiHash: Data) -> Bool {
        guard let expected = pinnedSPKI[host] else { return false }
        return expected == spkiHash
    }

    /// 严格配置：不开 ATS 例外，不启用 WebKit。
    public static func strictSession() -> URLSession {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.httpShouldSetCookies = false
        cfg.httpCookieStorage = nil
        cfg.urlCache = nil
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.tlsMinimumSupportedProtocolVersion = .TLSv12
        cfg.connectionProxyDictionary = [:]
        return URLSession(configuration: cfg)
    }
}
