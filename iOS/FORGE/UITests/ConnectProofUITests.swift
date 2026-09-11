import XCTest

/// SC-11 proof: in-TUI /connect provider auth with zero launch-env overrides.
///
/// Drives the PRODUCTION path with synthetic user input (tap + type):
/// Mode card tap → composer → typed /connect commands → native secure key
/// entry → live /connect test call → terminate + relaunch → still connected
/// (Keychain persistence). No FORGE_API_* launch environment is set; the
/// only secret source is /tmp/connect-proof-env.json {"api_key": ...},
/// written by the harness over sftp and never logged.
final class ConnectProofUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        // Menu first: mode entry happens through the card tap, like a user.
        app.launchArguments += ["-FORGE_START_MODE", "none"]
        app.launch()
        // Zero-override proof (SC-11): fail loudly if any launch channel
        // carries provider credentials; the key travels guest-file only.
        let launchSurface = app.launchArguments.joined(separator: " ")
            + app.launchEnvironment.values.joined(separator: " ")
        XCTAssertFalse(launchSurface.contains("FORGE_API_"),
            "launch-env override present")
        // Cold-start allowance: fresh-booted sim + cold bundle need wall time
        // before first interaction (t75: menu still rendering at test+40s).
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

    /// Reads the key-length marker from the status bubble. The bubble carries
    /// NO key material (length only), so comparing two readings proves the
    /// Keychain round-trip without ever touching secret bytes.
    private func statusKeyLength(file: StaticString = #filePath, line: UInt = #line) -> Int {
        let bubble = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "API Key:")
        ).firstMatch
        waitFor(bubble, timeout: 20, file: file, line: line)
        let label = bubble.label
        XCTAssertFalse(label.contains("contributor-free"), "free model id leaked into status", file: file, line: line)
        guard let r = label.range(of: #"configured \((\d+) chars\)"#, options: .regularExpression) else {
            XCTFail("status lacks key-length marker", file: file, line: line)
            return -1
        }
        let digits = label[r].components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Int(digits) ?? -1
    }

    private func snap(_ name: String) {        let shot = XCUIScreen.main.screenshot()
        let url = URL(fileURLWithPath: "/tmp/connect-proof/" + name + ".png")
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

    /// SC-11: typed /connect end to end on a clean slate, then persistence.
    func testConnectFlowAndPersistence() {
        let key = proofKey()
        enterMode1()
        snap("01-entered-mode1")

        // Typed /connect opens the provider-auth flow.
        sendLine("/connect status")
        expectBubble(containing: "Provider auth", timeout: 45)
        snap("02-connect-status")
        let lenBeforeRelaunch = statusKeyLength()

        // Non-secret fields through typed slash commands.
        sendLine("/connect provider openai")
        expectBubble(containing: "Saved provider", timeout: 20)
        sendLine("/connect model muse-spark-1.3-contributor")
        expectBubble(containing: "Saved model", timeout: 20)
        sendLine("/connect url https://opencode.ai/zen/go/v1")
        expectBubble(containing: "Saved url", timeout: 20)
        snap("03-fields-set")

        // Key through the native secure prompt — never typed terminal text.
        sendLine("/connect key")
        let secure = app.secureTextFields.firstMatch
        waitFor(secure, timeout: 15)
        secure.tap()
        secure.typeText(key)
        // SecureField value is not observable to AX: typing is proven by
        // dots on tape, so settle fixed, then Save; the Keychain bubble arbitrates.
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
        // First-ever Keychain write on a cold sim can stall inside SecItemAdd
        // (t65 DIAG: setSecret entered, no return within 23s). Allow 90s.
        expectBubble(containing: "saved to Keychain", timeout: 90)
        snap("04-key-saved")

        // Live connected-provider call, zero launch-env overrides.
        sendLine("/connect test")
        expectBubble(containing: "PASS: connected", timeout: 150)
        snap("05-test-pass")

        // Persistence leg: terminate + relaunch clean, still connected.
        app.terminate()
        app.launch()
        enterMode1()
        sendLine("/connect status")
        // Post-relaunch inject reads Keychain synchronously; same allowance.
        expectBubble(containing: "configured", timeout: 60)
        // t79 tripwires: persisted model+URL must be the paid Go pair, and the
        // Keychain-read key length must equal the pre-relaunch reading.
        expectBubble(containing: "go/v1", timeout: 20)
        expectBubble(containing: "muse-spark-1.3-contributor", timeout: 20)
        let lenAfterRelaunch = statusKeyLength()
        XCTAssertGreaterThan(lenBeforeRelaunch, 30, "pre-relaunch key length implausible")
        XCTAssertEqual(lenBeforeRelaunch, lenAfterRelaunch, "keychain round-trip changed key material")
        sendLine("/connect test")
        expectBubble(containing: "PASS: connected", timeout: 150)
        snap("06-persistence-pass")
    }
}
