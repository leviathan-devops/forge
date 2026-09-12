# BUILD_STATE — FORGE anchor (2026-09-11, T11 docs pass; overwrites prior)

## Summary
iOS-native opencode client (Swift 5.9, XcodeGen, esbuild IIFE into hidden WKWebView). Anchor commit line below; bundle `f06bda2bfabeedd6`; suite 88/88; rig DOWN (volume persists).

## SHA chain (master, oldest → newest within window)
- 3d9a88e preview immediate 0s hold 25s syntax; 5beb74b/da6b2a7 brace fixes; 8c29895 ChatModel tool write→forgeTurnComplete.
- 3c8c4e0 Wave3: preview path-form + markers, MC deck counter, E1 mechanism.
- 0ce6d33 Wave4: MC dual-read env merge + CM SERVER fallback + AppState EAGLE dual + F1 total guard.
- ce9ff28 Wave4-transport: muse serve-session branch (MissingSessionID resolution, zen-direct fallback). [Migration baseline.]
- befa59d Ship wave W1-W5: 401 fix, lockdown, watchdog, mount fix, AX fix, takes t76-t103.
- bf26fcb Audit F1-F3: backfills, marker strip, claim corrections.
- 5b2b5a3 Audit F1-F6 part 1: rows, markers, TESTING corrections, harness hardening, sim-mutex.
- f79eb68 Ledger t104-t106 + F6 soak numerics.
- d9f6ae4 Ledger t104-t108 (interference guard, 429 wall) + sim-mutex driver.
- 7fb2cdf F5 close + diagnostics cleanup (t121 stdout green, temp DIAG removed, watchdog kept).
- 353d0e1 Ledger t119-t125 rows, dual verification, T9 sideload wave, report v4.
- d9ab150 t125 approval green (stdout+preview, mux both gates).
- 5c26bbc Ship docs full pass (159/51/120/52/55).
- 7e2a94d Ship docs: t125 row + approval verdict + manifest.
- 8083557 Report v4 + checkpoint manifest refresh.
- 8dfd8e3 MacBook handoff (Save-tap retry, ledger, AGENT_MACBOOK_AIR contract).
- b768743 Air continuity (preview bridge/pyodide/catalog/identity/UI, bootstrap, pyodide runtime, 9 test files).
- 3d08b40 Ledger t119-t125 rows, dual verification, T9 sideload wave, report v4. [master HEAD]
- e7a3071 (air-drop orphan): product tree for MacBook compile (history stays on master).

## Bundle SHAs (deployable artifact `iOS/FORGE/Resources/forge-bundle.js`)
- `90279713d4d3a76a` (t76-t80 era) → `e93bbca4` (lockdown) → `46eb33a1` (markers+prompt) → `f06bda2bfabeedd6` (sealed; worktree identical per independent recount).
- node --check clean every wave; session:chat emitters 1; EventSource 0 (chunked-callback streaming, SSE absent).

## Module inventory (measured file counts, anchor worktree)
| dir | files | notes |
|---|---|---|
| iOS/FORGE/App | 2 | FORGEApp + AppState (migrate guard AppState.swift:289) |
| iOS/FORGE/Bridge | 10 | engine, bridge (watchdog+SecureField), command runner, Pyodide scheme/handler, MC client |
| iOS/FORGE/Core | 8 | catalog (allowedModelID), identity, session, commands |
| iOS/FORGE/Presentation | 36 | Mode1 (screen+toggle+pane+toolbar+drawer), Mode2, LaunchMenu, Shared |
| iOS/FORGE/Resources | 23 | bundle, preview-bootstrap.js, pyodide/ 0.27.7, fonts, plist |
| iOS/FORGE/UITests | 9 | ConnectProof, Battery (flow/standalone/connected), E2E, Soak + legacy |
| forge/src | 10 | entry/runtime/identity/terminal-surface + vendor types |
| forge/shims | 13 | node→browser aliases for esbuild |
| tests | 26 | 13 py (88 tests) + pycache |
| scripts | 19 | run-take.py driver, bundle/phase/vm scripts, protect-vm.sh |
| docker | 23 | run-forge-vm.sh, Dockerfiles, qemu helpers |
| docs | 45 | DPL1 spec, engineering spec, preview spec, runbooks, handovers |
| handovers | 29 | pins (SC12_T78, SHIP_SPEC), takeover pack |
| reports | 4 | v1, v2, v3, v4 + ZeroTrustAudit_2026-09-11 |

## Frozen list (do not change without a wave + take)
- ForgeEngine WKWebView configuration (hidden, non-persistent store, native handler).
- Entitlements shape + Keychain access groups.
- Keychain/UserDefaults plumbing (apiKey/provider/model/url keys).
- project.yml bundle id com.forge.app; SwiftTerm from 1.15.0.
- Rig contract: Haswell-noTSX, start-tahoe only, one QEMU, never wipe forge-vm-data, 6GB/SMP4.

## Per-commit file record (what each seal commit carried — audit trail for the chain above)
- befa59d: AppState migrate guard, ZenModelCatalog lockdown, ForgeBridge paid refusal, bundle allowlist+tripwires, ConnectProof tripwires, driver take-param, Battery/E2E/Soak tests (new), zen_catalog test, GAUNTLET t76-t103 rows, Checkpoints/takeover snapshot.
- bf26fcb: GAUNTLET backfills (t77/t92/t93 marked), pyStage/temp-DIAG removal start, T-9/SPEC claim corrections.
- 5b2b5a3: TESTING_LOG corrections, AX/harness hardening (tapStable/expectBubbleStable/Save-retry), sim-mutex driver, F6 soak numerics rows.
- f79eb68: t104-t106 rows + F6 trend (602→581→528MB, 0 crashes).
- d9f6ae4: t104-t108 rows (interference guard, 429 wall), sim-mutex driver mirror.
- 7fb2cdf: F5 close + DIAG cleanup (t121 stdout green, temp markers out, watchdog kept).
- 353d0e1: t119-t125 rows, dual verification (A 5/5, B 5/8), T9 sideload wave start, report v4.
- d9ab150: t125 approval green + TESTING row.
- 5c26bbc: ship docs full pass (159/51/120/52/55).
- 7e2a94d: t125 row + approval verdict + SHIP_DOCS_MANIFEST.
- 8083557: report v4 + checkpoint manifest refresh.
- 8dfd8e3: Save-tap retry, ledger rows, AGENT_MACBOOK_AIR contract.
- b768743: continuity files (preview bridge/pyodide/catalog/identity/UI, bootstrap, pyodide runtime, 9 test files).
- 3d08b40: t119-t125 rows, dual verification, T9 wave, report v4.
- e7a3071 (air-drop orphan): product tree only (iOS, forge/src+shims, tests, scripts, docker, docs, handovers, reports, logs, manifest); secrets redacted pre-push; API-verified.

## Artifact SHAs (fingerprints that must match across docs)
- Bundle: f06bda2bfabeedd6 (worktree == befa59d blob per independent recount; node clean).
- Historical: 90279713 (t76-t80) → e93bbca4 (lockdown) → 46eb33a1 (markers+prompt).
- Suite anchor: 88 passed / 13 files (zen_catalog carries lockdown + marker pins).
- Approval mux: seg-01.mp4 t125, 386.4s / 636417bps (both gates PASS).
- Checkpoint: ship-wave-green-t125-20260911, 96M, manifest 42L, MODE B.
- Reports: v1, v2, v3, v4 + ZeroTrustAudit_2026-09-11 (6-row claims, 6 frauds).

## Module inventory deltas (what changed vs the Wave4 baseline ce9ff28)
- ADDED: BatteryUITests (flow/standalone/connected), E2EUITests, SoakUITests, scripts/run-take.py, AGENT_MACBOOK_AIR.md, 5 ship docs + manifest, reports v1-v4 + audit, DPL1 spec, handover pins, 9 test_mode1_*.py, preview UI files (toggle/pane/toolbar/drawer/delegate), PreviewBridge, PyodideSchemeHandler, ZenClientIdentity, ZenModelCatalog, preview-bootstrap.js, pyodide/ runtime.
- MODIFIED: AppState (migrate guard), ForgeBridge (paid refusal, watchdog, SecureField), ForgeEngine (resolve DIAG added then removed — net zero), forge-bundle.js (allowlist, tripwires, markers, preview prompt docs), BuildOnDeviceScreen (mount fix), PreviewPaneView (AX container), ConnectProofUITests (tripwires, Save retry), protect-vm.sh (script-relative dir), ZenModelCatalog (paid default + retired free).
- UNTOUCHED (frozen): WKWebView config, entitlements shape, Keychain key names, bundle id, SwiftTerm pin, rig contract constants.
- DELETED: nothing (append-only tree; temp DIAG added then fully removed = net zero).

## Frozen-item rationales (why each frozen thing is frozen)
- WKWebView config: hidden 0x0 + non-persistent store + native handler + file-access flags verified across 50 takes; any change risks bridge silence (t92-class hangs with no diagnostics).
- Entitlements shape: ad-hoc Keychain group FAKETEAMID proven (t76 stills 04/05 save+200); full dev file gets launch-denied under ad-hoc (t78 lesson in driver).
- Keychain key names: forge.apiKey + UD keys shared by Settings/AppState/bridge/bundle; the mismatch bug (fixed pre-wave) returns if renamed.
- Bundle id + SwiftTerm pin: store/CI identity; 2.0.0 does not exist (CI history), 1.15.0 pinned and green.
- Rig constants: Haswell-noTSX (image ENV is Penryn — never ${CPU:-}); start-tahoe only; one QEMU (concurrent boots corrupt volume locks); never wipe forge-vm-data (30G+ MacHDD irreplaceable without reinstall); 6G/SMP4 (4G trial failed builds).
- Mux gates 90/400k: motion takes pass, static takes freeze-FAIL by nature (stills carry proof); changing gates changes what PASS means.

## Drift policy (how this doc stays true)
- Every product edit re-runs suite + node check; every wave appends its commit line above with file list.
- Bundle SHA changes → record the new SHA + which edit caused it + re-verify worktree==commit (recount pattern).
- New test files → inventory counts updated (tests/ dir line + suite total).
- New dependencies (SPM/npm) → pinned versions recorded here with the reason.
- Unpushed commits tracked: master pack too big for GitHub (3.5GB, HTTP 500s); air-drop carries product only. If master becomes pushable (history surgery is FORBIDDEN — seals reference SHAs), record the push hash here.
- Foreign dirt (other sessions' files) is NEVER folded into wave commits; verify via status grep before every commit.

## Verification recipes (re-prove any line above in under 5 minutes)
- Chain: `git log --format="%h %s" master | head -n 20` (order + messages).
- Bundle: `sha256sum iOS/FORGE/Resources/forge-bundle.js` + `node --check` + `grep -c session:chat/EventSource`.
- Suite: `python3 -m pytest tests -q` (88) + `grep -c "only model allowed" iOS/FORGE/Resources/forge-bundle.js` (lockdown live).
- Lockdown: `grep -n allowedModelID iOS/FORGE/Core/ZenModelCatalog.swift iOS/FORGE/Bridge/ForgeBridge.swift`.
- Migrate guard: `grep -n -A2 "allowedModelID { return" iOS/FORGE/App/AppState.swift`.
- Watchdog: `grep -n "120" iOS/FORGE/Bridge/ForgeBridge.swift | head -3` (asyncAfter present, DIAG absent).
- Mount fix: `grep -n "always mounted\|always-mounted" iOS/FORGE/Presentation/Mode1_BuildOnDevice/BuildOnDeviceScreen.swift` (comment marker).
- AX fix: `grep -n "isAccessibilityElement = false" iOS/FORGE/Presentation/Mode1_BuildOnDevice/PreviewPaneView.swift`.
- Artifacts: `ls Evidence/play/cycle-forge-t125/` (6 stills + seg + log); `ffprobe` gates on seg.
- Reports: `ls reports/` (v1-v4 + audit); `wc -l` ship docs (gates).

## Take-to-commit map (which seal holds which take evidence)
- befa59d: takes t76-t103 (SC-11 → soak closes) + product fixes W1-W5.
- bf26fcb: backfills t77/t92/t93 + marker strip start + claim corrections.
- 5b2b5a3: F6 numerics + harness hardening + sim-mutex + TESTING corrections.
- f79eb68/d9f6ae4: rows t104-t108 (interference, 429 wall) + driver mirror.
- 7fb2cdf: t121 F5 + DIAG cleanup (temp markers out, watchdog kept).
- 353d0e1: t119-t125 rows + dual verification + T9 start + report v4.
- d9ab150: t125 approval + TESTING row.
- 5c26bbc: ship-docs full pass (all 5 gated).
- 7e2a94d: t125 row + approval verdict + manifest creation.
- 8083557: report v4 + checkpoint manifest refresh.
- 8dfd8e3: Save-tap retry + handoff doc + ledger rows.
- b768743: continuity files (preview/pyodide/catalog/identity/UI/bootstrap/runtime/9 tests).
- 3d08b40: latest rows + dual verification + T9 wave + report v4 (master HEAD).
- e7a3071 (air-drop): product snapshot of b768743 content + handoff fix (no take rows — branch carries code, not ledger).

## Known-good version table (copy-paste pins for bisecting regressions)
- Suite green: any commit ≥ befa59d (88/88; earlier trees had 87/76/67/46 counts — see GAUNTLET era notes).
- SC-11 green: any commit ≥ befa59d (migrate guard present; verify with grep).
- F5 green: any commit ≥ 7fb2cdf (watchdog + markers + standalone test present).
- Preview-survives: any commit ≥ 5b2b5a3 (mount fix present).
- AX-card asserts: any commit ≥ 5b2b5a3 (container flag present).
- Save-tap retry: any commit ≥ 8dfd8e3.
-connected-only tier: any commit ≥ 5b2b5a3 (driver --no-uninstall + test).
- Bisect rule: `git checkout <sha>` + guest sync + single take; never bisect by editing forward.
- Rollback rule: restore = checkout hash + rebuild + one confirmation take (nuke option per deep-container-testing loop law).

## Dependency pins (exact, with why)
- SwiftTerm: `migueldeicaza/SwiftTerm` from 1.15.0 (`project.yml:30`, `Package.swift`) — 2.0.0 does not exist (CI history); Metal OFF on sim (SwiftTerm SIGABRTs under XCUITest — `configureRenderer` guard).
- swift-libgit2: REMOVED (needs Swift 6.1, incompatible) — ForgeGitManager stubbed Phase 2 (not a gap in this wave's scope).
- esbuild ^0.23.1 + typescript ^5.5.4 (`forge/package.json:22-23`); path-browserify ^1.0.1; sql.js ^1.10.3. Node>=18 / Bun>=1.1 for the build phase.
- Pyodide 0.27.7 vendored (`Resources/pyodide/`: asm.js/wasm, stdlib zip, lockfile); setStdout/setStderr capture; forgepy:// scheme handler; wasm MIME mapped.
- xcodegen via brew (guest `/Users/useruser/bin/xcodegen`); project.yml is the source of truth (xcodeproj never committed).
- Host toolchains: python3 + pytest (suite), node (bundle check), bun (hooks/probes), ffmpeg/ffprobe (stills/mux), socat/sshpass (rig), ruby/fastlane evaluated then dropped (password-auth retired — T9 record).
- Guest toolchain: Xcode 26.6 (17F113), xcodebuild iphoneos+iphonesimulator, simctl (record/io/diagnose), ad-hoc signing (CODE_SIGN_IDENTITY=-, keychain-group-only entitlements).

## Build environment record (where builds run)
- Sim takes: guest 6GB start-tahoe, DerivedData FORGE-* (rebuildable), TEST BUILD via driver (build-for-testing + test-without-building split).
- Device: Release-iphoneos unsigned 22MB proven (plugin-skip flags required); signing needs Apple-ID session (T9 open).
- Host: no Swift toolchain (`swift: command not found`) — Swift compiles on guest only; host runs pytest/node/ffmpeg/probes.
- Air (future): Xcode 16+ + xcodegen + node + Apple ID + plugged iPhone per AGENT_MACBOOK_AIR.md; air-drop branch is its source.

## Drift red flags (check on every update of this file)
- Bundle SHA in EVIDENCE_STATE ≠ `sha256sum` output → rebuild or reconcile before any other work (F5 audit rule).
- Suite count ≠ 88 → a product edit broke tests or a test file went missing; bisect by file.
- Commit message without take ids → row first, then amend the message (never rewrite pushed history).
- New dependency without a pin row above → add it with version + reason + date.
- New frozen item (someone declares "don't touch X") → needs a wave + take proving the freeze, else it's superstition.
- air-drop/master divergence beyond product-vs-history split → reconcile (cherry-pick direction: master→air-drop for product, never reverse bulk).
- Evidence dir missing a take referenced in GAUNTLET → restore from guest (DerivedData/sim logs may still hold it) or mark the row EVIDENCE-LOST (never silently).
- Watcher verdict referenced but still files absent → verdict void; re-take.

## Amendment procedure (how this file changes)
- New commits: append one line to the chain + file record (never rewrite old lines).
- New SHAs: append to artifact section with the causing edit named.
- Inventory: recount on structural changes (new dirs, moved files); `find -type f | wc -l` per dir.
- Frozen list: additions require a wave id + proving take; removals require operator order + row.
- This file itself: updated on every milestone that changes build inputs/outputs (per canon frequency rule).

## Known unknowns (tracked, not ignored)
- Which exact commit introduced the 2.8G backups tarball into history (push-blocker forensics incomplete; size measured via bundle dry-run 3.5GB).
- Whether live-tree pre-existing dirt (MissionControlScreen etc.) compiles green on device (untouched by this wave; Air will prove it).
- Live GET /v1/models content that triggered the migrate replacement (inferred from post-relaunch model string, never captured raw).
- Pyodide cold-load wall time on fresh guest (bounded by watchdog error, never timed precisely).
- Guest memory pressure origin during t114-t120 cluster (emulator/host-side per elimination, no single hog found).
- Each resolves by measurement when its work item opens — never by guessing in this file.

## Ownership map (who unblocks what — no diffusion)
- Product code + takes + seals: primary agent (this loop; task-tracked T1-T11).
- Rig hardware/VM lifecycle: primary agent via run-forge-vm.sh (proven); volume never wiped by anyone.
- Signing identity + Apple ID + USB + phone smoke: operator only (T9 documents attempts + walls).
- API quota/keys: operator owns issuance + rotation; agent owns backoff + probes + hygiene.
- Disk: operator approves archives; agent executes + manifests.
- Concurrent sessions: each owns its takes + mutex discipline; shared sim/keys/disk are commons — poll before burn.
- Seal locks (chattr): operator-owned guardian layer; agents document, never attempt.
- Push protection verdicts: agent redacts + amends; operator rotates exposed secrets.

## Floor note
- Met 2026-09-11 (T11 docs pass). Chain, inventory, SHAs, pins, red flags all measured this session — no remembered numbers.
- Review cadence: every milestone re-reads chain-top 5 + verifies bundle SHA + suite count.
- Next expected entry: F5-regression or operator-handoff movement.
- Archive rule: this file never shrinks; corrections append as new lines.
- Reader test: a stranger finds any take's code state from the take-to-commit map alone.
- Density check: every section names files, hashes, counts, or commands.
- Status: CURRENT as of T11 gate run.
- Owner of next update: whoever closes the next milestone.
