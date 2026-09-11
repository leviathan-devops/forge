import XCTest

/// T-9 functional battery: live agent codes, runs, and previews on one tape.
///
/// Prologue repeats the proven /connect flow (status → provider/model/url →
/// secure key → test), then one battery prompt drives the agent end to end:
/// write hello.py + run python (ANSWER 42 / DONE) + write index.html +
/// TERMINAL/SPLIT/PREVIEW switching with the paid-model footer on screen.
/// Key travels guest-file only (/tmp/connect-proof-env.json {"api_key": ...}).
final class BatteryUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-FORGE_START_MODE", "none"]
        app.launch()
        let launchSurface = app.launchArguments.joined(separator: " ")
            + app.launchEnvironment.values.joined(separator: " ")
        XCTAssertFalse(launchSurface.contains("FORGE_API_"),
            "launch-env override present")
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

    private func enterMode1() {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30), "app never foregrounded")
        var entered = false
        for _ in 1...3 {
            if app.textFields["Message"].firstMatch.waitForExistence(timeout: 10) {
                entered = true
                break
            }
            app.activate()
            let card = app.buttons["BUILD ON-DEVICE"].firstMatch
            if card.waitForExistence(timeout: 15) {
                card.tap()
            }
        }
        XCTAssertTrue(entered, "never entered Mode 1 after 3 entry attempts")
        waitFor(app.textFields["Message"].firstMatch, timeout: 10)
    }

    private func sendLine(_ text: String) {
        let composer = app.textFields["Message"].firstMatch
        waitFor(composer, timeout: 20)
        composer.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 30),
            "software keyboard never appeared for composer")
        composer.typeText(text)
        let send = app.buttons["sendButton"].firstMatch
        waitFor(send, timeout: 10)
        send.tap()
    }

    private func expectBubble(containing token: String, timeout: TimeInterval = 20,
                               file: StaticString = #filePath, line: UInt = #line) {
        let bubble = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", token)
        ).firstMatch
        waitFor(bubble, timeout: timeout, file: file, line: line)
    }

    /// Post-turn queries: the AX tree is huge after an agent turn and full-tree
    /// snapshots can time out under guest load (t84-85). Retry with settles
    /// instead of failing the take on a sick snapshot.
    private func expectBubbleStable(containing token: String, attempts: Int = 4,
                                     file: StaticString = #filePath, line: UInt = #line) {
        for i in 1...attempts {
            let bubble = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", token)
            ).firstMatch
            if bubble.waitForExistence(timeout: 15) { return }
            if i == attempts {
                waitFor(bubble, timeout: 15, file: file, line: line)
                return
            }
            Thread.sleep(forTimeInterval: 10)
        }
    }

    /// Taps survive sick snapshots: short waits + settles, hard fail with a
    /// dump only after the attempts are exhausted (t84-87: full-tree snapshot
    /// timeouts under guest load kill single-shot waits).
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

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let url = URL(fileURLWithPath: "/tmp/battery-proof/" + name + ".png")
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: url)
    }

    private func proofKey() -> String {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: "/tmp/connect-proof-env.json")),
              let cfg = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let key = cfg["api_key"], !key.isEmpty else {
            XCTFail("missing /tmp/connect-proof-env.json api_key — harness must provision it")
            return ""
        }
        return key
    }

    func testBatteryFlow() {
        let key = proofKey()
        enterMode1()

        // Prologue: connect (proven path, short allowances).
        sendLine("/connect provider openai")
        expectBubble(containing: "Saved provider", timeout: 20)
        sendLine("/connect model muse-spark-1.3-contributor")
        expectBubble(containing: "Saved model", timeout: 20)
        sendLine("/connect url https://opencode.ai/zen/go/v1")
        expectBubble(containing: "Saved url", timeout: 20)
        sendLine("/connect key")
        let secure = app.secureTextFields.firstMatch
        waitFor(secure, timeout: 15)
        secure.tap()
        secure.typeText(key)
        Thread.sleep(forTimeInterval: 45)
        // t110: the Save tap query timed out on a sick tree (secure alert +
        // Passwords bar) with the overlay left open — retry like everything.
        var saved = false
        for i in 1...5 {
            let save = app.alerts.firstMatch.buttons["Save"].firstMatch
            if save.waitForExistence(timeout: 12) {
                save.tap()
                saved = true
                break
            }
            if i < 5 { Thread.sleep(forTimeInterval: 10) }
        }
        XCTAssertTrue(saved, "Save button never appeared")
        expectBubble(containing: "saved to Keychain", timeout: 90)
        sendLine("/connect test")
        expectBubble(containing: "PASS: connected", timeout: 150)

        // Battery prompt: one ask, agent writes + runs + previews.
        // HONESTY NOTE (t90): tokens like hello.py / ANSWER 42 / DONE also
        // appear in the echoed request, so bubble matches are FLOW gates only
        // (did the turn advance?) — output truth comes from the watcher read
        // of the stills, never from these asserts.
        sendLine("Write hello.py that prints ANSWER 42 on line one and DONE on line two, then run it with python. Also write index.html with a green Hello page.")
        expectBubble(containing: "hello.py", timeout: 420)
        // t111: agent turn was mid-flight (reads done, run pending) when the
        // window expired — slow streaming rounds need the longer allowance.
        expectBubble(containing: "Running python", timeout: 600)
        // Completion marker carries the byte count (echo-proof: the number is
        // computed at runtime). Watcher adjudicates the actual stdout text.
        // t123: agent was mid-turn (narrating progress) when 300s expired.
        expectBubble(containing: "python stdout bytes:", timeout: 600)
        Thread.sleep(forTimeInterval: 60)
        snap("b0-coded-and-ran")

        // Footer carries the paid model id (no other models allowed).
        expectBubbleStable(containing: "muse-spark-1.3-contributor")

        // Tab switching: TERMINAL → SPLIT → PREVIEW. Surfaces are proven by
        // stills + watcher (t83-86 dumps: neither forgeTerminal, the preview
        // WKWebView, nor the previewModeToggle container surface stable AX
        // ids — tab labels do). Stable taps throughout (t84-87: single-shot
        // waits die on sick snapshots under guest load).
        tapStable(buttonLabel: "TERMINAL")
        snap("b1-terminal")
        tapStable(buttonLabel: "SPLIT")
        snap("b2-split")
        tapStable(buttonLabel: "PREVIEW")
        snap("b3-preview")
    }

    private func connectPrologue(key: String) {
        sendLine("/connect provider openai")
        expectBubble(containing: "Saved provider", timeout: 20)
        sendLine("/connect model muse-spark-1.3-contributor")
        expectBubble(containing: "Saved model", timeout: 20)
        sendLine("/connect url https://opencode.ai/zen/go/v1")
        expectBubble(containing: "Saved url", timeout: 20)
        sendLine("/connect key")
        let secure = app.secureTextFields.firstMatch
        waitFor(secure, timeout: 15)
        secure.tap()
        secure.typeText(key)
        Thread.sleep(forTimeInterval: 45)
        var saved = false
        for i in 1...5 {
            let save = app.alerts.firstMatch.buttons["Save"].firstMatch
            if save.waitForExistence(timeout: 12) {
                save.tap()
                saved = true
                break
            }
            if i < 5 { Thread.sleep(forTimeInterval: 10) }
        }
        XCTAssertTrue(saved, "Save button never appeared")
        expectBubble(containing: "saved to Keychain", timeout: 90)
        sendLine("/connect test")
        expectBubble(containing: "PASS: connected", timeout: 150)
    }

    /// F5 connected-only take: assumes a connected app state from a prior take
    /// on the same sim (driver --no-uninstall). Skips the SecureField prologue
    /// entirely — the flakiest 3 minutes of every take.
    func testLivePythonConnected() {
        enterMode1()
        sendLine("Call the python tool with code print(40+2) on line one and print DONE on line two. Then report the exact stdout.")
        expectBubble(containing: "command(s)", timeout: 900)
        Thread.sleep(forTimeInterval: 30)
        snap("p0-stdout")
        // Footer carries the paid model id (no other models allowed).
        expectBubbleStable(containing: "muse-spark-1.3-contributor")
    }

    /// F5 focused take: ONE python run, tight prompt, no multi-file orbit.
    /// Proves live-agent stdout on pixels with minimal rounds and tree load.
    func testLivePythonStandalone() {
        let key = proofKey()
        enterMode1()
        connectPrologue(key: key)

        // Tight prompt: run first, one file, no preview orbit.
        // t116 lesson: agent PROSE can contain "Running python" ("Running it
        // now...") — bubble text cannot tell narration from product markers.
        // The only XCTest-side completion signal is the turn done-check
        // (runtime-computed counts); stdout truth is watcher-only.
        sendLine("Call the python tool with code print(40+2) on line one and print DONE on line two. Then report the exact stdout.")
        expectBubble(containing: "command(s)", timeout: 900)
        Thread.sleep(forTimeInterval: 30)
        snap("p0-stdout")
        // Footer carries the paid model id (no other models allowed).
        expectBubbleStable(containing: "muse-spark-1.3-contributor")
        // Second leg (t124 lesson): the multi-file prompt lets the model skip
        // the run. With python proven above, order the page + preview alone.
        sendLine("Call the write tool to create index.html with a green Hello page, then call the preview tool on it.")
        expectBubble(containing: "command(s)", timeout: 900)
        Thread.sleep(forTimeInterval: 30)
        tapStable(buttonLabel: "PREVIEW")
        snap("p1-preview")
    }
}
