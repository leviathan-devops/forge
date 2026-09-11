import SwiftUI
import UIKit
import WebKit

/// Dark host for the Preview pane. Exists without a WKWebView until first load (AP4).
/// Background is `UIColor.forgeBackground` from init so a later attach never flashes white (AP8).
final class PreviewPaneHostView: UIView {
    private(set) var webView: WKWebView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        applyForgeBackground()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        applyForgeBackground()
    }

    private func applyForgeBackground() {
        isOpaque = true
        backgroundColor = .forgeBackground
        // AP8: no white flash while the isolated WKWebView is still uncreated.
    }

    /// Allocates the isolated WKWebView on first call. Subsequent calls return the same instance.
    @discardableResult
    func ensureWebView(
        configuration: WKWebViewConfiguration,
        navigationDelegate: PreviewNavigationDelegate
    ) -> WKWebView {
        if let existing = webView { return existing }

        let wv = WKWebView(frame: bounds, configuration: configuration)
        wv.navigationDelegate = navigationDelegate
        wv.allowsBackForwardNavigationGestures = false
        wv.scrollView.bounces = true
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = UIColor.forgeBackground
        if #available(iOS 15.0, *) {
            wv.underPageBackgroundColor = UIColor.forgeBackground
        }
        wv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        wv.accessibilityIdentifier = "forgePreviewWebView"
        // Container, not leaf (t95): isAccessibilityElement=true hides the
        // web content from the AX tree (and VoiceOver). Web text must surface.
        wv.isAccessibilityElement = false
        addSubview(wv)
        webView = wv
        return wv
    }
}

/// PreviewPaneView
///
/// Per FORGE-PREVIEW-SPEC-V1.0 §3.3 / AP1 / AP2 / AP4 / AP8.
///
/// Visible, interactive WKWebView for agent artifacts (HTML / Canvas / WebGL / SVG).
/// Completely separate from the hidden ForgeEngine agent WebView:
/// - FRESH `WKProcessPool()` — NEVER share the agent's process pool (AP1).
/// - `websiteDataStore = .nonPersistent()` — preview cookies/storage die on teardown (AP2).
/// - Lazy: the isolated WKWebView is uncreated until first load (`isActive` / `ensureWebView`) (AP4).
/// - Dark `forgeBackground` on the host and scroll view — no white flash (AP8).
///
/// WAVE 2 inserts this into `BuildOnDeviceScreen` and sets `isActive = true` on
/// the first `renderPreview`. This file does not touch that screen.
struct PreviewPaneView: UIViewRepresentable {
    @Binding var webView: WKWebView?
    var onConsoleMessage: ((ConsoleEntry) -> Void)?
    var onPreviewError: ((PreviewError) -> Void)?
    /// AP4 — when false the host exists as a dark placeholder and WKWebView stays nil.
    /// WAVE 2 sets true on first `renderPreview` (or user-initiated SPLIT/PREVIEW).
    var isActive: Bool = false

    func makeUIView(context: Context) -> PreviewPaneHostView {
        let host = PreviewPaneHostView(frame: .zero)
        if isActive {
            publishWebView(host.ensureWebView(
                configuration: Self.makeIsolatedConfiguration(handler: context.coordinator),
                navigationDelegate: context.coordinator
            ))
        }
        return host
    }

    func updateUIView(_ host: PreviewPaneHostView, context: Context) {
        context.coordinator.onConsoleMessage = onConsoleMessage
        context.coordinator.onPreviewError = onPreviewError
        guard isActive else { return }
        if let existing = host.webView {
            existing.navigationDelegate = context.coordinator
            if webView !== existing {
                publishWebView(existing)
            }
            return
        }
        let wv = host.ensureWebView(
            configuration: Self.makeIsolatedConfiguration(handler: context.coordinator),
            navigationDelegate: context.coordinator
        )
        if webView !== wv {
            publishWebView(wv)
        }
    }

    func makeCoordinator() -> PreviewNavigationDelegate {
        PreviewNavigationDelegate(
            onConsoleMessage: onConsoleMessage,
            onPreviewError: onPreviewError
        )
    }

    // MARK: - Isolated configuration (never the agent pool)

    /// Isolated preview configuration. Fresh `WKProcessPool`, nonPersistent store,
    /// own `WKUserContentController`. Callers MUST NOT pass the agent's pool or store.
    static func makeIsolatedConfiguration(handler: PreviewNavigationDelegate) -> WKWebViewConfiguration {
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

        // CRITICAL: non-persistent store. Preview sessions leave no trace (AP2).
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()

        // CRITICAL: isolated process pool. Preview JS cannot touch agent JS (AP1).
        // FRESH WKProcessPool — NEVER share the agent's process pool.
        config.processPool = WKProcessPool()

        // Inject console/error capture BEFORE any page script runs (WAVE 1b console desk).
        // Missing bootstrap is non-fatal — chrome must not crash waiting on that file.
        if let bootstrapURL = Bundle.main.url(forResource: "preview-bootstrap", withExtension: "js"),
           let bootstrapSource = try? String(contentsOf: bootstrapURL, encoding: .utf8) {
            let bootstrapScript = WKUserScript(
                source: bootstrapSource,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
            config.userContentController.addUserScript(bootstrapScript)
        }
        config.userContentController.add(handler, name: "previewConsole")
        config.userContentController.add(handler, name: "previewError")

        return config
    }

    private func publishWebView(_ wv: WKWebView) {
        DispatchQueue.main.async { self.webView = wv }
    }
}
