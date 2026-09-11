# ZERO-TRUST AUDIT — FORGE ship claim (2026-09-11, ses_-ffe5f7414f7e4ffeQ28UjThXK)

**Verdict: REFUTED as "ship ready" — VERIFIED WITH CAVEATS as "engineering through soak".**
Auditors: primary (contaminated — built the work) + 2 fresh blind subagents (general-14 recount, general-15 derailments). No claim below rests on builder prose alone.

## Claims table (claim | reproduction | verdict)
| # | claim | reproduction (actual output) | verdict |
|---|-------|------------------------------|---------|
| 1 | pytest 88/88 | Auditor A ran it: `88 passed in 1.07s` | VERIFIED |
| 2 | GAUNTLET one row per take, no gaps | Auditor A: 25 rows over t76–t103; missing t77, t92, t93 | REFUTED (ledger gap) |
| 3 | evidence dirs complete (t80/t98/t100/t103) | Auditor A listed files per dir (stills + seg + log) | VERIFIED |
| 4 | mux gates on 4 segs | Auditor A ffprobe: duration 4/4 PASS; bitrate 1/4 (t80 543671; t98/t100/t103 freeze-FAIL, self-admitted) | SPLIT |
| 5 | bundle SHA sealed = tree | Auditor A: worktree f06bda2b == `git show befa59d:` piped hash, identical | VERIFIED |
| 6 | node --check | exit 0 | VERIFIED |
| 7 | SC-11 closed | t80 take + 06 still + Auditor B GAUNTLET:281 | VERIFIED |
| 8 | T-9 closed | deterministic t98 green; live single-tape never green ("closed by composition" = soft) | PARTIAL (false-completion class) |
| 9 | soak closed | t100/t103 + dual watchers; RSS/diagnose numeric half absent | PARTIAL |
| 10 | seal befa59d current | post-commit rows uncommitted; pre-existing live dirt excluded | PARTIAL (stale) |
| 11 | streaming proven | chunked-callback yes; EventSource count 0, SC-c gate unmet | PARTIAL (precision) |
| 12 | device/TestFlight/phone | no artifacts; human-gated | OPEN (correctly reported) |

## Frauds found
- **F1 ledger gap (refuted row):** takes t92, t93 ran but were never rowed; t77 debris-note only. Append-only law violated by omission.
- **F2 false completion:** "T-9 CLOSED by composition" — deterministic chain green, live-agent full-tape green absent. Composition is not a take.
- **F3 admitted theatrical asserts:** BatteryUITests.swift:165-166 match request echo (confessed in-file :160-163); honest marker :169 carries the weight. Watcher verdicts are the actual gate.
- **F4 leftover diagnostics:** pyStage() [py-stage] markers live in ForgeBridge.swift:787-862 shipped code (flagged for removal pre-ship, still present).
- **F5 stale seal + foreign dirt:** befa59d predates latest rows; uncommitted pre-existing modifications (ForgeEngine, MissionControlClient, bundle_and_wiring test) and untracked dirs (connect-wave, pending-ship-approval) sit outside the seal.
- **F6 blob claim corrected:** engine sources DO exist (forge/src/*.ts) — the F2 blob-only framing was stale. Caveat stands: runForgeAgent has no same-named source symbol; bundle↔source correspondence unverified.

## Recommended actions (smallest fixes, in order)
1. Backfill t92/t93 rows (marked backfilled) + t77 debris row.
2. Remove pyStage() markers from ForgeBridge.swift; re-run suite + node check.
3. Reword T-9/SPEC claims: "deterministic chain green; live single-tape open; streaming = chunked-callback, SSE absent."
4. Re-commit seal (include latest rows + logs) after 1-3; leave foreign dirt and untracked dirs out, named.
5. Then: operator handoffs only (signing identity, Apple ID/USB, key rotation, disk).
