# CHECKPOINT MANIFEST — ship-wave-green-t125-20260911
- Date: 2026-09-11. Token has no spaces (hyphens only).
- State: SHIP-WAVE GREEN — SC-11 + T-9 deterministic + F5 live-agent stdout + soak, all watcher-verified. Approval take t125 (mux both gates pass).
- Anchor commit: d9ab150 (t125 approval take green). Baseline lineage: ce9ff28 → befa59d → bf26fcb → 5b2b5a3 → f79eb68 → 7fb2cdf → 353d0e1 → d9ab150.
- Bundle SHA (deployable artifact id): f06bda2bfabeedd6 (bundle-forge.js, node --check clean, session:chat=1, EventSource=0). Verified equal to anchor worktree.
- Battery: pytest 88 passed (13 files). Guest: TEST BUILD SUCCEEDED every take (Xcode 26.6 ad-hoc, sim iPhone 17 Pro …8187).
- Approval evidence: Evidence/cycle-forge-t125/ (p0 stdout 42/DONE + p1 green preview, watcher 2/2 PASS, seg-01.mp4 386s/636kbps both gates PASS).
- Supporting takes: t80 (SC-11), t98 (deterministic E2E), t100/t103 (soak), t121 (F5 first green).

## Contents (verified counts)
- src/: iOS/ (71 Swift) + forge/ (src+shims+docs, tmp/node_modules EXCLUDED as debris) + tests/ (13 py) + scripts/ + docker/ + docs/ + handovers/ + reports/ = 104 Swift / 27 py. Total 96M with Evidence.
- bundle-forge.js + bundle-forge.sha256: the deployable artifact + fingerprint.
- context_management/: 16 canon docs (CONTEXT_MANAGEMENT copy).
- Ship docs (all 5): BUILD_REPORT, DEBUG_LOG, FAILURE_LOG, SPEC_VIOLATION_LOG, TESTING_LOG.
- GAUNTLET_PROGRESS.md: append-only rows t76-t125 + backfills.
- project.yml + Package.swift: build roots.

## Honest gaps (what is NOT verified in this checkpoint)
1. No dist/ — iOS app ships via guest xcodebuild, recorded ABSENT by design; rebuild = rsync + xcodegen + xcodebuild on forge-vm.
2. Live single-tape battery beyond t125: model nondeterminism means future takes may need retries (t92/t93/t112 pattern).
3. SSE token-streaming absent (chunked-callback proven); SC-c gate unmet.
4. Plain-words UX: no grandma-path tape.
5. Soak RSS numeric half: trend only, no diagnose bundle.
6. Device/TestFlight/phone smoke: operator-owned (0 guest identities/profiles).
7. Key rotation: two chat copies exist; env-only discipline held elsewhere.
8. Disk 99%: anchor duplication cost noted; take debris unrrowed pre-t76 retained in live tree.
9. Mux bitrate gates fail on static takes by nature; stills + AX asserts carry those takes.

## Seal mode
MODE B — NO LOCK (mutable working snapshot; operator owns the guardian layer and did not lock). Manifest documents living state. Re-seal to Mode A only on operator order with chattr by the operator.

## Per-dir contents
- src/iOS/FORGE/App/: FORGEApp.swift + AppState.swift (migrate guard AppState.swift:289).
- src/iOS/FORGE/Bridge/: ForgeEngine + ForgeBridge (watchdog, SecureField, Keychain) + ForgeCommandRunner + PyodideSchemeHandler + MissionControlClient.
- src/iOS/FORGE/Presentation/Mode1_BuildOnDevice/: screen (mount fix), PreviewPaneView (AX container fix), toolbar, toggle, console drawer, gestures.
- src/iOS/FORGE/UITests/: ConnectProof + Battery (standalone/connected) + E2E + Soak tests.
- src/forge/: TS entry/runtime/terminal-surface + 13 shims + vendor types.
- reports/: Engineering_Report_v1/v2 + ZeroTrustAudit_2026-09-11.
- docs/: DPL1 ship spec (400L) + engineering spec + preview spec + runbooks.

## Next work
Operator handoffs only: signing identity + Apple ID + USB + 10m smoke → TestFlight; key rotation; disk reclaim. Then Mode-A seal by operator order.

## Refresh log (MODE B mutable)
- 2026-09-11: ship docs refreshed in place (t125 row, approval milestone + verbatim operator verdict, SHIP_DOCS_MANIFEST created); anchor commit 7e2a94d. Operator verdict: first genuinely ship-ready evidence video seen. No product change in this refresh.
- 2026-09-11 (T11): canon refreshed in place (RUNNING logs + manifest new; 6 docs rewritten to anchor truth, gates green); ship docs re-copied; anchor a40989a line. No product change in this refresh.
