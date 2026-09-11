# BUILD_REPORT — FORGE ship wave (anchor: MIMOCODE/Forge)

## 2026-09-10 — W1: SC-11 close (t78-t80)
**Built:** paid-only model lockdown (bundle allowlist `forge-bundle.js:1860`, bridge refusal via `ZenModelCatalog.allowedModelID` `ForgeBridge.swift:640`, `ZenModelCatalog.swift:16` default + retired free-1.3); migrate guard (`AppState.swift:289` early-return on allowed id); proof driver take-parameterization + sim-mutex (`tmp/run-connect-proof.py`, mirrored `scripts/run-take.py`).
**Why:** second-call 401 on t76/t78 (same 200→401 shape, two keys).
**Evidence:** t80 PASS 184s, 06/06 stills, mux 207.8s/543kbps; bundle `90279713`→`e93bbca4`.
**Verification:** pytest 88/88 (incl new lockdown test); node clean.
**Honest notes:** Keychain exonerated by length tripwires (67 chars both sides); migrate was the culprit.

## 2026-09-10 — W2/W3: streaming + tools proof, 4 product fixes
**Built:** bytes-marker completion line (`forge-bundle.js:1796`); preview prompt docs (preview tool in system prompt); native 120s runPython watchdog (`ForgeBridge.swift:895`, double-settle safe); preview always-mounted fix (`BuildOnDeviceScreen.swift:391`, zero-height collapse); preview AX container fix (`PreviewPaneView.swift:46` isAccessibilityElement=false).
**Why:** t90/t91 watcher FAILs (spinner forever, blank revisit, silent hangs).
**Evidence:** DIAG proved runPython resolves 15 stdout bytes in 15s (t113 sim log); t91 b0 green Hello render.
**Honest notes:** streaming = chunked-callback, SSE/EventSource absent (SC-c unmet).

## 2026-09-10 — W4: T-9 battery (t81-t98)
**Built:** BatteryUITests (full flow), E2EUITests (deterministic fixture take), bytes-marker + key-length tripwires, tapStable/expectBubbleStable harness, Save-tap retry.
**Evidence:** t98 PASS 67s + watcher 3/3 (card + ANSWER 42 + green canvas); t90/t91 live-agent legs green.
**Honest notes:** live single-agent full-tape green outstanding at W4 close (later: F5 t121).

## 2026-09-10/11 — W5: soak (t99-t103)
**Built:** SoakUITests (background 60s, tabs, terminate/relaunch), dual-entry fix (E2E card counts as Mode-1 proof), run-once fixture guard.
**Evidence:** t100 + t103 PASS; watcher 5/6 then 5/5 stills; mux duration gates pass (bitrate freeze-FAIL by nature of static takes).
**Honest notes:** s5 watcher gap on t103 (AX asserts green); RSS drift 602→528MB idle noted.

## 2026-09-11 — Audit-fix wave (F1-F6) + F5 close
**Built:** backfilled rows; pyStage/temp-DIAG removed (grep zero, watchdog kept); TESTING_LOG corrections; seal commits befa59d → bf26fcb → 5b2b5a3 → f79eb68 → 7fb2cdf → 353d0e1.
**Evidence:** zero-trust audit artifact `reports/ZeroTrustAudit_2026-09-11.md` (REFUTED-as-ship / VERIFIED-through-soak); dual independent watchers (A 5/5 stills, B 5/8 timeline, 3 protocol-explained); t121 PASS 224s + watcher PASS (stdout 42/DONE ×3, gear rows, done banner, paid footer) = F5 CLOSED.
**Honest notes:** device/TestFlight/phone + key rotation + disk remain operator-owned.

## Evidence appendix (measured, per wave)
- Baseline lineage: ce9ff28 → befa59d → bf26fcb → 5b2b5a3 → f79eb68 → 7fb2cdf → 353d0e1 → d9ab150 (anchor HEAD).
- Bundle SHAs: `90279713d4d3a76a` (t76-t80) → `e93bbca4` (lockdown) → `46eb33a1` (markers+prompt) → `f06bda2bfabeedd6` (sealed; worktree identical per independent recount).
- Suite: `python3 -m pytest tests -q` → 88 passed (13 files) standing across every product edit; `node --check` clean every wave.
- Takes: t76-t125 + backfills, zero gaps (independent recount 25 rows over span + 3 backfilled); evidence dirs carry stills + seg-01.mp4 + xcodebuild-test.log each.
- Mux gates: t76 447s/462k PASS, t80 207s/544k PASS, t125 386s/636k PASS (both gates); static takes fail bitrate by nature, carried by stills+AX.
- Watchers: 13 blind sessions (t90-t125 + dual A/B close); dual close: A 5/5 stills, B 5/8 timeline (3 protocol-explained home frames).
- Key takes: t80 SC-11 (184s, 06 stills), t98 deterministic E2E (67s, watcher 3/3), t100/t103 soak (background+tabs+relaunch), t121 F5 stdout (224s, 42/DONE ×3), t125 approval (359s, stdout+preview, both mux gates).
- Zero-trust audit: reports/ZeroTrustAudit_2026-09-11.md — REFUTED-as-ship / VERIFIED-through-soak; 6 frauds with anchors; all autonomous fixes sealed.
- Checkpoint: Checkpoints/ship-wave-green-t125-20260911/ (96M, 104 Swift / 27 py, 16 canon docs, manifest 42L, MODE B).
- 2026-09-09 WAVE 3 cycle-forge-t1 LIVE FORGE_TEST_PROMPT (MODE1_E2E unset). Guest BUILD SUCCEEDED. Tape seg-0
- 2026-09-09 cycle-forge-t2 in flight after stdout/preview fix. Guest BUILD SUCCEEDED (t2 xcodebuild log :737)
- 2026-09-09 t2 FAIL take closed: PREVIEW orange + index.html ANSWER 42 (tiny dark text). Python TUI stdout ne
- 2026-09-09 t3 FAIL: live FORGE_TEST_PROMPT MODE1_E2E unset. BUILD SUCCEEDED :643. t20 TERMINAL python stdout
- 2026-09-09 t4 FAIL take closed (progress, not PASS). Guest BUILD SUCCEEDED :759. App mtime Sep 8 15:26:38. N
- 2026-09-09 t5 FAIL take closed. Host landed sanitizeWriteContents + preview-bootstrap data-forge-preview-def
- 2026-09-09 t6 FAIL take closed. Guest BUILD SUCCEEDED :640 nested rsync. MODE1_E2E unset. Lead ViL (read_fil
- 2026-09-09 t7 FAIL take closed (mechanical tape PASS; unlabeled critic FAIL). Guest BUILD SUCCEEDED :636. MO
- 2026-09-09 t8 FAIL take closed (product mash/stdout progress; tape duration FAIL). Host landed extractStream
- 2026-09-09 t9 FAIL take closed (mechanical tape PASS; write-slot critic 3–0 PASS; preview-slot 0–3 FAIL; vid
- 2026-09-09 t10 FAIL take closed. Host: test_mode1_mash_exec.py executes shipped sanitizeWriteContents/extrac
- 2026-09-09 t11 FAIL take closed. Guest defaults delete FORGE_START_MODE (pair did not exist). START_MODE UNS
- 2026-09-09 t12 FAIL take closed (mechanical tape PASS; launch PIN 3–0; write PIN 0–3; video 3–0; SC-9 both-s
- 2026-09-09 t13 FAIL take closed (mechanical tape PASS; launch PIN 3–0; write PIN 0–3; video 3–0; SC-9 both-s
- 2026-09-09 t14 FAIL take closed (mechanical tape PASS; launch PIN 3–0; write PIN 0–3; video PIN 0–3; SC-9 FA
- 2026-09-09 t15 FAIL take closed (mechanical tape PASS; launch PIN 3–0; write PIN 0–3; video PIN 1–2 FAIL; SC
- 2026-09-09 t16 FAIL take closed (mechanical tape PASS; launch PIN 3–0; write PIN 0–3; video PIN 1–2 FAIL; SC
- 2026-09-09 t17 FAIL take closed (mechanical tape PASS; launch PIN 3–0; write PIN 0–3; video PIN 1–2 FAIL; SC
- 2026-09-09 t18 FAIL take closed (mechanical tape PASS; launch orch-PASS; write orch-FAIL duplication; blind 
- 2026-09-09 t19 WAVE 3 GATE MET (mechanical tape PASS; blind dual critic PASS; VIDEO_WATCHED:YES). Guest nest
- 2026-09-09 t20 WAVE 4 soak FAIL (write slot strict; launch 3–0; video 3–0 re-panel). Unchanged build 7f4cfa0
- 2026-09-09 t21 WAVE 4 loop FAIL (write slot 2–1; launch 3–0; video 3–0). Unchanged build 7f4cfa01. Tape sha 
- 2026-09-09 t22 WAVE 4 loop OPEN (write 3–0 strict; video unfeddable). Unchanged build 7f4cfa01. Tape sha 9f1
- 2026-09-09 t23 WAVE 4 loop FAIL (launch 2–0 PASS third vote outstanding; write 0–3; video FAIL; SC-9 FAIL). 
- 2026-09-09 t24 WAVE 4 loop FAIL (launch 3–0; write 0–3; video PASS; SC-9 both-slots not met). Unchanged buil
- 2026-09-09 t25 WAVE 4 loop FAIL (launch 1–2; write 2–1; video PASS; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t26 WAVE 4 loop FAIL (launch 3–0; write 0–3; video PASS; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t27 WAVE 4 loop FAIL (launch 3–0; write 0–3; video FAIL; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t28 WAVE 4 loop FAIL (launch 3–0; write 0–3; video PASS; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t29 WAVE 4 loop FAIL (launch 3–0; write 0–3; video PASS; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t30 WAVE 4 loop FAIL (launch 3–0; write 0–3; video PASS; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t31 WAVE 4 loop FAIL (launch 3–0; write 0–3; video FAIL; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t32 WAVE 4 loop FAIL (launch 3–0; write 0–3; video PASS; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t33 WAVE 4 loop FAIL (launch 3–0; write 1–2; video FAIL; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t34 WAVE 4 loop FAIL (launch 2–1; write 3–0; video PASS; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t35 WAVE 4 loop CRITICS-PASS (launch 3–0; write 3–0; video PASS) — VIDEO_WATCHED outstanding, SC-
- 2026-09-09 t36 WAVE 4 loop FAIL (launch 0–3; write 0–3; video PASS; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t37 WAVE 4 loop FAIL (launch 0–3; write 0–3; video PASS; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t38 WAVE 4 loop FAIL (launch 3–0; write 0–3; video PASS; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t39 WAVE 4 loop FAIL (launch 2–1; write 0–3; video PASS; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t40 WAVE 4 loop FAIL (launch 3–0; write 1–2; video PASS; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t41 WAVE 4 loop FAIL (launch 3–0; write 0–3; video FAIL; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t42 WAVE 4 loop FAIL (launch 3–0; write 0–3; video PASS; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t43 WAVE 4 loop FAIL (launch 3–0; write 0–3; video FAIL; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t44 WAVE 4 loop FAIL (launch 3–0; write 1–2; video FAIL; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t45 WAVE 4 loop FAIL (launch 3–0; write 0–3; video FAIL; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t46 WAVE 4 loop FAIL (launch 3–0; write 3–0; video FAIL; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t47 WAVE 4 loop FAIL (launch 3–0; write 0–3; video FAIL; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t48 WAVE 4 loop FAIL (launch 3–0; write 3–0; video FAIL; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t49 WAVE 4 loop CRITICS-PASS (launch 3–0; write 3–0; video PASS) — VIDEO_WATCHED outstanding, SC-
- 2026-09-09 t50 WAVE 4 loop FAIL (launch 3–0; write 2–1; video FAIL; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t51 WAVE 4 loop FAIL (launch 3–0; write 3–0; video FAIL; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t52 WAVE 4 loop FAIL (launch 0–3; write 0–3; video PASS; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t53 WAVE 4 loop FAIL (launch 1–2; write 0–3; video FAIL; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t54 WAVE 4 loop FAIL (launch 3–0; write 0–3; video FAIL; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-08 compact-resume: PIN CURRENT REALITY upgraded to cycle-forge-w3-sim/mode1-e2e-late.png (ANSWER run
- 2026-09-08 orch audit: ForgeBridge SHA 7216377ad28f… posts __pythonResult; ForgeEngine SHA 00a8c9b5d6f4… cas
- 2026-09-08 guest THIS-build: xcodegen + xcodebuild ** BUILD SUCCEEDED ** (log scratch xcodebuild-iphonesimul
- 2026-09-08 operator correction: host serve = Mode 2 only. Mode 1 live TUI MUST be tested (FORGE_TEST_PROMPT 
- 2026-09-08 zen catalog: DialogModelView was a frozen August list (muse 1.2 + deepseek-v4-flash-free). Live G
- 2026-09-08 LLM error 400 ROOT: zen Console requires OpenCode client headers (`x-opencode-session` / `x-openc
- 2026-09-09 t55 WAVE 4 loop FAIL (launch 3–0; write 0–3; video FAIL; SC-9 not met). Unchanged build 7f4cfa01 
- 2026-09-09 t56 WAVE 4 loop FAIL (launch 3–0; write 0–3; video FAIL; SC-9 not met). Provider OpenCode Go muse
- 2026-09-09 t57 CONNECT-PROOF FAIL (SC-11 a/b/c unproven; script causes, not product verdict). THIS-build wit
- 2026-09-09 t58 CONNECT-PROOF FAIL (SC-11 unproven; harness focus cause, not product verdict). THIS-build wit
- 2026-09-09 t59 CONNECT-PROOF FAIL (SC-11 unproven; harness focus cause, not product verdict). RECOVERED take
- 2026-09-10 t76 CONNECT-PROOF FAIL (SC-11 a/b still-proven, c open; provider cause, not product verdict). THI
- 2026-09-10 t78 CONNECT-PROOF FAIL (fresh operator key; same 200-then-401 shape, mechanism still open at row 
- 2026-09-10 t79 CONNECT-PROOF FAIL with ROOT CAUSE FOUND (systematic, client-side, AppState.migrateModelToLiv
- 2026-09-10 t80 CONNECT-PROOF PASS — SC-11a/b/c proven on one tape (184s). Same fresh key, post-fix build: ty
- 2026-09-10 t81 CONNECT-PROOF/BATTERY FAIL (first BatteryUITests run; harness cause). Agent legs passed (hell
- 2026-09-10 t82 CONNECT-PROOF/BATTERY FAIL (harness cause). waitFor added; previewMode.TERMINAL still absent;
- 2026-09-10 t83 CONNECT-PROOF/BATTERY FAIL (harness cause). Label taps worked; forgeTerminal OtherElement abs
- 2026-09-10 t84 CONNECT-PROOF/BATTERY FAIL (environment cause). Reached PREVIEW stage; full-tree AX snapshot 
- 2026-09-10 t85 CONNECT-PROOF/BATTERY FAIL (environment cause). expectBubbleStable retry helper added; failed
- 2026-09-10 t86 CONNECT-PROOF/BATTERY FAIL (harness cause). Footer passed via stable query; previewModeToggle
- 2026-09-10 t87 CONNECT-PROOF/BATTERY FAIL (harness cause). b0/b1/b2 saved; expectBubbleStable("PREVIEW") fai
- 2026-09-10 t88 CONNECT-PROOF/BATTERY FAIL (harness cause). tapStable added for all tab taps; PREVIEW tap rea
- 2026-09-10 t89 CONNECT-PROOF/BATTERY FAIL (harness cause). b0/b1/b2 saved; PREVIEW query inside tapStable ti
- 2026-09-10 t90 BatteryUITests PASSED (XCTest green, 183s) + product AX fix (BuildOnDeviceScreen: removed par
- 2026-09-10 t91 BatteryUITests PASSED (XCTest green, 353s, completion window) + product AX fix shipped (toggl
- 2026-09-10 t94 E2EUITests FAIL (harness cause) + MAJOR FINDING on pixels: deterministic fixture (FORGE_TEST_
- 2026-09-10 t95 E2EUITests FAIL (harness cause) + fixture works 2nd time: probe-200 shows FORGE PREVIEW card 
- 2026-09-10 t96 E2EUITests FAIL (fixture never completed on cold-booted guest). Rig went down mid-loop (host 
- 2026-09-10 t97 E2EUITests FAIL (harness cause) + fixture green on AX: dump contains FORGE PREVIEW + "ANSWER 
- 2026-09-10 t98 E2EUITests PASS (67s, warm guest) + watcher 3/3 PASS: e0 clean terminal entry, e1+e2 full pre
- 2026-09-10 t99 SoakUITests FAIL (harness cause): s0-s4 saved (render, background survival, 3 tabs); relaunch
- 2026-09-10 t100 SoakUITests PASS (XCTest green) + watcher 5/6: s0 card rendered, s1 intact after 60s backgro
- 2026-09-10 t101 SoakUITests FAIL at post-PREVIEW-tap card poll (90s): s0-s3 saved, s4 missing. Root cause B-
- 2026-09-10 t102 SoakUITests FAIL at relaunch entry (s0-s4 saved, B-PREV fix holds — s4 card present). Root c
- 2026-09-10 t103 SoakUITests PASS (XCTest green) + watcher 5/6 PASS: s0 card rendered, s1 intact after 60s ba
- 2026-09-11 dual independent visual verification (T6, two fresh blind watchers, zero shared context): Watcher
- 2026-09-11 audit-fix F1+F2 (host-only, no key/rig): backfilled t77/t92/t93 rows above; removed pyStage() hel
- 2026-09-11 t104 BatteryUITests FAIL (external-interference class): entered Mode 1, typed /connect prologue, 
- 2026-09-11 t105 BatteryUITests FAIL (ENVIRONMENT verdict, not product): prologue /connect test answered 429 
- 2026-09-11 t106 BatteryUITests FAIL (ENVIRONMENT verdict): /connect test answered 429 again after 10-min coo
- 2026-09-11 F6 soak numerics (keyless): guest vm_stat free t0 602MB → t5 581MB → t10 528MB (idle drift, cause
- 2026-09-11 t107 BatteryUITests FAIL (ENVIRONMENT verdict): prologue 429 again (~40min wall). Backing off 30m
- 2026-09-11 t108 BatteryUITests FAIL (ENVIRONMENT verdict): prologue 429 again (~70min wall, survives 30min c
- 2026-09-11 t109 BatteryUITests FAIL (ENVIRONMENT verdict): prologue 429 persists (~2h wall) WHILE host pool 
- 2026-09-11 key-liveness probe (host direct, /responses minimal): HTTP 429 on the sim Go key itself — wall is
- 2026-09-11 t110 BatteryUITests FAIL (harness cause, new key untested): SecureField overlay left open — Save-
- 2026-09-11 t111 BatteryUITests FAIL (harness allowance): NEW KEY VERIFIED WORKING at prologue (past PASS: co
- 2026-09-11 t112 BatteryUITests FAIL (bytes marker absent 300s; done-check present, no ✗, no stdout): promise
- 2026-09-11 t113 BatteryUITests FAIL (bytes marker absent) BUT sim-log DIAG proves runPython RESOLVED in 15s 
- 2026-09-11 t114 BatteryUITests FAIL (snapshot timeout, line 34, no stills): sick tree again; DIAG shows norm
- 2026-09-11 t115 testLivePythonStandalone FAIL (model-behavior class): new key 200s at prologue; agent narrat
- 2026-09-11 t116 testLivePythonStandalone FAIL (harness flaw, not product): "Running python" matched AGENT PR
- 2026-09-11 t117 testLivePythonStandalone FAIL (snapshot timeout, line 34, no stills): guest CPU saturated at
- 2026-09-11 t118 testLivePythonStandalone FAIL (main-thread stall): /connect test QUEUED forever, main runloo
- 2026-09-11 t119 testLivePythonStandalone FAIL (snapshot timeout, line 34, no stills): sick tree in prologue 
- 2026-09-11 t120 testLivePythonStandalone FAIL (main-thread-busy, line 34, no stills): back-to-back takes sat
- 2026-09-11 t121 testLivePythonStandalone PASS (224s) + watcher PASS: live python stdout 42/DONE ×3 as agent 
- 2026-09-11 t121 testLivePythonStandalone PASS (224s) + watcher PASS: live python stdout 42/DONE ×3 as agent 
- 2026-09-11 t122 BatteryUITests FAIL (bytes marker absent; agent skipped python again — writes + preview only
- 2026-09-11 t123 BatteryUITests FAIL (window expiry, not product): agent mid-turn narrating progress when 300
- 2026-09-11 t124 BatteryUITests FAIL (bytes marker absent 600s; done-check present, no phase/stdout/✗): agent
- 2026-09-11 t125 testLivePythonStandalone PASS (359s) + watcher 2/2 PASS: p0 live stdout 42/DONE ×2 as agent 


## 2026-09-11 — Approval (t125 + operator verdict)
**The built:** t125 full-flow take (connect 200 → agent writes hello.py + index.html → live python stdout 42/DONE → green Hello preview render → tabs), watcher 2/2 PASS, mux 386s/636kbps both gates PASS; seg-01.mp4 in Evidence/play/cycle-forge-t125/.
**Operator verdict (verbatim):** "this is GREAT PROGRESS wow nice this is the first genuenly ship ready evidence video ive seen."
**The evidence:** bundle f06bda2b sealed; suite 88/88; checkpoint ship-wave-green-t125 refreshed MODE B.
**The honest notes:** device/TestFlight/phone, key rotation, disk remain operator-owned; SSE absent; plain-words UX open.
