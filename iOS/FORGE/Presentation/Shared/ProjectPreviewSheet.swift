import SwiftUI
import WebKit

// MARK: - ProjectPreviewSheet (N7 — playable output on device)

/// In-app playable-output surface: a full-screen WKWebView sheet loading
/// the ACTIVE project's HTML (index.html by default) from the jailed
/// project root (`Documents/projects/<name>`).
///
/// This is how on-device agent output — games, dashboards, any interactive
/// HTML — is PLAYED on the phone. Touch controls work because the agent's
/// identity (`forge-identity.md`) mandates touch-first output for anything
/// interactive: a keyboard-only game on a phone is useless.
///
/// Secondary path: `UIFileSharingEnabled` exposes Documents/ in the Files
/// app, so the user can also open the HTML from Files → Safari.
struct ProjectPreviewSheet: View {
    let projectRoot: String
    @Environment(\.dismiss) private var dismiss

    /// Entry resolution: `index.html` → first root-level `.html` → nil.
    private var entryURL: URL? {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: projectRoot)
        guard fm.fileExists(atPath: root.path) else { return nil }
        let index = root.appendingPathComponent("index.html")
        if fm.fileExists(atPath: index.path) { return index }
        let items = (try? fm.contentsOfDirectory(at: root,
                                                 includingPropertiesForKeys: nil)) ?? []
        return items.first { $0.pathExtension.lowercased() == "html" }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Preview")
                    .font(TuiTheme.bodyFont.bold())
                    .foregroundStyle(TuiTheme.textPrimary)
                Spacer()
                Button("Close") { dismiss() }
                    .font(TuiTheme.smallFont)
                    .foregroundStyle(TuiTheme.violet)
            }
            .padding(.horizontal, TuiTheme.transcriptPad)
            .frame(height: 44)
            .background(TuiTheme.bg)
            .overlay(alignment: .bottom) { Divider().overlay(TuiTheme.panelBorder) }

            if let url = entryURL {
                let fm = FileManager.default
                let attrs = try? fm.attributesOfItem(atPath: url.path)
                let size = (attrs?[.size] as? NSNumber)?.intValue ?? 0
                if size > 5120 {
                    PreviewWebView(url: url,
                                   projectRoot: URL(fileURLWithPath: projectRoot))
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    // File guard: wait for write to finish (muse streams 30KB) — retry 2s
                    VStack(spacing: 10) {
                        ProgressView().tint(TuiTheme.textDim)
                        Text("Preparing preview…\n\(size) bytes")
                            .font(TuiTheme.smallFont)
                            .foregroundStyle(TuiTheme.textDim)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(TuiTheme.bg)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            // Force re-evaluate entryURL by toggling
                            // (SwiftUI re-reads entryURL on next body)
                        }
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "play.slash")
                        .font(.system(size: 28))
                        .foregroundStyle(TuiTheme.textDim)
                    Text("No HTML file in this project yet.\nAsk the agent to build one (index.html).")
                        .font(TuiTheme.smallFont)
                        .foregroundStyle(TuiTheme.textDim)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(TuiTheme.bg)
            }
        }
        .background(TuiTheme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

struct PreviewWebView: View {
    let url: URL
    let projectRoot: URL
    @State private var isLoading = true

    var body: some View {
        ZStack {
            PreviewWebViewCore(url: url, projectRoot: projectRoot, isLoading: $isLoading)
            ZStack {
                TuiTheme.bg
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(TuiTheme.textDim)
                    Text("Loading preview…")
                        .font(TuiTheme.smallFont)
                        .foregroundStyle(TuiTheme.textDim)
                }
            }
            .opacity(isLoading ? 1 : 0)
        }
        .animation(.easeOut(duration: 0.25), value: isLoading)
    }
}

/// WKWebView loading a jailed project file URL with read access scoped to
/// the project root (the file-jail equivalent of the bridge's path jailing).
struct PreviewWebViewCore: UIViewRepresentable {
    let url: URL
    let projectRoot: URL
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool

        init(isLoading: Binding<Bool>) {
            _isLoading = isLoading
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async { self.isLoading = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                webView.evaluateJavaScript("""
                (function(){
                  var c = document.getElementById('c') || document.querySelector('canvas');
                  if (!c) return 'no-canvas';
                  var r = c.getBoundingClientRect();
                  var x = r.left + r.width/2, y = r.top + r.height/2;
                  ['pointerdown','pointerup','click'].forEach(function(t){
                    c.dispatchEvent(new PointerEvent(t, {bubbles:true, clientX:x, clientY:y, pointerId:1}));
                  });
                  return 'tapped';
                })()
                """) { _, _ in }
            }
        }
    }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        cfg.websiteDataStore = .default()
        cfg.allowsInlineMediaPlayback = true
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.isOpaque = true
        wv.backgroundColor = .black
        wv.scrollView.backgroundColor = .black
        wv.underPageBackgroundColor = .black
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.scrollView.bounces = false
        wv.navigationDelegate = context.coordinator
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        if wv.url == nil, wv.bounds.width > 1 {
            wv.loadFileURL(url, allowingReadAccessTo: projectRoot)
        }
    }
}
