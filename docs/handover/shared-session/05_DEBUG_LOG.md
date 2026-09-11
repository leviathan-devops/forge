# FORGE — Debug Log

**Initialized:** 2026-07-25
**Last Updated:** 2026-07-27 Wave 7
**Total Bugs Found:** 26 (22 code + 4 VM infrastructure)
**All Code Bugs Resolved:** Yes | VM Bugs: Partially

---

## CI Build Failures (8 iterations to first success)

### Bug #1: Workflow Branch Name Mismatch
- **Date:** 2026-07-25 | **Category:** CI Configuration
- **CI Run:** 30168447839 (22s)
- **Commit:** 1429858
- **Symptom:** CI never triggered on push
- **Root Cause:** GitHub Actions workflow targeted `branches: [main, dev]` but repo default is `master`
- **Fix:** Changed to `branches: [master]`
- **Impact:** Lost one CI cycle (22s)

### Bug #2: SwiftTerm Version 2.0.0 Does Not Exist
- **Date:** 2026-07-25 | **Category:** SPM Dependency
- **CI Run:** 30168945393 (54s)
- **Commit:** fd30340
- **Symptom:** SPM resolution fails — package not found
- **Root Cause:** Subagent assumed SwiftTerm 2.0.0 exists. Actual latest tag: v1.15.0
- **Fix:** Changed project.yml `from: "2.0.0"` to `from: "1.15.0"`
- **Verification:** `gh api repos/migueldeicaza/SwiftTerm/tags --jq '.[].name'` confirmed v1.15.0 is latest

### Bug #3: swift-libgit2 Requires Swift 6.1
- **Date:** 2026-07-25 | **Category:** SPM Dependency
- **CI Run:** 30168945393 (54s, same run as #2)
- **Commit:** fd30340
- **Symptom:** Package resolution fails for swift-libgit2
- **Root Cause:** swift-libgit2 Package.swift specifies `swift-tools-version: 6.1`. Xcode 15/16 ships Swift 5.x
- **Fix:** Removed swift-libgit2 dependency entirely. Stubbed ForgeGitManager. Phase 2 will add libgit2 via CMake + C bridging header
- **Trade-off:** Git operations return "Phase 2 feature" messages instead of working

### Bug #4: Color Type Ambiguity (SwiftUI.Color vs SwiftTerm.Color)
- **Date:** 2026-07-25 | **Category:** Swift Compilation — Type System
- **CI Runs:** 30169155844 (52s), 30169269435 (1m13s), 30169435718 (51s), 30170099414 (52s) — 4 iterations
- **Commits:** b080a41, 2662c2e, 1c550dd, b836553
- **Symptom:** "'Color' is ambiguous for type lookup in this context"
- **Root Cause:** SwiftTerm defines its own `Color` struct. In Swift's single-target app model, ALL imports from ALL files are visible to ALL other files (transitive visibility). This makes bare `Color` ambiguous project-wide whenever SwiftTerm is imported by ANY file.
- **Fix (4-step iterative):**
  1. `extension Color` -> `extension SwiftUI.Color` in ForgeTheme.swift
  2. `Color.forgeXXX` -> `SwiftUI.Color.forgeXXX` across 13 files (global sed replacement)
  3. `: Color` type annotations -> `: SwiftUI.Color` across all files
  4. `Color(red:green:blue:)` -> `SwiftUI.Color(red:green:blue:)` inside extension body (the bare initializer was STILL resolving to SwiftTerm.Color even inside `extension SwiftUI.Color`!)
- **Pattern Recorded:** See SoC_PRESERVATION.md for the full pattern documentation

### Bug #5: SwiftTerm.Color Initializer Label Mismatch
- **Date:** 2026-07-25 | **Category:** SwiftTerm API
- **CI Run:** 30169269435 (1m13s)
- **Commit:** 2662c2e
- **Symptom:** "incorrect argument labels in call (have 'red8:green8:blue8:', expected 'red:green:blue:')"
- **Root Cause:** Code used `SwiftTerm.Color(red8: 0xFF, green8: 0x55, blue8: 0x55)`. SwiftTerm v1.15.0's Color struct has `init(red: UInt16, green: UInt16, blue: UInt16)`, not the `red8:green8:blue8:` variant.
- **Fix:** Changed to `SwiftTerm.Color(red: 0xFF, green: 0x55, blue: 0x55)` — raw hex values inferred as UInt16

### Bug #6: ForgeGitManager Signature Mismatch
- **Date:** 2026-07-25 | **Category:** API Mismatch
- **CI Run:** 30170099414 (52s)
- **Commit:** e85837e
- **Symptom:** "extra arguments at positions #2, #4, #5 in call" and "missing arguments for parameters 'callbackId', 'webView'"
- **Root Cause:** ForgeBridge (written by subagent A) calls `gitManager.gitOperation(args, operation:, projectRoot:, resolve:, reject:)` with closures. My ForgeGitManager stub (written directly) had `gitOperation(args, callbackId:, webView:, projectRoot:)` with different parameters.
- **Fix:** Rewrote ForgeGitManager to match closure-based API: `func gitOperation(_ args:, operation:, projectRoot:, resolve: @escaping (Any) -> Void, reject: @escaping (String) -> Void)`

### Bug #7: TerminalView Has No scrollView Property
- **Date:** 2026-07-25 | **Category:** SwiftTerm API
- **CI Run:** 30170099414 (52s, same as #6)
- **Commit:** e85837e
- **Symptom:** "value of type 'TerminalView' has no member 'scrollView'"
- **Root Cause:** Code used `view.scrollView.bounces = true`. SwiftTerm's TerminalView inherits from UIScrollView — it IS the scroll view, it doesn't HAVE one as a property.
- **Fix:** `view.scrollView.bounces` -> `view.bounces`, `view.scrollView.alwaysBounceHorizontal` -> `view.alwaysBounceHorizontal`, `view.scrollView.showsVerticalScrollIndicator` -> `view.showsVerticalScrollIndicator`

### Bug #8: [weak self] on Struct + listRowCornerRadius
- **Date:** 2026-07-25 | **Category:** Swift Language
- **CI Run:** 30170214935 (1m7s)
- **Commit:** 56046a7
- **Symptom:** "'weak' may only be applied to class and class-bound protocol types, not 'ParallaxGridBackground'" and "value of type 'some View' has no member 'listRowCornerRadius'"
- **Root Cause:** ParallaxGridBackground is a SwiftUI View struct (value type). `[weak self]` requires reference types (classes). `.listRowCornerRadius(10)` was hallucinated by subagent — it doesn't exist in UIKit/SwiftUI.
- **Fix:** Removed `[weak self]` capture list from CMMotionManager closure. Removed `.listRowCornerRadius(10)` line entirely.

### Bug #9: TopBar Duplicate Lines from Audit Subagent
- **Date:** 2026-07-25 | **Category:** Subagent Error
- **CI Run:** Build failed after audit subagent commit
- **Commit:** aed95fa (fix)
- **Symptom:** "extraneous '}' at top level" and "expected declaration"
- **Root Cause:** Audit subagent added `.accessibilityIdentifier("backButton")` to TopBar.swift but duplicated the preceding `.buttonStyle(PlainButtonStyle())` and closing `}` in the process. Created a structural break.
- **Fix:** Removed the duplicate 3 lines. Verified structure manually.

---

## Runtime Bugs (Found by Audit Subagent — Not Caught by CI)

### Bug #10: BuildOnDeviceScreen Nil Bridge — CRITICAL
- **Severity:** CRITICAL (silent failure)
- **File:** BuildOnDeviceScreen.swift
- **Desc:** `startEngine()` called `applyProject()` BEFORE creating the bridge. `bridge?.setProjectRoot()` hit a nil bridge, so the project root was never set on the new engine. Git init was silently skipped.
- **Fix:** Restructured method to create bridge/engine first, store them, then apply project.

### Bug #11: Engine Leak on Retry — CRITICAL
- **Severity:** CRITICAL (memory leak)
- **File:** BuildOnDeviceScreen.swift
- **Desc:** Retry button created a new ForgeEngine + WKWebView without stopping the old one. Each retry leaked an entire JS heap (~50-100MB).
- **Fix:** Added `if engine != nil { stopEngine() }` guard at top of `startEngine()`.

### Bug #12: Fatal Array Index Out of Bounds — CRITICAL
- **Severity:** CRITICAL (crash)
- **File:** MissionControlScreen.swift
- **Desc:** `currentSession` computed property accessed `sessions[sessions.count - 1]`. When sessions array was empty, this evaluated to `sessions[-1]` → `EXC_BAD_ACCESS` crash.
- **Fix:** Made `currentSession` return `RemoteSession?` (optional) with empty-array guard returning nil.

### Bug #13: Negative Tail Offset — CRITICAL
- **Severity:** CRITICAL (crash)
- **File:** ForgeCommandRunner.swift
- **Desc:** `tail -n-5 file.txt` parsed `n = -5`, producing `offset = lines.count + 5`. Then `Array(lines[offset...])` crashed because offset exceeded array bounds.
- **Fix:** Added `n = max(0, n)` clamp and `safeOffset = min(offset, lines.count)` bounds check.

### Bug #14: WKWebView Retain Cycle — HIGH
- **Severity:** HIGH (memory leak per mode transition)
- **File:** ForgeEngine.swift
- **Desc:** `WKUserContentController.add(self, name:)` retains its handler. This created a retain cycle: engine → webView → config → controller → engine. Every mode entry/exit leaked the entire engine + WKWebView + JS heap.
- **Fix:** Created `WeakScriptMessageHandler` proxy class that wraps the engine weakly. Changed `webView` from `WKWebView!` to `WKWebView?`. Added `teardown()` method that nil's the webView.

### Bug #15: CMMotionManager Leak — HIGH
- **Severity:** HIGH (battery drain, accelerometer runs forever)
- **File:** ParallaxGridBackground.swift
- **Desc:** `motionManager` was `private let` (not `@State`). SwiftUI recreates the struct on every body evaluation. `onDisappear` called `stopDeviceMotionUpdates()` on a DIFFERENT CMMotionManager instance than the one that started updates. The original ran forever.
- **Fix:** Changed to `@State private var` so SwiftUI preserves the instance across body evaluations.

### Bug #16: Reconnect Counter Never Reset — HIGH
- **Severity:** HIGH (backoff grows permanently)
- **File:** RemoteSessionViewModel.swift
- **Desc:** `reconnectAttempts` was incremented on a background URLSession callback. It was reset by reading `isConnected` on `sessionQueue` before the main-thread dispatch executed. The counter never reset, so backoff grew to 60s permanently after first disconnect.
- **Fix:** Moved counter increment to `sessionQueue`. Reset in `openConnection()` via `sessionQueue.async`.

### Bug #17: Servers Never Loaded on Init — MEDIUM
- **Severity:** MEDIUM (data loss)
- **File:** AppState.swift
- **Desc:** `init()` never called `loadServers()`. Saved servers from UserDefaults were lost on every app restart.
- **Fix:** Added `loadServers()` call in `init()`.

### Bug #18: Force-Unwrap on Projects Directory — MEDIUM
- **Severity:** MEDIUM (crash if Documents dir missing)
- **File:** AppState.swift
- **Desc:** `projectsDirectory` used `.first!` force-unwrap on `FileManager.urls(for:in:)`.
- **Fix:** Added `?? FileManager.default.temporaryDirectory` fallback.

### Bug #19: Placeholder Instead of Real Mode Screens — MEDIUM
- **Severity:** MEDIUM (feature completely broken)
- **File:** LaunchMenuView.swift
- **Desc:** `fullScreenCover` always showed `ModePlaceholderView` instead of the real `BuildOnDeviceScreen` / `MissionControlScreen`. The actual mode screens were NEVER reachable from the launch menu.
- **Fix:** Replaced with `switch mode` that shows real screens.

### Bug #20: Deprecated APIs — LOW
- **File:** ServerPickerSheet.swift
- **Desc:** Used `.autocapitalization(.none)` / `.disableAutocorrection(true)` (deprecated in iOS 16+) and `NavigationView` (deprecated in iOS 16+).
- **Fix:** Updated to `.textInputAutocapitalization(.never)` / `.autocorrectionDisabled()` / `NavigationStack`.

### Bug #21: Silent JavaScript Errors — LOW
- **File:** ForgeEngine.swift
- **Desc:** All `evaluateJavaScript` calls used `completionHandler: nil`. JS errors were silently dropped, making debugging impossible.
- **Fix:** Added `evalJS()` helper that logs errors in `#if DEBUG` builds.

### Bug #22: Docker-OSX GTK Display Failure
- **Date:** 2026-07-25
- **Desc:** Docker-OSX failed with "gtk initialization failed" on first two attempts.
- **Root Cause:** QEMU uses GTK display by default. Our Linux server is headless (no X11/Wayland).
- **Fix:** Used VNC display (`-vnc 0.0.0.0:0`) instead of GTK. Works for screenshots and mouse.
- **Status:** RESOLVED

---

## VM Infrastructure Bugs (Wave 7, 2026-07-27)

### Bug #23: VNC Keyboard Events Don't Work in macOS/OpenCore
- **Severity:** CRITICAL (blocks macOS interaction)
- **Desc:** RFB key events sent via VNC protocol are not processed by macOS Recovery or OpenCore. Mouse works, keyboard doesn't.
- **Root Cause:** QEMU's USB keyboard emulation has a known bug where VNC keyboard events don't reach macOS HID driver.
- **Fix:** Use QEMU monitor `sendkey` command instead. Connect to monitor via `docker exec forge-vm python3 → socket 127.0.0.1:4444 → sendkey ret`. sendkey bypasses VNC entirely, sends keyboard events through QEMU hardware emulation layer.
- **Status:** RESOLVED (sendkey works — 358K pixels changed after sendkey ret)

### Bug #24: vncdotool (Twisted VNC client) Connection Refused
- **Severity:** MEDIUM (blocks screenshot capture)
- **Desc:** vncdotool Python API and CLI both fail with "Connection was refused" even though VNC port is open (nc succeeds, RFB banner received).
- **Root Cause:** Twisted reactor incompatibility with QEMU's VNC server implementation.
- **Fix:** Use `vncsnapshot -quiet localhost:0 /tmp/snap.jpg` instead (C-based TightVNC client, works perfectly).
- **Status:** RESOLVED

### Bug #25: scrot/grim Cannot Capture Wayland/XWayland Surfaces
- **Severity:** MEDIUM (blocks screenshot capture)
- **Desc:** scrot captures black screen (0,0,0). grim fails with "failed to create display". Weston's headless backend renders to memory buffers, not capturable surfaces.
- **Root Cause:** XWayland rootless mode doesn't expose windows to X11 screenshot tools. Weston headless backend doesn't create capturable Wayland surfaces.
- **Fix:** Use vncsnapshot instead — captures directly from QEMU's VNC framebuffer.
- **Status:** RESOLVED

### Bug #26: macOS Sonoma Kernel Stuck in Verbose Boot
- **Severity:** CRITICAL (blocks macOS VM)
- **Desc:** After `sendkey ret` boots macOS from OpenCore, Darwin kernel 23.6.0 starts (verbose boot text appears) but screen freezes. QEMU CPU usage drops to ~9.9% (idle). Screen static for 5+ minutes.
- **Root Cause:** Unknown — possible CPU feature incompatibility, driver hang, or Sonoma-specific QEMU issue.
- **Potential Fixes:**
  1. Try macOS Ventura (option 6) instead of Sonoma (option 7)
  2. Try `-cpu host` for CPU passthrough
  3. Try more RAM (`-m 8192`)
  4. Try OpenCore nopicker config
- **Status:** UNRESOLVED — top priority for next session

### Bug #27: Docker Commit Doesn't Capture qcow2 Changes
- **Severity:** MEDIUM (loses disk state)
- **Desc:** Docker commit of running container captures filesystem state but qcow2 disk image changes (macOS installation progress) are NOT included.
- **Root Cause:** qcow2 uses copy-on-write. Docker commit captures the base file, not the delta written during VM operation.
- **Fix:** Use volume mounts for persistent disk state, or export qcow2 separately.
- **Status:** NOTED (workaround: re-download BaseSystem each session)