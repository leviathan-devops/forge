import XCTest

/// T-9 deterministic battery: no-LLM Mode 1 turn via FORGE_TEST_MODE1_E2E=1.
///
/// writeFile hello.py → runPython (Pyodide) → write index.html from result →
/// renderPreview. No model, no key, no flakiness: every marker is computed at
/// runtime. Watcher adjudicates pixels; asserts below are flow gates.
final class E2EUITests: XCTestCase {

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
        let url = URL(fileURLWithPath: "/tmp/e2e-proof/" + name + ".png")
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: url)
    }

    func testMode1WriteRunPreview() {
        // Enter Mode 1 through the card tap, like a user.
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
        snap("e0-entered")

        // Deterministic markers from the shipped fixture. NOTE (t94): the
        // "[e2e]" line goes to the SwiftTerm canvas (AX-invisible); the
        // preview card renders in WKWebView (AX-visible web content), so
        // assert on the card, never on terminal text.
        expectBubble(containing: "FORGE PREVIEW", timeout: 420)
        expectBubble(containing: "ANSWER 42", timeout: 60)
        // NOTE (t97): CANVAS OK is canvas-drawn pixels (AX-invisible by
        // nature) — watcher proves it on stills, never assert it here.
        snap("e1-preview-rendered")
        // Preview tab shows the rendered page; stills + watcher prove pixels.
        let prevTab = app.buttons["PREVIEW"].firstMatch
        if prevTab.waitForExistence(timeout: 20) {
            prevTab.tap()
            Thread.sleep(forTimeInterval: 5)
        }
        snap("e2-preview-tab")
    }
}
