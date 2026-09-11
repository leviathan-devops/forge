# macOS VM Status — FORGE Docker Testing

**Last Updated:** 2026-07-27 Wave 7 (WORKING PIPELINE)
**Status:** macOS VM ALIVE — VNC + vncsnapshot + keyboard ALL WORKING

## Architecture
- Container: `forge-vm` (Docker-OSX Arch Linux, privileged, KVM)
- QEMU: macOS Sonoma 14.6 with VGA + VNC display
- VNC: localhost:5900 (mapped to host)
- Docker images: `macos-forge-container:v2-working` (7.28GB), `macos-forge-container:master` (11.3GB)

## What's Working (VERIFIED)
1. **vncsnapshot** captures screenshots from VNC: `vncsnapshot -quiet localhost:0 /tmp/snap.jpg`
2. **Python raw RFB** sends keyboard events (Enter confirmed working — 74K pixels changed)
3. **macOS responding** to keyboard input (screen changes detected via pixel diff)
4. **Content rendering** — text detected on dark background (verbose boot or boot menu)
5. **QEMU alive** with VGA device active, VNC serving framebuffer

## Working Tools
```bash
# Screenshot
vncsnapshot -quiet localhost:0 /tmp/screenshot.jpg

# Keyboard (Python)
python3 -c "
import socket, struct, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('localhost', 5900))
# RFB handshake
s.recv(12); s.send(b'RFB 003.008\n')
s.recv(2); s.send(bytes([1]))
import struct; struct.unpack('>I', s.recv(4))
s.send(b'\x01')
data = b''
while len(data) < 24: data += s.recv(24 - len(data))
# Send Enter key
s.send(struct.pack('>BBHI', 4, 1, 0, 0xFF0D))  # Key down
time.sleep(0.1)
s.send(struct.pack('>BBHI', 4, 0, 0, 0xFF0D))  # Key up
s.close()
"
```

## Common Keysyms
| Key | Keysym |
|-----|--------|
| Return | 0xFF0D |
| Tab | 0xFF09 |
| Escape | 0xFF1B |
| Space | 0x0020 |
| Backspace | 0xFF08 |
| Arrow Up | 0xFF52 |
| Arrow Down | 0xFF54 |
| Arrow Left | 0xFF51 |
| Arrow Right | 0xFF53 |

## Container Recreation (Post-Compaction)
```bash
docker run -d --name forge-vm --privileged --device /dev/kvm \
  -p 50922:10022 -p 5900:5900 \
  sickcodes/docker-osx:latest bash -c 'sleep infinity'

# Install packages
docker exec -u root forge-vm bash -c 'pacman -Syu --noconfirm weston xorg-xwayland scrot xdotool dbus python3'

# Copy macOS images
docker create --name ext macos-forge-container:v2-working
docker cp ext:/home/arch/OSX-KVM/BaseSystem.qcow2 /tmp/
docker cp ext:/home/arch/OSX-KVM/OpenCore/OpenCore.qcow2 /tmp/
docker rm ext
docker cp /tmp/BaseSystem.qcow2 forge-vm:/home/arch/OSX-KVM/
docker cp /tmp/OC.qcow2 forge-vm:/home/arch/OSX-KVM/OpenCore/OpenCore.qcow2

# Create disk + boot QEMU
docker exec -u root forge-vm bash -c '
  cd /home/arch/OSX-KVM
  qemu-img create -f qcow2 mac_hdd_ng.img 64G
  echo 1 > /sys/module/kvm/parameters/ignore_msrs
'
# Then start QEMU with -vnc 0.0.0.0:0 -device vmware-svga -k en-us
```

## What's NOT Working
- GTK display mode (`-display gtk`) fails with "gtk initialization failed" (XWayland authorization issue)
- vncdotool (Twisted-based Python VNC client) — connection refused (use vncsnapshot instead)
- Weston + scrot for screenshots — XWayland rootless mode prevents X11 screenshot capture
- macOS installation NOT yet completed (needs automated keyboard interaction via RFB)

## Next Steps for macOS Installation
1. Send Enter to select boot option
2. Wait for macOS Recovery to load
3. Use Terminal (Utilities menu) to format disk: `diskutil eraseDisk APFS MacintoshHD GPT /dev/disk1`
4. Select "Reinstall macOS Sonoma" and continue
5. Agree to license
6. Select disk and install
7. Wait 30-60 minutes for installation
8. Complete Setup Assistant
9. Enable SSH
10. Install Xcode

## Primary Testing Path
GitHub Actions macOS runner (macos-14 M1, Xcode 16.2, iOS 18.2 Simulator)
This is WORKING RELIABLY with 9+ successful builds.
The macOS VM is for LOCAL interactive testing and macOS installation.
