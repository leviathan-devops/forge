# BUILD SPEC ARTIFACT — FORGE Ship Wave (SC-11c close → SC-12 → TestFlight)
# BUILD SPEC ARTIFACT — FORGE Ship Wave (SC-11c close → SC-12 → TestFlight)
- Target: `/home/leviathan/OPENCODE_WORKSPACE/FORGE`
- Generated: 2026-09-10 · Trident v4.4.2 · Status: PLANNING
- Artifact Type: BUILD_SPEC (Layer 1 Prompt) · Discovery: ENABLED
- PREFLIGHT: script-test ✓ deep-container-testing ✓ ascii-diagrams ✓
- Parent evidence: `reports/Engineering_Report_v2.md` (base-tree v2, 2026-09-10)

## Discovered Intelligence
- Languages: Swift 5.9 (71 files, 19677 lines) · JS ES2022 IIFE bundle (2717L)
  · TS shims/sources 23 files under `forge/` · Python battery 13 files, 87 tests
- Entry Points: `iOS/FORGE/App/FORGEApp.swift:7` (@main) →
  `Bridge/ForgeEngine.swift:190 loadBundle()` (hidden WKWebView, `native`
  handler) → `forge-bundle.js:26 bootstrap()` → `window.__forge`
- Patterns: slash-dispatch table (`forge-bundle.js:1854-1912`), Keychain via
  `ForgeBridge.getSecret/setSecret`, `injectAPICredentials` merge, XCUITest
  proof-driver + watcher + ffprobe mux gates
- Failures: t76 second-call 401 (rowed FAIL) · suite 86/87 (B4 pollution
  residual) · bundle phase1-stub, 0 SSE · checkpoint untracked plain tree
- Decisions: 6GB start-tahoe rig · Go muse-only, Zen paused · VNC-dead,
  XCUITest-only · key BURNED 2026-09-10, rotation-gated t78
- Warheads: builder-under-audit (rows failures) · append-only takes · SC-12-only
  stop · main-never-opens-pixels (vision law)

## §A CONTEXT (evidence base)
Current state (measured 2026-09-10, host): bundle SHA
`90279713d4d3a76a13a396246cd0a9eb5408c3a6e43e1d00dc4e53572a8d681f`
identical live + checkpoint, 114285B, `node --check` CLEAN both,
`grep -c session:chat` = 1 (`:1509`), stub markers 4, `EventSource` 0.
pytest live `87 collected → 86 passed, 1 failed`
(`test_pollution_scrub_residuals` on `scripts/protect-vm.sh` OPENCODE string);
connect pair 9 passed; preview bridge+chrome+pyodide 26 passed. Baseline
`master @ ce9ff28`, live tree dirty (Bridge/*.swift, AppState, entitlements).
Prior builds: Session-1 greens (56046a7/aed95fa) · Aug-15 zero-trust audit
(VERIFIED WITH CAVEATS, F1 stub-vs-real, F2 blob-only, F4 XCUITest-never-green
— F4 since CLOSED for /connect via t76 XCUITest path) · t76 proof (407s,
mux 447.670s/461973bps PASS, stills 01-05 legs PASS, tail 401 leg FAIL).
References read: `CHECKPOINT_MANIFEST.md` (53L), `HONEST_WATCH.md` (89L),
`CONNECT_SPEC.md` (32L), `TAKEOVER_DUMP.md` (622L), `TAKEOVER_MANIFEST.md`
(177L), `NEUTRAL_AUDIT_GROK_VS_WORKSPACE.md` (116L), `BINDING.md` (88L),
`GOAL_PIN_SC12_T78.md` (20L), `docs/GOD_LOOP_ACCEPTANCE.md` (gates A-E),
`docs/FORGE_ENGINEERING_SPECIFICATION.md`, `docs/FORGE-PREVIEW-SPEC-V1.0.md`,
`docs/testflight-setup.md` (227L), `reports/Engineering_Report_v2.md`.
A fresh agent reading only this §A holds the full situation: /connect built +
unit-green, SC-11c partial on the 401, t78 staged rotation-gated, SC-12 +
ship open.
## §B THE DENSE BUILD PLAN
Module map (interfaces + flows): (i) bundle input layer — `inputHandler`
→ slash table → `processWithAgent`/`runForgeAgent`; EDIT adds SSE stream
reader + tool-call dispatcher + plain-words intent map; flows: text in →
tokens out (stream), tool JSON out (exec). (ii) bridge — `ForgeEngine`
hosts, `ForgeBridge` Keychain, `ForgeCommandRunner` exec with cwd jail +
allowlist; EDIT adds tool-call entry from agent context (same allowlist,
no new privilege). (iii) preview — `PreviewPaneView` + `preview-bootstrap.js`
capture; EDIT adds write-triggered reload + console→agent route.
(iv) auth — SecureField + Keychain + UserDefaults + merge; NO EDIT unless
t78 verdict demands (D1 default: none). (v) Mode 2 — untouched (out of wave
except regression). File manifest: EDIT `forge/src/forge-entry.ts`,
`forge-terminal-surface.ts`, bundle rebuild; EDIT `ForgeCommandRunner.swift`,
`PreviewPaneView.swift`, `preview-bootstrap.js`, `BuildOnDeviceScreen`
strings; EDIT `scripts/protect-vm.sh` or test exemption (D2);
EDIT `GAUNTLET_PROGRESS.md`; NEW take dirs, `FAILURE_LOG.md`,
`TESTING_LOG.md`, `proof-forge-ship.ts`; DELETE nothing. Wave sketch:
W1 desks {t78-driver, B4-scrub} disjoint {take-dir, protect-vm.sh/test} gate
SC-a/g; W2 {stream-builder} disjoint {forge/src/*} gate SC-c+h; W3
{tools+preview} disjoint {CommandRunner, PreviewPane, bootstrap} gate
SC-d/e/f; W4 {plain-words, battery} disjoint {input layer, strings} gate
T-9; W5 {soak, device} gate SC-i/j; W6 {TestFlight, seal} gate SC-k/l.
Waves sequential (builder≠critic law); watcher blind per take.

## §1 Problem Statement
Ship FORGE as grandma-usable opencode mobile: typed plain-words request →
live streamed agent work (write/edit/run on-device) → Preview tab shows the
result → one approve tap. Five named blockers stand between today and that:
(1) t76 second-call 401 undecided (transient vs systematic Keychain-read /
session-header cause); (2) agent loop is phase1-stub (1 emitter, no SSE, no
tool-call path from agent context); (3) agent→preview reload loop never taped;
(4) suite not 87/87 (B4 residual); (5) unsigned, no TestFlight, checkpoint
uncommitted. Operator directive verbatim: phone LAST, VM E2E first; SC-12-only
legal stop; fresh Go key, never persisted in chat/rows.

## §2 Architecture
Mode 1: SwiftUI (`BuildOnDeviceScreen.swift` 1208L) + SwiftTerm surface +
hidden WKWebView (`ForgeEngine.swift:69-97`, non-persistent store, `native`
handler, `allowFileAccessFromFileURLs :77-78`) + esbuild IIFE
(`scripts/build-forge-bundle.mjs:96-99`, entry `forge/src/forge-entry.ts`,
browser/platform, safari16) + Node-builtin shims (`forge/shims/*`, 13 files).
Auth: slash table → SecureField → Keychain (`ForgeSettingsKeys.apiKey`) +
UserDefaults (provider/model/URL + `apiBaseUrl`) → `injectAPICredentials`
hot-swap `window.__forgeConfig`. Exec: `ForgeCommandRunner.swift` 532L +
`PyodideSchemeHandler.swift` 272L. Preview: `PreviewPaneView` 157L + toolbar +
nav-delegate + mode-toggle + ConsoleDrawer + `preview-bootstrap.js` 129L
(console/error capture → `previewConsole`/`previewError`). Mode 2: Mission
Control fleet view (session protocol tests green). Build: XcodeGen
(`project.yml`, SwiftTerm `from: 1.15.0`) → xcodebuild iphonesimulator on
6GB start-tahoe guest (SSH p50922, sim UDID …8187). No host Swift toolchain
(`swift: command not found`, `xcodegen: command not found` — guest-only).

## §3 Discovery Intelligence
- Files/Lines: 71 Swift / 19677 lines · bundle 2717L / 114285B · 23 forge
  src+shim files · 13 pytest files (87 collected) · docs 10823L across 12
  files + engineering spec + preview spec + acceptance + runbooks
- Entry Points: FORGEApp.swift:7 · ForgeEngine.swift:190-214 ·
  forge-entry.ts:26 bootstrap · /connect table bundle:1854-1912
- Markers: `session:chat` 1 · stub 4 · SSE 0 · Bearer/:1960-1974 present
- Tests: full 86+1 · connect 9/9 · preview 26/26 · tsc N/A (0 `.ts`)
- Rig: 6GB start-tahoe · XCUITest-only · mux gates ≥90s/≥400kbps
- Gaps: 401 open · streaming absent · preview pipe untaped · B4 ·
  unsigned · untracked checkpoint (`git ls-files` = 0)
## §4 Core Insight
The implementation must produce runtime-grade software that works correctly
in a real runtime environment — not just code that compiles. Governing
non-negotiables: error handling on every path (401/timeout/retired-model/
key-like/empty-key refuse locally, never hang, never leak — CONNECT_SPEC
§Known-bad); boundary validation (slash-arg key-shape refused, unstored,
unechoed); resource cleanup (recorder off, mux pulled, sandbox rms, no
mid-record simctl shots); side-effects-before-claims (no PASS without the
tool-result token + the artifact row). The single thesis for this wave: close
the loop the stub leaves open — every typed request must be able to reach a
live model, change bytes, and show pixels, or FAIL loudly with the named
cause. No new stores (existing UserDefaults/Keychain plumbing only), no
re-panels, no weakened claims.

## §5 Scope (loaded work items, ≤200 chars each, ≤20)
1. t78 rotation-gated 401 branch (same-binary 200→401 contrast decides cause)
2. SSE/Toon stream render in bundle (replacing stub `process()` path)
3. Agent-context tool calls (write/edit/runCommand from agent, not buttons)
4. Agent→preview reload + console-back-to-agent loop, taped end-to-end
5. Plain-words UX (no slash cmds, no error codes on grandma path)
6. B4 scrub/allowlist (`scripts/protect-vm.sh` OPENCODE string) → 87/87
7. T-9 functional battery green on single tape
8. SC-12 soak (10m mixed + RSS t0/5/10, serve <4GB, growth <30%)
9. Team-signed device build + operator 10m on-phone smoke
10. TestFlight packaging (`docs/testflight-setup.md` 227L runbook)
11. Checkpoint commit (restore-by-hash) + Mode-A seal at delivery
12. FAILURE/SPEC_VIOLATION/TESTING logs opened (manifest admits absence)

## §5 EXPANSION (per-item acceptance + files + wave)
1. t78: GAUNTLET row t78 (PASS or FAIL with named cause) + HONEST_WATCH-t78
   entry + mux mp4 + stills; files: EDIT `GAUNTLET_PROGRESS.md`, NEW take
   dir; wave W1; gate: SC-a.
2. Streaming: bundle `process()` routes LLM stream via EventSource/chunked
   fetch, TUI appends partial tokens; files: EDIT `forge/src/forge-entry.ts`
   (or live-bundle source tree), EDIT `forge-terminal-surface.ts`, rebuild
   bundle, SHA re-pinned; wave W2; gate: SC-c + `EventSource`>0.
3. Tool calls: agent-context `write`/`edit`/`runCommand` dispatched through
   `native` bridge with allowlist + cwd jail; files: EDIT bundle dispatch
   table + `iOS/FORGE/Bridge/ForgeCommandRunner.swift`; wave W3; SC-d/e.
4. Preview loop: file-write triggers preview reload; console/error frames
   route back into agent context; taped; files: EDIT `PreviewPaneView.swift`
   + `preview-bootstrap.js`; wave W3; SC-f.
5. Plain-words: 3 intents (ask/build/show) mapped over slash table; slash
   retained underneath; files: EDIT bundle input layer + Mode1 strings;
   wave W4; gate: grandma-path eyes-check (no codes on tape).
6. B4: per D2; files: EDIT `scripts/protect-vm.sh` or test exemption;
   wave W1; SC-g.
7. T-9 battery: single-tape M+V+C+A groups green; take row + mux; W4; §7.
8. Soak: 10m mixed + RSS t0/5/10 + `simctl diagnose` zero SIGSEGV/SIGABRT;
   W5; SC-i.
9. Device: team-signed build, devicectl install/launch, 10m phone smoke
   note; W5; SC-j.
10. TestFlight: archive + upload receipt per `docs/testflight-setup.md`;
    W6; SC-k.
11. Checkpoint: `git add Checkpoints/` + Mode-A seal line; W6; SC-l.
12. Logs: NEW `FAILURE_LOG.md` (B1 verdict), `TESTING_LOG.md` (t78+T-9+soak
    rows); W1/W6.

## §6 Success Criteria (every row command/ledger/eyes-checkable)
| # | criterion | check |
|---|-----------|-------|
| SC-a | t78 verdict rowed (transient vs systematic + evidence) | GAUNTLET row + HONEST_WATCH entry |
| SC-b | live call succeeds twice post-relaunch on persisted key | 2× `TEST_PASS` stills, different relaunch |
| SC-c | stream renders token-by-token in TUI (no full-block flash) | mux frames show partial text + `EventSource`>0 in bundle |
| SC-d | agent writes file → bytes on disk, `sha256sum` match | exec sha + read-back in artifact |
| SC-e | agent runs command → exit code observed in TUI | `runCommand` result frame in mux |
| SC-f | preview renders agent output + console routes back | preview still + `previewConsole` frame |
| SC-g | pytest 87/87 | `pytest tests -q` → `87 passed` |
| SC-h | `node --check` clean + bundle SHA pinned in manifest | check output + manifest SHA line |
| SC-i | soak RSS/growth within bounds, zero SIGSEGV/SIGABRT | `simctl diagnose` + RSS log |
| SC-j | signed device install + 10m phone smoke | devicectl install/launch log + operator note |
| SC-k | TestFlight package per runbook | archive + upload receipt |
| SC-l | checkpoint committed, `git ls-files`>0, Mode-A seal | ls-files count + seal line |

## §6 EXPANSION (threshold rationales — why each number)
SC-b needs TWO passes because t76 proved exactly one (first 200, second 401:
HONEST_WATCH.md:52-55) — one pass re-proves nothing. SC-c's partial-token
rule exists because full-block flash is the stub's signature behavior; mux
1fps deltas are the mechanical detector (§8d). SC-d's sha-match (not
file-exists) because existence without bytes is the theatrical-write class.
SC-g's 87 (not 86) because B4's residual is a named test, and a waived test
is a waived contract — D2 resolves it, the suite doesn't excuse it. SC-i's
bounds (serve <4GB, growth <30%, zero SIGSEGV/SIGABRT) come from the recovery
plan P5 (FORGE_RECOVERY_TO_IPHONE_SHIP_PLAN_20260815.md:178-182) and the
27GB serve-catastrophe forensic plan — soak is where that class resurfaces.
SC-j's 10 minutes matches the recovery plan P6 operator smoke (§193-202).
## §7 CONTAINER TEST PLAN (plan-first; 6 angles, tokens tool-result-bound)
OBJECTIVE: prove the ship wave's runtime behaviors on the guest/sim rig
(stream, tool-call, preview loop, persistence, soak) with zero circularity.
TOOLS UNDER TEST: `forge-bundle.js` diff (stub→stream+tools) + bridge
`ForgeEngine/ForgeBridge/ForgeCommandRunner` + `PreviewPaneView` +
Keychain path; blast radius = every importer of `__forgeConfig`.
Angles (prompt → passToken [tool-result] / failToken / max):
1. IDENTITY — `/connect status` after key rotation → `"configured"` in
   TUI frame / `accepted-invalid-input` / 120s
2. TOOLS — agent `write`+`runCommand` round-trip → `exit 0` in exec +
   sha match / `unknown_action` / 300s
3. ERRORS — revoked key 401 → `FAIL: provider answered 401` + re-key
   hint / hang-or-leak / 180s
4. BOUNDARY — key-like slash arg + empty key → leak-warning refusal,
   prior config kept / `stored-invalid` / 120s
5. STATE — relaunch → status `configured` + live USE of persisted key
   (SC-b) / `SECOND_CALL FAIL` / 300s
6. INTEGRATION — full chain: ask → stream → write → run → preview →
   console-back (`"overall":true` in results artifact / `"overall":false`)
   / 600s. ADVERSARIAL: 401-replay + key-echo attempt + mux-kill mid-run
   (recovery rowed, not skipped). EVIDENCE: container/sim UDID + bundle
   SHA + `.trident/container-test-results.json` per-scenario rows.
   PASS: 6/6 tokens in tool-result context + failTokens absent + Phase-E 10.
   Per-scenario evidence lines: IDENTITY → TUI status frame screenshot;
   TOOLS → exec `sha256sum` + TUI `exit 0` frame; ERRORS → TUI 401 frame +
   re-key hint frame; BOUNDARY → refusal frames + config-unchanged status;
   STATE → post-relaunch `configured` frame + second `TEST_PASS` still;
   INTEGRATION → full mux (600s budget) + results artifact `overall:true`.
   Pass threshold: 6/6 executed, 6/6 tokens matched in tool-result context,
   0 timeouts, 0 circular (agent-typed) tokens, artifact written.

## §8 THE ANTI-PATTERN LEDGER
ARCHITECTURAL: (a) daemon-as-drive — bundle logic drifting into Swift
duplicates → detect: `grep -rn processWithAgent iOS/ | wc -l` must be 0;
(b) new credential stores beside Keychain/UserDefaults → detect: new
`setSecret|UserDefaults(` call-sites outside bridge must be 0;
(c) second WKWebView runtime beside ForgeEngine → detect: `WKWebView(`
count == 1. BEHAVIORAL: (d) full-block flash instead of streaming → detect:
mux 1fps frames show zero partial-text deltas; (e) silent 401 acceptance →
detect: results artifact lacks `401` token on failure takes; (f) key bytes
to pixels/logs/rows → detect: §12 grep contract + stills secrets-pass.
PROCESS: (g) model-mediated birth (agent retyping generated prompts) →
detect: dispatched-prompt SHA vs file SHA mismatch; (h) stale-image deploy
(old bundle SHA under test) → detect: exec `sha256sum` vs manifest SHA;
(i) tool-call-as-entry (buttons faking agent path) → detect: scenario
prompts address agent surface, no native-button steps. Bare-keyword-grep
detections without the named artifact are LEXICON VIOLATIONS.

## §9 THE OPEN DECISIONS
D1: 401 systematic-fix shape (deferred to t78 evidence; default: no product
change until verdict — HONEST_WATCH.md:76). D2: B4 scrub vs allowlist
(default: allowlist `scripts/protect-vm.sh` with comment + test exemption,
evidence: protector is infra not product). D3: checkpoint commit vs
copy-restore (default: commit + Mode-A seal at delivery; untracked until
then). D4: SSE transport (default: EventSource against `/responses` stream;
fallback: chunked fetch reader). D5: grandma plain-words scope (default:
3 intents — ask/build/show — slash table retained underneath).

## §9 EXPANSION (evidence per fork + recommended default)
D1 evidence: HONEST_WATCH.md:52-55 (200→401 minutes apart, same binary) +
:68-76 (cause open, no product change yet); default holds unless t78 shows
systematic Keychain-mangle (then: re-read path fix, never broader rewrite).
D2 evidence: `pytest tests -q` → `test_pollution_scrub_residuals` names
`scripts/protect-vm.sh` OPENCODE string; protector is VM-infra, not product;
default allowlist + comment keeps 87/87 honest (bytes unchanged, exemption
rowed). D3 evidence: `git ls-files Checkpoints/...` = 0, `status --porcelain`
`?? Checkpoints/...`; default commits at delivery (restore-by-hash) so the
ship artifact is hash-addressable. D4 evidence: provider exposes `/responses`
stream (bundle :1960-1974 POST shape); default EventSource, fallback chunked
fetch if the Zen endpoint refuses upgrade — decided by W2 spike, rowed.
D5 evidence: grandma path = 3 verbs max (ask/build/show); slash table stays
as power layer; default ships both, eyes-check on grandma tape (no codes).
## §10 THE SPEC ILLUSTRATED (master graphs; every box → its §)
G1 MASTER VIEW (§5→§6→§7→ship):
```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ t78 401 close│─►│ stream+tools │─►│ preview loop │
│ §5.1 §6.a-b  │  │ §5.2-3 §6c-e │  │ §5.4 §6f     │
└──────────────┘  └──────────────┘  └──────┬───────┘
                                           ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ TestFlight   │◄─│ soak SC-12   │◄─│ battery T-9  │
│ §5.10 §6k    │  │ §5.8 §6i     │  │ §5.7 §6g     │
└──────────────┘  └──────────────┘  └──────────────┘
```
G2 CORE MECHANISM (agent loop state machine, §4):
```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ TYPED ASK    │─►│ STREAM LIVE  │─►│ WRITE+RUN    │
│ slash/plain  │  │ SSE tokens   │  │ tool-result  │
└──────────────┘  └──────────────┘  └──────┬───────┘
                       │ 401/timeout       ▼
                       ▼              ┌──────────────┐
                 ┌──────────────┐     │ PREVIEW+BACK │
                 │ LOUD FAIL    │     │ console route│
                 │ named cause  │     │ §6f          │
                 └──────────────┘     └──────────────┘
```
G3 OVERLAYS (always-on: key hygiene, watcher, gates):
```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ SecureField  │  │ watcher text │  │ mux gates    │
│ never pixels │  │ main no pixel│  │ 90s/400kbps  │
└──────────────┘  └──────────────┘  └──────────────┘
```
G4 BUILD MANIFEST (waves, disjoint files):
```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ W1 t78+keys  │  │ W2 stream    │  │ W3 tools+prev│
│ Swift only   │  │ bundle only  │  │ bundle+Swift │
└──────────────┘  └──────────────┘  └──────────────┘
invariant core untouched: ForgeEngine WKWebView config, entitlements shape
```
G5 NAMED-ERROR MAP (§4/§7): `FAIL: no API key` · `FAIL: provider answered
401` · leak-warning refusal · retired-id refusal · timeout keep-prior ·
`SECOND_CALL FAIL` — each local text, never hang, never leak.
G6 GRANDMA SEQUENCE (swimlane: Grandma │ TUI │ Agent │ Preview):
ask-words → stream-tokens → write-file → run-exit → preview-render →
console-back → APPROVE → done. Every arrow is a §6 criterion (SC-b..f);
any broken arrow lands on G5's error map, never a silent stall.
## §11 THE SCRIPT TESTING SUITE (Mode B harness; real modules, sandbox, Exit)
HARNESS (`proof-forge-ship.ts`, bun): mkdtempSync sandbox + addFinalizer
rm; dynamic `import()` of the REAL unit (bundle funcs via extracted
`forge/src/*.ts`, pytest via spawned `python3 -m pytest` captured Exit);
verbs allowed: diskBytes · rows · exitShape · stateOf · emitted ·
returnedValue. Exactly ONE runPromise at the bottom edge; per-scenario
`Effect.timeout` (hang = named FAIL).
ST-1 BUNDLE MARKERS: import built `forge-bundle.js` text → assert
`session:chat` ≥1 (diskBytes), `EventSource` ≥1 post-W2 (SC-c),
`/connect` table present, `phase1-stub` ABSENT post-W2. Adversarial: stub
fixture (pre-wave bundle) must FAIL the same assertions (proves teeth).
ST-2 SLASH TABLE: feed `/connect provider|model|url|key|test|status` +
unknown-slash + key-like-arg + empty-key → assert spec-named tokens
(`Saved provider`, leak-warning, refusal) in returnedValue; unknown slash
never reaches LLM stub (emitted channel shows local error, no `runForgeAgent`
call). ST-3 CREDENTIAL MERGE: drive `injectAPICredentials` contract via
bridge-source shape test (UserDefaults keys + `apiBaseUrl` + Keychain
`apiKey`) → assert merged config object; adversarial: missing key →
`FAIL: no API key`. ST-4 PREVIEW PIPE: `preview-bootstrap.js` console/error
capture → assert `previewConsole`/`previewError` handler payloads in emitted
sink; adversarial: uncaught throw still routes (no silent drop). ST-5 B4:
`scripts/protect-vm.sh` OPENCODE string disposition → assert suite verdict
matches decision D2 (scrubbed bytes or allowlisted exemption row).
RUNNER: `bun run proof-forge-ship.ts` prints `PASS/FAIL name detail` table,
exit 0 iff all PASS. ASSERTION TABLES (spec-token → observable):
ST-1: `session:chat`≥1/diskBytes · `EventSource`≥1/diskBytes ·
`phase1-stub`==0/diskBytes · `/connect` present/diskBytes.
ST-2: `Saved provider`/returnedValue · leak-warning/returnedValue ·
refusal/returnedValue · no-`runForgeAgent`-on-unknown-slash/emitted.
ST-3: merged `apiBaseUrl`/returnedValue · `FAIL: no API key`/returnedValue.
ST-4: `previewConsole` payload/emitted · `previewError` on throw/emitted.
ST-5: B4 verdict matches D2/diskBytes+rows. ADVERSARIAL HALVES: stub-bundle
fails ST-1 (teeth) · key-like arg refused (no store) · empty-key keeps prior
· throw still routes preview-error · pre-wave bundle fails `EventSource`. ANTI-CHEAT: written-before-code (this spec), spec-named
tokens only, observable-only verbs, runner exit code, no spies; pytest
cross-check `87 passed` required alongside (ST suite judges logic, battery
judges product).
## §12 THE DEEP CONTAINER TESTING SUITE (guest/sim rig instantiation)
12-STEP INSTANCE: plan-first (§7, 2000+ chars, preflight READY) → setup
(fresh target, 6GB start-tahoe, bundle SHA verified vs manifest) → AUTH
PROBE FIRST (live Go 200, zero env overrides, keyfile-only) → status-bar/
TUI-frame verification (screenshot=message channel, exec=disk truth) →
6 scenarios (§7 angles) via XCUITest driver + watcher + mux → adversarial
discipline (first error = bug, fix+retest) → Phase-E 10 → results artifact
→ zero-broken-windows (battery+tsc N/A+build) → declaration (sha proof +
token excerpts + per-scenario behavior + verdicts; structural-PASS banned).
FAMILIES: AUTH (rotation, zero-override by construction + planned in-test
env assert) · STREAM (partial-token frames POSITIVE + full-block NEGATIVE) ·
TOOL-CALL (write/run POSITIVE with sha+exit tokens; button-bypass NEGATIVE) ·
PREVIEW (render+console-back POSITIVE; empty-preview NEGATIVE) · PERSISTENCE
(relaunch USE, SC-b) · SOAK (RSS/growth/crash-free) · ADVERSARIAL (401-replay,
key-echo, mux-kill recovery). ARTIFACT SCHEMA: per-scenario {name, angle,
passToken, failToken, passTokenMatch, failTokenAbsent, toolResultContext,
maxWaitMs, timedOut, verdict, evidence} + phaseE[10] + overallVerdict.
PASS: Phase-E 10/10 + negatives zero-misfire + declaration 4 elements.
Family POSITIVE+NEGATIVE pairs (each use case both halves, same run):
STREAM-POS (partial-token frames fire) / STREAM-NEG (legit full answer
unmutated, no gate fires) · TOOL-POS (write/run tokens) / TOOL-NEG (read-only
ask passes, zero tool gate) · AUTH-POS (revoked key 401 token) / AUTH-NEG
(valid key 200, zero misfire) · PREVIEW-POS (render+console-back) /
PREVIEW-NEG (static page, no spurious reload) · STATE-POS (relaunch USE) /
STATE-NEG (fresh install clean-onboard, no stale-config carry) · SOAK-POS
(RSS bounds hold) / SOAK-NEG (normal use never flagged). A use case with one
half is untested; a POSITIVE satisfied by a generic gate is UNOBSERVED.

## §13 COMPLETION CHECKLIST + ZERO-TRUST AUDIT
Checklist: 11 contract sections in order ✓ · ledger detections mechanical ✓ ·
decisions D1-D5 with defaults ✓ · evidence-currency clean (t76/HONEST_WATCH
latest; God-loop gates A-E marked Jul-29 STALE where superseded) ✓ · §7 6
angles + evidence + threshold ✓ · §6 all checkable ✓ · numbers measured ✓ ·
problem matches operator directives ✓ · no duplicate sections ✓ · graphs ≥4
with §-mapping ✓ · script suite (harness+5 ST+both halves+runner+anti-cheat)
✓ · container suite (12-step+families+schema+Phase-E) ✓ · skills loaded ✓.
Audit (adversarial read): no invented numbers (all host-measured or cited);
no derailment fuel (401 fork → D1+t78, B4 → D2, SSE → D4); verifiable §6;
plan-first integrity (§7 6/6 + Phase-E); mission fidelity (grandma target =
operator ship intent). Findings: none blocking. Verdict: APPROVED —
dispatchable to `trident-deep-planning` L2 or build agents.
SPEC-MANAGER GATE (revision loop): run
`bun run scripts/spec-manager.ts docs/FORGE_SHIP_DPL1_SPEC.md`; address every
✗ with the named remedy (missing section → write it; slop signature → name
the token/artifact; thin density → expand with measured anchors); no dispatch
(W1 or L2) until ✅ APPROVED. The machine's verdict is recorded in the wave
ledger before any build agent spawns.
*Completion marker: all anchors consumed, checklist §10 green, audit §11 verdict APPROVED.*
