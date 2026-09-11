# SPEC_VIOLATION_LOG — FORGE ship wave (spec § → requirement → observed → verdict → evidence)

| V-01 | DPL1 §6 SC-c (stream renders token-by-token + EventSource>0) | chunked-callback streaming proven (stream:true payloads, throttled 66ms emit, muse SSE normalizer) | VIOLATED MEDIUM (precision): EventSource count 0, SSE token-streaming absent | `forge-bundle.js` grep EventSource=0; SC-c gate unmet |
| V-02 | DPL1 §5.5 (plain-words UX, no slash/error codes on grandma path) | slash table remains the only mapped path; no grandma-path tape | VIOLATED MEDIUM (open work, not regression) | grep plainWords/intentMap: 0 hits; no tape rowed |
| V-03 | DPL1 §6 SC-i (soak RSS t0/5/10 + simctl diagnose, zero SIGSEGV) | RSS trend logged (602→581→528MB idle), throttled 0, 0 crashes; no diagnose bundle | VIOLATED LOW (numeric half): stability proven, artifact absent | GAUNTLET F6 row; no diagnose file on disk |
| V-04 | Pin legal stop (TestFlight receipt + phone smoke + seal) | device/TestFlight/phone blocked on signing identity + Apple ID + USB (guest: 0 identities, 0 profiles) | VIOLATED HIGH (operator-gated): correctly reported, not silently dropped | `security find-identity`: 0; no devicectl log |
| V-05 | DPL1 §6 SC-g (87/87) | suite at 88/88 (B4 scrub + lockdown test added) | PASSED (superseded upward) | `pytest tests -q`: 88 passed |
| V-06 | Key law (burned key never repo/chat/rows) | operator pasted Go keys in chat twice; env-only discipline held elsewhere (0 hits in every run log) | VIOLATED MEDIUM (chat copies exist) | FAILURE_LOG F-09; rotation open |

## Evidence detail (per row)
- V-01: `grep -c EventSource forge-bundle.js` → 0; streaming proven via `__forgeStreamChunk` throttled emit + t90/t91 live turns on tape; muse SSE normalizer `museSseToChat` present.
- V-02: `grep -rn "plainWords\|intentMap" iOS/ forge/src/ | wc -l` → 0; battery prompts are natural language but unmapped; no grandma tape exists.
- V-03: vm_stat free t0 602MB → t5 581MB → t10 528MB idle; throttled 0; 0 FORGE crash reports in guest DiagnosticReports; no `simctl diagnose` bundle collected.
- V-04: guest `security find-identity -v -p codesigning` → 0 valid identities; 0 provisioning profiles; no devicectl log; runbook `docs/testflight-setup.md` (227L) untouched by takes.
- V-05: `python3 -m pytest tests -q` → `88 passed in ~1s` (13 files, incl lockdown + B4 tests).
- V-06: operator pasted 2 Go keys in chat; every run log grepped `sk-[A-Za-z0-9]` → 0 hits; keys lived in env only, unset post-run.

## Remediation plan (per row, owner, concrete next step)
- V-01 SSE: EITHER implement EventSource token path in bundle + streaming-frames take (2-3 takes) OR amend SC-c to chunked-callback streaming (spec change, operator call). Owner: agent + operator decision.
- V-02 plain-words: map 3 intents (ask/build/show) over slash table + grandma tape with non-technical prompt read aloud. Owner: agent (2 waves) + operator eyes.
- V-03 soak numerics: run `xcrun simctl diagnose` post-soak-take and file the bundle path; add RSS assertions to SoakUITests via guest memadios (simctl spawn vm_stat parse). Owner: agent (1 take).
- V-04 device/TestFlight: operator provides signing identity + Apple ID + USB; agent runs archive/export/install/smoke. Owner: operator first, agent second.
- V-05: none (closed upward).
- V-06: operator rotates both keys; agent re-proves with fresh-key take (t78 pattern, 1 take).

## Status + evidence chain (per row)
- V-01 STATUS: open precision gap. CHAIN: DPL1 §6 SC-c text ("stream renders token-by-token ... EventSource>0") → bundle grep (EventSource 0, 1 session:chat emitter, chunked path present) → t90/t91 live turns (streaming observed on tape, token-level unproven) → verdict stands until SSE lands or spec amends.
- V-02 STATUS: open work. CHAIN: DPL1 §5.5 text → code grep zero → no tape → verdict stands until mapped + taped.
- V-03 STATUS: partially evidenced. CHAIN: SC-i text → vm_stat trend + throttled-zero + zero-crash artefacts → missing diagnose bundle → verdict stands until filed.
- V-04 STATUS: operator-blocked. CHAIN: pin legal-stop text → guest identity/profiles query (0/0) → no device artifacts → verdict stands until handoff completes.
- V-05 STATUS: closed. CHAIN: 87/87 text → 88/88 measured → superseded upward, no violation.
- V-06 STATUS: open rotation. CHAIN: key law → 2 chat copies → 0 log hits across ~20 run logs → rotation + re-proof closes it.
- Cross-ref: ZeroTrustAudit_2026-09-11.md frauds F3 (precision), auditor-B items 2/5/8; GAUNTLET F-rows for the fixed classes.

## DPL1 §5 coverage map (12 items → takes → status)
- §5.1 t78 retest → t78/t79/t80 → DONE (SC-11 closed).
- §5.2 SSE streaming → t90/t91 (chunked observed) → PARTIAL (V-01).
- §5.3 agent tool calls → t91/t98/t121 (write/run/preview on tape) → DONE.
- §5.4 agent→preview loop → t91-b0/t103-s4 (render + survive) → DONE.
- §5.5 plain-words UX → no take → OPEN (V-02).
- §5.6 B4 87/87 → host suite 88/88 → DONE (V-05).
- §5.7 T-9 battery → t98 deterministic + t121 live → DONE (composition noted honestly in audit).
- §5.8 soak + RSS → t100/t103 + F6 trend → PARTIAL (V-03).
- §5.9 device build + smoke → no take → OPEN operator (V-04).
- §5.10 TestFlight → no artifact → OPEN operator (V-04).
- §5.11 checkpoint + seal → Checkpoints/ship-wave-green-t125 + befa59d→d9ab150 → DONE (MODE B).
- §5.12 logs → all 5 ship docs at root → DONE.

## Ledger state
- Entries: V-01..V-06 (6 rows) + P-rows: none (no process-ruling violations recorded).
- Last full pass: 2026-09-11 (audit-fix wave). Next pass: after SSE/plain-words/device close-out.
- Auditor cross-check: ZeroTrustAudit items (b) SSE, T-9 composition, seal staleness — all mapped above; no unmapped audit finding remains.
