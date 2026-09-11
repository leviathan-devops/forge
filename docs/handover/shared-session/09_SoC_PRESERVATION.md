# SoC PRESERVATION — State of Consciousness

**Last Updated:** 2026-07-27 Wave 7

This document captures every pattern, gotcha, lesson learned, and non-obvious behavior discovered during the FORGE build. These are the things that will trip you up if you forget them.

---

## SWIFT + SWIFTTERM PATTERNS

### Pattern: SwiftTerm/SwiftUI Color Collision (CRITICAL)
- **Context:** When both SwiftUI and SwiftTerm are imported in the same Swift target (even in different files), bare `Color` references are ambiguous. SwiftTerm defines its own `Color` struct. In Swift's single-target app model, ALL imports from ALL files are visible to ALL other files via transitive visibility.
- **Impact:** Compilation failure: "'Color' is ambiguous for type lookup in this context". Affects EVERY file in the target, even files that only import SwiftUI.
- **Solution:** Qualify ALL Color references as `SwiftUI.Color`:
  - `extension Color {` → `extension SwiftUI.Color {`
  - `Color.forgeBackground` → `SwiftUI.Color.forgeBackground`
  - `Color.clear` → `SwiftUI.Color.clear`
  - `color: Color` → `color: SwiftUI.Color`
  - `Color(red:green:blue:)` → `SwiftUI.Color(red:green:blue:)` — even INSIDE `extension SwiftUI.Color`! The bare initializer inside the extension body was STILL resolving to SwiftTerm.Color.
- **How to apply globally:** `find . -name "*.swift" -exec perl -pi -e 's/\bColor\.(forge\w+)/SwiftUI.Color.$1/g; s/\bColor\.clear/SwiftUI.Color.clear/g; s/:\s*Color\b/: SwiftUI.Color/g' {} \;`
- **Source:** CI failures runs 3-5 (2026-07-25), took 4 iterations to fully resolve
- **Severity:** CRITICAL — blocks compilation entirely

### Pattern: SwiftTerm.Color API (v1.15.0)
- **Context:** SwiftTerm v1.15.0's Color struct uses `init(red: UInt16, green: UInt16, blue: UInt16)`.
- **What DOESN'T work:**
  - `SwiftTerm.Color(red8: 0xFF, green8: 0x55, blue8: 0x55)` — initializer doesn't exist
  - `SwiftTerm.Color(red: Double(0xFF)/255.0, ...)` — wrong type (Double, not UInt16)
- **What DOES work:**
  - `SwiftTerm.Color(red: 0xFF, green: 0x55, blue: 0x55)` — Swift infers UInt16 from parameter type
- **Source:** CI failure run 4 (2026-07-25)

### Pattern: TerminalView IS a UIScrollView
- **Context:** SwiftTerm's TerminalView inherits from UIScrollView on iOS. It IS the scroll view, not a view that contains one.
- **What DOESN'T work:** `terminalView.scrollView.bounces = true` — no scrollView property exists
- **What DOES work:** `terminalView.bounces = true` — access UIScrollView properties directly
- **Source:** CI failure run 6 (2026-07-25)
- **Contrast:** WKWebView DOES have a separate `scrollView` property. Don't confuse the two.

### Pattern: SwiftTerm TerminalViewDelegate Protocol
- **Context:** The TerminalViewDelegate protocol has specific method signatures that must match exactly.
- **Required methods:**
  ```swift
  func send(source: TerminalView, data: ArraySlice<UInt8>)
  func sizeChanged(source: TerminalView, newCols: Int, newRows: Int)
  func setTerminalTitle(source: TerminalView, title: String)
  func requestOpenLink(source: TerminalView, link: String, params: [String: String])
  func bell(source: TerminalView)
  func clipboardCopy(source: TerminalView, content: Data)
  func clipboardRead(source: TerminalView) -> Data?
  func scrolled(source: TerminalView, position: Double)
  func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?)
  func iTermContent(source: TerminalView, content: ArraySlice<UInt8>)
  func rangeChanged(source: TerminalView, startY: Int, endY: Int)
  ```
- **Verified:** All methods confirmed valid against SwiftTerm v1.15.0 source.

### Pattern: SwiftTerm feed() is Thread-Safe
- **Context:** `terminalView.feed(text:)` and `terminalView.feed(byteArray:)` can be called from ANY thread.
- **Impact:** No need for `DispatchQueue.main.async` when feeding ANSI data from background queues or WKWebView callbacks.
- **Source:** SwiftTerm README: "Thread-safe Terminal instances"

### Pattern: SwiftTerm installColors() Takes [SwiftTerm.Color]
- **Context:** `terminalView.installColors(colors)` expects an array of exactly 16 `SwiftTerm.Color` values.
- **Format:** Index 0-7 are normal ANSI colors, 8-15 are bright variants.
- **Example:** `terminalView.installColors(ForgeTheme.ansiColors)` where `ansiColors` is `[SwiftTerm.Color]` with 16 entries.

### Pattern: SwiftTerm setUseMetal() Throws
- **Context:** `try terminalView.setUseMetal(true)` can throw if Metal is not available (older devices, simulator without GPU).
- **Pattern:** Always wrap in do-catch:
  ```swift
  do { try view.setUseMetal(true) } catch { print("Metal unavailable, using CoreGraphics") }
  ```

---

## SWIFT LANGUAGE PATTERNS

### Pattern: [weak self] Only Works on Classes
- **Context:** SwiftUI Views are structs (value types). `[weak self]` in a closure capture list requires reference types (classes).
- **Impact:** "'weak' may only be applied to class and class-bound protocol types"
- **Solution:** In struct contexts, just remove the capture list entirely. Structs are captured by value (copy), so there's no retain cycle risk.
- **Source:** CI failure run 7 (ParallaxGridBackground.swift)

### Pattern: CMMotionManager Must Be @State in SwiftUI
- **Context:** If `motionManager` is `private let`, SwiftUI recreates the struct on every body evaluation. `onDisappear` then calls `stopDeviceMotionUpdates()` on a DIFFERENT instance. The original motion manager keeps running forever (battery drain).
- **Solution:** Use `@State private var motionManager = CMMotionManager()` so SwiftUI preserves the instance.

### Pattern: Avoid listRowCornerRadius
- **Context:** `.listRowCornerRadius()` was hallucinated by a subagent. It does not exist in the iOS SDK (as of iOS 17).
- **Solution:** Don't use it. If you need rounded list rows, use `.listRowBackground()` with a custom shape or `.background()` on the row content.

### Pattern: Use NavigationStack, Not NavigationView
- **Context:** `NavigationView` was deprecated in iOS 16. `NavigationStack` is the replacement.
- **Solution:** Always use `NavigationStack` in new code.

---

## SPM / DEPENDENCY PATTERNS

### Pattern: swift-libgit2 Requires Swift 6.1
- **Context:** The swift-libgit2 SPM package specifies `swift-tools-version: 6.1` in its Package.swift.
- **Impact:** Won't resolve on Xcode 15/16 (which ship Swift 5.x).
- **Solution:** Don't use swift-libgit2. Build libgit2 directly via CMake + ios-cmake toolchain. Create a C bridging header. This gives full C API access without the Swift wrapper.
- **Alternative:** Wait for swift-libgit2 to support Swift 5.x (unlikely — they chose 6.1 deliberately).

### Pattern: Always Verify SPM Package Versions
- **Context:** Subagents may assume version numbers that don't exist.
- **How to verify:** `gh api repos/<owner>/<repo>/tags --jq '.[].name' | head -10`
- **Example:** SwiftTerm was assumed at v2.0.0 but latest is v1.15.0.

---

## CI / GITHUB ACTIONS PATTERNS

### Pattern: GitHub Actions Branch Names Must Match Repo Default
- **Context:** `gh repo create` creates repos with `master` as default branch (not `main`).
- **Impact:** If workflow specifies `branches: [main]`, it never triggers.
- **Solution:** Always check `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'` and match the workflow.

### Pattern: Xcode Selection on macOS Runners
- **Context:** GitHub macOS-14 runners have multiple Xcode versions installed.
- **Solution:** Don't pin to a specific version. Use:
  ```bash
  sudo xcode-select -s "$(ls -d /Applications/Xcode*.app | sort -V | tail -1)" 2>/dev/null || true
  ```
- **Current runner:** macOS-14 M1 with Xcode 16.2 (default), 15.4 available.

### Pattern: xcodegen Must Run Before xcodebuild
- **Context:** The .xcodeproj doesn't exist in git — it's generated by xcodegen.
- **CI step order:** Install xcodegen → Generate project → Build → Test → Screenshot

### Pattern: UI Test Screenshots Are Scattered
- **Context:** The `find` command that collects screenshots grabs ALL .png files from the simulator directory, including system assets (Apple Maps textures, etc.).
- **Solution:** Use more specific filtering or rely on XCUITest's `XCTAttachment` system.

---

## SUBAGENT MANAGEMENT PATTERNS

### Pattern: Subagents Produce 80% Correct Code
- **Context:** trident_build subagents produce structurally sound code but with API mismatches, duplicate definitions, and syntax errors in ~20% of output.
- **Impact:** Always audit subagent output before committing.
- **Common subagent errors:**
  1. Hallucinated API methods (e.g., `listRowCornerRadius`, `red8:green8:blue8:`)
  2. Duplicate code blocks when adding modifiers (e.g., TopBar.swift got `.buttonStyle` added twice)
  3. Method signature mismatches between files written by different subagents
  4. `[weak self]` in struct contexts
  5. Deprecated API usage (NavigationView, autocapitalization)

### Pattern: Audit Subagents Should Run After Build Subagents
- **Context:** Having one subagent write code and another audit it catches ~80% of issues.
- **Pattern:** Dispatch build subagent → then dispatch audit subagent → then directly verify CI.

---

## ESBUND / TYPESCRIPT PATTERNS

### Pattern: opencode Conditional Exports
- **Context:** opencode uses: `"imports": { "#db": { "bun": "src/storage/db.bun.ts", "node": "src/storage/db.node.ts", "default": "src/storage/db.bun.ts" } }`
- **Solution:** esbuild `conditions: ['browser', 'default']` skips `bun` and `node`, resolves to `default`.
- **Note:** The `default` entry still imports `bun:sqlite`. We alias `bun:sqlite` to our `forge-sqlite.ts` (SQL.js WASM).

### Pattern: Buffer Extending Uint8Array
- **Context:** TypeScript's `Uint8Array` has a `from()` static method with specific overloads. Our `Buffer` class extends `Uint8Array` and adds its own `from()` with different parameters. TypeScript's structural checking flags this as incompatible.
- **Solution:** `// @ts-ignore` on the `static from` line. Runtime behavior is correct — esbuild doesn't type-check.

### Pattern: setImmediate Not Available in Browsers
- **Context:** `setImmediate` is a Node.js API. Not available in WKWebView.
- **Solution:** Replace with `setTimeout(fn, 0)`.

---

## DOCKER-OSX PATTERNS

### Pattern: Docker-OSX Needs -display none on Headless Servers
- **Context:** QEMU uses GTK display by default. On headless Linux (no X11/Wayland), it fails with "gtk initialization failed."
- **Solution:** `-e EXTRA="-display none"` in docker run command.

### Pattern: Docker-OSX First Boot Takes 30-60 Minutes
- **Context:** First boot installs macOS from BaseSystem recovery image to the virtual disk.
- **Impact:** SSH at port 50922 won't work until installation completes and macOS reboots.
- **Solution:** Start the VM early, check SSH periodically with `ssh -p 50922 user@localhost "echo OK"`.

---

## KEY LEARNINGS (Ranked by Importance)

1. **CI is the fastest feedback loop** — push early, push often. Each cycle is 1-8 minutes.
2. **Color qualification is non-negotiable** — always use `SwiftUI.Color`, never bare `Color`.
3. **Subagents produce 80% correct code** — always audit for API mismatches and duplicates.
4. **SwiftTerm API differs from what you might expect** — TerminalView IS UIScrollView, Color takes UInt16, no red8 initializer.
5. **Docker-OSX first boot takes forever** — start it immediately, check periodically.
6. **xcodegen generates the project at CI time** — the .xcodeproj is NOT in git.
7. **GitHub default branch may be `master` not `main`** — check and match workflow.
8. **swift-libgit2 needs Swift 6.1** — use direct C bindings instead.
9. **Structs can't use [weak self]** — remove capture lists in SwiftUI Views.
10. **WKWebView retain cycle via WKUserContentController** — always use weak proxy.
11. **VNC keyboard DOES NOT WORK in macOS/OpenCore** — QEMU USB keyboard emulation bug. Use `sendkey` via QEMU monitor (port 4444 inside container).
12. **vncsnapshot is the ONLY working screenshot tool** — vncdotool (Twisted), scrot (XWayland rootless), grim (Wayland headless) all fail. `vncsnapshot -quiet localhost:0 out.jpg`.
13. **Docker commit does NOT capture qcow2 disk changes** — macOS installation progress lost on container recreation. Use volume mounts or save qcow2 separately.
14. **QEMU monitor syntax matters** — QEMU 10.1.2 uses `server,nowait` (NOT `server,off`). Telnet monitor: `-monitor telnet:127.0.0.1:4444,server,nowait`.
15. **FORGE symlink bug** — NEVER create a symlink named `FORGE` inside the project directory. It causes esbuild to resolve paths through the symlink to the wrong directory.
16. **macOS Sonoma kernel stuck in QEMU** — Darwin 23.6.0 starts but freezes. Try Ventura (older, more compatible) or `-cpu host` (CPU passthrough).
17. **Mouse clicks work via RFB but keyboard doesn't** — RFB pointer events reach OpenCore/macOS. RFB key events do NOT. Use QEMU monitor sendkey for all keyboard.
18. ** Weston + XWayland + scrot = black screenshot** — XWayland rootless mode prevents X11 capture. Use vncsnapshot instead.
