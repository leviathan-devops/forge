import XCTest

/// FORGE Interactive Demo — two short robust segments recorded as one
/// continuous video (Agent Mode walkthrough, then Mission Control).
///
/// Segment 1 (testDemoAgentMode):
///   launch menu → Agent Mode chrome → agent build (tokens climb, wait until
///   idle) → ☰ palette → model dialog → agent dialog → new session → back
/// Segment 2 (testDemoMissionControl):
///   launch menu → Mission Control → connect + stream → ☰ palette →
///   View Active Sessions → carousel → spawn card → session cards
///
/// Launch env: DEMO_API_KEY + DEMO_TEST_PROMPT + DEMO_TEST_SERVER.
/// MC demo server must run at 127.0.0.1:8090 on the sim host.
final class DemoWalkthroughUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        // Config file: the launcher script writes /tmp/demo-env.json
        // ({"api_key":..., "prompt":..., "server":...}). The shell→xcodebuild→
        // runner env chain does NOT survive nohup/backgrounded runs, so the
        // demo reads a file instead (test runner runs as the VM user, /tmp is
        // readable).
        if let data = try? Data(contentsOf: URL(fileURLWithPath: "/tmp/demo-env.json")),
           let cfg = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            if let key = cfg["api_key"], !key.isEmpty {
                app.launchEnvironment["FORGE_API_KEY"] = key
            }
            if let prompt = cfg["prompt"], !prompt.isEmpty {
                app.launchEnvironment["FORGE_TEST_PROMPT"] = prompt
            }
            if let server = cfg["server"], !server.isEmpty {
                app.launchEnvironment["FORGE_TEST_SERVER"] = server
            }
            print("DEMO-CONFIG: loaded from /tmp/demo-env.json")
        } else {
            print("DEMO-CONFIG: /tmp/demo-env.json missing")
        }
        app.launchArguments = ["-FORGE_START_MODE", "none"]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Segment 1: Agent Mode

    func testDemoAgentMode() throws {
        // ═══ 1. LAUNCH MENU ═══
        XCTAssertTrue(app.buttons["BUILD ON-DEVICE"].waitForExistence(timeout: 12),
                      "AGENT MODE card")
        XCTAssertTrue(app.buttons["MISSION CONTROL"].exists, "MISSION CONTROL card")
        XCTAssertTrue(app.staticTexts["FORGE"].exists, "FORGE title")
        let versionPredicate = NSPredicate(format: "label MATCHES %@", "v?1\\.0\\.0")
        XCTAssertTrue(app.staticTexts.containing(versionPredicate).firstMatch.exists,
                      "version footer")
        capture("01-launch-menu")

        // ═══ 2. AGENT MODE chrome ═══
        app.buttons["BUILD ON-DEVICE"].tap()
        XCTAssertTrue(app.buttons["backButton"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.buttons["menuButton"].exists, "hamburger")
        XCTAssertTrue(app.otherElements["bottomStatusBar"].waitForExistence(timeout: 15) ||
                      app.staticTexts.containing(
                        NSPredicate(format: "label CONTAINS 'trident'")).firstMatch.exists,
                      "status bars")
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'FORGE-Demo'")).firstMatch.exists,
            "session header")
        capture("02-agent-mode")

        // ═══ 3. AGENT BUILD (auto-sent) ═══
        print("DEMO: agent building...")
        let tokenPredicate = NSPredicate(format: "label MATCHES %@", "[1-9]\\d*(\\.?[\\d.]+)?[KM]? \\(\\d+%\\)")
        let deadline = Date().addingTimeInterval(90)
        while Date() < deadline {
            if app.staticTexts.matching(tokenPredicate).firstMatch.exists { break }
            RunLoop.current.run(until: Date().addingTimeInterval(2))
        }
        // Wait until the status-bar token label stops changing = agent idle.
        var lastLabel = ""
        var stableCount = 0
        let idleDeadline = Date().addingTimeInterval(180)
        while Date() < idleDeadline && stableCount < 4 {
            let label = app.staticTexts.matching(tokenPredicate).firstMatch.label
            if label == lastLabel { stableCount += 1 } else { stableCount = 0 }
            lastLabel = label
            RunLoop.current.run(until: Date().addingTimeInterval(5))
        }
        capture("03-agent-build")

        // ═══ 4. PALETTE + DIALOGS (agent idle) ═══
        app.buttons["menuButton"].tap()
        XCTAssertTrue(app.textFields["Commands"].waitForExistence(timeout: 8),
                      "palette opens")
        XCTAssertTrue(app.buttons["paletteRow_suggested:model.list"].exists,
                      "Suggested group shows model.list")
        capture("04-palette-suggested")

        app.buttons["paletteRow_model.list"].tap()
        XCTAssertTrue(app.staticTexts["Switch model"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["deepseek-v4-flash"].exists, "deepseek listed")
        capture("05-model-dialog")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertFalse(app.staticTexts["Switch model"].exists)
        Thread.sleep(forTimeInterval: 1)

        app.buttons["menuButton"].tap()
        XCTAssertTrue(app.textFields["Commands"].waitForExistence(timeout: 8))
        app.buttons["paletteRow_agent.list"].tap()
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'trident'")).firstMatch.waitForExistence(timeout: 5))
        capture("06-agent-dialog")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 1)

        app.buttons["menuButton"].tap()
        XCTAssertTrue(app.textFields["Commands"].waitForExistence(timeout: 8))
        app.buttons["paletteRow_session.new"].tap()
        XCTAssertTrue(app.buttons["backButton"].waitForExistence(timeout: 8))
        capture("07-new-session")

        // ═══ 5. BACK TO LAUNCH ═══
        app.buttons["backButton"].tap()
        XCTAssertTrue(app.buttons["MISSION CONTROL"].waitForExistence(timeout: 10))
        capture("08-return-launch")
    }

    // MARK: - Segment 2: Mission Control

    func testDemoMissionControl() throws {
        // ═══ 6. MISSION CONTROL connect + stream ═══
        XCTAssertTrue(app.buttons["MISSION CONTROL"].waitForExistence(timeout: 12))
        app.buttons["MISSION CONTROL"].tap()
        XCTAssertTrue(app.buttons["menuButton"].waitForExistence(timeout: 12))
        Thread.sleep(forTimeInterval: 4) // let the stream populate
        XCTAssertTrue(app.otherElements["bottomStatusBar"].exists ||
                      app.staticTexts.containing(
                        NSPredicate(format: "label CONTAINS 'swipe'")).firstMatch.exists,
                      "MC status bars")
        capture("09-mission-control")

        // ═══ 7. PALETTE → VIEW ACTIVE SESSIONS → CAROUSEL ═══
        app.buttons["menuButton"].tap()
        XCTAssertTrue(app.textFields["Commands"].waitForExistence(timeout: 8))
        capture("10-mc-palette")
        let viewSessions = app.buttons["paletteRow_session.view_active"]
        XCTAssertTrue(viewSessions.exists, "View Active Sessions entry")
        viewSessions.tap()
        XCTAssertTrue(app.staticTexts["ACTIVE SESSIONS"].waitForExistence(timeout: 8),
                      "carousel opens")
        capture("11-carousel")

        // ═══ 8. SPAWN ═══
        let spawnCard = app.buttons["spawnCard"]
        XCTAssertTrue(spawnCard.exists, "spawn card in carousel")
        spawnCard.tap()
        capture("12a-after-spawn-tap")
        // DESIGN: a successful spawn POSTs /session (201), refreshes the
        // session list, then CLOSES the carousel and joins the new session
        // (MissionControlScreen.spawnNewSession line ~579).
        let carouselGone = Date().addingTimeInterval(10)
        var carouselClosed = false
        while Date() < carouselGone {
            if !app.staticTexts["ACTIVE SESSIONS"].exists { carouselClosed = true; break }
            RunLoop.current.run(until: Date().addingTimeInterval(1))
        }
        capture("12-spawned")
        XCTAssertTrue(carouselClosed, "carousel closes after successful spawn")
        // Landed back on the session screen (new session joined)
        XCTAssertTrue(app.buttons["backButton"].waitForExistence(timeout: 8),
                      "back in session screen after spawn")

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 1)
        capture("13-final")
    }

    private func capture(_ name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
