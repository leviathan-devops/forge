# BUILD MANIFEST — FORGE iOS

**Last Updated:** 2026-07-27 Wave 7
**Source:** `wc -l` verified line counts for every file
**Total Source Files:** 51 (30 Swift + 16 TS + 5 vendor .d.ts)
**Total Lines of Code:** 6,761 Swift + 4,866 TS = 11,627

---

## 1. SWIFT SOURCE FILES (30 files, 6,761 lines)

### App Layer (2 files, 541 lines)
| File | Path | Lines | Purpose |
|------|------|-------|---------|
| FORGEApp.swift | `iOS/FORGE/App/` | 39 | `@main` entry point, creates `WindowGroup`, injects `AppState` as `@StateObject` |
| AppState.swift | `iOS/FORGE/App/` | 502 | Global `@MainActor ObservableObject`. Manages servers (`@Published`), projects, settings. `loadServers()` from UserDefaults in `init()`. `addServer()`, `removeServer()`, `projectsDirectory` with fallback to temp dir. |

### Bridge Layer (7 files, 2,037 lines)
| File | Path | Lines | Purpose |
|------|------|-------|---------|
| ForgeEngine.swift | `iOS/FORGE/Bridge/` | 574 | WKWebView lifecycle manager. Creates hidden WKWebView (0x0 frame), configures `WKUserContentController`, registers message handler. `startEngine()`, `stopEngine()`, `evalJS()`. Contains `WeakScriptMessageHandler` proxy class to break retain cycle. Static `resolve(callbackId:_:)` and `reject(callbackId:_:)` send callbacks to JS via `evaluateJavaScript`. |
| ForgeBridge.swift | `iOS/FORGE/Bridge/` | 451 | All 13 native operations exposed to JavaScript. Each method receives `args: [String:Any]` and `callbackId: String?`. File ops route to FileManager, git ops to ForgeGitManager, commands to ForgeCommandRunner, secrets to KeychainHelper. `resolve`/`reject` private helpers send results back. |
| ForgeCommandRunner.swift | `iOS/FORGE/Bridge/` | 445 | Curated shell command executor. `execute(args:cwd:)` dispatches to 13 command implementations: `ls`, `cat`, `grep`, `find`, `mkdir`, `rm`, `cp`, `mv`, `wc`, `head`, `tail`, `touch` (+ `pwd`/`echo` inline). Returns `CommandResult(stdout:stderr:exitCode:)`. No arbitrary command execution — strict allowlist. |
| ConnectionManager.swift | `iOS/FORGE/Bridge/` | 281 | Bonjour mDNS server discovery. `startBrowsing()` creates `NWBrowser` for `_opencode._tcp`. `browseResultsUpdatedHandler` extracts discovered services. Session list polling via URLSession GET `/api/sessions`. |
| RemoteSessionViewModel.swift | `iOS/FORGE/Bridge/` | 194 | WebSocket TUI streaming for Mode 2. `openConnection()` creates `URLSessionWebSocketTask`. Async receive loop reads messages continuously. `reconnectAttempts` with exponential backoff (capped at 60s). Counter increment/reset on `sessionQueue` to prevent race conditions. |
| ForgeGitManager.swift | `iOS/FORGE/Bridge/` | 94 | Git operations (Phase 2 scaffold). `gitOperation(args:operation:projectRoot:resolve:reject:)` currently returns Phase 2 messages for all operations. Phase 2: build libgit2 as C static library via CMake + ios-cmake, add bridging header for full C API access. |
| KeychainHelper.swift | `iOS/FORGE/Security/` | 123 | Keychain wrapper for API keys and secrets. `save(key:value:)` uses `SecItemAdd`. `load(key:)` uses `SecItemCopyMatching`. `delete(key:)` uses `SecItemDelete`. All operations on default keychain access group. |

### Presentation — LaunchMenu (3 files, 470 lines)
| File | Path | Lines | Purpose |
|------|------|-------|---------|
| LaunchMenuView.swift | `iOS/FORGE/Presentation/LaunchMenu/` | 261 | Main mode picker screen. `fullScreenCover` with `switch mode` to `BuildOnDeviceScreen` or `MissionControlScreen` (not a temporary view — routes to real screens). `.accessibilityIdentifier` for UI test element queries. |
| ModeCard.swift | `iOS/FORGE/Presentation/LaunchMenu/` | 96 | Tappable card for each mode. Spring animation (response 0.35s, damping 0.8), `UIImpactFeedbackGenerator.medium` on tap, cyan glow border via shadow. |
| ParallaxGridBackground.swift | `iOS/FORGE/Presentation/LaunchMenu/` | 113 | Animated parallax grid background. Uses `@State private var motionManager` (NOT `private let` — SwiftUI recreates struct on body eval, would leak CMMotionManager). Device motion attitude maps to grid offset for depth illusion. |

### Presentation — Mode 1 BuildOnDevice (2 files, 576 lines)
| File | Path | Lines | Purpose |
|------|------|-------|---------|
| BuildOnDeviceScreen.swift | `iOS/FORGE/Presentation/Mode1_BuildOnDevice/` | 409 | Mode 1 container. `startEngine()` creates bridge/engine FIRST, stores them, THEN applies project (fixes nil-bridge bug). `stopEngine()` nils webView. Retry button checks `if engine != nil { stopEngine() }` before creating new one (prevents leak). TopBar integration with back button. |
| ForgeTerminalView.swift | `iOS/FORGE/Presentation/Mode1_BuildOnDevice/` | 167 | `UIViewRepresentable` wrapping SwiftTerm `TerminalView`. `makeUIView()` creates TerminalView, calls `installColors(ForgeTheme.ansiColors)`, wraps `setUseMetal(true)` in do-catch. Implements `TerminalViewDelegate` (11 methods). `feed(text:)` passthrough for ANSI data. |

### Presentation — Mode 2 MissionControl (6 files, 1,249 lines)
| File | Path | Lines | Purpose |
|------|------|-------|---------|
| MissionControlScreen.swift | `iOS/FORGE/Presentation/Mode2_MissionControl/` | 390 | Mode 2 container. `currentSession` returns `RemoteSession?` (optional with empty-array guard returning nil — fixes array OOB crash). Server list management, SessionPagerView integration. |
| SessionPagerView.swift | `iOS/FORGE/Presentation/Mode2_MissionControl/` | 289 | Swipeable session pager. `TabView` with `PageTabViewStyle`. DirectionLockPanGesture integration for axis-locked swiping. |
| ServerPickerSheet.swift | `iOS/FORGE/Presentation/Mode2_MissionControl/` | 157 | Manual server entry sheet (fallback to mDNS auto-discovery). `NavigationStack` (not deprecated `NavigationView`). `.textInputAutocapitalization(.never)`, `.autocorrectionDisabled()`. |
| SessionThumbnailCard.swift | `iOS/FORGE/Presentation/Mode2_MissionControl/` | 118 | Individual session thumbnail in Eagle Vision grid. Terminal snapshot preview, connection status pill overlay. |
| ConnectionStatusPills.swift | `iOS/FORGE/Presentation/Mode2_MissionControl/` | 83 | Connection status indicators. Green (connected), yellow (connecting), red (failed/disconnected). Animated transitions. |
| EagleVisionGridView.swift | `iOS/FORGE/Presentation/Mode2_MissionControl/` | 69 | Pinch-to-zoom grid of all session thumbnails. `LazyVGrid`, scale animation from single-session view. |

### Presentation — Shared (3 files, 872 lines)
| File | Path | Lines | Purpose |
|------|------|-------|---------|
| ProjectManagerSheet.swift | `iOS/FORGE/Presentation/Shared/` | 364 | Project selection and creation sheet. Directory browsing via FileManager, new project creation, project switching. |
| SettingsSheet.swift | `iOS/FORGE/Presentation/Shared/` | 266 | Settings UI. API key entry (KeychainHelper round-trip), theme confirmation, preferences. `.autocorrectionDisabled()`, `.textInputAutocapitalization(.never)`. |
| TopBar.swift | `iOS/FORGE/Presentation/Shared/` | 242 | Navigation bar with back button and network status indicator. `.accessibilityIdentifier("backButton")` for UI tests. Network status dot (green/red). |

### Gestures (2 files, 266 lines)
| File | Path | Lines | Purpose |
|------|------|-------|---------|
| DirectionLockPanGesture.swift | `iOS/FORGE/Gestures/` | 158 | `UIPanGestureRecognizer` subclass. Locks pan to horizontal OR vertical axis after initial movement threshold. Determines dominant axis from first 5 translation points. Velocity tracking for fling detection. |
| EagleVisionPinchHandler.swift | `iOS/FORGE/Gestures/` | 108 | `UIPinchGestureRecognizer` handler. Scale > 1.5 triggers Eagle Vision grid mode. Scale < 0.7 exits. `UIImpactFeedbackGenerator.medium` on trigger. |

### Theme (2 files, 389 lines)
| File | Path | Lines | Purpose |
|------|------|-------|---------|
| ForgeTheme.swift | `iOS/FORGE/Theme/` | 315 | Color palette (`SwiftUI.Color.forgeBackground` = #0A0A0F, `.forgeAccent` = #00F0FF), font constants (JetBrains Mono), `ansiColors: [SwiftTerm.Color]` array (16 entries: 8 normal + 8 bright ANSI colors as UInt16 RGB tuples). |
| Color+Hex.swift | `iOS/FORGE/Theme/` | 74 | `init(hex:)` extension on `SwiftUI.Color`. Parses `#RRGGBB` hex strings to RGB components. Used by theme for consistent color definitions. |

### UITests (2 files, 309 lines)
| File | Path | Lines | Purpose |
|------|------|-------|---------|
| FORGEUITests.swift | `iOS/FORGE/UITests/` | 255 | Main XCUITest suite. Element queries via `accessibilityIdentifier`, tap simulation, navigation flow verification. Tests FORGE title, mode buttons, back button. |
| FORGEUITestsLaunchTests.swift | `iOS/FORGE/UITests/` | 54 | Launch performance measurement. `measure {}` blocks for app startup time. Screenshot capture for regression comparison. |

---

## 2. TYPESCRIPT SOURCE FILES (21 files, 4,866 lines)

### Core Runtime (4 files, 975 lines)
| File | Path | Lines | Purpose |
|------|------|-------|---------|
| forge-terminal-surface.ts | `forge/src/` | 404 | Terminal output capture. Intercepts OpenTUI's write() method. Converts SolidJS virtual DOM render to ANSI escape sequences (cursor, SGR colors, text). Calls `__forgeNative.output()` to send ANSI to Swift via postMessage. |
| forge-runtime.ts | `forge/src/` | 308 | Runtime initialization. Bootstraps opencode Effect runtime, registers Trident plugin, configures agent registry (disables build/plan/general agents). Sets up `__forgeNative` global bridge object. |
| forge-entry.ts | `forge/src/` | 217 | esbuild entry point. Imports forge-runtime, starts opencode session, begins TUI loop. Exports `__forgeBoot()` function called by Swift on WKWebView load. |
| forge-identity.ts | `forge/src/` | 46 | FORGE identity text for Trident agent. Replaces default opencode identity with FORGE-specific system prompt. |

### Node.js Shims (12 files, 3,885 lines)
| File | Path | Lines | Purpose |
|------|------|-------|---------|
| forge-crypto.ts | `forge/shims/` | 548 | Node.js crypto module shim. Uses WebCrypto API (`crypto.subtle`) for hashing. Implements createHash, randomBytes, pbkdf2, createHmac using SubtleCrypto. |
| forge-stream.ts | `forge/shims/` | 545 | Node.js stream module shim. EventEmitter-based Readable, Writable, Transform, Duplex streams. Pipe() implementation. |
| forge-buffer.ts | `forge/shims/` | 519 | Node.js Buffer shim. Extends `Uint8Array`, adds Buffer API (toString with encoding, from, concat, alloc, allocUnsafe). `// @ts-ignore` on `static from` overload (TS structural checking too strict, runtime correct). |
| forge-util.ts | `forge/shims/` | 466 | Node.js util module shim. inherits, inspect, promisify, types. TextEncoder/TextDecoder wrappers. |
| forge-http.ts | `forge/shims/` | 409 | Node.js http/https module shim. Uses fetch() API. Wraps response in ServerResponse/IncomingMessage shape for compatibility. |
| forge-fs.ts | `forge/shims/` | 370 | Node.js fs module shim. Routes readFileSync/writeFileSync to `__forgeNative.readFile()`/`writeFile()` (Swift FileManager). All paths resolved against project root. |
| forge-events.ts | `forge/shims/` | 272 | Node.js events module shim. EventEmitter class with on, once, emit, removeListener, removeAllListeners. |
| forge-sqlite.ts | `forge/shims/` | 267 | bun:sqlite shim. Uses SQL.js (SQLite compiled to WASM). Loads wasm binary, creates Database instances. |
| forge-process.ts | `forge/shims/` | 240 | Node.js process module shim. process.env, process.argv, process.cwd, process.platform (returns 'ios'). nextTick implemented via macrotask queue scheduling. |
| forge-os.ts | `forge/shims/` | 121 | Node.js os module shim. platform(), homedir() (iOS app sandbox), tmpdir() (NSTemporaryDirectory equivalent). |
| forge-url.ts | `forge/shims/` | 78 | Node.js url module shim. Uses browser URL constructor. parse, format, resolve wrappers. |
| forge-noop.ts | `forge/shims/` | 41 | No-op module. Returns empty objects for Node.js modules FORGE doesn't need (cluster, dgram, net). |

### Type Declarations (5 files, 15 lines)
| File | Path | Lines | Purpose |
|------|------|-------|---------|
| opencode-agent.d.ts | `forge/src/vendor/` | 3 | Type declaration for opencode agent module |
| opencode-config.d.ts | `forge/src/vendor/` | 3 | Type declaration for opencode config module |
| opencode-plugin.d.ts | `forge/src/vendor/` | 3 | Type declaration for opencode plugin module |
| opencode-session.d.ts | `forge/src/vendor/` | 3 | Type declaration for opencode session module |
| trident-plugin.d.ts | `forge/src/vendor/` | 3 | Type declaration for Trident plugin module |

---

## 3. CONFIG / BUILD FILES

| File | Path | Lines | Purpose |
|------|------|-------|---------|
| project.yml | `/` | 87 | xcodegen project specification. Defines FORGE app target (iOS 17.0, SwiftTerm dep) and FORGEUITests target. Info.plist properties (fonts, orientations, Bonjour, ATS). |
| ios-build-test.yml | `.github/workflows/` | 168 | CI pipeline. 2 jobs: build (macos-14, xcodebuild + simctl + UI tests) and test-typescript (ubuntu-latest, tsc --noEmit + esbuild test). Artifact uploads. |
| Package.swift | `/` | 70 | Root SPM package (for tooling/scripts, not app build). |
| package.json | `forge/` | 40 | TS dependencies (path-browserify, sql.js), devDeps (esbuild, typescript, @types/node). Scripts: build, dev, typecheck, clean. |
| tsconfig.json | `forge/` | ~30 | TS compiler config. target ES2020, module ESNext, strict true, noEmit for typecheck. |
| build-forge-bundle.mjs | `scripts/` | ~120 | esbuild configuration. platform browser, format iife, target safari16, conditions browser+default. Aliases node:* to forge shims. Inject process/Buffer globals. Minify + treeShake. |
| xcode-build-phase.sh | `scripts/` | ~20 | Xcode pre-build script (placeholder for bundle integration). |
| run-macos-vm.sh | `scripts/` | ~15 | Docker-OSX launcher script. Headless mode (-display none), SSH port 50922. |

---

## 4. ASSET / RESOURCE FILES

| File | Path | Purpose |
|------|------|---------|
| Icon-1024.png | `iOS/FORGE/Resources/Assets.xcassets/AppIcon.appiconset/` | 1024x1024 app icon. Dark bg (#0A0A0F), cyan F (#00F0FF), monospace. Generated programmatically. |
| Assets.xcassets | `iOS/FORGE/Resources/` | Asset catalog root. Contains AppIcon.appiconset and AccentColor color set. |
| LaunchScreen.storyboard | `iOS/FORGE/Resources/` | Launch screen. Black bg, centered FORGE title in JetBrains Mono, cyan accent line. |
| forge-config.json | `iOS/FORGE/Resources/` | opencode agent config. default_agent: trident. Disables build, plan, general agents. |
| forge-identity.md | `iOS/FORGE/Resources/` | FORGE identity text for Trident system prompt. |
| AppIcon.svg | `iOS/FORGE/Resources/` | Vector source for app icon. |
| Info.plist | `iOS/FORGE/` | App config (via xcodegen). Bundle ID com.forge.app, fonts, orientations, Bonjour services, ATS settings. |
| FORGE.entitlements | `iOS/FORGE/` | App entitlements (currently empty — no signing for simulator builds). |

---

## 5. SPM DEPENDENCIES

| Package | Version | Product | Purpose |
|---------|---------|---------|---------|
| SwiftTerm | 1.15.0 | SwiftTerm | Native iOS terminal rendering. UIScrollView subclass with Metal GPU backend. ANSI escape parser. TerminalViewDelegate protocol. Keyboard accessory bar. |
| SwiftGen (transitive) | 1.5.0 | (internal) | SwiftTerm's build dependency, auto-resolved. |

### NPM Dependencies (forge/package.json)
| Package | Version | Purpose |
|---------|---------|---------|
| path-browserify | ^1.0.1 | Browser-compatible Node.js path module |
| sql.js | ^1.10.3 | SQLite compiled to WebAssembly (for bun:sqlite shim) |
| esbuild (dev) | ^0.23.0 | JavaScript bundler |
| typescript (dev) | ^5.5.4 | TypeScript compiler |
| @types/node (dev) | ^20.14.0 | Node.js type definitions |
