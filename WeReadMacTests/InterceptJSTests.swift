import XCTest
@testable import WeReadMac

final class InterceptJSTests: XCTestCase {
    func testInterceptJSExistsInBundle() {
        let url = Bundle.main.url(forResource: "intercept", withExtension: "js")
        // In test host context, the bundle is the app bundle
        // This test verifies the resource was properly added
        if url == nil {
            // When running tests, check the test bundle as well
            let testBundle = Bundle(for: type(of: self))
            let testUrl = testBundle.url(forResource: "intercept", withExtension: "js")
            XCTAssertTrue(url != nil || testUrl != nil, "intercept.js should be loadable from the app or test bundle")
        }
    }

    func testInterceptJSContentIsNotEmpty() {
        let url = Bundle.main.url(forResource: "intercept", withExtension: "js")
            ?? Bundle(for: type(of: self)).url(forResource: "intercept", withExtension: "js")

        if let url = url {
            let content = try? String(contentsOf: url, encoding: .utf8)
            XCTAssertNotNil(content)
            XCTAssertFalse(content?.isEmpty ?? true)
            XCTAssertTrue(content?.contains("notesCapture") ?? false, "intercept.js should reference notesCapture message handler")
        }
    }
}
