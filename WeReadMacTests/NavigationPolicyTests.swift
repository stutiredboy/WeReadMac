import XCTest
@testable import WeReadMac

final class NavigationPolicyTests: XCTestCase {

    func testWeReadMainDomain() {
        let url = URL(string: "https://weread.qq.com")!
        XCTAssertEqual(evaluateNavigationPolicy(for: url), .allow)
    }

    func testWeReadSubdomain() {
        let url = URL(string: "https://res.weread.qq.com/image/test.png")!
        XCTAssertEqual(evaluateNavigationPolicy(for: url), .allow)
    }

    func testWeChatOAuthDomain() {
        let url = URL(string: "https://open.weixin.qq.com/connect/qrconnect")!
        XCTAssertEqual(evaluateNavigationPolicy(for: url), .allow)
    }

    func testQQSubdomain() {
        let url = URL(string: "https://login.qq.com/auth")!
        XCTAssertEqual(evaluateNavigationPolicy(for: url), .allow)
    }

    func testExternalDomainGoogle() {
        let url = URL(string: "https://google.com")!
        XCTAssertEqual(evaluateNavigationPolicy(for: url), .external)
    }

    func testExternalDomainExample() {
        let url = URL(string: "https://example.com/page")!
        XCTAssertEqual(evaluateNavigationPolicy(for: url), .external)
    }

    func testURLWithNoHost() {
        let url = URL(string: "about:blank")!
        XCTAssertEqual(evaluateNavigationPolicy(for: url), .allow)
    }

    func testDataURL() {
        let url = URL(string: "data:text/html,<h1>test</h1>")!
        XCTAssertEqual(evaluateNavigationPolicy(for: url), .allow)
    }

    func testWeReadWithPath() {
        let url = URL(string: "https://weread.qq.com/web/reader/abc123")!
        XCTAssertEqual(evaluateNavigationPolicy(for: url), .allow)
    }
}

extension NavigationPolicy: @retroactive Equatable {
    public static func == (lhs: NavigationPolicy, rhs: NavigationPolicy) -> Bool {
        switch (lhs, rhs) {
        case (.allow, .allow), (.external, .external):
            return true
        default:
            return false
        }
    }
}
