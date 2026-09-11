# FORGE iOS — Preview Tab Specification

**Spec ID:** FORGE-PREVIEW-SPEC-V1.0
**Classification:** RUNTIME-GRADE COMPONENT SPECIFICATION
**Authority:** Extends FORGE Engineering Specification v1.0.0 §15 (Mode 1: Build On-Device)
**Target:** iOS 17.0+ / Swift 5.9+ / Xcode 15+
**Build Time Estimate:** 4–6 days (5 waves)
**Lines of Code Estimate:** 1,200–1,800 new Swift, 300–500 new JavaScript

---

## 1. Executive Summary

### 1.1 The Problem

FORGE Mode 1 runs the complete opencode agent inside a **hidden** WKWebView (0×0 frame). The agent can write files, execute Python, run the God Loop — but when it produces a **visual artifact** (an HTML page, a Canvas game, a Three.js scene, an SVG diagram), there is no visible surface on which to render it. The user sees terminal text describing the artifact. They never see the artifact.

### 1.2 The Solution

A **second, visible, interactive WKWebView** — the Preview Pane — added to the Mode 1 screen. The agent writes files through the existing ForgeBridge, then calls a new bridge method `renderPreview({ path })`. The Swift layer loads that file into the Preview WebView with full interactivity. The user sees and touches what the agent built.

### 1.3 What This Is NOT

This is NOT a native app compiler. The Preview Pane renders **web content**: HTML, CSS, JavaScript, Canvas, WebGL, SVG. It cannot compile Swift, run Docker, or produce `.ipa` files. Those remain out of scope.

### 1.4 Fidelity Rules

- The existing hidden WKWebView (ForgeEngine) is **untouched**. The Preview WebView is a completely separate `WKWebView` instance with its own `WKWebViewConfiguration`, its own `WKProcessPool`, and its own `WKUserContentController`.
- All preview chrome uses `ForgeTheme` tokens (§20 of the engineering spec). No new colors. No hardcoded hex outside `ForgeTheme`.
- The agent-facing API is exactly **5 new bridge methods**. No more. No fewer.
- Every anti-pattern in §9 is a bug that will happen if you ignore it.

---

## 2. Architecture Overview

### 2.1 The Dual-WebView Topology

```
+--------------------------------------------------------------------+
|                    LAYER 1: PRESENTATION                            |
|                                                                    |
|  BuildOnDeviceScreen (MODIFIED)                                    |
|  +-- TopBar                                                        |
|  +-- SessionHeaderRow                                              |
|  +-- PreviewModeToggle (NEW — segmented control)                   |
|  |     [ TERMINAL ]  [ SPLIT ]  [ PREVIEW ]                       |
|  +-- ZStack                                                        |
|  |     +-- ForgeTerminalView (SwiftTerm — existing)                |
|  |     +-- PreviewPaneView (NEW — visible WKWebView)               |
|  |     +-- PreviewToolbarView (NEW — reload/home/safari/console)   |
|  |     +-- ConsoleDrawerView (NEW — sliding log panel)             |
|  +-- KeyboardAccessoryBar (existing)                               |
|  +-- BottomStatusBarView (existing)                                |
+--------------------------------------------------------------------+
                              |
                   bridge calls (shared)
                              |
+--------------------------------------------------------------------+
|                    LAYER 2: BRIDGE (ForgeEngine — MODIFIED)         |
|                                                                    |
|  Existing methods (UNCHANGED):                                     |
|    readFile / writeFile / listFiles / deleteFile / searchFiles     |
|    runCommand / gitOperation / httpRequest / getSecret / setSecret |
|    shareFile / runPython / __output / __ready                      |
|                                                                    |
|  NEW methods (5):                                                  |
|    renderPreview({ path, mode })                                   |
|    injectPreviewCode({ js })                                       |
|    setPreviewTitle({ title })                                      |
|    previewConsole({ level, message, source, line })                |
|    previewError({ message, source, line, stack })                  |
+--------------------------------------------------------------------+
                              |
              +---------------+---------------+
              |                               |
+-------------v---------------+  +------------v----------------------+
| LAYER 3a: EXECUTION         |  | LAYER 3b: PREVIEW (NEW)           |
| (existing, UNTOUCHED)       |  |                                   |
|                             |  | PreviewWebView                    |
| Hidden WKWebView (0×0)      |  | +-- Visible, interactive          |
| +-- forge-bundle.js         |  | +-- nonPersistent() data store    |
| +-- opencode + Trident      |  | +-- Isolated WKProcessPool        |
| +-- tree-sitter WASM        |  | +-- Loads files from sandbox      |
| +-- Pyodide WASM            |  | +-- Captures console → bridge     |
| +-- SQL.js WASM             |  | +-- Renders HTML/JS/Canvas/WebGL  |
+-----------------------------+  +-----------------------------------+
```

### 2.2 Why Two WebViews

The hidden WKWebView runs the agent: opencode, Trident, Effect-TS, tree-sitter WASM, Pyodide WASM. This is CPU-heavy and memory-heavy. The Preview WebView renders the agent's output: Canvas games, Three.js scenes, interactive HTML. This is GPU-heavy.

Running both in a single WKWebView means they share one JavaScript thread and one memory pool. A Canvas game running at 60fps will starve the agent's AST parser. The agent's tree-sitter compilation will stutter the game to 2fps.

Two WebViews = two JavaScript contexts = two threads = zero interference.

### 2.3 Data Flow — Agent Builds Space Invaders

```
User types: "build me space invaders with canvas"
     |
     v
 SwiftTerm → ForgeBridge → Hidden WKWebView
     |
     v
 opencode routes to Trident agent
     |
     v
 Trident writes files via existing bridge:
   writeFile({ path: "space-invaders/index.html", content: "<!DOCTYPE html>..." })
   writeFile({ path: "space-invaders/game.js",    content: "const canvas = ..." })
     |
     v
 Trident calls NEW bridge method:
   renderPreview({ path: "space-invaders/index.html", mode: "auto" })
     |
     v
 ForgeEngine receives "renderPreview" message
   → resolves full path: Documents/projects/{project}/space-invaders/index.html
   → DispatchQueue.main.async { previewWebView.loadFileURL(...) }
   → switches PreviewModeToggle to .preview (if not already)
   → resolves callback: { ok: true, path: "space-invaders/index.html" }
     |
     v
 Preview WebView loads index.html with read access to space-invaders/ directory
   → game.js executes
   → Canvas renders
   → User sees Space Invaders
   → User touches the screen — game responds
     |
     v
 game.js calls console.log("Player hit!")
   → injected console proxy intercepts
   → calls previewConsole({ level: "log", message: "Player hit!" })
   → ForgeEngine routes to terminal: dim line "[preview] Player hit!"
```

### 2.4 Data Flow — Hot Reload After Agent Edit

```
User says: "make the aliens move faster"
     |
     v
 Trident modifies game.js via writeFile bridge
     |
     v
 Trident calls:
   injectPreviewCode({ js: "window.gameConfig.alienSpeed = 3.0;" })
     |
     v
 ForgeEngine evaluates JS in Preview WebView
   → game reads new speed on next frame
   → aliens move faster
   → NO full reload. NO flicker. Live patch.
```

---

## 3. Component Specifications

### 3.1 Component Map (7 components)

| Component | Responsibility | File | Status |
|---|---|---|---|
| `PreviewPaneView` | UIViewRepresentable wrapping the visible WKWebView | `Presentation/Mode1_BuildOnDevice/PreviewPaneView.swift` | NEW |
| `PreviewNavigationDelegate` | WKNavigationDelegate — blocks external nav, handles errors | `Presentation/Mode1_BuildOnDevice/PreviewNavigationDelegate.swift` | NEW |
| `PreviewToolbarView` | Reload / Home / Open-in-Safari / Console buttons | `Presentation/Mode1_BuildOnDevice/PreviewToolbarView.swift` | NEW |
| `PreviewModeToggle` | Segmented control: Terminal / Split / Preview | `Presentation/Mode1_BuildOnDevice/PreviewModeToggle.swift` | NEW |
| `ConsoleDrawerView` | Sliding panel showing captured console output | `Presentation/Mode1_BuildOnDevice/ConsoleDrawerView.swift` | NEW |
| `PreviewBridge` | Swift handler for the 5 new bridge methods | `Bridge/PreviewBridge.swift` | NEW |
| `PreviewBootstrap.js` | Injected script: console proxy, error handler, game template | `Resources/preview-bootstrap.js` | NEW |

**Modified files (3):**

| File | Change |
|---|---|
| `BuildOnDeviceScreen.swift` | Add PreviewModeToggle, ZStack with terminal + preview, toolbar |
| `ForgeEngine.swift` | Add 5 new cases to `userContentController` switch. Add `previewWebView` property. Add `showPreview()` / `hidePreview()` |
| `ForgeTheme.swift` | Add 2 tokens: `previewToolbarBg`, `consoleDrawerBg` (both derived from existing `surface` and `elevated`) |

### 3.2 PreviewModeToggle

```swift
enum PreviewMode: String, CaseIterable {
    case terminal = "TERMINAL"
    case split    = "SPLIT"
    case preview  = "PREVIEW"
}

struct PreviewModeToggle: View {
    @Binding var mode: PreviewMode
    var hasPreviewContent: Bool   // false until first renderPreview call

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PreviewMode.allCases, id: \.self) { m in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        mode = m
                    }
                    hapticFeedback(style: .light)
                } label: {
                    Text(m.rawValue)
                        .font(.forgeCaption)
                        .foregroundColor(mode == m ? .forgeBackground : .forgeSecondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            mode == m ? Color.forgeAccent : Color.clear
                        )
                }
                .disabled(m == .preview && !hasPreviewContent)
                .opacity(m == .preview && !hasPreviewContent ? 0.35 : 1.0)
            }
        }
        .background(Color.forgeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.forgeAccent.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}
```

**Rules:**
- PREVIEW is disabled (dimmed, untappable) until the first `renderPreview` call succeeds.
- SPLIT is always available.
- The toggle sits between `SessionHeaderRow` and the terminal/preview ZStack.
- Haptic: `.light` on every tap.

### 3.3 PreviewPaneView

```swift
struct PreviewPaneView: UIViewRepresentable {
    @Binding var webView: WKWebView?
    var onConsoleMessage: ((ConsoleEntry) -> Void)?

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.mediaTypesRequiringUserActionForPlayback = []

        // CRITICAL: non-persistent store. Preview sessions leave no trace.
        config.websiteDataStore = .nonPersistent()

        // CRITICAL: isolated process pool. Preview JS cannot touch agent JS.
        config.processPool = WKProcessPool()  // fresh instance, NOT shared

        // Inject console/error capture BEFORE any page script runs
        let bootstrapURL = Bundle.main.url(forResource: "preview-bootstrap", withExtension: "js")!
        let bootstrapSource = try! String(contentsOf: bootstrapURL)
        let bootstrapScript = WKUserScript(
            source: bootstrapSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(bootstrapScript)
        config.userContentController.add(context.coordinator, name: "previewConsole")
        config.userContentController.add(context.coordinator, name: "previewError")

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = false
        wv.scrollView.bounces = true
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = UIColor(
            red: 0x0A/255, green: 0x0A/255, blue: 0x0F/255, alpha: 1.0
        )

        DispatchQueue.main.async { self.webView = wv }
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> PreviewNavigationDelegate {
        PreviewNavigationDelegate(onConsoleMessage: onConsoleMessage)
    }
}
```

**Rules:**
- `WKProcessPool()` is instantiated fresh. NEVER share the agent's process pool.
- `websiteDataStore` is `.nonPersistent()`. Preview cookies, localStorage, IndexedDB — all gone on teardown.
- The WKWebView is fully interactive: touch, scroll, keyboard input all work.
- Background color matches `ForgeTheme.forgeBackground` so loading states don't flash white.

### 3.4 PreviewNavigationDelegate

```swift
final class PreviewNavigationDelegate: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    var onConsoleMessage: ((ConsoleEntry) -> Void)?
    var onPreviewError: ((PreviewError) -> Void)?

    init(onConsoleMessage: ((ConsoleEntry) -> Void)?) {
        self.onConsoleMessage = onConsoleMessage
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        // Allow file:// loads (our sandbox content)
        if url.isFileURL {
            decisionHandler(.allow)
            return
        }
        // Allow about:blank (injected content)
        if url.scheme == "about" {
            decisionHandler(.allow)
            return
        }
        // Allow data: URIs (SVG rendering)
        if url.scheme == "data" {
            decisionHandler(.allow)
            return
        }
        // BLOCK everything else. No external navigation.
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onPreviewError?(PreviewError(message: error.localizedDescription, source: nil, line: nil, stack: nil))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        onPreviewError?(PreviewError(message: error.localizedDescription, source: nil, line: nil, stack: nil))
    }

    // MARK: - WKScriptMessageHandler (console + error capture)

    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
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
```

### 3.5 PreviewToolbarView

```swift
struct PreviewToolbarView: View {
    let currentPath: String?
    let onReload: () -> Void
    let onHome: () -> Void
    let onOpenInSafari: () -> Void
    let onToggleConsole: () -> Void
    var consoleBadge: Int  // unread console messages

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onReload) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .medium))
            }
            .accessibilityIdentifier("previewReload")

            Button(action: onHome) {
                Image(systemName: "house")
                    .font(.system(size: 15, weight: .medium))
            }
            .accessibilityIdentifier("previewHome")

            // Path label — truncated, centered
            Text(currentPath ?? "no content")
                .font(.forgeCaption)
                .foregroundColor(.forgeSecondaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity)

            Button(action: onToggleConsole) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "terminal")
                        .font(.system(size: 15, weight: .medium))
                    if consoleBadge > 0 {
                        Text("\(min(consoleBadge, 99))")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.forgeBackground)
                            .padding(2)
                            .background(Color.forgeAccent, in: Circle())
                            .offset(x: 8, y: -8)
                    }
                }
            }
            .accessibilityIdentifier("previewConsoleToggle")

            Button(action: onOpenInSafari) {
                Image(systemName: "safari")
                    .font(.system(size: 15, weight: .medium))
            }
            .accessibilityIdentifier("previewOpenSafari")
        }
        .foregroundColor(.forgeAccent)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.forgeSurface)
    }
}
```

**Rules:**
- Toolbar height: 36pt.
- Toolbar appears ONLY when `previewMode == .preview` or `.split`.
- Reload: re-executes `loadFileURL` with the current path.
- Home: loads `about:blank`. Clears the preview.
- Open in Safari: copies the file path to clipboard + shows toast "Path copied — paste in Safari (file access limited)". Full Safari file access is not possible from sandboxed apps.
- Console badge: increments on every new console/error entry. Resets when console drawer is opened.

### 3.6 ConsoleDrawerView

```swift
struct ConsoleEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let level: ConsoleLevel
    let message: String
    let source: String?
    let line: Int?
}

enum ConsoleLevel: String {
    case log, warn, error, info, debug

    var color: Color {
        switch self {
        case .log, .info, .debug: return .forgePrimaryText
        case .warn:                 return .forgeWarning
        case .error:                return .forgeError
        }
    }

    var prefix: String {
        switch self {
        case .log:   return "›"
        case .info:  return "ℹ"
        case .warn:  return "⚠"
        case .error: return "✗"
        case .debug: return "·"
        }
    }
}

struct ConsoleDrawerView: View {
    let entries: [ConsoleEntry]
    let onClear: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("CONSOLE")
                    .font(.forgeCaption)
                    .foregroundColor(.forgeSecondaryText)
                Spacer()
                Button("Clear", action: onClear)
                    .font(.forgeCaption)
                    .foregroundColor(.forgeAccent)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(.forgeSecondaryText)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.forgeSurface)

            Divider().overlay(Color.forgeAccent.opacity(0.2))

            // Entries
            if entries.isEmpty {
                Text("no console output")
                    .font(.forgeCaption)
                    .foregroundColor(.forgeSecondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(entries) { entry in
                                HStack(alignment: .top, spacing: 6) {
                                    Text(entry.level.prefix)
                                        .foregroundColor(entry.level.color)
                                    Text(entry.message)
                                        .foregroundColor(entry.level.color)
                                        .textSelection(.enabled)
                                    Spacer()
                                    if let source = entry.source, let line = entry.line {
                                        Text("\(source):\(line)")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(.forgeSecondaryText)
                                    }
                                }
                                .font(.forgeCaption)
                                .id(entry.id)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                    .onChange(of: entries.count) { _ in
                        if let last = entries.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(height: 220)
        .background(Color.forgeElevated)
    }
}
```

**Rules:**
- Max 200 entries. Ring buffer — oldest entries drop off.
- Drawer slides up from the bottom of the preview area with `spring(response: 0.3, dampingFraction: 0.8)`.
- Drawer overlays the bottom 220pt of the preview. Does NOT resize the WebView.
- Console entries also stream to the terminal in dim text: `[preview] › Player hit!` — so the agent can see them in the God Loop context.

### 3.7 BuildOnDeviceScreen — Modified Layout

```swift
struct BuildOnDeviceScreen: View {
    @StateObject var engine: ForgeEngine
    @State private var previewMode: PreviewMode = .terminal
    @State private var hasPreviewContent = false
    @State private var previewWebView: WKWebView?
    @State private var consoleEntries: [ConsoleEntry] = []
    @State private var showConsoleDrawer = false
    @State private var currentPreviewPath: String?

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "FORGE", onBack: { ... }, onMenu: { ... })
            SessionHeaderRow(...)

            // NEW: mode toggle
            PreviewModeToggle(
                mode: $previewMode,
                hasPreviewContent: hasPreviewContent
            )

            // Content area — ZStack of terminal + preview
            ZStack {
                // Terminal layer
                ForgeTerminalView(terminalView: $engine.terminalView, ...)
                    .opacity(previewMode == .preview ? 0 : 1)
                    .allowsHitTesting(previewMode != .preview)

                // Preview layer
                if previewMode != .terminal {
                    VStack(spacing: 0) {
                        PreviewToolbarView(
                            currentPath: currentPreviewPath,
                            onReload: { engine.reloadPreview() },
                            onHome: { engine.loadPreviewBlank() },
                            onOpenInSafari: { engine.copyPreviewPathToClipboard() },
                            onToggleConsole: { showConsoleDrawer.toggle() },
                            consoleBadge: consoleEntries.count
                        )

                        PreviewPaneView(
                            webView: $previewWebView,
                            onConsoleMessage: { entry in
                                consoleEntries.append(entry)
                                if consoleEntries.count > 200 {
                                    consoleEntries.removeFirst()
                                }
                                // Also feed to terminal for agent visibility
                                engine.feedPreviewConsoleToTerminal(entry)
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // Console drawer overlay
                        if showConsoleDrawer {
                            ConsoleDrawerView(
                                entries: consoleEntries,
                                onClear: { consoleEntries.removeAll() },
                                onClose: { showConsoleDrawer = false }
                            )
                            .transition(.move(edge: .bottom))
                        }
                    }
                    .transition(.opacity)
                }
            }

            KeyboardAccessoryBar(...)
            BottomStatusBarView(...)
        }
        .onReceive(engine.previewReadyPublisher) { path in
            hasPreviewContent = true
            currentPreviewPath = path
            if previewMode == .terminal {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    previewMode = .preview
                }
            }
        }
    }
}
```

**Split mode layout:** When `previewMode == .split`, the ZStack becomes a VStack:

```
+------------------------------------------+
| TopBar                                    |
| SessionHeaderRow                          |
| [TERMINAL] [SPLIT] [PREVIEW]             |
+------------------------------------------+
|                                           |
|  Preview (60% height)                     |
|  +-- PreviewToolbarView                   |
|  +-- PreviewPaneView                      |
|                                           |
+------------------------------------------+
|                                           |
|  Terminal (40% height)                    |
|  +-- ForgeTerminalView (SwiftTerm)        |
|                                           |
+------------------------------------------+
| KeyboardAccessoryBar                      |
| BottomStatusBarView                       |
+------------------------------------------+
```

Split ratio: 60/40. User can drag the divider to adjust between 30% and 70%.

---

## 4. The Bridge Contract (5 Methods)

All 5 methods are added to the existing `ForgeEngine.userContentController(_:didReceive:)` switch. They follow the exact same callback pattern as existing bridge methods.

### 4.1 `renderPreview`

**Direction:** JS → Swift
**Purpose:** Load a file from the project sandbox into the Preview WebView.

```
Request:
{
    "method": "renderPreview",
    "args": {
        "path": "space-invaders/index.html",   // relative to project root
        "mode": "auto"                          // "auto" | "html" | "js" | "svg" | "markdown" | "raw"
    },
    "callbackId": "cb_42"
}

Success response (resolved):
{ "ok": true, "path": "space-invaders/index.html", "renderMode": "html" }

Failure response (rejected):
"renderPreview: file not found: space-invaders/index.html"
"renderPreview: unsupported file type: .xyz"
"renderPreview: file too large (max 5MB): scene.obj"
```

**Swift implementation:**

```swift
func renderPreview(_ args: [String: Any], callbackId: String?, webView: WKWebView?) {
    guard let path = args["path"] as? String, let cbId = callbackId else { return }
    let mode = args["mode"] as? String ?? "auto"

    DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        let fullPath = self.bridge.resolveProjectPath(path)

        // Validate file exists
        guard FileManager.default.fileExists(atPath: fullPath) else {
            self.rejectCallback(cbId, error: "renderPreview: file not found: \(path)")
            return
        }

        // Validate file size (max 5MB)
        let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath)
        let size = attrs?[.size] as? Int ?? 0
        guard size <= 5 * 1024 * 1024 else {
            self.rejectCallback(cbId, error: "renderPreview: file too large (max 5MB): \(path)")
            return
        }

        let fileURL = URL(fileURLWithPath: fullPath)
        let dirURL = fileURL.deletingLastPathComponent()

        // Determine render mode
        let renderMode = self.detectRenderMode(path: path, mode: mode)

        switch renderMode {
        case "html", "svg":
            // Load directly with directory read access
            self.previewWebView.loadFileURL(fileURL, allowingReadAccessTo: dirURL)

        case "js":
            // Wrap in game template
            let content = (try? String(contentsOfFile: fullPath)) ?? ""
            let html = self.wrapJSInGameTemplate(content, title: path)
            self.previewWebView.loadHTMLString(html, baseURL: dirURL)

        case "markdown":
            // Convert to HTML via lightweight renderer
            let content = (try? String(contentsOfFile: fullPath)) ?? ""
            let html = self.wrapMarkdown(content, title: path)
            self.previewWebView.loadHTMLString(html, baseURL: dirURL)

        case "raw":
            // Display source code in a styled pre block
            let content = (try? String(contentsOfFile: fullPath)) ?? ""
            let html = self.wrapRawSource(content, path: path)
            self.previewWebView.loadHTMLString(html, baseURL: dirURL)

        default:
            self.rejectCallback(cbId, error: "renderPreview: unsupported file type")
            return
        }

        self.currentPreviewPath = path
        self.previewReadyPublisher.send(path)
        self.resolveCallback(cbId, result: ["ok": true, "path": path, "renderMode": renderMode])
    }
}
```

### 4.2 `injectPreviewCode`

**Direction:** JS → Swift
**Purpose:** Evaluate JavaScript in the Preview WebView without reloading.

```
Request:
{
    "method": "injectPreviewCode",
    "args": {
        "js": "window.gameConfig.alienSpeed = 3.0;"
    },
    "callbackId": "cb_43"
}

Success: { "ok": true }
Failure: "injectPreviewCode: <JS error message>"
```

```swift
func injectPreviewCode(_ args: [String: Any], callbackId: String?, webView: WKWebView?) {
    guard let js = args["js"] as? String, let cbId = callbackId else { return }
    DispatchQueue.main.async { [weak self] in
        self?.previewWebView.evaluateJavaScript(js) { result, error in
            if let error = error {
                self?.rejectCallback(cbId, error: "injectPreviewCode: \(error.localizedDescription)")
            } else {
                self?.resolveCallback(cbId, result: ["ok": true, "result": result])
            }
        }
    }
}
```

### 4.3 `setPreviewTitle`

**Direction:** JS → Swift
**Purpose:** Update the PreviewToolbar path label.

```
Request:
{ "method": "setPreviewTitle", "args": { "title": "Space Invaders v2" }, "callbackId": "cb_44" }
```

### 4.4 `previewConsole`

**Direction:** Preview WebView → Swift (via injected bootstrap script)
**Purpose:** Forward `console.log/warn/error` from the preview page to the console drawer and terminal.

```
{
    "method": "previewConsole",
    "args": {
        "level": "log",
        "message": "Player hit! Score: 150",
        "source": "game.js",
        "line": 42
    }
}
```

### 4.5 `previewError`

**Direction:** Preview WebView → Swift (via injected bootstrap script)
**Purpose:** Forward uncaught JavaScript errors.

```
{
    "method": "previewError",
    "args": {
        "message": "TypeError: Cannot read properties of undefined",
        "source": "game.js",
        "line": 87,
        "stack": "TypeError: Cannot read...\n    at update (game.js:87:12)"
    }
}
```

---

## 5. Preview Bootstrap Script (preview-bootstrap.js)

Injected at `atDocumentStart` into every page loaded in the Preview WebView.

```javascript
// preview-bootstrap.js
// Injected into the Preview WebView BEFORE any page script executes.
// Captures console output and uncaught errors, routes them to the Swift bridge.

(function() {
    'use strict';

    // ---- Console capture ----
    var originalConsole = {
        log:   console.log.bind(console),
        warn:  console.warn.bind(console),
        error: console.error.bind(console),
        info:  console.info.bind(console),
        debug: console.debug.bind(console)
    };

    function sendConsole(level, args) {
        var message = Array.prototype.slice.call(args).map(function(a) {
            if (typeof a === 'object') {
                try { return JSON.stringify(a); } catch(e) { return String(a); }
            }
            return String(a);
        }).join(' ');

        // Extract source from Error stack if available
        var source = null;
        var line = null;
        for (var i = 0; i < args.length; i++) {
            if (args[i] instanceof Error && args[i].stack) {
                var match = args[i].stack.match(/at\s+.*?\(?(.*?):(\d+):(\d+)\)?/);
                if (match) {
                    source = match[1].split('/').pop();
                    line = parseInt(match[2], 10);
                }
                break;
            }
        }

        try {
            window.webkit.messageHandlers.previewConsole.postMessage({
                level: level,
                message: message,
                source: source,
                line: line
            });
        } catch(e) {
            // Bridge not available — fall through to original console
        }

        // Still call original console so DevTools (if attached) shows it
        originalConsole[level].apply(console, args);
    }

    console.log   = function() { sendConsole('log',   arguments); };
    console.warn  = function() { sendConsole('warn',  arguments); };
    console.error = function() { sendConsole('error', arguments); };
    console.info  = function() { sendConsole('info',  arguments); };
    console.debug = function() { sendConsole('debug', arguments); };

    // ---- Uncaught error capture ----
    window.addEventListener('error', function(event) {
        try {
            window.webkit.messageHandlers.previewError.postMessage({
                message: event.message || 'Unknown error',
                source: event.filename ? event.filename.split('/').pop() : null,
                line: event.lineno || null,
                stack: event.error ? event.error.stack : null
            });
        } catch(e) {}
    });

    // ---- Unhandled promise rejection capture ----
    window.addEventListener('unhandledrejection', function(event) {
        try {
            window.webkit.messageHandlers.previewError.postMessage({
                message: 'Unhandled rejection: ' + (event.reason ? event.reason.message || String(event.reason) : 'unknown'),
                source: null,
                line: null,
                stack: event.reason && event.reason.stack ? event.reason.stack : null
            });
        } catch(e) {}
    });

    // ---- FORGE Preview API (available to rendered content) ----
    window.__forgePreview = {
        // Request a file from the project sandbox (async)
        readFile: function(path) {
            return new Promise(function(resolve, reject) {
                var id = 'pvr_' + (++window.__forgePreview._cbId);
                window.__forgePreview._pending[id] = { resolve: resolve, reject: reject };
                window.webkit.messageHandlers.previewConsole.postMessage({
                    level: 'debug',
                    message: '__forgePreview.readFile(' + path + ')'
                });
                // Route through the main bridge
                window.webkit.messageHandlers.native.postMessage({
                    method: 'readFile',
                    args: { path: path },
                    callbackId: id
                });
            });
        },
        // Signal that the preview content has loaded and is interactive
        ready: function() {
            try {
                window.webkit.messageHandlers.previewConsole.postMessage({
                    level: 'info',
                    message: 'Preview content loaded'
                });
            } catch(e) {}
        },
        _cbId: 0,
        _pending: {}
    };

})();
```

---

## 6. Render Modes and Templates

### 6.1 Auto-Detection

```swift
func detectRenderMode(path: String, mode: String) -> String {
    if mode != "auto" { return mode }
    let ext = (path as NSString).pathExtension.lowercased()
    switch ext {
    case "html", "htm":           return "html"
    case "js", "mjs":             return "js"
    case "svg":                   return "svg"
    case "md", "markdown":        return "markdown"
    case "json", "txt", "css",
         "ts", "py", "swift",
         "sh", "yaml", "yml":     return "raw"
    default:                      return "raw"
    }
}
```

### 6.2 JS Game Template

When the agent writes a standalone `.js` file and calls `renderPreview({ path: "game.js", mode: "js" })`, the file is wrapped:

```swift
func wrapJSInGameTemplate(_ jsContent: String, title: String) -> String {
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0,
              maximum-scale=1.0, user-scalable=no">
        <title>\(title)</title>
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
            // Provide canvas context before user code runs
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
```

**Rules:**
- The canvas is full-screen, device-pixel-ratio aware.
- `touch-action: none` prevents Safari gesture interference.
- `window.canvas` and `window.ctx` are pre-created so the agent's JS can immediately call `ctx.fillRect(...)` without boilerplate.
- The agent's JS runs in the second `<script>` tag, AFTER the canvas setup.

### 6.3 SVG Template

```swift
func wrapSVG(_ svgContent: String, title: String) -> String {
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>\(title)</title>
        <style>
            body {
                margin: 0; padding: 16px;
                background: #0A0A0F;
                display: flex; justify-content: center; align-items: center;
                min-height: 100vh;
            }
            svg { max-width: 100%; max-height: 90vh; }
        </style>
    </head>
    <body>
    \(svgContent)
    </body>
    </html>
    """
}
```

### 6.4 Markdown Template

Use a lightweight regex-based Markdown-to-HTML converter (no external dependency). Support: headings, bold, italic, inline code, code blocks, lists, links.

```swift
func wrapMarkdown(_ content: String, title: String) -> String {
    let html = lightweightMarkdownToHTML(content)
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>\(title)</title>
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
```

### 6.5 Raw Source Template

For file types that cannot be rendered (`.ts`, `.py`, `.json`, etc.), display the source code in a styled, syntax-highlighted `<pre>` block.

```swift
func wrapRawSource(_ content: String, path: String) -> String {
    let escaped = content
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>\(path)</title>
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
        <div class="path">\(path) — source preview (not renderable)</div>
        <pre>\(escaped)</pre>
    </body>
    </html>
    """
}
```

---

## 7. Agent Integration

### 7.1 FORGE Identity Update

Add to the FORGE_IDENTITY string in `forge-identity.ts`:

```
## Preview Pane
You have a Preview Pane — a visible, interactive WebView on the user's iPhone screen.
When you produce visual output (HTML pages, Canvas games, Three.js scenes, SVG diagrams):
1. Write the files to the project using writeFile.
2. Call renderPreview({ path: "path/to/index.html", mode: "auto" }) to display it.
3. The user will see and interact with your output immediately.
4. To make live adjustments without reloading, use injectPreviewCode({ js: "..." }).
5. Console output from the preview is visible to you in the terminal as [preview] lines.
6. JavaScript errors in the preview are reported to you as [preview-error] lines.
   Read them. Fix the code. Re-render.
7. For Canvas games: the template provides window.canvas and window.ctx pre-configured.
   Draw with ctx. Handle touch events on the canvas element.
8. For Three.js: load from the bundled local copy at ./vendor/three.module.js.
   Do NOT load from CDN.
```

### 7.2 Trident God Loop Integration

When Trident's `trident_build` subagent produces a visual artifact, the VERIFY phase can now check the preview:

```
VERIFY phase addition:
- If the build produced an HTML/JS/SVG file:
  1. Call renderPreview({ path })
  2. Wait 2 seconds
  3. Call injectPreviewCode({ js: "document.title + ' | errors: ' + (window.__forgeErrors || []).length" })
  4. Read the result. If errors > 0, the artifact is NOT runtime-grade.
  5. Report: "Preview rendered with 0 errors" or "Preview rendered with 3 errors"
```

This gives the God Loop a **mechanical, verifiable signal** that the visual output actually works — not just that the code compiles.

### 7.3 Example Agent Session

```
> build me a 3D solar system with three.js

AUDIT — Phase 1/10
  No existing project files. Starting fresh.

EXECUTE — Writing files
  ✓ solar-system/index.html (1,204 bytes)
  ✓ solar-system/scene.js (8,432 bytes)
  ✓ solar-system/vendor/three.module.js (bundled)

RENDER — Preview
  → renderPreview({ path: "solar-system/index.html", mode: "auto" })
  ✓ Preview loaded. User sees 3D solar system.

VERIFY — Runtime check
  → injectPreviewCode({ js: "document.querySelectorAll('canvas').length" })
  → Result: 1 (canvas present)
  → injectPreviewCode({ js: "(window.__forgeErrors || []).length" })
  → Result: 0 (no errors)
  ✓ Preview verified: 0 errors, canvas rendering

PASS — Quality grade: 97/100
  Git checkpoint: "FORGE: 3D solar system (97)"
```

---

## 8. Performance Budgets

| Operation | Budget |
|---|---|
| Tab switch (terminal → preview) | < 80ms |
| First render after `renderPreview` | < 150ms |
| Hot reload via `injectPreviewCode` | < 50ms |
| Console message latency (preview → terminal) | < 30ms |
| Preview WebView memory (typical Canvas game) | < 250MB |
| Preview WebView memory (Three.js scene) | < 400MB |
| Console drawer render (200 entries) | < 16ms (LazyVStack) |
| Split mode: both WebViews active | 60fps in both panes |

---

## 9. Anti-Patterns

### AP1 — Shared Process Pool

**What will happen:** If the Preview WebView shares the agent's `WKProcessPool`, the Canvas game's 60fps render loop and the agent's tree-sitter AST parsing compete on the same JavaScript thread. Both stutter.

**Correct:** Fresh `WKProcessPool()` per Preview WebView. Never share.

### AP2 — Persistent Data Store

**What will happen:** If the Preview WebView uses the default `WKWebsiteDataStore`, cookies and localStorage accumulate across preview sessions. The agent's Space Invaders high score from yesterday leaks into today's CAD model preview.

**Correct:** `config.websiteDataStore = .nonPersistent()`. Always.

### AP3 — External Navigation

**What will happen:** The agent writes an HTML file with `<script src="https://cdn.example.com/lib.js">`. The preview loads it. The CDN is down. The preview shows a blank screen. The user thinks the agent failed.

**Correct:** The `WKNavigationDelegate` blocks all non-`file://` navigation. The FORGE identity instructs the agent to bundle all dependencies locally. Three.js is shipped as a local file in `Resources/vendor/`.

### AP4 — Preview WebView Created at App Launch

**What will happen:** Creating a second WKWebView at launch doubles the baseline memory footprint. On an iPhone SE (4GB RAM), this pushes the app closer to the jetsam threshold before the user has even typed a prompt.

**Correct:** Lazy creation. The Preview WebView is instantiated on the FIRST `renderPreview` call, not at app launch.

### AP5 — Console Entries in @State Inside Row Views

**What will happen:** `LazyVStack` reuses rows. `@State` in a console entry row view loses or mixes text when the list scrolls.

**Correct:** Console entries live in the `consoleEntries` array on `BuildOnDeviceScreen`. Row views are pure functions of their `ConsoleEntry` value.

### AP6 — Feeding Console to Terminal on Every Message

**What will happen:** A Canvas game logging `"frame rendered"` every 16ms floods SwiftTerm with 60 terminal lines per second. The terminal stutters. The agent's God Loop output becomes unreadable.

**Correct:** Throttle console-to-terminal forwarding. Batch entries over 500ms windows. Cap at 10 lines per batch. If a single source produces > 50 lines in 5 seconds, suppress it and show `[preview] game.js: 50+ lines suppressed`.

### AP7 — Reloading Instead of Injecting

**What will happen:** The agent changes one variable (`alienSpeed = 3.0`) and calls `renderPreview` again. The entire page reloads. The Canvas flickers. The game state resets. The user loses their score.

**Correct:** For small changes, use `injectPreviewCode`. For structural changes (new HTML, new script files), use `renderPreview`. The FORGE identity instructs the agent on which to use.

### AP8 — White Flash on Load

**What will happen:** WKWebView defaults to a white background. Every `renderPreview` call flashes white for 50-100ms before the dark content renders.

**Correct:** `webView.isOpaque = false`, `webView.backgroundColor = .clear`, `webView.scrollView.backgroundColor = forgeBackground`. Set BEFORE the first load.

---

## 10. Implementation Waves

| Wave | Scope | Gate (mechanical) |
|---|---|---|
| **W1** | `PreviewPaneView` + `PreviewNavigationDelegate` + `renderPreview` bridge + `PreviewModeToggle` | Agent calls `renderPreview`. HTML file renders in visible WebView. Toggle switches between terminal and preview. Screenshot evidence. |
| **W2** | `preview-bootstrap.js` + console capture + `ConsoleDrawerView` + `previewConsole`/`previewError` bridge | `console.log` in preview appears in console drawer AND terminal. JS error appears as `[preview-error]`. Screenshot evidence. |
| **W3** | Render modes (js/svg/markdown/raw) + game template + auto-detection | Agent writes standalone `.js` file. `renderPreview` wraps it in canvas template. Game renders and responds to touch. Video evidence. |
| **W4** | `injectPreviewCode` + hot reload + `PreviewToolbarView` | Agent modifies game variable via inject. Preview updates without reload. Toolbar buttons work. Video evidence. |
| **W5** | Split mode + draggable divider + performance pass + God Loop VERIFY integration | Split mode shows both panes at 60fps. God Loop runs audit→fix→preview→verify cycle. Combined video evidence. |

Each wave: build green → simulator run → screenshot/video → update BUILD_STATE/TASK_QUEUE.

---

## 11. File Manifest

**New (7):**

| File | Lines (est.) |
|---|---|
| `Presentation/Mode1_BuildOnDevice/PreviewPaneView.swift` | 120 |
| `Presentation/Mode1_BuildOnDevice/PreviewNavigationDelegate.swift` | 140 |
| `Presentation/Mode1_BuildOnDevice/PreviewToolbarView.swift` | 90 |
| `Presentation/Mode1_BuildOnDevice/PreviewModeToggle.swift` | 65 |
| `Presentation/Mode1_BuildOnDevice/ConsoleDrawerView.swift` | 130 |
| `Bridge/PreviewBridge.swift` | 280 |
| `Resources/preview-bootstrap.js` | 120 |

**Modified (3):**

| File | Change |
|---|---|
| `Presentation/Mode1_BuildOnDevice/BuildOnDeviceScreen.swift` | Add toggle, ZStack, split layout, console state |
| `Bridge/ForgeEngine.swift` | Add `previewWebView` property, 5 new switch cases, `showPreview()`/`hidePreview()`, `reloadPreview()`, `loadPreviewBlank()` |
| `Theme/ForgeTheme.swift` | Add `previewToolbarBg`, `consoleDrawerBg` tokens |

**Resources (1):**

| File | Purpose |
|---|---|
| `Resources/vendor/three.module.js` | Bundled Three.js for offline 3D rendering |

---

## 12. Risk Register

| Risk | L | I | Mitigation |
|---|---|---|---|
| Two WKWebViews exceed memory on iPhone SE | M | H | Lazy preview creation. Monitor with `task_vm_info`. Under memory pressure: suspend preview WebView (`webView.evaluateJavaScript("window.__forgePreviewSuspend && window.__forgePreviewSuspend()")`), release GL contexts. |
| WKWebView blocks `getUserMedia` / `WebAudio` without user gesture | L | M | Preview content that needs audio must call `AudioContext.resume()` on first touch. Document in FORGE identity. |
| Three.js bundle size bloats app binary | L | L | Ship minified `three.module.js` (~600KB). Only loaded when preview requests it. |
| Agent writes HTML with external CDN links | M | M | CSP meta tag blocks external loads. FORGE identity explicitly forbids CDN. Navigation delegate cancels external requests. |
| `loadFileURL` read access too broad | L | H | `allowingReadAccessTo` is scoped to the file's parent directory ONLY. Never the project root. Never Documents. |
| Console flood from 60fps game loop | M | M | Throttle: 500ms batch window, 10-line cap per batch, source suppression after 50 lines/5s. |
| Preview WebView retains state across `renderPreview` calls | L | M | Every `renderPreview` call loads a fresh page. No `history.pushState`. No SPA routing. |
| App Store review flags preview as "arbitrary code execution" | M | H | Preview renders web content in WKWebView sandbox — identical to Safari. No native code execution. Position as "built-in web preview for code editor", same as Xcode's canvas preview. |

---

## 13. Test Specifications

### 13.1 Unit Tests — PreviewBridgeTests.swift

```swift
func testRenderPreviewResolvesPath() throws {
    let bridge = PreviewBridge(projectRoot: "/tmp/forge-test")
    let resolved = bridge.resolveProjectPath("space-invaders/index.html")
    XCTAssertEqual(resolved, "/tmp/forge-test/space-invaders/index.html")
}

func testRenderPreviewRejectsMissingFile() async {
    let bridge = PreviewBridge(projectRoot: "/tmp/forge-test")
    // renderPreview("nonexistent.html") → reject with "file not found"
}

func testRenderPreviewRejectsLargeFile() async {
    // Write 6MB file → renderPreview → reject with "file too large"
}

func testAutoDetectHTML() {
    let bridge = PreviewBridge(projectRoot: "/tmp")
    XCTAssertEqual(bridge.detectRenderMode(path: "index.html", mode: "auto"), "html")
    XCTAssertEqual(bridge.detectRenderMode(path: "game.js", mode: "auto"), "js")
    XCTAssertEqual(bridge.detectRenderMode(path: "diagram.svg", mode: "auto"), "svg")
    XCTAssertEqual(bridge.detectRenderMode(path: "README.md", mode: "auto"), "markdown")
    XCTAssertEqual(bridge.detectRenderMode(path: "main.py", mode: "auto"), "raw")
}

func testJSEscapingInTemplate() {
    let bridge = PreviewBridge(projectRoot: "/tmp")
    let html = bridge.wrapRawSource("<script>alert('xss')</script>", path: "test.html")
    XCTAssertFalse(html.contains("<script>alert"))
    XCTAssertTrue(html.contains("&lt;script&gt;"))
}
```

### 13.2 Integration Tests

```swift
func testEndToEndPreviewRender() async throws {
    // 1. Create project directory with index.html
    // 2. Call renderPreview via bridge
    // 3. Assert previewWebView.isLoading == true
    // 4. Wait for didFinish navigation
    // 5. Assert previewMode switched to .preview
}

func testConsoleCapture() async throws {
    // 1. Load HTML with <script>console.log("hello")</script>
    // 2. Wait 1 second
    // 3. Assert consoleEntries contains entry with message "hello"
}

func testInjectPreviewCode() async throws {
    // 1. Load HTML with <script>window.value = 1;</script>
    // 2. Call injectPreviewCode({ js: "window.value = 42;" })
    // 3. Call injectPreviewCode({ js: "window.value" })
    // 4. Assert result == 42
}

func testNavigationBlocked() async throws {
    // 1. Load HTML with <a href="https://example.com" id="link">go</a>
    // 2. Simulate navigation to that URL
    // 3. Assert decidePolicyFor returned .cancel
}
```

### 13.3 UI Tests (XCUITest)

```swift
func testPreviewToggleDisabledWithoutContent() {
    // Launch Mode 1. PREVIEW button should be dimmed and untappable.
}

func testPreviewAppearsAfterAgentRender() {
    // Trigger renderPreview via bridge.
    // Assert PREVIEW toggle becomes active.
    // Assert preview WebView is visible.
}

func testSplitModeShowsBothPanes() {
    // Switch to SPLIT. Assert both terminal and preview are visible.
}

func testConsoleDrawerOpensAndCloses() {
    // Tap console toolbar button. Assert drawer appears.
    // Tap close. Assert drawer disappears.
}

func testReloadButtonReloadsPreview() {
    // Load preview. Tap reload. Assert navigation restarts.
}
```

### 13.4 Adversarial Tests

| Scenario | Expected |
|---|---|
| `renderPreview` with path containing `../` | Rejected. Path traversal blocked. |
| `renderPreview` with 10MB file | Rejected with "file too large". |
| Preview JS enters infinite loop | WKWebView watchdog kills JS after 10s. Error overlay shown. Terminal shows `[preview-error] JavaScript execution timed out`. |
| 50 rapid `injectPreviewCode` calls | All evaluate in order. No dropped calls. No crash. |
| Preview + terminal + Pyodide active simultaneously | Memory stays under 1.2GB on iPhone 15 Pro. No jetsam kill. |
| User backgrounds app during preview render | On foreground return, preview is intact. No white flash. |
| Agent calls `renderPreview` while preview is already loading | Previous load cancelled. New load starts. No orphaned callbacks. |

---

## 14. Compliance Matrix

| Requirement | Source | Wave |
|---|---|---|
| Preview WebView is separate from agent WebView | This spec §2.2 | W1 |
| Preview WebView uses `nonPersistent()` data store | This spec §3.3 | W1 |
| Preview WebView uses isolated `WKProcessPool` | This spec §3.3 | W1 |
| External navigation blocked | This spec §3.4 | W1 |
| Console capture via injected bootstrap | This spec §5 | W2 |
| Console entries appear in drawer AND terminal | This spec §3.6 | W2 |
| JS game template provides `window.canvas` + `window.ctx` | This spec §6.2 | W3 |
| `injectPreviewCode` patches without reload | This spec §4.2 | W4 |
| Split mode renders both panes simultaneously | This spec §3.7 | W5 |
| God Loop VERIFY checks preview for errors | This spec §7.2 | W5 |
| No hardcoded colors outside ForgeTheme | Engineering spec §20 | All |
| All animations use spring(response: 0.3, dampingFraction: 0.8) | Engineering spec §20.3 | All |
| Haptic feedback on all interactive elements | Engineering spec §20.4 | All |

---

## DOCUMENT METADATA

| Field | Value |
|---|---|
| Document ID | FORGE-PREVIEW-SPEC-V1.0 |
| Classification | RUNTIME-GRADE COMPONENT SPECIFICATION |
| Extends | FORGE Engineering Specification v1.0.0 §15 |
| Authoritative For | Preview Pane, Preview Bridge, Console Drawer, Render Modes |
| New Files | 7 Swift + 1 JavaScript |
| Modified Files | 3 |
| Build Time | 4–6 days (5 waves) |
| Dependencies | None beyond existing FORGE stack |

---

**END OF PREVIEW TAB SPECIFICATION v1.0**

*"The agent writes the code. The preview shows the truth. The God Loop verifies both. When the terminal says PASS and the preview renders clean — the work is done."*