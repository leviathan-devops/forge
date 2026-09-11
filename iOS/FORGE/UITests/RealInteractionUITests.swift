import XCTest

/// Real touch + keyboard interaction tests — the things simctl cannot do.
///
/// Drives FORGE with ACTUAL taps and keystrokes through XCUITest:
///   A. REAL agent turn (OpenRouter free via /tmp/demo-env.json key) →
///      tap the collapsed write one-liner → payload expands (N3 proof) →
///      play button → preview sheet opens → Close dismisses it (N7)
///   B. tap the AGENT MODE card → type into the composer (real keyboard)
///      → tap send → user bubble appears
///
/// Config: /tmp/demo-env.json {"api_key":..., "base_url":..., "model":...}
/// (the DemoWalkthrough config-file pattern — runner env does not survive
/// the ssh→xcodebuild chain).
final class RealInteractionUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-FORGE_START_MODE", "none"]
        if let data = try? Data(contentsOf: URL(fileURLWithPath: "/tmp/demo-env.json")),
           let cfg = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            if let key = cfg["api_key"], !key.isEmpty { app.launchEnvironment["FORGE_API_KEY"] = key }
            if let url = cfg["base_url"], !url.isEmpty { app.launchEnvironment["FORGE_API_BASE_URL"] = url }
            if let model = cfg["model"], !model.isEmpty { app.launchEnvironment["FORGE_API_MODEL"] = model }
        }
        // launchEnvironment must be set BEFORE launch() — post-launch writes
        // never reach the running process (that was the silent no-turn bug).
        if self.name.contains("testA") {
            app.launchEnvironment["FORGE_TEST_PROMPT"] =
                "Write a file uitest.txt containing uitest-ok then run ls"
        }
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    private func waitFor(_ element: XCUIElement, timeout: TimeInterval = 10,
                         file: StaticString = #filePath, line: UInt = #line) {
        let ok = element.waitForExistence(timeout: timeout)
        if !ok {
            // Dump the live tree so failures name what WAS on screen.
            print("=== UI TREE DUMP (failure context) ===")
            print(app.debugDescription)
            print("=== END DUMP ===")
        }
        XCTAssertTrue(ok, "element not found: \(element)", file: file, line: line)
    }

    private func settle(_ seconds: Double) {
        // The engine WKWebView boots on Mode-1 entry; heavy webview work can
        // starve the accessibility snapshot. Give it room before queries.
        Thread.sleep(forTimeInterval: seconds)
    }

    /// FULL-A: real LLM turn → tool-row tap-to-expand (N3) → preview sheet (N7).
    func testA_TurnToolRowExpandAndPreview() {
        let card = app.buttons["BUILD ON-DEVICE"].firstMatch
        waitFor(card, timeout: 15)
        card.tap()

        let composer = app.textFields["Message"].firstMatch
        waitFor(composer, timeout: 20)

        // The turn writes uitest.txt and finishes with a done banner.
        let row = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "uitest.txt")
        ).firstMatch
        waitFor(row, timeout: 150)
        row.tap()

        // Expanded panel shows the written content token.
        let payload = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "uitest-ok")
        ).firstMatch
        waitFor(payload, timeout: 8)

        // Preview sheet via the play button (N7).
        let play = app.buttons["previewButton"].firstMatch
        waitFor(play, timeout: 10)
        play.tap()

        let close = app.buttons["Close"].firstMatch
        waitFor(close, timeout: 10)
        close.tap()

        waitFor(app.textFields["Message"].firstMatch, timeout: 8)
    }

    /// FULL-B: card tap navigation + composer typing + send bubble.
    func testB_TapNavigateAndTypeAndSend() {
        let card = app.buttons["BUILD ON-DEVICE"].firstMatch
        waitFor(card, timeout: 15)
        card.tap()

        // Fresh sessions seed the workspace async — the composer is the
        // deterministic Mode-1 marker.
        let composer = app.textFields["Message"].firstMatch
        waitFor(composer, timeout: 20)
        settle(3)

        composer.tap()
        settle(1)
        composer.typeText("uitest-typed")

        let send = app.buttons["sendButton"].firstMatch
        waitFor(send, timeout: 8)
        send.tap()

        let bubble = app.staticTexts["uitest-typed"].firstMatch
        waitFor(bubble, timeout: 10)
    }
}
