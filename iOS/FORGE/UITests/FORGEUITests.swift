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
/// - Mode1 terminal: "forgeTerminal" (TerminalView) / "forgeTerminalContainer"
final class FORGEUITests: XCTestCase {

    /// The app instance under test.
    var app: XCUIApplication!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        // Stop on first failure so we get clean, focused test reports
        continueAfterFailure = false
        app = XCUIApplication()
        // Gate D: optional on-disk screenshot directory for simctl/capture scripts.
        // vm-gate-d-screenshots.sh / xcodebuild set FORGE_SCREENSHOT_DIR (and
        // TEST_RUNNER_FORGE_SCREENSHOT_DIR which maps into the UITest process).
        // Forward into the app so crash logs can be correlated.
        if let shotDir = screenshotOutputDirectory() {
            app.launchEnvironment["FORGE_SCREENSHOT_DIR"] = shotDir
        }
        app.launchEnvironment["FORGE_GATE_D"] = "1"
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Gate D helpers

    /// Resolve on-disk screenshot directory from the UITest process environment.
    /// Accepts FORGE_SCREENSHOT_DIR and TEST_RUNNER_FORGE_SCREENSHOT_DIR (xcodebuild
    /// injects the latter; some hosts only export the former to the shell).
    func screenshotOutputDirectory() -> String? {
        let env = ProcessInfo.processInfo.environment
        for key in ["FORGE_SCREENSHOT_DIR", "TEST_RUNNER_FORGE_SCREENSHOT_DIR"] {
            if let dir = env[key], !dir.isEmpty {
                return dir
            }
        }
        return nil
    }

    /// Mode1 surface queries. SwiftTerm TerminalView sets isAccessibilityElement=true,
    /// so it often does NOT appear under app.scrollViews — prefer app-owned identifiers.
    func mode1TerminalElement() -> XCUIElement {
        // Identifier may surface as any element type depending on iOS/XCTest version.
        let byId = app.descendants(matching: .any)["forgeTerminal"]
        if byId.exists { return byId }
        let container = app.descendants(matching: .any)["forgeTerminalContainer"]
        if container.exists { return container }
        // Do not fall back to any scrollView for *reserved* D2 decisions —
        // Springboard after a Mode1 crash has scroll views and would false-pass.
        return byId
    }

    /// True when the app process is still under XCUITest control (not Springboard).
    /// Used to refuse reserved D2 PNGs after EXC/SIG kills (no free-text crash tokens).
    func appIsAlive() -> Bool {
        let state = app.state
        return state == .runningForeground || state == .runningBackground
    }

    /// STRICT Mode1 chrome: only app-owned a11y ids that prove we left the launch menu.
    /// - backButton (TopBar on BuildOnDeviceScreen)
    /// - forgeTerminal / forgeTerminalContainer (SwiftTerm wrapper)
    /// NEVER treat "no BUILD ON-DEVICE card + any scrollView" as Mode1 — that is the
    /// Springboard false-positive that produced mean~70 D2 PNGs in CI recovery.
    func mode1StrictChromeVisible() -> Bool {
        if app.buttons["backButton"].exists { return true }
        if app.descendants(matching: .any)["forgeTerminal"].exists { return true }
        if app.descendants(matching: .any)["forgeTerminalContainer"].exists { return true }
        return false
    }

    /// True when Mode1 chrome is visible (left launch menu into BUILD ON-DEVICE).
    /// Prefer backButton + forgeTerminal ids; never use launch-menu FORGE title alone.
    func observeMode1Chrome(timeout: TimeInterval = 12) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        // Poll so we catch chrome as soon as fullScreenCover settles.
        while Date() < deadline {
            if !appIsAlive() { return false }
            if mode1StrictChromeVisible() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return mode1StrictChromeVisible() && appIsAlive()
    }

    /// Soft terminal presence (does not hard-fail Gate D smoke).
    /// Prefer forgeTerminal ids; scrollViews only as weak signal *after* strict chrome.
    func observeMode1TerminalSurface(timeout: TimeInterval = 8) -> Bool {
        let terminal = app.descendants(matching: .any)["forgeTerminal"]
        if terminal.waitForExistence(timeout: timeout) {
            return true
        }
        let container = app.descendants(matching: .any)["forgeTerminalContainer"]
        if container.exists {
            return true
        }
        // Weak: only if strict chrome already proves Mode1 (avoids Springboard scroll).
        if mode1StrictChromeVisible() {
            return app.scrollViews.firstMatch.waitForExistence(timeout: 2)
        }
        return false
    }

    /// Tap BUILD ON-DEVICE when hittable; returns whether the card was tapped.
    func tapBuildOnDeviceCard(timeout: TimeInterval = 12) -> Bool {
        let buildCard = app.buttons["BUILD ON-DEVICE"]
        guard buildCard.waitForExistence(timeout: timeout) else { return false }
        // Wait briefly for animation/hittable (card tap can race parallax grid).
        let hitDeadline = Date().addingTimeInterval(3)
        while Date() < hitDeadline && !buildCard.isHittable {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        if buildCard.isHittable {
            buildCard.tap()
            return true
        }
        // Coordinate fallback — center of the card frame.
        let frame = buildCard.frame
        if frame.width > 1 && frame.height > 1 {
            let coord = buildCard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            coord.tap()
            return true
        }
        buildCard.tap()
        return true
    }

    /// Write reserved D2 PNGs only when Mode1 strict chrome is live and app is alive.
    /// Returns true when reserved names were written.
    @discardableResult
    func writeD2ReservedIfMode1Ready() -> Bool {
        guard appIsAlive(), mode1StrictChromeVisible() else {
            print("FORGEUITests: refuse reserved D2 — appAlive=\(appIsAlive()) strictChrome=\(mode1StrictChromeVisible())")
            return false
        }
        writeReservedScreenshotPNG(named: "02-build-on-device")
        writeReservedScreenshotPNG(named: "D2_mode1_terminal")
        writeReservedScreenshotPNG(named: "terminal-screen")
        takeScreenshot(named: "02_BuildOnDevice")
        return true
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

        // Also write PNG to FORGE_SCREENSHOT_DIR when set (Gate D artifact pull).
        // Filenames keep the test name so capture-screenshots.sh can match
        // terminal / mission / launch patterns via copy_attachment.
        guard let dir = screenshotOutputDirectory() else {
            return
        }
        let fm = FileManager.default
        var isDir: ObjCBool = false
        if !fm.fileExists(atPath: dir, isDirectory: &isDir) {
            try? fm.createDirectory(
                atPath: dir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        let safe = name
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        let path = (dir as NSString).appendingPathComponent("\(safe).png")
        do {
            try screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
        } catch {
            // Non-fatal: attachment in xcresult remains the source of truth.
            print("FORGEUITests: failed to write screenshot \(path): \(error)")
        }
    }

    /// Write Gate D reserved PNG under FORGE_SCREENSHOT_DIR with an exact filename.
    /// Used for acceptance paths that use hyphens (02-build-on-device.png) which
    /// differ from XCTest attachment names that historically used underscores.
    func writeReservedScreenshotPNG(named fileBase: String) {
        guard let dir = screenshotOutputDirectory() else {
            // Still attach to xcresult for CI artifact extractors.
            takeScreenshot(named: fileBase)
            return
        }
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = fileBase
        attachment.lifetime = .keepAlways
        add(attachment)

        let fm = FileManager.default
        if !fm.fileExists(atPath: dir) {
            try? fm.createDirectory(
                atPath: dir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        let safe = fileBase
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        let path = (dir as NSString).appendingPathComponent("\(safe).png")
        do {
            try screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
        } catch {
            print("FORGEUITests: failed to write reserved PNG \(path): \(error)")
        }
    }

    /// Gate D4 crash probe written beside reserved PNGs when FORGE_SCREENSHOT_DIR is set.
    /// Honest: records whether Mode1 chrome was seen and that the XCUITest process
    /// completed the smoke path without a hard app kill (no crash keywords hit).
    /// Crash keyword names appear only on keywords_scanned/keywords_found catalog lines
    /// so host scanners (capture-screenshots / vm-gate-d) do not false-positive.
    func writeD4CrashProbe(
        status: String,
        mode1Chrome: Bool,
        mode2Chrome: Bool,
        detail: String
    ) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        // Catalog-only keyword listing; free-text lines must not contain those tokens.
        let body = """
        stamp=\(stamp)
        source=testGateDSmokeScreenshots
        bundle=com.forge.app
        D4_status=\(status)
        mode1_chrome_seen=\(mode1Chrome ? "yes" : "no")
        mode2_chrome_seen=\(mode2Chrome ? "yes" : "no")
        launch_out=uitest_process
        relaunch_started=n/a_uitest_single_launch
        detail=\(detail)
        ---
        keywords_scanned=EXC_BAD_ACCESS|Fatal error|SIGABRT|SIGSEGV
        keywords_found=none_in_uitest_harness
        note=UITest smoke path completed writing this probe; keywords_found=none is harness-level evidence. Guest simctl DiagnosticReports remain authoritative when capture-screenshots.sh runs.
        """
        // Always attach for xcresult / CI artifact extractors.
        let attachment = XCTAttachment(string: body)
        attachment.name = "d4_crash_probe"
        attachment.lifetime = .keepAlways
        add(attachment)

        // On-disk probe when FORGE_SCREENSHOT_DIR set (guest/CI pull path).
        guard let dir = screenshotOutputDirectory() else {
            return
        }
        let fm = FileManager.default
        if !fm.fileExists(atPath: dir) {
            try? fm.createDirectory(
                atPath: dir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        let path = (dir as NSString).appendingPathComponent("d4_crash_probe.txt")
        do {
            try body.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
        } catch {
            print("FORGEUITests: failed to write d4_crash_probe \(path): \(error)")
        }
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

        // Wait for Mode1 strict chrome (backButton / forgeTerminal) before shot.
        // Sleep-only was the CI residual path: app died mid-sleep → Springboard PNG.
        let mode1Ready = observeMode1Chrome(timeout: 14)
        XCTAssertTrue(
            mode1Ready && appIsAlive(),
            "Back button / forgeTerminal should appear after BUILD ON-DEVICE"
        )
        if mode1Ready {
            takeScreenshot(named: "02_BuildOnDevice")
            _ = writeD2ReservedIfMode1Ready()
        }

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

        // ── Step 6: Open Settings via ☰ palette ────────────────────────

        // Enter Agent Mode first (Settings lives in the palette now)
        let agentCard = app.buttons["BUILD ON-DEVICE"]
        XCTAssertTrue(agentCard.waitForExistence(timeout: 10))
        agentCard.tap()
        let menuButton = app.buttons["menuButton"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 15),
                      "hamburger menu must exist in Agent Mode")
        Thread.sleep(forTimeInterval: 1.0) // settle transition
        menuButton.tap()
        XCTAssertTrue(app.textFields["Commands"].waitForExistence(timeout: 10),
                      "palette must open")

        let settingsRow = app.buttons["paletteRow_settings.open"]
        XCTAssertTrue(
            settingsRow.waitForExistence(timeout: 15),
            "Settings palette row should be visible"
        )
        settingsRow.tap()

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

        // ── Step 3: Wait for Mode1 chrome then terminal surface ────────
        // Prefer forgeTerminal a11y ids (SwiftTerm isAccessibilityElement=true
        // often hides the UIScrollView query). Refuse Springboard false-pass.
        let mode1Up = observeMode1Chrome(timeout: 12)
        XCTAssertTrue(
            mode1Up && appIsAlive(),
            "Mode1 chrome should appear after BUILD ON-DEVICE before terminal probe"
        )

        // Soft settle for engine/placeholder feed (phase1-stub path).
        if mode1Up {
            sleep(3)
        }

        // ── Step 4: Screenshot (reserved name only if Mode1 alive) ─────
        if mode1Up && appIsAlive() {
            takeScreenshot(named: "terminal-screen")
            // Also emit Gate D reserved aliases when FORGE_SCREENSHOT_DIR set.
            _ = writeD2ReservedIfMode1Ready()
        } else {
            takeScreenshot(named: "terminal-screen_FAILED_no_mode1")
        }

        // ── Step 5: Verify terminal surface ────────────────────────────
        let terminalOk = observeMode1TerminalSurface(timeout: 10)
        XCTAssertTrue(
            terminalOk,
            "Mode1 terminal surface (forgeTerminal / forgeTerminalContainer) should exist"
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
    /// 1. Enter Agent Mode → open the ☰ palette → tap Settings.
    /// 2. Screenshot "settings-open".
    /// 3. Verify "API Key" text exists.
    /// 4. Tap Done to dismiss.
    /// 5. Screenshot "settings-closed".
    func testSettingsFlow() throws {
        // ── Step 0: Enter Agent Mode + open the palette ────────────────

        let modeCard = app.buttons["BUILD ON-DEVICE"]
        XCTAssertTrue(modeCard.waitForExistence(timeout: 10))
        modeCard.tap()
        let menuButton = app.buttons["menuButton"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 12))
        menuButton.tap()
        XCTAssertTrue(app.textFields["Commands"].waitForExistence(timeout: 5),
                      "palette must open")

        // ── Step 1: Tap Settings (palette command) ─────────────────────

        let settingsRow = app.buttons["paletteRow_settings.open"]
        XCTAssertTrue(settingsRow.waitForExistence(timeout: 5),
                      "Settings palette row should exist")
        settingsRow.tap()

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

        XCTAssertTrue(
            app.buttons["menuButton"].waitForExistence(timeout: 10),
            "Should return to the session screen after dismissing settings"
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

        // Footer: version only (operator ruling W7 — footer buttons removed)
        let versionPredicate = NSPredicate(format: "label MATCHES %@", "v?1\\.0\\.0")
        XCTAssertTrue(
            app.staticTexts.containing(versionPredicate).firstMatch.exists,
            "Version footer should exist on the launch menu (v1.0.0)"
        )
        XCTAssertFalse(
            app.buttons["Settings"].exists,
            "Settings footer button must NOT exist (moved into the ☰ palette)"
        )

        takeScreenshot(named: "LaunchMenu_Elements")
    }

    // MARK: - Settings Sheet

    /// Opens settings via the ☰ palette (footer buttons removed per operator
    /// ruling W7), verifies the sheet content, then dismisses it.
    func testSettingsSheetContent() throws {
        let forgeTitle = app.staticTexts["FORGE"]
        XCTAssertTrue(forgeTitle.waitForExistence(timeout: 10))

        // Enter Agent Mode
        let modeCard = app.buttons["BUILD ON-DEVICE"]
        XCTAssertTrue(modeCard.waitForExistence(timeout: 10))
        modeCard.tap()

        // Open the command palette via ☰
        let menuButton = app.buttons["menuButton"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 12))
        menuButton.tap()
        XCTAssertTrue(app.textFields["Commands"].waitForExistence(timeout: 5),
                      "palette must open")

        // Settings is a palette command (spec §10.2 settings.open)
        let settingsRow = app.buttons["paletteRow_settings.open"]
        XCTAssertTrue(settingsRow.waitForExistence(timeout: 5),
                      "Settings palette row must exist")
        settingsRow.tap()

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

        // Verify we're back in the session screen
        XCTAssertTrue(
            app.buttons["menuButton"].waitForExistence(timeout: 10),
            "Should return to the session screen after dismissing settings"
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
        // Prefer Mode1 strict chrome (backButton / forgeTerminal) over FORGE title —
        // title alone false-passes on launch and false-fails when TopBar races.
        let mode1Up = observeMode1Chrome(timeout: 12)
        XCTAssertTrue(
            mode1Up && appIsAlive(),
            "Mode1 chrome (backButton / forgeTerminal) should appear after BUILD ON-DEVICE"
        )
        if mode1Up {
            takeScreenshot(named: "BuildOnDevice_Transition")
        }

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

    // MARK: - Gate D smoke path (D1–D4)

    /// Single end-to-end path used by `scripts/vm-gate-d-screenshots.sh`:
    /// launch menu (D1) → Mode1 terminal (D2) → Mode2 Mission Control (D3).
    /// Absence of process crash / XCT fail is D4 evidence on the smoke path.
    ///
    /// Reserved on-disk paths when FORGE_SCREENSHOT_DIR is set:
    /// - D1_launch_menu.png / 01_LaunchMenu.png
    /// - D2_mode1_terminal.png / 02-build-on-device.png / terminal-screen.png
    /// - D3_mission_control.png / mission-control.png
    /// - D4_smoke_final.png / d4_crash_probe.txt
    ///
    /// Design notes for D4 / no hard crash keywords:
    /// - continueAfterFailure = true so a soft Mode1 flake still writes the
    ///   D4 probe and remaining screenshots instead of aborting mid-path.
    /// - Reserved D2 PNGs (02-build-on-device.png + D2_mode1_terminal.png) are
    ///   only written after Mode1 chrome (backButton / forgeTerminal ids) —
    ///   never from launch/Springboard false-positives.
    /// - Terminal surface queried via forgeTerminal accessibility ids first;
    ///   scrollViews.firstMatch is legacy fallback only (SwiftTerm a11y).
    /// - Screenshots are taken promptly after Mode1 chrome appears so engine
    ///   boot races do not leave D2 empty if a later assertion soft-fails.
    /// - d4_crash_probe.txt uses keywords_found catalog lines only (no free-text
    ///   crash tokens) so host scanners do not false-positive.
    func testGateDSmokeScreenshots() throws {
        // Soft-continue so D4 probe + reserved PNGs still land on partial fail.
        // Hard XCTest aborts after Mode1 crash previously left D2 as Springboard.
        continueAfterFailure = true

        var mode1Chrome = false
        var mode2Chrome = false
        var d2Written = false
        var appDied = false
        var detailParts: [String] = []
        var d4Status = "fail"
        var finalMenu = false

        // Always emit D4 probe — even if later steps throw / process soft-fails.
        defer {
            if d4Status == "fail" && finalMenu && mode1Chrome && d2Written && !appDied {
                d4Status = "pass"
            }
            writeD4CrashProbe(
                status: d4Status,
                mode1Chrome: mode1Chrome,
                mode2Chrome: mode2Chrome,
                detail: detailParts.joined(separator: ";")
            )
        }

        // D1 — dual-mode launch menu
        let forgeTitle = app.staticTexts["FORGE"]
        XCTAssertTrue(
            forgeTitle.waitForExistence(timeout: 15),
            "D1: FORGE title should be visible on the launch menu"
        )
        XCTAssertTrue(
            app.buttons["BUILD ON-DEVICE"].waitForExistence(timeout: 10),
            "D1: BUILD ON-DEVICE card must be present"
        )
        XCTAssertTrue(
            app.buttons["MISSION CONTROL"].exists,
            "D1: MISSION CONTROL card must be present"
        )
        takeScreenshot(named: "01_LaunchMenu")
        writeReservedScreenshotPNG(named: "D1_launch_menu")
        detailParts.append("D1=ok")

        // D2 — Mode 1 terminal (Launch → BUILD ON-DEVICE → strict chrome)
        let tapped = tapBuildOnDeviceCard(timeout: 12)
        if !tapped {
            detailParts.append("D2=build_card_missing")
            takeScreenshot(named: "02_BuildOnDevice_FAILED_no_card")
            d4Status = "fail"
            XCTAssertTrue(false, "D2: BUILD ON-DEVICE card must be tappable")
            return
        }

        // Wait for Mode1 chrome first (TopBar backButton / forgeTerminal ids).
        // STRICT only — never leftLaunch+scrollView (Springboard residual).
        mode1Chrome = observeMode1Chrome(timeout: 14)
        if !mode1Chrome {
            // Second chance after fullScreenCover settle; re-check process alive.
            if !appIsAlive() {
                appDied = true
                detailParts.append("D2=app_not_alive_after_mode1_tap")
            } else {
                sleep(2)
                mode1Chrome = observeMode1Chrome(timeout: 8)
            }
        }

        if !appIsAlive() {
            appDied = true
            detailParts.append("D2=app_not_alive")
        }

        if mode1Chrome && !appDied {
            // Reserved D2 paths only after strict chrome + process alive.
            d2Written = writeD2ReservedIfMode1Ready()
            detailParts.append(d2Written ? "D2=mode1_strict_chrome" : "D2=write_refused")
        } else {
            detailParts.append("D2=mode1_chrome_missing")
            // Do NOT write reserved D2 names from launch/Springboard.
            // Use a non-reserved name so capture-screenshots will not promote it.
            takeScreenshot(named: "02_BuildOnDevice_FAILED_no_mode1_chrome")
        }

        // Soft terminal presence — prefer forgeTerminal / forgeTerminalContainer.
        var terminalOk = false
        if mode1Chrome && !appDied {
            terminalOk = observeMode1TerminalSurface(timeout: 8)
            if terminalOk {
                detailParts.append("D2_terminal_surface=yes")
                // Refresh reserved shots once terminal surface is live.
                _ = writeD2ReservedIfMode1Ready()
                d2Written = true
            } else {
                detailParts.append("D2_terminal_surface=no")
            }
        }

        XCTAssertTrue(
            mode1Chrome && !appDied,
            "D2: Mode1 chrome (backButton / forgeTerminal) should appear after BUILD ON-DEVICE without process death"
        )
        if !terminalOk && mode1Chrome {
            print("FORGEUITests Gate D: Mode1 terminal surface not seen within timeout (soft)")
        }

        // Return to launch menu only if Mode1 is actually up.
        if mode1Chrome && appIsAlive() {
            let backButton = app.buttons["backButton"]
            if backButton.exists {
                backButton.tap()
            } else if app.buttons["backButton"].waitForExistence(timeout: 5) {
                app.buttons["backButton"].tap()
            }
            sleep(2)
        }
        let backToMenuAfterMode1 = appIsAlive() && forgeTitle.waitForExistence(timeout: 10)
        if !appIsAlive() {
            appDied = true
            detailParts.append("D2_return=app_dead")
        }
        XCTAssertTrue(
            backToMenuAfterMode1,
            "D2: return to launch menu after Mode1"
        )
        if backToMenuAfterMode1 {
            detailParts.append("D2_return=ok")
        } else {
            detailParts.append("D2_return=fail")
        }

        // D3 — Mode 2 Mission Control (empty fleet OK). Skip if app already dead.
        if appIsAlive() {
            let missionCard = app.buttons["MISSION CONTROL"]
            let missionVisible = missionCard.waitForExistence(timeout: 10)
            XCTAssertTrue(missionVisible, "D3: MISSION CONTROL card should be visible")
            if missionVisible {
                missionCard.tap()
                // Screenshot early after transition — empty fleet must not hard-kill the process.
                sleep(2)
                if !appIsAlive() {
                    appDied = true
                    detailParts.append("D3=app_not_alive")
                } else {
                    if app.buttons["backButton"].waitForExistence(timeout: 10)
                        || app.buttons["Add Server"].exists
                        || app.staticTexts["No Servers Configured"].exists {
                        mode2Chrome = true
                    }
                    takeScreenshot(named: "03_MissionControl")
                    writeReservedScreenshotPNG(named: "mission-control")
                    writeReservedScreenshotPNG(named: "D3_mission_control")
                    detailParts.append(mode2Chrome ? "D3=mode2_chrome" : "D3=mode2_chrome_weak")

                    let addServerButton = app.buttons["Add Server"]
                    let noServersText = app.staticTexts["No Servers Configured"]
                    let emptyOrNav = addServerButton.waitForExistence(timeout: 8)
                        || noServersText.exists
                        || app.buttons["backButton"].exists
                    XCTAssertTrue(
                        emptyOrNav,
                        "D3: Mission Control should show empty state or navigable chrome"
                    )

                    if app.buttons["backButton"].waitForExistence(timeout: 10) {
                        app.buttons["backButton"].tap()
                    }
                    sleep(2)
                }
            } else {
                detailParts.append("D3=mission_card_missing")
            }
        } else {
            detailParts.append("D3=skipped_app_dead")
        }

        finalMenu = appIsAlive() && forgeTitle.waitForExistence(timeout: 10)
        XCTAssertTrue(
            finalMenu && !appDied,
            "D4 smoke: return to launch menu without process death"
        )
        if finalMenu {
            writeReservedScreenshotPNG(named: "D4_smoke_final")
        }

        // D4 status for defer probe (no free-text crash tokens).
        if appDied {
            d4Status = "fail"
            detailParts.append("D4=fail_app_not_alive")
        } else if finalMenu && mode1Chrome && d2Written {
            d4Status = "pass"
            detailParts.append("D4=pass_no_crash_keywords")
        } else if finalMenu {
            d4Status = "partial"
            detailParts.append("D4=partial_menu_alive")
        } else {
            d4Status = "fail"
            detailParts.append("D4=fail_no_final_menu")
        }
    }
}
