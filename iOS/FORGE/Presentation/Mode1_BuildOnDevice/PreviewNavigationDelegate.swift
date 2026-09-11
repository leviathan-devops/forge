import Foundation
import WebKit

/// PreviewNavigationDelegate
///
/// Per FORGE-PREVIEW-SPEC-V1.0 §3.4 / AP3.
///
/// WKNavigationDelegate + WKScriptMessageHandler for the Preview pane.
/// Sandbox: allow `file://`, `about:`, `data:` — block every other navigation
/// (no CDN, no http(s), no unexpected scheme). Console/error messages from
/// `preview-bootstrap.js` are forwarded on the main queue.
final class PreviewNavigationDelegate: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    var onConsoleMessage: ((ConsoleEntry) -> Void)?
    var onPreviewError: ((PreviewError) -> Void)?

    init(
        onConsoleMessage: ((ConsoleEntry) -> Void)? = nil,
        onPreviewError: ((PreviewError) -> Void)? = nil
    ) {
        self.onConsoleMessage = onConsoleMessage
        self.onPreviewError = onPreviewError
        super.init()
    }

    // MARK: - WKNavigationDelegate (sandbox)

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if isAllowedPreviewNavigation(url) {
            decisionHandler(.allow)
            return
        }
        // BLOCK unexpected nav. No external navigation (AP3).
        decisionHandler(.cancel)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        guard let url = navigationResponse.response.url, isAllowedPreviewNavigation(url) else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        emitPreviewError(error)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        emitPreviewError(error)
    }

    /// `file://` (sandbox content), `about:` (blank/injected), `data:` (SVG).
    func isAllowedPreviewNavigation(_ url: URL) -> Bool {
        if url.isFileURL { return true }
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "about" || scheme == "data"
    }

    private func emitPreviewError(_ error: Error) {
        let err = PreviewError(
            message: error.localizedDescription,
            source: nil,
            line: nil,
            stack: nil
        )
        DispatchQueue.main.async { [weak self] in
            self?.onPreviewError?(err)
        }
    }

    // MARK: - WKScriptMessageHandler (console + error capture)

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any] else { return }
        switch message.name {
        case "previewConsole":
            let entry = ConsoleEntry(
                timestamp: Date(),
                level: ConsoleLevel(rawValue: body["level"] as? String ?? "log") ?? .log,
                message: body["message"] as? String ?? "",
                source: body["source"] as? String,
                line: body["line"] as? Int
            )
            DispatchQueue.main.async { [weak self] in
                self?.onConsoleMessage?(entry)
            }
        case "previewError":
            let err = PreviewError(
                message: body["message"] as? String ?? "Unknown error",
                source: body["source"] as? String,
                line: body["line"] as? Int,
                stack: body["stack"] as? String
            )
            DispatchQueue.main.async { [weak self] in
                self?.onPreviewError?(err)
            }
        default:
            break
        }
    }
}
