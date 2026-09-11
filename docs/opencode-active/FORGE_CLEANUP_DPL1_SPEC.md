# BUILD SPEC ARTIFACT — FORGE V1 Cleanup (Preview / List / Swipe Closure)

- Target: `/home/leviathan/OPENCODE_WORKSPACE/FORGE` (canonical record:
  `Shared Workspace Context/Trident_Agent/Active_Projects/FORGE/docs/`)
- Generated: 2026-08-30 · Trident Version: v4.4.2+ · Status: PLANNING
- Artifact Type: BUILD_SPEC (Layer 1 Prompt — skill-authored DPL1)
- Discovery: ENABLED (6 Swift files, 3,729 lines measured; bundle 84,879 bytes;
  3 commits; 12 evidence videos inventoried)

## Discovered Intelligence block

- Languages: Swift 5 (SwiftUI, WebKit, os.Logger), JavaScript (esbuild IIFE bundle,
  WKWebView-embedded engine template), shell (VM record scripts).
- Entry Points: `FORGEApp.swift` → `AppState.swift:318` FULL_E2E chain →
  `BuildOnDeviceScreen.swift:171` preview trigger → `ForgeEngine` (WKWebView) →
  `runForgeAgent` (`forge-bundle.js:1485`) → `__forgeStreamChunk` (`:1626`) →
  `ChatModel.swift:599` lane router → `MissionControlScreen.swift:243` MC hooks.
- Patterns: lane-routed chat deltas (AP1/AP4 clean), completion-driven E2E chain
  (post-F1 fix), surgical-bundle-patch discipline (F1 guard honored).
- Failures (measured): F1 preview black 900×600 (`p0170/p0190`); F2 `GET /session`
  `-1001` at 20s cold; F3 deck unseen in 335 PNGs; F4 brace regression (fixed `da6b2a7`).
- Decisions (locked): free-zen-only `public` sentinel; muse default;
  `max_output_tokens 16384` (zen cap, §4); `192.168.100.7:8090` host LAN.
- Warheads active: VIL Laws 1–3, STTGF claim gate, red-team-by-default, anti-cuck
  expand-reflex, verification-before-declaration.
- Audit Layers: R0 spec-partial, R2 bundle-pass, R5 UI-partial, R7 net-partial,
  R10 build-pass, R12 test-fail (see §6 rows 5–7).

## §1 Problem Statement

FROM the operator (verbatim): "clean all of this up and make sure you are able to
generate, AND VISUALLY VERIFY VIA DIRECT WATCH, that every single item in the spec
works properly and has been documented on video with 0 cheats or hacks."
The on-device agent streams and writes (proven) but its two proof surfaces — the
playable Preview sheet and the populated Mission Control list — never appear on one
tape. Three named deltas block ship: (1) preview centre flat black where neon canvas
belongs; (2) `Connecting… / No sessions yet` where 11 titles belong; (3) no swipe-deck
card where `1/3→3/3` belongs. All three root fixes are committed and build-green;
none has its proof tape yet. First principles: a fix without its pixels is a claim,
and claims are rejected — the work is 50% re-tape, 0% new engineering, plus the
mechanical gates that make the re-tape decisive.

## §2 Architecture

Hidden WKWebView + `forge-bundle.js` (Trident-forged engine template: `runForgeAgent`
12-iteration tool loop, `httpRequestStream` native streaming, `AGENT_TOOLS`
write_file/run_command, muse `/responses` branch + `museSseToChat` SSE translator,
plain-user-message tool round-trip) → `ForgeEngine`/`ForgeBridge` (Swift) →
`.forgeChatMessage` → `LaneRouter` → `ChatStore` (delta-merge, AP1/AP4) →
`.forgeTurnComplete` → `BuildOnDeviceScreen` preview sheet (`ProjectPreviewSheet` →
`PreviewWebViewCore.loadFileURL`) and `AppState` post-turn chain (menu → MC).
MC side: `ConnectionManager` (`GET /session`, stable merge) → pager / Eagle grid /
tinder deck. Test hooks are env-driven (`SIMCTL_CHILD_*`), production paths untouched.

## §3 Discovery Intelligence (measured, 2026-08-30)

| File | Lines | Role |
|---|---|---|
| `Presentation/Shared/ChatModel.swift` | 664 | lane router + turn-complete signal (`:599-618`) |
| `Presentation/Mode1_BuildOnDevice/BuildOnDeviceScreen.swift` | 916 | Mode1 container + preview trigger (`:171-186`) |
| `Presentation/Shared/ProjectPreviewSheet.swift` | 176 | WKWebView sheet + file guard (`:49`) |
| `Presentation/Mode2_MissionControl/MissionControlScreen.swift` | 919 | pager/Eagle/deck + hooks (`:243-387`) |
| `Bridge/ConnectionManager.swift` | 416 | session poll + merge (`:259-265`) |
| `App/AppState.swift` | 638 | E2E chain (`:318-348`) |
| `Resources/forge-bundle.js` | 84,879 bytes | engine (muse branch `:1591`, translator `:1638`) |

Git HEAD `8c29895` (trigger) over `da6b2a7` (brace) over `5beb74b`. Evidence:
`proper-tape-327s.mp4` 11MB/334s/335 PNGs; `n9-muse-279s.mp4` 13MB/279s/280 PNGs;
`final-n9-362s.mp4`, `mc-green-52s.mp4`, `preview-only-23s.mp4`, `J1.mp4` 44MB,
`FULL-E2E.mp4` 28MB. Serve: `opencode serve --port 8090` bounded
(`NODE_OPTIONS=--max-old-space-size=3584 timeout 5400`), guest Tahoe 26.6.2,
`DerivedData/FORGE-fnbvuxcaavzlicabsbfqwartprlt`, `ARCHS=x86_64`.

## §4 Core Insight

The implementation must produce runtime-grade software that works correctly in a real
runtime environment — not just code that compiles. Non-negotiables: (1) every async
path (stream, poll, sheet) carries its error lane — silent returns are defects;
(2) boundary validation before presentation (file >5KB before `loadFileURL`, sessions
non-empty before deck, else explicit fallback); (3) resource discipline (bounded serve,
25s preview hold inside a 350s tape budget — 180s reasoning + 75s MC + margins);
(4) side-effects before claims (pixels on disk before PASS); (5) evidence hierarchy
(frame pixels > device file > grep > prose). The pending work is verification, and
verification is engineered: prime the DB, fix the windows, sample at 1fps, diff the
trap frames.

## §5 Scope (≤200 chars each)

1. Re-tape TapeA-v2 350s FULL_E2E (muse, 192.168.100.7, SWIPE=3, EAGLE=1) with DB prime.
2. Prove preview canvas marching (`p0170` neon, `p0170≠p0175` diff non-zero).
3. Prove list 11 titles (`p0220` TRIDENT FACTORY — 4s ago).
4. Prove deck `1/3→2/3→3/3` (`p0235/038/041`).
5. Prove Eagle 6+ cards + `:100 sessions` footer (`p0250`).
6. Re-prove prior PASS beats on the same tape (title, muse footer, no errors).
7. Container-test the bundle translator + gates (tokens below).
8. Write `VERDICT.md` zero-deltas + `pending-ship-approval-v2` checkpoint + commit.
9. Update canon (TASK_QUEUE, EVIDENCE_STATE, DEBUG_LOG, DECISION_CHAIN).
10. No model/provider changes; no bundle rebuild from `forge/src`; no paid keys.

## §6 Success Criteria (all command/ledger/eyes-checkable)

| # | Criterion | Check |
|---|---|---|
| 1 | `BUILD SUCCEEDED` + fresh 85KB bundle in `/tmp/FORGE.app` | `xcodebuild … \| grep -E "BUILD (SUCCEEDED\|FAILED)"` → SUCCEEDED; `ls -l` mtime |
| 2 | TapeA duration 340–360s, PNG count = duration ±2, all magic `\x89PNG` | `ffprobe` + `python3` assert + `sha256sum` ledger |
| 3 | Title frame: FORGE + Build Anything + both cards + v1.0.0 | eyes on `c0003`-class frame |
| 4 | Muse stream, zero errors, model footer all frames | eyes sweep; `grep` frames for `✗` → 0 |
| 5 | Preview neon canvas + marching diff | eyes `c0170`-class + `diff(c0170,c0175) ≠ 0` |
| 6 | List 11 titles | eyes `c0220`-class `TRIDENT FACTORY — 4s ago` |
| 7 | Deck `1/3→2/3→3/3` | eyes `c0235/038/041`-class counters |
| 8 | Eagle grid + `:100 sessions` | eyes `c0250`-class |
| 9 | Container tokens `PASS_MUSE_TRANSLATE`, `PASS_CHATMODEL_DONE`, `PASS_TAPE_GATES`, FAIL tokens absent | `trident-container-test` results artifact |

## §7 CONTAINER TEST PLAN (plan-first — the definition of done)

Evidence requirement (all scenarios): tool-result stdout + `sha256sum` of bundle +
`grep -c` counts recorded in `.trident/container-test-results.json`. Pass threshold:
3/3 scenarios PASS, 0 FAIL tokens, adversarial sub-cases green.

| Angle | Prompt | Pass token (tool-result) | Fail token |
|---|---|---|---|
| TOOLS | node harness: feed `museSseToChat` synthetic `output_text.delta` + `output_item.added(function_call)` + `arguments.delta`; assert synthetic `choices[].delta` lines | `PASS_MUSE_TRANSLATE` | `FAIL_MUSE_TRANSLATE` |
| AUDIT | `grep` ChatModel tool-write→`forgeTurnComplete` + status-`done`; `node --check` bundle | `PASS_CHATMODEL_DONE` | `FAIL_CHATMODEL_DONE` |
| INTEGRATION | `grep` `timeoutInterval = 30` + `asyncAfter(.*25.0.*safety)`; full hook chain dry-run | `PASS_TAPE_GATES` | `FAIL_TAPE_GATES` |
| BOUNDARY | malformed-JSON SSE line → translator returns input, no throw | `PASS_BOUNDARY_SAFE` | `ReferenceError` |
| STATE | empty sessions + 0-byte index.html → mock deck path + `Preparing preview…` guard (grep both) | `PASS_STATE_FALLBACK` | `accepted-invalid-input` |

Anti-circularity: tokens are printed by the harness/node/grep exit paths, never typed
by the agent under test; frame tokens (§6.5–8) match in PNG pixels, never chat prose.

## §8 Appendix — runbook pointers + audit note

Runbook: `Active_Projects/FORGE/docs/CLEANUP_SPEC_V1.md` §3 (rsync → xcodegen →
xcodebuild → user install → prime → detached DUR=350 record → `kill -INT` → scp →
ffmpeg → watch → VERDICT → checkpoint). Prior audit: `trident-code-audit` fired twice
(`started:true, detached:true`) but ledger
`FORGE/.trident/aether-ledger/run-status.json` absent + `status` = `NO_ACTIVE_RUN` +
no artifact — receipt phantom, zero findings credited; hand-audit stands in its place
(7 SOLID / 5 fix-landed-unproven / 1 metering-unverified — see session record).
Re-check artifact path `FORGE/.trident/audit-report-PRELIMINARY.md` before any re-fire.

## Zero-Trust Audit (self-audit of this DPL1)

| Severity | Finding | Surgical edit |
|---|---|---|
| MEDIUM | §7 TOOLS scenario needs the harness file to exist in-container | agent writes `/tmp/muse-harness.js` from bundle `sed -n` extract first |
| LOW | §6.4 "grep frames" is OCR-dependent | primary check is eyes-sweep; grep is auxiliary |
| LOW | Duration tolerance ±2s vs recorder `sleep 6` tail | accept 335–352s window |
Verdict: 0 CRITICAL, 0 HIGH, 1 MEDIUM, 2 LOW — no unresolvable gaps. Sections: 9/9
present in order; §7 angles: 5 (TOOLS, AUDIT, INTEGRATION, BOUNDARY, STATE); all §6
rows mechanically checkable; all §3 numbers measured this session.
