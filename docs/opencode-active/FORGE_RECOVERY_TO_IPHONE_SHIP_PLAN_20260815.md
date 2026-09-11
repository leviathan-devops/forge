# FORGE — RECOVERY → VM FULL E2E VERIFICATION → iPHONE (v2 — the E2E-first plan)

**Written:** 2026-08-15 (v2, supersedes v1) · **Operator directive:** the phone is THE LAST STEP. Before anything ships: the app must be proven 100% functional inside the VM through complete, continuous, real-use E2E runs — not isolated token checks. 
**Order of operations, non-negotiable:**
```
Phase 0  engine recovery          (host)
Phase 1  VM resurrection          (boot + SSH + disk mining)
Phase 2  build gate               (deploy + BUILD SUCCEEDED at restored state)
Phase 3  functional battery       (isolated scenario verification — the parts list)
Phase 4  FULL E2E USE-CASE RUNS   (continuous user journeys — THE GATE)  ← the main event
Phase 5  soak + stability         (sustained mixed usage, crash/memory audit)
Phase 6  iPHONE SHIP              (only after 3+4+5 are 100% green)
Phase 7  close-out                (canon, checkpoint, release re-cut)
```
No Apple ID ask, no USB, no phone step is even MENTIONED to the operator until Phases 3–5 exit green.

---

## 0. STATE (audit digest — verified 2026-08-15, read from ALL docs/checkpoints/specs)

**Solid:** Swift app 59 files/15,884 lines (0 `as!`, 0 `try!`, 0 TODO/FIXME, 0 empty catch) · MC real networking (Bonjour `_http._tcp`, REST+WS PTY w/ byte-level hygiene) · native bridge real (path jail, sandboxed cmds, delegate SSE) · Tahoe 26.6 + Xcode 26.6 previously PASS · policy greps clean (trident-only, free-zen-only, no hardcoded server).

**Broken (fix order):**
- **F1** working-tree `forge-bundle.js` = STUB rebuild (SHA `b26b4e85`, 0 `session:chat`); REAL engine (SHA `48fc7962…`) lives in git HEAD + `checkpoints/working-ui-baseline` (byte-identical). → Phase 0
- **F2** engine TS sources never committed (host `forge/src` = Jul 29 stub era; real sources likely transient on the VM disk). → Phase 1 mining / Phase 4 reconstruction
- **F3** pytest drifted 13/15 · **F4** XCUITest never green on VM (SwiftTerm SPM) · **F5** zero build/behavior evidence at HEAD `c9af561` · **F6** debris (0-byte PNG, stale comments, stub-shipping FORGE_RELEASE). → Phase 4 repairs
- **THE GAP THIS PLAN EXISTS FOR:** no continuous E2E use-case evidence exists anywhere — all prior evidence is per-scenario (S1–S5, D1–D4) or per-feature. A real user session has never been run start-to-finish on record.

**Verified recovery assets:** `git show HEAD:iOS/FORGE/Resources/forge-bundle.js` (real engine, readable esbuild output) · checkpoint byte-identical copy · VM volume `forge-vm-data` intact (256GB).

---

## 1. NEVER-REBREAK LIST (from MACOS_VM_ACCESS, OPERATOR_ACCESS_CARD, forensic log)

1. CPU forced `Haswell-noTSX` — never Penryn, never `${CPU:-…}`.
2. Boot only via `start-tahoe` / `start-tahoe-boot.sh` (OpenCore-tahoe, nopicker preferred). Never stock start-qemu.
3. Exactly ONE QEMU — assert n=1 before every boot.
4. NEVER wipe `forge-vm-data`. NEVER erase guest disks.
5. QEMU never runs as the container's death-pillar (CMD is `sleep infinity`).
6. NEVER disable SIP/AMFI/authenticated-root.
7. Sim-proof profile: `FORGE_GUEST_RAM=6 SMP=4` (RAM=4 provably fails `simctl boot`).
8. Host RAM gate: prune stale containers first — the VM+sim need ~10GB free of the 30GB box.
9. NEVER run the bundle rebuild (pytest test / build-forge-bundle.mjs / xcode-build-phase.sh) on host after Phase 0 — all overwrite the committed bundle from stub-era sources. The trap is host-side only (project.yml does NOT wire the phase into Xcode builds — keep it that way).
10. Any test serve: `NODE_OPTIONS=--max-old-space-size=3584` + `timeout 5400` + RSS watcher (27GB history). Kill at 90 min regardless.
11. No operator VNC login needed for Phases 0–5. Model/agent policy: trident + deepseek-v4-flash-free only.
12. Writes: the FORGE tree + `tmp/evidence/` only. Canon docs 1–4 updated at every milestone.

---

## 2. PHASE 0 — ENGINE RECOVERY & RE-PIN (host-only, ~30 min)

```
cd /home/leviathan/OPENCODE_WORKSPACE/FORGE
mkdir -p tmp/evidence/recovery-20260815
sha256sum iOS/FORGE/Resources/forge-bundle.js > tmp/evidence/recovery-20260815/stub-sha.txt   # record the regression
git status --porcelain > tmp/evidence/recovery-20260815/pre-restore-status.txt
git checkout HEAD -- iOS/FORGE/Resources/forge-bundle.js
# GATE-0a (hard): sha256 == 48fc7962ad5d7f39053061a8a2b75242039d993b5bf062bc9ebcd4de7d037529
#                 grep -c 'session:chat' == 1
```
- Keep the `start-tahoe-boot.sh` display-1 patch in-tree; commit both files: `recovery: restore real engine bundle (48fc7962) + boot patch`.
- **Rebuild-guard surgery (the F1 killer):** rebuild test → temp path + FAIL-on-drift (never write into Resources/); `build-forge-bundle.mjs` refuses to target Resources without `FORCE_BUNDLE_OVERWRITE=1`.

**GATE 0:** bundle SHA exact · driver present · rebuild refuses to overwrite · committed.

## 3. PHASE 1 — VM RESURRECTION + DISK MINING (~20 min)

```
# 1.0 free host RAM: prune stale sandbox containers (keep any actively-used); assert ≥10GB free
# 1.1 FORGE_GUEST_RAM=6 FORGE_GUEST_SMP=4 ./docker/run-forge-vm.sh up   (start-tahoe if QEMU dead)
# 1.2 GATE-1a: QEMU contract n=1 · Haswell-noTSX · OpenCore-tahoe · -m 6000
# 1.3 GATE-1b: ssh -p 50922 user@127.0.0.1 'hostname; sw_vers; xcodebuild -version'  (alpine)
#     → iMac-Pro.local · 26.6 · Xcode 26.6 (17F113) — capture to tmp/evidence/recovery-20260815/vm-alive.txt
# 1.4 MINE THE GUEST DISK (F2): inventory ~/FORGE/forge/src for session:chat>0 sources,
#     the guest bundle SHA, parked trees (~/FORGE.old etc.), DerivedData survivors.
#     If found → scp to tmp/evidence/recovery-20260815/guest-forge-src/ (F2 closed at source level).
```

**GATE 1:** contract holds · SSH green · mining result recorded honestly (found / not-found).

## 4. PHASE 2 — DEPLOY + BUILD GATE (~15 min)

```
./scripts/deploy-to-vm.sh        # EXPECT: tar_ok … XCODEGEN_OK … DEPLOY_OK … BUNDLE_OK
# GATE-2a (the deploy-chain proof): guest bundle SHA == 48fc7962…
# GATE-2b: guest xcodebuild -scheme FORGE -sdk iphonesimulator \
#          -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO clean build
#          → ** BUILD SUCCEEDED ** EXIT=0   → tmp/evidence/recovery-20260815/build-head-restored.log
# 2.4 xcrun simctl boot "iPhone 17 Pro" && bootstatus -b
```

**GATE 2:** DEPLOY_OK · guest SHA exact · BUILD SUCCEEDED · sim booted. Nothing else starts until all four.

---

## 5. PHASE 3 — FUNCTIONAL BATTERY (the parts list — every feature proven in isolation first)

**Recording pipeline (identical everywhere):** guest `simctl io booted recordVideo --codec h264 --force /tmp/<SID>.mp4` for the whole scenario → pull → `ffmpeg -vf fps=2 frames/` → **omni-vision DIRECT mode (base64)** verdicts against the token table. Install pattern: `simctl install` + `SIMCTL_CHILD_*` hooks (`FORGE_START_MODE`, `FORGE_TEST_*` per COMPACTION_SURVIVAL §7).

### 3.1 GROUP M — MODE 1 ENGINE (run FIRST — the F1 closer)
| ID | Drive | passToken | failToken |
|---|---|---|---|
| M1 | `FORGE_START_MODE=onDevice FORGE_TEST_PROMPT="write a small js clock app"` | `Thinking:` orange label → streaming growth ≥3 frames → `✓ write` tool row → expanded write panel with real JS (`setInterval`/`Date`) → `done N file(s)` → footer `trident · deepseek-v4-flash-free` | **`Phase-1 STUB` / `echo only`** = the stub shipped → STOP, re-verify GATE-2a, re-deploy |
| M2 | follow-up prompt "list the files you wrote" | tool rows + real file names | code-in-prose |
| M3 | multi-iteration prompt | ≥2 iterations, alive ≥60s | crash <60s |
| M4 | raw TerminalSheet | renders/echoes (stub banner ALLOWED here) | mirrored garbage |

### 3.2 GROUP V — SURFACE
V1 plain launch (both cards + `v1.0.0`) · V2 palette (`Commands`+`esc`, vanilla sections, no `ctrl+` shortcuts) · V3 model dialog (6 zen models, deepseek default, no paid names) · V4 MC empty fleet · V5 relaunch same mode (new pid).

### 3.3 GROUP C — MODE 2 vs REAL BOUNDED SERVE (host: `NODE_OPTIONS=…3584 timeout 5400 opencode serve --port 8090` + RSS watcher; VM path `192.168.100.7:8090`)
C1 Add-Server via the human-path form hook → green dot + real titles + timestamps · C2 spawn → **server-side count +1 (curl cross-check)** · C3 session chat history + `■ trident · deepseek-v4-flash-free` footers · C4 composer send → in-place streaming (no duplicate bubbles) · C5 swipe=2 pager · C6 Eagle live cards (t1≠t2 10s apart) · C7 PTY first-command clean (the Ctrl-U fix re-verified) · C8 MC palette session list.

### 3.4 GROUP A — ADVERSARIAL (all NEW — none exists at HEAD)
A1 dead port → loud fail + retry, no hang · A2 non-HTTP host → surfaced error + recovery · A3 network-broken Mode 1 → provider error in transcript, no fake success · A4 empty server → clean state · A5 serve killed mid-stream → loud end + reconnect · A6 PTY `exit` → clean teardown · A7 background 60s mid-stream → consistent resume · A8 truncated-bundle scratch install → actionable loader error, never fake-ready.

**Phase-3 exit:** M1 hard-green · C1/C2/C4/C7 green · every scenario has video+frames+verdict.md · all A-group loud-fail behaviors verified. Bugs found → fix loop BEFORE Phase 4.

---

## 6. PHASE 4 — THE FULL E2E USE-CASE RUNS (THE GATE — the main event)

**What makes this different from Phase 3:** continuous, uninterrupted, real-user journeys — one recording per journey, no scripted-hook shortcuts except where the hook IS the user action, real timing, real sequencing, real state carried between steps. This is "a day of using FORGE," on tape. **The app is USED, not probed.**

### JOURNEY 1 — "Build on-device" (Mode 1 complete user flow, ~8–10 min continuous)

| Step | User action | Vision must see (cumulative state carries!) |
|---|---|---|
| 1 | Launch app (plain) | launch menu, both cards |
| 2 | Tap BUILD ON-DEVICE | Mode 1 TUI, session header, composer ready |
| 3 | Prompt: *"create a js dashboard with a clock and 3 stat cards"* | `Thinking:` block streams; status `working · deepseek-v4-flash-free` |
| 4 | Watch (no input) | streaming deltas grow in-place; write panels EXPAND with real code; tool rows ✓ |
| 5 | Follow-up: *"make the stat cards red"* | second iteration; NEW write panel; earlier panels persist |
| 6 | Prompt: *"show me the files you made"* | tool row runs `ls`-class command; output panel with the real names |
| 7 | Open raw terminal (header icon) | terminal sheet renders; `ls` typed by the DRIVER shows the files from steps 3–5 — **the on-device filesystem state is REAL and carried** |
| 8 | Open palette → New session | fresh session, prior transcript gone, header updates |
| 9 | Prompt in session 2: *"what is 2+2"* | normal reply (short-path sanity) |
| 10 | Palette → Switch session → back to session 1 | session 1 transcript RESTORED (persistence proof) |
| 11 | Back to launch menu | clean exit, no crash |

**Journey-1 pass bar:** all 11 steps in ONE recording · file state consistent across steps 5→7 (same filenames) · session state consistent 8→10 · zero crashes/hangs >3s · footer policy tokens throughout.

### JOURNEY 2 — "Run the fleet" (Mode 2 complete user flow, ~8–10 min continuous, against the bounded real serve with REAL workspace sessions)

| Step | User action | Vision must see |
|---|---|---|
| 1 | Launch → MISSION CONTROL | MC empty state, Add Server CTA |
| 2 | Add Server form: name/host/port typed field-by-field (AUTOCONNECT hook types it — same code path) | form fills; on Add → connecting state |
| 3 | Wait | green dot; the REAL fleet session list (real titles, real relative timestamps) |
| 4 | Tap the busiest session | transcript renders with history (Thinking blocks, tool rows, write panels — the same TUI as Mode 1) |
| 5 | Composer: send a real prompt to the remote agent | reply STREAMS (delta-merge); turn footer `■ trident · deepseek-v4-flash-free` |
| 6 | Swipe left | next session's transcript, different content (pager works on real data) |
| 7 | Eagle vision (pinch/icon) | live grid; cards show CURRENT tails; 10s later content differs (t1≠t2) |
| 8 | Open the session's PTY terminal | prompt clean; type `echo forge-e2e && date` → output correct; **first command clean = the F2 fix live** |
| 9 | `exit` the PTY | clean teardown, back to chat |
| 10 | Kill the app, relaunch, enter MC | server REMEMBERED; reconnect automatic; list identical (persistence) |
| 11 | Remove the server | clean removal, back to empty state |

**Journey-2 pass bar:** all 11 steps in ONE recording · every network hop against the real serve (server-side curl cross-checks at steps 3, 5, 7) · PTY byte-clean · persistence proven (step 10).

### JOURNEY 3 — "Daily driver loop" (cross-mode lifecycle, ~6–8 min continuous)

1. Cold launch → Mode 1 → one short generation → **background 60s mid-stream** → foreground: stream either completed or resumed-consistent, no crash.
2. Mode 1 → launch menu → Mode 2 → connect (saved server) → browse one session → back to Mode 1 → session 1 transcript intact (both modes hold state simultaneously).
3. Settings: change model in the dialog → verify footer on next turn reflects it (within the free-zen catalog).
4. Force-quit + relaunch ×2 → state survives.
5. End: `simctl diagnose` + guest log grep (`simctl spawn booted log show --predicate 'process == "FORGE"' --last 15m`) → **zero SIGSEGV/SIGABRT/exceptions** — capture as the journey-3 log evidence.

### E2E EXIT BAR (all mandatory, or it does not pass)
- 3/3 journeys complete, uninterrupted, on tape, vision-verified per step.
- Zero crashes, zero unrecovered hangs, zero fake-success states anywhere in the recordings.
- State-carry proofs green (files across Journey-1 steps 5→7; sessions 8→10; server persistence Journey-2 step 10).
- Server-side cross-checks archived (curl outputs timestamped against the recording).
- The vision model's per-journey narrative matches the step table (no skipped steps, no "approximately").

---

## 7. PHASE 5 — SOAK + STABILITY (~30 min unattended + analysis)

- **10-minute mixed soak:** one continuous recording — MC connected with the eagle grid open (cards polling), one chat open, one PTY open, then switch to Mode 1 and run one long generation — all concurrently where the app allows. 
- **Metrics captured:** guest-side `ps` RSS of the FORGE sim process at t=0/5/10min (no runaway), the serve RSS log (bounded <4GB), `ss -tn state close-wait` on the serve host (<5 — the socket-hygiene bar from NEXT_STEPS Wave A), frame-sampling stability (no rendering regression late in the soak).
- **Exit:** no crash, no leak signature (RSS growth < ~30% over the soak), close-wait <5, recording archived. If the poller pileup shows up (close-wait climbs) → that's the Wave-A backlog firing → fix ServePoller per NEXT_STEPS §8 THEN re-soak.

## 8. PHASE 4/5 SHARED — FIX LOOP + TEST-LAYER REPAIRS (interleaved)

1. **Every battery/E2E bug:** reproduce minimal → root-cause fix → re-deploy → re-run the failed step + neighbors → green → next. 
2. **F3 pytest:** fix the 2 drifted asserts (current a11y ids; `/session` endpoint) → suite green.
3. **F4 UITest:** guest `resolvePackageDependencies` + `build-for-testing`; if SwiftTerm still unresolved, pin explicitly; ONE test green → full class → archive the FIRST green log. (Honest residual if it refuses — the vision E2E is the functional gate, UITest is belt-and-braces.)
4. **F2 sources:** if VM disk mining found them → restore into `forge/src/` + rebuild-parity check; else reconstruct from the readable committed bundle into `forge/src/vendor-recovered/` + RECOVERY_NOTES.md (acceptance = Journey 1 green, byte-parity optional).
5. **F6 debris:** 0-byte PNG, stale comment, FORGE_RELEASE re-cut (or superseded).

---

## 9. PHASE 6 — iPHONE SHIP (ONLY after 3+4+5 all green — the operator's reward)

Per `docs/DEPLOY_DEVICE_RUNBOOK.md` (free Apple ID, zero cost, 7-day profiles):
1. **Operator (2 min):** create THEIR OWN free Apple ID (appleid.apple.com, their phone) — copyresearch111 is dead — and hand the agent the credentials.
2. **Operator (10 s):** plug iPhone into host USB, unlock, tap Trust. **Operator (10 s):** relay the 2FA code when it texts.
3. **Agent:** USB passthrough via QEMU monitor (`device_add usb-host,vendorid=0x05ac,productid=0x12a8` — proven attached Aug 11) → Xcode sign-in (agent drives the GUI; sendkey fallback if VNC input is dead — the tab-drift probe-walk lesson from Aug 12 is in the runbook) → signed device build (`CODE_SIGNING_ALLOWED=YES DEVELOPMENT_TEAM=$TEAM -allowProvisioningUpdates`) → `devicectl device install app` → `devicectl device process launch com.forge.app`.
4. **Operator (10 min):** the on-phone smoke checklist (runbook §SMOKE) — the identical journeys, on the real device.

**GATE 6:** install exit 0 · launch pid · smoke checklist confirmed.

## 10. PHASE 7 — CLOSE-OUT
Canon re-stamp (EVIDENCE_STATE: the battery + journey verdicts with frame refs; BUILD_STATE: restored SHA + UITest first-green; TASK_QUEUE: F1–F6 dispositions; DECISION_CHAIN: the E2E-first ruling + Apple-ID pivot) · new checkpoint `battery-e2e-passed-2026MMDD/` · FORGE_RELEASE re-cut from the verified tree · serve killed, RSS log archived, VM left up for the operator's use.

---

## 11. FAILURE MODES (pre-prepared)
| If… | Then… |
|---|---|
| M1 or Journey-1 step 4 shows the stub banner | Deploy chain broke: re-assert guest SHA, re-checkout, re-deploy. NOTHING else proceeds. |
| `simctl boot` memory fail | 6G profile not applied / host RAM stolen — re-prune, re-assert contract, hygiene-reboot. |
| SSH dead post-boot | ssv-ssh-gate recovery (`run-ssv-ssh-gate.sh`); NEVER reinstall, NEVER wipe. |
| Serve RSS >4GB | Kill + restart bounded + record (the memory plan v3 stays the durable fix). |
| close-wait climbs in soak | Wave-A ServePoller fix executes NOW, then re-soak. |
| VNC input dead during Apple-ID | QEMU monitor sendkey (proven). |
| UITest refuses | Honest residual; vision E2E is the gate. |
| Guest disk has no engine sources | Bundle reconstruction path (acceptance = Journey 1 green). |

## 12. TIMELINE
P0 30m → P1 20m → P2 15m → P3 2–3h (battery+fixes) → **P4 1–2h (the journeys)** → P5 30m soak → P6 30m (after operator hands over Apple ID) → P7 30m. **Realistic single long session; the journeys + soak are the long pole and the ONLY thing standing between the VM and the phone.**

## 13. OPERATOR DEPENDENCIES (entire list — nothing else touches the human)
Nothing until Phase 6. Then: free Apple ID (2 min) · Trust tap (10 s) · 2FA relay (10 s) · on-phone smoke (10 min).
