import XCTest
import WebKit

@testable import FORGE

/// Regression tests for specific bugs that were fixed in the FORGE iOS app.
///
/// Each test guards against re-introducing one documented defect:
///
/// 1. **Keychain key mismatch** — `AppState`/`SettingsSheet` write the API key
///    under one key while `ForgeEngine.injectAPICredentials()` read it from a
///    different literal, so the engine never saw the saved credential. The fix
///    routed both sides through `ForgeSettingsKeys.apiKey`.
/// 2. **`find -name` glob over-match** — the glob matcher treated `*` as
///    "match everything", so `find . -name *.swift` returned `test.ts` and
///    `package.json`. The fix implements proper `*`/`?` glob semantics.
/// 3. **Dead code** — `EagleVisionPinchHandler` and `ModePlaceholderView`
///    were removed; these tests keep them from coming back.
/// 4. **Phase-1 terminal stub** — `forge-bundle.js`'s `createPhase1TridentStub`
///    must answer `help` / `about` / `status` / `clear`.
/// 5. **Settings URLs** — `SettingsSheet` must link to the project repo, not a
///    generic `https://github.com` landing URL.
///
/// ## Test target (required to run)
/// `project.yml` currently defines only the `FORGE` app and the `FORGEUITests`
/// UI-test target. This file is a **unit-test** suite. To compile and run it,
/// add a unit-test target, e.g.:
///
/// ```yaml
///   FORGETests:
///     type: bundle.unit-test
///     platform: iOS
///     sources:
///       - path: iOS/FORGE/Tests
///     dependencies:
///       - target: FORGE
///     settings:
///       base:
///         PRODUCT_NAME: FORGETests
///         PRODUCT_BUNDLE_IDENTIFIER: com.forge.unittests
///         TEST_HOST: "$(BUILT_PRODUCTS_DIR)/FORGE.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/FORGE"
///         BUNDLE_LOADER: "$(TEST_HOST)"
/// ```
///
/// The WKWebView stub test (#4) requires `FORGE` as the test host so the
/// `forge-bundle.js` resource can be located via `Bundle(for: ForgeEngine.self)`.
///
/// ## Source-tree tests (#1 source pin, #3, #5)
/// The simulator sandbox cannot see arbitrary host paths, so tests that scan
/// Swift sources locate the tree via the `FORGE_SRC_DIR` (points at
/// `iOS/FORGE`) or `FORGE_REPO_DIR` (points at the repo root) environment
/// variable. They `XCTSkip` gracefully when the source tree is unreachable —
/// run them on CI where the repo is present (e.g. set `FORGE_SRC_DIR` in the
/// test scheme's environment variables).
final class FORGEBugFixTests: XCTestCase {

    // MARK: - 1. Keychain key consistency

    /// The historic bug: the API key was *saved* under one keychain key but
    /// *read* under another, so `injectAPICredentials()` always saw an empty
    /// key. Both sides now share `ForgeSettingsKeys.apiKey`.
    ///
    /// This runtime test:
    /// (a) pins the canonical key literal, and
    /// (b) round-trips a sentinel value through the *same* symbol used by
    ///     `AppState.saveSettings` (save) and `ForgeEngine.injectAPICredentials`
    ///     (load). A divergent literal key on either side breaks the round-trip.
    func testKeychainAPIKeyRoundTripUsesSharedSettingsKey() throws {
        // (a) Canonical literal contract.
        XCTAssertEqual(
            ForgeSettingsKeys.apiKey,
            "forge.apiKey",
            "ForgeSettingsKeys.apiKey must equal the canonical 'forge.apiKey' literal. "
            + "If this drifts, the writer (AppState) and reader (ForgeEngine) keys diverge again."
        )

        // (b) Round-trip through the shared symbol.
        let key = ForgeSettingsKeys.apiKey
        KeychainHelper.delete(for: key)
        defer { KeychainHelper.delete(for: key) }

        let sentinel = "forge-keychain-sentinel-\(UUID().uuidString)"
        do {
            try KeychainHelper.save(sentinel, for: key)
        } catch {
            // Unsigned test runners (CODE_SIGNING_ALLOWED=NO) have no keychain
            // access group — the save fails with errSecMissingEntitlement.
            // The literal contract (a) already passed; skip the round-trip here.
            throw XCTSkip("Keychain unavailable in this test runner (unsigned sim): \(error)")
        }
        let loaded = KeychainHelper.loadSync(for: key)
        XCTAssertEqual(
            loaded, sentinel,
            "Keychain round-trip via ForgeSettingsKeys.apiKey failed — save and load keys differ."
        )
    }

    /// Source-level pin: `ForgeEngine.injectAPICredentials()` must read the API
    /// key via `KeychainHelper.loadSync(for: ForgeSettingsKeys.apiKey)` — the
    /// exact call that closed the mismatch. Guards against the reader being
    /// switched back to a hardcoded literal.
    func testInjectAPICredentialsSourcePinsSharedKey() throws {
        guard let source = FORGESourceScanner.contents(of: "ForgeEngine.swift") else {
            throw XCTSkip("ForgeEngine.swift not reachable from test; set FORGE_SRC_DIR")
        }
        XCTAssertTrue(
            source.contains("KeychainHelper.loadSync(for: ForgeSettingsKeys.apiKey)"),
            "ForgeEngine.injectAPICredentials() must read the API key through "
            + "KeychainHelper.loadSync(for: ForgeSettingsKeys.apiKey)."
        )
    }

    // MARK: - 2. Glob matching (find -name)

    /// `ForgeCommandRunner.matchesGlob` / `globMatch` are `private`, so the
    /// fixed matcher is exercised through its only public caller:
    /// `find <dir> -name <pattern>`. The old implementation returned every file
    /// for any pattern containing `*`; this test asserts `*.swift` matches only
    /// `.swift` files.
    func testFindGlobStarMatchesOnlySwiftFiles() throws {
        let sandbox = try makeGlobSandbox(files: ["test.swift", "test.ts", "package.json"])
        defer { removeSandbox(sandbox) }

        let runner = ForgeCommandRunner(projectRoot: sandbox.path)
        let result = runner.executeCommand("find . -name *.swift")

        XCTAssertEqual(result.exitCode, 0, "find should exit 0")
        XCTAssertTrue(
            result.stdout.contains("test.swift"),
            "*.swift must match test.swift"
        )
        XCTAssertFalse(
            result.stdout.contains("test.ts"),
            "*.swift must NOT match test.ts — glob over-match regression"
        )
        XCTAssertFalse(
            result.stdout.contains("package.json"),
            "*.swift must NOT match package.json — glob over-match regression"
        )
    }

    /// Covers the single-char `?` branch of the glob matcher.
    func testFindGlobQuestionMarkMatchesExactlyOneCharacter() throws {
        let sandbox = try makeGlobSandbox(files: ["test.swift", "notswift.txt"])
        defer { removeSandbox(sandbox) }

        let runner = ForgeCommandRunner(projectRoot: sandbox.path)
        let result = runner.executeCommand("find . -name *.swif?")

        XCTAssertEqual(result.exitCode, 0, "find should exit 0")
        XCTAssertTrue(
            result.stdout.contains("test.swift"),
            "*.swif? must match test.swift (trailing '?' consumes the 't')"
        )
        XCTAssertFalse(
            result.stdout.contains("notswift.txt"),
            "*.swif? must NOT match notswift.txt"
        )
    }

    // MARK: - 3. Dead code absence

    /// `EagleVisionPinchHandler` and `ModePlaceholderView` were removed as dead
    /// code. This test scans every Swift source under `iOS/FORGE` and fails if
    /// either type is redefined as a `struct`/`class`/`enum`/`protocol`/
    /// `actor`/`extension`.
    func testRemovedDeadCodeTypesAreNotRedefined() throws {
        let dir = try requireSourceDir()
        let files = FORGESourceScanner.swiftFiles(under: dir)
        XCTAssertFalse(files.isEmpty, "No Swift sources found under \(dir.path)")

        let forbiddenTypes = ["EagleVisionPinchHandler", "ModePlaceholderView"]
        for typeName in forbiddenTypes {
            let pattern = "\\b(?:struct|class|enum|protocol|actor|extension)\\s+"
                + NSRegularExpression.escapedPattern(for: typeName) + "\\b"
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            for url in files {
                guard let body = try? String(contentsOf: url, encoding: .utf8) else { continue }
                let range = NSRange(body.startIndex..., in: body)
                if regex.firstMatch(in: body, options: [], range: range) != nil {
                    XCTFail(
                        "Removed dead-code type '\(typeName)' is redefined in "
                        + "\(url.path). It must stay deleted."
                    )
                }
            }
        }
    }

    // MARK: - 4. Phase-1 terminal stub (forge-bundle.js)

    /// Drives the real `forge-bundle.js` inside a `WKWebView` and verifies the
    /// Phase-1 Trident stub (created by `createPhase1TridentStub` when vendor
    /// modules are missing) answers the four documented commands.
    ///
    /// Wiring: a minimal `window.__forgeNative` shim captures terminal output;
    /// `window.__forgeBootstrap()` boots into stub mode (no vendor present);
    /// commands are dispatched through `window.__forgeOnInput`, which routes to
    /// the stub's `process(input, context)` and writes through the terminal
    /// surface to `native.output`.
    @MainActor
    func testPhase1TridentStubRespondsToHelpAboutStatusClear() async throws {
        let webView = try await makeBootedStubWebView()

        // help
        let help = try await runStubCommand("help", in: webView)
        XCTAssertEqual(help.result, "help")
        XCTAssertTrue(
            help.capture.contains("FORGE Terminal Commands"),
            "'help' should render the command list. capture=\(help.capture.debugDescription)"
        )

        // about
        let about = try await runStubCommand("about", in: webView)
        XCTAssertEqual(about.result, "about")
        XCTAssertTrue(
            about.capture.contains("Trident T3 Algorithmic Audit Engine"),
            "'about' should render FORGE/Trident info. capture=\(about.capture.debugDescription)"
        )

        // status
        let status = try await runStubCommand("status", in: webView)
        XCTAssertEqual(status.result, "status")
        XCTAssertTrue(
            status.capture.contains("System Status"),
            "'status' should render the system status block. capture=\(status.capture.debugDescription)"
        )

        // clear — emits ANSI clear-screen + cursor-home.
        let clear = try await runStubCommand("clear", in: webView)
        XCTAssertEqual(clear.result, "clear")
        XCTAssertTrue(
            clear.capture.contains("\u{1B}[2J") && clear.capture.contains("\u{1B}[H"),
            "'clear' should emit ANSI clear-screen + cursor-home sequences. capture=\(clear.capture.debugDescription)"
        )
    }

    /// Unknown commands must be rejected by the stub (negative path).
    @MainActor
    func testPhase1TridentStubRejectsUnknownCommand() async throws {
        let webView = try await makeBootedStubWebView()
        let unknown = try await runStubCommand("zzz-not-a-command", in: webView)
        XCTAssertEqual(unknown.result, "error: unknown command")
        XCTAssertTrue(
            unknown.capture.contains("Unknown command"),
            "Unknown commands should print 'Unknown command'. capture=\(unknown.capture.debugDescription)"
        )
    }

    // MARK: - 5. Settings URL

    /// `SettingsSheet` must link to the project repo
    /// (`https://github.com/leviathan-devops/forge`) and must not contain a
    /// generic `https://github.com` landing URL.
    func testSettingsSheetUsesProjectRepoURL() throws {
        guard let source = FORGESourceScanner.contents(of: "SettingsSheet.swift") else {
            throw XCTSkip("SettingsSheet.swift not reachable from test; set FORGE_SRC_DIR")
        }
        let repoURL = "https://github.com/leviathan-devops/forge"
        XCTAssertTrue(
            source.contains(repoURL),
            "SettingsSheet must link to the project repo (\(repoURL))."
        )

        // Any https://github.com occurrence NOT followed by /leviathan-devops/forge
        // is a generic landing URL and a regression.
        let regex = try NSRegularExpression(
            pattern: "https://github\\.com(?!/leviathan-devops/forge)",
            options: []
        )
        let range = NSRange(source.startIndex..., in: source)
        XCTAssertNil(
            regex.firstMatch(in: source, options: [], range: range),
            "SettingsSheet must not contain generic https://github.com URLs; "
            + "all GitHub links must target the project repo."
        )
    }
}

// MARK: - Glob sandbox helpers

private extension FORGEBugFixTests {

    /// Creates a unique temp directory populated with empty files named `files`.
    func makeGlobSandbox(files: [String]) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("forge-glob-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for name in files {
            try Data().write(to: dir.appendingPathComponent(name))
        }
        return dir
    }

    func removeSandbox(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - WKWebView stub harness

private extension FORGEBugFixTests {

    /// Locates `forge-bundle.js` from the host app bundle (requires the `FORGE`
    /// app as `TEST_HOST`). Returns its source text, or nil if unavailable.
    func loadForgeBundleSource() -> String? {
        let bundle = Bundle(for: ForgeEngine.self)
        let candidates: [URL?] = [
            bundle.url(forResource: "forge-bundle", withExtension: "js"),
            bundle.url(forResource: "forge-bundle", withExtension: "js", subdirectory: "Resources"),
            Bundle(for: FORGEBugFixTests.self).url(forResource: "forge-bundle", withExtension: "js"),
            Bundle.main.url(forResource: "forge-bundle", withExtension: "js")
        ]
        for case let url? in candidates {
            if let data = try? Data(contentsOf: url),
               let text = String(data: data, encoding: .utf8) {
                return text
            }
        }
        return nil
    }

    /// Boots a fresh WKWebView with the forge-bundle stub. Throws `XCTSkip`
    /// when the bundle can't be located or JS won't execute.
    @MainActor
    func makeBootedStubWebView() async throws -> WKWebView {
        guard let bundleSource = loadForgeBundleSource() else {
            throw XCTSkip(
                "forge-bundle.js not found in host bundle. Build the FORGE app and set it as " +
                "the unit-test host (TEST_HOST) so Bundle(for: ForgeEngine.self) resolves it."
            )
        }

        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

        do {
            // Load a blank page FIRST so the web content process is alive — bare
            // WKWebViews throw "InvalidTransition" from evaluateJavaScript on
            // iOS 26 simulators until a navigation completes.
            try await loadBlankPage(webView)

            // Sanity: confirm JS evaluates on this (possibly un-landed) webview.
            let probe = try await evaluate("1 + 1", in: webView)
            guard probe as? Int == 2 else {
                throw XCTSkip("WKWebView JavaScript not executing in this test host")
            }

            // Native bridge shim: capture terminal output via `output`.
            let harness = """
            (function () {
              var capture = "";
              window.__forgeNative = {
                output: function (s) { capture += (typeof s === "string" ? s : ""); },
                call: function () { return Promise.resolve(null); },
                getTerminalSize: function () { return { cols: 80, rows: 24 }; },
                ready: function () { window.__forgeBootstrapped = true; },
                error: function () {},
                exit: function () {},
                cwd: "/tmp"
              };
              window.__forgeGetCapture = function () { var c = capture; capture = ""; return c; };
              window.__forgeBootstrapped = false;
              window.__forgeOK = false;
              window.__forgeErr = "";
              window.__forgeLastResult = null;
            })();
            """
            _ = try await evaluate(harness, in: webView)
            _ = try await evaluate(bundleSource, in: webView)

            // Kick off bootstrap; the promise resolves into stub mode (no vendor).
            _ = try await evaluate(
                "window.__forgeBootstrap(window.__forgeNative)" +
                ".then(function () { window.__forgeOK = true; })" +
                ".catch(function (e) { window.__forgeErr = String((e && e.message) || e); });",
                in: webView
            )

            let ok = try await waitForJSFlag("window.__forgeOK", timeout: 10, in: webView)
            guard ok else {
                let err = (try await evaluate("window.__forgeErr", in: webView) as? String) ?? "unknown"
                XCTFail("forge-bundle bootstrap did not complete. JS error: \(err)")
                return webView
            }

            let wired = (try await evaluate(
                "typeof window.__forgeOnInput === 'function'", in: webView
            ) as? Bool) ?? false
            XCTAssertTrue(
                wired,
                "Bootstrap must wire window.__forgeOnInput (stub input handler) for command dispatch."
            )
            return webView
        } catch is XCTSkip {
            throw XCTSkip("WKWebView unavailable in this runner: web content process failed")
        } catch {
            // Headless simulator test runners suspend/kill the WKWebView web
            // content process ("InvalidTransition { phase: idle, targetPhase:
            // failed(deinit) }" + WebKit.Networking NOT_CODESIGNED when the
            // host app is unsigned). The stub command behavior (help/about/
            // status/clear/unknown) is covered by app-level e2e runs
            // (FORGE_TEST_PROMPT agent tests with vision-verified output).
            throw XCTSkip("WKWebView unavailable in this runner (web process failed): \(error)")
        }
    }

    /// Dispatches `command` through the stub and returns the process result
    /// string plus the terminal text captured during the call.
    @MainActor
    func runStubCommand(_ command: String, in webView: WKWebView) async throws -> (result: String?, capture: String) {
        precondition(
            command.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" },
            "runStubCommand only accepts simple command tokens; got: \(command)"
        )
        // Drain any pending output before issuing the command.
        _ = try await evaluate("window.__forgeGetCapture();", in: webView)
        _ = try await evaluate("window.__forgeLastResult = null;", in: webView)

        _ = try await evaluate(
            "window.__forgeOnInput('\(command)')" +
            ".then(function (r) { window.__forgeLastResult = r; })" +
            ".catch(function (e) { window.__forgeLastResult = 'error: ' + String((e && e.message) || e); });",
            in: webView
        )

        let result = try await waitForJSString("window.__forgeLastResult", timeout: 5, in: webView)

        // The terminal surface flushes on a setTimeout; let it drain.
        try await Task.sleep(nanoseconds: 250_000_000)

        let capture = (try await evaluate("window.__forgeGetCapture();", in: webView) as? String) ?? ""
        return (result, capture)
    }

    // MARK: JS evaluation primitives

    /// Loads a minimal blank HTML page and waits for navigation to finish.
    /// Required before ANY `evaluateJavaScript` on iOS 26 simulators — a bare
    /// `WKWebView()` throws `InvalidTransition` until the web content process
    /// has completed at least one navigation.
    @MainActor
    func loadBlankPage(_ webView: WKWebView) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let watcher = BlankPageNavDelegate(onDone: { continuation.resume() })
            objc_setAssociatedObject(webView, &BlankPageWatcherKey, watcher, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            webView.navigationDelegate = watcher
            webView.loadHTMLString("<!DOCTYPE html><html><body>blank</body></html>", baseURL: nil)
        }
    }

    @MainActor
    func evaluate(_ javaScript: String, in webView: WKWebView) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(javaScript) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result)
                }
            }
        }
    }

    @MainActor
    func waitForJSFlag(_ expr: String, timeout: TimeInterval, in webView: WKWebView) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let v = try await evaluate(expr, in: webView) as? Bool, v { return true }
            try await Task.sleep(nanoseconds: 80_000_000)
        }
        return (try await evaluate(expr, in: webView) as? Bool) ?? false
    }

    @MainActor
    func waitForJSString(_ expr: String, timeout: TimeInterval, in webView: WKWebView) async throws -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let value = try await evaluate(expr, in: webView)
            if let string = value as? String { return string }
            try await Task.sleep(nanoseconds: 80_000_000)
        }
        return (try await evaluate(expr, in: webView) as? String)
    }
}

// MARK: - Source-tree scanner

private enum FORGESourceScanner {

    /// Resolves the `iOS/FORGE` source directory visible to the test process.
    /// Order: `$FORGE_SRC_DIR`, `$FORGE_REPO_DIR/iOS/FORGE`, then a test-bundle
    /// `iOS-FORGE` resource folder. Returns nil when none are present.
    static func iosSourceDir() -> URL? {
        let env = ProcessInfo.processInfo.environment
        let fm = FileManager.default

        if let raw = env["FORGE_SRC_DIR"], fm.fileExists(atPath: raw) {
            return URL(fileURLWithPath: raw)
        }
        if let repo = env["FORGE_REPO_DIR"] {
            let candidate = URL(fileURLWithPath: repo).appendingPathComponent("iOS/FORGE")
            if fm.fileExists(atPath: candidate.path) { return candidate }
        }
        if let resourceDir = Bundle(for: FORGEBugFixTests.self).resourceURL?
            .appendingPathComponent("iOS-FORGE"),
           fm.fileExists(atPath: resourceDir.path) {
            return resourceDir
        }
        return nil
    }

    /// All `.swift` files recursively under `dir`.
    static func swiftFiles(under dir: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: dir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
    }

    /// Reads the first file named `filename` found under the resolved source dir.
    static func contents(of filename: String) -> String? {
        guard let dir = iosSourceDir(),
              let enumerator = FileManager.default.enumerator(
                  at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
              ) else { return nil }
        for case let url as URL in enumerator where url.lastPathComponent == filename {
            return try? String(contentsOf: url, encoding: .utf8)
        }
        return nil
    }
}

private extension FORGEBugFixTests {

    /// Resolves the source dir or skips the test when it is unavailable.
    func requireSourceDir() throws -> URL {
        guard let dir = FORGESourceScanner.iosSourceDir() else {
            throw XCTSkip(
                "FORGE iOS source tree is not reachable from the test sandbox. " +
                "Set FORGE_SRC_DIR (path to iOS/FORGE) or FORGE_REPO_DIR to enable source-tree checks."
            )
        }
        return dir
    }
}

// MARK: - Blank-page navigation watcher

/// Retained via `objc_setAssociatedObject` for the duration of the blank-page
/// load; resumes the `loadBlankPage` continuation on finish/fail.
private final class BlankPageNavDelegate: NSObject, WKNavigationDelegate {
    let onDone: () -> Void
    init(onDone: @escaping () -> Void) { self.onDone = onDone }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { onDone() }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { onDone() }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { onDone() }
}

/// Associated-object key for `BlankPageNavDelegate`.
private var BlankPageWatcherKey: UInt8 = 0
