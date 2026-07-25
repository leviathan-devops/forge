import XCTest

/// Launch performance and smoke tests for the FORGE iOS app.
///
/// These tests measure startup time and verify the app reaches a
/// usable state quickly after launch.
final class FORGEUITestsLaunchTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Launch Performance

    /// Measures the time it takes to cold-launch the app and render the
    /// launch menu. Runs multiple iterations for statistical stability.
    @MainActor
    func testLaunchPerformance() throws {
        // XCTApplicationLaunchMetric is available on iOS 13.0+
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launch()

            // Block until the launch menu actually rendered — measuring
            // not just process start but time-to-first-useful-content.
            _ = app.staticTexts["FORGE"].waitForExistence(timeout: 10)

            app.terminate()
        }
    }

    // MARK: - Launch Smoke Test

    /// Launches the app and captures a screenshot immediately after the
    /// launch menu appears. Verifies the app didn't crash on startup.
    func testLaunchAndScreenshot() throws {
        let app = XCUIApplication()
        app.launch()

        let forgeTitle = app.staticTexts["FORGE"]
        XCTAssertTrue(
            forgeTitle.waitForExistence(timeout: 10),
            "App should launch and display the FORGE title within 10 seconds"
        )

        // Capture the post-launch screenshot
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Launch_Immediate"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
