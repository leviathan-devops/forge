# macOS VM — Complete Operating Manual

**Last Updated:** 2026-07-27 — Wave 7
**Status:** QEMU + VNC + Monitor WORKING. macOS boots but kernel stuck in verbose phase.
**Container:** forge-vm (Docker-OSX Arch Linux, privileged, KVM)

---

## 1. WHAT WORKS (Verified)

### Screenshot Capture — WORKS
```bash
# From HOST (port 5900 mapped to container):
vncsnapshot -quiet localhost:0 /tmp/screenshot.jpg

# Display 0 = port 5900 in VNC notation
# Produces 1920x1080 JPEG, ~1MB
```

### Keyboard Input — WORKS (via QEMU Monitor, NOT VNC)
```bash
# MUST connect from INSIDE the container (monitor binds to 127.0.0.1:4444)
docker exec forge-vm python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(5)
s.connect(('127.0.0.1', 4444))
time.sleep(0.5)
s.recv(4096)  # read banner
s.send(b'sendkey ret\n')  # Send Enter key
time.sleep(0.5)
print(s.recv(4096).decode())
s.close()
"
```

### Common sendkey Commands
```bash
# Single keys
sendkey ret          # Enter/Return
sendkey esc          # Escape
sendkey tab          # Tab
sendkey space        # Spacebar
sendkey backspace    # Backspace
sendkey up           # Arrow Up
sendkey down         # Arrow Down
sendkey left         # Arrow Left
sendkey right        # Arrow Right

# Modifier combinations
sendkey shift-a      # Shift + A
sendkey ctrl-c       # Ctrl + C
sendkey alt-f4       # Alt + F4
sendkey ctrl-alt-delete  # Ctrl+Alt+Del

# For typing text, send each character:
sendkey a
sendkey b
sendkey c
# Or use: sendkey a-b-c (chained, but unreliable)
```

### Mouse Input — WORKS (via VNC RFB)
```python
# Python RFB pointer events (from host, via vncdotool or raw socket)
import socket, struct, time

def connect_vnc():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(10)
    s.connect(('localhost', 5900))
    s.recv(12); s.send(b'RFB 003.008\n')
    s.recv(2); s.send(bytes([1]))
    import struct; struct.unpack('>I', s.recv(4))
    s.send(b'\x01')
    data = b''
    while len(data) < 24: data += s.recv(24 - len(data))
    return s

def send_click(s, x, y):
    # RFB PointerEvent: type(1B=5) + button-mask(1B) + x(2B) + y(2B)
    s.send(struct.pack('>BBHH', 5, 0, x, y))   # move (no button)
    time.sleep(0.1)
    s.send(struct.pack('>BBHH', 5, 1, x, y))   # left button down
    time.sleep(0.15)
    s.send(struct.pack('>BBHH', 5, 0, x, y))   # release
    time.sleep(0.3)

# Button masks: 1=left, 2=middle, 4=right, 8=scroll-up, 16=scroll-down
```

### VNC Connection Check
```bash
# Check VNC port from host
nc -z -w3 localhost 5900 && echo "VNC OPEN" || echo "VNC CLOSED"

# Get container IP
docker inspect forge-vm --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
```

---

## 2. WHAT DOESN'T WORK

| Tool | Issue | Workaround |
|------|-------|------------|
| vncdotool (Python API) | Twisted reactor connection refused | Use vncsnapshot instead |
| vncdotool CLI | Same Twisted issue | Use vncsnapshot |
| VNC keyboard (RFB key events) | QEMU USB keyboard not processed by macOS/OpenCore | Use QEMU monitor sendkey |
| GTK display (`-display gtk`) | "gtk initialization failed" — XWayland auth issue | Use VNC display only |
| Weston + scrot | XWayland rootless mode prevents X11 capture | Use vncsnapshot |
| grim (Wayland screenshot) | "failed to create display" — Weston headless backend | Use vncsnapshot |
| Docker commit for qcow2 | qcow2 disk changes NOT captured by docker commit | Volume mount or separate save |
| macOS keyboard in Recovery | USB keyboard emulation fails in macOS Recovery | Use QEMU monitor sendkey |

---

## 3. CONTAINER SETUP (Complete Recreation)

### Step 1: Create Container
```bash
docker run -d \
  --name forge-vm \
  --privileged \
  --device /dev/kvm \
  -v /home/leviathan/OPENCODE_WORKSPACE/FORGE:/app \
  -p 50922:10022 \
  -p 5900:5900 \
  sickcodes/docker-osx:latest \
  bash -c 'sleep infinity'
```

### Step 2: Install Packages
```bash
docker exec -u root forge-vm bash -c '
  pacman -Syu --noconfirm weston xorg-xwayland scrot xdotool dbus python3
'
```

### Step 3: Get macOS BaseSystem
```bash
# Option A: Extract from Docker image (FASTER)
docker create --name ext macos-forge-container:v2-working
docker cp ext:/home/arch/OSX-KVM/BaseSystem.qcow2 /tmp/BaseSystem.qcow2
docker cp ext:/home/arch/OSX-KVM/OpenCore/OpenCore.qcow2 /tmp/OC.qcow2
docker rm ext
docker cp /tmp/BaseSystem.qcow2 forge-vm:/home/arch/OSX-KVM/
docker cp /tmp/OC.qcow2 forge-vm:/home/arch/OSX-KVM/OpenCore/OpenCore.qcow2

# Option B: Download from Apple (SLOWER, ~5 min)
docker exec -u root forge-vm bash -c '
  cd /home/arch/OSX-KVM
  echo "7" | python3 fetch-macOS-v2.py  # 7 = Sonoma
  # Convert DMG to qcow2 (dmg2img needed for Apple DMG format)
  pacman -S --noconfirm dmg2img
  dmg2img BaseSystem.dmg BaseSystem.img
  qemu-img convert -f raw -O qcow2 BaseSystem.img BaseSystem.qcow2
'
```

### Step 4: Create Disk + Configure
```bash
docker exec -u root forge-vm bash -c '
  cd /home/arch/OSX-KVM
  qemu-img create -f qcow2 mac_hdd_ng.img 64G
  echo 1 > /sys/module/kvm/parameters/ignore_msrs
'
```

### Step 5: Start QEMU (THE WORKING COMMAND)
```bash
docker exec -d -u root forge-vm bash -c '
  export XDG_RUNTIME_DIR=/tmp
  export HOME=/home/arch
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
    -drive id=InstallMedia,if=none,file=BaseSystem.qcow2,format=qcow2 \
    -device ide-hd,bus=sata.3,drive=InstallMedia \
    -drive id=MacHDD,if=none,file=mac_hdd_ng.img,format=qcow2 \
    -device ide-hd,bus=sata.4,drive=MacHDD \
    -netdev user,id=net0,hostfwd=tcp::10022-:22 \
    -device vmxnet3,netdev=net0,id=net0,mac=52:54:00:c9:18:27 \
    -device vmware-svga \
    -vnc 0.0.0.0:0 \
    -k en-us \
    -monitor telnet:127.0.0.1:4444,server,nowait \
    > /tmp/qemu.log 2>&1
'
```

**Key flags explained:**
- `-vnc 0.0.0.0:0` — VNC display on port 5900 (display 0)
- `-monitor telnet:127.0.0.1:4444,server,nowait` — QEMU monitor on port 4444 (for sendkey)
- `-device vmware-svga` — VGA device for rendering
- `-device usb-kbd,bus=xhci.0` — USB keyboard (works via sendkey, not VNC)
- `-device usb-tablet,bus=xhci.0` — USB mouse tablet (absolute positioning)
- `-k en-us` — Keyboard layout US English
- NO `-display gtk` (causes crash)
- NO `-display none` (use VNC instead)

### Step 6: Boot macOS from OpenCore
```bash
# Wait 60s for OpenCore to load
sleep 60

# Send Enter key via QEMU monitor to boot selected option
docker exec forge-vm python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(5)
s.connect(('127.0.0.1', 4444))
time.sleep(0.5)
s.recv(4096)
s.send(b'sendkey ret\n')
time.sleep(1)
s.close()
"
```

---

## 4. CURRENT STATE (as of 2026-07-27)

### macOS Boot Status
- OpenCore boot picker: WORKING (visible, responds to mouse clicks for selection)
- `sendkey ret`: WORKING (boots selected OpenCore option — 358K pixels changed)
- macOS verbose boot: STARTS (Darwin kernel 23.6.0 messages appear)
- macOS Recovery GUI: NOT REACHED (kernel gets stuck in verbose boot)
- Screen is STATIC after initial boot text appears
- QEMU CPU usage: Low (~9.9%) — suggests kernel is idle/stuck, not actively booting

### Diagnosis
macOS Sonoma kernel starts booting but freezes during driver initialization.
Possible causes:
1. macOS Sonoma requires CPU features QEMU doesn't emulate
2. Specific driver hangs (USB, network, or graphics)
3. Memory allocation issue (7192MB might be insufficient)
4. macOS Sonoma BaseSystem might be incompatible with this QEMU version

### Potential Fixes (for next session)
1. Try macOS Ventura (13) instead of Sonoma (14) — older = more compatible
2. Increase RAM to 8192MB or more
3. Add more CPU cores: `-smp 8,cores=4,sockets=2`
4. Try different CPU model: `-cpu host` (pass-through host CPU)
5. Disable verbose boot: configure OpenCore to not use `-v`
6. Use a pre-built Docker-OSX image with macOS already installed

---

## 5. DOCKER IMAGES

| Image | Size | Contents | Status |
|-------|------|----------|--------|
| `sickcodes/docker-osx:latest` | 4.28GB | Docker-OSX base (Arch Linux + QEMU) | Base image |
| `macos-forge-container:master` | 11.3GB | node:20-bullseye + Weston + QEMU + macOS images | Older setup |
| `macos-forge-container:v2-working` | 7.28GB | Docker-OSX + Weston + macOS BaseSystem + tools | LATEST |

---

## 6. SCREENSHOT ANALYSIS TOOLS

```python
# Quick brightness check
python3 -c "
from PIL import Image; import numpy as np
img = Image.open('/tmp/screenshot.jpg')
arr = np.array(img)
b = arr.mean(axis=2)
print(f'Brightness: {b.mean():.1f}')
print(f'Bright pixels: {(b > 100).sum()}')
print(f'Blue pixels: {((arr[:,:,0]<80)&(arr[:,:,1]>60)&(arr[:,:,2]>80)).sum()}')
"

# Pixel diff between two screenshots
python3 -c "
from PIL import Image; import numpy as np
a1 = np.array(Image.open('/tmp/snap1.jpg'))
a2 = np.array(Image.open('/tmp/snap2.jpg'))
diff = (np.abs(a1.astype(int) - a2.astype(int)).sum(axis=2) > 30).sum()
print(f'Pixels changed: {diff}')
"

# Find blue UI elements (buttons, progress bars)
python3 -c "
from PIL import Image; import numpy as np
arr = np.array(Image.open('/tmp/snap.jpg'))
blue = (arr[:,:,0] < 80) & (arr[:,:,1] > 60) & (arr[:,:,2] > 80)
if blue.sum() > 0:
    by = np.where(blue.any(axis=1))[0]
    bx = np.where(blue.any(axis=0))[0]
    print(f'Blue area: x={bx.min()}-{bx.max()} y={by.min()}-{by.max()} ({blue.sum()} pixels)')
"
```

---

## 7. AUTOMATION HELPER SCRIPTS

### sendkey.sh (Execute inside container)
```bash
#!/bin/bash
# Usage: docker exec forge-vm /tmp/sendkey.sh ret
docker exec forge-vm python3 -c "
import socket, time, sys
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(5)
s.connect(('127.0.0.1', 4444))
time.sleep(0.5)
s.recv(4096)
s.send(b'sendkey ${1:-ret}\n')
time.sleep(0.5)
s.close()
"
```

### screenshot.sh (Execute on host)
```bash
#!/bin/bash
# Usage: ./screenshot.sh output.jpg
vncsnapshot -quiet localhost:0 "${1:-/tmp/snap.jpg}"
echo "Saved: ${1:-/tmp/snap.jpg} ($(stat -c%s "${1:-/tmp/snap.jpg}") bytes)"
```

### type_text.py (Type via sendkey)
```python
# Usage: docker exec forge-vm python3 /tmp/type_text.py "Hello World"
import socket, time, sys

text = sys.argv[1] if len(sys.argv) > 1 else ""
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(5)
s.connect(('127.0.0.1', 4444))
time.sleep(0.5)
s.recv(4096)

for char in text:
    if char == ' ':
        key = 'space'
    elif char == '\n':
        key = 'ret'
    elif char.isupper():
        key = f'shift-{char.lower()}'
    else:
        key = char
    s.send(f'sendkey {key}\n'.encode())
    time.sleep(0.15)
    try:
        s.recv(4096)
    except:
        pass

s.close()
```

---

## 8. PORT MAPPING REFERENCE

| Host Port | Container Port | Service |
|-----------|---------------|---------|
| 5900 | 5900 | VNC display (QEMU) |
| 50922 | 10022 | SSH (macOS, after install) |
| 6310 | 9222 | CDP (unused) |
| (internal) | 4444 | QEMU monitor (telnet, 127.0.0.1 only) |

---

## 9. FULL INSTALLATION FLOW (For Working macOS)

1. Start container (Step 1-5 above)
2. Wait 60s for OpenCore
3. `sendkey ret` to boot macOS BaseSystem
4. Wait 120-300s for macOS Recovery GUI (verbose boot is SLOW)
5. Use `sendkey` to navigate: Terminal → `diskutil eraseDisk APFS MacintoshHD GPT /dev/disk0`
6. Quit Terminal: `sendkey ctrl-q` (Cmd+Q doesn't work — try alt-f4 or click)
7. Navigate to "Reinstall macOS Sonoma" via mouse clicks
8. Click Continue, Agree, Select disk, Install
9. Wait 30-60 minutes for installation
10. Complete Setup Assistant (language, user account)
11. Enable SSH: System Settings → Sharing → Remote Login
12. `ssh -p 50922 user@localhost`
13. Install Xcode: `xcode-select --install`

---

## 10. TROUBLESHOOTING

### QEMU won't start
```bash
docker exec forge-vm cat /tmp/qemu.log | tail -10
# Common issues: invalid parameter, file not found, permission denied
```

### Monitor connection refused
```bash
# Check if monitor is listening
docker exec forge-vm ss -tlnp | grep 4444
# Must connect from INSIDE container (127.0.0.1:4444)
# NOT from host
```

### VNC connection refused
```bash
# Check port mapping
docker port forge-vm
# Check QEMU alive
docker exec forge-vm pgrep -c qemu
```

### macOS stuck in verbose boot
- This is the CURRENT issue. Try:
  1. Different macOS version (Ventura instead of Sonoma)
  2. More RAM (`-m 8192` or higher)
  3. Different CPU (`-cpu host` for passthrough)
  4. Disable specific devices that might cause hangs
  5. Check QEMU log for hardware errors
