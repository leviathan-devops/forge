# TESTING_LOG — FORGE ship wave (anchor: MIMOCODE/Forge)

## TEST PLAN ENTRY — 2026-09-11 — remaining verification

### HOST
- **What:** suite stays 88/88 across every product edit.
- **How:** `python3 -m pytest tests -q` post-edit.
- **PASS criteria:** `88 passed`, exit 0. **FAIL criteria:** any failure.
- **Status:** PASSED (standing order).

### CONTAINER (guest sim)
- **What:** F5 follow-up regression: live-agent stdout still green after future edits.
- **How:** BatteryUITests/testLivePythonStandalone + watcher still read.
- **PASS criteria:** p0 shows stdout pair as agent output, paid footer. **FAIL criteria:** spinner/error/blank.
- **Status:** PASSED t121 (re-run on any agent-path edit).

### HOST (device/out-of-band)
- **What:** team-signed install + 10m phone smoke + TestFlight receipt.
- **How:** operator: signing identity, Apple ID, USB, devicectl.
- **PASS criteria:** install log + smoke note + upload receipt. **FAIL criteria:** unsigned/unsigned-runnable only.
- **Status:** BLOCKED (0 guest identities, 0 profiles; operator-owned).

## Battery (host)
- 2026-09-10 anchor suite: **88 passed** (`tests/`, incl `test_single_model_lockdown_muse_13_paid_only` + `test_pollution_scrub_residuals` post-B4 scrub). Command: `python3 -m pytest tests -q`.
- Bundle: `node --check` clean every wave. SHAs: `90279713` (t76-t80) → `e93bbca4` (lockdown) → `46eb33a1` (bytes marker + preview prompt docs) → `f06bda2b` (sealed befa59d; identical worktree).
- F3 claim corrections (audit, all closed): T-9 was deterministic-chain-only until t121 (F5: single live-agent full-tape green, watcher PASS); streaming = chunked-callback via native bridge (EventSource 0) — SSE token-streaming absent, SC-c gate unmet.

## Takes (guest sim iPhone 17 Pro …8187, 6GB start-tahoe, XCUITest + watcher + ffprobe)
| take | test | XCTest | watcher | mux | verdict |
|------|------|--------|---------|-----|---------|
| t76 | connect proof | FAIL L147 (2nd 401) | partial (200 + 401 legs) | 447s/462k PASS | FAIL, cause open |
| t78 | connect proof, fresh key | FAIL L153 (2nd 401) | partial | seg saved | FAIL, same shape |
| t79 | + tripwires | FAIL L173 (model assert) | model `…flash-fin-free` post-relaunch | seg saved | FAIL, cause FOUND (migrate) |
| t80 | + migrate fix | PASS 184s, 06/06 stills | not separately watched (AX asserts green) | — | PASS, SC-11 CLOSED |
| t81-t89 | battery harness shakedown | FAILs (no-wait tap, AX ids, snapshot timeouts) | b0 legs green from t81 | segs saved | FAILs, harness fixed iteratively |
| t90 | battery | PASS 183s | FAIL (spinner, blank preview) | — | FAIL (B-PY/B-PREV found) |
| t91 | + completion window | PASS 353s | FAIL (prose claim, no stdout; blank revisit) | 379s/493k PASS | FAIL (stdout capture + revisit loss) |
| t92/t93 | bytes marker | FAIL (marker absent; dump: agent skipped python / L169) | — | segs saved | FAIL (model nondeterminism) |
| t94 | E2E fixture take | FAIL (AX-invisible terminal marker) | PASS (card + ANSWER + CANVAS OK on pixels) | — | FAIL harness, product green |
| t95 | E2E | FAIL (menu at end) | PASS (card at 200s; double-run error at 230s) | — | FAIL (double-run; run-once guard added) |
| t96 | E2E, cold guest | FAIL (card absent 420s) | fixture never ran (loader hang → watchdog error) | 563s/20k FAIL-freeze | FAIL (cold-load hang) |
| t97 | + stage markers | FAIL (card assert, AX flush timing) | — | — | FAIL harness |
| t98 | E2E | PASS 67s, 3/3 stills | PASS 3/3 (card + green canvas, zero errors) | 91s/139k FAIL-freeze | PASS deterministic chain |
| t99 | soak | FAIL (re-entry, 3 attempts) | s0-s4 green legs | 236s | FAIL harness (entry too short) |
| t100 | soak | PASS, 6/6 stills | s5 content by AX (watcher bytes unreadable) | 231s/104k FAIL-freeze | PASS (relaunch by AX; t103 re-verified on pixels) |
| t101 | soak | FAIL (card poll 90s post-tap) | — | — | FAIL (B-PREV unmount confirmed) |
| t102 | + mount fix | FAIL (re-entry) | dump: menu+Mode1+E2E fused tree | — | FAIL (restoration vs entry race) |
| t103 | + dual entry proof | PASS, 6/6 stills | 5/6 (s4 card-survives-switch VERIFIED; s5 bytes unreadable, AX asserts green) | 250s/109k FAIL-freeze | PASS, W5 soak CLOSED |
| t104 | battery F5 attempt | FAIL (entry; app backgrounded mid-take, no crash) | home screen mid-take | seg saved | FAIL external-interference (concurrent sessions share sim); driver sim-mutex added |
| t105 | battery F5 attempt | FAIL (prologue 429) | dump: FAIL provider answered 429 | — | FAIL environment (quota wall) |
| t106 | battery F5 attempt | FAIL (prologue 429 after 10m cool) | dump: 429 again | — | FAIL environment (loop pauses live takes until recovery) |
| t110-t120 | battery F5 attempts | FAILs (Save-tap stall, window expiry, snapshot timeouts, main-thread stall) | prologue 200s with new key (t111); agent skipped python (t112/t115) | segs saved | FAILs harness/model-behavior; Save retry, 600s window, done-check signal added |
| t121 | live-python standalone | PASS 224s, p0 still | PASS (stdout 42/DONE ×3, gear rows, done banner, paid footer) | seg saved | PASS, F5 CLOSED (single live-agent full-tape green) |

Mux-freeze note: static takes (fixture/soak) routinely fail the 400kbps gate; motion takes (t76/t80-class) pass. Stills + AX asserts carry static-take proof by design.
| t125 | approval battery (full flow) | PASS 359s, p0+p1 stills | PASS (stdout 42/DONE ×3 + green Hello full-bleed, paid footer) | 386s/636kbps PASS both gates | PASS — approval take (seg-01.mp4) |
