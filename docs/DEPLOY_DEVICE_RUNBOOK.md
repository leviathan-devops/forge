# FORGE — DEVICE DEPLOYMENT RUNBOOK (zero-cost, free Apple ID)

> Target: FORGE running on the operator's iPhone, NO paid Apple Developer
> account ($0). Free personal-team provisioning (7-day profiles) + direct
> USB install (no TestFlight). Everything runs inside the forge-vm macOS
> guest; the iPhone is passed through from the host USB.
> Verified states: 2026-08-11 (guest Tahoe 26.6, Xcode 26.6, device build
> compiles, USB passthrough attached the iPhone to the guest bus).

## THE TWO OPERATOR ACTIONS (nothing else is blocked on a human)

1. **Apple ID sign-in (once, ~30s)**: on the VM's GUI (VNC:
   `./docker/run-forge-vm.sh vnc-host` + `vncviewer 127.0.0.1:5901`),
   open Xcode → Settings → Accounts → add the FREE Apple ID
   (`copyresearch111@gmail.com` + its password). No paid enrollment —
   the free personal team appears. (Xcode is not logged in yet: verified
   2026-08-11 — no DVT account in the keychain.)
2. **Trust the computer (once, ~10s)**: with the iPhone plugged into the
   HOST USB, unlock it and tap **Trust** when macOS pairs. (The VM's USB
   bus already has the phone — verified 2026-08-11.)

## THE INFRA PATH (already done, for reference)

- iPhone on host: `lsusb` → `05ac:12a8` (Apple iPhone class).
- Container is privileged → after a container restart the phone's node
  appears in `/dev/bus/usb/001/005`.
- Attach to the guest's QEMU via the monitor (no reboot needed):
  `docker exec forge-vm python3 -c "import socket; s=socket.create_connection(('127.0.0.1',4444),3); s.send(b'device_add usb-host,vendorid=0x05ac,productid=0x12a8\n'); s.close()"`
  → `info usb` shows `USB Host Device` on the bus.
- If the phone was plugged AFTER the container start, restart the
  container first (`docker restart forge-vm`) then
  `./docker/run-forge-vm.sh up` to re-boot the guest (volume persists).

## THE INSTALL (once the Apple ID is signed in + phone trusted)

```bash
# on the VM (~/FORGE), as user:
UDID=$(xcrun devicectl list devices | grep -oE '[0-9A-F-]{36}' | head -1)
TEAM=$(xcrun xcodebuild -showBuildSettings 2>/dev/null | grep -m1 'DEVELOPMENT_TEAM = ' | awk '{print $3}')
[ -z "$TEAM" ] && TEAM=$(defaults read com.apple.dt.Xcode IDEProvisioningTeam 2>/dev/null)

# 1. DEVICE build with automatic signing (free team — creates the 7-day
#    dev cert + profile automatically; the app id com.forge.app must be
#    unique — it is)
xcodebuild -project FORGE.xcodeproj -scheme FORGE -configuration Debug \
  -sdk iphoneos -destination "id=$UDID" \
  -derivedDataPath /tmp/forge-dd-dev \
  -allowProvisioningUpdates CODE_SIGNING_ALLOWED=YES \
  DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic \
  build

# 2. INSTALL straight onto the phone (no TestFlight needed)
xcrun devicectl device install app --device "$UDID" \
  /tmp/forge-dd-dev/Build/Products/Debug-iphoneos/FORGE.app

# 3. LAUNCH + connect Mission Control to the fleet
xcrun devicectl device process launch --device "$UDID" com.forge.app
# in the app: Mission Control → Add Server → 192.168.100.7:18791 (host
# serve, your workspace fleet) or dragon.local:18792 (test node).
# mDNS auto-discovery works on a real LAN (the app now browses both
# _opencode._tcp and _http._tcp — NSBonjourServices declares both).
```

## SMOKE CHECKLIST ON THE PHONE (the 10-minute device test)

- [ ] App launches (no crash)
- [ ] MC: Add Server → 192.168.100.7:18791 → green dot
- [ ] Session list shows the workspace fleet incl. FORGE TEST SESSION 1
- [ ] Tap FORGE TEST SESSION 1 → the transcript renders (F8 navigation)
- [ ] Type a message in the composer → the host trident agent replies
- [ ] Eagle vision: pinch → live cards
- [ ] Terminal: open a session's terminal → FIRST command is clean (F2)
- [ ] mDNS: kill the app, relaunch → "Discovered on Network" lists the
      host serve (or use savedServers — manual entry always works)

## NOTES

- Free profiles expire in 7 days — re-install weekly (same commands).
- The phone's UDID is registered automatically by automatic signing.
- The project.yml keeps signing disabled for SIMULATOR builds
  (CODE_SIGNING_ALLOWED=NO); the device command above overrides with
  CODE_SIGNING_ALLOWED=YES + the free team.
- Info.plist carries NSLocalNetworkUsageDescription + NSBonjourServices
  (_opencode._tcp, _http._tcp) — the on-device mDNS prerequisites.
