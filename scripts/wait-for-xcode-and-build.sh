#!/bin/bash
# wait-for-xcode-and-build.sh — run on guest after Xcode.app is present
set -euo pipefail
export PATH="$HOME/bin:/usr/bin:/bin:$PATH"
if [[ ! -d /Applications/Xcode.app ]]; then
  echo "NO_XCODE_APP — install Xcode first (App Store / .xip)"
  exit 2
fi
echo alpine | sudo -S xcode-select -s /Applications/Xcode.app/Contents/Developer
echo alpine | sudo -S xcodebuild -license accept || true
xcodebuild -version | tee "$HOME/FORGE/tmp-xcodebuild-version.txt"
cd "$HOME/FORGE"
if [[ ! -d FORGE.xcodeproj ]]; then
  "$HOME/bin/xcodegen" generate
fi
# Resolve a simulator destination
DEST=$(xcrun simctl list devices available | awk -F'[()]' '/iPhone/{print $1; exit}' | xargs)
if [[ -z "${DEST:-}" ]]; then DEST="generic/platform=iOS Simulator"; fi
echo "DEST=$DEST"
set +e
xcodebuild -scheme FORGE -sdk iphonesimulator \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  -derivedDataPath "$HOME/FORGE/DerivedData" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  build 2>&1 | tee "$HOME/FORGE/xcodebuild-sim.log"
ec=${PIPESTATUS[0]}
if [[ $ec -ne 0 ]]; then
  xcodebuild -scheme FORGE -sdk iphonesimulator \
    -destination "generic/platform=iOS Simulator" \
    -derivedDataPath "$HOME/FORGE/DerivedData" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
    build 2>&1 | tee -a "$HOME/FORGE/xcodebuild-sim.log"
  ec=${PIPESTATUS[0]}
fi
exit $ec
