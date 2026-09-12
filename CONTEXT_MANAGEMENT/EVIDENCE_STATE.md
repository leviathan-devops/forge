# EVIDENCE STATE — FORGE iOS (behavioral, vision-verified)

**Git HEAD:** face47374b767c1ddef9903adda903c7ccaff6b3 · **Bundle SHA:** 48fc7962ad5d7f39053061a8a2b75242039d993b5bf062bc9ebcd4de7d037529

**RULE: behavioral evidence only. "It works" is a claim; a frame with the
passToken is proof. Structural greens (build OK) are necessary but never
sufficient. Every entry below cites the artifact + the token that matched.**

---

## 1. THE SHA CHAIN (mechanical truth)

| Artifact | SHA / ref |
|---|---|
| forge-bundle.js (app) | `48fc7962ad5d7f39053061a8a2b75242039d993b5bf062bc9ebcd4de7d037529` |
| Git HEAD | `face47374b767c1ddef9903adda903c7ccaff6b3` |
| Checkpoint manifest | `checkpoints/working-ui-baseline/MANIFEST.txt` (matches above) |
| Earlier commits | c31ebd3 → c65c3fb → a1f51d5 → 94fb41e → 630678a → 31a0a99 → … → face4737 |

---

## 2. BEHAVIORAL EVIDENCE PER SCENARIO (the passToken matched in tool-result
context — vision frames, not free text)

### S1 — On-device agent end-to-end (todo/dashboard build)
- **Artifacts:** `evidence/full-e2e-2026-08-04/` (video 15.3MB + 9 frames),
  `evidence/video/forge-si-final-working.mp4` (33.7MB, 110s alive).
- **PassTokens (matched in vision frames):** `Thinking:` orange label +
  dim italic; `QUEUED` badge; `working · deepseek-v4-flash-free`; expanded
  write panels with visible code (`ctx.fillRect`, `updateClock`, `.stat-trend`);
  `✓ write app.js`; `done 3 file(s), 0 command(s)`; footer `trident ·
  deepseek-v4-flash-free`.
- **FailTokens (absent in final runs):** word-per-line wrapping; duplicated
  paragraphs; mirrored terminal bleed; code-as-prose; `build`/`k3` footers.
- **Verdict: PASS** (vision f003/f015: write panels + completion).

### S2 — Popup menu = vanilla opencode 1:1
- **Artifacts:** `evidence/fixes-2026-08-05/popup-full-vanilla-set.png`.
- **PassTokens:** `Commands` + `esc` header; section headers Suggested/Prompt/
  Session/Agent/System/Workspace; `Stash prompt`; `Skills`; the 17 Session
  commands (New, Switch, Share, Rename, Jump to message, Fork, Compact, Undo
  previous message, Hide sidebar, Disable code concealment, Show timestamps,
  Hide thinking, Hide tool details, Toggle session scrollbar, Show generic
  tool output, Copy last assistant, Copy transcript); NO shortcut column;
  SOLID orange selection bar; `esc to close / enter to select`.
- **FailTokens:** shortcut text (`ctrl+x n` etc.) in rows; `▶` icons;
  "tap outside to close".
- **Verdict: PASS.**

### S3 — MC real-server connect (in-app flow)
- **Artifacts:** `evidence/mission-control-2026-08-05/01-connect-flow.mp4`,
  `02-picker-form.png`, `03-connected-sessions.png`.
- **PassTokens:** Add Server form fields (Name/Hostname/Port/Bearer/TLS);
  green dot `192.168.100.7`; real session titles + real timestamps (`13s ago`,
  `2m ago`, `1h ago`); spawn created a REAL session (server-side verified:
  session count grew — the app's POST /session hit the live server).
- **Verdict: PASS.** (Also: server-side curl evidence of the spawned session
  in the list.)

### S4 — MC session chat = the SAME TUI as on-device
- **Artifacts:** `evidence/mission-control-2026-08-05/05-session-chat.png`,
  `06-swipe-session-chat.png`.
- **PassTokens:** Thinking blocks with orange label; agent output; turn
  footers `■ trident · deepseek-v4-flash-free` (after the trident-only fix);
  message history rendered from the real GET /session/{id}/message.
- **FailTokens:** `■ build · k3 · $0.0000` (present BEFORE the fix — that is
  the regression evidence that D4/D5 closed).
- **Verdict: PASS after fix.**

### S5 — Eagle Vision = LIVE agent streams
- **Artifacts:** `evidence/fixes-2026-08-05/eagle-live-grid.png`,
  `eagle-live-t1.png`, `eagle-live-t2.png`, `eagle-vision-live-streams.mp4`.
- **PassTokens:** card text `✓ zai-vision_analyze_image`; `Thinking: The
  batch keyframe read...`; `trident-omni-vision` tasks; bash commands
  (`cd "/home/leviathan/OPENCO..."`); `Large session — tap to open` for the
  96MB-transcript sessions.
- **Live-proof:** t1 (317,340B) ≠ t2 (316,042B) — cards updated between
  captures.
- **Verdict: PASS.**

### S6 — PTY terminal (real server protocol)
- **Artifacts:** `evidence/mission-control-2026-08-05/` terminal frames;
  `mc-clean10.png` equivalent frames.
- **PassTokens:** `leviathan@LeviathanLocal:~/OPENCODE_WORKSPACE$` on ONE line;
  block cursor after `$`; green dot.
- **FailTokens (each was a measured bug, all now absent):** `^[[8;24;80t`;
  `;24;80t`; `{"cursor":132}`; bare `^[`.
- **Verdict: PASS** (after JSON strip + BEL strip + C1 normalization + ANSI
  sequencer + 11pt font).

### S7 — Bottom bar clean
- **Artifacts:** `evidence/fixes-2026-08-05/bottom-bar-clean.png`.
- **PassTokens:** one line `trident | deepseek-... | 0 tokens | 0% context |
  $0.00`; NO `swipe switch` hint.
- **FailTokens:** wrapped text; the hint.
- **Verdict: PASS.**

---

## 3. WHAT'S MECHANICALLY PROVEN vs MERELY CLAIMED

### Proven (artifact-cited above)
- The 7 scenarios S1-S7 (vision frames + video).
- The build is green (xcodebuild clean build succeeded on the VM).
- The serve-side spawn (server session list grew — curl-verified).
- The PTY byte-level fixes (each mapped to a captured raw frame).

### Claimed but NOT yet mechanically proven (must verify, not assume)
- **Message pagination** (`?limit=20`): one probe returned an error envelope;
  the /doc spec lists the param. UNVERIFIED — re-probe on a live serve.
- **The v2 message API**: inert in probes — do not rely on it.
- **Eagle cards for >20MB sessions**: "Large session" label is BY DESIGN, not
  a bug; the actual page-load path for those sessions is untested (they're
  huge by nature).
- **The memory fix plan v3**: a PLAN (no edits made). The per-workspace serve
  model is untested on this box — it mirrors the operator's 12-parallel
  pattern, which is daily-proven.

## 4. CONTAINER-RUN PROVENANCE (which simulator, which runs)

- All demos: macOS VM simulator (iPhone 17 Pro, iOS 26.5), app
  `com.forge.app`, launched with SIMCTL_CHILD_ env hooks, recorded with
  `xcrun simctl io booted recordVideo`, frames extracted with ffmpeg, analyzed
  with trident-omni-vision (API mode).
- Server: host `opencode serve` (the SAME process that hit 27GB — currently
  DOWN per the forensic; do not restart it unbounded).
- The 2 demo sessions with real prompts: POST /session/{id}/message with
  {parts:[{type:text}], model:{providerID:"opencode-zen",
  modelID:"deepseek-v4-flash-free"}, agent:"trident"} → HTTP 200, messages
  confirmed.

## 5. AUDIT FINDINGS (TRUE stats, not embellished)

- 59 Swift files, ~11,000 lines of app source, bundle 48fc7962.
- The "9/10" and "8/10" vision scores from the EARLY session were single-frame
  artifacts (the video was static) — the operator caught this. The final
  verdicts above are per-phase frame analyses, not single-frame scores.
- The 27GB serve: 17.2GB RSS + 8.8GB swap, 671 threads, 1395 FDs (forensic).
  The app's contribution: polling + test relaunches (the CLOSE-WAIT pileup).

---

## 6. THE NEXT AGENT'S EVIDENCE CHECKLIST

- Before claiming "PASS" on anything new: capture a frame with the passToken
  visible, cite the artifact path, and record it in THIS doc.
- Before claiming the memory fixes work: verify RSS < 2GB per serve, pressure
  full avg10 < 1.0, close-wait < 5, session count identical after restart —
  and record the numbers.
- Never re-cite the early single-frame "9/10" as evidence of the final state.

---

## 7. THE COMPLETE DEMO LOG (chronological — the journey's proof trail)

| Date | Demo | Artifact | Verdict |
|---|---|---|---|
| 08-04 | v4 todo build | forge-tui-v4-todo-e2e.mp4 | PASS (write panels) |
| 08-04 | Space Invaders 110s | forge-si-final-working.mp4 | PASS (alive, streaming) |
| 08-04 | menu demos ×6 | menu-2026-08-04/ | PASS (all dialogs) |
| 08-04 | SI function-calling | si8.mp4 | PASS (tool rows, no prose code) |
| 08-04 | full E2E | full-e2e-2026-08-04/ | PASS (14 phases) |
| 08-05 | MC connect flow | mission-control-2026-08-05/ | PASS (green dot) |
| 08-05 | MC session chat | sw-03-swipe3.png | PASS (Thinking blocks) |
| 08-05 | swipe + eagle | mc-swipe-demo.mp4, eagle.png | PASS |
| 08-05 | eagle LIVE | fixes-2026-08-05/ | PASS (t1≠t2) |
| 08-05 | popup vanilla | popup-full3.png | PASS |
| 08-05 | bottom bar | bottombar2.png | PASS |

## 8. THE MEASURED BUG PROOFS (each fix has its counter-evidence)

- SIGSEGV: sim log `domain:signal(2) code:SIGSEGV(11)` at 12:11:31 → absent
  after the delegate-key fix (110s alive).
- WebKit churn: log showed dozens of prepareToSuspend→releaseMemory cycles →
  absent at 250ms.
- `^[` garbage: frame hex showed U+009B C1 CSI (contains("\u{1B}") false) →
  normalized.
- build/k3: fd2-09 footer `trident · deepseek-v4-flash-free` (the regression
  frame showing the OLD footer was sw-03).
- Static video: the 75%-static complaint → sequenced hooks → eagle video with
  continuous motion (t1≠t2 proves it).

## 9. WHAT THE NEXT AGENT MUST RECORD (before claiming ANY new PASS)

1. The frame or video path where the passToken is visible.
2. The measured number (RSS, pressure, close-wait, response bytes).
3. The SHA of the artifact state.
4. Add the row to THIS doc. No row = no claim.

## 10. THE HONEST REMAINDER (what is NOT proven)

- Message pagination params (probe error envelope — UNVERIFIED).
- The per-workspace serve model on this box (mirrors the operator's proven
  pattern but untested here).
- TestFlight/signing (never started).
- The full vanilla palette SCROLLED to the bottom (17 commands registered;
  the visible fold showed 10 — the rest are in the scroll).
- Eagle cards for >20MB sessions (by-design "Large session" label; the
  full-page load path for those is untested).

---

## 11. THE VERIFICATION PROTOCOL THE NEXT AGENT MUST FOLLOW

1. **Build first:** xcodegen + xcodebuild clean build on the VM (see
   BUILD_STATE §10). A green build is the entry ticket, never the verdict.
2. **Deploy + launch:** install on the iPhone 17 Pro sim, launch with the
   SIMCTL_CHILD hooks for the scenario under test.
3. **Record:** `xcrun simctl io booted recordVideo --codec h264 /tmp/x.mp4`.
4. **Extract frames:** `ffmpeg -i x.mp4 -vf fps=1/5 /tmp/frames/f%03d.png`.
5. **Vision verdict:** trident-omni-vision API mode on the key frames with a
   prompt naming the exact passTokens expected. Record WHICH frame matched.
6. **Write the row:** add the artifact path + the matched token + the SHA to
   §7 of this doc. No row, no claim.

## 12. THE SHA VERIFICATION COMMANDS (for the next agent)

```bash
# The ground truth bundle
sha256sum /home/leviathan/OPENCODE_WORKSPACE/FORGE/iOS/FORGE/Resources/forge-bundle.js
# Must equal: 48fc7962ad5d7f39053061a8a2b75242039d993b5bf062bc9ebcd4de7d037529
cd /home/leviathan/OPENCODE_WORKSPACE/FORGE && git log -1 --format="%H"
# Must equal: face47374b767c1ddef9903adda903c7ccaff6b3
# Checkpoint manifest
cat "/home/leviathan/OPENCODE_WORKSPACE/Shared Workspace Context/Trident_Agent/
  Active_Projects/FORGE/checkpoints/working-ui-baseline/MANIFEST.txt"
```
If any of these disagree with the docs: the docs are STALE — fix the docs
BEFORE building on them (the cross-consistency gate, §5b).

---

## 13. THE FILE:LINE ANCHORS OF THE EVIDENCE (where each proof lives in code)

- Delta-merge proof (no duplication): `ChatModel.swift:156-201` (prose),
  `ChatModel.swift:187-201` (thinking).
- Lane routing proof (code never in prose): `ChatModel.swift:344-403`.
- Streaming proof (250ms, no churn): `ForgeBridge.swift:460-520`,
  `ForgeEngine.swift:203-216` (terminal gate).
- PTY hygiene proof (clean prompt): `RemoteSessionViewModel.swift:144-250`.
- Spawn policy proof (trident/zen footer): `MissionControlClient.swift:60-70`.
- Eagle live proof (mini transcript): `SessionThumbnailCard.swift:20-90`.
- Popup vanilla proof: `CommandPaletteView.swift:100-160`,
  `CommandRegistry.swift:260-280`.
- Bottom bar proof: `BottomStatusBarView.swift:20-60`.
- MC chat = same TUI proof: `RemoteSessionChatView.swift:30-100` (the shared
  MessageView/PartView render).

---

## 14. THE DRAGON LIVE TEST — 2026-08-11 (MC vs a REAL dragon server, 9/9 PASS)

Setup: dragon VM (qemu, /tmp/dragon-vm) rebuilt via the canonical one-command
setup; serve 18792 exposed via hostfwd `0.0.0.0:18792`; FORGE sim (macOS VM)
reaches it at 192.168.100.7:18792 (verified 200). The BUG-016 canon fix
(`opencode/deepseek-v4-flash-free`) made the model actually reply.

| Scenario | Result | Evidence |
|---|---|---|
| 1. Connect + session list | PASS | t8: green dot "192.168.100.7", list = 10 REAL dragon titles w/ timestamps; sim.log `[MC] decoded N real sessions` every 10s |
| 1b. TUI render | PASS | t26: thinking block + assistant reply "OK" + footer `build · deepseek-v4-flash-free · $0.0000` |
| 1c. Eagle vision | PASS | t66: 6 live cards w/ green dots + tool parts (`write /home/dragon/workspace/he...`, `bash chmod +x hello.sh`, output `FORGE_MC_TOOL_OK`) |
| 2. Spawn (trident+zen policy) | PASS | server truth: new session `agent=trident, model={opencode-zen, deepseek-v4-flash-free}`; app list → 11 sessions |
| 3. Add Server picker | PASS | t10: Name/Host/Port(8080)/Token/TLS fields + saved "192.168.100.7:18792" + trash icon |
| 4. Adversarial: dead port 9999 | PASS | red dot + "Connection Failed / Cannot reach 192.168.100.7" + Retry; stable 10s (t12=t22); sim.log `no data from` |
| 5. PTY protocol (app's exact flow) | PASS | POST /pty 200 → WS → echo FORGE_PTY_OK + pwd + ls (hello.sh present!) + exit + DELETE |
| 6. Resilience: kill/restart serve | PASS | green → red dot + "The network connection was lost." + Retry (NO crash) → green + 11 sessions recovered |

FINDINGS:
- F1 (FIXED, dragon side): canon model ID was `opencode-go/deepseek-v4-flash`
  — nonexistent in opencode 1.14.43 (catalog: `opencode/deepseek-v4-flash-free`)
  → every turn stuck silently; setup probe was circular (BUG-016). Dragon
  DEBUG_LOG + CHANGELOG carry the full record.
- F2 (FORGE APP BACKLOG — PTY input pollution): the initial resize
  `\x1b[8;24;80t` echoes `\x07;rows;colst` INTO the shell line buffer — the
  app's FIRST typed command merges with the junk (`bash: syntax error near
  unexpected token ';'`). The app strips the residue visually on receive
  (RemoteSessionViewModel.swift:160-164) but the shell-side pollution
  remains. Suggested fix: after the initial resize, send `\x15` (kill line)
  once the residue frame arrives — verify on the next device test.
- F3 (minor cosmetic): the saved-server port renders "18,792" (grouping
  separator) in the picker list — cosmetic only.

---

## 15. THE HOST-SERVE + FULL-REMOTE-CONTROL WORK — 2026-08-11 (operator: connect THIS session to FORGE)

### The 3 answers (mechanically proven)
1. **How to expose THIS session:** `opencode serve` scopes its session list to
   the serve's WORKING DIRECTORY (serve-per-workspace — the operator's
   12-parallel pattern). The systemd unit `forge-host-serve.service` runs
   `WorkingDirectory=/home/leviathan/OPENCODE_WORKSPACE` + the minimal config
   `/home/leviathan/forge-serve.json` → GET /session = 100 live workspace
   sessions incl. THIS session + FORGE TEST SESSION 1. Port 18791, mDNS on.
2. **RETRACTED + REPLACED — the session-view scoping is `projectID`, NOT the plugin** (2026-08-11 correction): an earlier claim said the trident plugin breaks a serve's session view (stale list). THE ISOLATION MATRIX PROVED THAT WRONG — the plugin is innocent:
   - TEST 1: real config (trident plugin loaded) + CWD=OPENCODE_WORKSPACE → 100/100 live sessions
   - TEST 2: minimal config (no plugins) + CWD=/home/leviathan → the "June-stale" list
   The real mechanism: opencode tags every session with `projectID` = a hash of the
   working directory where it was created; `opencode serve` lists ONLY the project
   of ITS OWN CWD. The "stale" list was the /home/leviathan project's sessions
   (old because the operator's TUI runs from OPENCODE_WORKSPACE). The operational
   rule: ONE serve per project (workspace root) — run it from the directory whose
   sessions you want listed. The FORGE host serve (18791) runs CWD=OPENCODE_WORKSPACE
   → lists the live fleet (projectID 4c83128b…). NO serve-per-workspace
   multiplication — ONE serve, N sessions swiped in the app (operator's pattern).
3. **The DB is shared** (one file per user: ~/.local/share/opencode/
   opencode.db — 16GB, WAL) — the serve reads the same sessions the TUI
   writes. No copy, no sync. The serve-per-workspace CWD is the scope.

### Full-remote-control (the point of Mission Control) — LIVE VERIFIED
The composer + send path (prompt_async) was ADDED to RemoteSessionChatView
(2026-08-11). 4/4 round-trips from the FORGE sim → host serve → FORGE TEST
SESSION 1 (ses_00f34550dffe9mJiyOTvaJBd20), each with the host trident
agent's reply (server-side message table + vision-verified screenshots):
- "Reply with exactly: FORGE_REMOTE_SEND_OK" → FORGE_REMOTE_SEND_OK
- "Second remote send - count to 3" → "1, 2, 3."
- "Third remote send: say FORGE_FINAL_OK" → FORGE_FINAL_OK
- "FINAL6 unique marker: 7+5=?" → "12"
The session list shows FORGE TEST SESSION 1 at the TOP (t8 screenshot).

### App fixes shipped in this work (all build-verified, runtime-verified where noted)
- F1: mDNS dual-browse — `_opencode._tcp` + `_http._tcp` (instance filter
  `opencode-*`) — ConnectionManager.swift:155-235 (the old code browsed a
  type nothing publishes).
- F2: composer + prompt_async send + FORGE_TEST_MC_SEND hook
  (RemoteSessionChatView.swift:106-215, MissionControlScreen.swift:216-229).
- F5: STABLE merge (ConnectionManager.mergeSessions) — in-place patch, new
  sessions prepended — the visible page no longer jumps on every poll.
- F6: identity-based pager re-anchor (MissionControlScreen — currentSessionID
  + onChange) — the page stays on the session the user is viewing even when
  fresh sessions shift every index (the hyper-active fleet pushes new
  sessions into the top-100 every poll).
- F7: send scoped by sessionID (notification guard) — no broadcast.
- Test hooks: FORGE_TEST_MC_JOIN (retry-join by title substring),
  FORGE_TEST_MC_SEND (scoped send through the composer path).

### Honest residuals
- The JOIN hook's visible-page proof is flaky (the fleet's constant churn vs
  the 100-session cap + merge timing) — the FUNCTION is proven (the scoped
  send hits FTS1 only), the visual of the joined page needs the operator's
  device tap (session list → FORGE TEST SESSION 1) for a clean capture.
- Live mDNS discovery needs the operator's iPhone on the LAN (the sim can't
  see multicast across two QEMU user-nets) — the code is build-verified.
- The host serve's memory: 2.3GB RSS at the 100-session load (cgroup-capped
  at 6G with Restart=on-failure — the catastrophe net is active).

---

## 16. FTS1 PILOT + FINAL-BUILD REGRESSION — 2026-08-11 (the operator: "you piloted the forge test session 1?")

- PILOT: YES, on-screen + server-side. 7/7 round-trips from the app composer
  into FORGE TEST SESSION 1 (ses_00f34550dffe9mJiyOTvaJBd20) with host trident
  agent replies (count 20 in the message table). Screenshot t9.2 shows the
  FTS1 page with the exchange rendered (thinking block, replies, footers
  "trident · deepseek-v4-flash · $0.0037").
- F8 (fixed): tapping a session in the "Switch session" list was a NO-OP
  (onSelect ignored the id — just closed the dialog). Now routed through
  selectRemoteSession(id:) — the single navigation path (list, carousel,
  test hooks). THIS was why FTS1 couldn't be reached via the UI.
- F9 (fixed): the pager is now fully id-driven — viewControllerBefore/After
  and didFinishAnimating resolve indices from the session ID instead of the
  host's stored index (which goes stale the moment the list merges).
- F10 (KNOWN EDGE, logged): with the hyper-active host fleet (sessions
  reordering every poll), the pager can still jump to a neighbor after a
  merge. NOT present on the stable dragon server (regression battery clean).
  The list-tap path (F8) re-selects cleanly. Wave backlog.
- FINAL-BUILD REGRESSION vs the dragon server: 4/4 (session list with real
  titles, chat TUI with exchange + composer, eagle grid with live tool
  outputs, adversarial Connection Failed + Retry) + spawn (server truth:
  new trident-agent session at 2026-08-11T14:01:38Z).

---

## 17. F10 RESOLVED + THE DEFINITIVE PILOT CAPTURE — 2026-08-11

- The FTS1 page held across THREE captures (t9.2/t16/t30) through multiple
  fleet merges — the identity anchoring (F8 selectRemoteSession + F9
  id-driven pager + onChange re-anchor) now holds. The earlier "jumps" were
  the join-to-a-nonvisible-page + stale-index window; the id-driven path
  eliminated them. The FULL exchange rendered on screen: test → trident
  identity reply (thinking block + footer trident · deepseek-v4-flash ·
  $0.0037) → FORGE_REMOTE_SEND_OK → 1,2,3 → FORGE_FINAL_OK ×2 → 7+5=? → 12
  → FINAL_ROUND ×2 → PILOTED_OK ×2. Composer + green dot live throughout.
- Instrumentation (os.Logger) confirmed: join found FTS1 at index 6 after a
  fleet reorder; no spurious pager switches; the page stayed FTS1.
- 8/8 remote-control round-trips into FORGE TEST SESSION 1, server-side
  message table as ground truth.
- Soak monitor started: /tmp/opencode/soak.log (host serve RSS/FDs/threads
  every 5 min, nohup) — cgroup MemoryMax=6G remains the hard net.

---

## 18. F2 FIXED + DEVICE BUILD VERIFIED — 2026-08-11

- F2 (PTY first-command corruption): the resize echo residue ("\x07;rows;colst")
  landed in the shell's line buffer. FIX: RemoteSessionViewModel sends a one-time
  Ctrl-U (\x15) after the first residue frame — kills the junk line inside bash.
  VERIFIED against the real dragon server: resize → residue → Ctrl-U → the first
  command runs clean (output shows the junk backspaced away, no "syntax error").
- DEVICE BUILD: xcodebuild -sdk iphoneos -destination 'generic/platform=iOS'
  CODE_SIGNING_ALLOWED=NO → BUILD SUCCEEDED, FORGE.app for Debug-iphoneos.
  The app compiles for a real iPhone (untested on-device: keyboard, WiFi,
  mDNS, memory profile).
- SHIP STATE (honest): NOT TestFlight-ready — needs the operator's paid Apple
  Developer identity (the VM knows copyresearch111@gmail.com as the Apple ID)
  + an Archive → Distribute → App Store Connect flow + a real-device smoke
  test. Everything code-side that can be proven without a device is proven.

---

## 19. THE GUI LOGIN + THE DISPLAY SAGA — 2026-08-11 (the operator: "set this up correctly... and sign in")

### The recovery chain (all verified)
1. The display slept (pmset sleep 10) → the vmware-vga scanout blacked; every
   reboot re-entered black (the guest rendered — the login screen verified via
   the QEMU screendump pixels — but the VNC capture AND input both died at the
   qemu level).
2. My container-test setup attempt DESTROYED the forge-vm container (name
   collision — recreated from the sandbox image). Recovered: docker rm +
   recreate from macos-forge:master + the forge-vm-data volume (the 256GB
   disk INTACT).
3. The OpenCore picker silently waited (the nopicker variant now auto-boots —
   start-tahoe-boot.sh prefers OpenCore-nopicker.qcow2).
4. The OVMF vars (the guest's UEFI NVRAM) restored pristine EVERY boot (the
   boot script patch — SIGKILLs had corrupted them).
5. THE LOGIN: `user console Aug 11 21:50` — via the QEMU MONITOR sendkey
   (the only live input: the VNC input + the monitor mouse are BOTH dead).
   Password verified correct: `dscl . -authonly user alpine` → rc=0.
6. SSH "alpine" works through an agent-installed gate (run-ssv-ssh-gate.sh —
   its own auth layer), NOT the macOS account — hence the confusion.

### The live tooling (for the next session)
- VISION: the QEMU screendump (`docker exec forge-vm python3 -c "<socket to
  127.0.0.1:4444; sendkey/screendump>"`) + the ASCII-map rendering (20px +
  5px cells via the container python — NO PIL needed).
- INPUT: ONLY the monitor `sendkey` (single-key per exec — the multi-key
  loops + the mouse verbs are firewall-flaky but the single sendkey passes).
- The login field at (960,975) — the default focus meant the keyboard alone
  logged in.
- Xcode is OPEN; the Settings window + the Accounts toolbar located; the
  sheet not yet opened (the + click + the Tab-nav attempts pending).

### The honest remainder
The Xcode account sign-in (Apple ID + 2FA — the operator's phone code) needs
the form: the keyboard-only Tab navigation through the Settings continues
next session. The 2FA code from the operator is required regardless.

---

## 20. THE 2026-08-15 FULL BATTERY (vision-verified — 26 scenarios, 3 journeys, soak)

**HEAD at battery:** c9af561 → 626ca8a (8 fix commits) · **Driver model:** nemotron-3-ultra-free (deepseek guest quota 429'd — see §D-MODEL in VERDICT.md)
**Verdict doc:** `tmp/evidence/battery-20260815/VERDICT.md` (the full table) · 55 evidence files (frames + J1.mp4 45.8MB + J2.mp4 12.6MB)

**Groups:** V 5/5 · M 4/4 · C 8/8 · A 6/8 (A7/A8 code-covered honestly) · Journeys 3/3 · Soak PASS (RSS stable, close-wait 7, 0 crashes)

**Bugs fixed (9, all vision-verified):** tail-flush duplication · silent error paths ×7 · spinnerTimer ReferenceError · double user bubble · L1 composer agent=build violation · spawn providerID · PTY connect race · hook guard gaps · **OUTPUT-BLINDNESS** (the agent was blind to ALL command output — the deepest find).
**Feature:** transcript persistence — sessions restore full transcripts on switch + Continue-last-session resume.

**D-MODEL:** deepseek-v4-flash-free 429'd all day on the guest's public sentinel (likely daily cap); engine proven model-agnostic with nemotron/laguna; host serve's auth has deepseek quota (server-side drives proven). Formal deepseek run = re-run M1+J1 with `SIMCTL_CHILD_FORGE_API_MODEL=deepseek-v4-flash-free` on quota reset, or operator's zen key in Settings.

**Follow-ups (not blocking):** J1-L7 edge — mid-stream-killed turns lose partial content (persist is per-completed-turn); V3 model dialog ctrl+a/ctrl+f hint leftovers; 0-session serve unfabricatable on shared DB (A4 code-covered); A7 no simctl background API; XCUITest SwiftTerm SPM still unresolved on VM (vision battery is the functional gate).

## N9 evidence (2026-08-29)
- muse /responses + public sentinel: OK (resp_6a91b610…; incomplete only from 16-token cap).
- muse /chat/completions: 500 ×6 (both auths, stream both) — zen converter broken for muse.
- CLI proof: ~/.local/share/opencode/log/2026-08-28T162008.log → url zen/v1/responses.
- Bundle: 81,367 bytes; openai branch @~53344; /responses hits pre-patch: 0.
- vil-e2e2.mp4 (233s) full verification PASS earlier this session; report delivered in-chat.

## N10 Wave-1 evidence (2026-08-30, wave-1788700739744-496a25) — PASS
- gate-verify: OR-1 eq 1 (BuildOnDeviceScreen:173), OR-2 eq 2 (ChatModel:611+620),
  OR-3 ge 1 (MissionControl:370), OR-4 eq 1 (ConnectionManager:265), node --check 0,
  bundle 84,879B, occurrences 2/2/2 — pasted evidence block in wave return.
- vm-build-install: serve 000→200 (bounded restart); Tahoe 26.6.2 25G83;
  BUILD SUCCEEDED exit 0; install exit 0 + listapps Bundle; prime 4×200/69,046B
  (3.31s → 0.015s warm); installed bundle sha 4a237c4d… == host (re-verified).
- Audit: FORGE/.trident/wave-audit/wave-1788700739744-496a25.md — both CORRECT.

## N10 Wave-2 evidence (2026-09-06, wave-1788702091778-3fe71a) — FAIL verdict, CORRECT agent
- `FORGE/tmp/evidence/n-work/tapeA/tapeA-take2.mp4` 316.41s/10.5MB/1965 frames +
  `tapeA.mp4` take 1 306.66s + `frames/` 316 PNGs + `VERDICT.md` 79 lines.
- Law-1: COUNT=316, MAGIC_MISMATCHES=0, SHAs first/mid/last/tape ledgered,
  `/tmp/tapeA-verify.py` EXIT=0. Trap diff 5286B (text, not marching — not claimed).
- Beats: title PASS (c0212 read first-hand by orchestrator), kimi footer PASS,
  Eagle PASS, ledger PASS; duration FAIL, preview FAIL, deck FAIL, list INCONCLUSIVE.
- Prime: host 200 0.147/0.016s, VM 200 0.072/0.031s, 69034B ×4.

## N10 Wave-3 evidence (2026-09-06, wave-1788706433739-cb739c) — both CORRECT
- Trigger: ChatModel:611 `lastPathComponent` fix + markers (3+4 hits, re-verified by
  me); AppState untouched; `git diff` +13/+2 source-only (+12 MC).
- MC: `grep -c SIMCTL_CHILD_` MissionControlScreen = 0 (re-verified by me — E1);
  deckCounter at :634 (verified); battery `/tmp/opencode/wave3-hook-deck-tests.test.ts`
  14/0 re-run BY ME identical; mutation 13/1 B1-red claimed consistent.
- Join-path intended bypass (249-253); F1 trap found+routed; D1 widen 300–360s recorded.

## 2026-09-11 — T11 docs evidence (append)
- Ship gates: BUILD_REPORT 165, DEBUG_LOG 51, FAILURE_LOG 120, SPEC_VIOLATION_LOG 52, TESTING_LOG 55+ lines + SHIP_DOCS_MANIFEST.md (baseline SHA f06bda2bfabeedd6).
- Canon: RUNNING_BUILD_LOG + RUNNING_DEBUG_LOG created (4 entries each); CANON_MANIFEST.md created; 6 docs rewritten to anchor truth.
- Verification: bundle SHA unchanged (f06bda2b), suite 88 passed re-run, anchor HEAD recorded.
- Summary: docs describe the sealed state (master 3d08b40 line); no drift introduced by this pass.
