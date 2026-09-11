# FAILURE_LOG — FORGE ship wave (append-only derailment ledger)

### F-01 — Second-call 401 (t76/t78/t79)
- **What happened:** first live-200 then provider-401 post-relaunch, identical shape across two Go keys.
- **Found:** t76 tail frames + t78 same-shape repeat + t79 key-length tripwires (67 chars both sides, Keychain exonerated).
- **Root cause:** `AppState.migrateModelToLiveCatalog()` (`AppState.swift:289` pre-fix) replaced the paid id (absent from live GET) with `live.first` and persisted it.
- **Impact:** SC-11 blocked across 3 takes; Keychain falsely suspected.
- **Disposition:** FIXED+PROVEN (early-return on allowedModelID; t80 PASS 184s, 06 stills, mux 207.8s/543kbps).

### F-02 — Theatrical AX asserts (t90)
- **What happened:** ANSWER/DONE bubbles matched the request echo, not agent output; XCTest green, pixels red.
- **Found:** watcher stills (spinner, no stdout) vs XCTest PASS on same take.
- **Root cause:** `label CONTAINS` cannot separate echo from output; turn done-check absent.
- **Impact:** false green; forced the flow-gates + watcher-verdict discipline.
- **Disposition:** FIXED+PROVEN (completion markers, runtime-computed; watcher is the verdict).

### F-03 — Silent python hang (t92/t93)
- **What happened:** "Running python..." spinner forever; no stdout, no error, no marker.
- **Found:** bytes-marker wait expiry + empty dumps across two takes.
- **Root cause:** hidden-WebView JS timers stall; rejects vanish silently (evalJS swallows).
- **Impact:** 2 takes burned with zero diagnostic signal.
- **Disposition:** FIXED+PROVEN (native 120s watchdog, double-settle safe; fired loud on t96 probe-240).

### F-04 — Preview blank on revisit (t91/b2-b3, t101/s4)
- **What happened:** preview renders (b0 green) then black on tab switch-back.
- **Found:** watcher stills b2/b3 + s4 (blank) vs b0/s0 (rendered).
- **Root cause:** `modeContent` conditionals unmounted the preview branch incl. its WKWebView (`BuildOnDeviceScreen.swift:394` pre-fix).
- **Impact:** T-4 unproven until fixed; every revisit blank.
- **Disposition:** FIXED+PROVEN (always-mounted branches, zero-height collapse; t102 assert + t103 watcher s4 card).

### F-05 — AX-invisible surfaces (t83-t86, t95)
- **What happened:** tab ids, terminal id, preview card text unmatchable.
- **Found:** UI-tree dumps across 4 takes.
- **Root cause:** segmented children expose labels not ids; SwiftTerm canvas has no AX text; webview leaf flag hid card text (also a VoiceOver defect).
- **Impact:** 4 takes of harness iteration.
- **Disposition:** FIXED+PROVEN (label taps, stable retry, `isAccessibilityElement=false`; t96+ card asserts match).

### F-06 — Fixture double-run (t95)
- **What happened:** second runPython hit the watchdog; preview overwritten with error card.
- **Found:** probe-230 PYTHON ERROR after probe-120/180 success on same take.
- **Root cause:** view re-appear re-fired `scheduleMode1E2E`; second run raced the first.
- **Impact:** 1 take voided.
- **Disposition:** FIXED+PROVEN (run-once static guard; t98 PASS 67s).

### F-07 — Cold-load loader hang (t96)
- **What happened:** fixture never ran on fresh-booted guest; watchdog error card.
- **Found:** probe frames (menu → error, no success card) + watchdog firing as designed.
- **Root cause:** Pyodide first-load never completed on cold guest (warm guest loads fine).
- **Impact:** 1 take; open refinement (loader progress/timeout UX).
- **Disposition:** FIXED-process (watchdog names it loud); refinement OPEN.

### F-08 — State-restoration vs entry race (t99/t102)
- **What happened:** relaunch lands in Mode 1 (preview tab, composer hidden); entry loop demanded composer.
- **Found:** fused AX tree (menu + Mode-1 + E2E card) in t102 dump.
- **Root cause:** state restoration bypasses the launch menu; harness assumed menu-first.
- **Impact:** 2 takes failed on entry, product healthy.
- **Disposition:** FIXED+PROVEN (E2E card counts as Mode-1 proof; t100/t103 green).

### F-09 — Key-in-chat contamination (session)
- **What happened:** operator pasted Go keys in chat twice.
- **Found:** chat transcript (unavoidable, operator-typed).
- **Root cause:** no out-of-band key channel established before takes needed keys.
- **Impact:** both keys should rotate at convenience; env-only discipline held elsewhere (0 hits in every run log).
- **Disposition:** OPEN (operator: rotate at convenience).

### F-10 — Anchor bulk symlinks (session)
- **What happened:** symlinking tracked bulk showed 4285 deletions in anchor status.
- **Found:** `git status` immediately post-migration.
- **Root cause:** symlinks over tracked paths (tmp/, backups/, forge/tmp/).
- **Impact:** none shipped (caught pre-commit); anchor 17G, disk 99%.
- **Disposition:** FIXED (real copies for tracked bulk; symlinks only for untracked Evidence/OPENCODE_ACTIVE_PROJECTS/node_modules).

### F-11 — Sim-mutex absence (t104)
- **What happened:** app backgrounded mid-take (home screen, no crash, no jetsam).
- **Found:** probe-150 home screen + concurrent sessions running takes (w1a/w2/w3-sim dirs).
- **Root cause:** shared sim, no mutual exclusion across sessions.
- **Impact:** 1 take voided.
- **Disposition:** FIXED+PROVEN (driver refuses on concurrent driver; mirrored to anchor scripts/run-take.py).

### F-12 — 429 quota wall (t105-t109, ~2h)
- **What happened:** prologue probe 429s; pool healthy (585/0→585/576 cached), sim key throttled key-scopely.
- **Found:** identical FAIL across 5 takes + direct /responses probe (429) + pool probe (200s).
- **Root cause:** server-side key-scoped throttle (rate vs revocation indistinguishable from outside).
- **Impact:** live-call takes parked ~2h; lifted with fresh key at t110+.
- **Disposition:** FIXED-process (backoff ladder + direct key-liveness probe); key health stays operator-visible.

### F-13 — SecureField Save-tap stall (t110)
- **What happened:** Save-tap query timed out on sick tree (secure alert + Passwords bar), overlay left open.
- **Found:** probe-170 overlay open with dots; line-34 snapshot throw.
- **Root cause:** single-shot AX query under guest load.
- **Impact:** 1 take (new key untested that round).
- **Disposition:** FIXED+PROVEN (retry loop on Save in both proof tests; t111 prologue 200s).

### F-14 — Agent narration vs markers (t116)
- **What happened:** "Running python" matched agent prose ("Running it now"), not the phase line.
- **Found:** dump text analysis post-take.
- **Root cause:** bubble text cannot separate narration from product markers.
- **Impact:** 1 take misdiagnosed initially; corrected same turn.
- **Disposition:** FIXED+PROVEN (completion signal = turn done-check runtime counts; stdout truth = watcher only).

### F-15 — Recorder wedge (t119)
- **What happened:** killed take left sim recorder lock ("Host recording already in progress").
- **Found:** driver REFUSE on refire; no guest process held it (server-side lock).
- **Root cause:** timeout-kill mid-take orphaned the sim media lock.
- **Impact:** 1 aborted refire; sim reboot cleared it.
- **Disposition:** FIXED-process (timeouts sized sleep+take separately; reboot remedy documented).

### F-16 — Cold-sim slowness (t119/t120)
- **What happened:** fresh-booted sim too slow for prologue/entry windows; main-thread-busy episodes.
- **Found:** probe frames (menu at 60s, slow progression) + line-34 throws.
- **Root cause:** cold caches + guest strain after reboot.
- **Impact:** 2 takes.
- **Disposition:** FIXED-process (cools; connected-only takes via --no-uninstall skip SecureField prologue).

### F-17 — F5 closure (t121)
- **What happened:** n/a (success record): live-agent stdout 42/DONE ×3 as agent output, gear rows, done banner, paid footer.
- **Found:** p0 still + independent watcher PASS.
- **Root cause:** n/a.
- **Impact:** F5 single-live-tape requirement met.
- **Disposition:** CLOSED (sealed 7fb2cdf).
