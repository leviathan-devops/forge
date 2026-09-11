# ARCHITECTURE BIBLE — FORGE iOS

**Last Updated:** 2026-07-27 Wave 7
**Source:** 51 files (30 Swift + 21 TS), 11,627 lines total, mechanically verified

---

## 1. THREE-LAYER ARCHITECTURE

```
╔══════════════════════════════════════════════════════════════════════╗
║                    LAYER 1: PRESENTATION (Swift)                     ║
║                  SwiftUI + UIKit + SwiftTerm (Metal)                 ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  ┌─────────────────┐    ┌──────────────────┐    ┌────────────────┐  ║
║  │  LaunchMenuView │───▶│ BuildOnDeviceScr │    │MissionControlScr│  ║
║  │  (Mode picker)  │    │  (Mode 1)        │    │  (Mode 2)      │  ║
║  └────────┬────────┘    └────────┬─────────┘    └───────┬────────┘  ║
║           │                      │                      │           ║
║     ┌─────┴─────┐         ┌──────┴──────┐        ┌──────┴──────┐    ║
║     │ ModeCard  │         │ForgeTerminal│        │SessionPager │    ║
║     │ParallaxBg │         │    View     │        │EagleVision  │    ║
║     └───────────┘         │ (SwiftTerm) │        │ServerPicker │    ║
║                           └─────────────┘        └─────────────┘    ║
║                                                                      ║
║  Shared: TopBar | SettingsSheet | ProjectManagerSheet | ForgeTheme   ║
║  Gestures: DirectionLockPanGesture | EagleVisionPinchHandler         ║
║  Security: KeychainHelper                                            ║
╚══════════════════════════════════════════════════════════════════════╝
                              │
                    feed(text:) / send(data:)
                              │
╔══════════════════════════════════════════════════════════════════════╗
║                    LAYER 2: BRIDGE (Swift ↔ JS)                      ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  ┌──────────────┐    ┌──────────────┐    ┌───────────────────┐      ║
║  │ ForgeEngine  │◀──▶│ ForgeBridge  │    │ ForgeCommandRunner│      ║
║  │ (WKWebView   │    │ (13 methods: │    │ (13 commands:     │      ║
║  │  lifecycle)  │    │  file/git/   │    │  ls/cat/grep/find │      ║
║  │              │    │  http/secret/│    │  mkdir/rm/cp/mv   │      ║
║  │ WeakScript   │    │  share/python│    │  wc/head/tail/    │      ║
║  │ MsgHandler   │    │  )           │    │  pwd/echo/touch)  │      ║
║  └──────┬───────┘    └──────┬───────┘    └───────────────────┘      ║
║         │                   │                                        ║
║  ┌──────┴───────┐    ┌──────┴───────┐    ┌───────────────────┐      ║
║  │ForgeGitMgr   │    │ConnectionMgr │    │RemoteSessionVM    │      ║
║  │(Phase 2:     │    │(Bonjour mDNS │    │(WebSocket TUI     │      ║
║  │ C libgit2)   │    │ discovery +  │    │ streaming via     │      ║
║  │              │    │ session poll)│    │ URLSession WS)    │      ║
║  └──────────────┘    └──────────────┘    └───────────────────┘      ║
╚══════════════════════════════════════════════════════════════════════╝
                              │
              evaluateJavaScript / postMessage
                              │
╔══════════════════════════════════════════════════════════════════════╗
║                 LAYER 3: EXECUTION (JavaScript)                      ║
║            Hidden WKWebView (0x0 frame, offscreen)                  ║
║         JIT + WASM + Web APIs (fetch, crypto, setTimeout)           ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  ┌─────────────────────────────────────────────────────────────┐    ║
║  │                  forge-bundle.js (esbuild IIFE)             │    ║
║  │                                                             │    ║
║  │  ┌─────────────┐  ┌──────────────┐  ┌────────────────────┐ │    ║
║  │  │  opencode   │  │   Trident    │  │     OpenTUI        │ │    ║
║  │  │   core      │  │   plugin     │  │  (SolidJS → ANSI)  │ │    ║
║  │  │             │  │              │  │                    │ │    ║
║  │  │ - sessions  │  │ - 18-layer   │  │ - terminal render  │ │    ║
║  │  │ - config    │  │   audit      │  │ - ANSI escape seq  │ │    ║
║  │  │ - tools     │  │ - God Loop   │  │ - cursor, color    │ │    ║
║  │  │ - Effect    │  │ - Poseidon   │  │ - alt screen       │ │    ║
║  │  │   runtime   │  │ - subagents  │  │ - 256/TrueColor    │ │    ║
║  │  └─────────────┘  └──────────────┘  └────────────────────┘ │    ║
║  │                                                             │    ║
║  │  ┌─────────────┐  ┌──────────────┐  ┌────────────────────┐ │    ║
║  │  │web-tree-    │  │  Vercel AI   │  │  Node.js shims     │ │    ║
║  │  │  sitter     │  │    SDK       │  │  (forge-*.ts)      │ │    ║
║  │  │ (WASM)      │  │  (LLM via    │  │  fs, crypto, http, │ │    ║
║  │  │             │  │   fetch)     │  │  stream, buffer,   │ │    ║
║  │  │ code parser │  │              │  │  process, sqlite   │ │    ║
║  │  └─────────────┘  └──────────────┘  └────────────────────┘ │    ║
║  └─────────────────────────────────────────────────────────────┘    ║
║                                                                      ║
║  WKWebView provides: JIT (Baseline→DFG→FTL), WASM, fetch(),         ║
║  crypto.subtle, TextEncoder, setTimeout, queueMicrotask             ║
╚══════════════════════════════════════════════════════════════════════╝
```

---

## 2. COMPLETE DATA FLOW — MODE 1 (Build On-Device / Terminal)

```
USER TYPES KEY
    │
    ▼
SwiftTerm TerminalView
    │  TerminalViewDelegate.send(source:data:)
    ▼
ForgeTerminalView (UIViewRepresentable wrapper)
    │  Captures ArraySlice<UInt8> from keyboard
    ▼
ForgeBridge.sendInput(data)
    │  Converts to base64 string
    ▼
ForgeEngine.evalJS("__forgeNative.input('\(base64)')")
    │  evaluateJavaScript on WKWebView
    ▼
WKWebView JavaScript Context
    │  __forgeNative.input() decodes base64
    ▼
opencode TUI input handler (OpenTUI)
    │  Processes keystroke (navigation, text input, etc.)
    ▼
opencode agent logic (Effect runtime)
    │  If command triggers agent: LLM API call via fetch()
    │  Effect fiber yields, resumes on API response
    ▼
OpenTUI re-renders (SolidJS virtual DOM)
    │  Produces new terminal screen state
    ▼
forge-terminal-surface.ts captureOutput()
    │  Converts SolidJS render → ANSI escape sequences
    │  (cursor position, colors, text, clear screen)
    ▼
__forgeNative.output(ansiString)
    │  window.webkit.messageHandlers.native.postMessage()
    ▼
ForgeEngine.userContentController(:didReceiveMessage:)
    │  WKScriptMessage handler callback
    │  Extracts ANSI string from message body
    ▼
terminalView.feed(text: ansiString)
    │  SwiftTerm parses ANSI escape sequences
    │  Updates internal terminal grid (rows × cols)
    ▼
SwiftTerm Metal Renderer
    │  Renders terminal grid via Metal GPU
    │  CoreText for glyph rendering (JetBrains Mono)
    ▼
USER SEES UPDATED TERMINAL SCREEN
```

**Latency budget:** Key press → screen update should be <16ms (one frame at 60fps).
- SwiftTerm rendering: ~2-5ms (Metal GPU, optimized)
- JS processing: depends on operation (simple input: <1ms, LLM call: 500ms+)
- Bridge overhead: <1ms (postMessage is async, near-zero cost)

---

## 3. COMPLETE DATA FLOW — MODE 2 (Mission Control / Remote)

```
APP LAUNCHES MODE 2
    │
    ▼
MissionControlScreen.onAppear
    │
    ▼
ConnectionManager.startBrowsing()
    │  NWBrowser(serviceType: "_opencode._tcp", type: .tcp)
    │  Discovers opencode servers on local network via mDNS/Bonjour
    ▼
NWBrowser.browseResultsUpdatedHandler
    │  For each discovered service: extract name, host, port
    ▼
ServerPickerSheet (manual fallback)
    │  User can enter host:port manually if no mDNS
    ▼
AppState.addServer(name, host, port)
    │  Persisted to UserDefaults
    ▼
RemoteSessionViewModel.openConnection()
    │
    ├─▶ URLSession GET http://<host>:<port>/api/sessions
    │       │  Returns JSON array of active sessions
    │       ▼
    │   Session list displayed in SessionPagerView
    │
    └─▶ User selects a session
            │
            ▼
        URLSessionWebSocketTask(url: ws://<host>:<port>/ws/session/<id>)
            │  Opens WebSocket to remote opencode TUI stream
            ▼
        webSocketTask.resume()
            │
            ▼
        receive() loop (async repeat)
            │  Reads WebSocket messages continuously
            │  Each message = ANSI output from remote terminal
            ▼
        DispatchQueue.main.async { terminalView.feed(text:) }
            │  SwiftTerm renders remote terminal output
            ▼
        USER SEES REMOTE TERMINAL STREAMING

PARALLEL: User input path
    SwiftTerm.send() → webSocket.send(.string(input)) → remote opencode
    Remote processes input → new ANSI output → WebSocket → feed()

GESTURE: Swipe between sessions
    DirectionLockPanGesture → SessionPagerView switches currentSession
    → WebSocket disconnects old, connects new

GESTURE: Pinch for Eagle Vision
    EagleVisionPinchHandler → scale > threshold → EagleVisionGridView
    → Shows 2xN grid of all session thumbnails
```

---

## 4. ANSI BRIDGE PIPELINE (Step by Step)

The pipeline that converts JavaScript terminal output to SwiftTerm rendering:

| Step | Layer | Component | Operation |
|------|-------|-----------|-----------|
| 1 | JS | OpenTUI SolidJS render | Produces virtual DOM with terminal cell grid |
| 2 | JS | forge-terminal-surface.ts | Intercepts OpenTUI's write() method via monkey-patch |
| 3 | JS | captureOutput() | Converts cell grid to ANSI escape sequences (cursor move, SGR colors, text) |
| 4 | JS | __forgeNative.output() | Calls window.webkit.messageHandlers.native.postMessage({type:'output', data: ansi}) |
| 5 | Swift | WKScriptMessage handler | ForgeEngine receives WKScriptMessage, extracts .body dictionary |
| 6 | Swift | Message routing | Checks message type field, routes to appropriate handler |
| 7 | Swift | terminalView.feed(text:) | SwiftTerm TerminalView ingests ANSI string (thread-safe, any thread OK) |
| 8 | Swift | SwiftTerm ANSI parser | Parses escape sequences, updates terminal grid (rows × cols of cells) |
| 9 | Swift | Metal renderer | Renders grid to screen via Metal GPU + CoreText glyphs |

**Reverse pipeline (input):** Steps 1-4 reversed — SwiftTerm captures keyboard → ForgeBridge → evalJS → opencode TUI input handler.

---

## 5. EVERY SWIFT FILE — Role and Key Methods

### App Layer
| File | Lines | Role | Key Methods/Types |
|------|-------|------|-------------------|
| `App/FORGEApp.swift` | 39 | App entry point, root view | `@main FORGEApp`, `WindowGroup`, injects `AppState` |
| `App/AppState.swift` | 502 | Global observable state (servers, projects, settings) | `loadServers()`, `addServer()`, `removeServer()`, `projectsDirectory`, `@Published` properties for all UI state |

### Bridge Layer
| File | Lines | Role | Key Methods/Types |
|------|-------|------|-------------------|
| `Bridge/ForgeEngine.swift` | 574 | WKWebView lifecycle, JS bridge setup, message handling | `startEngine()`, `stopEngine()`, `evalJS()`, `WeakScriptMessageHandler` (breaks retain cycle), `userContentController(:didReceiveMessage:)`, static `resolve()`/`reject()` |
| `Bridge/ForgeBridge.swift` | 451 | All 13 native operations exposed to JS | `setProject()`, `setProjectRoot()`, `resolveProjectPath()`, `readFile()`, `writeFile()`, `listFiles()`, `deleteFile()`, `searchFiles()`, `runCommand()`, `gitOperation()`, `httpRequest()`, `getSecret()`, `setSecret()`, `shareFile()`, `runPython()` |
| `Bridge/ForgeGitManager.swift` | 94 | Git operations (Phase 2: C libgit2 binding) | `gitOperation(args, operation, projectRoot, resolve, reject)` — currently returns Phase 2 messages |
| `Bridge/ForgeCommandRunner.swift` | 445 | 13 curated shell commands (no arbitrary exec) | `execute(args, cwd)` dispatches to: `cmdLs`, `cmdCat`, `cmdGrep`, `cmdFind`, `cmdMkdir`, `cmdRm`, `cmdCp`, `cmdMv`, `cmdWc`, `cmdHead`, `cmdTail`, `cmdTouch` (+ pwd/echo inline). Returns `CommandResult(stdout, stderr, exitCode)` |
| `Bridge/ConnectionManager.swift` | 281 | Bonjour mDNS discovery + session polling | `startBrowsing()`, `NWBrowser` setup, `browseResultsUpdatedHandler`, session list fetch via URLSession |
| `Bridge/RemoteSessionViewModel.swift` | 194 | WebSocket TUI streaming for Mode 2 | `openConnection()`, `closeConnection()`, WebSocket receive loop, `reconnectAttempts` with exponential backoff |

### Presentation — LaunchMenu
| File | Lines | Role | Key Methods/Types |
|------|-------|------|-------------------|
| `LaunchMenu/LaunchMenuView.swift` | 261 | Main mode picker screen | `.fullScreenCover` with switch to `BuildOnDeviceScreen` or `MissionControlScreen`, `.accessibilityIdentifier` for UI tests |
| `LaunchMenu/ModeCard.swift` | 96 | Tappable card for each mode | Spring animation, haptic feedback, cyan glow border |
| `LaunchMenu/ParallaxGridBackground.swift` | 113 | Animated grid background | `CMMotionManager` parallax via device motion, `@State` preserved across body evals |

### Presentation — Mode 1
| File | Lines | Role | Key Methods/Types |
|------|-------|------|-------------------|
| `Mode1_BuildOnDevice/BuildOnDeviceScreen.swift` | 409 | Mode 1 container, engine lifecycle | `startEngine()` (creates bridge before applying project), `stopEngine()`, retry button with leak guard, TopBar integration |
| `Mode1_BuildOnDevice/ForgeTerminalView.swift` | 167 | UIViewRepresentable wrapping SwiftTerm | `makeUIView()` creates TerminalView, `installColors()`, `setUseMetal()`, TerminalViewDelegate conformance, `feed()` passthrough |

### Presentation — Mode 2
| File | Lines | Role | Key Methods/Types |
|------|-------|------|-------------------|
| `Mode2_MissionControl/MissionControlScreen.swift` | 390 | Mode 2 container, session management | `currentSession` (optional, empty-array guard), server list, SessionPagerView integration |
| `Mode2_MissionControl/SessionPagerView.swift` | 289 | Swipeable session pager | TabView with PageTabViewStyle, DirectionLockPanGesture integration |
| `Mode2_MissionControl/EagleVisionGridView.swift` | 69 | Pinch-to-zoom grid of session thumbnails | LazyVGrid, scale animation |
| `Mode2_MissionControl/SessionThumbnailCard.swift` | 118 | Individual session card in grid | Terminal snapshot preview, connection status pill |
| `Mode2_MissionControl/ServerPickerSheet.swift` | 157 | Manual server entry (fallback to mDNS) | NavigationStack, text fields, validation |
| `Mode2_MissionControl/ConnectionStatusPills.swift` | 83 | Connection status indicators | Green/yellow/red pills, animated |

### Presentation — Shared
| File | Lines | Role | Key Methods/Types |
|------|-------|------|-------------------|
| `Shared/TopBar.swift` | 242 | Navigation bar with back button + network status | `.accessibilityIdentifier("backButton")`, network status dot |
| `Shared/SettingsSheet.swift` | 266 | Settings UI (API key, theme, preferences) | KeychainHelper integration, `.autocorrectionDisabled()`, `.textInputAutocapitalization(.never)` |
| `Shared/ProjectManagerSheet.swift` | 364 | Project selection and creation | Directory browsing, new project creation |

### Gestures
| File | Lines | Role | Key Methods/Types |
|------|-------|------|-------------------|
| `Gestures/DirectionLockPanGesture.swift` | 158 | Locks pan to horizontal OR vertical axis | `UIPanGestureRecognizer` subclass, direction lock after threshold, velocity tracking |
| `Gestures/EagleVisionPinchHandler.swift` | 108 | Pinch-to-zoom for Eagle Vision grid | `UIPinchGestureRecognizer`, scale threshold detection, haptic feedback on trigger |

### Theme
| File | Lines | Role | Key Methods/Types |
|------|-------|------|-------------------|
| `Theme/ForgeTheme.swift` | 315 | Color palette, fonts, ANSI 16-color array | `SwiftUI.Color.forgeBackground`, `.forgeAccent`, `.forgeCardBg`, `ansiColors: [SwiftTerm.Color]` (16 entries), JetBrains Mono constants |
| `Theme/Color+Hex.swift` | 74 | Hex string to SwiftUI.Color init | `init(hex:)` parses #RRGGBB to SwiftUI.Color |

### Security
| File | Lines | Role | Key Methods/Types |
|------|-------|------|-------------------|
| `Security/KeychainHelper.swift` | 123 | Keychain wrapper for API keys | `save(key:value:)`, `load(key:)`, `delete(key:)`, uses `SecItemAdd`/`SecItemCopyMatching` |

### UITests
| File | Lines | Role | Key Methods/Types |
|------|-------|------|-------------------|
| `UITests/FORGEUITests.swift` | 255 | XCUITest automation | Element queries by accessibilityIdentifier, tap simulation, navigation flow tests |
| `UITests/FORGEUITestsLaunchTests.swift` | 54 | Launch performance tests | Measures app launch time, screenshots |

---

## 6. BRIDGE METHOD INVENTORY (13 Methods + 3 Helpers)

All methods in `ForgeBridge.swift`, exposed to JavaScript via `window.webkit.messageHandlers.native`:

| # | Method | Signature | Purpose |
|---|--------|-----------|---------|
| 1 | `setProject` | `(_ name: String)` | Set active project name in engine state |
| 2 | `setProjectRoot` | `(_ path: String)` | Set filesystem root for file operations |
| 3 | `resolveProjectPath` | `(_ relativePath: String) -> String` | Resolve relative path against project root |
| 4 | `readFile` | `(_ args: [String:Any], callbackId:)` | Read file contents from project dir |
| 5 | `writeFile` | `(_ args: [String:Any], callbackId:)` | Write/create file in project dir |
| 6 | `listFiles` | `(_ args: [String:Any], callbackId:)` | List directory contents |
| 7 | `deleteFile` | `(_ args: [String:Any], callbackId:)` | Delete file or directory |
| 8 | `searchFiles` | `(_ args: [String:Any], callbackId:)` | Search file contents (grep) |
| 9 | `runCommand` | `(_ args: [String:Any], callbackId:)` | Execute curated shell command (13 commands) |
| 10 | `gitOperation` | `(_ args: [String:Any], callbackId:)` | Git operation (Phase 2: C libgit2) |
| 11 | `httpRequest` | `(_ args: [String:Any], callbackId:)` | HTTP request via URLSession |
| 12 | `getSecret` | `(_ args: [String:Any], callbackId:)` | Read from Keychain |
| 13 | `setSecret` | `(_ args: [String:Any], callbackId:)` | Write to Keychain |
| 14 | `shareFile` | `(_ args: [String:Any], callbackId:)` | Share file via UIActivityViewController |
| 15 | `runPython` | `(_ args: [String:Any], callbackId:)` | Execute Python via Pyodide (Phase 2) |
| — | `topMostViewController` | `() -> UIViewController?` (private) | Helper for presenting sheets |
| — | `resolve` | `(_ callbackId:, _ result:)` (private) | Send success callback to JS |
| — | `reject` | `(_ callbackId:, _ error:)` (private) | Send error callback to JS |

**Callback pattern:** JS calls `native.postMessage({method: "readFile", args: {...}, callbackId: "uuid"})`. Swift executes, then calls `engine.resolve(callbackId, result)` or `engine.reject(callbackId, error)` via `evaluateJavaScript`.

---

## 7. SPM DEPENDENCIES

| Package | Version | Source | Purpose |
|---------|---------|--------|---------|
| SwiftTerm | 1.15.0 | github.com/migueldeicaza/SwiftTerm | Native terminal rendering (UIScrollView subclass, Metal GPU, CoreText, ANSI parser, keyboard accessory) |
| SwiftGen (transitive) | 1.5.0 | (pulled by SwiftTerm) | SwiftTerm's build dependency |

**Removed dependencies:**
| Package | Reason |
|---------|--------|
| swift-libgit2 | Requires Swift 6.1. Xcode 15/16 has Swift 5.x. Phase 2: build libgit2 via CMake + ios-cmake, add C bridging header. |

**Declared in project.yml:**
```yaml
packages:
  SwiftTerm:
    url: https://github.com/migueldeicaza/SwiftTerm
    from: "1.15.0"
```

---

## 8. GESTURE SYSTEM ARCHITECTURE

### DirectionLockPanGesture (Session Swiping)
```
User swipes → UIPanGestureRecognizer fires
    │
    ▼
Track translation in X and Y over first 5 points
    │
    ▼
Determine dominant axis (|deltaX| vs |deltaY|)
    │
    ▼
Lock to that axis (ignore perpendicular movement)
    │
    ├─ Horizontal lock → SessionPagerView switches sessions
    │   - Velocity > threshold → fling to next/prev session
    │   - Slow drag → rubber-band scroll
    │
    └─ Vertical lock → ScrollView scrolls normally
```

### EagleVisionPinchHandler (Zoom to Grid)
```
Two-finger pinch → UIPinchGestureRecognizer fires
    │
    ▼
Track scale factor (relative to initial touch distance)
    │
    ▼
scale > 1.5 → Trigger Eagle Vision mode
    │
    ├─ Haptic feedback (UIImpactFeedbackGenerator.medium)
    ├─ Animate to LazyVGrid showing all session thumbnails
    └─ Dim non-focused sessions
    │
scale < 0.7 (reverse pinch from grid) → Exit Eagle Vision
    ├─ Haptic feedback
    └─ Animate back to single-session view
```

### Parallax Grid (Device Motion)
```
CMMotionManager starts device motion updates
    │  (must be @State to survive SwiftUI body re-evaluation)
    ▼
onEach motion update → read attitude.pitch, attitude.roll
    │
    ▼
Map to grid offset: offsetX = roll * 10, offsetY = pitch * 10
    │
    ▼
Grid lines shift → parallax depth illusion
    │
    ▼
onDisappear → stopDeviceMotionUpdates()
    (on the SAME @State instance that started updates)
```

---

## 9. TYPESCRIPT SHIM ARCHITECTURE

All Node.js APIs are shimmed in `forge/shims/`. esbuild aliases each `node:*` import to the corresponding shim:

| Node.js Module | Shim File | Lines | Strategy |
|----------------|-----------|-------|----------|
| `node:fs` | `forge-fs.ts` | 370 | Routes to ForgeBridge.readFile/writeFile (Swift FileManager) |
| `node:crypto` | `forge-crypto.ts` | 548 | Uses WebCrypto API (crypto.subtle) + custom hash implementations |
| `node:http`/`node:https` | `forge-http.ts` | 409 | Uses fetch() API, wraps in ServerResponse/IncomingMessage shape |
| `node:stream` | `forge-stream.ts` | 545 | EventEmitter-based Readable/Writable/Transform streams |
| `node:buffer` | `forge-buffer.ts` | 519 | Extends Uint8Array, adds Node.js Buffer API (toString, from, concat) |
| `node:util` | `forge-util.ts` | 466 | inherits, inspect, promisify, TextEncoder/TextDecoder |
| `node:events` | `forge-events.ts` | 272 | EventEmitter class with on/emit/removeListener |
| `node:os` | `forge-os.ts` | 121 | Platform info, homedir, tmpdir (returns iOS app sandbox paths) |
| `node:path` | `path-browserify` (npm) | — | NPM package, browser-compatible path module |
| `node:url` | `forge-url.ts` | 78 | URL parsing via browser URL constructor |
| `node:process` | `forge-process.ts` | 240 | Process env, argv, cwd, nextTick (→ setTimeout) |
| `bun:sqlite` | `forge-sqlite.ts` | 267 | SQL.js WASM (SQLite compiled to WebAssembly) |
| (no-op) | `forge-noop.ts` | 41 | Returns empty objects for modules we don't need |
