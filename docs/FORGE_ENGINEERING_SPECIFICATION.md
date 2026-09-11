# FORGE — Complete Engineering Design Specification

## iOS-Native opencode TUI with Embedded Trident Agent + Mission Control Fleet Commander

**Version:** 1.0.0-MASTER
**Date:** 2026-07-25
**Classification:** RUNTIME-GRADE ENGINEERING SPECIFICATION
**Authority:** SINGLE SOURCE OF TRUTH — this document alone is sufficient to build the entire system
**Status:** APPROVED FOR IMPLEMENTATION
**Target:** iOS 17.0+ / Swift 5.9+ / Xcode 15+

---

## SPEC GOVERNANCE

**This document is self-contained.** An engineer or AI coding agent reading ONLY this spec can build the entire application. No external clarification is required. Every architectural decision, interaction pattern, visual specification, and technical constraint is defined herein.

**Reading order for post-compaction recovery:**
1. Read §1 through §32 of this spec in full
2. Read §31 (Risk Register) for known failure modes
3. Read §30 (Build Sequence) for implementation order
4. Read §29 (File Manifest) for the complete file list

**Hard dependencies (must exist before build):**
- opencode source v1.14.43 (github.com/anomalyco/opencode)
- Trident v4.4.2 SHIP package with v4.4.3 enhancements
- SwiftTerm (github.com/migueldeicaza/SwiftTerm) via SPM
- swift-libgit2 (github.com/swift-developer-tools/swift-libgit2) via SPM
- esbuild >= 0.21.0 (build-time only, runs on Mac)
- Apple Developer Account ($99/year, for code signing + TestFlight)

**Soft dependencies:**
- Tailscale iOS app (for Mission Control mesh networking)
- Physical iPhone running iOS 17+ (for final device testing)
- GitHub Actions macOS runner (for CI/testing without owning a Mac)

---

## TERMINOLOGY — READ BEFORE PROCEEDING

| Term | Definition |
|------|-----------|
| **FORGE** | The iOS application this spec describes. Dual-mode: on-device agent + remote fleet control. |
| **Mode 1** | Build On-Device. A fully self-contained opencode TUI running locally on the iPhone with Trident as the sole agent. No network required for operation (only for LLM API calls). |
| **Mode 2** | Mission Control. A remote fleet command center that connects to opencode servers on other devices via WebSocket, rendering their TUI sessions locally on the iPhone. |
| **forge-bundle.js** | The single JavaScript file produced by esbuild at build time. Contains all of opencode core + Trident plugin + shims. Loaded into the hidden WKWebView at runtime. |
| **Hidden WKWebView** | A WKWebView instance with zero visible area (0x0 frame or offscreen). Used purely as a JavaScript execution environment with JIT, WASM, and Web API support. The user never sees it. |
| **ForgeBridge** | The Swift class implementing WKScriptMessageHandler. The bidirectional communication channel between Swift and JavaScript. Every native operation (file I/O, Git, networking) flows through this bridge. |
| **SwiftTerm** | Miguel de Icaza's native terminal emulator library. Renders ANSI escape sequences as a character grid using CoreText + optional Metal GPU. The user's terminal display. |
| **OpenTUI** | opencode's terminal UI framework (@opentui/solid). Renders SolidJS components to ANSI escape sequences. On iOS, its output is captured from the WKWebView and fed to SwiftTerm. |
| **Trident Plugin** | The sole agent plugin loaded in FORGE. Provides the 18-layer audit engine, God Loop (PASS/LOOP), Poseidon Mode, context synthesis, deep planning, and problem-solving. All vanilla opencode agents are disabled. |
| **Direction-Lock Gesture** | A custom UIGestureRecognizer subclass that determines whether a touch is horizontal (session switch) or vertical (terminal scroll) after a 15-point displacement threshold, then locks to that axis for the remainder of the gesture. |
| **Eagle Vision** | An overview mode in Mission Control. Pinch outward to zoom out from a single session terminal to a grid of all session thumbnails. Pinch inward to zoom back into a session. |
| **ANSI Bridge** | The data pipeline connecting OpenTUI's ANSI output (inside WKWebView) to SwiftTerm's rendering (native UIKit). Output flows WKWebView to JS callback to ForgeBridge to SwiftTerm.feed(). Input flows SwiftTerm to ForgeBridge to evaluateJavaScript to WKWebView. |
| **Subagent** | A secondary agent dispatched by Trident within the same WKWebView process. Runs as an Effect fiber (async task), not a child process. Examples: trident_build, trident_explore, trident_planner. |
| **God Loop** | Trident's autonomous quality enforcement cycle: AUDIT to SCORE to DECIDE to PLAN to EXECUTE to VERIFY to LOOP/PASS. Runs until quality grade >= 96% or 10 cycles reached. |
| **Vanilla Agents** | opencode's built-in default agents: build (full-access), plan (read-only), general (subagent). These are DISABLED via configuration in FORGE. Trident is the only agent. |

---

## TABLE OF CONTENTS

1. Application Identity and Philosophy
2. Architecture Overview
3. The Hidden WKWebView Layer
4. The esbuild Bundle Pipeline
5. The opencode iOS Adaptation
6. The Trident Plugin Integration
7. The SwiftTerm Integration
8. The ANSI Bridge
9. The Swift Bridge Layer (ForgeBridge)
10. The File System Layer
11. The Git Integration (libgit2)
12. The Networking Layer
13. The Keychain Layer
14. Code Execution (Python via Pyodide)
15. Mode 1: Build On-Device
16. Mode 2: Mission Control
17. Launch Menu
18. The Gesture System
19. Eagle Vision
20. The Theme System
21. The Settings Sheet
22. Project Management
23. iCloud Sync
24. Error Handling and Recovery
25. Background Execution and Lifecycle
26. Info.plist and Entitlements
27. App Store Review Strategy
28. Testing Requirements
29. File Manifest
30. Build Sequence
31. Risk Register
32. Configuration Reference

---

## 1. APPLICATION IDENTITY AND PHILOSOPHY

### 1.1 What FORGE Is

FORGE is a native iOS application written in Swift using SwiftUI for the presentation layer and UIKit for terminal rendering and gesture handling. It is a single binary distributed through the App Store or TestFlight. The app has exactly two operational modes, selectable from a launch menu, and these modes share no runtime state with each other.

The app's visual identity is a deep-space dark theme built on a near-black background color of hex 0A0A0F, with electric cyan 00F0FF as the sole accent color. All typography uses a monospaced font family — JetBrains Mono loaded as a bundled resource, falling back to SF Mono. The app should feel like a piece of military-grade command software, not a consumer productivity tool.

### 1.2 Design Principles

1. **The iPhone IS the computer.** In Mode 1, the device runs the complete opencode agent locally. No cloud compute. No remote dependency beyond the LLM API call. The agent reads files from the local sandbox, writes to local storage, executes Python via Pyodide WASM, and runs the full Trident God Loop on-device.

2. **The terminal is native, not web.** The terminal is rendered by SwiftTerm — a native UIKit view with Metal GPU acceleration. The JavaScript engine (WKWebView) is hidden and invisible. The user never sees a web page. The user sees a terminal.

3. **Trident is the only agent.** opencode's vanilla build, plan, and general agents are disabled via configuration. Trident is the sole primary agent. Its subagents (trident_build, trident_explore, trident_planner) run as in-process async tasks within the same JavaScript context.

4. **Full subagent support.** Trident's subagent system is fully preserved. Subagents run as Effect fibers within the WKWebView's JavaScript context. No process spawning. No child processes. No PTY required.

5. **Every animation uses spring physics.** Response time 0.3 to 0.4 seconds, damping fraction 0.8. Haptic feedback (medium intensity UIImpactFeedbackGenerator) fires on every button press, session switch, and mode transition.

6. **No permissions at launch.** The app requests no permissions when first opened. Network access requires no prompt. File access is within the sandbox. iCloud sync uses the iCloud entitlement (no runtime prompt). OAuth flows use ASWebAuthenticationSession.

7. **There is no light mode.** The dark theme is the only theme.

### 1.3 Supported Devices

- iPhone running iOS 17.0 or later (primary target)
- iPad running iPadOS 17.0 or later (supports all orientations)
- Apple Silicon Mac (via "Designed for iPad" — automatic, no separate Mac target needed)

---

## 2. ARCHITECTURE OVERVIEW

### 2.1 The Three-Layer Architecture

FORGE is built in three layers. Each layer has a single, well-defined responsibility.

```
+--------------------------------------------------------------------+
|                    LAYER 1: PRESENTATION                           |
|                                                                    |
|  SwiftUI Views                    UIKit Views (UIViewRepresentable) |
|  +- LaunchMenu                    +- TerminalScreen (SwiftTerm)     |
|  +- SettingsSheet                 +- SessionPager (gestures)        |
|  +- ServerPickerSheet             +- EagleVisionGrid                |
|  +- ProjectManager                +- DirectionLockGestureRecognizer |
|                                                                    |
|  Theme System: 0A0A0F bg, 00F0FF accent, JetBrains Mono            |
+----------------------------------+---------------------------------+
                                   |
                    ANSI output / keyboard input
                                   |
+----------------------------------v---------------------------------+
|                    LAYER 2: BRIDGE                                 |
|                                                                    |
|  ForgeBridge.swift (WKScriptMessageHandler)                        |
|  +- JS to Swift: window.webkit.messageHandlers.native.postMessage()|
|  +- Swift to JS: webView.evaluateJavaScript()                      |
|  +- File operations (FileManager)                                  |
|  +- Git operations (swift-libgit2)                                 |
|  +- Command runner (curated shell commands)                        |
|  +- Network proxy (URLSession)                                     |
|  +- Keychain access                                                |
|  +- Share sheet (UIActivityViewController)                         |
|  +- Cloud storage (Google Drive, Dropbox SDKs)                     |
+----------------------------------+---------------------------------+
                                   |
                    native calls / JS responses
                                   |
+----------------------------------v---------------------------------+
|                    LAYER 3: EXECUTION                              |
|                                                                    |
|  Hidden WKWebView (0x0 frame, offscreen)                           |
|  +- forge-bundle.js (esbuild output — single file)                 |
|  |   +- opencode core (sessions, config, tools, Effect runtime)    |
|  |   +- Trident plugin (18-layer audit, God Loop, Poseidon)        |
|  |   +- OpenTUI (SolidJS to ANSI escape sequences)                 |
|  |   +- web-tree-sitter (WASM code parser)                         |
|  |   +- Vercel AI SDK (LLM provider via fetch)                     |
|  |   +- Node.js shims (fs to bridge, crypto to WebCrypto)          |
|  +- WKWebView provides: JIT, WASM, fetch, crypto.subtle            |
+--------------------------------------------------------------------+
```

### 2.2 Why WKWebView (Not Standalone JSContext)

This is the most critical architectural decision in the entire spec.

**Standalone JSContext** (the JavaScriptCore.framework API used directly in Swift) is fundamentally inadequate for running opencode:

| Capability | Standalone JSContext | WKWebView (hidden) | Why It Matters |
|-----------|---------------------|---------------------|----------------|
| JIT compilation | NO (LLInt only) | YES (Baseline to DFG to FTL) | Effect.ts runtime, OpenTUI SolidJS, AI SDK parsers need JIT for acceptable performance. Without JIT, execution is 5-15x slower. |
| WebAssembly | NO (unreliable/absent) | YES (full WASM 1.0) | web-tree-sitter (opencode's code parser) is a WASM module. Without WASM, the audit engine cannot parse source files. |
| fetch() | NO (must build from scratch) | YES (native) | The Vercel AI SDK uses fetch() for all LLM API calls. Building a fetch polyfill is weeks of work. |
| crypto.subtle | NO (must bridge CryptoKit) | YES (native Web Crypto) | API key hashing, token generation, cryptographic operations needed by AI SDK providers. |
| TextEncoder/TextDecoder | NO (must polyfill) | YES (native) | Used extensively by opencode for string/byte conversions. |
| setTimeout/setInterval | NO (must implement) | YES (native) | Needed by Effect.ts runtime for async scheduling. |
| Promise microtasks | Partially (needs run loop spinning) | YES (native event loop) | Effect.ts is entirely Promise-based. Broken microtask scheduling breaks the entire runtime. |

**The WKWebView is never visible.** It is created with a CGRect.zero frame and added to the view hierarchy offscreen. It exists solely as a JavaScript sandbox. All visible UI is rendered by SwiftTerm (Layer 1). The user sees a native terminal, not a web page.

### 2.3 Data Flow — Complete Cycle

A single user interaction flows through all three layers:

```
User types "audit this codebase" on keyboard
    |
    v
SwiftTerm captures keystroke via TerminalViewDelegate.send(source:data:)
    |
    v
ForgeBridge sends keystroke to WKWebView:
    webView.evaluateJavaScript("window.__forgeInput('...')")
    |
    v
Inside WKWebView:
    forge-bundle.js receives input via window.__forgeInput callback
    +- opencode routes to Trident agent
    +- Trident starts God Loop: AUDIT phase
    +- web-tree-sitter parses project files
    +- 18-layer audit engine produces findings
    +- OpenTUI renders results as SolidJS components to ANSI strings
    +- ANSI output captured by window.__forgeOutput callback
    |
    v
WKScriptMessageHandler receives "output" message:
    { method: "output", data: "\u001b[32mAUDIT PASS\u001b[0m\n..." }
    |
    v
ForgeBridge routes to SwiftTerm:
    terminalView.feed(text: ansiString)  // thread-safe
    |
    v
SwiftTerm renders ANSI escape sequences as colored terminal characters
    |
    v
User sees audit results in native terminal
```

### 2.4 Mode 2 Data Flow — Remote Sessions

Mission Control does NOT run any JavaScript locally. It connects to remote opencode servers:

```
iPhone (Mission Control)
    |
    +-- NWBrowser discovers "_opencode._tcp" services on local network
    |
    +-- URLSession GET http://rog-laptop:8080/api/sessions
    |   +-- Returns: [{ id, name, active, lastLines, agent }]
    |
    +-- URLSessionWebSocketTask ws://rog-laptop:8080/ws/session/abc123
    |   +- Receives: TUI event messages (ANSI terminal output)
    |   +- Sends: keystroke input from SwiftTerm
    |   +- Sends: resize events (cols, rows)
    |
    +-- SwiftTerm renders remote terminal output natively
        User sees the EXACT TUI from the remote device, in real-time
```

---

## 3. THE HIDDEN WKWEBVIEW LAYER

### 3.1 Configuration

The hidden WKWebView is created and configured in the ForgeEngine class. It must be configured BEFORE any JavaScript is loaded.

```swift
import WebKit

class ForgeEngine: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    private var webView: WKWebView!
    private let bridge: ForgeBridge
    private var outputHandler: ((String) -> Void)?
    private var readyHandler: (() -> Void)?

    init(bridge: ForgeBridge) {
        self.bridge = bridge
        super.init()

        let config = WKWebViewConfiguration()

        // Enable JavaScript and WASM
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        // Allow local file access (for loading bundled resources)
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.preferences.setValue(true, forKey: "allowUniversalAccessFromFileURLs")

        // Inject the ForgeBridge message handler
        config.userContentController.add(self, name: "native")

        // Inject native API before bundle loads
        injectNativeAPI(config.userContentController)

        // Create the WebView with zero frame (hidden)
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self

        // Disable all user interaction (it is invisible)
        webView.isUserInteractionEnabled = false
        webView.scrollView.isScrollEnabled = false

        // Suppress all web content (we only want JS execution)
        webView.evaluateJavaScript(
            "document.documentElement.style.display = 'none'",
            completionHandler: nil
        )
    }

    func loadBundle() {
        guard let bundleURL = Bundle.main.url(
            forResource: "forge-bundle", withExtension: "js"
        ) else {
            fatalError("forge-bundle.js not found in app resources")
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
}
```

### 3.2 The Native API Injection

Before forge-bundle.js loads, we inject a native API object onto window that provides the bridge interface:

```swift
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
```

### 3.3 Message Handler Implementation

```swift
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
            DispatchQueue.main.async { [weak self] in
                self?.outputHandler?(ansi)
            }
        }

    case "__ready":
        DispatchQueue.main.async { [weak self] in
            self?.readyHandler?()
        }

    case "readFile":
        bridge.readFile(args, callbackId: callbackId, webView: webView)
    case "writeFile":
        bridge.writeFile(args, callbackId: callbackId, webView: webView)
    case "listFiles":
        bridge.listFiles(args, callbackId: callbackId, webView: webView)
    case "deleteFile":
        bridge.deleteFile(args, callbackId: callbackId, webView: webView)
    case "searchFiles":
        bridge.searchFiles(args, callbackId: callbackId, webView: webView)
    case "runCommand":
        bridge.runCommand(args, callbackId: callbackId, webView: webView)
    case "gitOperation":
        bridge.gitOperation(args, callbackId: callbackId, webView: webView)
    case "httpRequest":
        bridge.httpRequest(args, callbackId: callbackId, webView: webView)
    case "getSecret":
        bridge.getSecret(args, callbackId: callbackId, webView: webView)
    case "setSecret":
        bridge.setSecret(args, callbackId: callbackId, webView: webView)
    case "shareFile":
        bridge.shareFile(args, callbackId: callbackId, webView: webView)
    case "runPython":
        bridge.runPython(args, callbackId: callbackId, webView: webView)

    default:
        if let cbId = callbackId {
            rejectCallback(cbId, error: "Unknown method: \(method)")
        }
    }
}
```

### 3.4 Callback Resolution

```swift
func resolveCallback(_ callbackId: String, result: Any) {
    let json: String
    if let data = try? JSONSerialization.data(withJSONObject: result),
       let str = String(data: data, encoding: .utf8) {
        json = str
    } else if let str = result as? String {
        json = "\"\(str)\""
    } else {
        json = "null"
    }
    let js = "window.__forgeNative.resolve('\(callbackId)', \(json));"
    webView?.evaluateJavaScript(js, completionHandler: nil)
}

func rejectCallback(_ callbackId: String, error: String) {
    let escaped = error.replacingOccurrences(of: "'", with: "\\'")
    let js = "window.__forgeNative.reject('\(callbackId)', '\(escaped)');"
    webView?.evaluateJavaScript(js, completionHandler: nil)
}
```

### 3.5 Memory and Lifecycle

The WKWebView must be retained for the lifetime of Mode 1. The WebView lives as long as the Build On-Device screen is active.

The WKWebView uses websiteDataStore = .nonPersistent() to prevent persistent storage from accumulating. Session data is managed by opencode's own storage layer (SQLite via SQL.js WASM).

Under memory pressure, hint the JS engine to GC:

```swift
func didReceiveMemoryWarning() {
    webView?.evaluateJavaScript("if (window.gc) { window.gc(); }", completionHandler: nil)
}
```

---

## 4. THE ESBUILD BUNDLE PIPELINE

### 4.1 Overview

The forge-bundle.js is produced at BUILD TIME on the developer's Mac. It is NOT generated on the iOS device. The build script runs as an Xcode Build Phase before "Compile Sources."

The pipeline:

```
opencode source (v1.14.43)
    |
    +-- Trident plugin source (v4.4.2 SHIP + v4.4.3 enhancements)
    |
    +-- forge-entry.ts (custom iOS entry point)
    |
    +-- forge-shims/ (Node.js API replacements)
    |   +- forge-fs.ts (to Swift FileManager bridge)
    |   +- forge-process.ts (to Swift command runner)
    |   +- forge-crypto.ts (to Web Crypto API)
    |   +- forge-os.ts (to hardcoded iOS constants)
    |   +- forge-path.ts (to path-browserify)
    |   +- forge-events.ts (minimal EventEmitter)
    |   +- forge-stream.ts (minimal stream polyfill)
    |   +- forge-http.ts (fetch-based HTTP)
    |   +- forge-url.ts (whatwg-url polyfill)
    |   +- forge-globals.js (process, Buffer injection)
    |   +- forge-sqlite.ts (SQL.js WASM SQLite)
    |   +- forge-noop.ts (empty module for unsupported)
    |
    +-- esbuild (build tool, runs on Mac)
    |   +- platform: 'browser'
    |   +- format: 'iife' (single self-contained file)
    |   +- target: ['safari16'] (iOS 16+ WKWebView)
    |   +- conditions: ['browser', 'default'] (skip bun/node)
    |   +- alias: all Node built-ins to forge-shims
    |   +- inject: process shim, Buffer shim
    |   +- define: process.env.NODE_ENV, process.platform
    |   +- loader: { '.wasm': 'binary', '.txt': 'text', '.md': 'text' }
    |   +- minify: true, sourcemap: 'linked', treeShaking: true
    |
    +-- Output: forge-bundle.js (single file, ~2-4MB minified)
          Copied to: iOS app Resources/ directory
```

### 4.2 The Custom Entry Point (forge-entry.ts)

The entry point replaces opencode's CLI bootstrap (yargs) with a programmatic API. No command-line parsing, no process.argv, no process.exit.

```typescript
// forge-entry.ts

import { Config } from "@opencode-ai/opencode/src/config/config"
import { Session } from "@opencode-ai/opencode/src/session/session"
import { Agent } from "@opencode-ai/opencode/src/agent/agent"
import { Plugin } from "@opencode-ai/opencode/src/plugin/plugin"
import { Provider } from "@opencode-ai/opencode/src/provider/provider"

import * as TridentPlugin from "../../trident/src/index"
import { FORGE_IDENTITY } from "./forge-identity"

import "./forge-shims"

window.__forgeBootstrap = async function() {
    const native = window.__forgeNative

    ;(globalThis as any).__FORGE_IDENTITY__ = FORGE_IDENTITY

    const config = {
        default_agent: "trident",
        agent: {
            build: { disable: true },
            plan: { disable: true },
            general: { disable: true },
        },
        model: {
            provider: await native.call("getSecret", { key: "llm_provider" }) || "anthropic",
            id: await native.call("getSecret", { key: "llm_model" }) || "claude-sonnet-4-20250514",
        },
        permission: { "*": "allow", bash: "allow" },
    }

    const runtime = await initializeForgeRuntime({ config, tridentPlugin: TridentPlugin, nativeBridge: native })
    const terminalSurface = createForgeTerminalSurface()

    window.__forgeOnInput = function(data: string) { runtime.processInput(data) }
    native.ready()
}

function createForgeTerminalSurface() {
    return {
        write: (data: string) => { window.__forgeNative.output(data) },
        getSize: () => ({ cols: window.__forgeCols || 80, rows: window.__forgeRows || 24 }),
        onResize: (cb: (c: number, r: number) => void) => { window.__forgeResizeCallback = cb },
    }
}
```

### 4.3 The FORGE Identity

```typescript
export const FORGE_IDENTITY = `
# FORGE - iOS-Native Trident Agent

You are FORGE. You are a Trident T3 Algorithmic Audit Engine running ON AN iPHONE.

## Your Environment
1. You run inside a WKWebView on iOS. You are NOT on a server. You are on a phone.
2. Your file system is the iOS app sandbox. All file operations go through the Swift bridge.
3. Your code parser is web-tree-sitter (WASM). It works exactly like on desktop.
4. Your LLM calls use the browser fetch() API. Keys come from Swift Keychain.
5. You have NO child processes. The bash tool routes to a Swift command runner.
6. You run the FULL 18-layer audit engine (R0-R17). This is your core power.
7. You run the God Loop: AUDIT -> SCORE -> DECIDE -> PLAN -> EXECUTE -> VERIFY -> LOOP until 96%.

## Your Subagents
- trident_build: Executes remediation plans (reads/writes files, runs code)
- trident_explore: Explores codebases (reads files, searches, analyzes structure)
- trident_planner: Generates L2 engineering specifications

## Your Behavior
1. When given a task, run the God Loop autonomously until 96% quality or 10 cycles.
2. Display phase transitions: AUDIT (yellow), WORKING (cyan), VERIFY (yellow), GRADE (green/red).
3. Checkpoint via Git after every God Loop cycle. Revert on regression.
4. You are battery-aware. Be efficient. Skip irrelevant audit layers when possible.
5. You identify as FORGE, not Trident. Trident is your engine.
6. You NEVER claim work is done without the verify grade proving it.
7. The user is a developer holding a phone. Be concise. Terminal output is the only UI.
`
```

### 4.4 esbuild Build Script

```javascript
// scripts/build-forge-bundle.mjs
import * as esbuild from 'esbuild'
import { readdirSync, existsSync, mkdirSync, copyFileSync, statSync } from 'fs'
import { join, resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const ROOT = resolve(__dirname, '..')
const OUT_DIR = join(ROOT, 'iOS', 'FORGE', 'Resources')
const SHIMS_DIR = join(ROOT, 'forge', 'shims')

if (!existsSync(OUT_DIR)) mkdirSync(OUT_DIR, { recursive: true })

const isRelease = process.env.CONFIGURATION === 'Release'

await esbuild.build({
    entryPoints: [join(ROOT, 'forge', 'src', 'forge-entry.ts')],
    bundle: true,
    outfile: join(OUT_DIR, 'forge-bundle.js'),
    platform: 'browser',
    format: 'iife',
    target: ['safari16'],
    minify: isRelease,
    treeShaking: true,
    legalComments: 'none',
    sourcemap: isRelease ? false : 'linked',
    sourcesContent: !isRelease,
    alias: {
        'fs': join(SHIMS_DIR, 'forge-fs.ts'),
        'node:fs': join(SHIMS_DIR, 'forge-fs.ts'),
        'fs/promises': join(SHIMS_DIR, 'forge-fs.ts'),
        'child_process': join(SHIMS_DIR, 'forge-process.ts'),
        'node:child_process': join(SHIMS_DIR, 'forge-process.ts'),
        'crypto': join(SHIMS_DIR, 'forge-crypto.ts'),
        'node:crypto': join(SHIMS_DIR, 'forge-crypto.ts'),
        'os': join(SHIMS_DIR, 'forge-os.ts'),
        'node:os': join(SHIMS_DIR, 'forge-os.ts'),
        'path': 'path-browserify',
        'node:path': 'path-browserify',
        'http': join(SHIMS_DIR, 'forge-http.ts'),
        'node:http': join(SHIMS_DIR, 'forge-http.ts'),
        'https': join(SHIMS_DIR, 'forge-http.ts'),
        'net': join(SHIMS_DIR, 'forge-noop.ts'),
        'node:net': join(SHIMS_DIR, 'forge-noop.ts'),
        'tls': join(SHIMS_DIR, 'forge-noop.ts'),
        'stream': join(SHIMS_DIR, 'forge-stream.ts'),
        'node:stream': join(SHIMS_DIR, 'forge-stream.ts'),
        'events': join(SHIMS_DIR, 'forge-events.ts'),
        'node:events': join(SHIMS_DIR, 'forge-events.ts'),
        'url': join(SHIMS_DIR, 'forge-url.ts'),
        'util': join(SHIMS_DIR, 'forge-util.ts'),
        'buffer': join(SHIMS_DIR, 'forge-buffer.ts'),
        'zlib': join(SHIMS_DIR, 'forge-noop.ts'),
        'bun:sqlite': join(SHIMS_DIR, 'forge-sqlite.ts'),
    },
    inject: [join(SHIMS_DIR, 'forge-globals.js')],
    define: {
        'process.env.NODE_ENV': isRelease ? '"production"' : '"development"',
        'process.env.FORGE': '"true"',
        'process.platform': '"darwin"',
        'process.arch': '"arm64"',
        'global': 'globalThis',
        '__dirname': '"/"',
        '__filename': '"/forge-bundle.js"',
    },
    conditions: ['browser', 'default'],
    loader: {
        '.wasm': 'binary',
        '.txt': 'text',
        '.md': 'text',
        '.sql': 'text',
        '.json': 'json',
        '.node': 'empty',
    },
    logLevel: 'info',
    metafile: true,
})

// Copy binary resources (tree-sitter WASM, Pyodide, etc.)
function copyBinaryResources() {
    const resources = [
        ['node_modules/web-tree-sitter/tree-sitter.wasm', 'tree-sitter.wasm'],
    ]
    for (const [src, dest] of resources) {
        const srcPath = join(ROOT, src)
        if (existsSync(srcPath)) copyFileSync(srcPath, join(OUT_DIR, dest))
    }
}
copyBinaryResources()

const outputFile = join(OUT_DIR, 'forge-bundle.js')
const sizeKB = Math.round(statSync(outputFile).size / 1024)
console.log(`FORGE bundle built: ${sizeKB} KB`)
```

### 4.5 Xcode Build Phase

```bash
# Build Phase: Build FORGE JavaScript Bundle (before Compile Sources)
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:$HOME/.bun/bin"

if command -v bun &> /dev/null; then
    RUNTIME="bun"
elif command -v node &> /dev/null; then
    RUNTIME="node"
else
    echo "error: Neither bun nor node found."
    exit 1
fi

cd "$SRCROOT"
$RUNTIME scripts/build-forge-bundle.mjs

if [ ! -f "$SRCROOT/iOS/FORGE/Resources/forge-bundle.js" ]; then
    echo "error: forge-bundle.js not generated"
    exit 1
fi
```

### 4.6 The File System Shim (forge-fs.ts)

```typescript
// forge/shims/forge-fs.ts
const native = (globalThis as any).__forgeNative

const __fileCache: Record<string, any> = {}
const __dirCache: Record<string, string[]> = {}

export async function readFile(path: string): Promise<string> {
    const result = await native.call('readFile', { path })
    __fileCache[path] = result
    return result as string
}

export function readFileSync(path: string): string {
    if (__fileCache[path] !== undefined) return __fileCache[path]
    throw new Error(`File not in cache (sync read): ${path}`)
}

export async function writeFile(path: string, data: string): Promise<void> {
    await native.call('writeFile', { path, content: data })
    __fileCache[path] = data
}

export function writeFileSync(path: string, data: string): void {
    native.call('writeFile', { path, content: data })
    __fileCache[path] = data
}

export async function readdir(path: string): Promise<string[]> {
    const result = await native.call('listFiles', { path })
    const names = (result as any[]).map(i => i.name)
    __dirCache[path] = names
    return names
}

export function readdirSync(path: string): string[] {
    return __dirCache[path] || []
}

export function existsSync(path: string): boolean {
    return __fileCache[path] !== undefined
}

export async function stat(path: string): Promise<any> {
    const parent = path.split('/').slice(0, -1).join('/')
    const name = path.split('/').pop()
    const items = await native.call('listFiles', { path: parent })
    const item = (items as any[]).find(i => i.name === name)
    if (!item) throw new Error(`ENOENT: ${path}`)
    return {
        isFile: () => !item.isDirectory,
        isDirectory: () => item.isDirectory,
        size: item.size || 0,
        mtime: new Date(item.modified || Date.now()),
    }
}

export async function unlink(path: string): Promise<void> {
    await native.call('deleteFile', { path })
    delete __fileCache[path]
}

export async function mkdir(path: string): Promise<void> {
    await native.call('writeFile', { path: path + '/.gitkeep', content: '' })
}

export function watch(path: string, cb: (event: string, filename: string) => void) {
    let lastTime = Date.now()
    const interval = setInterval(async () => {
        try {
            const s = await stat(path)
            if (s.mtime.getTime() > lastTime) {
                lastTime = s.mtime.getTime()
                cb('change', path)
            }
        } catch {}
    }, 1000)
    return { close: () => clearInterval(interval) }
}

export default {
    readFile, readFileSync, writeFile, writeFileSync, readdir, readdirSync,
    existsSync, stat, unlink, mkdir, watch,
    promises: { readFile, writeFile, readdir, stat, unlink, mkdir },
}
```

### 4.7 The Process Shim (forge-process.ts)

```typescript
const native = (globalThis as any).__forgeNative

export async function exec(command: string): Promise<{ stdout: string; stderr: string }> {
    const result = await native.call('runCommand', { command })
    return { stdout: result.stdout || '', stderr: result.stderr || '' }
}

export function execSync(command: string): string {
    console.warn('execSync not supported on iOS: ' + command)
    return ''
}

export default { exec, execSync }
```

### 4.8 The Crypto Shim (forge-crypto.ts)

```typescript
export const webcrypto = crypto

export function randomUUID(): string {
    return crypto.randomUUID()
}

export function getRandomValues(arr: Uint8Array): Uint8Array {
    return crypto.getRandomValues(arr)
}

export function createHash(algorithm: string) {
    const encoder = new TextEncoder()
    let data: Uint8Array = new Uint8Array(0)
    return {
        update(input: string | Uint8Array): any {
            const bytes = typeof input === 'string' ? encoder.encode(input) : input
            const combined = new Uint8Array(data.length + bytes.length)
            combined.set(data)
            combined.set(bytes, data.length)
            data = combined
            return this
        },
        async digest(encoding?: string): Promise<string> {
            const hashBuffer = await crypto.subtle.digest(
                algorithm === 'sha256' ? 'SHA-256' :
                algorithm === 'sha1' ? 'SHA-1' : 'SHA-256', data
            )
            return Array.from(new Uint8Array(hashBuffer))
                .map(b => b.toString(16).padStart(2, '0')).join('')
        }
    }
}

export default { webcrypto, randomUUID, getRandomValues, createHash }
```

### 4.9 The Globals Injection (forge-globals.js)

```javascript
const processShim = {
    env: {
        NODE_ENV: 'production',
        FORGE: 'true',
        HOME: '/tmp',
        TMPDIR: '/tmp',
        PWD: '/',
        PATH: '/usr/bin:/bin',
    },
    platform: 'darwin',
    arch: 'arm64',
    version: 'v20.0.0',
    pid: 1,
    cwd: () => '/',
    argv: ['forge'],
    stdout: {
        write: (data) => {
            if (typeof window !== 'undefined' && window.__forgeNative)
                window.__forgeNative.output(String(data))
        },
        isTTY: true, columns: 80, rows: 24,
    },
    stderr: {
        write: (data) => {
            if (typeof window !== 'undefined' && window.__forgeNative)
                window.__forgeNative.output(String(data))
        },
        isTTY: true,
    },
    stdin: { on: () => {}, resume: () => {}, pipe: () => {} },
    exit: (code) => { console.log('[FORGE] process.exit(' + code + ') ignored') },
    on: () => {},
    nextTick: (fn) => { Promise.resolve().then(fn) },
}

class BufferShim extends Uint8Array {
    static from(data, encoding) {
        if (typeof data === 'string') return new BufferShim(new TextEncoder().encode(data))
        return new BufferShim(data)
    }
    static alloc(size) { return new BufferShim(size) }
    static allocUnsafe(size) { return new BufferShim(size) }
    static isBuffer(x) { return x instanceof Uint8Array }
    static concat(list) {
        let total = 0
        for (const item of list) total += item.length
        const result = new BufferShim(total)
        let offset = 0
        for (const item of list) { result.set(item, offset); offset += item.length }
        return result
    }
    toString() { return new TextDecoder().decode(this) }
}

export { processShim as 'process', BufferShim as 'Buffer' }
```

### 4.10 The Events Shim (forge-events.ts)

```typescript
export class EventEmitter {
    private _l: Map<string, Function[]> = new Map()
    on(e: string, fn: Function): this {
        if (!this._l.has(e)) this._l.set(e, [])
        this._l.get(e)!.push(fn)
        return this
    }
    once(e: string, fn: Function): this {
        const wrapper = (...a: any[]) => { fn(...a); this.off(e, wrapper) }
        return this.on(e, wrapper)
    }
    off(e: string, fn: Function): this {
        const l = this._l.get(e)
        if (l) { const i = l.indexOf(fn); if (i >= 0) l.splice(i, 1) }
        return this
    }
    emit(e: string, ...a: any[]): boolean {
        let called = false
        const l = this._l.get(e)
        if (l) { for (const fn of [...l]) { fn(...a); called = true } }
        return called
    }
    removeAllListeners(e?: string): this {
        if (e) this._l.delete(e); else this._l.clear()
        return this
    }
}
export default { EventEmitter }
```

### 4.11 The SQLite Shim (forge-sqlite.ts)

```typescript
// Replaces bun:sqlite with SQL.js (WASM SQLite)
let SQL: any = null
let db: any = null

async function getSQL() {
    if (SQL) return SQL
    const wasmResponse = await fetch('sql-wasm.wasm')
    const wasmBuffer = await wasmResponse.arrayBuffer()
    const sqlJs = await import('sql.js')
    SQL = await sqlJs.default({ wasmBinary: wasmBuffer })
    return SQL
}

export class Database {
    constructor(public path: string) {}

    async init() {
        const sql = await getSQL()
        try {
            const data = await (globalThis as any).__forgeNative.call('readFile', { path: this.path })
            if (data) {
                const bytes = new Uint8Array(data.length)
                for (let i = 0; i < data.length; i++) bytes[i] = data.charCodeAt(i)
                db = new sql.Database(bytes)
            } else {
                db = new sql.Database()
            }
        } catch { db = new sql.Database() }
    }

    prepare(sql: string) {
        return {
            all: (...params: any[]) => {
                const stmt = db.prepare(sql)
                stmt.bind(params)
                const results = []
                while (stmt.step()) results.push(stmt.getAsObject())
                stmt.free()
                return results
            },
            run: (...params: any[]) => {
                db.run(sql, params)
                return { changes: db.getRowsModified() }
            },
            get: (...params: any[]) => {
                const stmt = db.prepare(sql)
                stmt.bind(params)
                const r = stmt.step() ? stmt.getAsObject() : null
                stmt.free()
                return r
            },
        }
    }

    async persist() {
        const data = db.export()
        const content = String.fromCharCode.apply(null, data as any)
        await (globalThis as any).__forgeNative.call('writeFile', { path: this.path, content })
    }
}

export default { Database }
```

---

## 5. THE OPENCODE iOS ADAPTATION

### 5.1 What Changes vs What Stays

| Component | Status | Approach |
|-----------|--------|----------|
| Agent registry | UNCHANGED | Config-driven: disable vanilla agents, set Trident default |
| Tool system | UNCHANGED | Tool dispatcher works as-is; individual tools shimmed |
| Session management | MODIFIED | Database driver swapped to SQL.js WASM |
| Effect runtime | UNCHANGED | Pure TypeScript, works in WKWebView |
| Plugin loader | MODIFIED | Pre-bundle Trident; no dynamic import() |
| CLI entry (yargs) | REPLACED | Programmatic bootstrap (forge-entry.ts) |
| TUI worker | ELIMINATED | Run in-process; RPC becomes direct function calls |
| HTTP server | BYPASSED | Call handler directly: app.fetch(request) |
| Config loading | SIMPLIFIED | Bundled default + user overrides in Documents |
| LLM providers | UNCHANGED | Uses fetch() (available natively in WKWebView) |
| web-tree-sitter | UNCHANGED | WASM-based, designed for browsers |

### 5.2 Eliminating the TUI Worker

opencode runs the TUI in a Web Worker thread, communicating with the main agent logic via postMessage RPC. On iOS in WKWebView, we eliminate this. Everything runs in the main JavaScript context. The RPC layer becomes direct function calls.

This is valid because:
1. The TUI rendering (OpenTUI/SolidJS) is pure CPU work — it does not need a separate thread for correctness
2. The agent logic (Effect fibers, LLM calls) is async — it yields the event loop naturally
3. SwiftTerm rendering happens on the Swift main thread — it does not compete with JavaScript execution

### 5.3 Bypassing the HTTP Server

opencode's server mode creates an HTTP server using node:http.createServer(). We do not need this for Mode 1. Instead, we call the internal handler directly:

```typescript
const forgeServer = {
    async handle(method: string, path: string, body?: any): Promise<any> {
        const url = `http://localhost:0${path}`
        const request = new Request(url, {
            method,
            body: body ? JSON.stringify(body) : undefined,
            headers: { 'Content-Type': 'application/json' }
        })
        const app = getOpencodeServerApp()
        const response = await app.fetch(request)
        return response.json()
    }
}
;(globalThis as any).__forgeServer = forgeServer
```

### 5.4 Config Loading — Simplified

opencode's config system loads from multiple sources. On iOS, we simplify to two sources:

1. Bundled default config — shipped in the app
2. User overrides — in the app's Documents directory (forge-config.json)

```json
{
    "default_agent": "trident",
    "agent": {
        "build": { "disable": true },
        "plan": { "disable": true },
        "general": { "disable": true }
    },
    "permission": {
        "*": "allow",
        "bash": "allow",
        "read": { "*": "allow", "*.env": "ask", "*.env.*": "ask" },
        "edit": { "*": "allow" }
    }
}
```

### 5.5 Plugin Loading — Pre-Bundled

opencode's plugin loader uses dynamic import(). On iOS, dynamic import() is not available with esbuild format: 'iife'. We pre-bundle the Trident plugin at build time and register it via a lookup table:

```typescript
import * as TridentPlugin from "../../trident/src/index"

const pluginRegistry: Record<string, any> = {
    'trident': TridentPlugin,
    '@forge/trident': TridentPlugin,
}
;(globalThis as any).__forgePluginRegistry = pluginRegistry
```

---

## 6. THE TRIDENT PLUGIN INTEGRATION

### 6.1 What Is Included

| Component | Status | Notes |
|-----------|--------|-------|
| 18-layer audit engine (R0-R17) | INCLUDED | Full AST-based code analysis via web-tree-sitter WASM |
| God Loop (PASS/LOOP) | INCLUDED | Autonomous quality enforcement cycle |
| Poseidon Mode | INCLUDED | God Loop orchestrator with multi-wave dispatch |
| Context Synthesis (T1/T2) | INCLUDED | T1 injectable context generation |
| Deep Planning (L1/L2/L3) | INCLUDED | Engineering specification generation |
| Problem Solving (6-layer) | INCLUDED | Systematic debugging and analysis |
| trident_build subagent | INCLUDED | Executes remediation plans |
| trident_explore subagent | INCLUDED | Codebase exploration and search |
| trident_planner subagent | INCLUDED | L2 engineering spec generation |
| 8 hooks | INCLUDED | system.transform, tool.before, tool.after, etc. |
| Hive Mind integration | EXCLUDED | Requires OpenViking server |
| Container testing | EXCLUDED | Docker does not exist on iOS |
| trident-container-test tool | EXCLUDED | Not applicable |

### 6.2 How Subagents Work on iOS

Subagents in opencode are NOT child processes. They are Effect fibers — lightweight async tasks running within the same JavaScript context. This is the key insight that makes subagents work on iOS without process spawning.

```
Trident (primary agent)
    |
    +-- dispatches trident_build subagent
    |   +-- Effect runtime creates a new fiber
    |       +- New session context (own messages, own tools)
    |       +- Same LLM provider (shares API key)
    |       +- Same file system (shares project directory)
    |       +-- Returns result to parent when complete
    |
    +-- dispatches trident_explore subagent (parallel)
    |   +-- Effect runtime creates another fiber
    |       +- Read-only tool access
    |       +- Searches files via Swift bridge
    |       +-- Returns findings to parent
    |
    +-- Both subagents run concurrently as Effect fibers
        No fork. No exec. No child processes. No PTY.
```

### 6.3 Trident Tool Adaptations

| Trident Tool | iOS Status | Notes |
|-------------|------------|-------|
| trident-code-audit | Works as-is | tree-sitter WASM + bridge |
| trident-deep-planning | Works as-is | bridge + fetch |
| trident-problem-solving | Works as-is | Pure logic |
| trident-context-synthesis | Works as-is | bridge + WASM |
| trident-poseidon | Works as-is | Effect fiber dispatch |
| trident-gate | Works as-is | Pure logic |
| trident-status | Works as-is | Pure logic |

### 6.4 The FORGE Identity Override

Trident's identity blocks are overridden with the FORGE identity via opencode's hook system:

```typescript
hooks.on("system.transform", (input) => {
    if (input.system && input.system.length > 0) {
        input.system = [FORGE_IDENTITY]
    }
    return input
})
```

---

## 7. THE SWIFTTERM INTEGRATION

### 7.1 Overview

SwiftTerm (github.com/migueldeicaza/SwiftTerm) is a native terminal emulator for iOS. It provides full VT100/xterm ANSI support, Metal GPU rendering, thread-safe feed(), keyboard accessory bar, custom fonts, and full color palette customization.

### 7.2 SPM Integration

Add via Xcode: File -> Add Package Dependencies -> https://github.com/migueldeicaza/SwiftTerm

### 7.3 The UIViewRepresentable Wrapper

SwiftTerm's built-in SwiftUI wrapper is marked #if DEBUG. We write our own production wrapper:

```swift
import SwiftUI
import SwiftTerm

struct ForgeTerminalView: UIViewRepresentable {
    @Binding var terminalView: TerminalView?
    var onSend: ((Data) -> Void)?
    var onResize: ((Int, Int) -> Void)?

    func makeUIView(context: Context) -> TerminalView {
        let view = TerminalView(frame: .zero)
        view.terminalDelegate = context.coordinator
        view.font = UIFont(name: "JetBrainsMono-Regular", size: 14)
            ?? UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        view.nativeBackgroundColor = UIColor(red: 0x0A/255, green: 0x0A/255, blue: 0x0F/255, alpha: 1.0)
        view.nativeForegroundColor = UIColor(red: 0xE0/255, green: 0xE0/255, blue: 0xE0/255, alpha: 1.0)
        view.selectedTextBackgroundColor = UIColor(red: 0x00/255, green: 0xF0/255, blue: 0xFF/255, alpha: 0.2)
        view.installColors(ForgeTheme.ansiColors)
        do { try view.setUseMetal(true) } catch { print("Metal unavailable: \(error)") }
        view.changeScrollback(5000)
        view.scrollView.bounces = true
        view.scrollView.alwaysBounceHorizontal = false
        DispatchQueue.main.async { self.terminalView = view }
        return view
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onSend: onSend, onResize: onResize) }

    final class Coordinator: NSObject, TerminalViewDelegate {
        let onSend: ((Data) -> Void)?
        let onResize: ((Int, Int) -> Void)?
        init(onSend: ((Data) -> Void)?, onResize: ((Int, Int) -> Void)?) {
            self.onSend = onSend; self.onResize = onResize
        }
        func send(source: TerminalView, data: ArraySlice<UInt8>) { onSend?(Data(data)) }
        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) { onResize?(newCols, newRows) }
        func setTerminalTitle(source: TerminalView, title: String) {}
        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
            if let url = URL(string: link) { UIApplication.shared.open(url) }
        }
        func bell(source: TerminalView) { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        func clipboardCopy(source: TerminalView, content: Data) {
            UIPasteboard.general.string = String(data: content, encoding: .utf8)
        }
        func clipboardRead(source: TerminalView) -> Data? {
            return UIPasteboard.general.string?.data(using: .utf8)
        }
        func scrolled(source: TerminalView, position: Double) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}
        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    }
}
```

### 7.4 The FORGE ANSI Color Palette

```swift
struct ForgeTheme {
    static let ansiColors: [SwiftTerm.Color] = [
        SwiftTerm.Color(red8: 0x1A, green8: 0x1A, blue8: 0x24),  // 0: Black
        SwiftTerm.Color(red8: 0xFF, green8: 0x55, blue8: 0x55),  // 1: Red
        SwiftTerm.Color(red8: 0x50, green8: 0xFA, blue8: 0x7B),  // 2: Green
        SwiftTerm.Color(red8: 0xF1, green8: 0xFA, blue8: 0x8C),  // 3: Yellow
        SwiftTerm.Color(red8: 0x00, green8: 0xF0, blue8: 0xFF),  // 4: Blue/Cyan accent
        SwiftTerm.Color(red8: 0xFF, green8: 0x79, blue8: 0xC6),  // 5: Magenta
        SwiftTerm.Color(red8: 0x8B, green8: 0xE9, blue8: 0xFD),  // 6: Cyan light
        SwiftTerm.Color(red8: 0xE0, green8: 0xE0, blue8: 0xE0),  // 7: White
        SwiftTerm.Color(red8: 0x28, green8: 0x28, blue8: 0x32),  // 8: Bright black
        SwiftTerm.Color(red8: 0xFF, green8: 0x6E, blue8: 0x6E),  // 9: Bright red
        SwiftTerm.Color(red8: 0x69, green8: 0xFF, blue8: 0x94),  // 10: Bright green
        SwiftTerm.Color(red8: 0xFF, green8: 0xFA, blue8: 0x6C),  // 11: Bright yellow
        SwiftTerm.Color(red8: 0x00, green8: 0xFF, blue8: 0xFF),  // 12: Bright blue
        SwiftTerm.Color(red8: 0xFF, green8: 0x92, blue8: 0xD0),  // 13: Bright magenta
        SwiftTerm.Color(red8: 0xA4, green8: 0xFF, blue8: 0xFF),  // 14: Bright cyan
        SwiftTerm.Color(red8: 0xFF, green8: 0xFF, blue8: 0xFF),  // 15: Bright white
    ]
}
```

### 7.5 Feeding Data and Capturing Input

```swift
// Feeding ANSI from WKWebView to SwiftTerm (thread-safe):
func handleANSIOutput(_ ansi: String) {
    terminalView?.feed(text: ansi)  // Thread-safe — call from any thread
}

// Capturing keyboard input from SwiftTerm and sending to WKWebView:
func send(source: TerminalView, data: ArraySlice<UInt8>) {
    let input = String(data: Data(data), encoding: .utf8) ?? ""
    let escaped = input.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "'", with: "\\'")
        .replacingOccurrences(of: "\n", with: "\\n")
        .replacingOccurrences(of: "\r", with: "\\r")
    forgeEngine?.sendInput(escaped)
}
```

---

## 8. THE ANSI BRIDGE

### 8.1 Output Pipeline

OpenTUI renders SolidJS components to ANSI escape sequences. We redirect them to the native bridge:

```typescript
// Inside forge-bundle.js:
// Instead of process.stdout.write(ansi), we do:
window.__forgeNative.output(ansi)
```

This calls window.webkit.messageHandlers.native.postMessage() which routes to terminalView.feed(text:).

### 8.2 Input Pipeline

```
SwiftTerm keyboard input
  -> TerminalViewDelegate.send(source:data:)
  -> Data(data) to String
  -> ForgeEngine.sendInput(escapedString)
  -> webView.evaluateJavaScript("window.__forgeInput('...')")
  -> window.__forgeOnInput callback in forge-bundle.js
  -> opencode session processes input
```

### 8.3 Resize Handling

```swift
func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
    let js = "window.__forgeCols=\(newCols);window.__forgeRows=\(newRows);window.__forgeResizeCallback&&window.__forgeResizeCallback(\(newCols),\(newRows));"
    forgeEngine?.webView?.evaluateJavaScript(js, completionHandler: nil)
}
```

### 8.4 Performance — Output Batching

Buffer writes for 16ms (one frame) and coalesce to avoid flooding SwiftTerm:

```swift
private var outputBuffer = ""
private var outputTimer: DispatchSourceTimer?

func handleANSIOutput(_ ansi: String) {
    outputBuffer += ansi
    if outputTimer == nil {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .milliseconds(16))
        timer.setEventHandler { [weak self] in
            guard let buf = self?.outputBuffer, !buf.isEmpty else { return }
            self?.terminalView?.feed(text: buf)
            self?.outputBuffer = ""
            self?.outputTimer = nil
        }
        timer.resume()
        outputTimer = timer
    }
}
```

---

## 9. THE SWIFT BRIDGE LAYER (ForgeBridge)

### 9.1 Overview

ForgeBridge is the Swift class implementing all native operations requested by JavaScript. Every bridge method follows the same pattern: receive from WKScriptMessageHandler, dispatch to background, perform operation, resolve or reject callback.

### 9.2 File Operations

```swift
class ForgeBridge {
    var projectRoot: String = ""

    func readFile(_ args: [String: Any], callbackId: String?, webView: WKWebView?) {
        guard let path = args["path"] as? String, let cbId = callbackId else {
            ForgeEngine.reject(webView, callbackId, "Missing path"); return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fullPath = self.resolveProjectPath(path)
                let content = try String(contentsOfFile: fullPath, encoding: .utf8)
                ForgeEngine.resolve(webView, cbId, content)
            } catch {
                ForgeEngine.reject(webView, cbId, "readFile: \(error.localizedDescription)")
            }
        }
    }

    func writeFile(_ args: [String: Any], callbackId: String?, webView: WKWebView?) {
        guard let path = args["path"] as? String,
              let content = args["content"] as? String,
              let cbId = callbackId else {
            ForgeEngine.reject(webView, callbackId, "Missing path/content"); return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fullPath = self.resolveProjectPath(path)
                let dir = (fullPath as NSString).deletingLastPathComponent
                try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                try content.write(toFile: fullPath, atomically: true, encoding: .utf8)
                ForgeEngine.resolve(webView, cbId, true)
            } catch {
                ForgeEngine.reject(webView, cbId, "writeFile: \(error.localizedDescription)")
            }
        }
    }

    func listFiles(_ args: [String: Any], callbackId: String?, webView: WKWebView?) {
        guard let cbId = callbackId else { return }
        let path = args["path"] as? String ?? ""
        DispatchQueue.global(qos: .userInitiated).async {
            let fullPath = self.resolveProjectPath(path)
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: fullPath)
                let items = contents.map { name -> [String: Any] in
                    let itemPath = (fullPath as NSString).appendingPathComponent(name)
                    var isDir: ObjCBool = false
                    FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDir)
                    let attrs = try? FileManager.default.attributesOfItem(atPath: itemPath)
                    return [
                        "name": name,
                        "isDirectory": isDir.boolValue,
                        "size": attrs?[.size] as? Int ?? 0,
                        "modified": (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
                    ]
                }
                ForgeEngine.resolve(webView, cbId, items)
            } catch {
                ForgeEngine.reject(webView, cbId, "listFiles: \(error.localizedDescription)")
            }
        }
    }

    func deleteFile(_ args: [String: Any], callbackId: String?, webView: WKWebView?) {
        guard let path = args["path"] as? String, let cbId = callbackId else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let fullPath = self.resolveProjectPath(path)
            do {
                try FileManager.default.removeItem(atPath: fullPath)
                ForgeEngine.resolve(webView, cbId, true)
            } catch {
                ForgeEngine.reject(webView, cbId, "deleteFile: \(error.localizedDescription)")
            }
        }
    }

    func searchFiles(_ args: [String: Any], callbackId: String?, webView: WKWebView?) {
        guard let query = args["query"] as? String, let cbId = callbackId else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let basePath = self.projectRoot
            var results: [[String: Any]] = []
            guard let enumerator = FileManager.default.enumerator(atPath: basePath) else { return }
            while let file = enumerator.nextObject() as? String {
                let fullPath = (basePath as NSString).appendingPathComponent(file)
                if let content = try? String(contentsOfFile: fullPath, encoding: .utf8) {
                    let lines = content.components(separatedBy: "\n")
                    for (i, line) in lines.enumerated() {
                        if line.contains(query) {
                            results.append([
                                "path": file,
                                "line": i + 1,
                                "content": line.trimmingCharacters(in: .whitespaces)
                            ])
                        }
                    }
                }
            }
            ForgeEngine.resolve(webView, cbId, results)
        }
    }

    func resolveProjectPath(_ relativePath: String) -> String {
        if relativePath.isEmpty { return projectRoot }
        if relativePath.hasPrefix("/") { return relativePath }
        return (projectRoot as NSString).appendingPathComponent(relativePath)
    }
}
```

### 9.3 Command Runner

Executes curated shell commands within the app sandbox via FileManager and POSIX:

```swift
func runCommand(_ args: [String: Any], callbackId: String?, webView: WKWebView?) {
    guard let command = args["command"] as? String, let cbId = callbackId else { return }
    DispatchQueue.global(qos: .userInitiated).async {
        let result = self.executeCommand(command)
        ForgeEngine.resolve(webView, cbId, [
            "stdout": result.stdout,
            "stderr": result.stderr,
            "exitCode": result.exitCode
        ])
    }
}

struct CommandResult { var stdout: String; var stderr: String; var exitCode: Int32 }

func executeCommand(_ command: String) -> CommandResult {
    let parts = command.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
    guard let cmd = parts.first?.lowercased() else {
        return CommandResult(stdout: "", stderr: "Empty command", exitCode: 1)
    }
    let args = parts.count > 1 ? String(parts[1]) : ""
    let cwd = projectRoot

    switch cmd {
    case "ls": return cmdLs(args, cwd: cwd)
    case "cat": return cmdCat(args, cwd: cwd)
    case "grep": return cmdGrep(args, cwd: cwd)
    case "find": return cmdFind(args, cwd: cwd)
    case "mkdir": return cmdMkdir(args, cwd: cwd)
    case "rm": return cmdRm(args, cwd: cwd)
    case "cp": return cmdCp(args, cwd: cwd)
    case "mv": return cmdMv(args, cwd: cwd)
    case "wc": return cmdWc(args, cwd: cwd)
    case "head": return cmdHead(args, cwd: cwd)
    case "tail": return cmdTail(args, cwd: cwd)
    case "pwd": return CommandResult(stdout: cwd + "\n", stderr: "", exitCode: 0)
    case "echo": return CommandResult(stdout: args + "\n", stderr: "", exitCode: 0)
    case "touch": return cmdTouch(args, cwd: cwd)
    default:
        return CommandResult(stdout: "", stderr: "Not supported on iOS: \(cmd)", exitCode: 127)
    }
}

private func cmdLs(_ args: String, cwd: String) -> CommandResult {
    let path = args.isEmpty ? cwd : (cwd as NSString).appendingPathComponent(args)
    do {
        let contents = try FileManager.default.contentsOfDirectory(atPath: path)
        return CommandResult(stdout: contents.sorted().joined(separator: "\n") + "\n", stderr: "", exitCode: 0)
    } catch {
        return CommandResult(stdout: "", stderr: "ls: \(error.localizedDescription)", exitCode: 1)
    }
}

private func cmdCat(_ args: String, cwd: String) -> CommandResult {
    let path = (cwd as NSString).appendingPathComponent(args)
    do {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        return CommandResult(stdout: content, stderr: "", exitCode: 0)
    } catch {
        return CommandResult(stdout: "", stderr: "cat: \(error.localizedDescription)", exitCode: 1)
    }
}

private func cmdMkdir(_ args: String, cwd: String) -> CommandResult {
    let path = (cwd as NSString).appendingPathComponent(args)
    do {
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return CommandResult(stdout: "", stderr: "", exitCode: 0)
    } catch {
        return CommandResult(stdout: "", stderr: "mkdir: \(error.localizedDescription)", exitCode: 1)
    }
}

private func cmdRm(_ args: String, cwd: String) -> CommandResult {
    let path = (cwd as NSString).appendingPathComponent(args.replacingOccurrences(of: "-rf ", with: ""))
    do {
        try FileManager.default.removeItem(atPath: path)
        return CommandResult(stdout: "", stderr: "", exitCode: 0)
    } catch {
        return CommandResult(stdout: "", stderr: "rm: \(error.localizedDescription)", exitCode: 1)
    }
}

private func cmdGrep(_ args: String, cwd: String) -> CommandResult {
    // Simplified grep: search recursively for pattern
    let parts = args.split(separator: " ", maxSplits: 1)
    guard parts.count >= 1 else { return CommandResult(stdout: "", stderr: "grep: missing pattern", exitCode: 1) }
    let pattern = String(parts[0])
    var results: [String] = []
    if let enumerator = FileManager.default.enumerator(atPath: cwd) {
        while let file = enumerator.nextObject() as? String {
            if let content = try? String(contentsOfFile: (cwd as NSString).appendingPathComponent(file), encoding: .utf8) {
                for (i, line) in content.components(separatedBy: "\n").enumerated() {
                    if line.contains(pattern) {
                        results.append("\(file):\(i+1):\(line.trimmingCharacters(in: .whitespaces))")
                    }
                }
            }
        }
    }
    return CommandResult(stdout: results.joined(separator: "\n") + "\n", stderr: "", exitCode: results.isEmpty ? 1 : 0)
}

private func cmdTouch(_ args: String, cwd: String) -> CommandResult {
    let path = (cwd as NSString).appendingPathComponent(args)
    if !FileManager.default.fileExists(atPath: path) {
        FileManager.default.createFile(atPath: path, contents: nil)
    }
    return CommandResult(stdout: "", stderr: "", exitCode: 0)
}
```

### 9.4 HTTP Request Bridge

```swift
func httpRequest(_ args: [String: Any], callbackId: String?, webView: WKWebView?) {
    guard let urlString = args["url"] as? String,
          let method = args["method"] as? String,
          let cbId = callbackId,
          let url = URL(string: urlString) else { return }

    var request = URLRequest(url: url)
    request.httpMethod = method
    request.timeoutInterval = 30
    if let headers = args["headers"] as? [String: String] {
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
    }
    if let body = args["body"] as? String { request.httpBody = body.data(using: .utf8) }

    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error { ForgeEngine.reject(webView, cbId, "HTTP: \(error.localizedDescription)"); return }
        guard let resp = response as? HTTPURLResponse,
              let data = data,
              let bodyStr = String(data: data, encoding: .utf8) else { return }
        var headers: [String: String] = [:]
        for (k, v) in resp.allHeaderFields {
            if let k = k as? String, let v = v as? String { headers[k] = v }
        }
        ForgeEngine.resolve(webView, cbId, ["status": resp.statusCode, "headers": headers, "body": bodyStr])
    }.resume()
}
```

### 9.5 Keychain Bridge

```swift
func getSecret(_ args: [String: Any], callbackId: String?, webView: WKWebView?) {
    guard let key = args["key"] as? String, let cbId = callbackId else { return }
    let value = KeychainHelper.loadSync(for: key) ?? ""
    ForgeEngine.resolve(webView, cbId, value)
}

func setSecret(_ args: [String: Any], callbackId: String?, webView: WKWebView?) {
    guard let key = args["key"] as? String,
          let value = args["value"] as? String,
          let cbId = callbackId else { return }
    do {
        try KeychainHelper.save(value, for: key)
        ForgeEngine.resolve(webView, cbId, true)
    } catch {
        ForgeEngine.reject(webView, cbId, "Keychain: \(error.localizedDescription)")
    }
}
```

### 9.6 Share Sheet

```swift
func shareFile(_ args: [String: Any], callbackId: String?, webView: WKWebView?) {
    guard let path = args["path"] as? String, let cbId = callbackId else { return }
    let fileURL = URL(fileURLWithPath: resolveProjectPath(path))
    DispatchQueue.main.async {
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        if let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController {
            activityVC.popoverPresentationController?.sourceView = rootVC.view
            activityVC.popoverPresentationController?.sourceRect = CGRect(
                x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
            rootVC.present(activityVC, animated: true)
        }
        ForgeEngine.resolve(webView, cbId, true)
    }
}
```

---

## 10. THE FILE SYSTEM LAYER

### 10.1 Project Directory Structure

```
<App Sandbox>/Documents/
+- projects/
|  +- my-app/
|  |  +- src/
|  |  |  +- index.ts
|  |  |  +- utils.ts
|  |  +- package.json
|  |  +- README.md
|  |  +- .git/                    <- Git repository (libgit2)
|  +- another-project/
|  |  +- ...
+- forge-config-user.json           <- User settings overrides
+- forge-state.json                 <- App state (last mode, last project)
+- forge.db                         <- SQLite database (SQL.js WASM)
```

### 10.2 Path Resolution

```swift
func setProject(_ name: String) {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let projectDir = docs.appendingPathComponent("projects").appendingPathComponent(name)
    try? FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
    projectRoot = projectDir.path
}
```

### 10.3 POSIX Access

iOS apps CAN use POSIX file APIs (open, read, write, close, stat, mkdir, unlink) within their sandbox. The sandbox restricts the namespace, not the API surface.

---

## 11. THE GIT INTEGRATION (libgit2)

### 11.1 Package

Use swift-libgit2 via SPM: https://github.com/swift-developer-tools/swift-libgit2

Provides pre-compiled libgit2 1.9.1 xcframework with bundled libssh2 and OpenSSL. iOS 15.0+. In-memory SSH key support (git_cred_ssh_key_memory_new).

### 11.2 Git Bridge

```swift
class ForgeGitManager {
    private let queue = DispatchQueue(label: "forge.git", qos: .userInitiated)

    func gitOperation(_ args: [String: Any], callbackId: String?, webView: WKWebView?, projectRoot: String) {
        guard let operation = args["operation"] as? String, let cbId = callbackId else { return }
        queue.async {
            do {
                let result: Any
                switch operation {
                case "init": result = try self.gitInit(at: projectRoot)
                case "add":
                    let files = args["files"] as? [String] ?? ["."]
                    result = try self.gitAdd(files, at: projectRoot)
                case "commit":
                    let msg = args["message"] as? String ?? "FORGE commit"
                    result = try self.gitCommit(message: msg, at: projectRoot)
                case "push":
                    let remote = args["remote"] as? String ?? "origin"
                    let branch = args["branch"] as? String ?? "main"
                    result = try self.gitPush(remote: remote, branch: branch, at: projectRoot)
                case "diff": result = try self.gitDiff(at: projectRoot)
                case "log":
                    let count = args["count"] as? Int ?? 20
                    result = try self.gitLog(count: count, at: projectRoot)
                case "status": result = try self.gitStatus(at: projectRoot)
                default: throw NSError(domain: "Git", description: "Unknown: \(operation)")
                }
                ForgeEngine.resolve(webView, cbId, result)
            } catch {
                ForgeEngine.reject(webView, cbId, "Git: \(error.localizedDescription)")
            }
        }
    }

    private func gitInit(at path: String) throws -> Bool {
        var repo: OpaquePointer?
        guard git_repository_init(&repo, path, 0) == 0 else {
            throw NSError(domain: "Git", description: "Init failed")
        }
        git_repository_free(repo)
        return true
    }

    private func gitStatus(at path: String) throws -> [String: Any] {
        var repo: OpaquePointer?
        guard git_repository_open(&repo, path) == 0 else { throw NSError(domain: "Git", description: "Cannot open") }
        defer { git_repository_free(repo) }
        var opts = git_status_options()
        git_status_init_options(&opts, UInt32(GIT_STATUS_OPTIONS_VERSION))
        opts.show = GIT_STATUS_SHOW_INDEX_AND_WORKDIR
        var statusList: OpaquePointer?
        guard git_status_list_new(&statusList, repo, &opts) == 0 else {
            throw NSError(domain: "Git", description: "Status list failed")
        }
        defer { git_status_list_free(statusList) }
        let count = git_status_list_entrycount(statusList)
        var staged: [[String: Any]] = []
        var modified: [[String: Any]] = []
        var untracked: [[String: Any]] = []
        for i in 0..<count {
            let entry = git_status_byindex(statusList, i).pointee
            let flags = entry.status.rawValue
            if flags & UInt32(GIT_STATUS_INDEX_NEW.rawValue) != 0 || flags & UInt32(GIT_STATUS_INDEX_MODIFIED.rawValue) != 0 {
                staged.append(["path": String(cString: entry.head_to_index?.new_file.path ?? "")])
            }
            if flags & UInt32(GIT_STATUS_WT_MODIFIED.rawValue) != 0 {
                modified.append(["path": String(cString: entry.index_to_workdir?.new_file.path ?? "")])
            }
            if flags & UInt32(GIT_STATUS_WT_NEW.rawValue) != 0 {
                untracked.append(["path": String(cString: entry.index_to_workdir?.new_file.path ?? "")])
            }
        }
        return ["staged": staged, "modified": modified, "untracked": untracked]
    }

    private func gitPush(remote: String, branch: String, at path: String) throws -> Bool {
        var repo: OpaquePointer?
        guard git_repository_open(&repo, path) == 0 else { throw NSError(domain: "Git", description: "Cannot open") }
        defer { git_repository_free(repo) }
        var gitRemote: OpaquePointer?
        guard git_remote_lookup(&gitRemote, repo, remote) == 0 else {
            throw NSError(domain: "Git", description: "Remote not found: \(remote)")
        }
        defer { git_remote_free(gitRemote) }
        var callbacks = git_remote_callbacks()
        git_remote_init_callbacks(&callbacks, UInt32(GIT_REMOTE_CALLBACKS_VERSION))
        let credCallback: git_cred_acquire_cb = { cred, _, username_from_url, _, _ in
            let token = KeychainHelper.loadSync(for: "git_token") ?? ""
            let username = username_from_url.map { String(cString: $0) } ?? "git"
            return git_cred_userpass_plaintext_new(cred, username, token)
        }
        callbacks.credentials = credCallback
        var pushOpts = git_push_options()
        git_push_init_options(&pushOpts, UInt32(GIT_PUSH_OPTIONS_VERSION))
        pushOpts.callbacks = callbacks
        let refspec = "refs/heads/\(branch):refs/heads/\(branch)"
        var refspecCStr = refspec.cString(using: .utf8)!
        var strs = [UnsafePointer<CChar>?]([UnsafePointer(refspecCStr.withUnsafeMutablePointer { $0 })])
        var strArray = git_strarray(count: 1, strings: &strs)
        guard git_remote_push(gitRemote, &strArray, &pushOpts) == 0 else {
            throw NSError(domain: "Git", description: "Push failed")
        }
        return true
    }
}
```

### 11.3 Credentials

| Credential | Keychain Key | Access |
|-----------|-------------|--------|
| GitHub/GitLab PAT | git_token | kSecAttrAccessibleWhenUnlockedThisDeviceOnly |
| Git username | git_username | Same |
| Remote URL | git_remote_url | Same |

For SSH: use git_cred_ssh_key_memory_new with key contents from Keychain.

---

## 12. THE NETWORKING LAYER

### 12.1 LLM API Calls

LLM API calls are made directly from JavaScript using WKWebView's native fetch(). No Swift bridge needed for this. API keys injected from Keychain:

```swift
func injectAPICredentials() {
    let provider = KeychainHelper.loadSync(for: "llm_provider") ?? "anthropic"
    let apiKey = KeychainHelper.loadSync(for: "llm_api_key") ?? ""
    let model = KeychainHelper.loadSync(for: "llm_model") ?? "claude-sonnet-4-20250514"
    let js = """
    window.__forgeConfig = { provider: '\(provider)', apiKey: '\(apiKey)', model: '\(model)' };
    """
    webView?.evaluateJavaScript(js, completionHandler: nil)
}
```

### 12.2 Mission Control Networking

```swift
class ConnectionManager: ObservableObject {
    @Published var discoveredServers: [DiscoveredServer] = []
    @Published var sessions: [RemoteSession] = []
    private var browser: NWBrowser?

    func startDiscovery() {
        let params = NWParameters()
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_opencode._tcp", domain: nil)
        browser = NWBrowser(for: descriptor, using: params)
        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            DispatchQueue.main.async {
                self?.discoveredServers = results.compactMap { result in
                    if case .service(let name, _, _, _) = result.endpoint {
                        return DiscoveredServer(name: name, endpoint: result.endpoint)
                    }
                    return nil
                }
            }
        }
        browser?.start(queue: .main)
    }

    func discoverSessions(server: ServerConnection) async {
        guard let url = URL(string: "http://\(server.hostname):\(server.port)/api/sessions") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let sessions = try JSONDecoder().decode([RemoteSessionInfo].self, from: data)
            await MainActor.run {
                self.sessions = sessions.map { RemoteSession(info: $0, server: server) }
            }
        } catch { print("Discovery failed: \(error)") }
    }
}
```

### 12.3 WebSocket for Remote Sessions

```swift
class RemoteSessionViewModel: ObservableObject {
    private var webSocket: URLSessionWebSocketTask?
    private var terminalView: TerminalView?

    func connect(to session: RemoteSession, terminalView: TerminalView) {
        self.terminalView = terminalView
        let url = URL(string: "ws://\(session.server.hostname):\(session.server.port)/ws/session/\(session.id)")!
        webSocket = URLSession.shared.webSocketTask(with: url)
        webSocket?.resume()
        receiveLoop()
    }

    private func receiveLoop() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let msg):
                switch msg {
                case .string(let text):
                    DispatchQueue.main.async { self?.terminalView?.feed(text: text) }
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async { self?.terminalView?.feed(text: text) }
                    }
                @unknown default: break
                }
                self?.receiveLoop()
            case .failure:
                DispatchQueue.main.async {
                    self?.terminalView?.feed(text: "\r\n\u001b[31mConnection lost - reconnecting...\u001b[0m\r\n")
                }
                self?.reconnect()
            }
        }
    }

    func sendInput(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        webSocket?.send(.string(text)) { _ in }
    }

    func sendResize(cols: Int, rows: Int) {
        webSocket?.send(.string("{\"type\":\"resize\",\"cols\":\(cols),\"rows\":\(rows)}")) { _ in }
    }

    private var reconnectAttempts = 0
    private func reconnect() {
        reconnectAttempts += 1
        let delay = min(2.0 * pow(2.0, Double(reconnectAttempts - 1)), 60.0)
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            // Reconnect logic...
            self.reconnectAttempts = 0
            self.receiveLoop()
        }
    }
}
```

### 12.4 App Transport Security

```xml
<!-- Info.plist -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>localhost</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>

<key>NSLocalNetworkUsageDescription</key>
<string>FORGE discovers opencode servers on your local network.</string>

<key>NSBonjourServices</key>
<array>
    <string>_opencode._tcp</string>
</array>
```

For Tailscale connections (100.64.0.0/10), use NWConnection directly — it bypasses ATS entirely.

---

## 13. THE KEYCHAIN LAYER

### 13.1 KeychainHelper

```swift
struct KeychainHelper {
    private static let service = "com.forge.app"

    static func save(_ value: String, for key: String) throws {
        let data = value.data(using: .utf8)!
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "Keychain", description: "Save failed: \(status)")
        }
    }

    static func loadSync(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else { return nil }
        return value
    }

    static func delete(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

### 13.2 Stored Credentials

| Key | Content | Purpose |
|-----|---------|---------|
| llm_provider | anthropic / openai / custom | LLM provider |
| llm_api_key | sk-ant-... | LLM auth |
| llm_model | claude-sonnet-4-20250514 | Model name |
| llm_base_url | http://100.x.x.x:8080 | Custom endpoint |
| git_token | ghp_... | Git push/pull |
| git_username | git | Git auth |
| git_remote_url | https://github.com/... | Git remote |
| drive_token | OAuth token | Google Drive |
| dropbox_token | OAuth token | Dropbox |
| server_bearer_<name> | Bearer token | Mission Control |

All values use kSecAttrAccessibleWhenUnlockedThisDeviceOnly.

---

## 14. CODE EXECUTION (PYTHON VIA PYODIDE)

### 14.1 Overview

Pyodide is CPython compiled to WebAssembly. It runs inside the WKWebView's JavaScript context. Loaded lazily on first Python execution request (~3-5 seconds initial load, fast subsequently).

### 14.2 Loading and Running Python

```swift
func runPython(_ args: [String: Any], callbackId: String?, webView: WKWebView?) {
    guard let code = args["code"] as? String, let cbId = callbackId else { return }
    let escapedCode = code.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "`", with: "\\`")
    let js = """
    (async function() {
        try {
            if (!window.__pyodide) {
                window.__forgeNative.output('Loading Python runtime...\\n');
                importScripts('pyodide.js');
                window.__pyodide = await loadPyodide({ indexURL: './' });
                window.__pyodide.setStdout({
                    batched: (text) => window.__forgeNative.output(text + '\\n')
                });
            }
            const result = await Promise.race([
                window.__pyodide.runPython(`\(escapedCode)`),
                new Promise((_, reject) =>
                    setTimeout(() => reject(new Error('Timeout (30s)')), 30000))
            ]);
            window.__forgeNative.resolve('\(cbId)', String(result));
        } catch (error) {
            window.__forgeNative.reject('\(cbId)', error.message);
        }
    })();
    """
    webView?.evaluateJavaScript(js, completionHandler: nil)
}
```

### 14.3 Isolation

Python code in Pyodide is sandboxed within the WKWebView. It cannot directly access the iOS file system. If the agent needs to read a file into Python, it calls the readFile bridge first, then injects the content as a Python variable.

---

## 15. MODE 1: BUILD ON-DEVICE

### 15.1 Startup Sequence

```
1. User taps "BUILD ON-DEVICE" card on Launch Menu
2. Card unfolds animation (0.4s spring)
3. ForgeTerminalView appears
4. ForgeEngine initializes:
   a. Create hidden WKWebView
   b. Inject native API script
   c. Load forge-bundle.js
   d. Wait for __ready signal
5. Inject API credentials from Keychain
6. Load or create project
7. opencode TUI renders in SwiftTerm
8. Terminal prompt appears, user can type
```

### 15.2 The God Loop on iOS

```
> audit and fix the empty catch blocks in src/

AUDIT (yellow)
+- web-tree-sitter parses all .ts files
+- 18-layer audit engine runs (R0-R17)
+- R4 finds 3 empty catch blocks
+- Score: 72/100

EXECUTE (cyan)
+- trident_build subagent dispatched (Effect fiber)
+- Reads files via bridge, modifies, writes via bridge
+- All 3 catch blocks fixed

VERIFY (yellow)
+- Re-audit: R4 now passes
+- Score: 98/100

PASS (green)
+- Score 98 >= 96 -> God Loop complete
+- Git checkpoint: "FORGE: Fixed 3 empty catch blocks (98)"
+- Terminal shows final grade in green
```

### 15.3 User Interaction

The user interacts with the agent by typing at the terminal prompt. The experience is identical to running opencode on a desktop:
- Type a message, press Enter, agent processes it
- Agent streams response in real-time (token by token)
- Tool calls displayed inline
- Subagent dispatches show dispatch messages
- God Loop phases clearly labeled
- Keyboard accessory bar provides ESC, CTRL, TAB, arrows, F-keys

### 15.4 Mode 1 Screen Layout

```
+----------------------------------------------+
| < FORGE                              [gear]  |  <- 44pt top bar
+----------------------------------------------+
|                                              |
|  FORGE - Trident T3 Audit Engine             |
|  Project: my-app                             |
|  ------------------------------------------  |
|                                              |
|  > audit and fix empty catch blocks          |
|                                              |
|  AUDIT - Phase 1/10                          |  <- Yellow
|    Parsing 15 source files...                |
|    R4: Found 3 empty catch blocks            |
|    Score: 72/100                             |
|                                              |
|  EXECUTE - Fixing...                         |  <- Cyan
|    src/index.ts:45 done                      |
|    src/utils.ts:12 done                      |
|    src/api.ts:89 done                        |
|                                              |
|  VERIFY - Phase 2/10                         |  <- Yellow
|    Re-auditing...                            |
|    Score: 98/100                             |
|                                              |
|  ==========================================  |
|  PASS - Quality grade: 98/100                |  <- Green
|  Git checkpoint created                      |
|  ==========================================  |
|                                              |
|  > _                                         |  <- Prompt
|                                              |
+----------------------------------------------+
| [ESC] [CTRL] [TAB] [|] [/] [-] [^] [v] [<] [>]| <- Accessory bar
+----------------------------------------------+
```

---

## 16. MODE 2: MISSION CONTROL

### 16.1 Architecture

Mission Control connects to remote opencode servers. No JavaScript runs locally. Uses NWBrowser, URLSession, URLSessionWebSocketTask, and SwiftTerm.

### 16.2 Server Discovery

Uses Bonjour/mDNS (NWBrowser) to find opencode servers advertising "_opencode._tcp" on the local network or Tailscale mesh. Also supports manual hostname entry.

### 16.3 Session Pager

Displays one session at a time in full-screen SwiftTerm. User swipes horizontally between sessions using the direction-lock gesture recognizer (see section 18).

### 16.4 Eagle Vision

Pinch outward to zoom out to a grid of all session thumbnails. Each thumbnail shows the last 5 lines of terminal output (live from WebSocket). Tap a thumbnail to zoom back in.

### 16.5 Mission Control Screen Layout

```
+----------------------------------------------+
| < MISSION CONTROL                      [+]   |  <- 44pt top bar
+----------------------------------------------+
| [rog-laptop *] [redmagic-1 *] [macbook .]   |  <- Server status pills
+----------------------------------------------+
|                                              |
|  Session: Trident Factory                    |
|  Server: rog-laptop                          |
|  Phase: EXECUTE (Cycle 3)                    |
|                                              |
|  ... live terminal output from remote ...    |
|  ... streaming via WebSocket ...             |
|                                              |
|  > _                                         |
|                                              |
+----------------------------------------------+
|        . . o . . . . . .                     |  <- Session indicator dots
+----------------------------------------------+
```

---

## 17. LAUNCH MENU

### 17.1 Layout

Full-screen dark view. FORGE title in 36pt bold monospaced white text centered vertically. Thin cyan line beneath. Two large rectangular cards (140pt tall, 16pt corner radius, hex 1A1A24 background, 1pt cyan stroke at 20% opacity).

Card 1: BUILD ON-DEVICE with bolt.fill icon, subtitle "Local agent, full sandbox, zero cloud."
Card 2: MISSION CONTROL with antenna.radiowaves.left.and.right icon, subtitle "Remote fleet, swipe between agents, eagle vision."

Below cards: "Continue last session" text button (12pt, secondary color).

Background: animated grid overlay (3% opacity, 40pt grid, parallax drift from CoreMotion accelerometer).

### 17.2 Card Animation

When tapped, the card performs a scale animation expanding to fill the entire screen over 0.4 seconds with a spring curve. The destination mode's view fades in beneath it.

### 17.3 Parallax Grid

```swift
struct ParallaxGridBackground: View {
    @State private var offsetX: CGFloat = 0
    @State private var offsetY: CGFloat = 0
    private let motionManager = CMMotionManager()
    private let gridSize: CGFloat = 40
    private let maxOffset: CGFloat = 10

    var body: some View {
        Canvas { context, size in
            let cols = Int(size.width / gridSize) + 2
            let rows = Int(size.height / gridSize) + 2
            for row in 0..<rows {
                for col in 0..<cols {
                    let x = CGFloat(col) * gridSize + offsetX
                    let y = CGFloat(row) * gridSize + offsetY
                    let rect = CGRect(x: x, y: y, width: gridSize, height: gridSize)
                    context.stroke(Path(rect), with: .color(.white), lineWidth: 0.5)
                }
            }
        }
        .onAppear {
            guard motionManager.isAccelerometerAvailable else { return }
            motionManager.accelerometerUpdateInterval = 1.0 / 30.0
            motionManager.startAccelerometerUpdates(to: .main) { data, _ in
                guard let data = data else { return }
                withAnimation(.linear(duration: 0.1)) {
                    offsetX = CGFloat(data.acceleration.x) * maxOffset
                    offsetY = CGFloat(-data.acceleration.y) * maxOffset
                }
            }
        }
        .onDisappear { motionManager.stopAccelerometerUpdates() }
    }
}
```

---

## 18. THE GESTURE SYSTEM

### 18.1 Direction-Lock Gesture Recognizer

Custom UIGestureRecognizer subclass. Distinguishes horizontal swipes (session switch) from vertical scrolls (terminal scrollback). Uses 15-point displacement threshold, then locks to dominant axis.

```swift
import UIKit.UIGestureRecognizerSubclass

class DirectionLockPanGesture: UIGestureRecognizer {
    var activationThreshold: CGFloat = 15.0
    var lockedAxis: LockedAxis = .none

    enum LockedAxis { case none, horizontal, vertical }

    private var startPoint: CGPoint = .zero
    private var lastReportedPoint: CGPoint = .zero
    private var directionDetermined = false
    var translation: CGFloat = 0

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else { state = .failed; return }
        startPoint = touch.location(in: view)
        lastReportedPoint = startPoint
        directionDetermined = false
        lockedAxis = .none
        translation = 0
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else { return }
        let point = touch.location(in: view)
        let totalDx = point.x - startPoint.x
        let totalDy = point.y - startPoint.y

        if !directionDetermined {
            if abs(totalDx) > activationThreshold || abs(totalDy) > activationThreshold {
                directionDetermined = true
                lockedAxis = abs(totalDx) > abs(totalDy) ? .horizontal : .vertical
                state = .began
                lastReportedPoint = point
            }
            return
        }

        let delta: CGFloat
        switch lockedAxis {
        case .horizontal: delta = point.x - lastReportedPoint.x
        case .vertical: delta = point.y - lastReportedPoint.y
        case .none: delta = 0
        }
        translation += delta
        lastReportedPoint = point
        state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        state = directionDetermined ? .ended : .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        state = .cancelled
    }

    override func reset() {
        startPoint = .zero
        lastReportedPoint = .zero
        directionDetermined = false
        lockedAxis = .none
        translation = 0
        super.reset()
    }
}
```

### 18.2 Coexisting with SwiftTerm's Scroll View

The gesture recognizer must coexist with SwiftTerm's UIScrollView pan gesture. Strategy: make SwiftTerm's scroll pan WAIT for our direction determination:

```swift
class TerminalPagerDelegate: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy other: UIGestureRecognizer
    ) -> Bool {
        // SwiftTerm's scroll pan must wait for our gesture to fail
        // If horizontal -> our gesture begins, scroll pan fails -> session switches
        // If vertical -> our gesture fails, scroll pan begins -> normal scrolling
        if other is UIPanGestureRecognizer {
            return true
        }
        return false
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        return false  // Mutually exclusive once direction is determined
    }
}
```

### 18.3 WKWebView Configuration for Mission Control

```swift
// Prevent WKWebView (if used for remote terminal) from interfering with gestures
webView.allowsBackForwardNavigationGestures = false
webView.scrollView.alwaysBounceHorizontal = false
webView.scrollView.bounces = true  // Preserve vertical rubber-banding
```

---

## 19. EAGLE VISION

### 19.1 Overview

Pinch outward to zoom out from a single session terminal to a grid of all session thumbnails. Pinch inward to zoom back in.

### 19.2 Pinch Gesture

```swift
class EagleVisionController: UIViewController {
    var pinchGesture: UIPinchGestureRecognizer!
    var isInEagleVision = false

    override func viewDidLoad() {
        super.viewDidLoad()
        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinchGesture.delegate = self
        view.addGestureRecognizer(pinchGesture)
    }

    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .changed:
            if gesture.scale < 0.5 && !isInEagleVision {
                enterEagleVision()
                gesture.state = .cancelled
            }
        default: break
        }
    }

    func enterEagleVision() {
        isInEagleVision = true
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0.5, options: []) {
            self.terminalView.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
            self.terminalView.alpha = 0
            self.eagleVisionGrid.alpha = 1
            self.eagleVisionGrid.transform = .identity
        }
    }

    func exitEagleVision(sessionIndex: Int) {
        isInEagleVision = false
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0.5, options: []) {
            self.eagleVisionGrid.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
            self.eagleVisionGrid.alpha = 0
            self.terminalView.transform = .identity
            self.terminalView.alpha = 1
        }
        // Switch to selected session
        currentSessionIndex = sessionIndex
    }
}
```

### 19.3 Eagle Vision Grid

LazyVGrid with adaptive columns (160-240pt wide). Each cell:
- Miniature terminal preview (120pt tall, hex 12121A bg, 7pt monospaced text, 70% opacity, cyan color)
- Status row: green/gray dot + session name + server name
- Trident phase progress bar (cyan for active, gray for idle)

### 19.4 Gesture Coexistence

The pinch gesture (two fingers) is naturally distinguishable from the direction-lock pan (one finger). The direction-lock recognizer cancels when a second finger touches:

```swift
// In DirectionLockPanGesture.touchesMoved:
if event.allTouches?.count ?? 0 > 1 && directionDetermined {
    state = .cancelled
    return
}
```

---

## 20. THE THEME SYSTEM

### 20.1 Colors

All colors defined as static constants. No hardcoded values elsewhere.

| Name | Hex | Usage |
|------|-----|-------|
| background | 0A0A0F | App background |
| surface | 1A1A24 | Cards, panels |
| elevatedSurface | 12121A | Overlays, sheets |
| accent | 00F0FF | Primary accent (cyan) |
| primaryText | E0E0E0 | Body text |
| secondaryText | 888888 | Captions, labels |
| success | 50FA7B | Pass states |
| warning | F1FA8C | Audit phases |
| error | FF5555 | Failures |
| border | accent @ 20% | Card strokes |

```swift
extension Color {
    static let forgeBackground = Color(red: 0x0A/255, green: 0x0A/255, blue: 0x0F/255)
    static let forgeSurface = Color(red: 0x1A/255, green: 0x1A/255, blue: 0x24/255)
    static let forgeElevated = Color(red: 0x12/255, green: 0x12/255, blue: 0x1A/255)
    static let forgeAccent = Color(red: 0x00/255, green: 0xF0/255, blue: 0xFF/255)
    static let forgePrimaryText = Color(red: 0xE0/255, green: 0xE0/255, blue: 0xE0/255)
    static let forgeSecondaryText = Color(red: 0x88/255, green: 0x88/255, blue: 0x88/255)
    static let forgeSuccess = Color(red: 0x50/255, green: 0xFA/255, blue: 0x7B/255)
    static let forgeWarning = Color(red: 0xF1/255, green: 0xFA/255, blue: 0x8C/255)
    static let forgeError = Color(red: 0xFF/255, green: 0x55/255, blue: 0x55/255)
    static let forgeBorder = Color(red: 0x00/255, green: 0xF0/255, blue: 0xFF/255).opacity(0.2)
}
```

### 20.2 Typography

JetBrains Mono bundled as resource, registered in Info.plist under UIAppFonts.

```swift
extension Font {
    static let forgeTitle = Font.custom("JetBrainsMono-Bold", size: 24)
    static let forgeHeadline = Font.custom("JetBrainsMono-SemiBold", size: 17)
    static let forgeBody = Font.custom("JetBrainsMono-Regular", size: 14)
    static let forgeCaption = Font.custom("JetBrainsMono-Regular", size: 12)
    static let forgeTerminal = Font.custom("JetBrainsMono-Regular", size: 14)
}
```

### 20.3 Animation

All animations use spring physics:
```swift
.animation(.spring(response: 0.3, dampingFraction: 0.8))
```

### 20.4 Haptics

```swift
func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
}
```

---

## 21. THE SETTINGS SHEET

### 21.1 Sections

Presented modally from gear icon. Native SwiftUI sheet with dark background.

**API Provider:** Picker (Anthropic, OpenAI, Custom Endpoint). If Custom, text field for base URL.

**API Key:** Secure text field. Stored in Keychain.

**Model:** Text field (default: claude-sonnet-4-20250514 or gpt-4o).

**Project:** Current project name and path. Buttons to create new or open existing.

**Git:** Remote URL, username, secure token field. All in Keychain.

**Cloud Storage:** Authorize Google Drive / Dropbox buttons.

**About:** App version, links to opencode and Trident repositories.

### 21.2 Implementation

```swift
struct SettingsSheet: View {
    @State private var provider = "anthropic"
    @State private var apiKey = ""
    @State private var model = "claude-sonnet-4-20250514"
    @State private var gitRemote = ""
    @State private var gitUsername = ""
    @State private var gitToken = ""

    var body: some View {
        NavigationView {
            Form {
                Section("API Provider") {
                    Picker("Provider", selection: $provider) {
                        Text("Anthropic").tag("anthropic")
                        Text("OpenAI").tag("openai")
                        Text("Custom Endpoint").tag("custom")
                    }
                    SecureField("API Key", text: $apiKey)
                    TextField("Model", text: $model)
                }
                Section("Git") {
                    TextField("Remote URL", text: $gitRemote)
                    TextField("Username", text: $gitUsername)
                    SecureField("Token", text: $gitToken)
                }
                Section("About") {
                    Text("FORGE v1.0.0")
                    Text("Powered by opencode + Trident")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveSettings() }
                }
            }
        }
        .onAppear { loadSettings() }
    }

    func saveSettings() {
        try? KeychainHelper.save(provider, for: "llm_provider")
        try? KeychainHelper.save(apiKey, for: "llm_api_key")
        try? KeychainHelper.save(model, for: "llm_model")
        try? KeychainHelper.save(gitRemote, for: "git_remote_url")
        try? KeychainHelper.save(gitUsername, for: "git_username")
        try? KeychainHelper.save(gitToken, for: "git_token")
    }

    func loadSettings() {
        provider = KeychainHelper.loadSync(for: "llm_provider") ?? "anthropic"
        apiKey = KeychainHelper.loadSync(for: "llm_api_key") ?? ""
        model = KeychainHelper.loadSync(for: "llm_model") ?? "claude-sonnet-4-20250514"
        gitRemote = KeychainHelper.loadSync(for: "git_remote_url") ?? ""
        gitUsername = KeychainHelper.loadSync(for: "git_username") ?? ""
        gitToken = KeychainHelper.loadSync(for: "git_token") ?? ""
    }
}
```

---

## 22. PROJECT MANAGEMENT

### 22.1 Creating a Project

```swift
func createProject(name: String) {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let projectDir = docs.appendingPathComponent("projects").appendingPathComponent(name)
    try? FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

    // Initialize Git if credentials configured
    if KeychainHelper.loadSync(for: "git_token") != nil {
        forgeGitManager?.gitInit(at: projectDir.path)
    }

    bridge.projectRoot = projectDir.path

    // Display confirmation in terminal
    terminalView?.feed(text: "\n\u001b[32mProject '\(name)' created at \(projectDir.path)\u001b[0m\n")
}
```

### 22.2 Opening a Project

Lists all directories in Documents/projects sorted by last modified. User selects one. Agent working directory is set to selected project.

### 22.3 iCloud Sync

Projects directory synced via iCloud Drive:

```swift
// Entitlements: iCloud Documents capability
// Info.plist: NSUbiquitousContainers

if let ubiquityURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
    let iCloudProjects = ubiquityURL.appendingPathComponent("Documents/projects")
    // Sync between local Documents/projects and iCloud Documents/projects
}
```

---

## 23. iCLOUD SYNC

### 23.1 Configuration

Requires iCloud capability in entitlements. Uses NSUbiquitousKeyValueStore for metadata and iCloud Drive container for file storage.

### 23.2 Sync Strategy

- Project files synced via iCloud Drive container
- App state (last mode, last project) via NSUbiquitousKeyValueStore
- Credentials stay in Keychain (NOT synced — device-local only)
- Database (forge.db) NOT synced — each device has its own session history

---

## 24. ERROR HANDLING AND RECOVERY

### 24.1 Principles

1. The app NEVER crashes on a recoverable error
2. All errors surface to the user (terminal for Mode 1, banner for Mode 2)
3. JavaScript bridge wraps every native call in try-catch
4. Swift wraps every async operation in do-catch
5. Structured error objects propagate through the callback mechanism

### 24.2 Error Categories

| Category | Display | Recovery |
|----------|---------|----------|
| File system error | Terminal message | Agent retries or reports |
| Network failure | Terminal message | Agent retries with backoff |
| LLM API error | Terminal message | Agent reports, user can change settings |
| Git error | Terminal message | Agent reports, may skip Git operation |
| WebSocket disconnect (Mode 2) | Red banner + reconnect | Auto-reconnect with exponential backoff |
| Bundle load failure | Full-screen error | App restart |
| Memory warning | Silent GC hint | Reduce scrollback, clear caches |
| Python execution timeout | Terminal message | Agent continues |

### 24.3 Bridge Error Propagation

```swift
// Every bridge method catches errors and rejects the JS callback:
do {
    let result = try operation()
    ForgeEngine.resolve(webView, cbId, result)
} catch {
    ForgeEngine.reject(webView, cbId, "\(error)")
}
```

The JavaScript side receives the rejection as a Promise rejection:
```javascript
try {
    const data = await native.call('readFile', { path })
} catch (error) {
    // Agent sees: "readFile: The file couldn't be opened."
    console.error(error.message)
}
```

---

## 25. BACKGROUND EXECUTION AND LIFECYCLE

### 25.1 App Backgrounding

When the user presses Home:
- **Mode 1:** The WKWebView's JavaScript continues briefly (~5 seconds), then the app is suspended. The God Loop is paused. On foreground return, the agent resumes from where it left off.
- **Mode 2:** WebSocket connections are suspended. On foreground return, reconnection logic fires automatically.

### 25.2 Graceful Pause

```swift
func sceneDidEnterBackground(_ scene: UIScene) {
    // Signal the JS engine to pause the God Loop
    webView?.evaluateJavaScript("window.__forgePause && window.__forgePause()", completionHandler: nil)

    // Save state
    saveAppState()

    // Begin background task for ~30 seconds of grace
    backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "ForgeGrace") {
        // Expiration — save immediately
        self.saveAppState()
        UIApplication.shared.endBackgroundTask(self.backgroundTaskId!)
    }
}

func sceneWillEnterForeground(_ scene: UIScene) {
    // Resume the God Loop
    webView?.evaluateJavaScript("window.__forgeResume && window.__forgeResume()", completionHandler: nil)
}
```

### 25.3 Memory Warning

```swift
override func didReceiveMemoryWarning() {
    webView?.evaluateJavaScript("if(window.gc){window.gc()}", completionHandler: nil)
    URLCache.shared.removeAllCachedResponses()
}
```

---

## 26. INFO.PLIST AND ENTITLEMENTS

### 26.1 Info.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>FORGE</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UILaunchScreen</key>
    <dict>
        <key>UIColorName</key>
        <string>ForgeBackground</string>
    </dict>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>

    <!-- Custom Fonts -->
    <key>UIAppFonts</key>
    <array>
        <string>JetBrainsMono-Regular.ttf</string>
        <string>JetBrainsMono-Bold.ttf</string>
        <string>JetBrainsMono-SemiBold.ttf</string>
    </array>

    <!-- App Transport Security -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key>
        <true/>
        <key>NSExceptionDomains</key>
        <dict>
            <key>localhost</key>
            <dict>
                <key>NSExceptionAllowsInsecureHTTPLoads</key>
                <true/>
            </dict>
        </dict>
    </dict>

    <!-- Local Network (Bonjour discovery) -->
    <key>NSLocalNetworkUsageDescription</key>
    <string>FORGE discovers opencode servers on your local network.</string>
    <key>NSBonjourServices</key>
    <array>
        <string>_opencode._tcp</string>
    </array>

    <!-- Hide status bar for full-screen terminal -->
    <key>UIStatusBarHidden</key>
    <false/>
    <key>UIStatusBarStyle</key>
    <string>UIStatusBarStyleLightContent</string>
</dict>
</plist>
```

### 26.2 Entitlements

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>

    <!-- iCloud for project sync -->
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.forge.app</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudDocuments</string>
    </array>
    <key>com.apple.developer.ubiquity-container-identifiers</key>
    <array>
        <string>iCloud.com.forge.app</string>
    </array>

    <!-- Keychain access group (optional, for sharing with extensions) -->
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)com.forge.app</string>
    </array>
</dict>
</plist>
```

---

## 27. APP STORE REVIEW STRATEGY

### 27.1 Positioning

The app is positioned as a **code editor with AI assistance**, not an "agent runner." The agent operates within the app sandbox. Pyodide is sandboxed WASM. No arbitrary native code execution.

### 27.2 Review Guideline Compliance

| Guideline | Status | Notes |
|-----------|--------|-------|
| 2.1 App Completeness | PASS | Fully functional, no placeholder UI |
| 2.5.1 API Use | PASS | Uses standard iOS frameworks |
| 2.5.2 App Update | PASS | Standard update mechanism |
| 2.5.6 Executable Code | PASS | JS runs in WKWebView sandbox. Pyodide is WASM (not native code). No downloadable code execution outside sandbox. |
| 4.2 Minimum Functionality | PASS | Full-featured code editor + agent |
| 5.1 Privacy | PASS | No data collection. API keys in Keychain. No analytics. |

### 27.3 Privacy Nutrition Label

- **Data Not Collected:** The app collects no user data
- **Data Used:** API keys (stored locally in Keychain), project files (stored locally in sandbox)
- **No tracking, no analytics, no advertising**

---

## 28. TESTING REQUIREMENTS

### 28.1 Testing Strategy

| Phase | Environment | Tool | Purpose |
|-------|------------|------|---------|
| Unit tests | CI (GitHub Actions macOS runner) | XCTest | Test Swift bridge, shims, logic |
| Integration tests | CI | XCTest + iOS Simulator | Test WKWebView + bridge + SwiftTerm |
| Visual tests | CI | iOS Simulator (screenshots) | Verify terminal rendering, UI layout |
| Device tests | BrowserStack / physical device | Manual + XCTest | Verify Metal, keyboard, gestures |
| Beta | TestFlight (via Xcode Cloud) | Real users | Real-world validation |

### 28.2 Required Tests

1. **WKWebView + JS Bundle load:** Verify forge-bundle.js loads and __ready signal fires
2. **ANSI bridge:** Feed test ANSI to SwiftTerm, verify rendering
3. **Input bridge:** Type characters, verify they reach the JS engine
4. **File operations:** read/write/list/delete/search via bridge
5. **Git operations:** init/add/commit/status via libgit2
6. **Command runner:** ls/cat/grep/mkdir/rm produce correct output
7. **Keychain:** save/load/delete credentials
8. **Settings:** save/load round-trip
9. **Project management:** create/open/list projects
10. **God Loop:** Run a simple audit task, verify PASS/LOOP
11. **WebSocket (Mode 2):** connect to test server, receive data, send input
12. **Direction-lock gesture:** horizontal swipes switch sessions, vertical scrolls terminal
13. **Eagle Vision:** pinch out enters grid, tap enters session, pinch in exits
14. **Background/foreground:** app survives backgrounding without losing state
15. **Memory pressure:** app handles memory warning without crash

### 28.3 Physical Device Requirements

The app MUST be tested on a physical iPhone (not solely simulator):
- WKWebView WebGL/Metal rendering differs on real hardware
- Keyboard handling has subtle differences
- Gesture recognition (multi-touch) behaves differently
- Performance characteristics differ (iPhone CPU is slower than Mac)

Minimum test devices:
- iPhone SE (3rd gen) — smallest screen, A15 chip
- iPhone 15 Pro — latest hardware, ProMotion display
- iPad (10th gen) — tablet layout validation

---

## 29. FILE MANIFEST

### 29.1 Swift Source Files

```
iOS/FORGE/
+- App/
|  +- FORGEApp.swift                    <- @main entry, scene configuration
|  +- ForgeScene.swift                  <- Scene delegate, lifecycle management
|  +- AppState.swift                    <- Global app state (ObservableObject)
|
+- Presentation/
|  +- LaunchMenu/
|  |  +- LaunchMenuView.swift           <- Mode selection screen
|  |  +- ModeCard.swift                 <- Mode selection card component
|  |  +- ParallaxGridBackground.swift   <- CoreMotion parallax grid
|  |
|  +- Mode1_BuildOnDevice/
|  |  +- BuildOnDeviceScreen.swift      <- Mode 1 container view
|  |  +- ForgeTerminalView.swift        <- SwiftTerm UIViewRepresentable wrapper
|  |  +- ForgeTerminalCoordinator.swift <- TerminalViewDelegate implementation
|  |
|  +- Mode2_MissionControl/
|  |  +- MissionControlScreen.swift     <- Mode 2 container view
|  |  +- SessionPagerView.swift         <- Horizontal swipe pager (UIViewControllerRepresentable)
|  |  +- EagleVisionGridView.swift      <- Grid of session thumbnails
|  |  +- SessionThumbnailCard.swift     <- Individual thumbnail card
|  |  +- ServerPickerSheet.swift        <- Add/remove server sheet
|  |  +- ConnectionStatusPills.swift    <- Server status pills row
|  |
|  +- Shared/
|  |  +- SettingsSheet.swift            <- Settings modal sheet
|  |  +- ProjectManagerSheet.swift      <- Project create/open sheet
|  |  +- TopBar.swift                   <- 44pt top bar component
|
+- Bridge/
|  +- ForgeBridge.swift                 <- WKScriptMessageHandler, all native methods
|  +- ForgeEngine.swift                 <- WKWebView management, callback resolution
|  +- ForgeGitManager.swift             <- libgit2 operations
|  +- ForgeCommandRunner.swift          <- Curated command executor
|
+- Gestures/
|  +- DirectionLockPanGesture.swift     <- Custom direction-locking recognizer
|  +- EagleVisionPinchGesture.swift     <- Pinch-to-grid handler
|
+- Theme/
|  +- ForgeTheme.swift                  <- Colors, fonts, ANSI palette
|  +- Color+Hex.swift                   <- UIColor hex extension
|
+- Security/
|  +- KeychainHelper.swift              <- Keychain CRUD operations
|
+- Resources/
|  +- forge-bundle.js                   <- esbuild output (generated at build time)
|  +- tree-sitter.wasm                  <- tree-sitter WASM binary
|  +- pyodide/                          <- Pyodide distribution (lazy loaded)
|  |  +- pyodide.js
|  |  +- pyodide.asm.wasm
|  |  +- python_stdlib.zip
|  +- Fonts/
|  |  +- JetBrainsMono-Regular.ttf
|  |  +- JetBrainsMono-Bold.ttf
|  |  +- JetBrainsMono-SemiBold.ttf
|  +- forge-config.json                 <- Bundled default opencode config
|  +- forge-identity.md                 <- FORGE identity text
|
+- Info.plist
+- FORGE.entitlements
```

### 29.2 JavaScript/TypeScript Source Files

```
forge/
+- src/
|  +- forge-entry.ts                    <- iOS entry point (programmatic bootstrap)
|  +- forge-identity.ts                 <- FORGE identity text
|  +- forge-runtime.ts                  <- Effect runtime initialization
|  +- forge-terminal-surface.ts         <- OpenTUI capture adapter
|
+- shims/
|  +- forge-fs.ts                       <- fs replacement (Swift bridge)
|  +- forge-process.ts                  <- child_process replacement
|  +- forge-crypto.ts                   <- crypto replacement (Web Crypto)
|  +- forge-os.ts                       <- os replacement (hardcoded)
|  +- forge-events.ts                   <- events replacement (EventEmitter)
|  +- forge-stream.ts                   <- stream replacement
|  +- forge-http.ts                     <- http replacement (fetch-based)
|  +- forge-url.ts                      <- url replacement
|  +- forge-util.ts                     <- util replacement
|  +- forge-buffer.ts                   <- Buffer replacement
|  +- forge-sqlite.ts                   <- bun:sqlite replacement (SQL.js)
|  +- forge-noop.ts                     <- Empty module for unsupported APIs
|  +- forge-globals.js                  <- process/Buffer injection
|
+- scripts/
|  +- build-forge-bundle.mjs            <- esbuild build script

vendor/
+- opencode/                            <- opencode v1.14.43 source (git submodule)
+- trident/                             <- Trident v4.4.2 SHIP source (git submodule)
```

### 29.3 Xcode Project Structure

```
FORGE.xcodeproj
+- FORGE (target)
   +- Build Phases:
   |  1. Run Script: build-forge-bundle.mjs (before Compile Sources)
   |  2. Compile Sources (Swift files)
   |  3. Copy Bundle Resources (forge-bundle.js, WASM, fonts, config)
   |  4. Link Binary With Libraries (SwiftTerm, swift-libgit2)
   |
   +- Build Settings:
      - iOS Deployment Target: 17.0
      - Swift Language Version: 5.9
      - Objective-C Bridging Header: (none — pure Swift)
      - Info.plist: FORGE/Info.plist
      - Entitlements: FORGE/FORGE.entitlements

+- Project Dependencies (SPM):
   - https://github.com/migueldeicaza/SwiftTerm (2.0.0+)
   - https://github.com/swift-developer-tools/swift-libgit2 (1.0.0+)
```

---

## 30. BUILD SEQUENCE

### 30.1 Implementation Phases

The application is built in 6 waves, ordered by technical risk. Each wave produces a testable artifact.

### Wave 0: WKWebView + esbuild Proof of Concept (2-3 days)

**Goal:** Prove the ANSI bridge works end-to-end.

```
1. Create minimal Xcode project with a hidden WKWebView
2. Write a simple TypeScript file that outputs ANSI text
3. esbuild bundles it into forge-bundle.js
4. WKWebView loads the bundle
5. JS calls window.__forgeNative.output("\u001b[31mHello\u001b[0m")
6. Swift receives the message
7. SwiftTerm renders red "Hello" text

GATE: End-to-end ANSI flow works. SwiftTerm displays colored text from JS.
```

### Wave 1: opencode Bundle (3-5 days)

**Goal:** opencode core logic runs inside WKWebView.

```
1. Fork opencode at v1.14.43 tag
2. Create forge-entry.ts (programmatic bootstrap)
3. Create forge-config.json (strip vanilla agents, Trident default)
4. Bundle Trident plugin (pre-compiled, no dynamic import)
5. Create all shims (fs, process, crypto, os, path, events, stream, sqlite)
6. esbuild -> forge-bundle.js (platform: browser, conditions: browser/default)
7. Load in WKWebView
8. Test: session creation, agent instantiation, LLM API call

GATE: opencode runs inside WKWebView. Trident agent responds to a prompt.
```

### Wave 2: Full Terminal + Bridge (3-4 days)

**Goal:** Full opencode TUI renders and is interactive on iPhone screen.

```
1. SwiftTerm UIViewRepresentable (production wrapper)
2. OpenTUI output capture -> SwiftTerm feed
3. SwiftTerm input -> WKWebView evaluateJavaScript
4. FileManager bridge (readFile/writeFile/listFiles/searchFiles)
5. Command runner (curated shell commands)
6. Keyboard handling (accessory bar, resize notifications)
7. Theme/colors configuration

GATE: Full opencode TUI renders and is interactive on iPhone screen.
```

### Wave 3: Tools + Git + Settings (3-4 days)

**Goal:** Agent can read/write files, run Git, persist state.

```
1. libgit2 integration (swift-libgit2 via SPM)
2. Git bridge methods (init/add/commit/push/diff/log/status)
3. Keychain credential storage
4. Settings sheet (API provider, key, model, project, Git remote)
5. Project management (create/open in Documents dir)
6. iCloud sync for projects
7. Pyodide integration (lazy loading)

GATE: Agent runs full God Loop with file operations, Git checkpoints, Python execution.
```

### Wave 4: Mission Control (4-5 days)

**Goal:** Connect to remote opencode server, see live TUI, swipe between sessions.

```
1. NWBrowser (Bonjour discovery)
2. URLSession HTTP client (/api/sessions)
3. URLSessionWebSocketTask (/ws/session/:id)
4. SwiftTerm per session (remote mode)
5. Direction-locking gesture recognizer
6. Session pager (swipe between sessions)
7. Eagle Vision (pinch-to-grid)
8. Server picker sheet
9. Connection status pills
10. Reconnection logic (exponential backoff)

GATE: Connect to remote opencode server, see live TUI, swipe between sessions.
```

### Wave 5: Polish + Ship (2-3 days)

```
1. Launch menu (card transitions, parallax grid)
2. Haptic feedback throughout
3. ATS configuration
4. iPad layout testing
5. GitHub Actions CI (build + test on macOS runner)
6. TestFlight upload via Xcode Cloud
7. Physical device testing
8. App Store submission

GATE: App submitted to TestFlight. Beta testers can install.
```

### 30.2 Total Estimated Timeline

| Wave | Duration | Dependencies |
|------|----------|-------------|
| Wave 0 | 2-3 days | None (can start immediately) |
| Wave 1 | 3-5 days | Wave 0 passes |
| Wave 2 | 3-4 days | Wave 1 passes |
| Wave 3 | 3-4 days | Wave 2 passes |
| Wave 4 | 4-5 days | Wave 2 passes (can overlap with Wave 3) |
| Wave 5 | 2-3 days | Waves 3+4 pass |
| **Total** | **17-24 days** | Focused development |

---

## 31. RISK REGISTER

### 31.1 Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| SQL.js WASM fails to load in WKWebView | Low | High | Fallback: native SQLite via Swift bridge. SQL.js is designed for browsers, should work. |
| OpenTUI output capture incompatible | Low | High | OpenTUI writes to a surface object. We intercept the write method. If that fails, replace OpenTUI with direct output. |
| WKWebView memory pressure | Medium | Medium | Monitor with task_vm_info. Semantic layer filtering (skip irrelevant audit layers). Lazy-load Pyodide. |
| App Store rejection | Medium | Fatal | Position as code editor. Pyodide is sandboxed WASM. No native code execution outside sandbox. |
| esbuild can't resolve all opencode imports | Medium | High | Iterative bundling — fix each unresolved import. opencode has browser conditions that help. |
| Effect.ts runtime incompatibility | Low | High | Effect is pure TypeScript. If issues arise, they are likely Promise/microtask related — fixable. |
| LLM API latency on mobile | Low | Low | Same as desktop — it is an API call. Network is network. |
| SwiftTerm rendering issues at extreme scrollback | Low | Low | Cap scrollback at 5000 lines. Use Metal renderer. |
| libgit2 push/pull over Tailscale | Low | Medium | Use NWConnection (bypasses ATS). libgit2 handles TCP natively. |
| Gesture conflicts (Mode 2) | Medium | Medium | Extensive testing required. Direction-lock with 15pt threshold is proven pattern. |

### 31.2 Fallback Strategies

If the primary architecture (hidden WKWebView + SwiftTerm) fails:

**Fallback A:** Use WKWebView as VISIBLE terminal with xterm.js rendering (the original spec approach). Less native feel but proven.

**Fallback B:** Use a Swift-native reimplementation of the opencode TUI (SwiftUI views that mirror what OpenTUI renders). More work but eliminates the JS rendering layer entirely.

**Fallback C:** Use iSH-style Linux emulation to run actual opencode/Bun. Maximum compatibility, significant performance overhead.

---

## 32. CONFIGURATION REFERENCE

### 32.1 forge-config.json (Bundled Default)

```json
{
    "default_agent": "trident",
    "agent": {
        "build": { "disable": true },
        "plan": { "disable": true },
        "general": { "disable": true }
    },
    "permission": {
        "*": "allow",
        "bash": "allow",
        "read": { "*": "allow", "*.env": "ask", "*.env.*": "ask", "*.env.example": "allow" },
        "edit": { "*": "allow" },
        "external_directory": { "*": "ask" }
    },
    "provider": {
        "anthropic": { "npm": "@ai-sdk/anthropic" },
        "openai": { "npm": "@ai-sdk/openai" }
    }
}
```

### 32.2 forge-config-user.json (User Overrides)

Stored in Documents/forge-config-user.json. Merged with bundled default at runtime.

```json
{
    "model": {
        "provider": "anthropic",
        "id": "claude-sonnet-4-20250514"
    },
    "trident": {
        "god_loop_target": 96,
        "god_loop_max_cycles": 10,
        "audit_engine": {
            "semantic_filter": true,
            "skip_irrelevant_layers": true
        }
    }
}
```

### 32.3 esbuild Conditions Reference

| Condition | Active When | Effect |
|-----------|-------------|--------|
| browser | platform: 'browser' (always in our config) | Prefers browser-specific module exports |
| default | Always | Fallback when no other condition matches |
| import | ESM import statement | Not used in IIFE format |
| require | CommonJS require | Not used in IIFE format |
| bun | platform: 'bun' | NOT active (skipped) |
| node | platform: 'node' | NOT active (skipped) |

### 32.4 opencode Agent Configuration

The agent registry in opencode reads config and processes agent definitions:

```typescript
// From opencode's agent.ts:
for (const [key, value] of Object.entries(cfg.agent ?? {})) {
    if (value.disable) {
        delete agents[key]  // Vanilla agents removed
        continue
    }
    // ... merge custom config
}
```

With `build: { disable: true }`, `plan: { disable: true }`, and `general: { disable: true }`, only Trident and the hidden infrastructure agents (compaction, title, summary) remain.

### 32.5 Trident God Loop Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| god_loop_target | 96 | Quality score required for PASS |
| god_loop_max_cycles | 10 | Maximum cycles before forced PASS |
| semantic_filter | true | Skip irrelevant audit layers |
| checkpoint_per_cycle | true | Git commit after each cycle |
| revert_on_regression | true | Git revert if score drops |

---

## DOCUMENT METADATA

| Field | Value |
|-------|-------|
| Document ID | FORGE-ENG-SPEC-V1.0.0 |
| Classification | RUNTIME-GRADE ENGINEERING SPECIFICATION |
| Target System | FORGE iOS App v1.0.0 |
| Authoritative For | All components, both modes, full build sequence |
| Target Lines | 3000+ |
| Dependencies | opencode v1.14.43, Trident v4.4.2/v4.4.3, SwiftTerm, swift-libgit2 |
| iOS Target | 17.0+ |
| Swift Version | 5.9+ |
| Xcode Version | 15+ |

---

> **END OF FORGE ENGINEERING SPECIFICATION v1.0.0**
>
> "This document is the sole source of truth for building FORGE. An engineer reading only this spec can build the entire application. Every architectural decision is documented. Every constraint is defined. Every risk is identified. When the code disagrees with this document, the document is right."
>
> -- FORGE Engineering, 2026-07-25
