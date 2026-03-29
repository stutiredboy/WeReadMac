import Foundation

enum NavigationPolicy {
    case allow
    case external
}

func evaluateNavigationPolicy(for url: URL) -> NavigationPolicy {
    guard let host = url.host?.lowercased() else { return .allow }

    // Allow weread and related qq.com domains (covers WeChat OAuth login flow)
    if host == "weread.qq.com" || host.hasSuffix(".weread.qq.com") {
        return .allow
    }
    if host.hasSuffix(".qq.com") {
        return .allow
    }

    return .external
}
