# FORGE Takeover SC-11 — ENGINEERING REPORT v2
**Series:** base tree (takeover SC-11 /connect wave; parent/base series is Engineering_Report_v1.md 2026-09-08)
**Project:** FORGE iOS opencode agent
**Date:** 2026-09-10
**Author:** MiMoCode Compose
**Baseline:** master @ ce9ff28 (Wave4-transport: muse serve-session branch)
**Commit:** ce9ff28 · live tree dirty (Bridge/*.swift, AppState, entitlements modified, untracked checkpoint dir)
**Container:** none · **Image:** n/a (host-measured; guest build claimed, log absent)

## ONE-PARAGRAPH SUMMARY
FORGE is an iOS-native (iOS 17+, Swift 5.9, XcodeGen+xcodebuild, esbuild IIFE bundle into hidden WKWebView) opencode client with Mode 1 on-device TUI and Mode 2 Mission Control fleet view, and this v2 report audits the outgoing takeover pack (`FORGE/handovers/FORGE_TAKEOVER_OUTGOING/`, 7 files on disk, zip 36553B unpacked 73160B — "11 files" = 6 files + 5 dir entries) plus the session checkpoint (`FORGE/Checkpoints/takeover-sc11-open-t76partial-20260910/`, 16MB, 155 files incl. 5 pyc, 71 Swift / 19677 lines) against the unbiased Aug-15 zero-trust baseline; the audit VERIFIES the pack's core honesty (bundle SHA `90279713d4d3a76a13a396246cd0a9eb5408c3a6e43e1d00dc4e53572a8d681f`, 114285B, 2717 lines, `node --check` clean, t76 rowed FAIL on a named provider 401 rather than hidden) while DOWNSCOPING three claims (pytest "76 green" is stale — live collects 87, runs 86 passed + 1 failed pollution test; guest TEST BUILD SUCCEEDED and live-200/Keychain legs ship no log/stills/mp4 inside the checkpoint; bundle is a REAL esbuild artifact but still phase1-stub runtime with 1 `session:chat` emitter, 0 SSE, /connect present), so the product stands at SC-11a/b PROVEN once, SC-11c PARTIAL, SC-12 OPEN, with the single P0 being a fresh Go key + rotation-gated t78 retest of the transient-vs-systematic 401.

## THE LIFECYCLE MAP
```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  P0 migrate  │─►│  P1 /connect │─►│  P2 t76 proof│
│ 13/13 ident  │  │ 5 surfaces   │  │ mux 447s FAIL│
└──────────────┘  └──────────────┘  └──────┬───────┘
                                           ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  P5 SC-12    │◄─│  P4 t78      │◄─│  P3 key rot  │
│  soak open   │  │  staged open │  │  BURNED wait │
└──────────────┘  └──────────────┘  └──────────────┘
```
Ruler: widest line 46 cols. Flow: migrate → build → proof(FAIL rowed) → rotate → retest → soak. Center arrows align under box midpoints.

## THE ARCHITECTURE
### M1 — JS runtime bundle (Mode 1 TUI surface)
```
┌─────────────────────────┐
│ forge-bundle.js 2717L   │
│ /connect + phase1-stub  │
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│ ForgeEngine WKWebView   │
│ injectAPICredentials    │
└─────────────────────────┘
```
Interfaces: `bootstrap()` (`forge/src/forge-entry.ts:26` live-tree equivalent), slash dispatch `/connect provider|model|url|key|test|status` (`forge-bundle.js:1854-1912` checkpoint copy), `window.__forgeConfig` merge target. Data flow: typed input → `inputHandler` → `/`-intercept → local `/connect` table or `processWithAgent` → stub `process()` → `fetch POST <base>/responses + Authorization: Bearer` (`:1960-1974`) → terminal write. Failure modes: no key → `FAIL: no API key` (`:1956`); 401 → local FAIL text + re-key hint, config preserved; unknown slash → local error, NEVER the LLM (CONNECT_SPEC.md:14). Anchors: `src/iOS/FORGE/Resources/forge-bundle.js:1825-1912` (/connect block), `:1345/:1353` stub ctor, `:1430` config, `:1509` single `session:chat` fire-and-forget. Constants: mux GATE A duration ≥90s / bitrate ≥400kbps (HONEST_WATCH.md:26).

### M2 — Swift bridge (credentials + Keychain)
Interfaces: `ForgeBridge.getSecret/setSecret` (Keychain-backed), `ForgeEngine.injectAPICredentials` (UserDefaults provider/model + Keychain key + launch-env overrides merge), `promptSecret` native SecureField (new this wave). Flow: `/connect key` → SecureField → Keychain `ForgeSettingsKeys.apiKey` → re-inject → hot-swap `__forgeConfig` (CONNECT_SPEC.md:16). Failure: `-34018` was UNSIGNED-build artifact, dissolved on ad-hoc (TAKEOVER_MANIFEST.md:132-140); key-like slash arg refused, never stored/echoed (CONNECT_SPEC.md:24). Anchors: TAKEOVER_DUMP.md:610-618 (bridge/engine/AppState/Settings/entitlements lines).

### M3 — Settings UI + persistence
`SettingsSheet.apiConfigurationSection` + base-URL TextField via existing `saveSettings()`; provider/model/URL → UserDefaults (+ new `apiBaseUrl`), key → Keychain. t76 proved: 3 field saves + KEY_SAVED + status-configured-after-relaunch (read leg); live USE of persisted state unproven → SC-11c PARTIAL (HONEST_WATCH.md:68-72).

### M4 — Proof rig (XCUITest + watcher + mux)
Driver `t76` (407s, 2026-09-09 17:05:42–17:12:29 guest, 4GB hw.memsize 4294967296 — 6GB revert came after), in-test stills 01-05 (XCUIScreen PNGs, NOT mux) + tail frames z422/z435/z444 (ffmpeg from muxed mp4, t=422/435/444 of 447.67s), ffprobe gates duration 447.670 / bitrate 461973 PASS, watcher ProofReader 2 rounds text-only, main never opened pixels (HONEST_WATCH.md:9-27). Failure preserved: FAILED line 147 second-PASS assert, 150s budget vs 401 (HONEST_WATCH.md:61).

### M5 — Mode 2 Mission Control (unchanged this wave)
Remote fleet view; no new claims in pack; Aug-15 grade A- carries, unverified this turn.

## THE BUG LEDGER
| # | bug | root cause | fix | evidence |
|---|-----|------------|-----|----------|
| B1 | 2nd live call 401 (t76 FAIL) | OPEN: transient provider refusal vs systematic stale/mangled Keychain read or session-header binding | t78 same-binary contrast retest (rotation-gated) | HONEST_WATCH.md:52-55,87-89; CHECKPOINT_MANIFEST.md:5-8 |
| B2 | "11 files" count | zip dir entries counted as files (6 files + 5 dirs) | report 7 files on disk (incl README.txt) | `find handovers/FORGE_TAKEOVER_OUTGOING -type f` → 7 paths; `unzip -l` 73160B |
| B3 | BINDING.md rig § stale 4GB | trial-era text, superseded by 6GB revert | dump/manifest override (TAHOE_BOOT_OK) | TAKEOVER_DUMP.md:105-106; TAKEOVER_MANIFEST.md:114-119 |
| B4 | live suite 86/87, 1 FAIL | `test_pollution_scrub_residuals`: OPENCODE hardcode in scripts/protect-vm.sh | scrub or allowlist the protector script | `pytest tests -q` → `1 failed, 86 passed` |
| B5 | checkpoint 151 vs 155 files | manifest excludes __pycache__ (5 pyc) + top-md method diff | method difference, not a lie | `find -type f` ext histogram; `du -sh` 16M |
| B6 | -34018 Keychain (historic) | UNSIGNED entitlement-less build | dissolved on ad-hoc; t76 stills 04/05 | TAKEOVER_MANIFEST.md:132-140 |
| B7 | XCTest key-echo breach (historic) | `Type … into SecureField` echoed key, 18 files | scrubbed to zero, key BURNED 2026-09-10 | TAKEOVER_MANIFEST.md:95-110 |
| B8 (Aug15 F1, evolved) | stub-vs-real bundle | Jul-29 stub-era `forge/src` overwrote Resources | bundle now REAL esbuild w/ /connect, but runtime still phase1-stub, 0 SSE | `grep -c session:chat`=1 (`:1509`); stub hits=4; `EventSource`=0 |

Detail B1: same binary, first call 200 (`muse-spark-1.3-contributor`, `https://opencode.ai/zen/go/v1`, zero launch-env overrides, keyfile `/tmp/connect-proof-env.json` 0600) then 200→401 minutes apart post-relaunch (HONEST_WATCH.md:39-55). No product change made; t78 decides (GOAL_PIN_SC12_T78.md:13). Detail B8: Aug-15 SHA `48fc7962` (2077L, SSE streaming) → now `90279713` (2717L, `/connect` + Bearer + `/responses` builder, no streaming). Progress on auth surface, regression-neutral on streaming: phase1 label intact (`:1214`).

## THE TESTING LEDGER
| test | scope | how | result |
|------|-------|-----|--------|
| pytest connect pair | `test_mode1_connect.py + test_mode1_connect_swift.py` | `pytest -q` host | 9 passed (measured this turn) |
| pytest full suite | `tests/` live tree | `pytest -q` host | 86 passed, 1 failed (B4) — CLAIM "76 green" STALE (87 collected vs 76 claimed) |
| pytest claimed 76 | checkpoint tree | NOT in checkpoint (no log ships) | CLAIM ONLY — manifest L11-12 rows it, artifact absent (manifest honestly flags gaps L28-47) |
| node --check bundle | checkpoint + live `forge-bundle.js` | `node --check` | CLEAN both (measured) |
| t76 XCUITest proof | guest sim …8187, ad-hoc build | XCUITest driver + watcher + ffprobe | FAIL rowed (named 401): stills 01-05 PASS legs, tail 401 leg FAIL; mux 447.670s/461973bps PASS |
| guest TEST BUILD | 6GB start-tahoe | xcodebuild (claimed) | CLAIM ONLY — no log ships in checkpoint |
| hygiene sweep | secrets/paths | grep contract §12 | 0 hits claimed post-scrub; live B4 shows 1 residual path string |
| tsc | n/a | no TS in tree | NOT APPLICABLE (verified: 0 `.ts`) |
| regression | Aug15→now | F1–F4 re-check | F1 evolved (stub→/connect-real, still no SSE); F2 open (engine still blob-only + untracked checkpoint); F3 unrerun; F4 CLOSED for /connect (XCUITest path proven usable, VNC-dead doctrine) |

Adversarial coverage: known-bad table (401/timeout/retired-id/key-like/empty-key) in CONNECT_SPEC.md:21-26; systematic-401 branch planned t78; soak/environ (disk 98-99%, mem ~1G, SSH 255 at pack time) recorded not hidden (NEUTRAL_AUDIT:82-90).

## THE SPEC MANDATE → ENGINEERING MAP
| the operator said | what was built | evidence |
|---|---|---|
| phone LAST; VM E2E first | t76 full-flow proof attempt before any device step | HONEST_WATCH.md full take; recovery plan P0-P4 order kept |
| /connect in-TUI auth, SecureField only | slash table + SecureField + Keychain + UserDefaults + hot-swap | CONNECT_SPEC.md:14-18; bundle :1854-1912 |
| key burned → rotate, never persist | key absent from pack + checkpoint; scheduler re-pin pending | README.txt:26-30; MANIFEST L43-44; SHORT_INJECT.txt:11-13 |
| 6GB revert (4GB trial superseded) | TAHOE_BOOT_OK + TEST BUILD on 6GB; BINDING 4GB text dead | TAKEOVER_MANIFEST.md:114-119; TAKEOVER_DUMP.md:71-77,105-106 |
| VNC typing DEAD → XCUITest-only; no monitor-quit | R8/R9 rulings; t76 XCUITest path | TAKEOVER_DUMP.md:114-119; HONEST_WATCH.md method |
| builder-under-audit, rows not hidden | t76 FAIL rowed 67; honest-gaps §§; breach self-reported | GAUNTLET ledger; CHECKPOINT_MANIFEST.md:28-47 |
| append-only takes, t78 next | t23-59 closed, t76 rowed, t77 unrrowed, t78 staged + proof driver | TAKEOVER_DUMP.md:47-49,566-591,622 |
| SC-12-only stop | SC-11 a/b proven, c partial, SC-12 open; soak gates set | TAKEOVER_DUMP.md:37-38,377-416 |

## THE NUMBERS
```
┌────────────────────────┬──────────────────────────────┐
│ metric                 │ value (measured)             │
├────────────────────────┼──────────────────────────────┤
│ handover files         │ 7 on disk; zip 36553B/73160B │
│ checkpoint size        │ 16M (du -sh)                 │
│ checkpoint files       │ 155 (71 swift,27 sh,19 py)   │
│ swift lines (cp)       │ 19677 (wc -l)                │
│ bundle SHA             │ 90279713…81f exact both trees│
│ bundle bytes/lines     │ 114285 B / 2717 L            │
│ node --check           │ CLEAN (both)                 │
│ session:chat emitters  │ 1 (:1509)                    │
│ stub markers           │ 4 hits                       │
│ SSE/EventSource        │ 0                            │
│ pytest live            │ 87 collected; 86 pass 1 fail │
│ pytest connect pair    │ 9 passed                     │
│ mux duration/bitrate   │ 447.670s / 461973bps PASS    │
│ baseline commit        │ ce9ff28 (+111 ahead, dirty)  │
│ prior report series    │ reports/Engineering_Report_v1│
└────────────────────────┴──────────────────────────────┘
```
Width check: longest line 60 cols.

## THE FILE MANIFEST
```
FORGE/
├── handovers/FORGE_TAKEOVER_OUTGOING/   # EXISTING pack (audit target)
│   ├── README.txt                       # EXISTING paste-order + keyless law
│   ├── 00_DUMP/SHORT_INJECT.txt         # EXISTING one-pager claims
│   ├── 00_DUMP/TAKEOVER_DUMP.md (622L)  # EXISTING root authority post-BINDING
│   ├── 01_LAW_AND_PLAN/BINDING.md (88L) # EXISTING law (4GB text stale→B3)
│   ├── 01_LAW_AND_PLAN/GOAL_PIN_SC12_T78.md # EXISTING t78 loop
│   ├── 02_AUDIT_AND_RECORD/NEUTRAL_AUDIT_GROK_VS_WORKSPACE.md # EXISTING
│   ├── 02_AUDIT_AND_RECORD/TAKEOVER_MANIFEST.md (177L) # EXISTING
│   └── FORGE_TAKEOVER_OUTGOING.zip      # EXISTING 36553B mirror
├── Checkpoints/takeover-sc11-open-t76partial-20260910/ # EXISTING untracked
│   ├── CHECKPOINT_MANIFEST.md (53L)     # EXISTING pointer doc, gaps honest
│   ├── CONNECT_SPEC.md (32L)            # EXISTING /connect authority
│   ├── HONEST_WATCH.md (89L)            # EXISTING t76 verdict FAIL
│   ├── GAUNTLET_PROGRESS_SNAPSHOT.md    # EXISTING 67-row ledger copy
│   └── src/{iOS,tests,scripts,docker}   # EXISTING rebuild base (no .git)
├── iOS/FORGE/Resources/forge-bundle.js # MODIFIED (90279713 live = cp)
├── tests/ (13 files, 87 collected)      # MODIFIED (+connect suites)
└── reports/Engineering_Report_v2.md     # NEW (this file)
```

## WHAT'S NEEDED FROM THE OPERATOR
1. P0 FRESH GO KEY: mint new OpenCode Go key (t63-burned key dead 2026-09-10), deliver guest-file only (`/tmp/connect-proof-env.json` 0600), re-pin scheduler; NEVER paste into chat/rows (README.txt:26-30; GOAL_PIN:10).
2. GO t78: rotation-gated systematic-401 branch (same-binary 200→401 contrast decides transient vs Keychain-read/session-header cause; no product change until verdict).
3. GO T-9 battery + SC-12 soak after t78 green (3-0/3-0 + video PASS + PLAYED/VIDEO_WATCHED rows per dump §9.3-9.4).
4. P0 BLOCKER WATCH: rig mem ≥6GB + uptime ≥15min gates, disk pressure (was 98-99%), SSH 50922 reachability; reboot-drift gate per manifest §12.
5. DECISION: accept checkpoint stays MODE B mutable untracked vs commit snapshot (restore-by-copy works, restore-by-hash does not — `git ls-files` = 0).
6. DECISION: B4 disposition — allowlist `scripts/protect-vm.sh` OPENCODE path string or scrub it (blocks 87/87 green claim).
7. DECISION: streaming roadmap — /connect-real-but-stub runtime (0 SSE) accepted as SC-11 scope, or schedule SSE restoration toward Aug-15 `48fc7962` parity.
