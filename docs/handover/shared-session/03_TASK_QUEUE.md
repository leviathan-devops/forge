# TASK QUEUE — FORGE iOS Build

**Last Updated:** 2026-07-27 Wave 7 — Post-compaction priority list

---

## PRIORITY 1: FIX macOS VM BOOT (BLOCKING EVERYTHING LOCAL)

### T-VM1: Try macOS Ventura instead of Sonoma
- **Why:** Sonoma kernel stuck in verbose boot. Ventura is older, more QEMU-compatible.
- **Steps:**
  1. Kill current QEMU: `docker exec -u root forge-vm bash -c 'pkill -9 qemu'`
  2. Download Ventura: `docker exec -u root forge-vm bash -c 'cd /home/arch/OSX-KVM && echo "6" | python3 fetch-macOS-v2.py'`
  3. Convert DMG: `dmg2img BaseSystem.dmg BaseSystem.img && qemu-img convert -f raw -O qcow2 BaseSystem.img BaseSystem-ventura.qcow2`
  4. Start QEMU with Ventura BaseSystem (see 17_MACOS_VM_OPERATING_MANUAL.md)
  5. Wait 60s, `sendkey ret`, wait 300s for Recovery GUI
  6. Check if screen changes: `vncsnapshot -quiet localhost:0 /tmp/check.jpg`
- **If Ventura also stuck:** Try `-cpu host` or more RAM (`-m 8192`)

### T-VM2: Alternative — try `-cpu host` CPU passthrough
- Modify QEMU command: replace `-cpu Penryn,...` with `-cpu host`
- This passes through actual Intel CPU features instead of emulating Penryn

### T-VM3: Alternative — use OpenCore nopicker config
- Use `OpenCore/OpenCore-nopicker.qcow2` instead of `OpenCore/OpenCore.qcow2`
- This auto-boots without showing the picker, might bypass the stuck state

---

## PRIORITY 2: COMPLETE macOS INSTALLATION (after boot fix)

### T-VM4: Format disk via Terminal
Once macOS Recovery GUI loads:
1. Open Terminal via Utilities menu (use mouse clicks + sendkey)
2. `sendkey` to type: `diskutil eraseDisk APFS MacintoshHD GPT /dev/disk0`
3. `sendkey ret` to execute
4. Wait 30s for format

### T-VM5: Run macOS installer
1. Close Terminal
2. Click "Reinstall macOS" in Utilities window
3. Click Continue, Agree (twice), Select disk, Install
4. Wait 30-60 min (monitor with vncsnapshot every 5 min)

### T-VM6: Complete Setup Assistant
1. Select language/region (sendkey + clicks)
2. Create user account: user/alpine (sendkey to type)
3. Skip Apple ID
4. Enable SSH: System Settings → Sharing → Remote Login

### T-VM7: Install Xcode
```bash
ssh -p 50922 user@localhost
xcode-select --install  # Command line tools
# Or download full Xcode from Apple Developer Portal
```

### T-VM8: Test FORGE in iOS Simulator
```bash
ssh -p 50922 user@localhost
cd /path/to/forge
xcodegen generate
xcodebuild build -project FORGE.xcodeproj -scheme FORGE -sdk iphonesimulator
xcrun simctl boot "iPhone 16"
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/FORGE.app
xcrun simctl launch booted com.forge.app
```

---

## PRIORITY 3: iOS APP FEATURES

### T-APP1: Phase 2 — Full opencode+Trident bundle
- Clone opencode v1.14.43 into vendor/opencode
- Clone Trident v4.4.2 SHIP into vendor/trident
- Replace vendor stubs with real module imports
- Run `node scripts/build-forge-bundle.mjs`
- Fix unshimmed modules iteratively
- Target: <5MB bundle

### T-APP2: libgit2 integration
- Build libgit2 as static C library via cmake + ios-cmake
- Create bridging header
- Replace ForgeGitManager stub with real implementation

### T-APP3: UI/UX Polish (REQUIRES working Simulator or macOS VM)
- Test terminal rendering visually
- Test keyboard input flow
- Test gesture system (direction-lock, Eagle Vision)
- Verify settings persistence
- Test project creation/management
- Polish animations and transitions

---

## PRIORITY 4: APP STORE (needs user input)

### T-SHIP1: Apple Developer account
- User creates account ($99/year)
- Generate App ID for com.forge.app
- Create code signing certificates

### T-SHIP2: TestFlight submission
- Fill fastlane/Appfile + Matchfile placeholders
- Add GitHub Secrets: APPLE_ID, FASTLANE_PASSWORD, TEAM_ID, etc.
- Tag release: `git tag v1.0.0-beta.1 && git push --tags`

---

## COMPLETED (Reference)
All previous tasks completed — see 02_BUILD_STATE.md and 04_CHANGELOG.md
