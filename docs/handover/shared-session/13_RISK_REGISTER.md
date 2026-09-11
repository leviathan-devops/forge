# RISK REGISTER — FORGE iOS

**Last Updated:** 2026-07-27 Wave 7
**Purpose:** Track every known risk to FORGE's production readiness, with probability, impact, status, and mitigation/fallback strategies.

---

## 0. RISK ASSESSMENT METHODOLOGY

### Probability Scale
| Level | Meaning | Criteria |
|-------|---------|----------|
| High | >70% chance of occurring | Known technical blocker, untested critical path with uncertain outcome |
| Medium | 30-70% chance | Plausible scenario, some evidence it could happen, not yet verified |
| Low | <30% chance | Unlikely based on current knowledge, standard approach should work |

### Impact Scale
| Level | Meaning | Criteria |
|-------|---------|----------|
| Fatal | Project cannot ship without resolution | App Store rejection, fundamental architecture failure |
| High | Major feature broken, significant workaround needed | Terminal doesn't render, agent can't execute, data loss |
| Medium | Degraded experience, workaround available | Performance issues, feature limitations, fallback exists |
| Low | Minor inconvenience, cosmetic | Slow loading, missing non-critical feature |

### Status Categories
| Status | Meaning |
|--------|---------|
| Not yet tested | Risk identified but not yet verified or debunked |
| Monitored | Watching for signs of the risk materializing |
| Mitigated | Mitigation strategy in place and active |
| Expected | Risk is expected behavior (by design), fallback documented |

### Review Schedule
- **After every wave:** Review all active risks, update status
- **Before TestFlight submission:** Full risk assessment pass
- **After App Store submission:** Update with any rejection feedback
- **Ongoing:** Any new risk discovered during development is added immediately

---

## 1. ACTIVE RISKS (Unresolved)

| # | Risk | Probability | Impact | Status | Mitigation Strategy |
|---|------|-------------|--------|--------|---------------------|
| A1 | SQL.js WASM fails to load in WKWebView | Low | High | Not yet tested | SQL.js requires loading a .wasm binary. WKWebView supports WASM, but the loading method (fetch + WebAssembly.instantiate) needs verification. **Fallback:** Native SQLite via Swift bridge — implement SQLite3 C API wrapper in Swift, expose read/write/query methods via ForgeBridge. |
| A2 | OpenTUI output capture incompatible with WKWebView | Low | High | Not yet tested | OpenTUI writes terminal output via a write() method. We intercept this via monkey-patch in forge-terminal-surface.ts. If the patch target or call convention differs from what we expect, output capture fails silently. **Fallback:** If monkey-patch fails, read directly from OpenTUI's internal terminal buffer state after each render cycle. |
| A3 | WKWebView memory pressure (opencode + Trident + tree-sitter + Pyodide) | Medium | Medium | Monitored | Multiple large JS/WASM modules in a single WKWebView may exceed iOS memory limits (jetsam kill at ~1.5GB for foreground apps). **Mitigation:** Semantic filter for terminal output (don't buffer everything), lazy-load Pyodide (only when Python is requested), explicit GC hints via `window.gc()` if available. **Fallback:** Run subagents in separate WKWebView instances. |
| A4 | App Store rejection | Medium | Fatal | Not yet submitted | App Store may reject for: running arbitrary code, JIT/WASM usage, local network access, or "developer tool" categorization concerns. **Mitigation:** Position as code editor / development environment (not a terminal emulator). WASM is sandboxed by WebKit (safe). Local networking is for server discovery (user-initiated). Prepare App Store metadata emphasizing educational/productivity use. |
| A5 | forge-bundle.js too large for WKWebView | Low | Medium | Not yet created | esbuild output with opencode + Trident + OpenTUI + tree-sitter WASM may be 3-8MB. WKWebView can handle this, but initial parse time may be slow. **Mitigation:** Aggressive tree-shaking, minification, code splitting (load Pyodide lazily). Target <5MB for initial load. **Fallback:** Split into multiple bundles loaded on demand. |
| A6 | Docker-OSX SSH never becomes available | Medium | Low | Monitoring | Docker-OSX first boot installs macOS (30-60 min). If installation fails or SSH doesn't come up, local macOS testing is blocked. **Mitigation:** GitHub Actions CI is the primary test path — Docker-OSX is supplementary. Check `docker logs forge-macos` for installation progress. **Fallback:** Use GitHub Actions exclusively for all testing. |
| A7 | LLM API latency on mobile network (3G/4G) | Low | Low | N/A | LLM API calls go through fetch() in WKWebView. On slow mobile networks, response times may be 5-30s. **Mitigation:** Same as desktop — the API call is an API call regardless of platform. Show loading indicators. Stream responses if API supports it. |
| A8 | Effect.ts runtime behaves differently in WKWebView vs Node | Low | High | Not yet tested | Effect runtime relies on microtask scheduling (queueMicrotask, Promise). WKWebView's JSC should handle these natively. But edge cases in fiber scheduling, resource cleanup, or async teardown may differ. **Mitigation:** Test all Effect operations in WKWebView. Effect is pure TypeScript with no Node.js dependencies — should work. **Fallback:** Polyfill any missing scheduling primitives. |
| A9 | web-tree-sitter WASM module fails to initialize | Low | High | Not yet tested | opencode uses web-tree-sitter for code parsing. It loads a .wasm binary and a language grammar. If the loading path or streaming compilation fails in WKWebView, syntax highlighting and code analysis break. **Mitigation:** Verify WASM instantiation works. Ensure the grammar files are bundled (not fetched at runtime). **Fallback:** Disable tree-sitter features — opencode still works without syntax parsing. |
| A10 | Vercel AI SDK streaming incompatible with WKWebView fetch | Low | Medium | Not yet tested | The AI SDK uses streaming responses (Server-Sent Events or chunked transfer). WKWebView's fetch() supports streaming via ReadableStream, but implementation details may differ from Node.js/Bun. **Mitigation:** Test streaming responses specifically. If streaming fails, fall back to non-streaming mode (collect full response, then render). |
| A11 | Bonjour/mDNS discovery fails on cellular (no LAN) | Medium | Low | Expected behavior | NWBrowser requires local network access. On cellular data, no mDNS services are discoverable. **Mitigation:** Manual server entry (ServerPickerSheet) is the fallback. Show clear messaging when on cellular. |
| A12 | iOS keyboard accessory conflicts with SwiftTerm | Low | Low | Not yet tested | SwiftTerm provides its own keyboard accessory bar (ESC, CTRL, TAB, arrows). iOS may also show its own suggestions bar. **Mitigation:** Configure SwiftTerm's input accessory view. Disable autocorrect/autocapitalization on the terminal input. |

---

## 2. RESOLVED RISKS

| # | Risk | How Resolved | Resolution Date |
|---|------|-------------|-----------------|
| R1 | Bun won't compile for iOS ARM64 | Confirmed via websearch — Bun's build system doesn't target iOS. Pivoted to WKWebView (hidden, 0x0 frame) as JavaScript execution engine. | 2026-07-25 |
| R2 | Standalone JSContext lacks JIT, WASM, Web APIs | Discovered in architecture research. JSContext (JavaScriptCore.framework) has only LLInt interpreter (5-15x slower), no WebAssembly, no fetch/crypto/setTimeout. Pivoted to WKWebView which has full JIT (Baseline→DFG→FTL), WASM, and all Web APIs. | 2026-07-25 |
| R3 | SwiftTerm version 2.0.0 doesn't exist | Initial project.yml specified `from: "2.0.0"`. Verified via `gh api repos/migueldeicaza/SwiftTerm/tags` — latest is v1.15.0. Changed to `from: "1.15.0"`. | 2026-07-25 |
| R4 | Color type ambiguity (SwiftUI.Color vs SwiftTerm.Color) | SwiftTerm defines its own `Color` struct. In Swift single-target model, bare `Color` is ambiguous project-wide. Resolved by qualifying ALL Color references as `SwiftUI.Color` across 13 files (4 CI iterations to fully resolve). | 2026-07-25 |
| R5 | swift-libgit2 requires Swift 6.1 (Xcode has 5.x) | swift-libgit2 Package.swift specifies `swift-tools-version: 6.1`. Removed dependency entirely. ForgeGitManager returns Phase 2 messages. Phase 2 plan: build libgit2 as C static library via CMake + ios-cmake toolchain, add C bridging header. | 2026-07-25 |
| R6 | Docker-OSX GTK display failure on headless server | QEMU uses GTK display by default. Headless Linux server has no X11/Wayland. Fixed by adding `-e EXTRA="-display none"` environment variable. QEMU runs without display, SSH at port 50922 works once macOS boots. | 2026-07-25 |
| R7 | ForgeGitManager API signature mismatch | ForgeBridge called gitOperation with closures (resolve/reject), ForgeGitManager expected callbackId/webView. Rewrote ForgeGitManager to match closure-based API: `func gitOperation(_ args:, operation:, projectRoot:, resolve: @escaping (Any) -> Void, reject: @escaping (String) -> Void)`. | 2026-07-25 |
| R8 | TerminalView.scrollView doesn't exist | SwiftTerm's TerminalView inherits from UIScrollView — it IS the scroll view. Changed all `.scrollView.bounces` to `.bounces`, `.scrollView.alwaysBounceHorizontal` to `.alwaysBounceHorizontal`, etc. | 2026-07-25 |
| R9 | WKWebView retain cycle via WKUserContentController | `WKUserContentController.add(self, name:)` retains its handler, creating cycle: engine→webView→config→controller→engine. Created `WeakScriptMessageHandler` proxy class that wraps engine weakly. Changed webView to `WKWebView?` (optional). Added `teardown()` that nils webView. | 2026-07-25 |
| R10 | CMMotionManager leak in ParallaxGridBackground | `motionManager` was `private let` — SwiftUI recreates struct on body eval, creating new instance. `onDisappear` called stop on wrong instance. Changed to `@State private var` so SwiftUI preserves instance. | 2026-07-25 |
| R11 | MissionControlScreen array OOB crash | `currentSession` accessed `sessions[sessions.count - 1]`. Empty array = `sessions[-1]` = crash. Changed to return `RemoteSession?` (optional) with empty-array guard. | 2026-07-25 |
| R12 | ForgeCommandRunner negative tail offset crash | `tail -n-5` parsed n=-5, offset=lines.count+5, then `Array(lines[offset...])` crashed. Added `n = max(0, n)` clamp and `safeOffset = min(offset, lines.count)` bounds check. | 2026-07-25 |
| R13 | Engine leak on retry in BuildOnDeviceScreen | Retry created new engine without stopping old one. Each retry leaked ~50-100MB JS heap. Added `if engine != nil { stopEngine() }` guard at start of `startEngine()`. | 2026-07-25 |
| R14 | BuildOnDeviceScreen nil bridge (silent failure) | `startEngine()` called `applyProject()` before creating bridge. `bridge?.setProjectRoot()` hit nil. Restructured to create bridge/engine first, then apply project. | 2026-07-25 |

---

## 3. ACCEPTANCE CRITERIA CHECKLIST

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | App builds GREEN on CI (macos-14 runner) | ✅ | CI run #13 (30172508352) SUCCESS, 6m56s. 6 total successful builds. |
| 2 | App renders correctly in iOS Simulator (vision-verified) | ✅ | Screenshot from CI run #8+ confirmed: dark theme, cyan accent, FORGE title, two mode cards, grid background, navigation bar. |
| 3 | Terminal shows real content when entering Mode 1 (forge-bundle.js loaded) | ❌ | forge-bundle.js not yet created. Need to vendor opencode + Trident source, run esbuild, deploy to app. |
| 4 | Settings persist correctly (Keychain round-trip verified) | ❌ | No integration test written. KeychainHelper code exists but round-trip not verified via XCUITest. |
| 5 | Mission Control connects to remote opencode server | ❌ | No remote opencode server available for testing. WebSocket code exists but untested end-to-end. |
| 6 | Docker-OSX local testing verified | ❌ | macOS still installing (first boot 30-60 min). SSH at localhost:50922 not yet available. |
| 7 | TestFlight build submitted | ❌ | Apple Developer account not configured. Need $99/year developer membership, provisioning profiles, App Store Connect setup. |
| 8 | App Store metadata complete | ❌ | App Store Connect listing, screenshots, description, privacy policy, support URL — none started. |

**Score: 2/8 complete (25%)**

---

## 4. FALLBACK STRATEGIES (If Primary Architecture Fails)

### F1: If WKWebView JavaScript Execution Fails
**Scenario:** WKWebView can't run opencode effectively (memory, performance, API incompatibility).
**Fallback:** Hybrid architecture — run opencode server mode on a remote Mac/cloud, connect from iPhone via Mode 2 (Mission Control) exclusively. Mode 1 becomes a thin client that SSH-tunnels to a remote opencode instance.
**Cost:** Requires always-on server. Reduces "build on device" promise to "build via remote device."

### F2: If SwiftTerm Terminal Rendering Fails
**Scenario:** SwiftTerm has unfixable rendering bugs, performance issues, or API changes.
**Fallback:** Switch to xterm.js rendered inside a VISIBLE WKWebView (not hidden). User sees a web terminal instead of native terminal. Less performant but functional. Previously rejected by user, but it's the last-resort option.
**Cost:** Loses native Metal rendering, keyboard accessory bar, and the "real terminal" feel.

### F3: If libgit2 C Integration Fails (Phase 2)
**Scenario:** Can't build libgit2 for iOS via CMake, or bridging header doesn't work.
**Fallback:** Use Swift's Process API to shell out to a bundled git binary (if one can be cross-compiled for iOS). Or: implement minimal git operations via HTTP (clone/push/pull to GitHub API directly, no local git repo).
**Cost:** No local git history, no branching/merging without server round-trip.

### F4: If Pyodide (Python) Integration Fails
**Scenario:** Pyodide WASM too large, or Python execution breaks in WKWebView.
**Fallback:** Remote Python execution — send code to a cloud Python service (repl.it API, Google Colab, custom endpoint). Or: defer Python support to Phase 3.
**Cost:** No on-device Python. Network required for Python execution.

### F5: If App Store Rejects FORGE
**Scenario:** Apple rejects for code execution, JIT/WASM, or "not appropriate" reasons.
**Fallback:** Distribute via TestFlight (beta, up to 10,000 testers) and/or ad-hoc distribution (direct install via Xcode, up to 100 devices per developer account). Open-source the app for sideloading via AltStore/SideStore.
**Cost:** No App Store discoverability. Manual distribution required.

### F6: If Bonjour/mDNS Discovery Fails
**Scenario:** NWBrowser doesn't find opencode servers, or mDNS is blocked by network.
**Fallback:** Manual server entry (already implemented as ServerPickerSheet). QR code scanning for server connection details (camera + QR generator on server side).
**Cost:** Requires manual hostname/port entry. Less seamless than auto-discovery.

### F7: If CI macOS Runner Becomes Unavailable
**Scenario:** GitHub changes runner availability, removes free tier, or macos-14 runner deprecated.
**Fallback:** Self-hosted runner on Docker-OSX or a dedicated Mac mini. MacStadium ($50+/month) or AWS EC2 Mac ($540+/month for dedicated) as paid alternatives.
**Cost:** Monthly infrastructure cost. More maintenance overhead.

---

## 5. RISK HEAT MAP

Plotting active risks by probability (rows) vs impact (columns):

```
                    Impact
             Low      Medium     High       Fatal
          ┌─────────┬──────────┬──────────┬──────────┐
  High    │         │          │          │          │
  (70%+)  │  —      │   —      │   —      │   —      │
          ├─────────┼──────────┼──────────┼──────────┤
  Medium  │ A6,A11  │   A3     │          │   A4     │
  (30-70%)│         │          │          │          │
          ├─────────┼──────────┼──────────┼──────────┤
  Low     │ A7,A12  │   A5,A10 │ A1,A2    │          │
  (<30%)  │         │          │ A8,A9    │          │
          └─────────┴──────────┴──────────┴──────────┘
```

**Highest priority risks** (Medium probability + Fatal/High impact):
- **A4** (App Store rejection) — Medium probability, Fatal impact. Must prepare metadata and positioning before submission.
- **A3** (WKWebView memory pressure) — Medium probability, Medium impact. Monitor jetsam kills during testing.

**High-impact low-probability risks** (watch closely):
- **A1** (SQL.js WASM), **A2** (OpenTUI capture), **A8** (Effect runtime), **A9** (tree-sitter) — all Low probability but High impact. If any fails, Mode 1 is broken. Test ALL of these before declaring forge-bundle.js functional.

---

## 6. DEPENDENCY RISK CHAIN

Risks that cascade — failure of one increases probability of others:

```
A5 (bundle too large) ──increases──▶ A3 (memory pressure)
                                          │
A9 (tree-sitter fails) ──────────────────┤
                                          ▼
A2 (OpenTUI capture) ─────────────▶ Mode 1 completely broken
                                          │
A1 (SQL.js fails) ────────────────────────┤
                                          ▼
A8 (Effect runtime) ──────────────▶ Agent execution broken
```

**Critical insight:** Risks A1, A2, A8, and A9 are INDEPENDENT but CONCURRENT — they all need to succeed simultaneously for Mode 1 to work. The probability of ALL succeeding is the PRODUCT of individual probabilities. Even at 90% each, combined probability is only 0.9^4 = 65.6%. This means there's a ~34% chance at least ONE of these four risks materializes.

**Mitigation:** Test each risk INDEPENDENTLY first (isolation testing), then test them TOGETHER (integration testing). Fix individual failures before attempting full integration.

---

## 7. RISK BUDGET SUMMARY

| Category | Active Count | Resolved Count | Highest Priority |
|----------|-------------|----------------|------------------|
| Architecture/JS Runtime | 5 (A1,A2,A5,A8,A9) | 2 (R1,R2) | A2 — OpenTUI capture |
| CI/Infrastructure | 2 (A6,A7) | 1 (R6) | A6 — Docker-OSX |
| App Store/Distribution | 1 (A4) | 0 | A4 — App Store rejection |
| Performance/Memory | 2 (A3,A10) | 0 | A3 — Memory pressure |
| Networking | 2 (A11,A12) | 0 | A11 — Cellular limitation |
| Compilation/API | 0 | 12 (R3-R14) | ALL RESOLVED |
| **Total** | **12** | **14** | |

**Net assessment:** All compilation and API risks are resolved. Remaining risks are runtime/behavioral (untestable until forge-bundle.js is created) and distribution (untestable until submission). The critical path is: create forge-bundle.js → test runtime risks A1/A2/A8/A9/A10 → fix any failures → submit to App Store → address A4 if rejected.

---

## 8. WAVE 7 RISK UPDATES (2026-07-27)

### NEW Active Risk

| ID | Risk | Prob | Impact | Status | Mitigation |
|----|------|------|--------|--------|------------|
| A13 | macOS Sonoma kernel stuck in QEMU verbose boot | HIGH | HIGH | Active — top priority | Try Ventura, -cpu host, more RAM |
| A14 | Docker commit loses qcow2 disk state | MEDIUM | MEDIUM | Noted | Use volume mounts for persistent disk |

### Resolved Risks (Wave 7)

| ID | Risk | How Resolved |
|----|------|-------------|
| R15 | VNC keyboard doesn't work in macOS | Resolved via QEMU monitor sendkey |
| R16 | Can't capture screenshots from macOS VM | Resolved via vncsnapshot |
| R17 | GTK display fails in Docker | Resolved by using VNC display instead |
| R18 | vncdotool connection refused | Resolved by using vncsnapshot instead |

### Updated Risk Budget

| Category | Active Count | Resolved Count | Highest Priority |
|----------|-------------|----------------|------------------|
| Architecture/JS Runtime | 5 | 2 | A2 — OpenTUI capture |
| CI/Infrastructure | 3 (A6,A7,A13) | 5 (R6,R15-R18) | A13 — macOS kernel stuck |
| App Store/Distribution | 1 | 0 | A4 — App Store rejection |
| Performance/Memory | 2 | 0 | A3 — Memory pressure |
| Networking | 2 | 0 | A11 — Cellular limitation |
| Docker Infrastructure | 1 (A14) | 0 | A14 — qcow2 state loss |
| Compilation/API | 0 | 12 | ALL RESOLVED |
| **Total** | **14** | **18** | |

### Acceptance Criteria Status

1. ✅ App builds on CI — 9+ successes
2. ✅ App renders in Simulator — launch menu confirmed
3. ❌ macOS VM fully working — kernel stuck (A13)
4. ❌ FORGE tested in macOS VM iOS Simulator
5. ❌ Full opencode+Trident bundle (Phase 2)
6. ❌ TestFlight submission — needs Apple Dev account
7. ❌ App Store review submission
8. ❌ iPad layout testing

**Progress: 2/8 criteria met. A13 (macOS kernel) is the critical blocker.**
