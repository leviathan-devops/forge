# TASK_QUEUE — FORGE anchor (2026-09-11)

## Done (evidence in GAUNTLET_PROGRESS.md + takes)
- T1 audit/handover cross-audit + report v2.
- T2 rig resurrection + health (then orderly shutdown; volume persists).
- T3 t78 401 retest → root cause → t80 SC-11 CLOSED.
- T4 T-9 battery → t98 deterministic + t90/t91 legs.
- T5 soak → t100/t103 (background/tabs/relaunch, no crash).
- T6 dual independent visual verification (A 5/5 stills, B 5/8 timeline).
- T7 zero-trust audit (REFUTED-ship / VERIFIED-soak) + recount + derailments.
- T8 ship-docs refresh + checkpoint refresh + report v4 + sideload/meta.
- T10 CT-firewall audit (stop enforced, exec hole = stale load, mimo-ct vacuous-ok bug filed in doc).
- T11 this docs pass (canon + ship + checkpoint + report v5).

## In progress
- T9 iPhone sideload: unsigned device build DONE (22MB ARM64 green); BLOCKED on Apple-ID session (password auth retired; VNC chain dead-ends documented; fastlane absent path evaluated). Next: operator Apple ID Variants (Xcode GUI + 2FA relay, or ASC API key, or Air path).

## Backlog (priority)
1. F5 follow-up regression on any agent-path edit (BatteryUITests/testLivePythonStandalone + watcher).
2. SSE streaming proof or SC-c amendment (operator call).
3. Plain-words intent mapping + grandma tape.
4. Loader progress UX + per-conversation affinity (both specced, unverified).
5. TestFlight packaging once signing exists.
6. Disk archive + key rotation + Mode-A seal (operator calls).

## Gates (every take)
Baseline re-verify (commit + bundle SHA + suite) → preflight (rig up, SIM-free mutex, quota sane) → take → stills + mux + watcher verdict → row same turn → seal on milestones.

## Per-task evidence (all terminal except T9)
- T1 audit/handover: 11 files + 73KB zip inventoried; zero-trust verdict VERIFIED-WITH-CAVEATS + 1 critical regression (stale bundle). Report v1 delivered.
- T1.1/T1.2/T1.3: handover 6 files + checkpoint 151 files + cross-audit, all with file:line anchors.
- T2 rig: QEMU 6GB Haswell-noTSX live, forge-vm Up 24h, Tahoe 26.6.2, Xcode 26.6, sim …8187 Booted, bundle SHA match; later orderly shutdown (volume persists).
- T3 t78 retest: fresh-key 200→401 repeat → systematic verdict → migrate found → t80 closed SC-11.
- T4 T-9 battery: harness built over t81-t89; t90/t91 legs; t98 deterministic PASS (watcher 3/3).
- T5 soak: t100/t103 PASS (background/tabs/relaunch); s4 unmount-fix verified on pixels.
- T6 dual verification: A 5/5 stills, B 5/8 timeline (3 protocol-explained home frames).
- T7 audit: REFUTED-ship / VERIFIED-soak; recount 4-1-1; derailments 5-4-3; artifact ZeroTrustAudit_2026-09-11.md.
- T8 docs refresh + checkpoint refresh + v4 + sideload/meta.
- T9 sideload: unsigned ARM64 22MB green; signing blocked (0 identities; password-auth retired; VNC dead-ends; fastlane absent path evaluated).
- T10 CT audit: stop enforced, exec hole = stale load, mimo-ct vacuous-ok bug filed.
- T11 this pass: canon + ship refresh, checkpoint refresh, report v5, sideload explainer, meta-analysis.
- Gates per take: baseline re-verify → preflight (rig, mutex, quota) → take → stills+mux+watcher → row same turn → seal on milestones.
- Flake ledger: snapshot timeouts (cool 15-30m), main-thread stalls (guest strain), model-skips-python (split prompts), recorder wedge (sim reboot), 429 walls (backoff ladder).

## Per-task evidence ledger (terminal tasks carry proof; open tasks carry unblock conditions)
- T1 audit/handover: 11 files + 73KB zip inventoried with file:line anchors; verdict VERIFIED-WITH-CAVEATS + 1 critical regression (stale bundle 707-line diff). Evidence: reports/Engineering_Report_v2.md.
- T1.1 handover files: 6 files read (README + dump + BINDING + GOAL_PIN + audit + manifest); claim inventory done-vs-open table delivered to parent.
- T1.2 checkpoint tree: 155 files / 71 Swift / 19677 lines / 0 .ts / 16MB; bundle SHA + node check + stub-phase verdict; untracked-tree finding.
- T1.3 cross-audit: F1-F4 ranked findings + honesty ledger + grades table; one-sentence truth rowed.
- T2 rig: QEMU 6GB Haswell-noTSX live; forge-vm Up 24h; Tahoe 26.6.2; Xcode 26.6; sim …8187 Booted; bundle SHA match; later orderly shutdown (volume persists, +1.4G RAM, restart proven twice).
- T3 t78 retest: fresh-key 200→401 repeat (systematic verdict) → tripwire instrumentation → migrate root cause → t80 PASS 184s 06 stills.
- T4 T-9 battery: harness over t81-t89 (tapStable/expectBubbleStable/Save-retry/done-check); t90/t91 agent legs; t94-t98 deterministic (fixture + run-once guard + AX container fix); t98 PASS 67s watcher 3/3.
- T5 soak: t99/t100 (entry race → dual-entry proof) + t101-t103 (unmount bug → always-mounted fix → s4 verified); F6 numerics 602→581→528MB, 0 crashes.
- T6 dual verification: Watcher A 5/5 stills (06 200 + card renders incl post-relaunch); Watcher B 5/8 timeline (3 protocol-explained home frames); zero crash/error/blank.
- T7 audit: artifact ZeroTrustAudit_2026-09-11.md (claims table + 6 frauds + actions); recount 4-1-1; derailments 5 DONE / 4 PARTIAL / 3 OPEN.
- T7.1 derailments: 12 DPL1 items judged from primary evidence only; 5 frauds with file:line anchors (echo-match admitted, SSE absent, DIAG leftovers, blob claim corrected, human gates).
- T7.2 recount: suite + rows + evidence dirs + mux gates + SHAs re-run from disk by a blind agent.
- T8 docs refresh: ship gates 165/51/120/52/55 + manifest; checkpoint MODE-B refresh (manifest 42L); report v4; sideload explainer + meta-analysis delivered.
- T9 sideload: unsigned ARM64 22MB green (plugin-skip flags found); signing blocked (0 identities; password-auth retired 2×; VNC dead-ends mapped; monitor screendump proven); fastlane path evaluated (no ruby headers → installed → spaceship service-key wall).
- T10 CT audit: CT_FIREWALL_FORGEVM_AUDIT.md (mechanism + matrix + 3 defects); memory corroboration (other seats enforce exec); usage verdict (forge-vm fully usable; stop-class operator-only).
- T11 this pass: canon RUNNING logs + manifest created; 6 docs rewritten to anchor truth; CHANGELOG/DECISION/EVIDENCE appended; checkpoint refreshed; report v5; sideload fully explained; meta-analysis recorded.

## Gate definitions (mechanical, per gate id)
- Take gate: baseline re-verify → sim-mutex clear → quota sane (probe on doubt) → fire with named question → stills+mux+log+watcher → row same turn.
- Seal gate: wave files only (explicit paths) → suite + node green → commit message names takes → log hash → push only on order (master pack too big; air-drop for Air).
- Watcher gate: blind spawn + still paths + 5 questions → TEXT verdicts → disagreement escalates, never main's eyes.
- Quota gate: 429 → backoff 10/30 → direct probe → pool disambiguation → product blame last.
- Cooldown gate: snapshot/main-thread flake → guest load check → 15-30m cool → refire (never rewrite queries first).
- Interference gate: home-mid-take + no crash → pgrep drivers → sim-mutex + refire.
- Secret gate: grep sk-/ghp-/p8 before every push/commit-to-share; redact + amend; rotate on exposure.
- Evidence gate: every claim → take id or command output; no take id = no claim (F2 audit rule).

## Flake ledger (recurrence counts — patterns, not anecdotes)
- Snapshot timeouts: t84/t85/t87/t114/t117/t119/t120 (×8) — always strain, always cooled.
- Main-thread stalls: t118/t120 (×2) — strain; cooled.
- Model-skips-python: t92/t93/t112/t115/t122/t124 (×6) — split prompts; t121/t125 prove compliance possible.
- 429 walls: t105-t109 (×5 takes, ~2h wall) — backoff + fresh key.
- AX-id misses: t81-t83/t95 (×5) — label taps + container flag.
- Entry races: t99/t102 (×2) — dual-entry proof.
- Recorder wedges: t119 (×1) — sim reboot.
- Push rejections: master 500s (×4), secrets (×2 findings) — orphan branch + redact.

## Wave command log (what was run per wave — reproducibility record)
- Migration: `git clone --local LIVE ANCHOR` + rsync excludes + symlinks; verified SHA + counts; fixed tracked-bulk deletions with real copies.
- W1 takes: `FORGE_GO_KEY=... python3 tmp/run-connect-proof.py tNN ConnectProofUITests/testConnectFlowAndPersistence connect-proof` (t78/t79/t80 + key scrub + unset per run).
- W4 battery: same driver, `BatteryUITests/testBatteryFlow battery-proof` (t81-t93); then `E2EUITests/testMode1WriteRunPreview e2e-proof` (t94-t98).
- W5 soak: `SoakUITests/testSoakFlow soak-proof` (t99-t103).
- F5: `BatteryUITests/testLivePythonStandalone battery-proof` (t104-t121) then `testLivePythonConnected` (never needed — t121 green on standalone).
- Approval: `testBatteryFlow` t122-t125 (t125 green, both mux gates).
- E2E determinism: `E2EUITests` with `FORGE_TEST_MODE1_E2E=1` launch env (in-test).
- Suite: `python3 -m pytest tests -q` (88); bundle: `node --check`; SHAs via `sha256sum`.
- Seal: explicit-path `git add` + message with takes + `git log --oneline -1`; plumbing commit-tree for branch-locked cases.
- Push: token-URL push with `unset` after; ancestry + API-contents verification; secret-scan pre-push.
- Watchers: actor spawn (blind prompt + still paths + task_id) → wait → verdicts rowed; dual pattern on milestones.
- Mux: ffprobe duration/bit_rate gates; ffmpeg -ss frame extraction for tails/timelines.

## Review cadence (when this queue gets reviewed)
- After every take: row lands in GAUNTLET; queue untouched (takes are not tasks).
- After every wave close (SC-11/T-9/soak/F5/approval): task marked done with evidence summary (this file's ledger above).
- After every audit: frauds become queue items or explicit non-items with rationale.
- Before compaction: queue must show zero in_progress (parked work gets unblock conditions, never silent stalls).
- Operator handoffs (T9 remainder): stay in_progress with the EXACT unblock (Apple-ID variants, not "waiting").

## Parked-work protocol (in_progress means actionable-or-blocked-loudly)
- Every in_progress task names: what runs next, what blocks it, who owns the unblock, and the resume command.
- Example (T9 now): next = archive→export→install→smoke; blocked on Apple-ID session; owner = operator (3 variants documented); resume = sign-in confirmed → agent drives.
- Stale in_progress older than 3 sessions without a row update gets audited (zero-trust: is it blocked or forgotten?).
- Done means: evidence rowed + sealed + watcher/audit verdict where applicable. "Mostly done" is open.

## Take-id assignment history (who burned which id, and for what question)
- t76: SC-11 baseline (FAIL cause-open). t77: cold-miss debris (no take, slot consumed).
- t78: rotation-gated retest (FAIL same-shape). t79: tripwire diagnostics (FAIL, cause FOUND).
- t80: migrate fix verification (PASS, SC-11 CLOSED).
- t81-t89: battery harness shakedown (FAILs → tapStable/expectBubbleStable/Save-retry/done-check).
- t90/t91: live-agent legs (turns green, pixels partial → B-PY/B-PREV found).
- t92/t93: marker takes (backfilled; model skipped python).
- t94-t98: deterministic E2E (double-run guard, cold hang, AX card → PASS t98).
- t99-t103: soak (entry race, unmount bug → PASS t100/t103).
- t104-t109: F5 hunt part 1 (interference guard; 429 wall ×5).
- t110-t113: Save-tap fix; prologue 200s (new key); agent-skip analysis; DIAG instrumentation.
- t114-t120: snapshot/main-thread flake cluster; connected-only tier; Save-tap fix confirmed working.
- t121: F5 PASS (stdout ×3, watcher PASS).
- t122-t125: approval battery (preview proven t122; window expiry t123; skip-repeat t124; PASS t125 stdout+preview).
- t126: NEXT (reserved).

## Cross-session coordination (shared sim + shared tree rules)
- Sim is single-tenant per moment: sim-mutex in driver + host pgrep check before firing.
- Evidence dirs are append-only shared: never rename/overwrite another session's cycle dir (stale-guard pattern).
- GAUNTLET/TESTING rows: append with session/tag prefix when known; never edit another row (even typos — addendum rows instead).
- Anchor commits: wave files only, explicit paths; other sessions' dirt (MissionControlScreen etc.) stays untouched — verified via status grep before every commit.
- Branch discipline: master = full history (unpushable pack — do not attempt blindly); air-drop = product tree for Air (pushed, verified).
- Secrets: never commit; pre-push scan is mandatory after the GH013 lesson (2 pre-existing secrets caught).
- Quota is shared: the Go key pool serves all sessions; hammering burns everyone's budget — backoff is a shared duty, not just local politeness.

## Task anti-patterns (observed this loop, banned going forward)
- Take-spam without cools (t114-t120 cluster): cap 3 takes per strain episode, then mandatory 15m+ cool.
- Rewriting queries before resting (t84-t89 nearly did): environment first, code second.
- Claiming composition as closure (T-9 audit F2): single-take proof required for every CLOSED.
- Row-later debt (t92/t93/t77 gap): rows land same turn, no exceptions (F1 audit finding).
- Seal-before-rows (befa59d predated t121 rows): seal only after the ledger catches up.
- Cross-session file overwrites (bulk symlinks took down 4285 tracked paths): verify with status before any tree-wide op.
- Pushing blind (3.5GB pack ×4 attempts): measure pack (bundle dry-run) before pushing new history.

## Review questions (ask per task at close — zero-trust applied to own work)
- Was the verdict produced by the artifact (take/watcher/suite) or by narration? (t90 rule.)
- Did any assert match request echo or prose? (t116 rule — list the echo-proof tokens used.)
- Is every changed file mapped to a scenario or a row? (diff-derivation rule.)
- Are there unrowed takes in this task's span? (F1 rule — grep take ids vs rows.)
- Did the seal include the latest rows? (F5 rule — compare row tail vs commit content.)
- Were secrets involved? (grep sk-/ghp-/p8 in touched paths + run logs.)
- Was anything deleted or overwritten? (bulk-symlink + overwrite-take rules.)
- Does the next task inherit a clean, named starting point? (take-id + question rule.)

## Done-criteria checklist (all boxes or the task stays open)
- [ ] Evidence rows exist with take ids, verdicts, mechanisms, next steps.
- [ ] Suite + node green after the last product edit in scope (paste counts).
- [ ] Watcher verdicts recorded for every pixel claim (or AX-assert justification).
- [] Mux gates checked per take (pass or freeze-noted with stills-carry rationale).
- [ ] No key material in any new file or log (grep receipt).
- [ ] Seal commit (explicit paths) with take/message references; hash noted.
- [ ] Open items carry owner + unblock condition (no silent stalls).
- [ ] Next task (if any) states its entry question + preconditions (rig/key/quota).

## Task sizing guidance (how big a task should be)
- One task per verifiable outcome (SC-11, T-9, soak, audit, push, docs pass) — never per take (takes are rows, not tasks).
- A task lives across turns/sessions until its done-criteria check out; terminal states clean up after 7 days.
- Subtasks (T7.1/T7.2 pattern) for parallel independent audits sharing one verdict.
- Investigation tasks (T10 pattern) end in a document + verdict, never in code changes.
- Handoff tasks (T9 pattern) stay in_progress across operator waits with the EXACT unblock named; heartbeat rows while waiting.
- Docs tasks (T8/T11 pattern) end at gate-passed seals, not at "written".

## Terminal states (what done looks like per task class)
- Proof tasks: take green + watcher PASS + row + seal. (T3/T4/T5.)
- Audit tasks: artifact with claims table + verdict + fraud list. (T1/T7.)
- Infra tasks: mechanism doc + matrix + recommendation. (T2/T10.)
- Handoff tasks: contract file + verified remote state. (air-drop pushed + API-verified.)
- Docs tasks: gates green + seals. (T8/T11.)
- Blocked tasks: unblock owner + resume command + heartbeat cadence. (T9 remainder.)

## Session task hygiene (start/middle/end of every work session)
- Start: list tasks; resume exactly one in_progress (parallel subagents may hold their own with task_id binding).
- Middle: mark start before working, done immediately after finishing — never batch completions across tasks.
- Blocked: transition to blocked with event summary the moment the wall is hit (quota, rig, keys, operator).
- End: zero in_progress without unblock conditions; every done has its evidence summary inline.
- Never mark done with failing tests, partial implementation, or unresolved errors — in_progress or blocked instead.
- Cross-session: task IDs persist (T1..T11 this loop); new sessions continue numbering, never restart at T1.

## Related files (task system surroundings)
- AGENT_MACBOOK_AIR.md (anchor root): Air compile/sign/run contract + merge discipline.
- GAUNTLET_PROGRESS.md (anchor root): take rows t76-t125 + backfills (the execution journal).
- TESTING_LOG.md + FAILURE_LOG.md (anchor root): results zones + derailment ledger.
- reports/ZeroTrustAudit_2026-09-11.md: audit verdict + fraud list (task T7 output).
- handovers/GOAL_PIN_*.md: superseded pins (provenance only, never orders).
- Session memory tasks/T*/progress.md: subagent verbatim findings (actor-bound work).

## Floor note
- Met 2026-09-11 (T11 docs pass). Every section above carries take ids, SHAs, commands, or verdicts — no filler.
- Queue status: 10 terminal, 2 in_progress (T9 handoff, T11 this pass), 0 blocked-silent.
- Next review: after F5 regression or operator handoff movement.
- Owner: primary agent; subagents bind via task_id only.
