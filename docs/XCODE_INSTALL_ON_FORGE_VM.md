# Install full Xcode on forge-vm (required for xcodebuild -sdk iphonesimulator)

## Why
Command Line Tools alone **cannot** build iOS apps. FORGE needs **Xcode.app** with iOS Simulator SDK.

## Guest facts
- SSH: `ssh -p 50922 user@127.0.0.1` (password `alpine`)
- Disk: ~241 GiB free on `/` (enough for Xcode ~10–15 GB)
- CLT may be installable via `softwareupdate` (helps tools, not sim)

## Path A — App Store / GUI (most reliable)
1. `./docker/run-forge-vm.sh vnc-host && vncviewer 127.0.0.1:5901`
2. Log in as `user` / `alpine`
3. Open App Store → install **Xcode** (Apple ID required)
4. Open Xcode once → accept license → install components
5. Terminal:
```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
xcodebuild -version
```

## Path B — xcodes CLI (needs Apple ID)
```bash
# after brew install
brew install xcodesorg/made/xcodes aria2
xcodes install --latest --experimental-unxip
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Path C — Developer portal .xip
1. Download Xcode .xip from https://developer.apple.com/download/all/ (Apple ID)
2. scp into guest `~/Downloads`
3. `xip -x Xcode_*.xip && sudo mv Xcode.app /Applications/`

## After Xcode is present
```bash
# host
./scripts/deploy-to-vm.sh
# guest
cd ~/FORGE
# install xcodegen if needed: brew install xcodegen
xcodegen generate
xcodebuild -scheme FORGE -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## PASS 2026-07-31 (Tahoe 26.6 + Xcode 26.6)

- Guest OS: macOS **26.6** (25G72) · SSH `user`/`alpine` `:50922`
- Xcode: **26.6** Build **17F113** at `/Applications/Xcode.app`
- Host xip: `/home/leviathan/Downloads/Xcode_26.6_Universal.xip` → SFTP → guest `xip -x`
- After install also required:
  - `xcodebuild -downloadPlatform iOS` (iOS 26.5 sim runtime ~10.6 GB)
  - `xcodebuild -downloadComponent MetalToolchain` (SwiftTerm metal)
- Build: `xcodebuild -scheme FORGE -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO` → **BUILD SUCCEEDED**
- Evidence: `tmp/evidence/xcode/` · Report: `Reports/FORGE_XCODE26_TAHOE_E2E_FORENSIC_REPORT.md`

## Historical (2026-07-30 Sonoma residual)
- Guest: **NO Xcode.app** at that time
- CLT alone cannot unlock iphonesimulator ship path
