# RUNNING_DEBUG_LOG — FORGE anchor (append-only, per debug event)

## [2026-09-10T–migrate-root-cause] — Second-call 401
- SYMPTOM: first live-200 then provider-401 post-relaunch, two keys same shape.
- ROOT CAUSE: `AppState.migrateModelToLiveCatalog()` (`AppState.swift:289` pre-fix) replaced the paid id (absent from live GET) with `live.first` and persisted it.
- FIX: early return on `ZenModelCatalog.allowedModelID`.
- LESSON: same-binary contrast decides transient vs systematic; tripwire persisted values, never trust the plumbing.
- EVIDENCE: t80 PASS; 06-persistence-pass.png; key-length `configured (67 chars)` both sides.

## [2026-09-10T–silent-hang] — Python promise never settles
- SYMPTOM: "Running python..." spinner forever; no stdout, no error, no marker.
- ROOT CAUSE: hidden-WebView JS timers stall; rejects vanish silently in evalJS.
- FIX: native 120s watchdog (`ForgeBridge.swift`, double-settle safe); temp stage markers (removed post-diagnosis).
- LESSON: silence → named error via unthrottled channel (DispatchQueue); temp diagnostics get removal rows.
- EVIDENCE: t96 probe-240 error card fired loud; DIAG resolve path healthy after.

## [2026-09-10T–blank-revisit] — Preview black on tab switch
- SYMPTOM: preview renders (b0 green) then black on switch-back.
- ROOT CAUSE: `modeContent` conditionals unmounted the preview branch incl. its WKWebView.
- FIX: both branches always mounted; hidden ones collapse (zero height + opacity 0 + no hit-testing + clipped).
- LESSON: hide, don't remove — navigation-by-unmount destroys webview state.
- EVIDENCE: t102 card poll passed; t103 watcher s4 FULL CARD survives switches.

## [2026-09-11T–push-500s] — Master push dies, secrets surface
- SYMPTOM: repeated HTTP 500 + disconnect on master push; then GH013 push-protection naming a PAT.
- ROOT CAUSE: ~3.5GB pack (2.8G tarball + videos in history) over constrained link; 2 pre-existing committed secrets (Apple-ID pw, PAT).
- FIX: orphan air-drop branch (product only); redacted both secrets before push; ancestry proved neither reached GitHub.
- LESSON: bulk never belongs in history; secret-scan before push (tail cut the detail twice).
- EVIDENCE: API contents checks on air-drop; token scopes full; zero-object ref push OK.
