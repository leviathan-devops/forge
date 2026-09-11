#!/bin/bash
# forge-vm-setup.sh — Full automated macOS VM setup
# Runs INSIDE the forge-vm container
# Resource-limited: 2 cores, 4GB RAM (P-core + E-core)

set -e
cd /home/arch/OSX-KVM

echo "============================================"
echo "  FORGE macOS VM — Automated Setup"
echo "============================================"

# Step 1: Fix packages (targeted, not full upgrade)
echo "[1/8] Fixing packages..."
pacman -Sy --noconfirm --overwrite '*' socat 2>/dev/null || true
# Fix libnettle for XWayland if needed
pacman -Sy --noconfirm --overwrite '*' nettle wget dnsmasq 2>/dev/null || true
# Fix libgcc_s.so.1
if [ ! -e /usr/lib/libgcc_s.so.1 ]; then
    echo "Injecting libgcc_s.so.1..."
    docker run --rm archlinux:latest cat /usr/lib/libgcc_s.so.1 > /usr/lib/libgcc_s.so.1 2>/dev/null || true
fi
pacman -Sy --noconfirm --overwrite '*' gcc-libs libgomp libstdc++ 2>/dev/null || true

# Step 2: Download BaseSystem if not present
if [ ! -f /data/BaseSystem.img ]; then
    echo "[2/8] Downloading macOS Sonoma BaseSystem..."
    SHORTNAME=sonoma make BaseSystem.img mac_hdd_ng.img
    # Convert to qcow2
    qemu-img convert BaseSystem.dmg -O qcow2 -p -c /data/BaseSystem.img
    rm -f BaseSystem.dmg
    # Move disk to persistent volume
    cp mac_hdd_ng.img /data/mac_hdd_ng.img
else
    echo "[2/8] BaseSystem already exists on volume"
    # Symlink from OSX-KVM to /data
    ln -sf /data/BaseSystem.img BaseSystem.img
    ln -sf /data/mac_hdd_ng.img mac_hdd_ng.img
fi

# Ensure symlinks point to persistent storage
ln -sf /data/BaseSystem.img BaseSystem.img 2>/dev/null || true
ln -sf /data/mac_hdd_ng.img mac_hdd_ng.img 2>/dev/null || true

# Step 3: Modify Launch.sh
echo "[3/8] Configuring QEMU..."
cp Launch.sh.orig Launch.sh 2>/dev/null || cp Launch.sh Launch.sh.orig

# UHCI USB (not xHCI)
sed -i 's/-device qemu-xhci,id=xhci/-usb/' Launch.sh
sed -i 's/-device usb-kbd,bus=xhci.0 -device usb-tablet,bus=xhci.0/-device usb-kbd -device usb-tablet/' Launch.sh

# Telnet monitor
sed -i 's/-monitor stdio/-monitor telnet:127.0.0.1:4444,server,nowait/' Launch.sh

# Add VNC
sed -i '/^-vga vmware/a -vnc 127.0.0.1:0 \\' Launch.sh

# Remove audio
sed -i '/audiodev/d; /ich9-intel-hda/d; /hda-duplex/d' Launch.sh

# Add cache=unsafe for faster I/O
sed -i 's|format=${IMAGE_FORMAT:-qcow2}|format=qcow2,cache=unsafe,aio=threads|g' Launch.sh

# Remove screen share forward (conflicts with VNC)
sed -i 's/hostfwd=tcp::${SCREEN_SHARE_PORT:-5900}-:5900,//' Launch.sh

# Use nopicker OpenCore
sed -i 's|OpenCore/OpenCore.qcow2|OpenCore/OpenCore-nopicker.qcow2|' Launch.sh

echo "  Launch.sh configured"

# Step 4: Start Weston display
echo "[4/8] Starting Weston..."
pkill -9 weston 2>/dev/null || true
rm -rf /tmp/wayland-* /tmp/.X11-unix/* /tmp/.X0-lock
mkdir -p /tmp/weston-run /tmp/.X11-unix
chmod 0700 /tmp/weston-run
chmod 777 /tmp/.X11-unix
export XDG_RUNTIME_DIR=/tmp/weston-run
export HOME=/root
eval $(dbus-launch --sh-syntax) 2>/dev/null
/usr/bin/weston --backend=headless-backend.so --width=1920 --height=1080 --xwayland --log=/tmp/weston.log &
sleep 5
[ -e /tmp/.X11-unix/X0 ] && echo "  Weston OK" || echo "  Weston failed (non-critical)"

# Step 5: Start QEMU
echo "[5/8] Starting QEMU..."
export DISPLAY=:0
export XDG_RUNTIME_DIR=/tmp/weston-run
export HOME=/home/arch
export RAM=4
export SMP=2
export CORES=2
export SCREEN_SHARE_PORT=5901

bash ./Launch.sh > /tmp/qemu.log 2>&1 &
sleep 5

if pgrep -f "qemu-system-x86_64" > /dev/null; then
    echo "  QEMU running (PID: $(pgrep -f 'qemu-system-x86_64' | head -1))"
else
    echo "  QEMU FAILED"
    cat /tmp/qemu.log | tail -10
    exit 1
fi

echo "[6/8] Waiting 90s for macOS Recovery boot..."
sleep 90

# Step 6: Open Terminal and install macOS
echo "[7/8] Installing macOS via Terminal..."

# Monitor helper
qmon() { echo "$1" | socat -t 2 - TCP:127.0.0.1:4444 >/dev/null 2>&1; sleep 0.3; }

# Open Terminal via keyboard
qmon "sendkey ctrl-f2"
for i in 1 2 3 4; do qmon "sendkey right"; done
qmon "sendkey down"
for i in 1 2 3 4 5 6; do qmon "sendkey down"; done
qmon "sendkey ret"
sleep 5

# Type commands (using persistent Python typer)
python3 /tmp/qemu_typer.py "diskutil eraseDisk APFS MacintoshHD GPT /dev/disk1" 2>/dev/null
sleep 15

# Install macOS
python3 /tmp/qemu_typer.py '"/Install macOS Sonoma.app/Contents/Resources/startosinstall" --agreetolicense --volume "/Volumes/MacintoshHD 1"' 2>/dev/null

echo "[8/8] macOS installation started!"
echo "============================================"
echo "  Installation will take 20-30 minutes."
echo "  Then macOS will reboot (may take 60+ min"
echo "  for first boot due to SSV validation)."
echo "  DO NOT restart QEMU - just wait."
echo "============================================"
echo ""
echo "Monitor: socat - TCP:127.0.0.1:4444"
echo "SSH (after boot): ssh -p 50922 user@localhost"
