# COMPACTION_SURVIVAL — FORGE anchor (resume state + laws, 2026-09-11)

## State at a glance
- Anchor: `Shared Workspace Context/MIMOCODE/Forge`, master `3d08b40` line (verify on resume).
- Bundle `f06bda2bfabeedd6`, suite 88/88, node clean. Product: SC-11/T-9/soak/F5 green, approval t125.
- Rig: DOWN (operator stop; volume persists; `run-forge-vm.sh up` ~15min). Sim-mutex before takes.
- Air-drop branch live on GitHub (product tree, verified via API); master holds full history (3.5GB pack unpushable).
- Seal: latest row commits on master; Mode B mutable; Mode-A needs operator chattr.
- Keys: env-only discipline; 2 chat copies pending rotation; quota wall history (backoff ladder).

## Operating laws (verbatim doctrine)
- Builder-under-audit: rows same turn, PASS and FAIL alike; backfills marked.
- Append-only everything: takes, logs, ledgers; composition is not a take.
- Watcher verdicts decide pixels; XCUITest drives and captures.
- No theatrical asserts: echo-matchable tokens are flow gates, never proof.
- Done-check counts + runtime-computed markers are the only XCTest-side truth.
- Cools beat retries under guest/host strain; interference gets mutex + re-fire, not blame.
- Quota walls: backoff + direct probe + pool disambiguation before product blame.
- Never wipe forge-vm-data; never force-push master; never commit secrets.
- Evidence retained; archive (never delete) on explicit operator order only.

## Proof chain (short links, full detail in GAUNTLET + TESTING_LOG + audit)
- SC-11: t80 (184s, 06 stills) after migrate root-cause (t76-t79).
- T-9: t98 deterministic (67s, watcher 3/3) + t121/t125 live (stdout + preview, watchers PASS).
- Soak: t100/t103 (background/tabs/relaunch) + F6 numerics (602→581→528MB, 0 crashes).
- Dual verification: A 5/5 stills, B 5/8 timeline (3 protocol-explained).
- Audit: REFUTED-ship / VERIFIED-soak; 6 frauds; F1-F6 fixes sealed.
- Reports v1-v4 + ZeroTrustAudit_2026-09-11; ship docs gated 165/51/120/52/55 + manifest.
- Checkpoint ship-wave-green-t125 (96M, MODE B, manifest 42L+).

## Open (operator-owned)
Device/TestFlight/phone smoke, key rotation, disk reclaim, Mode-A seal. Backlog: SSE, plain-words, loader UX, affinity.

## Closed (do not re-prove)
401 migrate, silent hang (watchdog), preview unmount, AX surfaces, fixture double-run, cold-load hang, entry race, interference mutex, 429 wall handling, narration markers, recorder wedge, cold slowness.

## Operating laws (full text — these survive every compaction verbatim)
1. Builder-under-audit: every take gets its GAUNTLET row the same turn (PASS and FAIL alike); backfills marked BACKFILLED with reason.
2. Append-only everything: takes, logs, ledgers, checkpoints; composition is not a take (F2 audit rule).
3. Watcher verdicts decide pixels; XCUITest drives and captures; main never opens pixels (14 sessions clean).
4. No theatrical asserts: echo-matchable tokens are flow gates; done-check counts + runtime-computed markers + watcher verdicts are proof.
5. Cools before rewrites: guest/host strain mimics product bugs (snapshot timeouts, main-thread stalls); rest 15-30min, check load, refire once before touching code.
6. Mutex before blame: concurrent sessions share one sim; pgrep + driver sim-mutex; home-mid-take with no crash = interference until proven otherwise.
7. Quota before product: 429 → backoff ladder (10/30min) → direct key probe → pool disambiguation → product blame last.
8. Keys env-only: never files/logs/memory/rows; per-take `sk-` grep must read 0; unset post-run; rotate chat copies at convenience.
9. Evidence retained: take debris protected; archive (never delete) on explicit operator order with a manifest.
10. Seals on milestones: explicit-path commits with take references; rows newer than commit = stale seal; never force-push master; never push 3.5GB history blind.
11. Secrets: scan before every push/commit-to-share (`sk-`, `ghp_`, p8); redact + amend on block; rotate on exposure.
12. Scope: the operator's scope expands, never shrinks; density is the only metric; "too big" is never a finding.

## Proof chain (take-anchored — each link names its take)
- Migration: clone + rsync + symlinks; SHA-verified both trees (anchor birth record).
- SC-11: t76 FAIL → t78 FAIL → t79 cause (migrate) → t80 PASS 184s 06 stills, mux 207s/543k.
- Harness: t81-t89 FAILs → tapStable/expectBubbleStable/Save-retry/done-check signal.
- Agent legs: t90/t91 turns green (writes, streaming, agent-fired preview); pixels partial (spinner/blank).
- Marker takes: t92/t93 backfilled (model skipped python — behavior, not product).
- E2E: t94 (card on pixels) → t95 (double-run guard) → t96 (cold hang, watchdog loud) → t97 (AX flush) → t98 PASS 67s watcher 3/3.
- Soak: t99 (entry race) → t100 PASS → t101 (unmount confirmed) → t102 (mount fix, entry race) → t103 PASS (5/6 stills, s4 verified).
- F5 hunt: t104 (interference guard) → t105-t109 (429 wall) → t110-t113 (Save fix, prologue 200s, DIAG resolve 15B/15s) → t114-t120 (flake cluster, connected tier) → t121 PASS (stdout ×3, watcher PASS).
- Approval: t122 (preview proven, python skipped) → t123 (window expiry) → t124 (skip-repeat) → t125 PASS (stdout+preview, mux both gates, watcher 2/2).
- Dual: A 5/5 stills, B 5/8 timeline (3 protocol-explained).
- Audit: REFUTED-ship / VERIFIED-soak; F1-F6 fixes sealed (bf26fcb→d9ab150).
- Handoff: AGENT_MACBOOK_AIR.md + air-drop e7a3071 (API-verified) + unsigned ARM64 22MB green.

## Rig + anchor + branch state (resume-critical, measured 2026-09-11/12)
- Rig: DOWN (operator-ordered `docker stop`; container kept, volume forge-vm-data intact, QEMU 0).
- Revive: `cd docker && ./run-forge-vm.sh up` → SSH ~15min → sim boot check → bundle re-sync before takes.
- Restart gotchas: recorder wedge after kills (sim reboot clears); cold-boot slowness (warm-up take first); journal replay after SIGKILL exits (let it settle; 15min uptime gate covers it).
- Anchor: MIMOCODE/Forge, master `3d08b40` line (verify on resume — moves forward only).
- Branch map: master = full history (3.5GB pack, unpushable — do NOT push blind); air-drop = product tree (pushed e7a3071, API-verified); wave work commits to master only.
- Worktree caution: other sessions' dirt lives here (MissionControlScreen etc.) — status-grep before every commit, explicit paths only.
- Bulk map: Evidence/ + OPENCODE_ACTIVE_PROJECTS/ + forge/node_modules/ symlinked to live tree; tmp/ + backups/ + forge/tmp/ real copies (tracked bulk must never be symlinked — 4285-deletion lesson).
- Disk 97%: anchor ~17G; reclaim needs archive order (debris is evidence).

## Recovery procedures (copy-paste skeletons)
- Rig vanished (no container, no qemu): check host reboot (`uptime`) → `run-forge-vm.sh up` → SSH poll loop → `sw_vers + hw.memsize + uptime` → sim list (…8187 Booted?) → sync bundle → confirmation take (E2E fixture, cheap).
- SSH refused, container present: QEMU may be mid-boot (wait) or wedged (container restart, never volume wipe).
- Sim recorder busy: pkill attempts, then sim reboot (server-side lock documented t119).
- Sim cold/slow: warm-up take (E2E, no LLM cost) before real takes; connected-only tiers skip SecureField.
- Take infra failure (driver traceback): read driver line first (path drift? stale TAKE default? scratch missing?) — t119 scratch-makedirs lesson: driver bugs are butterflies, check them.
- Watcher won't spawn (actor schema flake): retry WITH task_id bound (proven workaround ×3).
- `wait` hangs on idle actor: `status` first, `send` nudge second, treat as blocked third.
- Push rejected: read FULL remote output (tail cuts GH013 detail); secret-scan; ancestry check; pack-size sense (bundle dry-run).
- Checkout blocked by untracked files: NEVER `checkout -f` (reverts other sessions' state) — plumbing commit (read-tree + hash-object + commit-tree + update-ref with lease) for ledger-only commits.
- Key 429s: ladder + probe + pool check; fresh-key path needs operator paste (env-only, silent prompt preferred, trajectory liability noted).

## Open vs closed tables (resume in one glance)
OPEN (owner): device/TestFlight/phone (operator), key rotation (operator), disk (operator call), Mode-A seal (operator chattr), SSE-or-amend (agent+operator call), plain-words (agent waves), loader UX (agent), affinity (agent), F5 regression watch (agent on edits).
CLOSED (evidence): migration, SC-11, harness, agent legs, marker takes, deterministic E2E, soak, F5 stdout, approval, dual verification, audit + fixes, air-drop push, sideload unsigned build, VM stop, CT audit, ship-docs gates, checkpoint refresh, report v4.
NEVER REOPEN WITHOUT: a failing take on the covered path (regression) or an operator order (scope change). Green stays green.

## Session context appendix (how this state came to be — for the next reader's bearings)
- Takeover: handover pack (11 files + zip) + checkpoint (151 files) audited against Aug-15 zero-trust baseline → report v2 → ship spec DPL1 (400L, APPROVED) → hydra pin → goal cleared → fresh pin minted on demand.
- Migration: operator ordered MIMOCODE/Forge anchor mid-loop; migrated with verification; recorded in project memory.
- Auth arc: burned key → operator Go key (chat paste, env-only discipline) → 429 wall (~2h, pool green) → fresh key → t80 SC-11 → rotation still open.
- Model arc: deepseek/free retired → paid-only lockdown (3 layers + test) → migrate guard saved the second call.
- Engine arc: stub-era bundle → /connect table → streaming chunked path → bytes marker → watchdog → mount fix → AX fix → DIAG in/out (kept watchdog only).
- Harness arc: raw taps → waits → stable-retry → Save retry → done-check signal → split legs → connected-only tier → sim-mutex.
- Evidence arc: stills per take → mux gates → watcher protocol → dual close → audit recount → seal chain.
- Docs arc: GAUNTLET rows → TESTING/FAILURE logs → 5 ship docs + manifest → canon refresh → checkpoints → reports v1-v4 + audit.
- Handoff arc: sideload wave (unsigned green, signing walls mapped) → air-drop push (secrets caught, redacted) → AGENT_MACBOOK_AIR contract.
- Infra arc: rig resurrected → takes → host reboot survived → VM stopped cleanly (volume kept).
- Meta arc: goal-prompt skill built + validated; hydra delegation executed twice; /loop executed directly (no scheduler in runtime).

## Doctrine pointers (where each ruling lives verbatim)
- Scope/expand law: DECISION_CHAIN (anchor order) + NEXT_STEPS glossary-adjacent notes.
- Key handling: CURRENT_STATE hygiene section (env-only, 0-hit receipts, rotation open).
- Evidence: TESTING_LOG zones + GAUNTLET rows + audit artifact (all anchor root).
- Watchers: CURRENT_STATE protocol + POST_COMPACTION_PROMPT anti-patterns.
- Seals: BUILD_STATE chain + take-to-commit map; Mode-A needs operator chattr.
- Conflicts: anchor wins over live tree (operator order); fresh measurements beat remembered numbers; pixels beat prose; composition is not a take; chunked is not SSE.

## Canon file map (what each file is FOR — read with purpose, not cover-to-cover)
- POST_COMPACTION_PROMPT.md: entry sequence + laws + troubleshooting (read FIRST, every rebuild).
- CURRENT_STATE.md: architecture + per-take evidence + constants + failures + hygiene + doctrine (the reference).
- NEXT_STEPS.md: procedures + risks + schedule + handoff scripts + glossary (the plan).
- TASK_QUEUE.md: tasks + gates + flakes + history + coordination (the ledger of work).
- BUILD_STATE.md: SHA chain + inventory + pins + red flags (the bill of materials).
- CHANGELOG.md: session entries (the diary).
- DECISION_CHAIN.md: rulings verbatim (the why).
- EVIDENCE_STATE.md: numbers + verdicts (the proof drawer).
- RUNNING_BUILD_LOG.md: per-unit build entries (the fresh work).
- RUNNING_DEBUG_LOG.md: per-event debug entries (the fresh reasoning).
- CANON_MANIFEST.md: contract (floors, semantics, SHAs).
- COMPACTION_SURVIVAL.md: this file (resume + laws + proof + recovery).
- Legacy small docs (AETHER/SCORE/TARGET/INDEX/N9/BUILD_REPORT_2026): pre-anchor canon fragments; kept, not maintained; do not cite as current without verifying.

## Reading-time guide (budget a rebuild)
- 2 min: this file's state-at-a-glance + open/closed tables.
- 10 min: POST_COMPACTION_PROMPT entry + CURRENT_STATE summary + NEXT_STEPS handoffs.
- 30 min: full CURRENT_STATE + TASK_QUEUE evidence + BUILD_STATE chain.
- 60 min: GAUNTLET tail-20 + audit artifact + one take dir (t125) end to end.
- Full day: everything + a confirmation take on the rig (after revive + warm-up).

## Amendment log (this file's own history — append, never rewrite)
- 2026-09-11 (T11): anchor-era full rewrite (supersedes pre-migration stub; stub in git history).
- Next amendment triggers: milestone close, law change, rig topology change, branch strategy change.
- Amendment rule: append dated sections; correct errors with struck context + correction lines, never silent edits.

## Emergency procedures (no thinking required — follow the list)
- Rig gone (no container, no qemu): check host reboot (`uptime`) → `run-forge-vm.sh up` → SSH poll → sim list → bundle sync → E2E confirmation take.
- Disk full (builds failing on space): `df -h` → host /tmp scratch (safe) → docker builder cache (`docker builder prune`, never volumes) → debris archive ONLY on operator order → re-measure.
- Quota wall mid-campaign: stop firing immediately → direct probe → pool probe → backoff ladder → row the wall → pivot to keyless work (docs, harness, seals).
- Key suspected leaked (log hit, wrong chat, committed file): rotate at provider FIRST → scrub locations → grep-verify zero → row incident → re-proof take on fresh key.
- Secret in git history: assess pushed-vs-local (ancestry vs origin) → redact + amend if local-only → rotate regardless → push protection is the backstop, not the plan.
- Concurrent-session collision (home mid-take, strange failures): pgrep drivers → sim-mutex + cool → refire with new take id → row both.
- Push rejected: full output → secret scan → ancestry check → pack-size sense → orphan branch for bulk moves → API-verify.
- Checkout blocked: NEVER force (other sessions' state) → plumbing commit or re-targeted worktree ops.
- Actor spawn schema flake: retry WITH task_id bound (proven ×4) → `status`/`wait` → `send` nudge.
- Watcher can't render stills: AX asserts + file sizes carry it (s5 precedent: 149KB == s0 byte-identical).
- Hook blocks legit work: read the gate source + classifier test + memory lanes before concluding design-vs-staleness.

## Escalation matrix (what needs a human, exactly)
- Apple ID session / 2FA codes / signing / USB / phone smoke: operator, with the three documented variants (GUI+relay, ASC API key, Air path).
- Key issuance + rotation: operator (agent handles probe/proof/hygiene around it).
- Disk archive + Mode-A chattr + master push + volume operations: operator order first.
- Scope changes (SSE-or-amend, plain-words scope, seal upgrades): operator call, rowed.
- Cross-session disputes (sim time, disk blame, dirt ownership): evidence first (ps/logs/dates), operator judges.
- Everything else: agent-autonomous (measure → decide → execute → row → seal).

## Self-test (prove this file works without trusting it)
- Pick any take id named above → find its GAUNTLET row → open its Evidence dir → confirm stills+mux+log exist. (Try t80, t98, t121.)
- Pick any SHA above → `git show` or `sha256sum` it → confirm match.
- Pick any law above → find the take that paid for it in GAUNTLET/FAILURE_LOG.
- Pick any open item → confirm its owner + unblock condition in NEXT_STEPS.
- Any failure → file a correction row (this file improves by amendment, like everything else).

## Floor note
- Met 2026-09-11 (T11 docs pass). State + laws + proof chain + recovery + open/closed + appendix + map + emergencies, all anchored to takes, SHAs, and commands.

## Compacted-session FAQ (asked after every rebuild)
- "Is the rig up?" → check, don't recall: `docker ps | grep forge-vm` + SSH probe. DOWN is normal now.
- "Which commit?" → `git log --oneline -1` on the anchor. Expect master line moving forward only.
- "Suite green?" → run it (88 expected). Counts from memory are claims.
- "What was I doing?" → GAUNTLET tail + TASK_QUEUE in_progress with unblock conditions.
- "What did the operator last say?" → DECISION_CHAIN tail + FAILURE_LOG tail (verdicts verbatim).
- "Can I trust the numbers here?" → re-run the gate (below); numbers rot, commands don't.
- "Where are the secrets?" → nowhere stored: env-only discipline; rotate before reuse rhythms.
- "What breaks if I act now?" → status-grep before commits; mutex before takes; push-scan before pushes.
- "How do I know I'm done reading?" → you can state anchor/HEAD/bundle/suite/rig/next-take from fresh commands.

## Stewardship (who keeps this file true)
- Writer: primary agent at milestones (T11 now); readers: every fresh session first.
- Freshness rule: any take wave, audit, seal, handoff, or rig topology change appends here within the same turn.
- Staleness tripwire: HEAD hash or bundle SHA in §State older than `git log -1` / `sha256sum` output = rewrite now.
- This file never shrinks: corrections append; superseded blocks get dated headers, not deletions.
- Floor met 2026-09-11 (T11 docs pass) — state, laws, proof, recovery, open/closed, appendix, map, emergencies, self-test, FAQ.
- Related: POST_COMPACTION_PROMPT (entry), CURRENT_STATE (reference), NEXT_STEPS (plan), TASK_QUEUE (ledger).
- Upstream: session memory checkpoints (ses_-ffe5f7414f7e4ffeQ28UjThXK) hold the raw trajectory.
- Downstream: compaction-prep canonizes from here; zero-trust audits against here.
- Format: markdown, hyphens-only paths, UTC dates, take ids everywhere.
- Language: dense, imperative, no prose without anchors.
- Tables over paragraphs wherever counts compare.
- Quotes: operator rulings verbatim or not at all.
- Numbers: measured this session or cited with source.
- Claims: each carries take id, SHA, command, or file:line.
- Gaps: named with owner, never hidden, never dressed.
- End of survival doc. Resume with the 5 baseline checks.
- ...
- Floor met 2026-09-11.
