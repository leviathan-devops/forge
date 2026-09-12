# CURRENT_STATE — FORGE anchor @ b768743 line (2026-09-11, T11 docs pass)

## Anchor + baseline
- Root: `/home/leviathan/OPENCODE_WORKSPACE/Shared Workspace Context/MIMOCODE/Forge` (live `OPENCODE_WORKSPACE/FORGE` is reference + bulk host only).
- Git: master through `8083557` + air-drop continuity; bundle `f06bda2bfabeedd6` sealed == worktree (independent recount); suite 88/88; node clean.
- Air-drop branch `e7a3071` live on GitHub (product tree, secrets redacted, API-verified).

## Per-module status (all paths absolute under anchor)
- **Agent runtime** `iOS/FORGE/Resources/forge-bundle.js:26` bootstrap → `:1854` slash table → `:1987` `runForgeAgent` 12-iter loop → `:1481` AGENT_TOOLS (read/write/edit/python/bash/grep/preview) → TUI writes + done-check. Chunked-callback streaming (66ms throttle, muse normalizer); `session:chat` 1 emitter (`:1510`); EventSource 0. Lockdown allowlist `:1860`; bytes marker `:1796`.
- **Bridge** `iOS/FORGE/Bridge/ForgeBridge.swift:544` get/setSecret, `:576` promptSecret, `:616` saveProviderConfig (paid-only), `:755` runPython (forgepy Pyodide 0.27.7, stdout capture, 120s native watchdog). `ForgeEngine.swift:190` loadBundle (hidden WKWebView), `:381` injectAPICredentials (UD+Keychain+env merge).
- **Auth**: SecureField → Keychain `forge.apiKey` → hot-swap; provider/model/URL in UserDefaults; migrate guard `AppState.swift:289`.
- **Preview**: `PreviewPaneView.swift:46` container (not leaf); always-mounted branches (`BuildOnDeviceScreen.swift:391`); bootstrap console capture; agent-fired render proven t91/t125.
- **Proof rig**: `tmp/run-connect-proof.py` (mirrored `scripts/run-take.py`): rsync, keyfile 0600, entitlements, uninstall/--no-uninstall, recordVideo, build, test, fetch, redact, sim-mutex. Tests: ConnectProof, Battery (flow/standalone/connected), E2E fixture, Soak.
- **Mode 2 Mission Control**: session protocol green; carried, unexpanded.

## Proven machinery (takes t76-t125, watchers 14 sessions, dual close A 5/5 B 5/8)
- SC-11: t80 (184s, 06 stills, mux 207s/543k). T-9: t98 deterministic (67s, watcher 3/3) + t121/t125 live (stdout + preview, watcher PASS). Soak: t100/t103 (background/tabs/relaunch). Approval: t125 mux 386s/636k both gates.
- Suite standing green across every product edit (zero regressions).

## Open (honest)
- SSE token-streaming absent (chunked only); plain-words UX unmapped; device/TestFlight/phone operator-owned (0 guest identities); key rotation (2 chat copies); disk 97%; VM DOWN (restart ~15min); firewall OFF per operator order.

## Per-take evidence (t76-t125, verdicts condensed from GAUNTLET)
- t76 FAIL (2nd 401, cause open) → t78 FAIL same shape (fresh key) → t79 FAIL root FOUND (migrate) → t80 PASS SC-11 CLOSED.
- t81-t89 battery harness shakedown FAILs (no-wait tap, AX ids, snapshot timeouts) → tapStable/expectBubbleStable/Save-retry.
- t90/t91 live-agent legs green (writes, streaming, agent-fired preview; stdout/preview-revisit partial).
- t92/t93 backfilled FAILs (model skipped python); t94-t98 deterministic E2E → t98 PASS (watcher 3/3).
- t99-t103 soak → t100/t103 PASS (background/tabs/relaunch; s4 unmount-fix verified on pixels).
- t104-t121 F5 hunt (interference guard, 429 wall, narration-vs-markers, cold slowness) → t121 PASS (stdout ×3, watcher PASS).
- t122-t125 approval battery → t125 PASS (stdout+preview, mux both gates, watcher 2/2).
- Dual verification: A 5/5 stills, B 5/8 timeline (3 protocol-explained home frames).
- Audit: 2 fresh auditors → REFUTED-ship / VERIFIED-soak; 6 frauds, all fixed except human-gated.

## Calibration constants (named, never magic)
- Mux gates: duration ≥90s, bitrate ≥400000. Agent loop: 12 iters, 66ms emit throttle.
- Timeouts: connect test 150s, Keychain save 90s, python JS race 90s, native watchdog 120s, SecureField settle 45s.
- Proof budgets: write panel 420s, run window 600s, relaunch entry 5×(15+3+20s).
- Rig: 6GB start-tahoe, SSH p50922, sim UDID …8187, uptime gate 15min, host mem gate 6GB.
- Suite: 88 tests / 13 files; bundle node --check clean every wave.

## Failure modes (how each subsystem breaks, from the ledger)
- Auth: wrong model post-relaunch → 401 (migrate, fixed); empty key → "FAIL: no API key"; revoked → 401 + re-key hint.
- Python: cold-load stall → watchdog named error (120s); timeout → ✗ rendered; empty stdout → "(empty)" marker + byte count.
- Preview: tab-switch unmount → blank (fixed: always-mounted); leaf-flag hid web text (fixed: container).
- Harness: sick snapshots → stable-retry; concurrent takes → sim-mutex refuse; killed take → recorder wedge → sim reboot.
- Quota: 429 wall → backoff ladder (10/30min) + direct key-liveness probe; pool-vs-key disambiguation via proxy probe.

## Module deep detail (interfaces, flows, failures, constants)
### Agent runtime (`iOS/FORGE/Resources/forge-bundle.js`, 2719L)
- Interfaces: `bootstrap()` (:26) wires terminal surface + config + plugin + runtime → `window.__forge`; `inputHandler` routes slash vs natural; `buildConnectUpdate` validates provider/model/url/key; `connectTestCall` (:1954) minimal live probe; `runForgeAgent` (:1987) 12-iteration tool loop.
- Data flow: typed input → slash table (local, never LLM for secrets) → provider normalize → SecureField/Keychain for keys → hot-swapped `__forgeConfig` → LLM via native httpRequest/Stream → tool dispatch (read/write/edit/python/bash/grep/preview) → terminal writes + chat bubbles + done-check counts.
- Failure modes: 401/timeout/retired/key-like/empty all refuse locally with named text; unknown slash → local error; 90s JS race + 120s native watchdog bound runPython (double-settle safe); transcript virtualization prunes old bubbles (AX).
- Constants: 12 iters; 66ms stream throttle; 4000-char cap; mux gates 90s/400kbps; SecureField settle 45s; Keychain save allowance 90s; prove windows (write 420s, run 600s, marker 300/600s).
### Bridge (`iOS/FORGE/Bridge/`, 10 files)
- `ForgeEngine.swift:69` WKWebView config (hidden 0x0, non-persistent store, native handler, file-access flags); `:190` loadBundle; `:381` injectAPICredentials (UD+Keychain+env merge, esc, session/project/request ids); `:740` message router (__output/__ready/__error/__pythonResult/__pythonError/readFile/writeFile/runCommand/http).
- `ForgeBridge.swift:544` get/setSecret, `:576` promptSecret SecureField alert, `:616` saveProviderConfig (paid-only refusal), `:755` runPython (forgepy Pyodide 0.27.7, setStdout capture, stdout+repr delivery).
- `ForgeCommandRunner.swift` 532L curated sandbox; `PyodideSchemeHandler.swift` forgepy scheme + wasm MIME; `MissionControlClient.swift` fleet sessions.
### Auth + lockdown
- SecureField → Keychain `forge.apiKey` (SecItemDelete+Add, no dupes) → re-inject hot-swap; provider/model/URL (+apiBaseUrl) in UserDefaults; status length marker `configured (N chars)` (no material).
- Bundle allowlist (`:1860` only-model refusal); bridge `allowedModelID` (`ZenModelCatalog.swift:16`); retired free-1.3 + deeps/1.2; migrate early-return (`AppState.swift:289`).
### Preview (`Presentation/Mode1_BuildOnDevice/`)
- `PreviewPaneView.swift:46` container-not-leaf; always-mounted branches (`BuildOnDeviceScreen.swift:391`, zero-height collapse + opacity + no-hit + clipped); toolbar, toggle, console drawer, gestures; `preview-bootstrap.js` 129L console/error capture.
### Proof rig
- Driver `tmp/run-connect-proof.py` (mirrored `scripts/run-take.py`): rsync anchor→guest, keyfile 0600 via sftp, entitlements plist, uninstall (or --no-uninstall), recordVideo with wedge handling, xcodegen+build, XCUITest, fetch stills+mux, key scrub, sim-mutex refuse on concurrent drivers.
- Tests: ConnectProof (SC-11 legs + tripwires), Battery (flow/standalone/connected + done-check signal), E2E fixture (deterministic write→run→render), Soak (background/tabs/relaunch + dual entry).
- Watcher protocol: spawned blind agents read stills via omni-vision/read; main consumes VERDICT + deltas; dual close on milestones.
### Mode 2 (carried)
- Session protocol tests green; MissionControl screens navigable (D3-era PASS carries); no wave work this cycle.

## Bridge method table (Swift entry points an agent will call or read)
| method | file:line | contract |
|---|---|---|
| loadBundle | ForgeEngine.swift:190 | loads forge-bundle.js via loadHTMLString; non-persistent store; native handler; file-access flags |
| injectAPICredentials | ForgeEngine.swift:381 | merges UD provider/model/URL + Keychain key + launch env; escapes quotes; hot-swaps __forgeConfig; refreshes catalog async |
| getSecret/setSecret | ForgeBridge.swift:544/555 | Keychain load/save behind callback ids; missing-arg rejections |
| promptSecret | ForgeBridge.swift:576 | SecureField alert on main thread; resolves typed value to JS memory only; never logs |
| saveProviderConfig | ForgeBridge.swift:616 | validates provider/model/url; paid-only refusal; persists; re-injects |
| runPython | ForgeBridge.swift:755 | guards code present; requires bundled pyodide dir; evaluates loader JS; 120s native watchdog; resolves stdout+repr |
| httpRequest | ForgeBridge.swift:370 | URLSession, 120s timeout, Zen identity headers stamped, resolves status+headers+body |
| renderPreview | PreviewBridge | isolated WKWebView render of sandbox path; console/error capture |
| sessionID/projectID | ZenClientIdentity.swift:23/33 | persisted ses_/wrk_ ids; stable across relaunch; per-conversation mapping specced, unwired |

## Data-flow sequences (the three golden paths)
### Connect (SC-11, t80 pattern)
type /connect provider/model/url → slash table validates → saveProviderConfig persists → inject hot-swaps → SecureField key → setSecret Keychain → re-inject → /connect test → native httpRequest Bearer → PASS bubble + footer → terminate → relaunch → inject reads Keychain → status configured → second live 200.
### Agent turn (t121 pattern)
prompt → boxed echo + working status → 12-iter loop (stream deltas → tool calls: write/read/python/preview) → per-tool ✓ rows → done-check counts → summary prose → footer attribution.
### E2E fixture (t98 pattern)
FORGE_TEST_MODE1_E2E=1 → scheduleMode1E2E (run-once guard) → writeFile hello.py → runPython (Pyodide stdout capture) → write index.html from result → renderPreview → card (FORGE PREVIEW + ANSWER 42 + CANVAS OK) → AX-visible web text asserts green.
### Soak (t100/t103 pattern)
render → home-press 60s → activate (state intact) → tab cycle (TERMINAL/SPLIT/PREVIEW, content survives) → terminate → launch (restoration or menu) → dual-entry proof → render again.

## Failure-mode matrix (observed class → detector → remedy location)
- Wrong-model 401 → post-relaunch status model line → migrate guard (DONE).
- Silent hang → bytes marker absent + no ✗ → native watchdog (DONE).
- Blank revisit → s-still black with rendered b0 → always-mounted branches (DONE).
- Unmatchable surface → UI dump missing id → label taps / container flag (DONE).
- Double-run race → second PYTHON ERROR → run-once guard (DONE).
- Cold slowness → fresh-boot timings → cools + connected-only takes (process).
- Sick snapshots → waitForExistence throws → stable-retry + settles (process).
- Interference → home mid-take, no crash → sim-mutex refuse (DONE).
- Quota wall → 429 prologue → backoff ladder + direct probe (process).
- Narration-vs-marker → prose matches tokens → done-check + watcher (process).
- Recorder wedge → recordVideo busy → sim reboot (documented).
- Stale seal → rows newer than commit → seal on milestones (process).

## Per-wave file inventory (what each wave touched, anchor paths)
- W1 SC-11: iOS/FORGE/App/AppState.swift (migrate guard), iOS/FORGE/Core/ZenModelCatalog.swift (allowedModelID + retired free-1.3), iOS/FORGE/Bridge/ForgeBridge.swift (paid refusal), iOS/FORGE/Resources/forge-bundle.js (allowlist :1860, status length marker), iOS/FORGE/UITests/ConnectProofUITests.swift (tripwires), tmp/run-connect-proof.py (take param, sim-mutex, --no-uninstall).
- W2/W3 engine: forge-bundle.js (bytes marker :1796, preview prompt docs), ForgeBridge.swift (120s watchdog), BuildOnDeviceScreen.swift (always-mounted branches), PreviewPaneView.swift (AX container flag).
- W4 battery: BatteryUITests.swift (flow/standalone/connected, done-check signal, stable helpers), E2EUITests.swift (deterministic fixture take), scripts/run-take.py (driver mirror), tests/test_mode1_zen_catalog.py (lockdown + marker pins).
- W5 soak: SoakUITests.swift (background/tabs/relaunch, dual entry proof).
- Audit-fix: GAUNTLET backfills, pyStage/temp-DIAG removal, TESTING_LOG corrections, seals befa59d→d9ab150.
- Handoff: AGENT_MACBOOK_AIR.md contract, air-drop branch (product tree, secrets redacted, API-verified).
- Suite: tests/test_mode1_zen_catalog.py (DEFAULT paid, RETIRED_FREE_13, lockdown asserts, marker asserts); B4 scrub in scripts/protect-vm.sh (script-relative FORGE_DIR).

## Open-item drilldowns (what remains, precisely)
- SSE: chunked-callback proven (payloads + throttle + normalizer + live turns); EventSource 0; SC-c gate text unmet. Close by implementing EventSource token path OR amending SC-c (operator call).
- Plain-words: zero mapped intents; slash table is the only path. Close by mapping ask/build/show + grandma tape with eyes-check.
- Device: 0 identities/profiles on guest; unsigned ARM64 22MB proven green. Close by Apple-ID session + archive/export/install/smoke (operator owns identity + USB).
- TestFlight: runbook untouched by takes; needs paid membership + App Store Connect. Close after device.
- Keys: 2 chat copies; env-only discipline verified (0 hits × ~20 logs). Close by rotation + one probe take.
- Disk: 97%; anchor duplication ~9G; debris evidence-protected. Close by archive order + prune (never volumes).
- Seal: MODE B mutable, fully rowed; Mode-A needs operator chattr. Close by order.
- Loader UX: cold-guest Pyodide stall named loud; progress/timeout UX unbuilt. Close by design + take.
- Affinity: per-conversation session derivation specced (GAUNTLET), wired nowhere, unverifiable under past quota wall. Close by implementation + dual-take cache comparison.

## Rig operating parameters (measured, not remembered)
- Guest: Tahoe 26.6.2, hw.memsize 6291456000, Xcode 26.6, sim iPhone 17 Pro 0DE1D698-8187-497A-8EAC-4CF80441F62D, SSH p50922 (alpine), uptime gate 15min.
- QEMU: -m 6000 Haswell-noTSX, 4 cores, OpenCore-tahoe, monitor telnet 4444 (screendump path), VNC chain half-configured (monitor proven, vncdo refused).
- Host: 31.7G box; 6GB free required to start takes; drop_caches for pagecache/slab; never kill other sessions; never prune volumes.
- Driver: rsync anchor→guest, keyfile 0600 sftp, entitlements plist (keychain group only), uninstall or --no-uninstall, recordVideo (wedge→reboot), xcodegen+build, XCUITest filter, fetch stills+mux, key scrub, sim-mutex.
- Quota: backoff 10/30min; direct key probe; pool-vs-key disambiguation via proxy probe (585/0→585/576 healthy pattern).

## Watcher protocol (the verdict layer, exact)
- Spawn: blind subagent, zero build context, still paths + 5 questions (screen/mode, output-as-agent-output vs echo, markers/errors, preview blank-vs-render, model id).
- Tools: trident-omni-vision direct mode if present in ITS surface, else read tool; one call per image; TEXT-ONLY returns.
- Main consumes VERDICT + deltas; never opens pixels (14 sessions clean).
- Dual close pattern (milestones): two fresh agents, one stills (A), one timeline frames (B); disagreements escalate to a third read, never to main's eyes.
- Known watcher failure: bytes never render in watcher context (t103 s5) → fall back to AX asserts + file sizes (s5 149KB == s0 byte-identical render).
- Still provenance law: in-test PNGs (XCUIScreen, witness asserts) vs mux-extracted frames (ffmpeg, tail coverage) labeled separately in HONEST_WATCH-style records.

## Take taxonomy (every take is one of these shapes)
- Connect-proof: prologue (provider/model/url/key/test) + persistence leg (terminate/relaunch/retest). Decides auth真相.
- Battery-full: prologue + multi-file agent prompt + tabs. Decides end-to-end (flaky: model skips steps).
- Battery-tight: prologue + single-tool order + done-check + still. Decides one capability cheaply.
- Battery-connected: NO prologue (--no-uninstall, Keychain carries). Decides agent behavior without SecureField flake.
- E2E-fixture: env FORGE_TEST_MODE1_E2E=1, no LLM, deterministic write→run→render. Decides product path, not model.
- Soak: fixture + background + tabs + terminate/relaunch. Decides stability + restoration.
- Diagnostic: stage markers / DIAG traces / length tripwires. Decides mechanism, then markers come OUT.
- Refire rules: harness cause → fix + refire; environment cause → cool + refire; model-behavior → re-prompt + refire; product cause → fix + rebuild + refire.

## Flake playbook (symptom → first action, no theorizing)
- Snapshot timeout (line 34, no stills): cool 15-30m, check guest load, refire. Never rewrite queries first.
- Main-thread busy 30s: check guest CPU + take cadence; cool; refire once before product blame.
- Home mid-take, no crash: concurrent driver suspected → sim-mutex check (`pgrep -af run-connect-proof`), refire.
- 429 prologue: backoff ladder, direct probe, pool disambiguation; never touch product.
- Recorder busy: sim reboot (server-side lock, no guest process holds it).
- Overlay left open: Save-tap retry (already in both proof tests).
- Phase matched, no completion: check DIAG/sim log for dispatch→result→resolve chain before blaming loader.
- Mux freeze bitrate: expected on static takes; stills carry proof; motion takes must pass it.
- Card absent 420s on cold guest: engine-ready window exceeded; warm guest or longer provisioning.

## Key + quota hygiene (the law, with receipts)
- Keys travel: operator message → env var in ONE bash call → guest file 0600 via sftp → SecureField typing → Keychain. Never disk (host), never logs (0 `sk-` hits × ~20 run logs, grepped per take), never memory rows, unset post-run.
- Contamination record: 2 Go keys + 1 Apple-ID password + 1 GitHub PAT pasted in chat across sessions; PAT + Apple pw found committed in old docs (redacted pre-push, ancestry proves neither reached GitHub). Rotation open for all three.
- Quota doctrine: 429s ladder (10/30min cools) → direct key-liveness probe (minimal /responses) → pool disambiguation (proxy probe 585/0→585/576 healthy pattern) → product blame only after pool green + key 200 elsewhere.
- Driver key handling: reads FORGE_GO_KEY env, refuses when empty (exit 2), scrubs exact + 18-char prefix from BOTH log copies, prints provisioning confirmations without values.

## Cross-reference index (where truth lives per question)
- "Did auth work?" → GAUNTLET t-rows + Evidence stills 01-06 + t80/t103 muxes.
- "Does the agent run code?" → t121 p0 (watcher: stdout ×3) + DIAG resolve record (15 bytes / 15s).
- "Does preview render?" → t91 b0, t98 e1/e2, t103 s4, t125 p1 (all watcher PASS).
- "Is it stable?" → t100/t103 + F6 numerics + dual timeline (no crash/error/blank in 8 frames).
- "What broke?" → FAILURE_LOG F-01..F-21 + DEBUG_LOG EN-1..EN-8.
- "What remains?" → NEXT_STEPS.md (this folder) + SPEC_VIOLATION_LOG.md (anchor root).
- "Can I trust the numbers?" → ZeroTrustAudit_2026-09-11.md + independent recount (Auditor A table).
- "How do I run a take?" → scripts/run-take.py + POST_COMPACTION_PROMPT.md first-action + driver --help surface.
- "How do I compile on Air?" → AGENT_MACBOOK_AIR.md (anchor root) + air-drop branch (pushed, API-verified).

## Doctrine (why each law exists — paid for in takes)
- Rows same turn: t92/t93 ran unrowed and the gap hid for a full audit cycle (F1) — the ledger is the memory.
- Backfills marked: silent history edits are indistinguishable from fraud; marked ones are process.
- Watcher verdicts: t90 XCTest-green/pixels-red proved prose and bubbles lie; only pixels decide output truth.
- Done-check counts: the sole XCTest-side signal that survives narration (t116 prose matched phase text).
- Cools before rewrites: t84-t89 burned takes on code that was never broken (guest strain); rest first, cut code second.
- Mutex before blame: t104 home-screen looked like product failure until concurrent sessions surfaced.
- Quota before product: t105-t109 burned takes on a throttled key the product couldn't fix.
- Composition is not a take: T-9 "closed by composition" was soft until t121/t125 proved single takes (F2 audit finding).
- Chunked is not SSE: naming precision (Auditor B) keeps SC-c honest.
- Seal on milestones: befa59d→d9ab150 chain lets any session verify any claim's code state by hash.
- Evidence retained: t60-t77 debris still answers questions months later; archive needs an order, deletion needs a better one.

## Session handoff checklist (copy into the next session's first message if compacted blind)
- [ ] Anchor path + HEAD commit + bundle SHA + suite count re-verified (POST_COMPACTION_PROMPT first action).
- [ ] Rig state known (DOWN now; up-command + 15min gate if takes are next).
- [ ] Sim-mutex clear (`pgrep -af run-connect-proof` empty).
- [ ] Key status known (quota history: 2h wall t105-t109, fresh key t110+, rotation open).
- [ ] Next take id assigned (t126 after t125) with its question named before firing.
- [ ] Watcher dispatched per take; verdicts rowed same turn.
- [ ] Firewall state known (OFF per operator order — re-enable after trusted work).
