# FORGE — Post-Compaction Workflow: Headed Display macOS VM Testing

**Last Updated:** 2026-07-27 Wave 7
**Status:** GTK display still fails. VNC display works. Use vncsnapshot + sendkey (NOT Weston/GTK).
**NOTE:** This doc describes the ORIGINAL headed display approach. The ACTUAL working approach is documented in `17_MACOS_VM_OPERATING_MANUAL.md` — use VNC display + vncsnapshot + QEMU monitor sendkey.

**CRITICAL:** This is an iOS app. The ENTIRE thing is a UX system. Headless testing is FORBIDDEN. You MUST use a headed Weston + XWayland virtual display to see the macOS GUI, interact with the macOS installer, and test the iOS Simulator.

## Why Headed (NOT Headless)

1. macOS Installation requires GUI interaction (clicking through Disk Utility, installer wizard)
2. macOS Recovery keyboard input FAILS over VNC (QEMU USB keyboard emulation bug)
3. Weston's compositor synthesizes pointer events that reach the macOS GUI — VNC does not
4. `scrot` captures pixel-perfect screenshots from the compositor — VNC screenshots are lossy
5. `xdotool` sends keyboard/mouse events through the compositor — VNC keyboard is unreliable
6. This is an iOS app — you need to SEE the UI to verify quality

## Prerequisites

- Docker with KVM support (`/dev/kvm` exists)
- Intel GPU accessible (Raptor Lake-S UHD Graphics on this system)
- 16GB+ RAM available
- container-virtual-display skill loaded
- Docker-OSX image pulled (`sickcodes/docker-osx:latest`)

## Step 1: Create Headed Display Container

Use the container-virtual-display skill's setup script, but with Docker-OSX as the base image instead of node:20-bullseye:

```bash
# Create container with Weston + KVM + Intel GPU
docker run -d \
  --name forge-vm \
  --privileged \
  --device /dev/kvm \
  --device /dev/dri/card1 \
  --device /dev/dri/renderD128 \
  -v /home/leviathan/OPENCODE_WORKSPACE/FORGE:/app \
  -p 50922:10022 \
  -p 6310:9222 \
  sickcodes/docker-osx:latest \
  bash -c 'sleep infinity'

# Install Weston + tools INSIDE the container (as root)
docker exec -u root forge-vm bash -c '
  pacman -Syu --noconfirm weston xorg-server-xvfb xorg-xinput scrot xdotool dbus python3
  
  # Set up display
  mkdir -p /tmp/.X11-unix
  chmod 777 /tmp/.X11-unix
  export XDG_RUNTIME_DIR=/tmp
  export HOME=/home/arch
  eval $(dbus-launch --sh-syntax) 2>/dev/null
  
  # Start Weston (HEADED virtual display)
  weston --backend=headless-backend.so --width=1920 --height=1080 --xwayland --log=/tmp/weston.log &
  sleep 5
  
  ls /tmp/.X11-unix/X0 && echo "DISPLAY :0 READY" || echo "DISPLAY FAILED"
'
```

## Step 2: Download macOS BaseSystem (if not already present)

```bash
docker exec -u root forge-vm bash -c '
  cd /home/arch/OSX-KVM
  
  if [ ! -f BaseSystem.img ]; then
    echo "7" | python3 fetch-macOS-v2.py  # Sonoma
    qemu-img convert BaseSystem.dmg -O raw BaseSystem.img
  fi
  
  if [ ! -f mac_hdd_ng.img ]; then
    qemu-img create -f qcow2 mac_hdd_ng.img 64G
  fi
  
  echo 1 > /sys/module/kvm/parameters/ignore_msrs
  ls -lh BaseSystem.img mac_hdd_ng.img
'
```

## Step 3: Boot macOS with HEADED Display

```bash
docker exec -d -u root forge-vm bash -c '
  export DISPLAY=:0
  export XDG_RUNTIME_DIR=/tmp
  cd /home/arch/OSX-KVM
  
  qemu-system-x86_64 \
    -enable-kvm -m 7192 \
    -cpu Penryn,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,check \
    -machine q35 \
    -device qemu-xhci,id=xhci \
    -device usb-kbd,bus=xhci.0 -device usb-tablet,bus=xhci.0 \
    -smp 4,cores=2,sockets=1 \
    -global ICH9-LPC.acpi-pci-hotplug-with-bridge-support=off \
    -device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc" \
    -drive if=pflash,format=raw,readonly=on,file=OVMF_CODE.fd \
    -drive if=pflash,format=raw,file=OVMF_VARS-1920x1080.fd \
    -smbios type=2 -device ich9-ahci,id=sata \
    -drive id=OpenCoreBoot,if=none,snapshot=on,format=qcow2,file=OpenCore/OpenCore.qcow2 \
    -device ide-hd,bus=sata.2,drive=OpenCoreBoot \
    -drive id=InstallMedia,if=none,file=BaseSystem.img,format=raw \
    -device ide-hd,bus=sata.3,drive=InstallMedia \
    -drive id=MacHDD,if=none,file=mac_hdd_ng.img,format=qcow2 \
    -device ide-hd,bus=sata.4,drive=MacHDD \
    -netdev user,id=net0,hostfwd=tcp::10022-:22 \
    -device vmxnet3,netdev=net0,id=net0,mac=52:54:00:c9:18:27 \
    -device vmware-svga \
    -display gtk \
    -k en-us \
    > /tmp/qemu.log 2>&1
'
```

**CRITICAL DIFFERENCE from headless approach:**
- `-display gtk` (NOT `-display none`) — renders to Weston's XWayland display
- `-device vmware-svga` (NOT `-vnc`) — uses VGA device, not VNC
- `DISPLAY=:0` environment variable set — QEMU knows where to render
- NO `-vnc` flag — eliminates the VNC keyboard bug entirely

## Step 4: Capture Screenshots

```bash
# Wait for macOS to boot (60-120 seconds)
sleep 90

# Capture screenshot from the HEADED display
docker exec forge-vm bash -c 'DISPLAY=:0 scrot /tmp/macos-screen.png'
docker cp forge-vm:/tmp/macos-screen.png /tmp/macos-screen.png

# Analyze with vision tool
# Use trident-omni-vision or zai-vision to analyze the screenshot
```

## Step 5: Interact with macOS via xdotool

```bash
# Click on an element (e.g., "Reinstall macOS Sonoma")
docker exec forge-vm bash -c 'DISPLAY=:0 xdotool mousemove 960 540 click 1'
sleep 2

# Type text (works in Weston — NOT in VNC!)
docker exec forge-vm bash -c 'DISPLAY=:0 xdotool type "Macintosh HD"'

# Press Enter
docker exec forge-vm bash -c 'DISPLAY=:0 xdotool key Return'

# Capture result
docker exec forge-vm bash -c 'DISPLAY=:0 scrot /tmp/macos-after-click.png'
docker cp forge-vm:/tmp/macos-after-click.png /tmp/macos-after-click.png
```

## Step 6: Complete macOS Installation

The macOS installation requires several GUI interactions:

1. **Disk Utility:** Format disk as APFS
   - Click "Disk Utility" → Continue
   - Select disk → Erase → "Macintosh HD" → APFS → Erase
   - Cmd+Q to quit Disk Utility

2. **Install macOS:** 
   - Click "Reinstall macOS Sonoma" → Continue
   - Agree to license (click Agree twice)
   - Select "Macintosh HD" → Continue
   - WAIT 30-60 minutes for installation

3. **Setup Assistant:**
   - Select region/language
   - Create user account: user / alpine
   - Skip Apple ID
   - Enable SSH in System Settings → Sharing

4. **Install Xcode:**
   - Download Xcode from Apple Developer Portal
   - Or use `xcode-select --install` for command line tools

## Step 7: Build FORGE in the macOS VM

Once macOS is installed and SSH is enabled:

```bash
# SSH into the macOS VM
ssh -p 50922 user@localhost

# Install xcodegen
brew install xcodegen

# Clone FORGE
git clone https://github.com/leviathan-devops/forge.git
cd forge

# Generate Xcode project
xcodegen generate

# Build for Simulator
xcodebuild build -project FORGE.xcodeproj -scheme FORGE -sdk iphonesimulator

# Run in Simulator
xcrun simctl boot "iPhone 16"
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/FORGE.app
xcrun simctl launch booted com.forge.app

# Capture screenshot from macOS VM display
# (Use scrot on the Linux host, or screencapture inside macOS)
```

## Debugging

### Display Not Working
```bash
docker exec forge-vm bash -c 'ls /tmp/.X11-unix/X0 && echo "READY" || echo "DOWN"'
docker exec forge-vm cat /tmp/weston.log | tail -10
docker exec forge-vm bash -c 'pgrep -a weston'
```

### QEMU Not Rendering
```bash
docker exec forge-vm cat /tmp/qemu.log | tail -10
docker exec forge-vm bash -c 'echo $DISPLAY'  # Should be :0
```

### Keyboard Not Working
If xdotool doesn't work, try the QEMU monitor:
```bash
docker exec forge-vm bash -c 'echo "sendkey ret" | nc -q1 localhost 4444'
```

### macOS Boot Loop
If macOS keeps returning to OpenCore boot menu, the installation is incomplete. Boot from BaseSystem and re-run the installer.

## Container Management

### Save State (Docker Commit)
```bash
docker commit forge-vm macos-forge-container:master
```

### Restart After Crash
```bash
docker restart forge-vm
# Wait for Weston to restart
docker exec forge-vm bash -c 'sleep 5; ls /tmp/.X11-unix/X0 && echo "READY"'
```

### Clean Restart
```bash
docker rm -f forge-vm
# Repeat from Step 1
```
