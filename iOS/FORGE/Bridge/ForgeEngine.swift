import Foundation
import WebKit
import UIKit

/// ForgeEngine
///
/// Per FORGE Engineering Specification §3.
///
/// Owns the hidden WKWebView (a 0x0-frame, offscreen JavaScript execution
/// environment) and the bidirectional message channel between Swift and
/// JavaScript.
///
/// Responsibilities:
/// 1. Configure the WKWebView with JavaScript, WASM, and local file access.
/// 2. Inject the native bridge API script (`window.__forgeNative`) before the
///    bundle loads.
/// 3. Load `forge-bundle.js` from app resources.
/// 4. Receive all messages on the `"native"` channel and route them to
///    `ForgeBridge`.
/// 5. Resolve / reject JavaScript callbacks via `evaluateJavaScript`.
/// 6. Forward ANSI output to SwiftTerm (batched at one frame for performance).
/// 7. Forward keyboard input back into the JS engine.
///
/// Simulator safety: init never force-unwraps, never evaluates JS before a
/// document exists, and surfaces bundle/bootstrap failures via `errorHandler`
/// instead of crashing the process (Gate D Mode1 residual).
final class ForgeEngine: NSObject, WKScriptMessageHandler, WKNavigationDelegate {

    // MARK: - Properties

    /// The hidden web view used purely as a JS sandbox.
    private(set) var webView: WKWebView?

    /// Weak proxy that breaks the retain cycle between ForgeEngine and
    /// WKUserContentController. The controller retains its message handlers,
    /// so passing `self` directly would create a cycle:
    ///   engine → webView → configuration → userContentController → engine
    /// The proxy is retained by the controller but weakly references the
    /// engine, breaking the cycle.
    private weak var messageProxy: WeakScriptMessageHandler?

    /// The bridge that handles every native method call.
    private let bridge: ForgeBridge

    /// Isolated Preview Pane API (FORGE-PREVIEW-SPEC-V1.0 §4).
    /// Uses a FRESH `WKProcessPool` inside PreviewBridge / PreviewPaneView.
    /// NEVER share this engine's hidden-agent process pool with the preview.
    let previewBridge: PreviewBridge

    /// Visible Preview WKWebView. Isolated process pool — never `webView`
    /// (the hidden agent sandbox) and never `webView.configuration.processPool`.
    var previewWebView: WKWebView? {
        get { previewBridge.previewWebView }
        set {
            if let wv = newValue {
                previewBridge.attachPreviewWebView(wv)
            }
        }
    }

    /// Invoked with batches of ANSI escape output destined for SwiftTerm.
    /// Set by the owning view; always called on the main thread.
    var outputHandler: ((String) -> Void)?

    /// Invoked once when the JS bundle signals `__ready`.
    var readyHandler: (() -> Void)?

    /// Invoked when the web view reports a navigation error (bundle load
    /// failure, etc.).
    var errorHandler: ((String) -> Void)?

    /// Tracks whether the `__ready` signal has fired (idempotent).
    private var readyFired = false

    /// Whether init completed without a fatal configuration error.
    private(set) var isInitialized: Bool = false

    // MARK: - Empty-response retry (§15.2 — t1b evidence f037-f093)

    /// Remaining retry attempts for the current turn (max 2 retries → 3 total attempts).
    private var retryBudget = 2

    /// The last escaped user input captured in `sendInput` for auto-retry.
    private var lastUserInput = ""

    // MARK: - Output batching (§8.4)

    /// Accumulates ANSI output for one frame (16 ms) before flushing to
    /// SwiftTerm, coalescing many small writes into a single `feed` call.
    private var outputBuffer = ""
    private var outputTimer: DispatchSourceTimer?
    private let outputQueue = DispatchQueue(label: "forge.output", qos: .userInitiated)

    // MARK: - Init (safe — never throws into SwiftUI)

    init(bridge: ForgeBridge) {
        self.bridge = bridge
        self.previewBridge = PreviewBridge()
        super.init()

        // Safe-init: construct WKWebView without evaluating JS and without
        // simulator-private KVC. Failures surface via errorHandler, never abort.
        configureWebView()
        isInitialized = (webView != nil)
        if !isInitialized {
            DispatchQueue.main.async { [weak self] in
                self?.errorHandler?("Engine init failed: WKWebView unavailable")
            }
        }

        // Wire the bridge back to this engine so it can resolve/reject.
        bridge.engine = self
        previewBridge.fileBridge = bridge
        previewBridge.engine = self
        previewBridge.onPreviewReady = { [weak self] _ in
            self?.showPreview()
        }
        previewBridge.onConsoleMessage = { [weak self] entry in
            let line = "\u{001b}[2m[preview] \(entry.message)\u{001b}[0m\r\n"
            self?.handleANSIOutput(line)
        }
    }

    /// Builds the hidden WKWebView (soft — sets webView nil only on failure).
    private func configureWebView() {
        let config = WKWebViewConfiguration()

        // JavaScript: prefer modern API, fall back for older SDKs.
        if #available(iOS 14.0, *) {
            let pagePrefs = WKWebpagePreferences()
            pagePrefs.allowsContentJavaScript = true
            config.defaultWebpagePreferences = pagePrefs
        } else {
            config.preferences.javaScriptEnabled = true
        }
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        // Soft private-API toggles for local file:// bundle loads. Use KVC
        // carefully — never force-unwrap; ignore failures on locked-down sims.
        softSetPreference(config.preferences, key: "allowFileAccessFromFileURLs", value: true)
        softSetPreference(config.preferences, key: "allowUniversalAccessFromFileURLs", value: true)

        // Use a non-persistent data store: opencode manages its own storage
        // (SQL.js WASM) and we do not want web-cache accumulation (§3.5).
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()

        // Register the message handler that JS calls via
        // `window.webkit.messageHandlers.native.postMessage(...)`.
        // Use a weak proxy to avoid the retain cycle:
        //   engine → webView → config → userContentController → engine
        let proxy = WeakScriptMessageHandler(proxyTarget: self)
        messageProxy = proxy
        config.userContentController.add(proxy, name: "native")

        // Inject the native API script at document start, before any bundle
        // code runs.
        injectNativeAPI(config.userContentController)

        // Custom scheme for Pyodide WASM/assets (indexURL forgepy://localhost/pyodide/).
        // Must be registered on this configuration before WKWebView is created.
        config.setURLSchemeHandler(PyodideSchemeHandler(), forURLScheme: "forgepy")

        // Create the WebView with a zero frame — it is never visible.
        // Agent process pool stays on this configuration. PreviewPaneView
        // allocates a FRESH WKProcessPool — NEVER share it with preview.
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self

        // Disable all user interaction; this view is invisible.
        wv.isUserInteractionEnabled = false
        wv.scrollView.isScrollEnabled = false
        wv.allowsBackForwardNavigationGestures = false

        // Do NOT evaluateJavaScript before a document is loaded — that used
        // to race under simulator and contributed to flaky Mode1 boots.
        webView = wv
    }

    /// Best-effort KVC for private WKPreferences keys used by local file loads.
    /// Skipped on simulator — file:// script tags work without these toggles
    /// for same-bundle resources, and private KVC is a residual crash surface.
    private func softSetPreference(_ prefs: WKPreferences, key: String, value: Bool) {
        #if targetEnvironment(simulator)
        // Simulator: skip private KVC entirely (residual crash surface under
        // XCUITest; same-bundle file:// script tags work without these).
        return
        #else
        // Device best-effort. Prefer setValue; if the key is missing the
        // runtime may ignore or log — never force-unwrap.
        prefs.setValue(value, forKey: key)
        #endif
    }

    // MARK: - Native API injection (§3.2)

    /// Injects `window.__forgeNative` with call/resolve/reject/output/ready and
    /// `window.__forgeInput` as a WKUserScript at document start.
    ///
    /// Also sets `autoBootstrap = false` so Swift owns the bootstrap call via
    /// `window.__forgeBootstrap()` after the IIFE bundle loads (phase1-stub
    /// honesty preserved; no fake full-agent claim).
    private func injectNativeAPI(_ controller: WKUserContentController) {
        let nativeAPIScript = """
        (function() {
            var callbackId = 0;
            var pendingCallbacks = {};

            window.__forgeNative = {
                // Swift drives bootstrap after script load (see loadBundle).
                autoBootstrap: false,

                call: function(method, args) {
                    return new Promise(function(resolve, reject) {
                        var id = 'cb_' + (++callbackId);
                        pendingCallbacks[id] = { resolve: resolve, reject: reject };
                        try {
                            window.webkit.messageHandlers.native.postMessage({
                                method: method,
                                args: args || {},
                                callbackId: id
                            });
                        } catch (e) {
                            delete pendingCallbacks[id];
                            reject(e);
                        }
                    });
                },

                resolve: function(id, result) {
                    if (pendingCallbacks[id]) {
                        pendingCallbacks[id].resolve(result);
                        delete pendingCallbacks[id];
                    }
                },

                reject: function(id, error) {
                    if (pendingCallbacks[id]) {
                        pendingCallbacks[id].reject(new Error(error));
                        delete pendingCallbacks[id];
                    }
                },

                output: function(ansi) {
                    // Terminal output gate: in chat mode the terminal lives in a
                    // sheet (not visible), so native.output() wake-up calls are
                    // pure WebContent churn. The sheet flips this flag on open.
                    if (!window.__forgeTerminalVisible) return;
                    try {
                        window.webkit.messageHandlers.native.postMessage({
                            method: '__output',
                            args: { ansi: String(ansi == null ? '' : ansi) }
                        });
                    } catch (e) { /* swallow — never crash host */ }
                },

                ready: function() {
                    try {
                        window.webkit.messageHandlers.native.postMessage({
                            method: '__ready',
                            args: {}
                        });
                    } catch (e) { /* swallow */ }
                },

                error: function(msg) {
                    try {
                        window.webkit.messageHandlers.native.postMessage({
                            method: '__error',
                            args: { message: String(msg == null ? '' : msg) }
                        });
                    } catch (e) { /* swallow */ }
                }
            };

            window.__forgeInput = function(data) {
                if (window.__forgeOnInput) {
                    try { window.__forgeOnInput(data); } catch (e) {}
                }
            };

            // Terminal visibility gate: false in chat mode (terminal in sheet).
            // TerminalSheet sets true when opened, false when dismissed.
            window.__forgeTerminalVisible = false;
        })();
        """

        let userScript = WKUserScript(
            source: nativeAPIScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        controller.addUserScript(userScript)
    }

    // MARK: - Bundle loading (§3.1)

    /// Loads `forge-bundle.js` (bundled in app resources) into the hidden
    /// web view. The bundle exposes `window.__forgeBootstrap` (phase1-stub
    /// honest path); we invoke it after the script tag loads.
    func loadBundle() {
        guard isInitialized, webView != nil else {
            DispatchQueue.main.async { [weak self] in
                self?.errorHandler?("ForgeEngine not initialized (safe-init failed)")
            }
            return
        }

        guard let bundleURL = Bundle.main.url(
            forResource: "forge-bundle", withExtension: "js"
        ) else {
            // No bundle present — surface a clear error instead of crashing
            // so the UI can present a recovery screen (§24.2).
            DispatchQueue.main.async { [weak self] in
                self?.errorHandler?("forge-bundle.js not found in app resources")
            }
            return
        }

        // Escape absolute file URL for embedding in HTML attribute.
        let src = bundleURL.absoluteString
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")

        // Invoke bootstrap safely: prefer window.__forgeBootstrap (exported
        // by forge-entry), fall back to autoBootstrap re-trigger, never throw
        // an uncaught ReferenceError into the page (which can tear down the
        // content process under aggressive simulator builds).
        let html = """
        <!DOCTYPE html>
        <html>
        <head><meta charset="utf-8"></head>
        <body>
        <script src="\(src)"></script>
        <script>
        (function() {
          try {
            var boot = window.__forgeBootstrap;
            if (typeof boot === 'function') {
              var p = boot();
              if (p && typeof p.catch === 'function') {
                p.catch(function(err) {
                  try {
                    window.__forgeNative && window.__forgeNative.error &&
                      window.__forgeNative.error(String(err && err.message || err));
                  } catch (e) {}
                });
              }
            } else if (window.__forgeNative) {
              // Bundle may only honor autoBootstrap; flip and re-signal.
              window.__forgeNative.autoBootstrap = true;
              try {
                window.__forgeNative.error &&
                  window.__forgeNative.error(
                    'forge-bundle loaded but window.__forgeBootstrap missing (phase1-stub path)'
                  );
              } catch (e) {}
              // Soft ready so Mode1 UI is not stuck if bootstrap export is absent.
              try { window.__forgeNative.ready && window.__forgeNative.ready(); } catch (e2) {}
            }
          } catch (e) {
            try {
              window.__forgeNative && window.__forgeNative.error &&
                window.__forgeNative.error(String(e && e.message || e));
            } catch (e3) {}
          }
        })();
        </script>
        </body>
        </html>
        """

        DispatchQueue.main.async { [weak self] in
            self?.webView?.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
        }
    }

    // MARK: - API credentials (§12.1)

    /// Injects LLM provider credentials from Keychain into the JS context so
    /// the bundle can use them without an extra bridge round-trip.
    func injectAPICredentials() {
        // Read from the SAME keys that SettingsSheet/AppState use (fixes keychain mismatch bug)
        let defaults = UserDefaults.standard
        let provider = defaults.string(forKey: ForgeSettingsKeys.apiProvider) ?? "OpenAI"
        // zen free tier works with the "public" sentinel key — zero setup
        let storedKey = KeychainHelper.loadSync(for: ForgeSettingsKeys.apiKey) ?? ""
        let apiKey = storedKey.isEmpty ? "public" : storedKey
        let storedModel = defaults.string(forKey: ForgeSettingsKeys.modelName) ?? ZenModelCatalog.defaultModelID
        let model = ZenModelCatalog.isRetired(storedModel)
            ? ZenModelCatalog.defaultModelID
            : storedModel
        // Default base URL = opencode Zen (free models via opencode.ai/auth).
        // "OpenAI" provider → OpenAI-compatible zen endpoint.
        let defaultBaseUrl = "https://opencode.ai/zen/v1"

        // Environment overrides (simulator/CI testing only — no effect in production)
        let env = ProcessInfo.processInfo.environment
        let envProvider = env["FORGE_API_PROVIDER"]
        let envApiKey = env["FORGE_API_KEY"]
        let envModel = env["FORGE_API_MODEL"]
        let envBaseUrl = env["FORGE_API_BASE_URL"]

        // Precedence: launch env (sim/CI) > user-saved Settings value > default.
        let savedBaseUrl = defaults.string(forKey: ForgeSettingsKeys.apiBaseUrl)
        let baseUrl = envBaseUrl ?? savedBaseUrl ?? defaultBaseUrl

        // Escape any quote characters in values.
        func esc(_ s: String) -> String {
            return s.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
        }

        // Normalize the provider to the bundle's lowercase contract:
        // "Anthropic" → "anthropic", "OpenAI" → "openai", others lowercased.
        func normalizeProvider(_ raw: String) -> String {
            switch raw.lowercased() {
            case "anthropic": return "anthropic"
            case "openai", "zen", "opencode zen": return "openai"
            default: return raw.lowercased()
            }
        }

        let identity = ZenClientIdentity.headers()
        let js = """
        window.__forgeConfig = {
            provider: '\(esc(normalizeProvider(envProvider ?? provider)))',
            apiKey: '\(esc(envApiKey ?? apiKey))',
            model: '\(esc(envModel ?? model))',
            baseUrl: '\(esc(envBaseUrl ?? baseUrl))',
            sessionID: '\(esc(identity["x-opencode-session"] ?? ZenClientIdentity.sessionID))',
            projectID: '\(esc(identity["x-opencode-project"] ?? ZenClientIdentity.projectID))',
            requestID: '\(esc(identity["x-opencode-request"] ?? ZenClientIdentity.nextRequestID()))',
            client: '\(esc(ZenClientIdentity.client))',
            userAgent: '\(esc(ZenClientIdentity.userAgent))'
        };
        """
        evalJS(js)
        Task { await ZenModelCatalog.shared.refresh() }
    }


    // MARK: - Input forwarding (§8.2)

    /// Sends keyboard input (already JS-escaped) from SwiftTerm into the JS
    /// engine via the `window.__forgeInput` callback.
    func sendInput(_ escapedInput: String) {
        if !escapedInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lastUserInput = escapedInput
        }
        let js = "window.__forgeInput && window.__forgeInput('\(escapedInput)');"
        evalJS(js)
    }

    /// Sends a resize event to the JS engine so OpenTUI can re-layout.
    func sendResize(cols: Int, rows: Int) {
        let safeCols = max(1, cols)
        let safeRows = max(1, rows)
        let js = """
        window.__forgeCols=\(safeCols);window.__forgeRows=\(safeRows);
        if(window.__forgeResizeCallback){window.__forgeResizeCallback(\(safeCols),\(safeRows));}
        """
        evalJS(js)
    }

    // MARK: - Lifecycle (§25)

    /// Signals the JS engine to pause the God Loop when the app backgrounds.
    func pause() {
        evalJS("window.__forgePause && window.__forgePause();")
    }

    /// Resumes the God Loop when the app returns to the foreground.
    func resume() {
        evalJS("window.__forgeResume && window.__forgeResume();")
    }

    // MARK: - Preview pane (isolated WKWebView — NEVER the agent process pool)

    /// WAVE 2 / PreviewPaneView attaches the visible isolated web view.
    /// Do not assign `webView.configuration.processPool` onto this view.
    func attachPreviewWebView(_ webView: WKWebView) {
        previewBridge.attachPreviewWebView(webView)
    }

    /// Agent `renderPreview` (and the public API) opens the PREVIEW tab.
    func showPreview() {
        NotificationCenter.default.post(
            name: .forgeShowPreviewTab,
            object: nil,
            userInfo: ["open": true]
        )
    }

    func hidePreview() {
        NotificationCenter.default.post(
            name: .forgeShowPreviewTab,
            object: nil,
            userInfo: ["open": false]
        )
    }

    func reloadPreview() {
        previewBridge.reloadPreview()
    }

    func loadPreviewBlank() {
        previewBridge.loadPreviewBlank()
    }

    func copyPreviewPathToClipboard() {
        previewBridge.copyPreviewPathToClipboard()
    }

    /// No-LLM simctl hook: write a jailed `index.html` under the demo project
    /// and call the shipped `PreviewBridge.renderPreview` path (not a second loader).
    /// No-LLM Mode 1 turn: write `hello.py` via `writeFile`, run it with
    /// shipped `runPython` (Pyodide), write `index.html` from the result,
    /// then `renderPreview`. Callback ids `forge-e2e-*` are intercepted in
    /// `resolveCallback` / `rejectCallback`.
    func runMode1WriteRunPreviewFixture() {
        _ = bridge.ensureDemoProjectRoot()
        let py = """
        print("PYODIDE_HELLO")
        x = 6 * 7
        print("ANSWER", x)
        x
        """
        bridge.writeFile(
            ["path": "hello.py", "content": py],
            callbackId: "forge-e2e-write-py"
        )
    }

    fileprivate func e2eWriteCompleted(_ callbackId: String) {
        if callbackId == "forge-e2e-write-py" {
            let py = """
            print("PYODIDE_HELLO")
            x = 6 * 7
            print("ANSWER", x)
            x
            """
            // runPython only — Preview HTML is rewritten when JS posts
            // __pythonResult / __pythonError for callbackId forge-e2e-python.
            handleANSIOutput("\u{001b}[2m[e2e] python hello.py\u{001b}[0m\r\n")
            bridge.runPython(["code": py], callbackId: "forge-e2e-python")
            return
        }
        if callbackId == "forge-e2e-write-html" {
            previewBridge.renderPreview(
                ["path": "index.html", "mode": "html"],
                callbackId: nil,
                webView: nil
            )
        }
    }

    fileprivate func e2ePythonFinished(result: String?, error: String?) {
        let body: String
        if let error, result == nil {
            body = "<p>PYTHON ERROR</p><pre>\(Self.e2eEscape(error))</pre>"
        } else {
            let shown = Self.e2eEscape(result ?? "")
            body = """
            <h1>FORGE PREVIEW</h1>
            <p>hello.py via writeFile + runPython</p>
            <p class="ans">ANSWER \(shown)</p>
            <canvas id="c" width="240" height="72"></canvas>
            <script>
            var c=document.getElementById('c').getContext('2d');
            c.fillStyle='#22c55e'; c.fillRect(0,0,240,72);
            c.fillStyle='#111'; c.font='bold 22px sans-serif';
            c.fillText('CANVAS OK', 52, 46);
            </script>
            """
        }
        let html = """
        <!DOCTYPE html><html><head>
        <meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <title>FORGE Mode1 E2E</title>
        <style>
        html,body{margin:0;background:#0b0b0b;color:#f97316;font-family:-apple-system,sans-serif}
        .mark{margin:40px 20px;padding:24px;border:3px solid #f97316;border-radius:16px}
        h1{font-size:28px;letter-spacing:0.12em;margin:0 0 8px}
        p{color:#f5f5f4;font-size:16px;margin:8px 0}
        .ok,.ans{color:#22c55e;font-weight:700}
        </style></head><body><div class="mark">\(body)</div></body></html>
        """
        bridge.writeFile(
            ["path": "index.html", "content": html],
            callbackId: "forge-e2e-write-html"
        )
    }

    private static func e2eEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    func renderJailedPreviewFixture() {
        let root = bridge.ensureDemoProjectRoot()
        let html = """
        <!DOCTYPE html>
        <html><head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <title>FORGE Preview Hook</title>
        <style>
        html,body{margin:0;background:#0b0b0b;color:#f97316;
          font-family:-apple-system,sans-serif;min-height:100%}
        .mark{margin:48px 24px;padding:28px;border:3px solid #f97316;border-radius:16px}
        h1{font-size:32px;letter-spacing:0.14em;margin:0 0 12px}
        p{color:#f5f5f4;font-size:18px;margin:0 0 16px}
        </style></head>
        <body>
        <div class="mark">
          <h1>FORGE PREVIEW</h1>
          <p>jailed index.html via renderPreview</p>
          <canvas id="c" width="240" height="72"></canvas>
        </div>
        <script>
        var c=document.getElementById('c').getContext('2d');
        c.fillStyle='#22c55e'; c.fillRect(0,0,240,72);
        c.fillStyle='#111'; c.font='bold 22px sans-serif';
        c.fillText('CANVAS OK', 52, 46);
        </script>
        </body></html>
        """
        let filePath = (root as NSString).appendingPathComponent("index.html")
        do {
            try html.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            errorHandler?("renderJailedPreviewFixture: \(error.localizedDescription)")
            return
        }
        previewBridge.renderPreview(
            ["path": "index.html", "mode": "html"],
            callbackId: nil,
            webView: nil
        )
    }

    /// Dim `[preview]` line into SwiftTerm so the agent can see console output.
    func feedPreviewConsoleToTerminal(_ message: String) {
        handleANSIOutput("\u{001b}[2m[preview] \(message)\u{001b}[0m\r\n")
    }

    // MARK: - Memory pressure (§3.5, §25.3)

    /// Hints the JS engine to garbage-collect under memory pressure.
    func didReceiveMemoryWarning() {
        evalJS("if (window.gc) { window.gc(); }")
    }

    // MARK: - Teardown

    /// Removes the message handler reference to break the retain cycle that
    /// WKUserContentController creates (it retains its script message handler).
    func teardown() {
        webView?.stopLoading()
        webView?.configuration.userContentController.removeScriptMessageHandler(
            forName: "native"
        )
        webView?.navigationDelegate = nil
        webView = nil
        outputTimer?.cancel()
        outputTimer = nil
        outputBuffer = ""
        readyFired = false
        isInitialized = false
    }

    deinit {
        // Avoid calling teardown() which touches main-thread UI from deinit
        // in edge cases — mirror essential cleanup.
        if let wv = webView {
            wv.configuration.userContentController.removeScriptMessageHandler(
                forName: "native"
            )
            wv.stopLoading()
        }
        outputTimer?.cancel()
    }

    // MARK: - WKNavigationDelegate

    func webView(
        _ webView: WKWebView,
        didFinish navigation: WKNavigation!
    ) {
        // Suppress any rendered web content — we only want JS execution.
        webView.evaluateJavaScript(
            "document.documentElement.style.display = 'none';",
            completionHandler: nil
        )
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.errorHandler?("Bundle load failed: \(error.localizedDescription)")
        }
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.errorHandler?("Bundle load failed: \(error.localizedDescription)")
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        // Soft-fail: content process died (memory, bad JS). Do not crash host.
        // CRITICAL: after termination, evaluateJavaScript on the stale webView
        // can SIGSEGV the host process. Immediately reload the bundle so the
        // content process respawns and JS calls land on a live process.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.readyFired = false
            // Try to respawn the content process by reloading the same bundle.
            // Guard: only reload if we still own the webView.
            if self.webView === webView {
                self.webView?.stopLoading()
                self.loadBundle()
            }
            self.errorHandler?(
                "JS content process terminated — engine reloaded (retry prompt if needed)"
            )
        }
    }

    // MARK: - WKScriptMessageHandler (§3.3)

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any],
              let method = body["method"] as? String else {
            return
        }

        let args = body["args"] as? [String: Any] ?? [:]
        let callbackId = body["callbackId"] as? String

        switch method {
        case "__output":
            if let ansi = args["ansi"] as? String {
                handleANSIOutput(ansi)
            }

        case "__ready":
            handleReady()

        case "__error":
            let msg = (args["message"] as? String) ?? "Unknown JS error"
            DispatchQueue.main.async { [weak self] in
                // Soft: show in terminal via output if possible; do not kill UI.
                self?.handleANSIOutput(
                    "\u{001b}[33m[FORGE] JS: \(msg)\u{001b}[0m\r\n"
                )
            }

        case "__pythonResult":
            let result = (args["result"] as? String) ?? ""
            let stdout = (args["stdout"] as? String) ?? ""
            // t7 double-dump: batched() already streamed each chunk via __output.
            // t7 double-dump: batched() already streamed each chunk via __output.
            // Skip a second ANSI dump of stdout here (it glued ANSWER 42DONE + reprint).
            // print() returns JS undefined / Py None — that is not stdout.
            let delivered: String
            if result.isEmpty || result == "undefined" || result == "None" {
                delivered = stdout
            } else {
                delivered = result
            }
            if let cbId = callbackId { resolveCallback(cbId, result: delivered) }

        case "__pythonError":
            let msg = (args["message"] as? String) ?? "python error"
            if let cbId = callbackId { rejectCallback(cbId, error: msg) }

        // File operations
        case "readFile":   bridge.readFile(args, callbackId: callbackId)
        case "writeFile":  bridge.writeFile(args, callbackId: callbackId)
        case "listFiles":  bridge.listFiles(args, callbackId: callbackId)
        case "deleteFile": bridge.deleteFile(args, callbackId: callbackId)
        case "searchFiles": bridge.searchFiles(args, callbackId: callbackId)

        // Command execution
        case "runCommand": bridge.runCommand(args, callbackId: callbackId)

        // Git
        case "gitOperation": bridge.gitOperation(args, callbackId: callbackId)

        // Networking
        case "httpRequest": bridge.httpRequest(args, callbackId: callbackId)
         case "httpRequestStream": bridge.httpRequestStream(args, callbackId: callbackId)

        // Secrets
        case "getSecret": bridge.getSecret(args, callbackId: callbackId)
        case "setSecret": bridge.setSecret(args, callbackId: callbackId)
        case "promptSecret": bridge.promptSecret(args, callbackId: callbackId)
        case "saveProviderConfig": bridge.saveProviderConfig(args, callbackId: callbackId)

        // Sharing
        case "shareFile": bridge.shareFile(args, callbackId: callbackId)

        // Python
        case "runPython": bridge.runPython(args, callbackId: callbackId)

        // Resource reads used by phase1-stub config load
        case "getResource":
            if let cbId = callbackId {
                let name = (args["name"] as? String)
                    ?? (args["path"] as? String)
                    ?? ""
                // Soft stub: return empty string so bootstrap continues.
                // Real file read can be layered later without breaking ready.
                if name.hasSuffix("forge-config.json")
                    || name == "forge-config.json" {
                    if let url = Bundle.main.url(
                        forResource: "forge-config", withExtension: "json"
                    ),
                       let data = try? String(contentsOf: url, encoding: .utf8) {
                        resolveCallback(cbId, result: data)
                    } else {
                        resolveCallback(cbId, result: "{}")
                    }
                } else {
                    resolveCallback(cbId, result: "")
                }
            }

        case "getBatteryLevel":
            if let cbId = callbackId {
                resolveCallback(cbId, result: 1.0)
            }

        // Token accounting (spec §15.2) — fired by the bundle after every LLM
        // response. Fire-and-forget: we resolve the JS callback immediately so
        // the bundle's `native.call(...).catch(...)` doesn't dangle, then post
        // a notification for BuildOnDeviceScreen to accumulate into SessionStore.
        case "reportTokens":
            let input = args["input"] as? Int ?? 0
            let output = args["output"] as? Int ?? 0
            let reasoning = args["reasoning"] as? Int ?? 0
            let cacheRead = args["cacheRead"] as? Int ?? 0
            let cacheWrite = args["cacheWrite"] as? Int ?? 0
            let cost = args["cost"] as? Double ?? 0.0
            if let cbId = callbackId { resolveCallback(cbId, result: true) }
            NotificationCenter.default.post(
                name: .forgeTokensReported,
                object: nil,
                userInfo: [
                    "input": input, "output": output, "reasoning": reasoning,
                    "cacheRead": cacheRead, "cacheWrite": cacheWrite, "cost": cost
                ]
            )

        // Structured chat event from the bundle (spec §15.2). Forwarded in
        // FULL to the UI layer's LaneRouter → ChatStore, which MERGES
        // streaming deltas into existing parts (never one event per delta)
        // and routes file content only to attachWrite/attachDiff (AP4 guard).
        // Kinds: user / reasoning / assistant / phase / tool / write /
        // status. The `write` kind carries path/content/bytes; `phase`
        // carries text — both flow through here verbatim.
        case "session:chat":
            let chatKind = args["kind"] as? String ?? ""
            let chatText = args["text"] as? String ?? ""
            if chatKind == "status", chatText.lowercased().contains("done") {
                retryBudget = 2
            }
            if chatKind == "assistant", chatText.contains("returned an empty response") {
                if retryBudget > 0 {
                    retryBudget -= 1
                    let attempt = 2 - retryBudget
                    let model = UserDefaults.standard.string(forKey: ForgeSettingsKeys.modelName) ?? ZenModelCatalog.defaultModelID
                    let phaseText = "■ retrying (\(attempt)/2) · \(model)"
                    NotificationCenter.default.post(
                        name: .forgeChatMessage, object: nil,
                        userInfo: ["kind": "phase", "text": phaseText]
                    )
                    let toRetry = lastUserInput
                    if !toRetry.isEmpty {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                            guard let self = self, !self.lastUserInput.isEmpty else { return }
                            self.sendInput(toRetry)
                        }
                    }
                    if let cbId = callbackId { resolveCallback(cbId, result: true) }
                    break
                } else {
                    retryBudget = 2
                    if let cbId = callbackId { resolveCallback(cbId, result: true) }
                    NotificationCenter.default.post(
                        name: .forgeChatMessage, object: nil,
                        userInfo: ["kind": "error", "text": chatText]
                    )
                    break
                }
            }
            if let cbId = callbackId { resolveCallback(cbId, result: true) }
            var userInfo: [AnyHashable: Any] = ["kind": chatKind]
            for (k, v) in args where k != "kind" { userInfo[k] = v }
            NotificationCenter.default.post(
                name: .forgeChatMessage, object: nil, userInfo: userInfo
            )
        case "session:header":
            let title = args["title"] as? String ?? "FORGE-Demo"
            let model = args["model"] as? String ?? ZenModelCatalog.defaultModelID
            if let cbId = callbackId { resolveCallback(cbId, result: true) }
            NotificationCenter.default.post(
                name: .forgeSessionHeader,
                object: nil,
                userInfo: ["title": title, "model": model]
            )

        // Preview Pane (FORGE-PREVIEW-SPEC-V1.0 §4). Isolated WKWebView —
        // NEVER share the hidden agent WKProcessPool with these handlers.
        case "renderPreview":
            _ = previewBridge.handleMethod(
                "renderPreview", args: args, callbackId: callbackId, webView: webView
            )
        case "injectPreviewCode":
            _ = previewBridge.handleMethod(
                "injectPreviewCode", args: args, callbackId: callbackId, webView: webView
            )
        case "setPreviewTitle":
            _ = previewBridge.handleMethod(
                "setPreviewTitle", args: args, callbackId: callbackId, webView: webView
            )
        case "previewConsole":
            _ = previewBridge.handleMethod(
                "previewConsole", args: args, callbackId: callbackId, webView: webView
            )
        case "previewError":
            _ = previewBridge.handleMethod(
                "previewError", args: args, callbackId: callbackId, webView: webView
            )

        default:
            if let cbId = callbackId {
                rejectCallback(cbId, error: "Unknown method: \(method)")
            }
        }
    }

    // MARK: - Output batching (§8.4)

    /// Buffers ANSI output for 16 ms (one frame) then flushes the accumulated
    /// batch to the output handler. This prevents flooding SwiftTerm with
    /// thousands of tiny `feed` calls during a large render.
    private func handleANSIOutput(_ ansi: String) {
        outputQueue.async { [weak self] in
            guard let self = self else { return }
            self.outputBuffer += ansi
            if self.outputTimer == nil {
                let timer = DispatchSource.makeTimerSource(queue: .main)
                timer.schedule(deadline: .now() + .milliseconds(16))
                timer.setEventHandler { [weak self] in
                    guard let self = self else { return }
                    self.outputQueue.async {
                        let batch = self.outputBuffer
                        self.outputBuffer = ""
                        self.outputTimer = nil
                        if !batch.isEmpty {
                            DispatchQueue.main.async {
                                self.outputHandler?(batch)
                            }
                        }
                    }
                }
                timer.resume()
                self.outputTimer = timer
            }
        }
    }

    // MARK: - Ready handling

    private func handleReady() {
        guard !readyFired else { return }
        readyFired = true
        injectAPICredentials()
        DispatchQueue.main.async { [weak self] in
            self?.readyHandler?()
        }
    }

    // MARK: - Callback resolution (§3.4)

    /// Evaluates JavaScript on the main thread, logging any error in DEBUG
    /// builds instead of silently dropping it. All fire-and-forget JS calls
    /// should route through this to ensure errors are visible during
    /// development.
    func evalJS(_ js: String) {
        guard let webView = webView else { return }
        let run = {
            webView.evaluateJavaScript(js) { _, error in
                #if DEBUG
                if let error = error {
                    print("[ForgeEngine] JS eval error: \(error.localizedDescription)")
                    print("[ForgeEngine] JS was: \(js.prefix(200))")
                }
                #endif
            }
        }
        if Thread.isMainThread {
            run()
        } else {
            DispatchQueue.main.async(execute: run)
        }
    }

    /// Resolves a pending JavaScript callback with `result`.
    ///
    /// The result is JSON-serialized when it is a JSON-compatible object,
    /// quoted when it is a plain string, and `null` otherwise.
    func resolveCallback(_ callbackId: String, result: Any) {
        let json = serializeForJS(result)
        let escapedId = callbackId
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let js = "window.__forgeNative && window.__forgeNative.resolve('\(escapedId)', \(json));"
        DispatchQueue.main.async { [weak self] in
            self?.evalJS(js)
            if callbackId == "forge-e2e-write-py" || callbackId == "forge-e2e-write-html" {
                self?.e2eWriteCompleted(callbackId)
            }
            if callbackId == "forge-e2e-python" {
                self?.e2ePythonFinished(result: String(describing: result), error: nil)
            }
        }
    }

    /// Rejects a pending JavaScript callback with an error message.
    func rejectCallback(_ callbackId: String, error: String) {
        let escapedId = callbackId
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let escaped = error.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
        let js = "window.__forgeNative && window.__forgeNative.reject('\(escapedId)', '\(escaped)');"
        DispatchQueue.main.async { [weak self] in
            if callbackId.hasPrefix("forge-e2e") {
                self?.e2ePythonFinished(result: nil, error: error)
            }
            self?.evalJS(js)
        }
    }

    /// Serializes a Swift value into a JS literal suitable for embedding in an
    /// `evaluateJavaScript` string.
    private func serializeForJS(_ value: Any) -> String {
        // Booleans
        if let b = value as? Bool {
            return b ? "true" : "false"
        }
        // Integers / floating point
        if let n = value as? Int { return String(n) }
        if let n = value as? Int32 { return String(n) }
        if let n = value as? Int64 { return String(n) }
        if let n = value as? UInt { return String(n) }
        if let n = value as? Double { return String(n) }
        if let n = value as? Float { return String(n) }

        // String: JSON-encode for safe embedding (handles quotes,
        // backslashes, newlines, unicode). NSString bridges correctly with
        // .fragmentsAllowed to produce a quoted JSON string.
        if let s = value as? String {
            return jsonQuoteString(s)
        }

        // Arrays / dictionaries — JSON serialize directly.
        if JSONSerialization.isValidJSONObject(value) {
            if let data = try? JSONSerialization.data(withJSONObject: value),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
        }
        return "null"
    }

    /// Produces a JSON-quoted, escaped string literal suitable for embedding
    /// inside `evaluateJavaScript`.
    private func jsonQuoteString(_ s: String) -> String {
        // JSONSerialization with a bare NSString and .fragmentsAllowed
        // produces a properly escaped JSON string like "hello\nworld".
        if let data = try? JSONSerialization.data(
            withJSONObject: s as NSString,
            options: [.fragmentsAllowed]
        ), let result = String(data: data, encoding: .utf8) {
            return result
        }
        // Manual fallback: escape the critical characters.
        var escaped = s
        escaped = escaped.replacingOccurrences(of: "\\", with: "\\\\")
        escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
        escaped = escaped.replacingOccurrences(of: "\n", with: "\\n")
        escaped = escaped.replacingOccurrences(of: "\r", with: "\\r")
        escaped = escaped.replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }

    // MARK: - Static helpers (used by ForgeBridge)

    /// Resolves a callback on the given engine. Provided as a convenience for
    /// bridge methods that only have a weak engine reference.
    static func resolve(_ engine: ForgeEngine?, _ callbackId: String, _ result: Any) {
        engine?.resolveCallback(callbackId, result: result)
    }

    /// Rejects a callback on the given engine.
    static func reject(_ engine: ForgeEngine?, _ callbackId: String, _ error: String) {
        engine?.rejectCallback(callbackId, error: error)
    }
}

// MARK: - WeakScriptMessageHandler

/// A weak proxy that breaks the retain cycle between ForgeEngine and
/// WKUserContentController.
///
/// `WKUserContentController.add(_:name:)` retains its message handler. If we
/// pass the ForgeEngine directly, the controller retains it:
///   engine → webView → configuration → userContentController → engine
///
/// This cycle prevents the engine from ever being deallocated. The proxy is
/// retained by the controller but holds only a weak reference to the engine,
/// so the cycle is broken. When the engine is deallocated, the proxy's target
/// becomes nil and message forwarding silently no-ops.
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?

    init(proxyTarget: WKScriptMessageHandler) {
        self.target = proxyTarget
        super.init()
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        target?.userContentController(userContentController, didReceive: message)
    }
}

// MARK: - Notification names (spec §15.2)

extension Notification.Name {
    /// Fired by `reportTokens` bridge messages. `userInfo` carries Int keys
    /// `input`, `output`, `reasoning`, `cacheRead`, `cacheWrite` and a Double `cost`.
    static let forgeTokensReported = Notification.Name("forgeTokensReported")

    /// Fired by `session:header` bridge messages. `userInfo` carries the
    /// String keys `title` and `model`.
    static let forgeSessionHeader = Notification.Name("forgeSessionHeader")
    static let forgeChatMessage = Notification.Name("forgeChatMessage")
    /// N7/E2E: open or close the playable-output preview sheet.
    /// userInfo["open"] = Bool (default true).
    static let forgeOpenPreview = Notification.Name("forgeOpenPreview")
    /// Fired when LaneRouter sees a "done N file(s)" status — the Mode-1
    /// turn actually finished (not a timer guess).
    static let forgeTurnComplete = Notification.Name("forgeTurnComplete")
    /// WAVE 2: open (`open: true`) or hide the Mode 1 PREVIEW tab.
    static let forgeShowPreviewTab = Notification.Name("forgeShowPreviewTab")
}
