# FORGE Ship Wave — ENGINEERING REPORT v5
**Series:** base tree (post-migration diff + meta-analysis + docs-current record; parent/base series is Engineering_Report_v1.md)
**Project:** FORGE iOS opencode agent
**Date:** 2026-09-11
**Author:** MiMoCode Compose
**Baseline:** master @ a40989a (anchor MIMOCODE/Forge; migration base ce9ff28)
**Commit:** a40989a
**Container:** forge-vm · **Image:** macos-forge:master (DOWN now; volume persists; restart ~15min)

## ONE-PARAGRAPH SUMMARY
Since the anchor migration the tree moved 14 commits and 199 files (+40849/-335) from the Wave4 baseline ce9ff28: SC-11 closed by the migrate guard (t80), paid-only lockdown at three layers, the agent loop proven end to end on pixels (t98 deterministic, t121/t125 live stdout + preview render with dual-watcher verdicts), soak closed (t100/t103 + numerics), the audit-refuted items fixed and re-sealed, the Air continuity branch pushed and API-verified, the unsigned ARM64 device build green, and in this pass all 5 ship docs gated (165/51/120/52/55 + manifest) plus 9 canon docs brought to floor (200+) with RUNNING logs + manifest newly created — while device signing, TestFlight, phone smoke, key rotation, and disk reclaim remain operator-owned.

## THE LIFECYCLE MAP
```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ migrate 3.4G │─►│ takes t76→   │─►│ audit+fixes  │
│ anchor truth │  │ t125 green   │  │ sealed chain │
└──────────────┘  └──────────────┘  └──────┬───────┘
                                           ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ device/TF    │◄─│ docs current │◄─│ air-drop Air │
│ operator own │  │ gates green  │  │ pushed+verif │
└──────────────┘  └──────────────┘  └──────────────┘
```

## THE ARCHITECTURE
### M1 — Agent runtime (bundle `f06bda2b`, 2719L)
Typed input → slash table (never LLM for secrets) → 12-iter LLM loop (chunked streaming, tool accumulation, file-fence) → TUI writes + done-check. Locks: paid allowlist (:1860), bytes marker (:1796), 90s race + 120s watchdog. session:chat 1, EventSource 0.
### M2 — Bridge
Keychain SecureField flow, `saveProviderConfig` hot-swap + paid refusal, inject merge (`ForgeEngine.swift:381`), Pyodide runPython + stdout capture, 532L command runner, forgepy scheme handler.
### M3 — Auth + lockdown
SecureField → Keychain → hot-swap; UD provider/model/URL; catalog `allowedModelID` (`ZenModelCatalog.swift:16`); retired free-1.3; migrate guard (`AppState.swift:289`).
### M4 — Preview
Isolated pool/store, always-mounted branches, AX container fix; agent-fired render proven t91/t125.
### M5 — Proof rig
Parameterized driver (take/test/stilldir/--no-uninstall) + 4 test classes + watcher protocol + sim-mutex + stable-retry helpers.
### M6 — Mode 2 (carried, session protocol green)

## THE BUG LEDGER
| # | bug | root cause | fix | evidence |
|---|-----|------------|-----|----------|
| B1-B12 | (v3/v4 carry detail) | — | — | GAUNTLET F-rows |
| B13-B16 | narration/markers, wedge, skips, cold slowness | (v4 carries detail) | done-check, reboot, split prompts, cools | takes t112-t120 |
| B17 | master push dies (3.5GB pack) | videos+tarballs in history | orphan air-drop branch | API-verified e7a3071 |
| B18 | secrets committed (Apple pw, PAT) | prior sessions wrote live secrets | redacted pre-push; rotate open | ancestry proves unpushed |
| B19 | VNC dead-ends | socat half-chain; white VGA; headless screencapture fails | monitor socket screendump proven | monitor-shot.png read |
Detail: B17/B18 found by reading FULL remote output (tail cut GH013 twice); B19 resolved to monitor channel, VNC abandoned honestly.

## THE TESTING LEDGER
| test | scope | how | result |
|------|-------|-----|--------|
| pytest 88/88 | host 13 files | per-edit re-runs | standing green |
| node --check | bundle | per-edit | clean |
| t76-t125 takes | full arc | XCUITest+watcher+ffprobe | rowed, greens as noted |
| dual verification | 13 frames | 2 blind agents | A 5/5, B 5/8 (3 explained) |
| audit + recount | claims | 2 fresh auditors | REFUTED-ship / VERIFIED-soak |
| sideload spike | device-arch compile | xcodebuild iphoneos unsigned | SUCCEEDED (22MB ARM64) |
| ship-docs gate | 5 docs | line/evidence checks | 165/51/120/52/55 PASS |
| canon gate | 9 docs + manifest | 200-floor + refs + SHAs | all green (RUNNING logs carry entries) |
| regression | per-fix | suite+node | zero regressions |

## THE SPEC MANDATE → ENGINEERING MAP
| the operator said | what was built | evidence |
|---|---|---|
| migrate anchor, authoritative | clone+rsync+symlinks, memory-recorded | @a40989a line |
| document post-migration changes | this report §diff below + memory entry | file |
| meta-analyze the process | Appendix A (what worked/why) | file |
| explain sideload | Appendix B (no-App-Store path) | file |
| update ship+canon docs | 5 ship gated + 9 canon floored + manifest | gate outputs |
| save checkpoint | refreshed MODE B + manifest note | Checkpoints/ |
| cleanup waste | host /tmp only; debris protected | below |

## THE NUMBERS
```
┌────────────────────────┬──────────────────────────────┐
│ metric                 │ value (measured)             │
├────────────────────────┼──────────────────────────────┤
│ migration diff         │ 14 commits, 199 files +40849 │
│ pytest                 │ 88 passed, 13 files          │
│ bundle SHA             │ f06bda2bfabeedd6 sealed      │
│ takes rowed            │ t76-t125, zero gaps          │
│ watcher sessions       │ 14 dispatched                │
│ anchor seal            │ a40989a                      │
│ ship docs gates        │ 165/51/120/52/55 + manifest  │
│ canon gate             │ 9×200+ + manifest + 2 logs   │
│ checkpoint             │ 96M, MODE B refreshed        │
│ device artifact        │ 22MB ARM64 unsigned green    │
│ guest signing ids      │ 0 · profiles 0               │
│ disk                   │ 97%                          │
└────────────────────────┴──────────────────────────────┘
```

## THE FILE MANIFEST
```
MIMOCODE/Forge/ @a40989a (+SHIP_DOCS_MANIFEST.md)
├── iOS/ · forge/src+shims/ · tests/ · scripts/run-take.py
├── CONTEXT_MANAGEMENT/ (9 floored + manifest + logs + legacy)
├── 5 ship docs + manifest · GAUNTLET · TESTING/FAILURE logs
├── docs/DPL1 + handovers + reports/v1-v5+audit
├── AGENT_MACBOOK_AIR.md · air-drop e7a3071 (GitHub)
└── Checkpoints/ship-wave-green-t125-20260911/ (refreshed)
```

## WHAT'S NEEDED FROM THE OPERATOR
1. Sideload: Appendix B — Apple ID + USB + smoke (guest has 0 identities).
2. TestFlight: Apple ID + Connect.
3. Key rotation, disk reclaim, Mode-A seal order.

## APPENDIX A — POST-MIGRATION DIFF (what changed since the anchor was cut)
Versus ce9ff28 (14 commits): product fixes (migrate guard, lockdown 3 layers, watchdog, mount fix, AX fixes, tripwires, markers, preview prompt docs); harness (4 test classes, driver parameterization, sim-mutex, --no-uninstall, stable helpers, done-check signal); suite (B4 scrub, lockdown test, 88 total); docs (DPL1, 5 ship docs + manifest, canon refresh, GAUNTLET t76-t125, reports v1-v5, audit, pins, handoff contract); infra (air-drop branch, unsigned device build proof). Unchanged: engine core, WKWebView config, entitlements, Keychain schema, Mode 2, bundle id, SwiftTerm pin.

## APPENDIX B — META-ANALYSIS (why this loop completed where others stall)
1. **One anchor.** Every hash, take, and seal refers to one tree. Ambiguity kills more builds than bugs.
2. **Takes, not tasks, are the unit of truth.** 50 takes × (prologue/build/run/stills/mux/log/row). Claims without take ids are opinions.
3. **Pixels decide.** 14 blind watcher sessions; the loop's three biggest saves (echo-asserts, prose-markers, blank-revisit) all came from stills contradicting green tests.
4. **Mechanism before remedy.** Tripwires (length markers), DIAG traces, and sim-log reads named causes (migrate, timers, unmount) before code moved — fixes landed once, not iteratively.
5. **Environment adjudicated separately.** Quota walls, sick snapshots, cold guests, concurrent sessions each got their own detector (probe, load check, mutex) instead of being debugged as product.
6. **Audits with teeth.** Two fresh agents, recounts from disk, fraud catalog — found 6 real items including the author's own soft claims.
7. **What didn't work:** mega-bash calls (timeout orphans), back-to-back takes (strain), echoable asserts, tracked-bulk symlinks, blind pushes (measure pack first).

## APPENDIX C — SIDELOAD EXPLAINED (no App Store, immediate test path)
Apple lets you install your own builds directly — the store is only for distribution to others. Chain: SIGN → TRANSFER → TRUST → RUN. (1) **Sign:** Apple ID into guest Xcode (your screen only) → Personal Team → bundle stays com.forge.app. Without this there is no installable artifact — the guest holds 0 identities today, which is the single gate. (2) **Build:** I run `xcodebuild archive` + export `.ipa` on the guest (unsigned ARM64 already proven green, so this step is mechanical once signing exists). (3) **Transfer:** `scp -P 50922` off the guest to your Mac (QEMU USB passthrough exists but is fragile — transfer wins). (4) **Install:** Xcode Devices drag / Sideloadly / AltStore onto the plugged iPhone. (5) **Trust:** Settings → General → VPN & Device Management → trust Apple ID. (6) **Run:** 10m smoke (connect, agent turn, preview, background, relaunch). Free-tier certs last 7 days (re-sign weekly); TestFlight needs paid membership. Ping me when the Apple ID lands and steps 2-4 are mine.
