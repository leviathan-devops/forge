# AGENT MACBOOK AIR — COMPILE / SIGN / RUN HANDOFF

Role split (operator order): the VM guest is the TEST RIG (XCUITest takes, evidence, sim);
this Mac is the COMPILE + SIGN + RUN machine (Air is slow at emulation, fast at Xcode).
You are the agent on the Air. Read this whole file before touching anything.

## 0. Current state (as pushed)
- Branch `master` at commit `79277310c6816469b408cb4420c444149343d8ba` (replaced at push time with the real SHA).
- What works on sim (proven on tape, GAUNTLET_PROGRESS.md t76-t125): /connect auth + Keychain
  persistence + double live-200 (SC-11), deterministic write→run→render chain (t98), soak
  (background/tabs/relaunch, t100/t103), live-agent stdout + preview (t121/t125, watcher PASS).
- Suite: `python3 -m pytest tests -q` → 88 passed. Bundle: `node --check` clean.
- Open (do NOT claim these): SSE token-streaming absent (chunked only), plain-words UX
  unmapped, TestFlight (needs paid membership), key rotation, disk on the VM side.

## 1. Prerequisites (install once)
- Xcode 16+ from the App Store. `brew install xcodegen`. `node >= 18` (or bun) for the
  `scripts/xcode-build-phase.sh` bundler. Python 3 + pytest (`pip install pytest`) for the suite.
- Apple ID signed into Xcode (operator's screen, never paste credentials anywhere).

## 2. First build (unsigned device-arch check, no signing needed)
```bash
git clone https://github.com/leviathan-devops/forge.git && cd forge
git checkout air-drop   # product tree branch (full history stays on master)
git log --oneline -1   # must match 79277310c6816469b408cb4420c444149343d8ba
xcodegen generate
xcodebuild build -project FORGE.xcodeproj -scheme FORGE -sdk iphoneos -configuration Release \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  -skipPackagePluginValidation -skipMacroValidation
```
PASS = `BUILD SUCCEEDED` + `Release-iphoneos/FORGE.app` present. This exact command is proven green.

## 3. Sign + install on the plugged-in iPhone
1. Xcode → Settings → Accounts → Apple ID (operator). Project → Signing → Team = Personal Team
   (free tier: re-sign weekly). Bundle id stays `com.forge.app`.
2. `xcodebuild archive -project FORGE.xcodeproj -scheme FORGE -destination 'generic/platform=iOS' -archivePath build/FORGE.xcarchive`
3. Export: Xcode Organizer → Distribute App → Development (or `xcodebuild -exportArchive`).
4. Install: Xcode Devices window → drag `.ipa` onto the iPhone (or Sideloadly/AltStore).
5. iPhone: Settings → General → VPN & Device Management → trust the Apple ID.
6. API key on device: open FORGE → Settings or `/connect` flow, enter the operator's OWN Go key
   via SecureField. NEVER commit keys, NEVER use a key pasted in any chat for anything but entry.

## 4. 10-minute smoke (row it in GAUNTLET_PROGRESS.md, new take id = next tNNN)
connect status → provider/model/url → secure key → live 200 → agent turn (write+run+preview)
→ background 60s → foreground intact → terminate → relaunch → status configured + live 200.
Row PASS/FAIL honestly with stills referenced.

## 5. Commit-back contract (so the VM rig and the Air never diverge)
- FIRST: `git pull --rebase origin master`. NO force-push to master, ever.
- COMMIT source + tests + docs + UITests ONLY. NEVER commit: DerivedData/, *.xcworkspace/,
  FORGE.xcodeproj/ (xcodegen-regenerable), *.ipa, *.xcarchive, API keys, auth.json, .env,
  screenshots outside Evidence/play/cycle-*, node_modules/.
- BEFORE push: `python3 -m pytest tests -q` (expect 88 passed) + `node --check iOS/FORGE/Resources/forge-bundle.js`.
- AFTER push: report the new SHA back. The VM rig rebases onto it for the next take wave.
- Merge conflicts: product code from the newest green take wins; ledger files (GAUNTLET/TESTING_LOG)
  append both sides' rows, never drop either.
