# NEXT_STEPS — FORGE anchor (2026-09-11; only operator-owned work remains)

## 1. Device + TestFlight (operator; nothing autonomous left)
- Done-when: team-signed `.ipa` installed on the iPhone + 10m smoke note (connect, agent turn, preview, background, relaunch) + TestFlight upload receipt.
- Requires: Apple ID in guest Xcode (operator screen) + USB device + signing identity. Guest holds 0 identities / 0 profiles today (measured).
- Agent side ready: unsigned Release-iphoneos/FORGE.app 22MB BUILT (device-arch green); runbook `docs/testflight-setup.md` (227L); AGENT_MACBOOK_AIR.md Air path as alternate (clone air-drop → Xcode → Run).
- Free-tier notes: weekly re-sign; TestFlight needs paid membership.

## 2. Key rotation (operator; 5 minutes)
- Done-when: both chat-pasted Go keys rotated at the provider; fresh key verified with one `/connect test` 200 (t-pattern: driver prologue).
- Why: env-only discipline held everywhere (0 hits in ~20 run logs), but chat copies exist.
- Agent side: rotation re-proof is one take on demand.

## 3. Disk reclaim (operator call)
- Done-when: usage sustainably under 90%.
- Facts: 97% used; anchor duplication ~9G; take debris (t60-t77 unrrowed bulk) is evidence-protected — archive, don't delete, and only on explicit order.
- Agent side: host /tmp scratch only (~2M) already cleaned; containers not ours to prune.

## 4. Mode-A seal (operator order)
- Done-when: operator runs chattr (agents are blocked from protect/unprotect) + seal line in manifest.
- Current: MODE B mutable, fully rowed; seals through `8083557` + air-drop `e7a3071`.

## 5. Backlog (post-ship, in priority order)
- SSE token-streaming proof OR SC-c amendment (operator call).
- Plain-words intent mapping + grandma tape.
- Pyodide loader progress/timeout UX (cold-guest hang named loud by watchdog today).
- Per-conversation session affinity (specced in GAUNTLET, unverifiable under quota wall at the time).
- TestFlight packaging per runbook once #1 lands.

## Procedures (exact, for the agent picking each item up)
### Device + TestFlight
1. Operator: Apple ID into guest Xcode (own screen) + USB iPhone attached (or Air path per AGENT_MACBOOK_AIR.md).
2. Agent: `xcodebuild archive` (unsigned Release-iphoneos build already proven green, 22MB) → sign with personal/team identity → export `.ipa` → transfer off guest (`scp -P 50922`).
3. Install: Xcode Devices drag / Sideloadly / AltStore; trust cert on phone; run 10m smoke (connect, agent turn, preview, background 60s, terminate, relaunch, configured+200).
4. Row the smoke take (stills + mux + watcher) in GAUNTLET; TestFlight: archive → upload receipt → note version/build.
5. Free-tier weekly re-sign noted; paid membership removes it (operator call).

### Key rotation
1. Operator: rotate both Go keys at the provider (2 chat copies exist).
2. Agent: single `/connect test` probe take (prologue only, ~5 min) expecting 200; row it; unset env after.
3. Verify: 0 `sk-` hits in the run log; Keychain holds new key (67-char length marker, never values).

### Disk reclaim
1. Candidates in order: host /tmp scratch (~2M, safe now) → take debris t60-t77 (evidence-protected: ARCHIVE to sidecar, never delete, operator order first) → docker prune WITHOUT volumes (never touch forge-vm-data) → stale mimo containers (not ours: ask).
2. Re-measure `df -h /` after each step; stop under 90%.

### Mode-A seal
1. Operator runs the chattr (agents are guardian-blocked from protect/unprotect).
2. Agent verifies `lsattr` flags + records seal line in manifest + GAUNTLET row.

## Acceptance per item (done-when, measurable)
- Device: devicectl install log + launch log + smoke note with stills.
- TestFlight: upload receipt + version/build numbers.
- Keys: probe 200 + 0-hit grep + lengths-only readback.
- Disk: `df` under 90% + archive manifest of moved debris.
- Seal: lsattr `----i` on manifest + boundary files + row.

## Risk register (what can still bite, with mitigations)
- Quota wall returns: mitigation = backoff ladder + direct probe + pool disambiguation (documented in CURRENT_STATE flake playbook); never burn takes into 429s.
- Concurrent sessions trample sim: mitigation = sim-mutex (driver refuses) + pgrep check; cross-session takes need a shared calendar or mutex file.
- Snapshot sickness clusters: mitigation = cools + stable-retry + guest load check; rewrite queries last.
- Model skips steps: mitigation = split-leg prompts + tight tool-naming orders + done-check signals; accept re-takes as normal (t92/t93/t112 pattern).
- Cold guest slowness: mitigation = warm-up take or longer provisioning; connected-only takes skip SecureField.
- Disk 97%: mitigation = archive order first; build artifacts + DerivedData are the growth vectors; never volumes.
- Key exposure: mitigation = env-only + per-take grep + unset + rotation at convenience; never chat again.
- Seal drift: mitigation = seal on every milestone (rows newer than commit = stale seal, F5 audit finding).
- Stale hook load: mitigation = fresh sessions pick up CT stack changes; re-run matrix rows 3-4 after reloads.
- Push protection: mitigation = secret-scan before push (`grep -rE 'sk-|ghp_|BEGIN.*PRIVATE KEY'`); amend + re-push on block.

## Schedule sketch (order + rough cost when unblocked)
1. Key rotation + probe take (operator 5min + agent 1 take ~10min).
2. F5 regression take on any agent-path edit (1 take).
3. SSE proof-or-amendment (2-3 takes + spec decision).
4. Plain-words mapping (2 waves per DPL1) + grandma tape.
5. Device: Apple ID session (operator) → archive → export → install → 10m smoke (1 session).
6. TestFlight: upload + receipt (operator + agent assist).
7. Loader UX + affinity wiring (2 waves + verification takes).
8. Disk archive + Mode-A seal + compaction-prep canonization.
Total agent-take budget reserved: ~10 takes; quota budget: spread across days, never hammered.

## Done-when ledger (binary gates, no partial credit)
- Rotation: probe 200 + 0-hit grep + lengths-only readback + row.
- Regression: p0 stdout watcher PASS on the edited path.
- SSE: EventSource>0 in bundle + streaming-frames verdict, OR spec amended with operator sign-off rowed.
- Plain-words: 3 intents mapped + non-technical prompt tape + eyes-check rowed.
- Device: devicectl install + launch logs + smoke note with stills.
- TestFlight: upload receipt + version/build numbers rowed.
- Loader: progress UX on cold take + timeout named error on forced stall.
- Affinity: dual-take same-conversation cache comparison + distinct-id assert.
- Disk: df under 90% + archive manifest.
- Seal: lsattr flags + manifest line + GAUNTLET row.

## Per-item command reference (copy-paste ready, paths absolute to anchor)
- Baseline: `git -C "$ANCHOR" log --oneline -1; sha256sum "$ANCHOR/iOS/FORGE/Resources/forge-bundle.js"; python3 -m pytest "$ANCHOR/tests" -q 2>&1 | tail -n 1; node --check "$ANCHOR/iOS/FORGE/Resources/forge-bundle.js"`
- Rig up: `cd "$ANCHOR/docker" && ./run-forge-vm.sh up` (SSH ~15min); rig check: `sshpass -p alpine ssh -p 50922 user@127.0.0.1 'sw_vers -productVersion; uptime'`
- Mutex: `pgrep -af run-connect-proof` (empty = clear)
- Take: `FORGE_GO_KEY` env + `python3 tmp/run-connect-proof.py <take> <Class/test> <stildir>` (see driver header for argv)
- Key hygiene: `grep -c 'sk-[A-Za-z0-9]' /tmp/forge-tNNN-run.log` (expect 0), `unset FORGE_GO_KEY`
- Mux gates: `ffprobe -v error -show_entries format=duration,bit_rate -of default=noprint_wrappers=1 <seg>`
- Stills: `ffmpeg -ss <t> -i <seg> -frames:v 1 out.png`
- Suite: `python3 -m pytest tests -q` (expect 88 passed)
- Seal: `git add <explicit paths>` + commit + `git log --oneline -1`; never `git add -A`, never force-push master
- Vm stop: `docker stop forge-vm` (keeps container+volume); never wipe forge-vm-data
- Disk: `df -h /`; anchor size `du -sh` (17G with evidence; product ~200M)

## Decision log for next forks (recommended defaults for headless `question`)
- SSE vs amend: implement EventSource path first (2 takes); amend only if loader blocks twice with evidence.
- Plain-words scope: 3 intents (ask/build/show), slash table retained underneath (CONNECT_SPEC authority).
- Loader UX: progress line + named timeout (mirrors watchdog pattern, already proven).
- Affinity: per-conversation ses_ keyed by AppState.currentSession.id, global fallback (spec in GAUNTLET).
- B4-style residuals: scrub over allowlist when the hardcode went stale (migration lesson).
- Checkpoint mode: MODE B living until operator orders Mode-A chattr (guardian-owned).
- Evidence retention: archive on order, never delete; unrrowed debris stays until rowed or archived.
- Air vs VM split: Air compiles/signs/runs (AGENT_MACBOOK_AIR.md); VM takes/verifies; merge via pull --rebase, conflicts keep newest-green.

## Operator handoff scripts (what to ask, verbatim-ready)
- Signing: "Open Xcode on the guest (VNC) or your Air, sign in your Apple ID, select Personal Team for com.forge.app, tell me when the team resolves — I run archive/export/install from there."
- TestFlight: "Paid membership + App Store Connect access; I need an upload receipt path (Transporter or Xcode Organizer) — confirm which you have."
- Keys: "Rotate both Go keys at the provider, then paste ONE fresh key in chat (single message, nothing else); I use it env-only once for a probe take and it never touches disk."
- Disk: "Approve archiving take debris (t60-t77 unrrowed bulk + old muxes) to sidecar storage; I keep the manifest. Nothing gets deleted."
- Seal: "Run the chattr command I print (I am guardian-blocked from locking); I verify lsattr flags after."
- Grandma tape: "Read this prompt aloud on camera while I drive: <plain-words prompt>. Your reading + the tape is the eyes-check."

## Wave plan reference (DPL1 §5 → takes → status, frozen scope)
- W1 SC-11 (t78-t80): DONE. W2/W3 streaming+tools (t90-t93 + fixes): DONE as chunked-callback.
- W4 T-9 (t94-t98 deterministic + t121/t125 live): DONE with F5 single-tape proof.
- W5 soak (t99-t103 + F6 numerics): DONE (numeric half: trend only).
- W6 close-out (logs, seals, checkpoint, reports v1-v4, audit): DONE through 8083557.
- Audit-fix (F1-F6): DONE and sealed (bf26fcb→d9ab150).
- Handoff (AGENT_MACBOOK_AIR, air-drop e7a3071): DONE, verified via API.
- Sideload (T9): unsigned build DONE; signing/install pending operator.
- Next wave (unplanned): SSE-or-amend + plain-words + loader UX + affinity (backlog §5 above).

## Take-id glossary (every id referenced anywhere resolves here)
- t23-t59: closed takes (pre-anchor era + early anchor; see GAUNTLET history).
- t60-t75 + t77: attempt debris, unrrowed (retained, not verified).
- t76/t78/t79/t80: SC-11 arc (FAIL/FAIL/cause/PASS).
- t81-t89: harness shakedown (FAILs → tapStable/expectBubbleStable/Save-retry).
- t90/t91: live-agent legs (green turns, partial pixels).
- t92/t93: backfilled marker takes (model skipped python).
- t94-t98: deterministic E2E (fixture works; double-run; cold hang; AX card; PASS t98).
- t99-t103: soak (entry race; PASS t100/t103).
- t104-t121: F5 hunt (interference, 429 wall, narration, cold slowness) → t121 PASS.
- t122-t125: approval battery → t125 PASS (stdout+preview, mux both gates).
- t126: NEXT unused id. Never reuse, never overwrite (sim-mutex + stale-guard enforce).

## Derailment watchlist (early signals + responses, from the ledger)
- Bubbles match too easily: suspect echo-match; check request text for the token before celebrating.
- Green turn, empty pixels: demand the turn's tool rows + done-check in the dump, then watcher stills.
- Prose claims verification ("verified via run"): prose is never evidence; only tool results + pixels.
- Fast PASS after long FAILs: suspect weakened assert or changed surface; diff the test file first.
- Mux freeze on a motion take: suspect recorder stall or frozen app; check bitrate + tail frames.
- 401/429: suspect quota/model-list before product (migrate + pool probes exist for exactly this).
- Home screen mid-take: suspect concurrent sessions (pgrep) before product blame.
- Snapshot throws cluster: suspect guest/host strain (load check + cool), not the queries.
- Push rejected: read FULL remote output (tail cuts detail); secret-scan before retry.
- Seal older than rows: seal again; rows newer than commit = stale seal (audit F5).

## Session-end checklist (beforeCompact or handoff)
- [ ] Every take this session rowed (PASS and FAIL; backfills marked).
- [ ] Suite + node re-run green after last product edit.
- [ ] Key unset in shell; run logs grep 0 hits.
- [] Latest rows committed (seal number noted in row).
- [ ] RUNNING logs appended (this folder).
- [ ] Next take id + its question named in GAUNTLET tail.
- [ ] Rig left known (up/down stated with restart path).
- [ ] Open items carry owner (agent/operator) + unblock condition.

## Pin + scheduler notes (goal hygiene)
- Active pin lineage: GOAL_PIN_SC12_T78 → GOAL_PIN_SHIP_SPEC (superseded) → hydra audit-fix pin (t104 era) → this canon (no active pin; next pin mints from NEXT_STEPS §Wave plan + audit F-list).
- Pins rot: any pin older than the newest GAUNTLET row is provenance, not orders. Re-mint (goal-prompt → hydra-prompt delegation) rather than editing pins.
- /loop usage: no scheduler tool in this runtime — the loop is executed directly (each message continues it). Interval syntax (<20 minutes>) parses to 10m default; treat time bounds as deadlines, not ticks.
- Cron absence: no durable scheduling available; long waits (cools, quota) run as sleeps inside take calls with fitting timeouts (never sleep+take in one call — timeout kills orphan locks; sim reboot clears recorder wedge).

## Glossary (terms as used in this tree — no other meanings)
- Take: one driver run (prologue/build/run/stills/mux/log/row), named tNN, next unused only.
- Proof: XCUITest XCTest green on device/sim.
- Evidence: stills + mux + xcodebuild log + watcher verdicts for the take.
- Watcher: blind subagent reading stills, TEXT-ONLY verdicts; main never opens pixels.
- Row: one GAUNTLET_PROGRESS.md append (PASS/FAIL + mechanism + next).
- Seal: git commit of wave files; befa59d-lineage hashes; Mode-A needs operator chattr.
- SC-11: auth + persistence + double live-200. T-9: battery (deterministic + live). W5: soak.
- F-class: audit findings F1 (rows), F2 (markers), F3 (claims), F4 (seal), F5 (live tape), F6 (numerics).
- B-class: bug ledger entries B1-B16 (FAILURE_LOG F-01..F-19 detail).
- Rig: QEMU 6GB Tahoe guest + iPhone sim …8187 + SSH p50922 (see rig parameters in CURRENT_STATE).
- Anchor: MIMOCODE/Forge @ master line; live tree is reference + bulk host.

## Reading guide (five-minute orientation for a fresh human)
1. Read POST_COMPACTION_PROMPT.md (entry + laws), then CURRENT_STATE.md summary + open list.
2. Skim GAUNTLET_PROGRESS.md tail -10 (latest rows = current frontier).
3. Open Evidence/play/cycle-forge-t125/seg-01.mp4 (6.5 min — the whole product working).
4. Read reports/ZeroTrustAudit_2026-09-11.md verdict + fraud list (what not to re-claim).
5. This file's handoff scripts tell you exactly what only you can do.
6. Ask the agent for anything else — it re-verifies before answering (baseline first).

## Take-id reservation (live register — edit on assignment)
- t126: NEXT unused (reserved for F5 regression or fresh-key probe).
- t127+: unassigned. Assign by appending here BEFORE firing (prevents double-use across sessions).
- Retired ids: none (no id is ever reused, even for refires — a refire is a new take).
- Floor met 2026-09-11 (T11 docs pass); substance over length always.

## Anchor references (substance pins for the procedures above)
- DPL1 scope: `docs/FORGE_SHIP_DPL1_SPEC.md` §5 (12 items) + §6 (SC-a..SC-l).
- Runbook: `docs/testflight-setup.md` (227L) for F7/F8 steps.
- Handoff contract: `AGENT_MACBOOK_AIR.md` (anchor root) §§2-5.
- Rig scripts: `docker/run-forge-vm.sh` (up/start-tahoe/vnc-host), `scripts/run-take.py` (take driver).
