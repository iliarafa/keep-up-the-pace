import XCTest

/// M2's exit check: a full demo walk runs on the simulator, from the setup screen to the
/// arrived screen and back.
final class DemoWalkUITests: XCTestCase {
    @MainActor
    func testDemoWalkArrivesEarlyAndReturnsToSetup() throws {
        let app = XCUIApplication()
        app.launch()

        let preview = app.buttons["demoButton"]
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        preview.tap()

        XCTAssertTrue(app.buttons["endButton"].waitForExistence(timeout: 10), "the walk screen should appear")
        XCTAssertTrue(app.staticTexts["deltaReadout"].exists)

        // The demo starts 280 m out and walks at about 1.72 m/s: roughly 2.5 minutes.
        let result = app.staticTexts["arrivedResult"]
        XCTAssertTrue(result.waitForExistence(timeout: 240), "the demo walk should arrive within 4 minutes")
        // It plans at 0.85 m/s but walks at ~1.72 m/s, so it always arrives early.
        XCTAssertTrue(result.label.hasSuffix("early"), "unexpected result: \(result.label)")

        app.buttons["doneButton"].tap()
        XCTAssertTrue(preview.waitForExistence(timeout: 10), "Done should return to the setup screen")
    }
}
