# DECISION CHAIN — FORGE iOS Build

**Initialized:** 2026-07-25
**Last Updated:** 2026-07-27 Wave 7
**Total Decisions:** 28

---

## Architecture Decisions

### D1: WKWebView (hidden) over Standalone JSContext
**Date:** 2026-07-25
**Decision:** Use a hidden WKWebView (0x0 frame, offscreen) as the JavaScript execution engine.
**Rationale:** Standalone JSContext (JavaScriptCore.framework used directly in Swift) is fundamentally inadequate:
- NO JIT compilation (only LLInt interpreter) → 5-15x slower than V8/Bun
- NO WebAssembly → web-tree-sitter (opencode's code parser) cannot load
- NO Web APIs → fetch(), crypto.subtle, TextEncoder, setTimeout, queueMicrotask all missing. Would need to build all of these from scratch (weeks of work).
- WKWebView's JSC has special Apple entitlements for JIT, WASM, and full Web API support
- WKWebView is NEVER visible to the user — SwiftTerm renders the terminal natively
**Alternatives Considered:**
- Standalone JSContext → rejected (see above)
- Bun as embedded framework → rejected (doesn't compile for iOS, confirmed via websearch)
- iSH Linux emulation → rejected (performance overhead, integration complexity)
**Impact:** This is THE foundational architecture decision. Everything else follows from it.

### D2: SwiftTerm for Terminal Rendering
**Date:** 2026-07-25
**Decision:** Use SwiftTerm (github.com/migueldeicaza/SwiftTerm) v1.15.0 via SPM.
**Rationale:**
- First-class iOS support (UIScrollView subclass with Metal GPU rendering)
- Thread-safe `feed(text:)` method — can be called from any thread
- `TerminalViewDelegate.send(source:data:)` captures all keyboard input
- Full VT100/xterm ANSI support (256-color, TrueColor, cursor, alt screen)
- Keyboard accessory bar (ESC, CTRL, TAB, arrows, F-keys)
- Used in commercial iOS SSH clients (Secure Shellfish, La Terminal)
- Custom fonts (JetBrains Mono) work via UIFont
- Configurable scrollback (default 500, set to 5000)
**Alternatives Considered:**
- xterm.js in WKWebView → rejected (user explicitly rejected "web terminal" approach)
- Custom terminal renderer → rejected (massive effort, SwiftTerm already does everything)

### D3: esbuild for JavaScript Bundling
**Date:** 2026-07-25
**Decision:** Use esbuild to bundle opencode + Trident into a single forge-bundle.js file.
**Configuration:**
- `platform: 'browser'` → uses browser condition exports, prefers browser-specific modules
- `format: 'iife'` → single self-contained file, all dynamic imports inlined
- `target: ['safari16']` → targets iOS 16+ WKWebView capabilities
- `conditions: ['browser', 'default']` → skips 'bun' and 'node' conditions in opencode's import maps
- `alias` → maps all Node.js built-in modules to custom forge shims
- `inject` → provides process and Buffer global variables
- `define` → compile-time constants for process.env, global, __dirname
- `loader: { '.wasm': 'binary', '.txt': 'text', '.md': 'text' }` → handles non-JS imports
- `minify: true, treeShaking: true` → smallest possible output
**Rationale:** Fastest bundler, designed for browser targets, handles conditional exports natively.

### D4: Strip Vanilla opencode Agents via Configuration
**Date:** 2026-07-25
**Decision:** Disable opencode's built-in `build`, `plan`, and `general` agents via JSON config.
**Config:**
```json
{
    "default_agent": "trident",
    "agent": {
        "build": { "disable": true },
        "plan": { "disable": true },
        "general": { "disable": true }
    }
}
```
**Rationale:** opencode's agent system is config-driven (agent.ts). Setting `disable: true` removes the agent from the registry. No source code changes needed. Hidden infrastructure agents (compaction, title, summary) remain active.

### D5: Keep Trident Subagents as Effect Fibers
**Date:** 2026-07-25
**Decision:** trident_build, trident_explore, and trident_planner run as Effect fibers within the same WKWebView JS context.
**Rationale:** In opencode, subagents are NOT child processes — they are lightweight async tasks (Effect fibers). This means they work perfectly on iOS without any process spawning. No fork, no exec, no PTY. The subagents share the same LLM provider, file system, and JS context as the primary agent.

### D6: Eliminate TUI Worker
**Date:** 2026-07-25
**Decision:** Run opencode's TUI in the main JavaScript context, not a Web Worker.
**Rationale:** opencode normally runs the TUI in a Web Worker, communicating via postMessage RPC. On iOS, we eliminate this — everything runs in the main JS context. The RPC layer becomes direct function calls.
- Valid because: OpenTUI rendering is pure CPU work (doesn't need a separate thread)
- Valid because: Agent logic (Effect fibers, LLM calls) is async — yields event loop naturally
- Valid because: SwiftTerm rendering happens on Swift's main thread — doesn't compete with JS

### D7: Bypass HTTP Server
**Date:** 2026-07-25
**Decision:** Don't start an HTTP server. Call opencode's internal request handler directly.
**Rationale:** opencode's server mode uses `node:http.createServer()`. We don't need this for Mode 1 — no remote client connects to the iPhone. Instead, we call `app.fetch(request)` directly from JavaScript, constructing synthetic Request objects.

### D8: Pre-Bundle Trident Plugin
**Date:** 2026-07-25
**Decision:** Bundle the Trident plugin at build time via esbuild, not at runtime via dynamic import().
**Rationale:** esbuild's `format: 'iife'` inlines all imports. Dynamic `import()` is not available. A plugin registry replaces the dynamic loader.

---

## Build/Infrastructure Decisions

### D9: SwiftTerm v1.15.0
**Date:** 2026-07-25
**Decision:** Use SwiftTag v1.15.0 as the SPM dependency version.
**Rationale:** Initial project.yml specified `from: "2.0.0"` which doesn't exist. GitHub tags show latest is v1.15.0. Earlier versions (v1.8.0 through v1.14.0) also exist but we want latest features.

### D10: Remove swift-libgit2, Stub ForgeGitManager
**Date:** 2026-07-25
**Decision:** Remove the swift-libgit2 SPM dependency. Stub ForgeGitManager with no-op implementations.
**Rationale:** swift-libgit2's Package.swift specifies `swift-tools-version: 6.1`. Our Xcode (15/16) uses Swift 5.x. The package won't resolve.
- Phase 2 plan: Build libgit2 as a static C library using CMake + ios-cmake toolchain. Create a C bridging header. This gives full libgit2 API access without needing swift-libgit2's Swift wrapper.

### D11: GitHub Actions macOS Runner for CI
**Date:** 2026-07-25
**Decision:** Use GitHub Actions `macos-14` runner for all iOS builds and tests.
**Rationale:**
- FREE for public repositories (unlimited minutes)
- Real Apple Silicon M1 hardware with full Xcode + iOS SDK
- iOS Simulator runs natively (not emulated)
- `xcrun simctl` provides screenshot capture and UI automation
- XCUITest framework for automated UI testing
- Cost: $0.062/min for private repos (2,000 free minutes/month)
**Alternative considered:** MacStadium ($50+/month), AWS Mac ($540+/month), Corellium (enterprise sales)

### D12: Docker-OSX for Local macOS VM
**Date:** 2026-07-25
**Decision:** Run Docker-OSX (sickcodes/docker-osx) for local macOS testing.
**Rationale:** System has KVM support (/dev/kvm), Docker 29.3.0, 30GB RAM, 32 CPUs. Docker-OSX provides full macOS virtualization via QEMU + KVM acceleration.
- Image: sickcodes/docker-osx:latest (4.28GB)
- Mode: Headless (`-display none`), SSH at localhost:50922
- SSH credentials: user=user, password=alpine
- First boot: macOS installs from BaseSystem recovery image (30-60 minutes)

### D13: xcodegen for Project Generation
**Date:** 2026-07-25
**Decision:** Use xcodegen to generate the .xcodeproj from project.yml.
**Rationale:**
- YAML-based, human-readable, diff-friendly
- No binary .xcodeproj file in git (generated at build time)
- Reproducible across machines
- CI step: `brew install xcodegen && xcodegen generate`

### D14: GitHub Actions for UI Testing
**Date:** 2026-07-25
**Decision:** Use XCUITest + simctl for automated UI testing in CI.
**Rationale:** No physical Mac needed. XCUITest provides element querying, tap simulation, screenshot capture. simctl provides simulator boot, app install, screenshot output.

---

## Design Decisions

### D15: Dark Theme Only
**Date:** 2026-07-25
**Decision:** No light mode. The dark theme (0A0A0F background, 00F0FF accent) is the only theme.
**Rationale:** Developer tool aesthetic. Military-grade command software feel. Reduces eye strain for terminal-heavy usage.

### D16: Monospaced Typography
**Date:** 2026-07-25
**Decision:** Use JetBrains Mono throughout the entire app.
**Rationale:** Code and terminal content require monospaced fonts. JetBrains Mono is designed for developers, has excellent readability, and supports the full character set needed for terminal rendering.

### D17: Spring Physics Animations
**Date:** 2026-07-25
**Decision:** All animations use spring physics with response 0.3-0.4s and damping 0.8.
**Rationale:** Feels natural and responsive. Matches Apple's own animation guidelines for iOS 17.

### D18: Haptic Feedback on All Interactions
**Date:** 2026-07-25
**Decision:** UIImpactFeedbackGenerator (medium) fires on every button press, session switch, and mode transition.
**Rationale:** Tactile confirmation of user actions. Critical for terminal apps where visual feedback may be minimal.

### D19: Bonjour/mDNS for Server Discovery
**Date:** 2026-07-25
**Decision:** Use NWBrowser with `_opencode._tcp` service type for automatic server discovery.
**Rationale:** opencode server already advertises via mDNS (bonjour-service package). NWBrowser on iOS discovers these services automatically on the local network. No manual hostname entry needed (though supported as fallback).

### D20: Project Workspace Under Shared Context
**Date:** 2026-07-25
**Decision:** All project files and context docs live in the Shared Workspace Context directory.
**Path:** `/home/leviathan/OPENCODE_WORKSPACE/Shared Workspace Context/Trident_Agent/Active_Projects/FORGE/`
**Rationale:** Centralized project workspace for compaction survival. Git working directory remains at `/home/leviathan/OPENCODE_WORKSPACE/FORGE/` for push operations. Source files are copied to both locations.

---

## Wave 5-7 Decisions

### D21: VNC Display (Not GTK) for macOS VM
**Date:** 2026-07-27
**Decision:** Use `-vnc 0.0.0.0:0` for QEMU display instead of `-display gtk`.
**Rationale:** GTK display fails with "gtk initialization failed" because Weston/XWayland auth doesn't propagate to QEMU's GTK backend in Docker exec. VNC works perfectly — QEMU's VGA device renders to VNC framebuffer, accessible via vncsnapshot and RFB mouse events.

### D22: QEMU Monitor sendkey (Not VNC Keyboard)
**Date:** 2026-07-27
**Decision:** Use QEMU monitor `sendkey` command for all keyboard input.
**Rationale:** VNC keyboard events (RFB key events) DON'T WORK in macOS/OpenCore due to QEMU USB keyboard emulation bug. sendkey bypasses VNC entirely, sends events through QEMU's hardware emulation layer. Verified working (358K pixels changed after sendkey ret).
**Implementation:** `docker exec forge-vm python3 → socket connect 127.0.0.1:4444 → send("sendkey ret\n")`

### D23: vncsnapshot (Not vncdotool/scrot/grim) for Screenshots
**Date:** 2026-07-27
**Decision:** Use `vncsnapshot -quiet localhost:0 /tmp/snap.jpg` for all screenshot capture.
**Rationale:** vncdotool (Twisted-based) fails with connection refused. scrot captures black (XWayland rootless). grim fails (Wayland headless backend). vncsnapshot (C-based TightVNC) works perfectly — 1920x1080 JPEG, ~1MB.

### D24: Docker-OSX as macOS VM Base (Not node:20-bullseye)
**Date:** 2026-07-27
**Decision:** Use `sickcodes/docker-osx:latest` (Arch Linux) instead of `node:20-bullseye` for macOS VM.
**Rationale:** Docker-OSX has QEMU compiled with macOS-compatible options, OpenCore bootloader, OVMF firmware, and fetch-macOS script. Building from node:20-bullseye required installing all of this manually.

### D25: macOS BaseSystem via fetch-macOS-v2.py
**Date:** 2026-07-27
**Decision:** Download macOS from Apple CDN using Docker-OSX's fetch script.
**Rationale:** Legitimate download from Apple's servers. Option 7 = Sonoma, Option 6 = Ventura, Option 5 = Monterey. DMG converted to qcow2 via dmg2img + qemu-img convert.

### D26: Telnet Monitor (Not Unix Socket) for QEMU
**Date:** 2026-07-27
**Decision:** Use `-monitor telnet:127.0.0.1:4444,server,nowait` for QEMU monitor.
**Rationale:** Unix socket syntax (`server,off`) fails on QEMU 10.1.2 with "Invalid parameter 'off'". Telnet with `server,nowait` works. Binds to 127.0.0.1 (container-internal only, accessed via docker exec).

### D27: macOS Sonoma STUCK — Try Ventura Next
**Date:** 2026-07-27
**Decision:** macOS Sonoma kernel gets stuck in verbose boot. Next session should try Ventura.
**Rationale:** Sonoma (14) is the latest macOS and may require CPU features QEMU's Penryn emulation doesn't provide. Ventura (13) is older and has better QEMU compatibility track record. Also try `-cpu host` for CPU passthrough.

### D28: Checkpoint Before macOS VM Work
**Date:** 2026-07-27
**Decision:** Save full codebase checkpoint before starting macOS VM debugging.
**Rationale:** macOS VM work is unpredictable and may require container recreation (losing state). Checkpoint at `Checkpoints/Session1_85Percent/` preserves all source code, docs, and build report (167 files, 20MB).
