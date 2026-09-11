#!/bin/bash
# apply-launch-patches.sh — minimal safe patches to stock Docker-OSX Launch.sh
# Idempotent. Prefer stock Launch.sh + env over rewrite (start-qemu.sh is legacy).
#
# Patches:
#   1. UHCI USB (Recovery keyboard) instead of xHCI-only
#   2. telnet monitor :4444 for sendkey/screendump
#   3. optional -vnc 127.0.0.1:0
#   4. strip audio (ALSA noise in headless)
#   5. MacHDD cache=unsafe,aio=threads
#   6. strip Screen Share hostfwd on 5900 (conflicts with -vnc)
#   7. optional nopicker OpenCore
#   8. force BaseSystem format=raw when BASESYSTEM_FORMAT=raw (volume convert path)
#
# Install topology (do not reverse):
#   sata.3 InstallMedia = BaseSystem = guest disk0 — NEVER eraseDisk
#   sata.4 MacHDD       = mac_hdd_ng  = guest disk1 — ONLY install target

set -euo pipefail

OSX_KVM="${OSX_KVM:-/home/arch/OSX-KVM}"
cd "$OSX_KVM"

if [[ ! -f Launch.sh ]]; then
  echo "ERROR: Launch.sh missing in $OSX_KVM"
  exit 1
fi

if [[ ! -f Launch.sh.orig ]]; then
  cp -a Launch.sh Launch.sh.orig
  echo "Backed up Launch.sh → Launch.sh.orig"
fi

# Restore clean base then re-apply (idempotent)
cp -a Launch.sh.orig Launch.sh

# UHCI for Recovery
sed -i 's|-device qemu-xhci,id=xhci|-usb|' Launch.sh || true
sed -i 's|-device usb-kbd,bus=xhci.0 -device usb-tablet,bus=xhci.0|-device usb-kbd -device usb-tablet|' Launch.sh || true
sed -i 's|-device usb-kbd,bus=xhci.0|-device usb-kbd|' Launch.sh || true
sed -i 's|-device usb-tablet,bus=xhci.0|-device usb-tablet|' Launch.sh || true

# Monitor: telnet for automation
sed -i 's|-monitor stdio|-monitor telnet:127.0.0.1:4444,server,nowait|' Launch.sh || true

# VNC for optional viewer (screendump remains primary)
if ! grep -q -- '-vnc 127.0.0.1:0' Launch.sh; then
  # insert after -vga vmware line if present
  if grep -q -- '-vga vmware' Launch.sh; then
    sed -i '/-vga vmware/a\    -vnc 127.0.0.1:0 \\' Launch.sh || true
  fi
fi

# Strip audio devices (do not leave comments mid-backslash chains)
sed -i '/audiodev/d;/ich9-intel-hda/d;/hda-duplex/d' Launch.sh || true

# Faster qcow2 writes on MacHDD path
sed -i 's|format=${IMAGE_FORMAT:-qcow2}|format=qcow2,cache=unsafe,aio=threads|g' Launch.sh || true
sed -i 's|format=\${IMAGE_FORMAT:-qcow2}|format=qcow2,cache=unsafe,aio=threads|g' Launch.sh || true

# BaseSystem format: detect actual image (volume dmg convert → raw). Never trust env alone
# (container may ship BASESYSTEM_FORMAT=qcow2 while /data/BaseSystem.img is raw).
BS_IMG="${OSX_KVM}/BaseSystem.img"
BS_FMT="${BASESYSTEM_FORMAT:-}"
if [[ -e "$BS_IMG" ]] && command -v qemu-img >/dev/null 2>&1; then
  det=$(qemu-img info "$BS_IMG" 2>/dev/null | sed -n 's/^file format: *//p' | head -1 || true)
  if [[ -n "$det" ]]; then
    BS_FMT="$det"
  fi
fi
# Prefer explicit detection; default raw (dmg→raw path used by forge)
BS_FMT="${BS_FMT:-raw}"
echo "InstallMedia BaseSystem format → ${BS_FMT}"
# Replace any ${BASESYSTEM_FORMAT:-...} or literal format=... on the BaseSystem drive line
sed -i -E "s|(file=/home/arch/OSX-KVM/BaseSystem.img),format=\$\{BASESYSTEM_FORMAT:-[^}]+\}|\1,format=${BS_FMT}|g" Launch.sh || true
sed -i -E "s|(file=/home/arch/OSX-KVM/BaseSystem.img),format=[a-z0-9]+|\1,format=${BS_FMT}|g" Launch.sh || true
# Also export so any remaining expansion is correct
export BASESYSTEM_FORMAT="$BS_FMT"

# Free port 5900 for QEMU -vnc
sed -i 's|hostfwd=tcp::${SCREEN_SHARE_PORT:-5900}-:5900,||g' Launch.sh || true
sed -i 's|hostfwd=tcp::\${SCREEN_SHARE_PORT:-5900}-:5900,||g' Launch.sh || true

if [[ "${NOPICKER:-false}" == "true" ]] || [[ "${USE_NOPICKER:-0}" == "1" ]]; then
  sed -i 's|OpenCore/OpenCore.qcow2|OpenCore/OpenCore-nopicker.qcow2|g' Launch.sh || true
fi

echo "Launch.sh patches applied (from Launch.sh.orig)."
echo "Verify critical lines:"
grep -nE 'usb-kbd|monitor telnet|vnc |MacHDD|InstallMedia|OpenCore|BaseSystem' Launch.sh | head -40 || true
echo "NOTE: guest disk0=InstallMedia/BaseSystem (never format); disk1=MacHDD (install only)"
