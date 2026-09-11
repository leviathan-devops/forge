import XCTest

/// FORGE Overhaul UI Tests — spec §28.4 (palette, dialogs, status bars, MC features)
///
/// Covers the W3-W6 UI surfaces:
/// - Command palette open/close/filter (☰ hamburger → verbatim Ctrl+P port)
/// - New Session → home prompt (verbatim opencode behavior)
/// - Two-tier bottom status bars + session header row
/// - Mission Control palette commands (View Active Sessions)
/// - Dialog surfaces (model/agent/session list)
///
/// Accessibility identifiers used (spec §25):
/// - mode cards: "BUILD ON-DEVICE" / "MISSION CONTROL" (ForgeMode.rawValue)
/// - hamburger: "menuButton" · back: "backButton"
/// - palette: "paletteClose" · rows: "paletteRow_{value}"
/// - status bar: "bottomStatusBar" · dialogs: "dialogClose"
final class FORGEOverhaulUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        // HERMETIC: override any persisted FORGE_START_MODE default (a previous
        // e2e run wrote missionControl into UserDefaults, which made the app
        // launch into Mission Control and poisoned every UI test). Passing
        // -FORGE_START_MODE none makes applyAgentLaunchOverrides fall through
        // to the default launch menu.
        app.launchArguments = ["-FORGE_START_MODE", "none"]
        app.launch()
        // Settle the launch transition before any interaction.
        XCTAssertTrue(app.buttons["BUILD ON-DEVICE"].waitForExistence(timeout: 12),
                      "app must launch to the launch menu (AGENT MODE card)")
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Launch menu

    func testLaunchMenuShowsBothModesAndFooter() {
        captureScreen("launch-menu")
        XCTAssertTrue(app.buttons["BUILD ON-DEVICE"].waitForExistence(timeout: 10),
                      "AGENT MODE card must exist")
        XCTAssertTrue(app.buttons["MISSION CONTROL"].exists,
                      "MISSION CONTROL card must exist")
        // Footer: version only (v1.0.0 from CFBundleShortVersionString).
        // Use a regex predicate so it matches regardless of exact label shape.
        let versionPredicate = NSPredicate(format: "label MATCHES %@", "v?1\\.0\\.0")
        let footer = app.staticTexts.containing(versionPredicate).firstMatch
        XCTAssertTrue(footer.exists, "footer must show version only (v1.0.0)")
    }

    // MARK: - Agent Mode palette

    func testAgentModeOpensPaletteViaHamburger() {
        XCTAssertTrue(app.buttons["BUILD ON-DEVICE"].waitForExistence(timeout: 10))
        app.buttons["BUILD ON-DEVICE"].tap()
        XCTAssertTrue(app.buttons["backButton"].waitForExistence(timeout: 12),
                      "Agent Mode must show back button")
        Thread.sleep(forTimeInterval: 1.0) // settle transition
        XCTAssertTrue(app.buttons["menuButton"].exists,
                      "hamburger menu must exist in Agent Mode")
        app.buttons["menuButton"].tap()
        // Palette opens with search field (placeholder "Commands")
        XCTAssertTrue(app.textFields["Commands"].waitForExistence(timeout: 5),
                      "palette search field must appear")
        XCTAssertTrue(app.buttons["paletteClose"].exists,
                      "palette close button must exist")
    }

    func testPaletteClosesOnBackdropTap() {
        XCTAssertTrue(app.buttons["BUILD ON-DEVICE"].waitForExistence(timeout: 10))
        app.buttons["BUILD ON-DEVICE"].tap()
        XCTAssertTrue(app.buttons["menuButton"].waitForExistence(timeout: 12))
        app.buttons["menuButton"].tap()
        XCTAssertTrue(app.textFields["Commands"].waitForExistence(timeout: 5))
        // Tap the dimmed backdrop (top-left corner = outside the palette card)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertFalse(app.textFields["Commands"].exists,
                       "palette must dismiss on backdrop tap")
    }

    func testNewSessionShowsHomePrompt() {
        XCTAssertTrue(app.buttons["BUILD ON-DEVICE"].waitForExistence(timeout: 10))
        app.buttons["BUILD ON-DEVICE"].tap()
        XCTAssertTrue(app.buttons["menuButton"].waitForExistence(timeout: 12))
        app.buttons["menuButton"].tap()
        XCTAssertTrue(app.textFields["Commands"].waitForExistence(timeout: 5))
        // New session row (paletteRow_session.new)
        let newSessionRow = app.buttons["paletteRow_session.new"]
        XCTAssertTrue(newSessionRow.exists, "New session palette row must exist")
        newSessionRow.tap()
        // Home prompt: terminal input focused (terminal surface present)
        XCTAssertTrue(app.buttons["backButton"].waitForExistence(timeout: 8),
                      "must remain in session screen after New Session")
    }

    func testPaletteShowsNewSessionWhenEmpty() {
        XCTAssertTrue(app.buttons["BUILD ON-DEVICE"].waitForExistence(timeout: 10))
        app.buttons["BUILD ON-DEVICE"].tap()
        XCTAssertTrue(app.buttons["menuButton"].waitForExistence(timeout: 12))
        app.buttons["menuButton"].tap()
        XCTAssertTrue(app.textFields["Commands"].waitForExistence(timeout: 5))
        // session.new is ALWAYS present (app-level command)
        XCTAssertTrue(app.buttons["paletteRow_session.new"].exists)
    }

    // MARK: - Status bars

    func testStatusBarsVisibleInAgentMode() {
        XCTAssertTrue(app.buttons["BUILD ON-DEVICE"].waitForExistence(timeout: 10))
        app.buttons["BUILD ON-DEVICE"].tap()
        // Bottom status bar (two-tier) must exist
        XCTAssertTrue(app.otherElements["bottomStatusBar"].waitForExistence(timeout: 12),
                      "bottom status bar must exist in Agent Mode")
        // Status row 1 text: agent · model · provider
        XCTAssertTrue(app.staticTexts["trident · deepseek-v4-flash · OpenCode Zen"].exists ||
                      app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'trident'")).firstMatch.exists,
                      "status row 1 must show agent/model/provider")
        captureScreen("mode1-status-header")
        // Session header row above terminal
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'FORGE-Demo'")).firstMatch.waitForExistence(timeout: 8),
                      "session header row must show ~ FORGE-Demo · model")
    }

    // MARK: - Mission Control palette

    func testMissionControlOpensPaletteWithViewSessions() {
        XCTAssertTrue(app.buttons["MISSION CONTROL"].waitForExistence(timeout: 10))
        app.buttons["MISSION CONTROL"].tap()
        XCTAssertTrue(app.buttons["menuButton"].waitForExistence(timeout: 12),
                      "MC must have hamburger menu")
        app.buttons["menuButton"].tap()
        captureScreen("mc-palette-after-tap")
        XCTAssertTrue(app.textFields["Commands"].waitForExistence(timeout: 5))
        // MC-only command: View Active Sessions
        XCTAssertTrue(app.buttons["paletteRow_session.view_active"].exists,
                      "MC palette must include View Active Sessions")
    }

    func testMissionControlHasStatusBars() {
        XCTAssertTrue(app.buttons["MISSION CONTROL"].waitForExistence(timeout: 10))
        app.buttons["MISSION CONTROL"].tap()
        XCTAssertTrue(app.otherElements["bottomStatusBar"].waitForExistence(timeout: 12),
                      "MC must have bottom status bar")
        // swipe hint on row 2
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'swipe'")).firstMatch.exists,
                      "MC status bar must show swipe hint")
    }

    // MARK: - Dialog surfaces

    func testModelDialogOpensFromPalette() {
        XCTAssertTrue(app.buttons["BUILD ON-DEVICE"].waitForExistence(timeout: 10))
        app.buttons["BUILD ON-DEVICE"].tap()
        XCTAssertTrue(app.buttons["menuButton"].waitForExistence(timeout: 12))
        app.buttons["menuButton"].tap()
        XCTAssertTrue(app.textFields["Commands"].waitForExistence(timeout: 5))
        let row = app.buttons["paletteRow_model.list"]
        XCTAssertTrue(row.exists, "model.list palette row must exist")
        row.tap()
        // Model dialog shows deepseek first (favorite/recommended)
        XCTAssertTrue(app.staticTexts["Switch model"].waitForExistence(timeout: 5),
                      "Switch model dialog must open")
    }

    func testAgentDialogOpensFromPalette() {
        XCTAssertTrue(app.buttons["BUILD ON-DEVICE"].waitForExistence(timeout: 10))
        app.buttons["BUILD ON-DEVICE"].tap()
        XCTAssertTrue(app.buttons["menuButton"].waitForExistence(timeout: 12))
        app.buttons["menuButton"].tap()
        XCTAssertTrue(app.textFields["Commands"].waitForExistence(timeout: 5))
        let row = app.buttons["paletteRow_agent.list"]
        XCTAssertTrue(row.exists, "agent.list palette row must exist")
        row.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'trident'")).firstMatch.waitForExistence(timeout: 5),
                      "Agent dialog must show trident")
    }

    // MARK: - Adversarial

    func testPaletteSurvivesRepeatedOpenClose() {
        XCTAssertTrue(app.buttons["BUILD ON-DEVICE"].waitForExistence(timeout: 10))
        app.buttons["BUILD ON-DEVICE"].tap()
        XCTAssertTrue(app.buttons["menuButton"].waitForExistence(timeout: 12))
        for cycle in 0..<5 {
            app.buttons["menuButton"].tap()
            if cycle == 3 { captureScreen("palette-cycle-3") }
            XCTAssertTrue(app.textFields["Commands"].waitForExistence(timeout: 3))
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            XCTAssertFalse(app.textFields["Commands"].exists, "palette must close each time")
        }
        // App still alive after 5 open/close cycles
        XCTAssertEqual(app.state, .runningForeground, "app must survive repeated palette toggles")
    }

    /// Captures the current screen into a keep-always attachment (debugging).
    func captureScreen(_ name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

}