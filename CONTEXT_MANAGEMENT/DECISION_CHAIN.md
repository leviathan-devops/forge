# DECISION CHAIN — FORGE iOS (operator rulings VERBATIM, canon)

**Git HEAD:** face47374b767c1ddef9903adda903c7ccaff6b3 · **Bundle SHA:** 48fc7962ad5d7f39053061a8a2b75242039d993b5bf062bc9ebcd4de7d037529

**RULE: these are canon. Never paraphrase. Never re-litigate. When the operator
refines a ruling, ADD an addendum below the original — never edit the original
words.**

---

## D1 — THERE IS NO "NEXT SESSION"; fix everything NOW
- **Verbatim:** "SHUT THE FUCK UP AND NEVER SAY ANY STUPID SHIT LIKE THIS
  AGAIN THERE IS NO 'NEXT SESSION' EVERY BUG MUST BE FIXED *NOW* GET THIS
  FUCKING SHIP READY WHY THE FUCK ARE WE WASTING TIME"
- **Context:** I proposed "save this as a known-bug baseline and tackle it in
  the next session" about the streaming bugs. The operator's response killed
  that framing permanently.
- **Why:** bugs compound; the operator wants a shippable product, not a
  bug-filed product.
- **Alternatives rejected:** deferring bugfixes to later sessions.
- **Implication:** every discovered bug is fixed in the current pass. Period.

## D2 — The TUI must look EXACTLY like opencode
- **Verbatim (on the spec doc):** "make sure this doc is AS DENSE AND DETAILED
  AS POSSIBLE W/ FULL EXAMPLES, ANTI PATTERNS, AND STEP BY STEP HOW TO BUILD
  IN SWIFTUI PROPERLY so deepseek doesnt get confused"
- **Verbatim (on the reference videos):** "THIS IS *LITERALLY* EXACTLY WHAT
  THE FORGE TUI SHOULD LOOK LIKE. SAME MECHANICS, SAME COLORS, SAME
  EVERYTHING JUST SIZED DOWN TO FIT INTO AN IPHONE DISPLAY"
- **Why:** the reference videos (4 screencasts → reference-frames/) are the
  ground truth for the UI.
- **Implication:** any UI deviation from the reference needs operator approval.
  The spec doc is normative.

## D3 — Vision in the loop, video-first verification
- **Verbatim:** "record FULL e2e videos of functionality and then process the
  videos with the omni vision tool" / "this is more efficient at seeing the
  real time status of the build than images and better for vision in the loop
  engineering"
- **Why:** static screenshots lie (a frozen frame looks fine); video frames +
  vision verdicts reveal the real behavior.
- **Implication:** every demo = video → frames → vision verdict per phase.

## D4 — TRIDENT-ONLY AGENT
- **Verbatim:** "THE ONLY AGENT SHOULD BE TRIDENT I HAVE EXPLICITLY SAID WE
  ARE REMOVING THE VANILLA PLAN/BUILD AGENT AND ONLY WIRING TRIDENT AS THE
  AGENT"
- **Context:** the MC chat footer showed `■ build · k3 · $0.0000` from my demo
  sessions.
- **Why:** the operator's fleet runs Trident; vanilla agents are noise.
- **Implication:** spawn = agent:"trident" everywhere. Grep-clean.

## D5 — FREE ZEN MODELS ONLY, DEEPSEEK DEFAULT
- **Verbatim:** "ALSO WTF IS THIS K3 MODEL *NO* PAID MODELS RIGHT NOW THERE
  SHOULD ONLY BE THE FREE ZEN MODELS W/ DEEPSEEK AS THE DEFAULT"
- **Context:** the same footer showed a paid Kimi model.
- **Why:** cost + consistency; zen free is the operator's free tier.
- **Implication:** spawn/display = deepseek-v4-flash-free / opencode-zen.
  Server HISTORY may show other models (real data — untouched).

## D6 — No hardcoded server; show the real connect flow
- **Verbatim:** "make sure you dont hardcode my server. how does the actual
  connect feature work from inside the app?"
- **Why:** the app must connect the way a user does — the Add Server form.
- **Implication:** FORGE_TEST_SERVER is a TEST HOOK that drives the SAME code
  path (fills the form + taps Add Server). Production connect = ServerPicker.

## D7 — Eagle cards must show the LIVE chat stream
- **Verbatim:** "in the visual preview of the session though should be a
  miniature live stream of the actual chat tui in that session itself so i
  can see the active chat stream/agent loop of that session from the kanban
  rolodex idk if that isnt coded correctly or all the sessions are just
  inactive or both but that is key"
- **Why:** the rolodex is the operator's monitoring surface; blank cards are
  useless.
- **Implication:** SessionThumbnailCard = mini live transcript (fetch + poll).
  It was BOTH (wrong source field + inactive sessions) — fixed.

## D8 — Popup = vanilla opencode 1:1, no keyboard shortcuts
- **Verbatim:** "on the menu there are a few missing features from the vanilla
  pop up menu that are obvious and the categories are not 1:1 fix this" +
  "we dont need to have the keyboard shortcuts on the iOS version since this
  is not a keyboard native env. remove those. clean up the pop up menu so it
  reflect vanilla opencode 1:1 - look at the section of the codebase that has
  the pop up menu and copy all of it so all of it is there"
- **Implication:** full 17-command Session set + Prompt/Stash/Skills + order
  Suggested→Prompt→Session→Agent→System→Workspace + NO shortcut column +
  orange selection bar.

## D9 — The swipe hint is the control, not a label
- **Verbatim:** "the 'swipe = switch' does not need to actually be written
  into the bottom that is the control feature it doesnt need to be written on
  the screen and its causing the text rendering of everything else ot be
  squished. remove it"
- **Implication:** bottom bar = metrics only; fixed height; no hint text.

## D10 — "switching to kimi multimodal" (the vision/analysis model note)
- **Verbatim:** "switching to kimi multimodal - watch this video directly
  extract keyframes 5 fps"
- **Context:** the operator switches the ANALYSIS model between deepseek/kimi/
  glm for vision tasks. The APP model policy (D4/D5) is separate and fixed.
- **Implication:** the app never uses kimi; the operator's tools may.

## D11 — The 12-parallel model is the memory answer (no-cripple)
- **Verbatim:** "how can we make this function exactly like my normal host
  opencode environment w/ built in memory management without needing to
  cripple this or be stupid with it" + "i have like 12 parallel opencodes rn
  and never have any issues with it"
- **Context:** after the 27GB serve catastrophe forensic.
- **Why:** the operator's daily pattern proves per-workspace processes +
  OS-reclaim-on-exit is the correct memory model.
- **Implication:** v3 plan = serve-per-workspace + idle-exit. NO --pure
  (plugins stay), NO deletion (archive only). This supersedes my v1 plan.

## D12 — "no edits - just plan"
- **Verbatim:** "no edits - just plan" (on the memory catastrophe)
- **Context:** the operator wanted analysis before any change to the host.
- **Implication:** the fix plan is a plan awaiting approval. App-side P2 work
  (poller/pagination) is code, not host-ops, and is not gated by this.

## D13 — Save checkpoint + update context on milestones
- **Verbatim (repeated):** "save the current checkpoint and update the
  context docs" / "update the context with the current status and then save
  the checkpoint"
- **Implication:** every material milestone → checkpoint + canon docs. This
  compaction prep is the current instance.

## D14 — "ok this looks pretty solid now" (state approval)
- **Verbatim:** "ok this looks pretty solid now. update the context with the
  current status and then save the checkpoint"
- **Context:** after eagle live + vanilla palette + clean bar.
- **Implication:** the UI/app surface is APPROVED as solid. The remaining work
  is the memory plan + app client hygiene + TestFlight.

---

## FROZEN-CLARIFICATION ADDENDA (refinements added later)

### A1 (on D1): the "working-ui-baseline" framing
The operator accepted the baseline name and checkpoint discipline — "this is
finally some tangible improvement make sure everything is proeprly saved".
The baseline is the frozen reference for the UI.

### A2 (on D4/D5): the demo sessions must be trident/zen
After the footer showed build/k3, the operator's fix demand included my demo
data: demo sessions were recreated as trident + deepseek-v4-flash-free. Data
you CREATE must follow the policy; data that EXISTS on the server (other
sessions' history) is real and untouched.

### A3 (on D11): the forensic's `--pure` suggestion is REJECTED
The forensic (Hermes) suggested `--pure` for the serve. The operator's
no-cripple directive overrides: plugins stay. The v3 plan removes `--pure`.

### A4 (on D11): `NODE_OPTIONS=--max-old-space-size` is VALID
Verified: opencode is Node.js (`#!/usr/bin/env node`) → the V8 heap cap is a
real memory-management tool. Bun assumptions would have been wrong.

---

## CONTEXT ADDENDA (the situation behind each ruling — so the next agent
understands WHY the operator said it)

### On D1 (no next session)
The streaming bugs produced a video that was "static for a full minute and
then everything disappears". I proposed deferring. The operator's response
was the no-session-boundary law. The lesson: when a demo looks broken, FIX IT
in that pass — the operator's patience is for shipped fixes, not bug lists.

### On D2 (TUI = opencode exactly)
The reference videos showed the gap: the app looked like a terminal dump vs
opencode's structured components. The operator gave the 4 screencasts as
ground truth. The spec doc (1262 lines) was written to make the builder
(deepseek) unable to be confused. Every pixel-level decision traces to a
frame.

### On D4/D5 (trident-only + free zen)
The MC footer showed `■ build · k3 · $0.0000` — my demo sessions were spawned
with agent "build" and a paid model. The operator's response is the policy.
Note the distinction: DATA YOU CREATE must follow the policy; the server's
EXISTING session history is real and untouched.

### On D11 (12-parallel model)
The forensic suggested --pure + deletion. The operator's question ("how can
we make this function exactly like my normal host... without crippling") and
the 12-parallel fact reframed the answer: the memory model that already works
is per-workspace processes + OS reclaim on exit. v3 is that model automated.

### On D12 (no edits - just plan)
The operator wanted analysis before touching the host. The plan v1→v2→v3
progression: v1 (--pure + deletion) was rejected by the no-cripple directive;
v2 (single-serve hardening) was superseded by v3 (per-workspace) once the
12-parallel evidence landed.

## THE RULINGS THE NEXT AGENT MUST NOT RE-LITIGATE (summary)

1. No session boundaries — fix everything now.
2. The TUI matches the reference videos exactly.
3. Trident-only agent, free-zen-only models, deepseek default.
4. No hardcoded server — the Add Server form is the connect path.
5. Eagle cards show LIVE chat streams.
6. Popup = vanilla 1:1, no keyboard shortcuts.
7. The swipe hint is the control, not a label.
8. Memory = the 12-parallel model (per-workspace, no-cripple, archive not
   delete).
9. No edits to the host without a plan + approval.
10. Checkpoint + context docs at every milestone.

---

## THE FILE:LINE ANCHORS OF THE DECISIONS (where each ruling is enforced)

- L1 trident-only: `MissionControlClient.swift:60-70` (spawn body),
  `CommandRegistry.swift:20-30` (session.new agent), MC footer strings in
  `MissionControlScreen.swift:70-90`.
- L2 free-zen-only: `MissionControlClient.swift:60-70` (model ref),
  `AppState.swift:241` (default), `DialogModelView.swift:38-51` (catalog).
- L3 no-hardcoded server: `ServerPickerSheet.swift:123-143` (addServer),
  `ConnectionManager.swift:99-116` (test hook only).
- D8 popup vanilla: `CommandRegistry.swift:260-280` (entries order),
  `CommandPaletteView.swift:100-160` (no shortcut column, orange bar).
- D9 bottom bar: `BottomStatusBarView.swift:20-60` (no hint, fixed height),
  `MissionControlScreen.swift:84-92` (no hint param).
- D7 eagle live: `SessionThumbnailCard.swift:20-90` (mini transcript),
  `SessionThumbnailCard.swift:140-175` (poll).
- D11 memory model: the plan file only (no code yet — gated).

## THE DECISION TIMELINE (dates the rulings were made)

- D1: 2026-08-04 (streaming bugs turn)
- D2: 2026-08-04 (spec + reference videos turn)
- D3: 2026-08-04 (E2E video turn)
- D4/D5: 2026-08-05 (MC footer build/k3 turn)
- D6: 2026-08-05 (MC connect turn)
- D7: 2026-08-05 (eagle rolodex turn)
- D8/D9: 2026-08-05 (popup + bottom bar turn)
- D10: 2026-08-05 (kimi multimodal turn)
- D11: 2026-08-06 (memory catastrophe turn)
- D12: 2026-08-06 (forensic turn)
- D13/D14: 2026-08-05/06 (checkpoint discipline + solid-state approval)

---

## 2026-08-15 ADDENDA (the battery session rulings)

1. **THE GO ENDPOINT RULING (operator, verbatim correction):** the working OpenCode Go endpoint is `https://opencode.ai/zen/go/v1` — NOT `/zen/v1`. The Go key returns HTTP 200 there with `deepseek-v4-flash`. My earlier "insufficient balance" finding was the WRONG endpoint. The app's engine hits `https://opencode.ai/zen/v1` by default (ForgeEngine.swift:351) — override via `FORGE_API_BASE_URL=https://opencode.ai/zen/go/v1` for Go.
2. **The serve's zen provider id is `opencode`** (verified live — "opencode-zen" and "zen" return ProviderModelNotFoundError on message runs). All spawn/send bodies use `providerID: "opencode"` (commits bf3bbf2).
3. **Trident-only is enforced on every app-originated path** (spawn + composer send both pin agent=trident). The `■ build` footer seen on 2026-08-15 was the SERVER's default agent answering an unpinned send — fixed; the fleet's history (trident_build etc.) is real server data rendered faithfully, per the standing "server history is real data" rule.
4. **The Apple-ID pivot:** copyresearch111@gmail.com is a dead account (its 2FA never reaches the operator). The device-ship path uses the operator's OWN fresh free Apple ID (to be created at ship time). The VM GUI sign-in is agent-driven (sendkey fallback, Aug-12 display saga).
5. **The rebuild-guard law (F1):** `iOS/FORGE/Resources/forge-bundle.js` is a COMMITTED engine artifact. `build-forge-bundle.mjs` refuses to overwrite it without `FORCE_BUNDLE_OVERWRITE=1` (use `--out <path>` for parity builds). Never run the rebuild on host casually — the stub-era forge/src would produce a stub (F2: engine sources were never committed; reconstruct from the committed bundle if needed).
6. **The serve-bounding law:** any test serve runs with `NODE_OPTIONS=--max-old-space-size=3584` + `timeout 5400` (the 27GB catastrophe history). No unbounded serve, ever.

### D-N9-1 (2026-08-29): muse default requires engine-level /responses support
Zen serves muse free ONLY via /responses; engine bundle is chat/completions-only; forge/src is a
stub so the fix is a surgical patch to the committed bundle (never a rebuild — F1 guard).
Chosen: 3-edit patch (museMode URL/payload branch + museSseToChat SSE translator). Rejected:
paid models (operator ban), host relay (breaks on-device story), rebuild-from-stub (regression).
### D-N9-2: Eagle/MC tape timing — chain MC hold 75s (EAGLE set) + Eagle hook +32s, else Eagle
fires after the chain navigated away (old +60 vs 48s hold). Verified against hook table.

## 2026-09-11 — Canon lives at CONTEXT_MANAGEMENT (legacy context_management/ frozen)
- Context: two canon-looking dirs exist; legacy one predates the anchor.
- Ruling: all canon maintenance targets CONTEXT_MANAGEMENT/; legacy dir is read-only provenance, never edited, never deleted.
- Rationale: single source of truth; history preserved without confusion.
