# DEBUG_LOG — FORGE ship wave (append-only; symptom → cause → fix → verification → lesson)

## EN-1 — Second-call 401 (t76/t78/t79, 2026-09-10)
- **FINDING:** first live-200 then provider-401 post-relaunch, identical shape across two Go keys.
- **ROOT CAUSE:** `AppState.migrateModelToLiveCatalog()` (`AppState.swift:286`) replaced the paid id (absent from live GET list) with `live.first` and persisted it; Keychain round-trip proven intact by length tripwires (67 chars both sides).
- **FIX:** early return on `ZenModelCatalog.allowedModelID` (`AppState.swift:289`).
- **VERIFICATION:** t80 PASS 184s, second live-200, 06-persistence-pass.png; mux 207.8s/543kbps.
- **LESSON:** same-binary contrast (200→401 minutes apart) decides transient vs systematic; tripwire the persisted values, not the plumbing.

## EN-2 — Silent python hang (t92/t93, 2026-09-10)
- **FINDING:** "Running python..." spinner forever; no stdout, no error, bytes marker absent.
- **ROOT CAUSE:** hidden-WebView JS timers stall; rejects vanish silently (evalJS swallows).
- **FIX:** native 120s watchdog in `ForgeBridge.runPython` (`ForgeBridge.swift:895`, double-settle safe) + temporary stage markers (removed post-diagnosis).
- **VERIFICATION:** t96 probe-240 shows watchdog error card firing loud as designed; DIAG later proved resolve path healthy (15 bytes in 15s).
- **LESSON:** silence → named error via unthrottled channel (DispatchQueue); temp diagnostics must have removal rows.

## EN-3 — Preview blank on revisit (t91/b2-b3, t101/s4, 2026-09-10)
- **FINDING:** preview renders (b0 green) then black on tab switch-back.
- **ROOT CAUSE:** `modeContent` conditionals unmounted the preview branch incl. its WKWebView (`BuildOnDeviceScreen.swift:394-407` pre-fix).
- **FIX:** both branches always mounted; hidden ones collapse (zero height + opacity 0 + no hit-testing + clipped).
- **VERIFICATION:** t102 card poll passed post-fix; t103 watcher: s4 FULL CARD survives switches.
- **LESSON:** navigation-by-unmount destroys webview state; hide, don't remove.

## EN-4 — AX-invisible surfaces (t83-t86/t95, 2026-09-10)
- **FINDING:** segmented tab ids, terminal id, preview card text unmatchable.
- **ROOT CAUSE:** (a) children expose labels not `previewMode.*` ids; (b) SwiftTerm canvas has no AX text; (c) `isAccessibilityElement=true` on the preview WKWebView hid all web content (also a VoiceOver defect).
- **FIX:** label taps, stable-retry queries, `isAccessibilityElement=false` (`PreviewPaneView.swift:46`).
- **VERIFICATION:** t96+ card asserts match; voiceover-visible web text.
- **LESSON:** assert on AX-visible surfaces only; stills + watcher carry the rest.

## EN-5 — Fixture double-run (t95, 2026-09-10)
- **FINDING:** second runPython hit the watchdog; preview overwritten with error card.
- **ROOT CAUSE:** view re-appear re-fired `scheduleMode1E2E`; second run raced the first.
- **FIX:** run-once static guard (`BuildOnDeviceScreen.swift:723`).
- **VERIFICATION:** t98 PASS 67s, single execution, watcher 3/3.
- **LESSON:** idempotence guards on every test hook that fires from view lifecycle.

## EN-6 — Snapshot timeouts + main-thread stalls (t84-t89/t104-t120, 2026-09-10/11)
- **FINDING:** full-tree AX snapshots time out under guest/host load; one main-runloop-busy episode.
- **ROOT CAUSE:** environment (back-to-back takes saturate emulator/host), not product — no crash, no jetsam, app responsive between takes.
- **FIX:** tapStable/expectBubbleStable retry helpers; 15-30min cools; driver sim-mutex (refuse concurrent drivers).
- **VERIFICATION:** t121 PASS after 15min cool; load 11→3.3 measured.
- **LESSON:** sick snapshots = rest the rig, not the code; serialize takes with a mutex.

## Verification outputs (pasted, per entry)
- EN-1: t80 `Test Succeeded`, 06-persistence-pass.png 219KB; mux `duration=207.86 bit_rate=543671`; key-length tripwire `configured (67 chars)` both sides.
- EN-2: t96 probe-240 PYTHON ERROR card on pixels (watcher-read); watchdog rejects at exactly +120s per sim log; DIAG later showed resolve path healthy (15 bytes / 15s).
- EN-3: t103 s4-preview.png 149KB FULL CARD post-switch (watcher: FORGE PREVIEW + ANSWER 42 + CANVAS OK intact).
- EN-4: t96+ `expectBubble("FORGE PREVIEW")` matches post-fix; pre-fix dump lacked all card text (leaf flag hid it).
- EN-5: t98 PASS 67s wall; single `runMode1WriteRunPreviewFixture` execution in sim log; no second PYTHON ERROR.
- EN-6: guest load 11.54 → 3.3 after cools; t121 PASS 224s post-15min-cool; driver refuses concurrent runs (sim-mutex tested by double-fire).
