# CHANGELOG — FORGE iOS (session-by-session)

**Git HEAD (current):** face47374b767c1ddef9903adda903c7ccaff6b3 · **Bundle SHA:** 48fc7962ad5d7f39053061a8a2b75242039d993b5bf062bc9ebcd4de7d037529

---

## SESSION 2026-08-04 (the overhaul — from broken dump to working agent)

### What was accomplished (with evidence)
- **The spec:** extracted 836 frames at 3-5fps from 4 real opencode TUI videos
  (primary agent chat, subagent edit stream, live build, session scroll);
  pixel-measured every design token (bg #131313, violet #875BF5, diff rows
  #1E2F37/#36202A, queued #6E647E/#4E2E7E, Thinking label ORANGE); wrote the
  1262-line normative spec `docs/UI_GAP_ANALYSIS_AND_OVERHAUL_PLAN.md` with
  full SwiftUI implementations + 12 anti-patterns each tied to a shipped bug.
- **The architecture:** ChatStore delta-merging (AP1), LaneRouter (AP4),
  TuiTheme, 15 components. Built + committed c31ebd3.
- **The 4 killer bugs (each diagnosed from real evidence):**
  1. SIGSEGV: `streamDelegates` stored under cbId but removed under streamId →
     leaked a full URLSession per agent iteration. Fix: consistent key.
  2. Dead-screen gaps: WebKit suspend/resume churn (each evaluateJavaScript
     wakes the content process; 66ms = dozens of prepareToSuspend→releaseMemory
     cycles/sec). Fix: 250ms throttle both sides + terminal output gate
     (`__forgeTerminalVisible`).
  3. Code-as-prose: model wrote ```file: blocks as text. Fix: OpenAI function
     calling (write_file/run_command tools) — code travels in tool_calls.
  4. Collapsed write panels: WritePanelView `@State expanded=false` overrode
     the store flag (AP9). Fix: store-driven expanded; plain-text streaming
     render (regex-on-growing-content crashed); highlight once at end.
- **E2E evidence:** Space Invaders alive 110s (was dead at 38s); 33.7MB
  continuous-streaming video; todo build with expanded code panels.

### Key decisions (context)
- Video-first verification (operator: record → frames → vision verdict).
- The free model sometimes writes code in planning text — accepted model
  limitation, not a UI bug.

### What FAILED (root cause — do not repeat)
- **The 1×1 WKWebView frame experiment:** thought a zero frame caused the
  throttling churn; 1×1 made WebKit try to RENDER → crashed at 13s (worse).
  Reverted to `.zero`. The real churn fix was the throttle + gate.
- **66ms throttles:** still crashed at 13s. 250ms was the sweet spot.

---

## SESSION 2026-08-04 (evening — MC real server + popup)

### What was accomplished (with evidence)
- **MC real server:** the operator's directive "PURE NETWORK — serve → connect,
  0 dependencies". Started `opencode serve` on the HOST (the process that later
  became the 27GB catastrophe). Probed the real API from `/doc` OpenAPI:
  GET /session (real shape), POST /session {title,agent,model:{id,providerID,
  variant}}, GET /session/{id}/message, POST /pty, WS /pty/{id}/connect.
  Adapted ConnectionManager + MissionControlClient to the REAL protocol (the
  old `/api/sessions` path returned the web UI HTML — a spec-invented shape).
  Real timestamps threaded (killed the '56y ago' bug).
- **Popup = opencode 1:1:** rewrote CommandPaletteView + DialogModelView from
  the operator's reference screenshots (Commands esc header, sharp corners,
  shortcut column → later removed, SOLID orange selection bar, model rows with
  Free badges).
- **The PTY terminal saga (5 measured byte bugs):**
  1. JSON cursor frames `{"cursor":132}` → strip anywhere.
  2. Resize echo `\x07;24;80t` (BEL + params) → strip.
  3. Literal caret-escapes vs real ESC — `contains("\u{1B}")` FAILED →
     the frame had U+009B (C1 CSI single char) → normalize C1.
  4. CSI split across WS frames → ANSI sequencer buffers partials.
  5. Narrow prompt wrap → initial 80x24 resize + 11pt mono font.
  Result: `leviathan@LeviathanLocal:~/OPENCODE_WORKSPACE$` clean on one line.

### What FAILED (root cause)
- `/ws/session/{id}` (the old spec path) → the real server doesn't expose it.
  The real attach is POST /pty → WS /pty/{id}/connect. (This was the "blank
  terminal" gap.)
- Message pagination probe: `?limit=5` returned an ERROR envelope; v2
  `/api/session/{id}/message` is inert ({items:[],cursor:null}). Still open —
  re-verify on a live serve.

---

## SESSION 2026-08-05 (eagle live + vanilla palette + clean bar)

### What was accomplished (with evidence)
- **Eagle Vision LIVE streams:** SessionThumbnailCard now fetches GET
  /session/{id}/message + polls 8s, renders a miniature live transcript
  (Thinking blocks, ✓/~ tool rows, prose, costs, progress bars). 20MB
  expected-content-length guard → "Large session — tap to open" for the 96MB
  transcripts. VERIFIED: real active sessions stream in the rolodex
  (zai-vision calls, omni-vision tasks, bash commands).
- **FULL vanilla palette:** all 17 Session commands + Prompt (Stash prompt,
  Skills with a real SkillsDialogView) + Agent/System/Workspace; order
  Suggested→Prompt→Session→Agent→System→Workspace; NO keyboard shortcuts
  (operator: iOS isn't keyboard-native); TuiPrefs singleton powers Hide
  thinking / Hide tool details / Show timestamps / Toggle scrollbar /
  Disable code concealment (wired into ThinkingView).
- **Bottom bar clean:** 'swipe = switch' REMOVED (operator: "it's the control
  feature it doesnt need to be written on the screen"), provider removed,
  fixed 26pt height + lineLimit(1). Verified one clean line.
- **Trident-only + free zen:** spawn client → `{agent:"trident",
  model:{id:"deepseek-v4-flash-free",providerID:"opencode-zen"}}`; demo
  sessions recreated as trident/zen; MC display strings → deepseek-v4-flash-free.

### What FAILED (root cause)
- `build · k3` footers: my demo sessions were created with agent "build" +
  paid k3 model. Root cause: I chose the wrong spawn args. Fixed.
- Static video 75%: the session-list modal stayed open covering the swipe/
  eagle phases. Root cause: hooks fired but never closed the modal. Fixed with
  sequenced hooks (list t+6, close t+14, swipe t+20, eagle t+60).

---

## SESSION 2026-08-06 (memory catastrophe + the fix plan)

### What was accomplished (with evidence)
- **Checkpoint + context:** working-ui-baseline saved (59 swift files, 7.8MB,
  manifest with SHAs), BUILD_STATE/COMPACTION_SURVIVAL rewritten.
- **Forensic read + fix plan v1→v2→v3:** the Hermes forensic documented the
  27GB catastrophe (PID 3647685: 17.2GB RSS + 8.8GB swap, 671 threads, 1395
  FDs, 15GB DB, 10 messages with 140-234MB summary.diffs, 309 CLOSE-WAIT to
  forge-vm). KEY: the FORGE app's polling contributed to the socket pileup.
- **v3 plan = the operator's own pattern:** the operator has 12 parallel
  opencodes with zero issues — each is a per-workspace process the OS reclaims
  on exit. v3 = serve-per-workspace + idle-exit + per-unit MemoryMax + V8 heap
  cap (VERIFIED opencode is Node.js → `--max-old-space-size` is real) +
  ARCHIVE (not delete) the giant summaries. NO --pure, NO deletion.
- **Verified in the spec:** GET /session has `directory` + `limit` params;
  GET /session/{id}/message has `limit` + `before` params.

### The honest disclosure
- The serve that powered all the MC demos (8090) is the SAME process that hit
  27GB. It's currently DOWN (killed in the forensic). Restarting it for demos
  must respect the plan (bounded process) or wait for the per-workspace model.
- The v1 plan (--pure + deletion) was WRONG per the operator's no-cripple
  directive; v3 supersedes it.

---

## HONEST DISCLOSURES (known-broken / unverified / embellished)

| Item | Status |
|---|---|
| Eagle cards for >20MB sessions | "Large session — tap to open" by design (not broken) |
| Bottom bar model truncation | cosmetic, accepted |
| Message pagination params | UNVERIFIED (error envelope in one probe) — must re-probe |
| v2 message API | INERT in 1.14.43 — do not use |
| The 27GB serve | DOWN; plan awaiting operator decisions |
| MC terminal WS on the real server | VERIFIED clean (after the 5-byte-bug saga) |
| TestFlight | NOT STARTED (needs operator Apple account) |

---

## APPENDIX C — THE OPERATOR-INTERACTION LOG (what was asked, what was answered)

| Date | Operator asked | Result |
|---|---|---|
| 08-04 | "look at the reference videos and fix the UI" | The 836-frame spec + the full overhaul |
| 08-04 | "the video is static for a full minute then disappears" | SIGSEGV + streaming root causes fixed |
| 08-04 | "build space invaders, demo the menu, demo MC" | Full E2E + menu + MC demos |
| 08-05 | "switching to kimi multimodal... this is 80% there" | Progressive write streaming + header/footer fixes |
| 08-05 | "MC needs the same chat UI as on-device" | RemoteSessionChatView (shared components) |
| 08-05 | "no hardcoded server, show the connect flow" | ServerPickerSheet verified end-to-end |
| 08-05 | "show swipe + eagle vision + multiple new sessions" | Tinder pager + eagle grid + 4 demo sessions |
| 08-05 | "TRIDENT ONLY... NO PAID MODELS" | spawn/display policy enforced (D4/D5) |
| 08-05 | "eagle cards should show the live chat stream" | SessionThumbnailCard mini live transcripts |
| 08-05 | "popup = vanilla 1:1, no shortcuts, bottom bar clean" | full command set + clean bar (D8/D9) |
| 08-06 | "save checkpoint + compaction prep" | THIS prep |
| 08-06 | "how to fix the serve memory like my 12 parallel opencodes" | Fix plan v3 (per-workspace + idle-exit) |

## APPENDIX D — THE NEXT SESSION'S FIRST COMMIT (the suggested starting point)

Wave A commit: `feat: app client hygiene — shared ServePoller + socket
timeouts + background pause` touching ServePoller.swift (new),
ConnectionManager.swift, RemoteSessionChatView.swift, SessionThumbnailCard.swift,
RemoteSessionViewModel.swift. Acceptance: serve close-wait < 5 after 60s MC;
eagle cards still live (t1≠t2). This commit needs NO gate and can ship before
any operator decision.
| All demo "PASS" claims | vision-verified (frames + video), not embellished |

---

## APPENDIX A — THE BUG-FIX LEDGER (every shipped fix, root cause, mechanism)

| Bug | Root cause (the mechanism) | The fix | Regression guard |
|---|---|---|---|
| Word-per-line text | per-delta views in a VStack | ChatStore delta merging into one string per part | ChatModel.swift:156-201 |
| Code-in-prose | text fences parsed post-stream; raw code streamed as prose | OpenAI function calling (write_file/run_command tools) | bundle AGENT_TOOLS |
| SIGSEGV at 38s | streamDelegates keyed cbId, removed streamId → URLSession leak per iteration | consistent streamId key | ForgeBridge.swift:442-448 |
| Static/burst streaming | WebKit suspend/resume churn at 66ms | 250ms throttle both sides + terminal gate | ForgeBridge.swift:460-520 |
| Collapsed write panels | WritePanelView @State overrode store flag | store-driven expanded + plain-text streaming render | TuiComponents.swift:527-566 |
| `^[` PTY garbage | 5 byte-level bugs (JSON frames, BEL echoes, caret-escapes, C1 U+009B, split CSI) | strip/normalize/sequencer chain | RemoteSessionViewModel.swift:144-250 |
| build/k3 footers | my demo sessions spawned with wrong agent/model | trident + opencode-zen everywhere | MissionControlClient.swift:60-70 |
| Eagle blank cards | lastLines nil on the real server | fetch real messages + mini live render | SessionThumbnailCard.swift |
| Static video 75% | session modal never closed in the demo sequence | sequenced hooks (close at t+14) | MissionControlScreen.swift:520-590 |
| 27GB serve | retention + no ceiling + app socket pileup | v3 plan (per-workspace + idle-exit) | plans/FORENSIC_FIX_PLAN |

## APPENDIX B — THE OPERATOR-FACING STATUS SUMMARY

- On-device agent: DONE (function calling, Thinking, expanded writes, stable).
- Popup: DONE (vanilla 1:1, no shortcuts).
- MC: DONE (real server, same-TUI chat, swipe, eagle live, PTY).
- Policy: DONE (trident-only, free-zen-only).
- Memory plan: WRITTEN, awaiting decisions.
- App client hygiene (poller/pagination): NEXT (Wave A/B).
- TestFlight: NOT STARTED.

---

## 2026-08-15 — THE FULL BATTERY SESSION (the app fully verified + hardened)

The zero-trust audit found the working tree had silently regressed the engine to a stub (the rebuild machinery overwrote the committed bundle). Recovery: restored the real engine (48fc7962), guarded the rebuild, realigned the test suite (16/16), then ran the full vision battery in the VM.

**Result:** 26 scenarios (V5/M4/C8/A6) + 3 journeys + soak + FULL-E2E.mp4 (all 65 frames watched) — ALL PASS.

**Bugs fixed (12, all vision-verified):** tail-flush duplication · 7 silent LLM error paths (permanent hangs → loud) · spinnerTimer ReferenceError · double user bubble · MC composer L1 violation (server ■ build → pinned trident) · spawn providerID · OUTPUT-BLINDNESS (agent blind to all command output — the deepest) · PTY label chain (@StateObject root) · connect persistence (server remembered). **Features:** transcript persistence + Continue-last-session resume.

**Operator rulings landed:** the Go endpoint is `https://opencode.ai/zen/go/v1` (verified working with the Go key + deepseek-v4-flash); the free zen tier is 429-exhausted on the guest public sentinel.

**Commits:** 075bbe7 → 3686575 (16). **Checkpoint:** checkpoints/battery-2026-08-15/. **Evidence:** tmp/evidence/battery-20260815/ (VERDICT.md + FULL-E2E.mp4). **Remaining:** the iPhone ship (operator's fresh free Apple ID) + the formal Go run + the backlog (TASK_QUEUE §4).

## 2026-09-11 — Docs/currentness wave (T11): canon + ship refresh, checkpoint refresh, report v5
- Accomplished: 5 ship docs gated (165/51/120/52/55 + SHIP_DOCS_MANIFEST.md); canon RUNNING logs + manifest created; CURRENT_STATE/NEXT_STEPS/TASK_QUEUE/BUILD_STATE/COMPACTION_SURVIVAL/POST_COMPACTION_PROMPT rewritten to anchor-era truth; CHANGELOG/DECISION_CHAIN/EVIDENCE_STATE appended; checkpoint ship-wave-green-t125 refreshed in place (MODE B); report v5 (post-migration diff + meta-analysis + sideload explainer).
- Evidence: gate counts above; bundle f06bda2b unchanged; suite 88/88 re-verified.
- Decisions: canon path = CONTEXT_MANAGEMENT (legacy context_management/ untouched); density floors enforced with real content, gaps named not padded.
- Failures: none (docs pass).
- Honest disclosures: small law/scope docs (AETHER/SCORE/TARGET/INDEX/N9/BUILD_REPORT_2026) left at legacy density — flagged, not faked.
