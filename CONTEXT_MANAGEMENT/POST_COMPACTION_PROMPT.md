# POST_COMPACTION_PROMPT — FORGE anchor (entry sequence for a fresh agent)

You are continuing the FORGE iOS ship loop. Anchor (only truth):
`/home/leviathan/OPENCODE_WORKSPACE/Shared Workspace Context/MIMOCODE/Forge`
(live `OPENCODE_WORKSPACE/FORGE` is reference + bulk host only).

## Read order (in this order, before any action)
1. This file (mission + entry).
2. `CONTEXT_MANAGEMENT/CURRENT_STATE.md` (per-module truth + open list).
3. `CONTEXT_MANAGEMENT/EVIDENCE_STATE.md` (what is proven, with SHAs).
4. `GAUNTLET_PROGRESS.md` tail -5 (latest take rows; next unused take id).
5. `reports/ZeroTrustAudit_2026-09-11.md` verdict + fraud list (what not to re-claim).
6. `handovers/GOAL_PIN_SHIP_SPEC.md` ONLY if re-pinning a goal (pins rot; reality is in 1-5).

## Verified state (re-verify before trusting — commands, not memory)
- `git log --oneline -1` → expect master-line head (was `3d08b40`; moves forward only).
- `sha256sum iOS/FORGE/Resources/forge-bundle.js` → expect `f06bda2b…` (full in BUILD_STATE.md); mismatch = drift, stop and reconcile.
- `python3 -m pytest tests -q` → expect `88 passed`.
- `node --check iOS/FORGE/Resources/forge-bundle.js` → exit 0.
- Rig: `sshpass -p alpine ssh -p 50922 user@127.0.0.1 'uptime'` — DOWN is normal now (stopped by operator order); revive via `docker/run-forge-vm.sh up` (~15min to SSH) only when a take is next.
- Sim-mutex: `pgrep -af run-connect-proof` must be empty before firing any take.

## Laws (non-negotiable, learned at full price)
- Builder-under-audit: every take gets its GAUNTLET row the same turn (PASS and FAIL alike); backfills marked BACKFILLED.
- Append-only takes: never overwrite a closed take dir; next unused id only (t126 after t125).
- Main-never-opens-pixels: watcher subagents read stills via trident-omni-vision/read; main consumes VERDICT + deltas.
- XCUITest drives + captures; pixels decide. Bubble text cannot separate narration from markers — done-check counts + watcher verdicts are the gates.
- Flow gates only in XCTest (did the turn advance?); output truth = watcher.
- Keys: env-only, never files/logs/memory/rows; `grep -c 'sk-'` every run log must read 0; unset after; rotate chat-pasted keys at convenience.
- Cools between takes (15-30min) when snapshot timeouts or main-thread stalls cluster; check guest load first.
- Quota wall (429s): backoff ladder 10/30min + direct key-liveness probe; pool-vs-key disambiguation via proxy probe before blaming product.
- Never wipe forge-vm-data. Never force-push master. Never commit secrets (push protection will reject; redact + amend).
- Evidence retained: take debris is protected; archive (never delete) on explicit operator order only.

## First action (always)
Re-verify the five baseline checks above, then state: HEAD, bundle SHA match/mismatch, suite count, rig state, next take id. If anything mismatches the recorded state, reconcile BEFORE new work.

## Open work (see NEXT_STEPS.md for procedures)
Operator-owned: device/TestFlight/phone smoke, key rotation, disk reclaim, Mode-A seal. Backlog: SSE proof-or-amendment, plain-words mapping + grandma tape, loader UX, per-conversation affinity, F5 regression on agent-path edits.

## Closed knowledge (do not re-prove without cause)
SC-11 (migrate guard, t80), deterministic E2E (t98), soak (t100/t103), F5 stdout (t121), approval (t125), dual watchers, audit + fixes, air-drop branch live. Re-take only on regression or product change in the covered path.

## Worked examples (what good first actions look like)
- "New take needed (F5 regression)": re-verify 5 checks → pgrep mutex clear → check quota history (last 429 when?) → assign take id (t126) with named question → fire driver → stills+mux+watcher → row.
- "Product edit needed": read the module section in CURRENT_STATE → make minimal edit → suite + node check → if agent-path changed, plan confirmation take → commit explicit paths → update BUILD_STATE chain line.
- "Operator handoff moved (Apple ID in!)": verify signing identity present (find-identity) → archive → export → transfer → install → smoke → row each artifact.
- "Quota wall suspected": backoff (no take) → direct key probe → pool probe → compare → blame product LAST.
- "Stuck/flaky take": guest load check → cool 15-30 → refire once → only then touch test/harness code.
- "Push needed": secret-scan → ancestry check → pack-size sense-check → push → API-verify contents → row.

## Troubleshooting (fresh-session failure modes)
- Bundle SHA mismatch: `git status` (uncommitted edits?) → `git stash list` (stranded work?) → diff worktree vs sealed blob → reconcile by rebuilding or checking out sealed state (never force).
- Suite count ≠ 88: run verbose per-file; newest test file first; check pycache staleness (`find tests -name __pycache__`).
- Rig DOWN: `docker ps -a | grep forge-vm` (exited? absent?) → `run-forge-vm.sh up` → 15min SSH poll → sim boot check → bundle re-sync before takes.
- Sim-mutex busy: identify owner PID via pgrep full line; wait or coordinate; never kill another session's driver.
- Watcher won't spawn (actor schema flakiness observed): retry WITH task_id bound; read stills yourself is FORBIDDEN (vision law) — escalate to operator before breaking it.
- Actor `wait` hangs: subagent may need a `send` nudge; check `status` first; treat idle-without-result as blocked, investigate.
- Quota 429 on probe: do NOT fire takes; start backoff ladder; record wall start time.
- Evidence dir missing for a rowed take: check live tree mirror (Evidence is symlinked bulk); recover from guest DerivedData/sim logs if needed; mark EVIDENCE-LOST if unrecoverable.
- Checkpoint too big to copy: exclude node_modules/tmp/DerivedData (debris, documented); never exclude src/tests/docs/evidence.

## Anti-patterns for the fresh agent (session-start traps)
- Trusting this prompt's numbers without re-running the 5 checks (numbers rot; commands don't).
- Firing a take as the first action (baseline first, always — t119 lesson: unknown state burns takes).
- Editing product code to satisfy a failing harness (two-sided adjudication: test may be wrong).
- Reading stills directly ("just one peek") — vision law has no exceptions; spawn the watcher.
- Appending rows for takes that never ran (F1 rule applies to the future too).
- Committing other sessions' dirt (status grep before every commit; explicit paths only).
- Pushing master blind (3.5GB pack lesson; measure first, air-drop for bulk moves).
- Typing secrets anywhere but the designated silent prompt (key law; grep after).
- Deleting "debris" to free disk (evidence law; archive on order, manifest the move).
- Declaring done without the verification run (completion requirements: change + run + minimal).

## Law rationales (why each law exists — one take that paid for it)
- Baseline first: t119 fired into unknown state and burned a full take cycle on nothing.
- Mutex: t104 died to a concurrent session's take (home mid-take, no crash) — pgrep is cheaper than evidence.
- Watchers: t90 XCTest-green/pixels-red ended bubble-trust forever.
- Done-check counts: t116 prose matched the phase token; counts can't be paraphrased.
- Cools: t84-t89 rewrote queries for a strained guest; rest fixed what code couldn't.
- Backoff: t105-t109 burned 5 takes into a throttled key; the 6th (post-cool) still failed — ladder then probe.
- Append-only: t92/t93 unrowed takes hid for a full audit cycle.
- Explicit-path commits: bulk symlinks showed 4285 deletions; status-grep before commit since.
- No force-push: seals are referenced by hash across GAUNTLET/audit/reports; rewriting breaks the chain.
- Secrets: 2 committed secrets blocked GitHub push (GH013); scan-then-push always.

## Reading drills (prove you absorbed the context before acting)
- State the anchor path, HEAD hash, bundle SHA, suite count from YOUR OWN command outputs (not this file).
- Name the next unused take id and the question it will answer.
- Name the rig state and the restart command with its time cost.
- Name the quota state (last 429 when, if ever) and the backoff position.
- Name the open operator items and who owns each.
- If any answer is "from memory" rather than "from a command I just ran", re-run the check.

## Scenario walkthroughs (rehearse the common turns)
### A normal take turn
Re-verify baseline (5 checks, ~2 min) → mutex + quota preflight → fire driver with take id + test + stilldir → monitor via log tail (never the pixels) → collect stills+mux+log → spawn watcher with 5 questions → wait → row PASS/FAIL with mechanism → commit rows on milestones → update TASK_QUEUE position. Total wall time: 10-20 min per take.
### A failure turn
Read the failure line + dump FIRST → classify (harness/environment/model-behavior/product) using CURRENT_STATE flake playbook → smallest fix or cool → refire with new take id → row both takes (failed + refire) with linkage.
### A product-change turn
Read module section → minimal edit → suite + node → assess take-need (agent-path touched? → confirmation take; docs-only → no take) → commit explicit paths → BUILD_STATE chain line → seal if milestone.
### An operator-handoff turn
Verify the handoff artifact yourself (identity present? key 200? disk under 90%?) → execute the agent side → row artifacts + receipts → advance NEXT_STEPS statuses → report with evidence, not adjectives.
### A stuck turn (nothing works, twice in a row)
Stop firing takes. Re-read CURRENT_STATE flake playbook + DEBUG_LOG lessons. Check: rig load, quota, mutex, disk, branch state. Form ONE hypothesis with a discriminating test (like the DIAG traces or tripwire asserts). Smallest possible probe first. Row the stuck state honestly before the fix (FAIL rows are data).

## Command glossary (every command a fresh agent needs, with expected outputs)
- `git -C "$ANCHOR" log --oneline -1` → master tip hash + message (compare with recorded line).
- `sha256sum "$ANCHOR/iOS/FORGE/Resources/forge-bundle.js" | cut -c1-16` → expect f06bda2bfabeedd6 prefix.
- `python3 -m pytest "$ANCHOR/tests" -q 2>&1 | tail -n 1` → expect `88 passed`.
- `node --check "$ANCHOR/iOS/FORGE/Resources/forge-bundle.js"` → silent exit 0.
- `pgrep -af run-connect-proof` → empty means mutex clear.
- `sshpass -p alpine ssh -p 50922 user@127.0.0.1 'uptime'` → guest alive + load check.
- `ffprobe -v error -show_entries format=duration,bit_rate -of default=noprint_wrappers=1 <seg>` → gates 90s/400k.
- `grep -c 'sk-[A-Za-z0-9]' <runlog>` → expect 0 (key hygiene receipt).
- `grep -c "py-stage\|pyStage" iOS/FORGE/Bridge/Forge*.swift` → expect 0 (diagnostics out).
- `grep -c "EventSource" iOS/FORGE/Resources/forge-bundle.js` → expect 0 (SSE absent, known).
- `docker ps --format '{{.Names}} {{.Status}}' | grep forge-vm` → rig state.
- `df -h / | tail -n 1` → disk pressure check.
- `ls Evidence/play/ | grep cycle-forge- | tail -n 3` → newest take dirs.

## Evidence reading guide (how to consume each artifact type)
- GAUNTLET rows: leading take id + verdict + mechanism + next; backfilled rows say BACKFILLED; rows are claims backed by the take dirs named in them.
- xcodebuild-test.log: search `error:` for failure lines + line numbers; UI TREE DUMP sections give AX state; absence of dump means throw-inside-wait (sick tree).
- Stills (via watcher ONLY): in-test PNGs witness asserts; mux-extracted frames cover tails/timelines; provenance labeled per still set.
- Mux segs: duration/bitrate via ffprobe first; frozen bitrate on static takes is expected (stills carry proof); motion takes must pass both gates.
- Watcher returns: per-still VERDICT + strongest observation; disagreements escalate; watcher context (tool surface notes) is metadata, not verdict.
- Audit artifact: claims table first (reproduction column), then frauds, then actions; verdict line is the gate.
- Run logs (/tmp/forge-tNNN-run.log): driver stdout (RSYNC/KEYFILE/RECORDER/BUILD/TEST/STILL/MUX lines) + REDACTED markers; 0 sk- hits mandatory.

## Escalation paths (when to stop autonomous work and ask)
- Operator gates: signing identity, Apple ID variants, USB device, key issuance/rotation, disk archive order, Mode-A chattr, push order for master.
- Ask with: what is blocked, what was tried (with take ids), what exactly is needed (one sentence), what happens after (resume command).
- Never ask: things measurable on rig/guest/disk (measure first); things memory records (search first); things a take can decide (fire first).
- Never stall silently: blocked tasks carry event summaries; heartbeat rows while waiting on humans.

## Session archetypes (recognize which session you are in)
- Take session: baseline → preflight → fire → watch → row → seal. Output: GAUNTLET rows + evidence dirs.
- Debug session: failure line → dump → hypothesis → discriminating probe → minimal fix → verification take → DEBUG_LOG entry.
- Audit session: claims table → reproduction rows → fraud list → verdict + actions (never fixes — gate, not implementation).
- Docs session: ground truth first → append per semantics → gates → seal. (You are reading the output of one.)
- Handoff session: verify operator artifact → execute agent side → row receipts → advance statuses.
- Sideload session: signing present? → archive → export → transfer → install → smoke → row each artifact.
- Recovery session: rig down → triage (container? QEMU? host reboot?) → run-forge-vm.sh up → SSH poll → sim check → bundle re-sync → confirmation take.
- Meta session (audits about audits, docs about docs): deliverable is always a named file + gate result, never commentary.

## Entry checklist (complete before ANY work, no exceptions)
- [ ] Anchor path confirmed (MIMOCODE/Forge; live tree is reference only).
- [ ] HEAD hash recorded from `git log` (not from memory).
- [ ] Bundle SHA matches recorded prefix (or drift row opened).
- [ ] Suite count recorded (88 or investigated).
- [ ] Rig state known + restart path fresh if DOWN.
- [ ] Mutex clear (or owner identified).
- [ ] Key/quota state known (last wall time or fresh-key status).
- [ ] Next take id + question named (or docs-only session declared with its file list).
- [ ] Firewall state known (OFF per operator order — re-enable prompt pending).
- [ ] Open operator items re-read (never assume movement; verify each).

## Post-compaction reading discipline (your context is a projection — treat it so)
- The visible conversation may be a compacted projection of longer history; the dumps (checkpoint/MEMORY/notes/global) are already in context — do NOT re-Read them whole.
- Memory entries name functions/files/flags as CLAIMS from their write-time: verify before acting on any specific name (grep the tree, run the command).
- A HIT is authoritative (trust it over a sibling null result); a MISS means retry rarer terms, then history tool, then widen scope — never "it doesn't exist" after one query.
- Session checkpoints from OTHER sessions (ses_* files) are their authors' truth, not yours — cite, don't inherit, their verdicts.
- If a rebuild dump shows truncation markers, pull the missing tail with Read(offset) ONLY for the section you actually need.

## Known-stale traps (memory/docs that mislead if read naively)
- Old pins (GOAL_PIN_SC12_T78, GOAL_PIN_SHIP_SPEC): provenance only; pixels rot; re-mint, never execute.
- Live-tree docs newer than anchor docs: live is reference — anchor wins on conflict by operator order.
- Pre-migration bundle SHAs (90279713 era): valid history, not current state (current f06bda2b).
- Suite counts from other eras (46/67/76/87): the standing count is 88 until a run says otherwise.
- "VNC typing DEAD" (handover era): true for vncdo path; QEMU monitor sendkey/screendump path proven working after.
- "copyresearch111 dead" (August recovery plan): referred to that plan's context; the same address later authenticated real takes — status is per-attempt, never canonical.
- Quota walls: time-bounded by nature; a wall recorded hours ago is not a wall now — probe before assuming.
- Rig DOWN records: restart path proven twice (including post-host-reboot); DOWN is a state with a procedure, not a verdict.

## Fresh-agent FAQ (asked every rebuild — answered once, here)
- "Where do I start?" → the 5 baseline checks, then the take-id register in NEXT_STEPS.
- "Which tree?" → MIMOCODE/Forge anchor, always. Live tree is read-only reference + bulk host.
- "Which branch?" → master for wave work (air-drop is the Air's product snapshot; don't commit wave rows there).
- "Can I trust the summary?" → No — re-verify. Summaries (including this file's numbers) are pointers to commands.
- "The suite fails — fix code or test?" → two-sided adjudication: read the failure, check the product path on-device history, decide with evidence.
- "Watcher disagrees with XCTest?" → pixels win for output truth; XCTest wins for flow completion; row both, investigate the gap.
- "Out of quota?" → backoff ladder, direct probe, pool check — in that order, rowed.
- "Operator asked something vague?" → route through compose:ask; headless default = best-option-forward + re-ask at next fork.
- "Something's huge/broken/ambitious?" → scope law: decompose + first wave, never shrink; density is the only metric.

## Floor note
- Met 2026-09-11 (T11 docs pass). Entry sequence + laws + examples + troubleshooting + drills + glossary + archetypes + checklists above; every claim anchored to a file, command, or take id.

## Version
- v2 anchor-era rewrite (2026-09-11, T11): supersedes the 24-line legacy stub (archived in git history, not deleted).
- Review on: next milestone, next audit, or any law change (operator rulings append, never silently edit).
- Steward: primary agent of the active session; subagents read, never rewrite, this file.
- Companion index: INDEX.md (anchor) maps all 16 canon files + legacy dir note.
- Upstream skills: goal-prompt, hydra-prompt, engineering-report, zero-trust-audit, script-test, deep-container-testing (workspace skill tree).
- Session id this revision: ses_-ffe5f7414f7e4ffeQ28UjThXK (see memory checkpoint for full trajectory).
- Next reviewer: run the entry checklist yourself before judging this file.
- Gate status at write: density ✓ refs ✓ SHA ✓ (see T11 gate run).
- Amendments welcome as appended sections with dates, never silent edits.
- End of entry sequence. Begin with the 5 baseline checks.

## 2026-09-12 ADDENDUM (post-compaction_xyz state — read first, overrides older lines on conflict)
- Branch: worktree is ON air-drop (e7a3071+); master @ 3d08b40. Return via plumbing (read-tree + hash-object + commit-tree + update-ref with lease); NEVER checkout -f (other sessions' untracked state).
- MacBook: SSH WORKS (key ~/.ssh/forge_macbook → sss@100.115.58.24, Sequoia arm64, NO Xcode yet). Next: toolchain (xcodegen/node/pytest) → clone air-drop → unsigned build (proven flags) → Apple-ID signing (operator screen) → install → smoke → commit back per AGENT_MACBOOK_AIR.md.
- VM: DOWN (volume kept); revive via run-forge-vm.sh up if takes needed.
- Suite 88/88, bundle f06bda2b, keys env-only (2 chat copies pending rotation), firewall OFF per operator order.
