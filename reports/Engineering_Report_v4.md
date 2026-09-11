# FORGE Ship Wave — ENGINEERING REPORT v4
**Series:** base tree (post-approval record: ship-docs refresh, checkpoint refresh, meta-analysis; parent/base series is Engineering_Report_v1.md)
**Project:** FORGE iOS opencode agent
**Date:** 2026-09-11
**Author:** MiMoCode Compose
**Baseline:** master @ 7e2a94d (anchor MIMOCODE/Forge)
**Commit:** 7e2a94d
**Container:** forge-vm · **Image:** macos-forge:master (6GB start-tahoe, Xcode 26.6, sim …8187)

## ONE-PARAGRAPH SUMMARY
Since the anchor migration (`git clone --local` @ ce9ff28 + rsync + bulk symlinks, 3.4G→17G as evidence accumulated) the ship loop closed SC-11 (migrate-guard fix, t80), paid-only lockdown (3 layers), T-9 (t98 deterministic + t121/t125 live-agent green), and soak (t100/t103), with every take rowed (t76-t125, zero gaps), suite 88/88, bundle `f06bda2b` sealed through `7e2a94d`, all 5 ship docs gated (165/51/120/52/55 + manifest), checkpoint `ship-wave-green-t125-20260911` refreshed in place (MODE B), and the approval take t125 (mux 386s/636kbps, watcher 2/2) earning the operator's first ship-ready verdict; remaining: device/TestFlight/phone, key rotation, disk.

## THE LIFECYCLE MAP
```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ migrate+W1-5 │─►│ audit F1-F6  │─►│ F5 appr t125 │
│ anchor green │  │ REFUTED→fix  │  │ mux gates OK │
└──────────────┘  └──────────────┘  └──────┬───────┘
                                           ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ device/TF    │◄─│ ship docs +  │◄─│ checkpoint   │
│ operator own │  │ seal 7e2a94d │  │ MODE-B fresh │
└──────────────┘  └──────────────┘  └──────────────┘
```

## THE ARCHITECTURE
### M1 — Agent runtime (`forge-bundle.js`, 2719L, `f06bda2b`)
Input → slash table → 12-iter LLM loop (chunked streaming, tool accumulation, file-fence) → TUI writes + done-check. Locks: paid-only allowlist (:1860), bytes marker (:1796), 90s race + 120s watchdog. No SSE (EventSource 0).
### M2 — Bridge
Keychain SecureField flow, `saveProviderConfig` hot-swap, `injectAPICredentials` merge (:381), Pyodide runPython with stdout capture, `ForgeCommandRunner` 532L.
### M3 — Preview
Isolated pool/store, always-mounted branches, AX container fix; agent-fired render proven t91/t125.
### M4 — Proof rig
Driver + 4 test classes + watcher protocol + sim-mutex + --no-uninstall tiers.
### M5 — Mode 2 Mission Control (carried)

## THE BUG LEDGER
| # | bug | root cause | fix | evidence |
|---|-----|------------|-----|----------|
| B1-B12 | (v3 ledger carries detail) | — | — | GAUNTLET F-rows |
| B13 | narration-vs-markers (t116) | prose matches bubble tokens | done-check signal, watcher verdict | process |
| B14 | recorder wedge (t119) | killed take orphaned sim lock | sim reboot remedy | process |
| B15 | model-skips-python (t92/93/112/115/122-124) | LLM nondeterminism on multi-file prompts | split-leg prompts, tight orders | t121/t125 green |
| B16 | cold-sim slowness (t119/120) | fresh-boot caches + strain | cools, connected-only takes | process |
Detail: B15 is behavior, not product — the loop answers with take volume + prompt surgery, never product churn.

## THE TESTING LEDGER
| test | scope | how | result |
|------|-------|-----|--------|
| pytest 88/88 | host | per-edit | standing green |
| t76-t103 | SC-11→soak | takes+watchers | rowed, greens noted |
| t104-t121 | F5 hunt | tight/connected takes | FAILs→t121 PASS (stdout ×3) |
| t122-t125 | approval battery | full flow+watcher | t125 PASS (stdout+preview, mux both gates) |
| dual verification | 13 frames | 2 blind agents | A 5/5, B 5/8 (3 explained) |
| audit + recount | claims | 2 fresh auditors | REFUTED-ship / VERIFIED-soak |
| ship-docs gate | 5 docs | line/evidence/SHA checks | 165/51/120/52/55 PASS |

## THE SPEC MANDATE → ENGINEERING MAP
| the operator said | what was built | evidence |
|---|---|---|
| migrate anchor, make authoritative | clone+rsync+symlinks, memory-recorded | anchor @7e2a94d |
| paid-only model | 3-layer allowlist + test | lockdown test |
| key hygiene | env-only, 0-hit checks | all run logs |
| pixels via watchers | 14 sessions, dual close | GAUNTLET |
| first ship-ready video | t125 seg-01.mp4 | 386s/636kbps |
| document the process | this report + memory entry | below/files |
| iPhone now, no App Store | sideload explainer | appendix below |
| cleanup waste | host /tmp only; debris protected | below |

## THE NUMBERS
```
┌────────────────────────┬──────────────────────────────┐
│ metric                 │ value (measured)             │
├────────────────────────┼──────────────────────────────┤
│ pytest                 │ 88 passed, 13 files          │
│ bundle SHA             │ f06bda2bfabeedd6 sealed      │
│ takes rowed            │ t76-t125, zero gaps          │
│ watcher sessions       │ 14 dispatched                │
│ anchor seal            │ 7e2a94d                      │
│ ship docs gates        │ 165/51/120/52/55 + manifest  │
│ checkpoint             │ 96M, MODE B refreshed        │
│ guest signing ids      │ 0 · profiles 0               │
│ disk                   │ 97%                          │
└────────────────────────┴──────────────────────────────┘
```

## THE FILE MANIFEST
```
MIMOCODE/Forge/ @7e2a94d (+SHIP_DOCS_MANIFEST.md)
├── iOS/ · forge/src+shims/ · tests/ · scripts/run-take.py
├── 5 ship docs + manifest · GAUNTLET · TESTING/FAILURE logs
├── docs/DPL1 + handovers + reports/v1-v4+audit
└── Checkpoints/ship-wave-green-t125-20260911/ (refreshed)
```

## WHAT'S NEEDED FROM THE OPERATOR
1. Sideload: signing identity + USB + smoke (explainer appendix).
2. TestFlight: Apple ID + Connect.
3. Key rotation, disk reclaim, Mode-A seal order.

## APPENDIX A — META-ANALYSIS (post-migration engineering process)
What actually completed the build after the migration, and why it worked:
1. **Authoritative anchor first.** One tree (`clone --local` + rsync + symlinked bulk) ended the LIVE-vs-workspace ambiguity; every SHA, take, and seal since refers to it. Cost noted honestly: 17G, disk 97%.
2. **Takes as the unit of truth.** 50 takes (t76-t125), each with prologue/build/run/stills/mux/log/row. No claim survived without a take; no take closed without a row (backfills marked).
3. **Watchers as the verdict layer.** 14 blind sessions; XCUITest drives and captures, pixels decide. Caught: echo-matched asserts, prose-vs-marker confusion, blank-on-revisit.
4. **Failure → mechanism → minimal fix → re-take.** 19 FAILURE_LOG entries; biggest wins: migrate guard (key exonerated by tripwires), watchdog (silence→named error), unmount fix (hide don't remove), sim-mutex (shared-sim trampling).
5. **Zero-trust audit before seal.** Two fresh auditors found 6 real items (rows, precision, leftovers, seal staleness); all fixed and re-sealed. The audit artifact is what makes v4's claims checkable.
6. **What didn't work:** long combined bash calls (timeout kills orphan locks), back-to-back takes without cools (snapshot/main-thread stalls), asserting on echoable tokens, symlinking tracked bulk.

## APPENDIX B — IPHONE SIDELOAD EXPLAINED (no App Store)
Why no store is needed: Apple allows installing your own builds directly via Xcode (free Apple ID, 7-day cert) or ad-hoc/enterprise distribution — the App Store is only required to distribute to OTHER people. For your own test phone: (1) add YOUR Apple ID to Xcode on the guest (Preferences → Accounts — only you can type it); (2) set the project's signing team to your Personal Team (bundle id stays com.forge.app); (3) I run `xcodebuild archive` + export an .ipa on the guest; (4) copy the .ipa off (scp :50922) to your Mac; (5) plug in the iPhone → Xcode Devices window → drag .ipa in (or Sideloadly/AltStore); (6) on iPhone trust the developer certificate (Settings → General → VPN & Device Management); (7) open FORGE, run the 10m smoke (connect + agent turn + preview + background + relaunch). Caveats: free-ID certs expire in 7 days (re-sign weekly); QEMU USB passthrough exists but is fragile — the .ipa-transfer path is the reliable one; the guest currently has 0 signing identities so step 1 gates everything. Say the word and I'll drive from step 3 the moment the Apple ID lands.
