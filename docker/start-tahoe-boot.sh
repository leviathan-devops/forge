#!/bin/bash
# start-tahoe-boot.sh — Haswell-noTSX + SHORTNAME=tahoe boot contract
# INSTALL_MEDIA=1 → keep BaseSystem InstallMedia (fresh install)
# default → post-install boot (MacHDD only)
set -euo pipefail
export DISPLAY="${DISPLAY:-:0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/weston-run}"
export HOME="${HOME:-/home/arch}"
# product_vm_sim default: 6G guest (-m 6000) for CoreSimulator free-RAM headroom.
# Agent-light override (no sim): FORGE_GUEST_RAM=4 FORGE_GUEST_SMP=4
# Heavy GUI: FORGE_GUEST_SMP=8 FORGE_NEED_DISPLAY=1
export RAM="${FORGE_GUEST_RAM:-6}"
export SMP="${FORGE_GUEST_SMP:-4}"
export CORES="${FORGE_GUEST_CORES:-4}"
export BASESYSTEM_FORMAT=raw
export SHORTNAME=tahoe
# FORCE Docker-OSX Tahoe contract (never inherit Penryn from image ENV)
export CPU=Haswell-noTSX
export CPUID_FLAGS='kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on'
export GENERATE_UNIQUE=true
export MASTER_PLIST_URL='https://raw.githubusercontent.com/sickcodes/osx-serial-generator/master/config-custom-sonoma.plist'

if [ -f /data/tahoe-serial.env ]; then
  # shellcheck disable=SC1091
  source /data/tahoe-serial.env
fi
# re-force after source
export CPU=Haswell-noTSX
export CPUID_FLAGS='kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on'
export BOOTDISK="${BOOTDISK:-/home/arch/OSX-KVM/OpenCore/OpenCore.qcow2}"
export IMAGE_PATH=/home/arch/OSX-KVM/mac_hdd_ng.img
export NETWORKING=vmxnet3
INSTALL_MEDIA="${INSTALL_MEDIA:-0}"

# Weston/virtual display is optional. Agent SSH path does not need it (saves CPU).
# Set FORGE_NEED_DISPLAY=1 for VNC/GUI sessions only.
if [[ "${FORGE_NEED_DISPLAY:-0}" == "1" ]]; then
  if [ ! -e /tmp/.X11-unix/X0 ]; then
    /usr/local/bin/start-display.sh || true
  fi
fi

cd /home/arch/OSX-KVM
# MacHDD
if [ -f /data/mac_hdd_ng.raw ]; then
  ln -sfn /data/mac_hdd_ng.raw mac_hdd_ng.img
elif [ -f /data/mac_hdd_ng.img ]; then
  ln -sfn /data/mac_hdd_ng.img mac_hdd_ng.img
fi
# BaseSystem
if [ -f /data/BaseSystem.img ]; then
  ln -sfn /data/BaseSystem.img BaseSystem.img
fi
# OpenCore: prefer the NOPICKER variant when present (2026-08-11 —
# DISPLAY-RECOVERY: the interactive picker waits forever when the framebuffer
# is dead; the nopicker auto-boots the default entry with zero interaction).
if [ -f /data/OpenCore/OpenCore-nopicker.qcow2 ]; then
  cp -a /data/OpenCore/OpenCore-nopicker.qcow2 /home/arch/OSX-KVM/OpenCore/OpenCore-nopicker.qcow2
  cp -a /data/OpenCore/OpenCore-nopicker.qcow2 /home/arch/OSX-KVM/OpenCore/OpenCore.qcow2
  export BOOTDISK=/home/arch/OSX-KVM/OpenCore/OpenCore-nopicker.qcow2
  echo "OpenCore: NOPICKER (auto-boot)"
elif [ -f /data/OpenCore/OpenCore-tahoe.qcow2 ]; then
  cp -a /data/OpenCore/OpenCore-tahoe.qcow2 /home/arch/OSX-KVM/OpenCore/OpenCore-tahoe.qcow2
  cp -a /data/OpenCore/OpenCore-tahoe.qcow2 /home/arch/OSX-KVM/OpenCore/OpenCore.qcow2
  export BOOTDISK=/home/arch/OSX-KVM/OpenCore/OpenCore-tahoe.qcow2
  echo "OpenCore: TAHOE (picker)"
elif [ -f /data/OpenCore/OpenCore-sonoma.qcow2 ]; then
  # interim: sonoma OC often used for sequoia/tahoe in upstream until dedicated image generated
  cp -a /data/OpenCore/OpenCore-sonoma.qcow2 /home/arch/OSX-KVM/OpenCore/OpenCore.qcow2
  export BOOTDISK=/home/arch/OSX-KVM/OpenCore/OpenCore.qcow2
fi
[ -f "$BOOTDISK" ] || [ -f /home/arch/OSX-KVM/OpenCore/OpenCore.qcow2 ] || {
  echo missing OpenCore bootdisk
  ls -la /home/arch/OSX-KVM/OpenCore/ /data/OpenCore/ 2>/dev/null || true
  exit 1
}

killall -9 qemu-system-x86_64 2>/dev/null || true
sleep 2

cp -a Launch.sh.orig Launch.sh
/usr/local/bin/apply-launch-patches.sh
# DISPLAY-RECOVERY (2026-08-11): the guest's UEFI NVRAM (OVMF vars) can be
# corrupted by SIGKILLs during container restarts (qemu writes it live) —
# the symptom is a black framebuffer at the QEMU level (no boot console,
# no login screen) while the guest SSH is healthy. Restore the pristine
# vars from /data every boot; the guest's OpenCore re-seeds its own
# boot-args from its config, so a NVRAM reset is safe.
cp -f /data/OVMF_VARS-1024x768.fd /home/arch/OSX-KVM/OVMF_VARS-1024x768.fd 2>/dev/null || true
echo "OVMF_VARS restored: $(sha256sum /home/arch/OSX-KVM/OVMF_VARS-1024x768.fd 2>/dev/null | cut -c1-16)"
sed -i 's|format=qcow2,cache=unsafe,aio=threads|format=raw,cache=unsafe,aio=threads|g' Launch.sh
if [ "$INSTALL_MEDIA" != "1" ]; then
  sed -i '/InstallMedia/d' Launch.sh
  echo "MODE=post-install (no InstallMedia)"
else
  echo "MODE=install (InstallMedia kept if Launch has it)"
  # ensure BaseSystem present for install
  if [ ! -e BaseSystem.img ] && [ ! -e BaseSystem.dmg ]; then
    echo FAIL_NO_BASESYSTEM
    exit 3
  fi
fi
# Bind VNC on all ifaces + lossy JPEG (lighter stream). Keep stock -vga vmware —
# vmware-svga/vgamem_mb breaks some Tahoe boots (pure black framebuffer).
sed -i 's|-vnc 127\.0\.0\.1:0|-vnc 0.0.0.0:0,lossy=on|g' Launch.sh
sed -i 's|-vnc 0\.0\.0\.0:0$|-vnc 0.0.0.0:0,lossy=on|g' Launch.sh
sed -i 's|-vnc 0\.0\.0\.0:0 \\|-vnc 0.0.0.0:0,lossy=on \\|g' Launch.sh
# DISPLAY-RECOVERY (2026-08-11): the display-0 VNC server wedged (black
# capture + dead input after the guest display sleep). Boot the VNC on
# display 1 (port 5901) — a fresh server at boot captures the surface.
sed -i 's|-vnc 0\.0\.0\.0:0,lossy=on|-vnc 0.0.0.0:1,lossy=on|g' Launch.sh || true
echo "VNC=$(grep -oE '\-vnc [^ ]+' Launch.sh | head -1)"
# Undo any prior svga experiment
sed -i 's|-device vmware-svga,vgamem_mb=[0-9]*|-vga vmware|g' Launch.sh || true
# DISPLAY-RECOVERY (2026-08-11): the vmware-vga lost its mode negotiation
# after the display sleep (guest reports NO resolution + no kext; framebuffer
# black at the qemu level). One controlled experiment: -vga std (the generic
# VGA — a DIFFERENT device path; macOS's built-in VGA console support can
# negotiate a mode where the vmware path cannot). Revert by deleting this
# sed if the experiment fails.


# Persist serial after GENERATE if produced
# Launch.sh / entry may write serial — also stash after boot attempt
echo "BOOT SHORTNAME=$SHORTNAME CPU=$CPU FLAGS=$CPUID_FLAGS BOOTDISK=$BOOTDISK INSTALL_MEDIA=$INSTALL_MEDIA RAM=${RAM}G SMP=$SMP"
bash ./Launch.sh > /tmp/qemu.log 2>&1 &
sleep 12
n=$(ps -eo cmd | awk '/qemu-system-x86_64/ && !/awk/' | wc -l)
echo "qemu_count=$n"
ps -eo pid,stat,pcpu,etime,cmd | awk '/qemu-system-x86_64/ && !/awk/'
ps -eo cmd | awk '/qemu-system-x86_64/ && !/awk/' | grep -q Haswell || {
  echo FAIL_STILL_NOT_HASWELL
  ps -eo cmd | awk '/qemu-system-x86_64/ && !/awk/'
  tail -40 /tmp/qemu.log
  exit 2
}
echo HASWELL_OK
[ "$n" = "1" ] || { echo FAIL_QEMU_COUNT; tail -50 /tmp/qemu.log; exit 1; }
# save serial env if generated in shell env file locations
if [ -n "${MAC_ADDRESS:-}" ] || [ -n "${SERIAL:-}" ]; then
  {
    echo "export MAC_ADDRESS=${MAC_ADDRESS:-}"
    echo "export SERIAL=${SERIAL:-}"
    echo "export BOARD_SERIAL=${BOARD_SERIAL:-}"
    echo "export UUID=${UUID:-}"
  } > /data/tahoe-serial.env 2>/dev/null || true
fi
# copy OpenCore as tahoe-named if we regenerated
if [ -f /home/arch/OSX-KVM/OpenCore/OpenCore.qcow2 ]; then
  cp -a /home/arch/OSX-KVM/OpenCore/OpenCore.qcow2 /data/OpenCore/OpenCore-tahoe.qcow2 2>/dev/null || true
fi
ss -lntp 2>/dev/null | grep -E ':5900' || netstat -lntp 2>/dev/null | grep 5900 || true
echo TAHOE_BOOT_OK
