import XCTest

final class LaunchTests: XCTestCase {

    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify the main window exists
        XCTAssertTrue(app.windows.count > 0, "App should have at least one window")
    }
}
