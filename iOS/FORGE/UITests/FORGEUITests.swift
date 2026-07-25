import XCTest

/// XCUITest suite for the FORGE iOS app.
///
/// Verifies core navigation flows through the app:
/// - Launch menu appearance and element verification
/// - Mode card selection (BUILD ON-DEVICE, MISSION CONTROL)
/// - Settings sheet presentation and dismissal
/// - Screenshot capture at every step for CI artifact review
///
/// Accessibility identifiers used:
/// - Mode cards: "BUILD ON-DEVICE", "MISSION CONTROL" (from ForgeMode.rawValue)
/// - Footer buttons: "Settings", "Projects" (from footerButton label)
/// - Back button: "backButton" (from TopBar)
final class FORGEUITests: XCTestCase {

    /// The app instance under test.
    var app: XCUIApplication!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        // Stop on first failure so we get clean, focused test reports
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Screenshot Helper

    /// Captures a full-screen screenshot and attaches it to the test report.
    ///
    /// The attachment uses `.keepAlways` lifetime so it persists into the
    /// `.xcresult` bundle and can be extracted as a CI artifact.
    ///
    /// - Parameter name: A descriptive name for the screenshot (e.g. "01_LaunchMenu").
    func takeScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Full Navigation Flow

    /// Walks the primary user journey end-to-end:
    ///
    /// 1. Launch menu screenshot
    /// 2. Tap BUILD ON-DEVICE → mode view screenshot → return
    /// 3. Tap MISSION CONTROL → mode view screenshot → return
    /// 4. Tap Settings → settings sheet screenshot → dismiss
    /// 5. Final screenshot
    func testFullNavigationFlow() throws {
        // ── Step 1: Verify launch menu appeared ────────────────────────

        let forgeTitle = app.staticTexts["FORGE"]
        XCTAssertTrue(
            forgeTitle.waitForExistence(timeout: 10),
            "FORGE title should be visible on the launch menu after app launch"
        )
        takeScreenshot(named: "01_LaunchMenu")

        // ── Step 2: Tap BUILD ON-DEVICE ────────────────────────────────

        let buildCard = app.buttons["BUILD ON-DEVICE"]
        XCTAssertTrue(
            buildCard.waitForExistence(timeout: 5),
            "BUILD ON-DEVICE mode card should be visible on the launch menu"
        )
        buildCard.tap()

        // Allow the card tap animation (0.25s) + fullScreenCover transition
        sleep(3)
        takeScreenshot(named: "02_BuildOnDevice")

        // ── Step 3: Return to launch menu ──────────────────────────────

        let backButton = app.buttons["backButton"]
        XCTAssertTrue(
            backButton.waitForExistence(timeout: 5),
            "Back button should be visible in the BUILD ON-DEVICE top bar"
        )
        backButton.tap()
        sleep(2)

        // Confirm we're back on the launch menu
        XCTAssertTrue(
            forgeTitle.waitForExistence(timeout: 5),
            "Should return to launch menu after tapping back from BUILD ON-DEVICE"
        )

        // ── Step 4: Tap MISSION CONTROL ────────────────────────────────

        let missionCard = app.buttons["MISSION CONTROL"]
        XCTAssertTrue(
            missionCard.waitForExistence(timeout: 5),
            "MISSION CONTROL mode card should be visible on the launch menu"
        )
        missionCard.tap()

        sleep(3)
        takeScreenshot(named: "03_MissionControl")

        // ── Step 5: Return to launch menu ──────────────────────────────

        XCTAssertTrue(
            backButton.waitForExistence(timeout: 5),
            "Back button should be visible in the MISSION CONTROL top bar"
        )
        backButton.tap()
        sleep(2)

        XCTAssertTrue(
            forgeTitle.waitForExistence(timeout: 5),
            "Should return to launch menu after tapping back from MISSION CONTROL"
        )

        // ── Step 6: Open Settings ──────────────────────────────────────

        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(
            settingsButton.waitForExistence(timeout: 5),
            "Settings footer button should be visible on the launch menu"
        )
        settingsButton.tap()

        // Wait for sheet presentation animation
        sleep(2)
        takeScreenshot(named: "04_SettingsSheet")

        // ── Step 7: Dismiss Settings ───────────────────────────────────

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: 5),
            "Done button should be visible in the settings sheet toolbar"
        )
        doneButton.tap()
        sleep(2)

        // ── Step 8: Final screenshot ───────────────────────────────────

        XCTAssertTrue(
            forgeTitle.waitForExistence(timeout: 5),
            "Should be back on the launch menu after dismissing settings"
        )
        takeScreenshot(named: "05_Final")
    }

    // MARK: - Launch Menu Elements

    /// Verifies that all expected launch menu elements are present and tappable.
    func testLaunchMenuElements() throws {
        let forgeTitle = app.staticTexts["FORGE"]
        XCTAssertTrue(
            forgeTitle.waitForExistence(timeout: 10),
            "FORGE title should appear on launch"
        )

        // Both mode cards
        XCTAssertTrue(
            app.buttons["BUILD ON-DEVICE"].exists,
            "BUILD ON-DEVICE card should exist on the launch menu"
        )
        XCTAssertTrue(
            app.buttons["MISSION CONTROL"].exists,
            "MISSION CONTROL card should exist on the launch menu"
        )

        // Footer buttons
        XCTAssertTrue(
            app.buttons["Settings"].exists,
            "Settings footer button should exist on the launch menu"
        )
        XCTAssertTrue(
            app.buttons["Projects"].exists,
            "Projects footer button should exist on the launch menu"
        )

        takeScreenshot(named: "LaunchMenu_Elements")
    }

    // MARK: - Settings Sheet

    /// Opens settings from the launch menu, verifies the sheet content,
    /// then dismisses it.
    func testSettingsSheetContent() throws {
        let forgeTitle = app.staticTexts["FORGE"]
        XCTAssertTrue(forgeTitle.waitForExistence(timeout: 10))

        // Tap settings
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        // The "Done" button is inside the sheet's navigation bar
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: 5),
            "Settings sheet should present with a Done button"
        )

        takeScreenshot(named: "Settings_Content")

        // Dismiss
        doneButton.tap()
        sleep(1)

        // Verify we're back
        XCTAssertTrue(
            forgeTitle.waitForExistence(timeout: 5),
            "Should return to launch menu after dismissing settings"
        )
    }

    // MARK: - Mode Transition Verification

    /// Taps BUILD ON-DEVICE, verifies the mode placeholder appeared,
    /// then returns.
    func testBuildOnDeviceTransition() throws {
        let forgeTitle = app.staticTexts["FORGE"]
        XCTAssertTrue(forgeTitle.waitForExistence(timeout: 10))

        let buildCard = app.buttons["BUILD ON-DEVICE"]
        XCTAssertTrue(buildCard.waitForExistence(timeout: 5))
        buildCard.tap()
        sleep(3)

        // The mode view should show the mode title in its top bar
        let modeTitle = app.staticTexts["BUILD ON-DEVICE"]
        XCTAssertTrue(
            modeTitle.waitForExistence(timeout: 5),
            "Mode title should appear in the top bar after selecting BUILD ON-DEVICE"
        )
        takeScreenshot(named: "BuildOnDevice_Transition")

        // Return
        let backButton = app.buttons["backButton"]
        XCTAssertTrue(backButton.exists)
        backButton.tap()
        sleep(2)

        XCTAssertTrue(
            forgeTitle.waitForExistence(timeout: 5),
            "Should return to launch menu"
        )
    }
}
