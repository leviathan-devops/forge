# FORGE Ship Wave — ENGINEERING REPORT v3
**Series:** base tree (ship-wave lineage: W1 SC-11 → W5 soak → audit-fix → F5 approval; parent/base series is Engineering_Report_v1.md)
**Project:** FORGE iOS opencode agent
**Date:** 2026-09-11
**Author:** MiMoCode Compose
**Baseline:** master @ 353d0e1 (anchor) · origin lineage ce9ff28 → befa59d → bf26fcb → 5b2b5a3 → f79eb68 → 7fb2cdf → 353d0e1 → d9ab150
**Commit:** d9ab150
**Container:** forge-vm · **Image:** macos-forge:master (6GB start-tahoe guest, Xcode 26.6, sim iPhone 17 Pro …8187)

## ONE-PARAGRAPH SUMMARY
FORGE is an iOS-native (iOS 17+, Swift 5.9, XcodeGen+xcodebuild, esbuild IIFE bundle into a hidden WKWebView) opencode client with Mode 1 on-device agent TUI (SwiftTerm surface, Pyodide python, preview pane, Keychain auth) and Mode 2 Mission Control fleet view, and this v3 reports the completed ship wave on the authoritative anchor `Shared Workspace Context/MIMOCODE/Forge` (3.4→17G with evidence; live tree is reference): SC-11 auth+persistance closed by root-causing the second-call 401 to `migrateModelToLiveCatalog` (t80), paid-only model lockdown enforced at three layers, T-9 battery closed by composition of deterministic E2E (t98) and live-agent takes (t90/t91 legs, t121/t125 full green with watcher-verified stdout and preview render), W5 soak closed (t100/t103 background+tabs+relaunch survival), every take rowed append-only in GAUNTLET (t76-t125 + backfills), suite 88/88, bundle `f06bda2b` sealed, checkpoint `Checkpoints/ship-wave-green-t125-20260911/` (96M, MODE B) holding product+evidence, approval take t125 (mux 386s/636kbps both gates PASS) as the .mp4, with device/TestFlight/phone-smoke, key rotation, and disk reclaim remaining operator-owned.

## THE LIFECYCLE MAP
```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ W1 SC-11 t78 │─►│ W2/W3 stream │─►│ W4 T-9 batt  │
│ 401→t80 PASS │  │ tools+prev   │  │ t98 det PASS │
└──────────────┘  └──────────────┘  └──────┬───────┘
                                           ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ seal+report  │◄─│ audit F1-F6  │◄─│ W5 soak t100 │
│ d9ab150 + v3 │  │ REFUTED→fix  │  │ t103 5/6 pix │
└──────────────┘  └──────────────┘  └──────────────┘
```
Widest line 46 cols. Flow: auth → engine → battery → soak → audit-fix → seal.

## THE ARCHITECTURE
### M1 — JS agent runtime (`iOS/FORGE/Resources/forge-bundle.js`, 2719L, sha `f06bda2b`)
```
┌─────────────────────────┐
│ input → slash table     │
│ → runForgeAgent loop×12 │
│ → tools → TUI writes    │
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│ native bridge calls     │
│ http/keychain/fs/py     │
└─────────────────────────┘
```
Interfaces: `bootstrap()` (:26), slash dispatch `/connect` (:1854-1912), AGENT_TOOLS 7 verbs (:1481), `connectTestCall` (:1954), `runForgeAgent` (:1987). Flows: typed input → local slash table or 12-iteration LLM loop (streaming chunked-callback 66ms throttle, muse SSE normalizer, file-fence, tool accumulation) → terminal writes + chat bubbles + done-check. Failure modes: 401/timeout/retired/key-like/empty all refuse locally (CONNECT_SPEC); unknown slash never reaches LLM; 90s JS race + 120s native watchdog (double-settle safe) bound runPython. Constants: 12 iters, 66ms emit, 90s JS race, 120s native watchdog, 4000-char cap, mux gates 90s/400kbps. Anchors: bundle :1481/:1954/:1987/:2116.

### M2 — Swift bridge (credentials, Keychain, exec, Pyodide)
`ForgeBridge.getSecret/setSecret` (Keychain), `promptSecret` SecureField alert, `saveProviderConfig` (UserDefaults + hot-swap inject, paid-only refusal), `ForgeEngine.injectAPICredentials` (:381: merge UD+Keychain+env, esc, session/project/request ids), `runPython` (forgepy-scheme Pyodide 0.27.7, setStdout capture, stdout+repr delivery), `ForgeCommandRunner` 532L, `PyodideSchemeHandler` (forgepy scheme, wasm MIME). Failure: -34018 unsigned-era dissolved on ad-hoc; SecItemDelete+Add overwrite (no dupes).

### M3 — Auth persistence + lockdown
SecureField → Keychain `forge.apiKey` → re-inject hot-swap; provider/model/URL (+apiBaseUrl) in UserDefaults. Lockdown: bundle allowlist (:1860), bridge `allowedModelID` (`ZenModelCatalog.swift:16`), retired free-1.3 + deeps/1.2. migrate() early-returns on allowed id (`AppState.swift:289`).

### M4 — Preview (pane survives switches)
`PreviewPaneView` (isolated pool/store, bootstrap console capture) + toolbar + toggle + console drawer + `preview-bootstrap.js` 129L. Always-mounted branches (zero-height collapse) so tab switches keep content. Failure was unmount-destroy (fixed t101/t102).

### M5 — Proof rig (XCUITest + watcher + mux)
Drivers `tmp/run-connect-proof.py` (mirrored `scripts/run-take.py`): rsync, keyfile 0600, entitlements plist, uninstall (or --no-uninstall), recordVideo, build, test, fetch stills+mux, redact. Sim-mutex refuses concurrent drivers. Tests: ConnectProof (SC-11), Battery (full + standalone + connected), E2E (deterministic fixture), Soak (background/tabs/relaunch).

### M6 — Mode 2 Mission Control (carried, unexpanded this wave)
Session protocol tests green; UI navigable (D3-era PASS carries).

## THE BUG LEDGER
| # | bug | root cause | fix | evidence |
|---|-----|------------|-----|----------|
| B1 | 2nd-call 401 (t76/78) | migrate() replaced paid id with live.first | early-return allowedModelID AppState.swift:289 | t80 PASS 184s, 06 stills |
| B2 | silent python hang | hidden-WebView JS timers stall, rejects vanish | native 120s watchdog (double-settle) | t96 error card fired loud |
| B3 | preview blank revisit | tab switch unmounted WKWebView branch | always-mounted + collapse | t102 assert, t103 s4 pixels |
| B4 | suite 86/87 pollution | OPENCODE hardcode in protect-vm.sh | script-relative FORGE_DIR | 88/88 |
| B5 | AX-invisible surfaces | labels-vs-ids, canvas, webview leaf flag | label taps, retries, container flag | t96+ card asserts |
| B6 | fixture double-run | re-appear re-fired E2E | run-once static guard | t98 PASS 67s |
| B7 | cold-load hang | Pyodide first load stalls cold guest | watchdog names it; warm loads fine | t96 vs t94/t95/t98 |
| B8 | entry vs restoration race | relaunch lands in Mode 1, composer hidden | E2E card counts as entry proof | t100/t103 |
| B9 | concurrent-sim trampling | shared sim, no mutex (t104 home mid-take) | driver sim-mutex | process |
| B10 | 429 quota wall (~2h) | server-side key throttle (pool green) | backoff + fresh key | t110+ prologue 200s |
| B11 | narration-vs-markers | prose matches bubble tokens | done-check signal, watcher verdict | process (t116+) |
| B12 | recorder wedge | killed take orphaned sim lock | sim reboot remedy | process |
Detail boxes: B1 (same-binary 200→401 contrast decided systematic; length tripwires 67 chars exonerated Keychain); B2 (15 stdout bytes in 15s proved capture healthy once DIAG traced it); B3 (s0 rendered vs s4 blank isolated unmount, not render); B10 (host pool 585/0→585/576 while sim key 429 = key-scoped).

## THE TESTING LEDGER
| test | scope | how | result |
|------|-------|-----|--------|
| pytest 88/88 | host battery (13 files) | `pytest tests -q` per edit | 88 passed standing |
| node --check | bundle syntax | per edit | clean every wave |
| t76-t80 | SC-11 connect proof | XCUITest + watcher + ffprobe | FAIL,FAIL,FAIL(root found),PASS |
| t81-t89 | battery harness shakedown | iterative takes | FAILs→harness hardened |
| t90/t91 | live-agent legs | XCTest green + watcher | agent runs, stdout/preview partial |
| t92/t93 | marker take | backfilled rows | FAIL (model skipped python) |
| t94-t98 | deterministic E2E | fixture + watcher 3/3 | PASS t98 (67s) |
| t99-t103 | soak | background/tabs/relaunch + watchers | PASS t100/t103 (5/6, s5 by AX) |
| t104-t121 | F5 live stdout | tight/connected takes + watcher | PASS t121 (224s, stdout ×3) |
| t122-t125 | approval battery | full flow + watcher | PASS t125 (359s, stdout+preview, mux both gates) |
| dual verification | 13 frames, 2 blind agents | A 5/5 stills, B 5/8 timeline (3 protocol-explained) | PASS |
| zero-trust audit | claims vs evidence + derailments | 2 fresh auditors | REFUTED-as-ship / VERIFIED-through-soak |
| regression | per-fix suite + node | after every product edit | zero regressions (88 held) |

## THE SPEC MANDATE → ENGINEERING MAP
| the operator said | what was built | evidence |
|---|---|---|
| phone LAST, VM E2E first | 40+ takes before any device step | Evidence/play/cycle-forge-* |
| paid-only muse-1.3-contributor, no other models | 3-layer allowlist + retired free + test | 88/88 lockdown test |
| key out of chat/rows, env+file only | driver env→sftp 0600, scrub, 0-hit checks | 0 sk- hits every run log |
| prove on pixels via watchers | 13 watcher sessions, dual independent close | GAUNTLET watcher verdicts |
| audit-fix F1-F6 | rows backfilled, markers out, claims corrected, sealed | bf26fcb→d9ab150 |
| grandma-proof 100% | shell/auth/agent/preview proven; plain-words UX open | V-02 |
| load to iPhone now, no App Store | sideload guide (below, chat) — needs signing identity | operator step |
| cleanup waste | §Cleanup below; evidence retained per law | — |

## THE NUMBERS
```
┌────────────────────────┬──────────────────────────────┐
│ metric                 │ value (measured)             │
├────────────────────────┼──────────────────────────────┤
│ swift files/lines      │ 71 / 19677 (checkpoint: 104) │
│ pytest                 │ 88 passed, 13 files          │
│ bundle SHA             │ f06bda2bfabeedd6 sealed      │
│ session:chat emitters  │ 1 · EventSource 0            │
│ takes rowed            │ t76-t125 + backfills (no gap)│
│ approval take t125     │ 359s, mux 386s/636kbps PASS  │
│ watcher sessions       │ 13 dispatched, verdicts rowed│
│ anchor seal            │ d9ab150 (168+ files)         │
│ checkpoint             │ 96M, MODE B, manifest 42L    │
│ guest signing ids      │ 0 · profiles 0               │
│ disk                   │ 97% (anchor duplication ~9G) │
└────────────────────────┴──────────────────────────────┘
```
Widest line 60 cols.

## THE FILE MANIFEST
```
MIMOCODE/Forge/ (anchor, @d9ab150)
├── iOS/FORGE/App/ (MODIFIED AppState migrate guard)
├── iOS/FORGE/Bridge/ (MODIFIED ForgeBridge watchdog+SecureField; engine untouched)
├── iOS/FORGE/Core/ (MODIFIED ZenModelCatalog lockdown)
├── iOS/FORGE/Presentation/Mode1_BuildOnDevice/ (MODIFIED mount fix, AX fix)
├── iOS/FORGE/Resources/forge-bundle.js (MODIFIED lockdown+markers+prompt)
├── iOS/FORGE/UITests/ (NEW Battery/E2E/Soak tests)
├── forge/src+shims/ (EXISTING) · tests/ (MODIFIED lockdown+B4)
├── scripts/run-take.py (NEW mirror) + protect-vm.sh (MODIFIED)
├── docs/FORGE_SHIP_DPL1_SPEC.md (NEW) · handovers/GOAL_PIN_* (NEW)
├── reports/v1+v2+audit (NEW) · TESTING/FAILURE/BUILD/DEBUG/SPEC logs (NEW)
├── GAUNTLET_PROGRESS.md (MODIFIED append-only)
└── Checkpoints/ship-wave-green-t125-20260911/ (NEW 96M)
```

## WHAT'S NEEDED FROM THE OPERATOR
1. **Sideload (below):** signing identity + USB + 10m smoke — guest has 0 identities; unsigned ad-hoc is the current artifact.
2. **TestFlight:** Apple ID + App Store Connect; runbook docs/testflight-setup.md.
3. **Key rotation:** two chat copies exist; env-only held elsewhere.
4. **Disk:** 97% — approve archiving take debris (t60-t77 unrrowed bulk first).
5. **Mode-A seal:** operator chattr by order (agents cannot).
6. **GO t125 approval:** watch seg-01.mp4 in cycle-forge-t125 — green Hello + stdout verified by watcher; approve in chat.
