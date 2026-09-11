import XCTest

/// W5 soak: extended session stability (SC-12) on the deterministic fixture.
///
/// Launch (E2E) → card renders → background 60s → foreground → tabs →
/// terminate → relaunch → card renders again. No crash, no hang, no stale
/// state across the cycle. No LLM, no key. Watcher adjudicates pixels.
final class SoakUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-FORGE_START_MODE", "none"]
        app.launchEnvironment["FORGE_TEST_MODE1_E2E"] = "1"
        app.launch()
        Thread.sleep(forTimeInterval: 25)
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    private func waitFor(_ element: XCUIElement, timeout: TimeInterval = 10,
                          file: StaticString = #filePath, line: UInt = #line) {
        let ok = element.waitForExistence(timeout: timeout)
        if !ok {
            print("=== UI TREE DUMP (failure context) ===")
            print(app.debugDescription)
            print("=== END DUMP ===")
        }
        XCTAssertTrue(ok, "element not found: \(element)", file: file, line: line)
    }

    private func expectBubble(containing token: String, timeout: TimeInterval = 20,
                               file: StaticString = #filePath, line: UInt = #line) {
        let bubble = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", token)
        ).firstMatch
        waitFor(bubble, timeout: timeout, file: file, line: line)
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let url = URL(fileURLWithPath: "/tmp/soak-proof/" + name + ".png")
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: url)
    }

    private func enterMode1(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 60), "app never foregrounded", file: file, line: line)
        var entered = false
        for _ in 1...5 {
            if app.textFields["Message"].firstMatch.waitForExistence(timeout: 15) {
                entered = true
                break
            }
            // t102: state restoration can land directly in Mode 1 with the
            // fixture auto-switched to PREVIEW (composer hidden). The E2E
            // card proves Mode 1 just as well as the composer does.
            if app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "FORGE PREVIEW")).firstMatch.waitForExistence(timeout: 10) {
                entered = true
                break
            }
            app.activate()
            Thread.sleep(forTimeInterval: 3)
            let card = app.buttons["BUILD ON-DEVICE"].firstMatch
            if card.waitForExistence(timeout: 20) {
                card.tap()
            }
        }
        if !entered {
            print("=== UI TREE DUMP (re-entry failure context) ===")
            print(app.debugDescription)
            print("=== END DUMP ===")
        }
        XCTAssertTrue(entered, "never entered Mode 1 after 5 entry attempts", file: file, line: line)
    }

    private func tapStable(buttonLabel: String, attempts: Int = 6,
                            file: StaticString = #filePath, line: UInt = #line) {
        for i in 1...attempts {
            let b = app.buttons[buttonLabel].firstMatch
            if b.waitForExistence(timeout: 12) {
                b.tap()
                Thread.sleep(forTimeInterval: 8)
                return
            }
            if i < attempts { Thread.sleep(forTimeInterval: 10) }
        }
        let b = app.buttons[buttonLabel].firstMatch
        waitFor(b, timeout: 20, file: file, line: line)
        b.tap()
        Thread.sleep(forTimeInterval: 8)
    }

    func testSoakFlow() {
        enterMode1()
        // First render (fixture).
        expectBubble(containing: "FORGE PREVIEW", timeout: 420)
        expectBubble(containing: "ANSWER 42", timeout: 60)
        snap("s0-first-render")

        // Background 60s, then foreground — state must survive.
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 60)
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30), "app never foregrounded after background")
        expectBubble(containing: "FORGE PREVIEW", timeout: 60)
        snap("s1-after-background")

        // Tab cycle under the same session.
        tapStable(buttonLabel: "TERMINAL")
        snap("s2-terminal")
        tapStable(buttonLabel: "SPLIT")
        snap("s3-split")
        tapStable(buttonLabel: "PREVIEW")
        // t100 s4 went black: after a tab switch the pane reloads — poll for
        // the card instead of snapshotting a fixed sleep (latency, not loss).
        expectBubble(containing: "FORGE PREVIEW", timeout: 90)
        snap("s4-preview")

        // Full terminate + relaunch — fixture re-runs in the new process.
        app.terminate()
        Thread.sleep(forTimeInterval: 10)
        app.launch()
        enterMode1()
        expectBubble(containing: "FORGE PREVIEW", timeout: 420)
        expectBubble(containing: "ANSWER 42", timeout: 60)
        snap("s5-after-relaunch")
    }
}
