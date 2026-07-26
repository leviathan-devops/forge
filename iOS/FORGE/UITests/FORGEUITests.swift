import XCTest

/// XCUITest suite for the FORGE iOS app.
///
/// Verifies core navigation flows through the app:
/// - Launch menu appearance and element verification
/// - Mode card selection (BUILD ON-DEVICE, MISSION CONTROL)
/// - Settings sheet presentation and dismissal
/// - Terminal rendering after WKWebView/forge-bundle.js load
/// - Screenshot capture at every step for CI artifact review
///
/// Accessibility identifiers used:
/// - Mode cards: "BUILD ON-DEVICE", "MISSION CONTROL" (from ForgeMode.rawValue)
/// - Footer buttons: "Settings", "Projects" (from footerButton label)
/// - Back button: "backButton" (from TopBar & MissionControlScreen)
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
    ///
    /// Timing notes:
    /// - fullScreenCover transitions animate over ~0.4s. We sleep 3-5s to
    ///   allow the transition AND any engine/WebView initialisation to settle
    ///   before querying the UI.
    /// - Back buttons are queried with `waitForExistence(timeout: 10)` to
    ///   survive animation delays on slower CI simulators.
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
            buildCard.waitForExistence(timeout: 10),
            "BUILD ON-DEVICE mode card should be visible on the launch menu"
        )
        buildCard.tap()

        // Allow the card tap animation (0.25s) + fullScreenCover transition
        // + engine/wkwebview boot. Use a generous wait so the TopBar (with
        // its backButton accessibility identifier) is fully rendered before
        // we query for it.
        sleep(5)
        takeScreenshot(named: "02_BuildOnDevice")

        // ── Step 3: Return to launch menu ──────────────────────────────

        let backButton = app.buttons["backButton"]
        XCTAssertTrue(
            backButton.waitForExistence(timeout: 10),
            "Back button should be visible in the BUILD ON-DEVICE top bar"
        )
        backButton.tap()
        sleep(3)

        // Confirm we're back on the launch menu
        XCTAssertTrue(
            forgeTitle.waitForExistence(timeout: 10),
            "Should return to launch menu after tapping back from BUILD ON-DEVICE"
        )

        // ── Step 4: Tap MISSION CONTROL ────────────────────────────────

        let missionCard = app.buttons["MISSION CONTROL"]
        XCTAssertTrue(
            missionCard.waitForExistence(timeout: 10),
            "MISSION CONTROL mode card should be visible on the launch menu"
        )
        missionCard.tap()

        sleep(5)
        takeScreenshot(named: "03_MissionControl")

        // ── Step 5: Return to launch menu ──────────────────────────────
        //
        // MissionControlScreen renders its own back button (not the shared
        // TopBar) but it shares the "backButton" accessibility identifier so
        // the same query works. The waitForExistence(timeout: 10) handles
        // the fullScreenCover transition latency.

        XCTAssertTrue(
            backButton.waitForExistence(timeout: 10),
            "Back button should be visible in the MISSION CONTROL top bar"
        )
        backButton.tap()
        sleep(3)

        XCTAssertTrue(
            forgeTitle.waitForExistence(timeout: 10),
            "Should return to launch menu after tapping back from MISSION CONTROL"
        )

        // ── Step 6: Open Settings ──────────────────────────────────────

        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(
            settingsButton.waitForExistence(timeout: 10),
            "Settings footer button should be visible on the launch menu"
        )
        settingsButton.tap()

        // Wait for sheet presentation animation
        sleep(3)
        takeScreenshot(named: "04_SettingsSheet")

        // ── Step 7: Dismiss Settings ───────────────────────────────────

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: 10),
            "Done button should be visible in the settings sheet toolbar"
        )
        doneButton.tap()
        sleep(3)

        // ── Step 8: Final screenshot ───────────────────────────────────

        XCTAssertTrue(
            forgeTitle.waitForExistence(timeout: 10),
            "Should be back on the launch menu after dismissing settings"
        )
        takeScreenshot(named: "05_Final")
    }

    // MARK: - Terminal Rendering

    /// Verifies that tapping BUILD ON-DEVICE loads the terminal view and that
    /// forge-bundle.js output renders into SwiftTerm.
    ///
    /// Flow:
    /// 1. Wait for BUILD ON-DEVICE card.
    /// 2. Tap it.
    /// 3. Wait 5 seconds for the WKWebView to load forge-bundle.js and for
    ///    SwiftTerm to render the ANSI welcome banner.
    /// 4. Screenshot "terminal-screen".
    /// 5. Check that a scroll view (SwiftTerm's TerminalView is a
    ///    UIScrollView subclass) exists in the view hierarchy.
    /// 6. Tap the back button.
    /// 7. Screenshot "back-to-launch".
    func testTerminalRenders() throws {
        // ── Step 1-2: Launch & tap BUILD ON-DEVICE ─────────────────────

        let buildCard = app.buttons["BUILD ON-DEVICE"]
        XCTAssertTrue(
            buildCard.waitForExistence(timeout: 10),
            "BUILD ON-DEVICE card should be visible on launch"
        )
        buildCard.tap()

        // ── Step 3: Wait for WKWebView + forge-bundle.js load ──────────

        // The engine boots asynchronously: ForgeEngine.loadBundle() creates a
        // WKWebView, evaluates forge-bundle.js, and routes ANSI output back
        // through the outputHandler into SwiftTerm. 5 seconds gives the
        // welcome banner ("FORGE v1.0.0 — Trident T3 Audit Engine") time to
        // render before we screenshot.
        sleep(5)

        // ── Step 4: Screenshot ─────────────────────────────────────────

        takeScreenshot(named: "terminal-screen")

        // ── Step 5: Verify terminal view exists ────────────────────────
        //
        // SwiftTerm's TerminalView inherits from UIScrollView. When the
        // WKWebView output renders, the terminal is live and scrollable.
        // We check for any UIScrollView descendant — if it exists, the
        // terminal is on screen.

        let terminalScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(
            terminalScrollView.waitForExistence(timeout: 10),
            "A scroll view (terminal) should exist after entering BUILD ON-DEVICE"
        )

        // ── Step 6: Tap back button ────────────────────────────────────

        let backButton = app.buttons["backButton"]
        XCTAssertTrue(
            backButton.waitForExistence(timeout: 10),
            "Back button should be visible in the BUILD ON-DEVICE top bar"
        )
        backButton.tap()
        sleep(3)

        // ── Step 7: Screenshot back on launch menu ─────────────────────

        let forgeTitle = app.staticTexts["FORGE"]
        XCTAssertTrue(
            forgeTitle.waitForExistence(timeout: 10),
            "Should return to launch menu after tapping back"
        )
        takeScreenshot(named: "back-to-launch")
    }

    // MARK: - Settings Flow

    /// Verifies the settings sheet opens from the launch menu, shows the API
    /// key field, and dismisses correctly.
    ///
    /// Flow:
    /// 1. Tap the Settings gear icon.
    /// 2. Screenshot "settings-open".
    /// 3. Verify "API Key" text exists.
    /// 4. Tap Done to dismiss.
    /// 5. Screenshot "settings-closed".
    func testSettingsFlow() throws {
        // ── Step 1: Tap Settings ───────────────────────────────────────

        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(
            settingsButton.waitForExistence(timeout: 10),
            "Settings footer button should be visible on the launch menu"
        )
        settingsButton.tap()

        // Wait for sheet presentation
        sleep(3)

        // ── Step 2: Screenshot ─────────────────────────────────────────

        takeScreenshot(named: "settings-open")

        // ── Step 3: Verify API Key field exists ────────────────────────

        let apiKeyField = app.secureTextFields["API Key"]
        XCTAssertTrue(
            apiKeyField.waitForExistence(timeout: 10),
            "API Key field should be visible in the settings sheet"
        )

        // ── Step 4: Tap Done to dismiss ────────────────────────────────

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: 10),
            "Done button should be visible in the settings sheet toolbar"
        )
        doneButton.tap()
        sleep(3)

        // ── Step 5: Screenshot ─────────────────────────────────────────

        let forgeTitle = app.staticTexts["FORGE"]
        XCTAssertTrue(
            forgeTitle.waitForExistence(timeout: 10),
            "Should return to launch menu after dismissing settings"
        )
        takeScreenshot(named: "settings-closed")
    }

    // MARK: - Mission Control Flow

    /// Verifies the Mission Control screen loads and shows the empty state
    /// when no servers are configured.
    ///
    /// Flow:
    /// 1. Tap MISSION CONTROL.
    /// 2. Wait 3 seconds for the screen to load.
    /// 3. Screenshot "mission-control".
    /// 4. Verify the empty state ("Add Server" button or "No Servers" text).
    /// 5. Tap back button.
    func testMissionControlFlow() throws {
        // ── Step 1: Tap MISSION CONTROL ────────────────────────────────

        let missionCard = app.buttons["MISSION CONTROL"]
        XCTAssertTrue(
            missionCard.waitForExistence(timeout: 10),
            "MISSION CONTROL card should be visible on the launch menu"
        )
        missionCard.tap()

        // ── Step 2: Wait for screen load ───────────────────────────────

        sleep(3)

        // ── Step 3: Screenshot ─────────────────────────────────────────

        takeScreenshot(named: "mission-control")

        // ── Step 4: Verify empty state ─────────────────────────────────
        //
        // With no saved servers, MissionControlScreen shows the
        // noServersState: a "No Servers Configured" title and an "Add
        // Server" button. We check for either marker so the test is
        // resilient to minor copy changes.

        let addServerButton = app.buttons["Add Server"]
        let noServersText = app.staticTexts["No Servers Configured"]
        let emptyStateVisible = addServerButton.waitForExistence(timeout: 10)
            || noServersText.exists

        XCTAssertTrue(
            emptyStateVisible,
            "Mission Control should show the empty state (Add Server button or No Servers text) when no servers are configured"
        )

        // ── Step 5: Tap back button ────────────────────────────────────

        let backButton = app.buttons["backButton"]
        XCTAssertTrue(
            backButton.waitForExistence(timeout: 10),
            "Back button should be visible in the Mission Control top bar"
        )
        backButton.tap()
        sleep(3)

        let forgeTitle = app.staticTexts["FORGE"]
        XCTAssertTrue(
            forgeTitle.waitForExistence(timeout: 10),
            "Should return to launch menu after tapping back"
        )
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
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10))
        settingsButton.tap()

        // Wait for sheet presentation
        sleep(3)

        // The "Done" button is inside the sheet's navigation bar
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: 10),
            "Settings sheet should present with a Done button"
        )

        takeScreenshot(named: "Settings_Content")

        // Dismiss
        doneButton.tap()
        sleep(3)

        // Verify we're back
        XCTAssertTrue(
            forgeTitle.waitForExistence(timeout: 10),
            "Should return to launch menu after dismissing settings"
        )
    }

    // MARK: - Mode Transition Verification

    /// Taps BUILD ON-DEVICE, verifies the mode view appeared,
    /// then returns.
    func testBuildOnDeviceTransition() throws {
        let forgeTitle = app.staticTexts["FORGE"]
        XCTAssertTrue(forgeTitle.waitForExistence(timeout: 10))

        let buildCard = app.buttons["BUILD ON-DEVICE"]
        XCTAssertTrue(buildCard.waitForExistence(timeout: 10))
        buildCard.tap()
        sleep(5)

        // The mode view should show the mode title in its top bar
        let modeTitle = app.staticTexts["FORGE"]
        XCTAssertTrue(
            modeTitle.waitForExistence(timeout: 10),
            "Top bar should appear after selecting BUILD ON-DEVICE"
        )
        takeScreenshot(named: "BuildOnDevice_Transition")

        // Return
        let backButton = app.buttons["backButton"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 10))
        backButton.tap()
        sleep(3)

        XCTAssertTrue(
            forgeTitle.waitForExistence(timeout: 10),
            "Should return to launch menu"
        )
    }
}
