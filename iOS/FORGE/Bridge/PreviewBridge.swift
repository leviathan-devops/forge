import Foundation
import UIKit
import WebKit

/// PreviewBridge
///
/// FORGE-PREVIEW-SPEC-V1.0 §4 — agent-facing Preview Pane API.
///
/// WAVE 2 `ForgeEngine.userContentController(_:didReceive:)` MUST case these
/// method names (no more, no fewer):
///   renderPreview
///   injectPreviewCode
///   setPreviewTitle
///   previewConsole
///   previewError
///
/// Jail: `resolvePreviewPath` mirrors `ForgeBridge.resolveProjectPath`
/// (standardize, then require root-or-descendant). Path traversal (`../`)
/// that escapes the project root is rejected.
/// Load: `renderPreview` loads the jailed file into the Preview WKWebView.
/// Caps: 5MB max; unknown extensions / modes reject as unsupported.
/// Isolation: Preview uses a FRESH `WKProcessPool`. NEVER share the hidden
/// agent WKWebView's process pool (`ForgeEngine.webView.configuration.processPool`).
final class PreviewBridge: NSObject, WKScriptMessageHandler {

    /// Max preview payload. Spec §4.1 / security table.
    static let maxPreviewFileBytes = 5 * 1024 * 1024

    /// Isolated preview process pool. A new `WKProcessPool()` — not the agent's.
    let previewProcessPool = WKProcessPool()

    /// Optional file-jail source. `projectRoot` is read from here when set.
    weak var fileBridge: ForgeBridge?

    /// Set by ForgeEngine so resolve/reject reach the agent WKWebView.
    weak var engine: ForgeEngine?

    /// The visible Preview WKWebView. WAVE 2 / PreviewPaneView attaches this.
    /// Never the hidden agent web view.
    weak var previewWebView: WKWebView?

    /// Strong owner for a lazy-created preview web view (first renderPreview
    /// before the pane attaches). Released when `attachPreviewWebView` runs.
    private var ownedPreviewWebView: WKWebView?

    /// Fallback jail root when `fileBridge` is unset.
    var projectRoot: String = ""

    /// Last successfully rendered relative path (toolbar / Home / Reload).
    private(set) var currentPreviewPath: String?

    /// Last resolved absolute file URL (Open-in-Safari copies this).
    private(set) var currentPreviewFileURL: URL?

    /// Last auto/explicit render mode used for reload.
    private(set) var lastRenderMode: String?

    /// Toolbar path label. `setPreviewTitle` updates this.
    private(set) var previewTitle: String?

    /// Console ring buffer (max 200). WAVE 2 binds this to ConsoleDrawerView.
    private(set) var consoleEntries: [ConsoleEntry] = []

    var onConsoleMessage: ((ConsoleEntry) -> Void)?
    var onPreviewError: ((PreviewError) -> Void)?
    var onTitleChange: ((String) -> Void)?
    var onPreviewReady: ((String) -> Void)?

    override init() {
        super.init()
    }

    convenience init(fileBridge: ForgeBridge?, engine: ForgeEngine? = nil) {
        self.init()
        self.fileBridge = fileBridge
        self.engine = engine
    }

    // MARK: - Engine dispatch (WAVE 2 calls this from the native switch)

    /// Returns true when `method` is one of the five preview methods.
    @discardableResult
    func handleMethod(
        _ method: String,
        args: [String: Any],
        callbackId: String?,
        webView: WKWebView?
    ) -> Bool {
        switch method {
        case "renderPreview":
            renderPreview(args, callbackId: callbackId, webView: webView)
            return true
        case "injectPreviewCode":
            injectPreviewCode(args, callbackId: callbackId, webView: webView)
            return true
        case "setPreviewTitle":
            setPreviewTitle(args, callbackId: callbackId, webView: webView)
            return true
        case "previewConsole":
            previewConsole(args, callbackId: callbackId, webView: webView)
            return true
        case "previewError":
            previewError(args, callbackId: callbackId, webView: webView)
            return true
        default:
            return false
        }
    }

    // MARK: - Isolated preview WKWebView configuration

    /// Configuration for the Preview WKWebView. Fresh process pool, non-persistent
    /// store, bootstrap injected at document start. Do not pass the agent's
    /// `WKWebViewConfiguration` or its `processPool` into here.
    func makeIsolatedPreviewConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        if #available(iOS 14.0, *) {
            let pagePrefs = WKWebpagePreferences()
            pagePrefs.allowsContentJavaScript = true
            config.defaultWebpagePreferences = pagePrefs
        } else {
            config.preferences.javaScriptEnabled = true
        }
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .nonPersistent()
        // CRITICAL: isolated pool. Preview JS cannot touch agent JS.
        config.processPool = previewProcessPool

        if let url = Bundle.main.url(forResource: "preview-bootstrap", withExtension: "js"),
           let source = try? String(contentsOf: url, encoding: .utf8) {
            let script = WKUserScript(
                source: source,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
            config.userContentController.addUserScript(script)
        }
        config.userContentController.add(self, name: "previewConsole")
        config.userContentController.add(self, name: "previewError")
        return config
    }

    /// WAVE 2 / PreviewPaneView attaches the visible web view. Replaces any
    /// lazy-owned instance so there is exactly one preview surface.
    func attachPreviewWebView(_ webView: WKWebView) {
        ownedPreviewWebView = nil
        previewWebView = webView
    }

    // MARK: - Jail (mirrors ForgeBridge.resolveProjectPath)

    /// Resolves a (possibly relative) path against the project root and jails
    /// the result under that root. Empty paths resolve to the root itself.
    /// Absolute paths and relative paths containing `..` are accepted only when
    /// the standardized result remains under the root; otherwise returns `nil`.
    func resolvePreviewPath(_ relativePath: String) -> String? {
        let rootRaw: String
        if let bridgeRoot = fileBridge?.projectRoot, !bridgeRoot.isEmpty {
            rootRaw = bridgeRoot
        } else {
            rootRaw = projectRoot
        }
        guard !rootRaw.isEmpty else {
            return nil
        }
        let root = (rootRaw as NSString).standardizingPath

        let joined: String
        if relativePath.isEmpty {
            joined = root
        } else if (relativePath as NSString).isAbsolutePath {
            joined = (relativePath as NSString).standardizingPath
        } else {
            joined = ((root as NSString)
                .appendingPathComponent(relativePath) as NSString)
                .standardizingPath
        }

        if joined == root {
            return joined
        }
        let prefix = root.hasSuffix("/") ? root : root + "/"
        if joined.hasPrefix(prefix) {
            return joined
        }
        return nil
    }

    // MARK: - 4.1 renderPreview

    func renderPreview(_ args: [String: Any], callbackId: String?, webView: WKWebView?) {
        _ = webView // agent web view — callbacks go through `engine`, not this
        guard let path = args["path"] as? String else {
            if let cbId = callbackId {
                reject(cbId, "renderPreview: missing 'path' argument")
            }
            return
        }
        let mode = args["mode"] as? String ?? "auto"

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            guard let fullPath = self.resolvePreviewPath(path) else {
                self.rejectIfNeeded(
                    callbackId,
                    "renderPreview: path escapes project root: \(path)"
                )
                return
            }

            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir),
                  !isDir.boolValue else {
                self.rejectIfNeeded(callbackId, "renderPreview: file not found: \(path)")
                return
            }

            let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath)
            let size: Int
            if let n = attrs?[.size] as? NSNumber {
                size = n.intValue
            } else if let i = attrs?[.size] as? Int {
                size = i
            } else {
                size = 0
            }
            guard size <= PreviewBridge.maxPreviewFileBytes else {
                self.rejectIfNeeded(
                    callbackId,
                    "renderPreview: file too large (max 5MB): \(path)"
                )
                return
            }

            guard let renderMode = self.detectRenderMode(path: path, mode: mode) else {
                let ext = (path as NSString).pathExtension.lowercased()
                let suffix = ext.isEmpty ? "" : ": .\(ext)"
                self.rejectIfNeeded(
                    callbackId,
                    "renderPreview: unsupported file type\(suffix)"
                )
                return
            }

            let wv = self.ensurePreviewWebView()
            wv.stopLoading()

            let fileURL = URL(fileURLWithPath: fullPath)
            let dirURL = fileURL.deletingLastPathComponent()

            switch renderMode {
            case "html", "svg":
                wv.loadFileURL(fileURL, allowingReadAccessTo: dirURL)
            case "js":
                let content = (try? String(contentsOfFile: fullPath, encoding: .utf8)) ?? ""
                wv.loadHTMLString(self.wrapJSInGameTemplate(content, title: path), baseURL: dirURL)
            case "markdown":
                let content = (try? String(contentsOfFile: fullPath, encoding: .utf8)) ?? ""
                wv.loadHTMLString(self.wrapMarkdown(content, title: path), baseURL: dirURL)
            case "raw":
                let content = (try? String(contentsOfFile: fullPath, encoding: .utf8)) ?? ""
                wv.loadHTMLString(self.wrapRawSource(content, path: path), baseURL: dirURL)
            default:
                self.rejectIfNeeded(callbackId, "renderPreview: unsupported file type")
                return
            }

            self.currentPreviewPath = path
            self.currentPreviewFileURL = fileURL
            self.lastRenderMode = renderMode
            if self.previewTitle == nil {
                self.previewTitle = path
            }
            self.onPreviewReady?(path)
            NotificationCenter.default.post(
                name: .forgePreviewReady,
                object: nil,
                userInfo: ["path": path, "renderMode": renderMode]
            )
            if let cbId = callbackId {
                self.resolve(cbId, ["ok": true, "path": path, "renderMode": renderMode])
            }
        }
    }

    // MARK: - 4.2 injectPreviewCode

    func injectPreviewCode(_ args: [String: Any], callbackId: String?, webView: WKWebView?) {
        _ = webView
        guard let js = args["js"] as? String else {
            if let cbId = callbackId {
                reject(cbId, "injectPreviewCode: missing 'js' argument")
            }
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let wv = self.previewWebView ?? self.ownedPreviewWebView else {
                self.rejectIfNeeded(callbackId, "injectPreviewCode: preview WebView not attached")
                return
            }
            wv.evaluateJavaScript(js) { result, error in
                if let error = error {
                    self.rejectIfNeeded(
                        callbackId,
                        "injectPreviewCode: \(error.localizedDescription)"
                    )
                } else if let cbId = callbackId {
                    var payload: [String: Any] = ["ok": true]
                    if let result, JSONSerialization.isValidJSONObject(["result": result]) {
                        payload["result"] = result
                    } else if let result {
                        payload["result"] = String(describing: result)
                    }
                    self.resolve(cbId, payload)
                }
            }
        }
    }

    // MARK: - 4.3 setPreviewTitle

    func setPreviewTitle(_ args: [String: Any], callbackId: String?, webView: WKWebView?) {
        _ = webView
        guard let title = args["title"] as? String else {
            if let cbId = callbackId {
                reject(cbId, "setPreviewTitle: missing 'title' argument")
            }
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.previewTitle = title
            self.onTitleChange?(title)
            NotificationCenter.default.post(
                name: .forgePreviewTitle,
                object: nil,
                userInfo: ["title": title]
            )
            if let cbId = callbackId {
                self.resolve(cbId, ["ok": true, "title": title])
            }
        }
    }

    // MARK: - 4.4 previewConsole

    func previewConsole(_ args: [String: Any], callbackId: String?, webView: WKWebView?) {
        _ = webView
        let level = ConsoleLevel(rawValue: args["level"] as? String ?? "log") ?? .log
        let message = args["message"] as? String ?? ""
        let source = args["source"] as? String
        let line = Self.intValue(args["line"])
        let entry = ConsoleEntry(
            timestamp: Date(),
            level: level,
            message: message,
            source: source,
            line: line
        )
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.appendConsole(entry)
            if let cbId = callbackId {
                self.resolve(cbId, ["ok": true])
            }
        }
    }

    // MARK: - 4.5 previewError

    func previewError(_ args: [String: Any], callbackId: String?, webView: WKWebView?) {
        _ = webView
        let message = args["message"] as? String ?? "Unknown error"
        let source = args["source"] as? String
        let line = Self.intValue(args["line"])
        let stack = args["stack"] as? String
        let err = PreviewError(message: message, source: source, line: line, stack: stack)
        let entry = ConsoleEntry(
            timestamp: Date(),
            level: .error,
            message: message,
            source: source,
            line: line
        )
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.appendConsole(entry)
            self.onPreviewError?(err)
            NotificationCenter.default.post(
                name: .forgePreviewError,
                object: nil,
                userInfo: [
                    "message": message,
                    "source": source as Any,
                    "line": line as Any,
                    "stack": stack as Any
                ]
            )
            if let cbId = callbackId {
                self.resolve(cbId, ["ok": true])
            }
        }
    }

    // MARK: - WKScriptMessageHandler (bootstrap → previewConsole / previewError)

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        let body = message.body as? [String: Any] ?? [:]
        switch message.name {
        case "previewConsole":
            previewConsole(body, callbackId: nil, webView: message.webView)
        case "previewError":
            previewError(body, callbackId: nil, webView: message.webView)
        default:
            break
        }
    }

    // MARK: - Toolbar helpers (WAVE 2 wires PreviewToolbarView to these)

    func reloadPreview() {
        guard let path = currentPreviewPath else { return }
        var args: [String: Any] = ["path": path]
        if let mode = lastRenderMode {
            args["mode"] = mode
        }
        renderPreview(args, callbackId: nil, webView: nil)
    }

    func loadPreviewBlank() {
        let wv = previewWebView ?? ownedPreviewWebView
        wv?.stopLoading()
        wv?.loadHTMLString("", baseURL: nil)
        currentPreviewPath = nil
        currentPreviewFileURL = nil
        previewTitle = nil
    }

    func copyPreviewPathToClipboard() {
        let value = currentPreviewFileURL?.path ?? currentPreviewPath
        guard let value else { return }
        UIPasteboard.general.string = value
    }

    // MARK: - Render modes (spec §6.1)

    func detectRenderMode(path: String, mode: String) -> String? {
        let allowed: Set<String> = ["html", "js", "svg", "markdown", "raw"]
        if mode != "auto" {
            return allowed.contains(mode) ? mode : nil
        }
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "html", "htm":
            return "html"
        case "js", "mjs":
            return "js"
        case "svg":
            return "svg"
        case "md", "markdown":
            return "markdown"
        case "json", "txt", "css", "ts", "py", "swift", "sh", "yaml", "yml":
            return "raw"
        default:
            return nil
        }
    }

    func wrapJSInGameTemplate(_ jsContent: String, title: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0,
                  maximum-scale=1.0, user-scalable=no">
            <title>\(Self.escapeHTML(title))</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                html, body {
                    width: 100%; height: 100%;
                    overflow: hidden;
                    background: #0A0A0F;
                    touch-action: none;
                }
                canvas {
                    display: block;
                    width: 100vw;
                    height: 100vh;
                }
            </style>
        </head>
        <body>
            <canvas id="forge-canvas"></canvas>
            <script>
                window.canvas = document.getElementById('forge-canvas');
                window.canvas.width = window.innerWidth * window.devicePixelRatio;
                window.canvas.height = window.innerHeight * window.devicePixelRatio;
                window.ctx = window.canvas.getContext('2d');
                window.ctx.scale(window.devicePixelRatio, window.devicePixelRatio);
            </script>
            <script>
        \(jsContent)
            </script>
        </body>
        </html>
        """
    }

    func wrapMarkdown(_ content: String, title: String) -> String {
        let html = lightweightMarkdownToHTML(content)
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(Self.escapeHTML(title))</title>
            <style>
                body {
                    margin: 0; padding: 20px;
                    background: #0A0A0F; color: #E0E0E0;
                    font-family: -apple-system, sans-serif;
                    font-size: 15px; line-height: 1.6;
                }
                h1, h2, h3 { color: #FF6B2C; margin-top: 1.2em; }
                code {
                    background: #1A1A24; padding: 2px 6px;
                    border-radius: 4px; font-size: 13px;
                    font-family: 'SF Mono', monospace;
                }
                pre {
                    background: #1A1A24; padding: 12px;
                    border-radius: 8px; overflow-x: auto;
                    border: 1px solid #2A2A30;
                }
                pre code { background: none; padding: 0; }
                a { color: #00F0FF; }
            </style>
        </head>
        <body>
        \(html)
        </body>
        </html>
        """
    }

    func wrapRawSource(_ content: String, path: String) -> String {
        let escaped = Self.escapeHTML(content)
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(Self.escapeHTML(path))</title>
            <style>
                body { margin: 0; padding: 16px; background: #0A0A0F; }
                .path {
                    color: #888888; font-family: monospace;
                    font-size: 12px; margin-bottom: 12px;
                }
                pre {
                    color: #E0E0E0; font-family: 'SF Mono', monospace;
                    font-size: 12px; line-height: 1.5;
                    white-space: pre-wrap; word-wrap: break-word;
                }
            </style>
        </head>
        <body>
            <div class="path">\(Self.escapeHTML(path)) — source preview (not renderable)</div>
            <pre>\(escaped)</pre>
        </body>
        </html>
        """
    }

    // MARK: - Private

    private func ensurePreviewWebView() -> WKWebView {
        if let wv = previewWebView { return wv }
        if let wv = ownedPreviewWebView {
            previewWebView = wv
            return wv
        }
        let wv = WKWebView(frame: .zero, configuration: makeIsolatedPreviewConfiguration())
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .forgeBackground
        ownedPreviewWebView = wv
        previewWebView = wv
        return wv
    }

    private func appendConsole(_ entry: ConsoleEntry) {
        consoleEntries.append(entry)
        if consoleEntries.count > 200 {
            consoleEntries.removeFirst(consoleEntries.count - 200)
        }
        onConsoleMessage?(entry)
        NotificationCenter.default.post(
            name: .forgePreviewConsole,
            object: nil,
            userInfo: [
                "level": entry.level.rawValue,
                "message": entry.message,
                "source": entry.source as Any,
                "line": entry.line as Any
            ]
        )
    }

    private func lightweightMarkdownToHTML(_ content: String) -> String {
        var escaped = Self.escapeHTML(content)
        escaped = escaped.replacingOccurrences(
            of: "`([^`]+)`",
            with: "<code>$1</code>",
            options: .regularExpression
        )
        escaped = escaped.replacingOccurrences(
            of: "(?m)^### (.+)$",
            with: "<h3>$1</h3>",
            options: .regularExpression
        )
        escaped = escaped.replacingOccurrences(
            of: "(?m)^## (.+)$",
            with: "<h2>$1</h2>",
            options: .regularExpression
        )
        escaped = escaped.replacingOccurrences(
            of: "(?m)^# (.+)$",
            with: "<h1>$1</h1>",
            options: .regularExpression
        )
        escaped = escaped.replacingOccurrences(
            of: "\\*\\*([^*]+)\\*\\*",
            with: "<strong>$1</strong>",
            options: .regularExpression
        )
        escaped = escaped.replacingOccurrences(
            of: "(?m)^- (.+)$",
            with: "<li>$1</li>",
            options: .regularExpression
        )
        escaped = escaped.replacingOccurrences(of: "\n", with: "<br>\n")
        return escaped
    }

    private static func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func intValue(_ raw: Any?) -> Int? {
        if let i = raw as? Int { return i }
        if let n = raw as? NSNumber { return n.intValue }
        if let s = raw as? String { return Int(s) }
        return nil
    }

    private func rejectIfNeeded(_ callbackId: String?, _ error: String) {
        guard let callbackId else { return }
        reject(callbackId, error)
    }

    private func resolve(_ callbackId: String, _ result: Any) {
        engine?.resolveCallback(callbackId, result: result)
    }

    private func reject(_ callbackId: String, _ error: String) {
        engine?.rejectCallback(callbackId, error: error)
    }
}

extension Notification.Name {
    /// Fired after a successful `renderPreview`. userInfo: `path`, `renderMode`.
    static let forgePreviewReady = Notification.Name("forgePreviewReady")
    /// Fired by `setPreviewTitle`. userInfo: `title`.
    static let forgePreviewTitle = Notification.Name("forgePreviewTitle")
    /// Fired for each captured console line. userInfo: level/message/source/line.
    static let forgePreviewConsole = Notification.Name("forgePreviewConsole")
    /// Fired for uncaught preview JS errors.
    static let forgePreviewError = Notification.Name("forgePreviewError")
}
