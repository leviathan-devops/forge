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
final class ForgeEngine: NSObject, WKScriptMessageHandler, WKNavigationDelegate {

    // MARK: - Properties

    /// The hidden web view used purely as a JS sandbox.
    private(set) var webView: WKWebView!

    /// The bridge that handles every native method call.
    private let bridge: ForgeBridge

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

    // MARK: - Output batching (§8.4)

    /// Accumulates ANSI output for one frame (16 ms) before flushing to
    /// SwiftTerm, coalescing many small writes into a single `feed` call.
    private var outputBuffer = ""
    private var outputTimer: DispatchSourceTimer?
    private let outputQueue = DispatchQueue(label: "forge.output", qos: .userInitiated)

    // MARK: - Init

    init(bridge: ForgeBridge) {
        self.bridge = bridge
        super.init()

        let config = WKWebViewConfiguration()

        // Enable JavaScript and WASM execution.
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        // Allow local file access so bundled resources (forge-bundle.js,
        // WASM binaries, Pyodide) can be loaded via file:// URLs.
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.preferences.setValue(true, forKey: "allowUniversalAccessFromFileURLs")

        // Use a non-persistent data store: opencode manages its own storage
        // (SQL.js WASM) and we do not want web-cache accumulation (§3.5).
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()

        // Register the message handler that JS calls via
        // `window.webkit.messageHandlers.native.postMessage(...)`.
        config.userContentController.add(self, name: "native")

        // Inject the native API script at document start, before any bundle
        // code runs.
        injectNativeAPI(config.userContentController)

        // Create the WebView with a zero frame — it is never visible.
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self

        // Disable all user interaction; this view is invisible.
        webView.isUserInteractionEnabled = false
        webView.scrollView.isScrollEnabled = false
        webView.allowsBackForwardNavigationGestures = false

        // Wire the bridge back to this engine so it can resolve/reject.
        bridge.engine = self

        // Suppress any rendered web content — we only want JS execution.
        webView.evaluateJavaScript(
            "document.documentElement.style.display = 'none'",
            completionHandler: nil
        )
    }

    // MARK: - Native API injection (§3.2)

    /// Injects `window.__forgeNative` with call/resolve/reject/output/ready and
    /// `window.__forgeInput` as a WKUserScript at document start.
    private func injectNativeAPI(_ controller: WKUserContentController) {
        let nativeAPIScript = """
        (function() {
            var callbackId = 0;
            var pendingCallbacks = {};

            window.__forgeNative = {
                call: function(method, args) {
                    return new Promise(function(resolve, reject) {
                        var id = 'cb_' + (++callbackId);
                        pendingCallbacks[id] = { resolve: resolve, reject: reject };
                        window.webkit.messageHandlers.native.postMessage({
                            method: method,
                            args: args,
                            callbackId: id
                        });
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
                    window.webkit.messageHandlers.native.postMessage({
                        method: '__output',
                        args: { ansi: ansi }
                    });
                },

                ready: function() {
                    window.webkit.messageHandlers.native.postMessage({
                        method: '__ready',
                        args: {}
                    });
                }
            };

            window.__forgeInput = function(data) {
                if (window.__forgeOnInput) {
                    window.__forgeOnInput(data);
                }
            };
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
    /// web view. The bundle then calls `window.__forgeBootstrap()` which fires
    /// the `__ready` signal.
    func loadBundle() {
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

        let html = """
        <!DOCTYPE html>
        <html>
        <head><meta charset="utf-8"></head>
        <body>
        <script src="\(bundleURL.absoluteString)"></script>
        <script>window.__forgeBootstrap();</script>
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
    }

    // MARK: - API credentials (§12.1)

    /// Injects LLM provider credentials from Keychain into the JS context so
    /// the bundle can use them without an extra bridge round-trip.
    func injectAPICredentials() {
        let provider = KeychainHelper.loadSync(for: "llm_provider") ?? "anthropic"
        let apiKey = KeychainHelper.loadSync(for: "llm_api_key") ?? ""
        let model = KeychainHelper.loadSync(for: "llm_model") ?? "claude-sonnet-4-20250514"
        let baseUrl = KeychainHelper.loadSync(for: "llm_base_url") ?? ""

        // Escape any quote characters in values.
        func esc(_ s: String) -> String {
            return s.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
        }

        let js = """
        window.__forgeConfig = {
            provider: '\(esc(provider))',
            apiKey: '\(esc(apiKey))',
            model: '\(esc(model))',
            baseUrl: '\(esc(baseUrl))'
        };
        """
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - Input forwarding (§8.2)

    /// Sends keyboard input (already JS-escaped) from SwiftTerm into the JS
    /// engine via the `window.__forgeInput` callback.
    func sendInput(_ escapedInput: String) {
        let js = "window.__forgeInput('\(escapedInput)');"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    /// Sends a resize event to the JS engine so OpenTUI can re-layout.
    func sendResize(cols: Int, rows: Int) {
        let js = """
        window.__forgeCols=\(cols);window.__forgeRows=\(rows);
        if(window.__forgeResizeCallback){window.__forgeResizeCallback(\(cols),\(rows));}
        """
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - Lifecycle (§25)

    /// Signals the JS engine to pause the God Loop when the app backgrounds.
    func pause() {
        webView?.evaluateJavaScript(
            "window.__forgePause && window.__forgePause();",
            completionHandler: nil
        )
    }

    /// Resumes the God Loop when the app returns to the foreground.
    func resume() {
        webView?.evaluateJavaScript(
            "window.__forgeResume && window.__forgeResume();",
            completionHandler: nil
        )
    }

    // MARK: - Memory pressure (§3.5, §25.3)

    /// Hints the JS engine to garbage-collect under memory pressure.
    func didReceiveMemoryWarning() {
        webView?.evaluateJavaScript(
            "if (window.gc) { window.gc(); }",
            completionHandler: nil
        )
    }

    // MARK: - Teardown

    /// Removes the message handler reference to break the retain cycle that
    /// WKUserContentController creates (it retains its script message handler).
    func teardown() {
        webView?.configuration.userContentController.removeScriptMessageHandler(
            forName: "native"
        )
        webView?.stopLoading()
        outputTimer?.cancel()
        outputTimer = nil
        outputBuffer = ""
    }

    deinit {
        teardown()
    }

    // MARK: - WKNavigationDelegate

    func webView(
        _ webView: WKWebView,
        didFinish navigation: WKNavigation!
    ) {
        // The bundle's bootstrap runs from the inline script; nothing to do
        // here beyond suppressing the rendered page.
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

        // Secrets
        case "getSecret": bridge.getSecret(args, callbackId: callbackId)
        case "setSecret": bridge.setSecret(args, callbackId: callbackId)

        // Sharing
        case "shareFile": bridge.shareFile(args, callbackId: callbackId)

        // Python
        case "runPython": bridge.runPython(args, callbackId: callbackId)

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
                    self.outputQueue.sync {
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

    /// Resolves a pending JavaScript callback with `result`.
    ///
    /// The result is JSON-serialized when it is a JSON-compatible object,
    /// quoted when it is a plain string, and `null` otherwise.
    func resolveCallback(_ callbackId: String, result: Any) {
        let json = serializeForJS(result)
        let js = "window.__forgeNative.resolve('\(callbackId)', \(json));"
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    /// Rejects a pending JavaScript callback with an error message.
    func rejectCallback(_ callbackId: String, error: String) {
        let escaped = error.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
        let js = "window.__forgeNative.reject('\(callbackId)', '\(escaped)');"
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(js, completionHandler: nil)
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
