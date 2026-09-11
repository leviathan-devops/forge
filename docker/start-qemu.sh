#!/bin/bash
# start-qemu.sh — thin wrapper around stock Launch.sh (NOT a hand-rolled QEMU rewrite)
#
# Previous agents broke installs by hardcoding -m 8000 / -smp 4 and wrong OVMF.
# Canonical path: env RAM/SMP/CORES + patched Launch.sh from apply-launch-patches.sh
#
# Usage:
#   docker exec -u root forge-vm /usr/local/bin/start-qemu.sh
#   DROP_INSTALL_MEDIA=1 docker exec ...  # after install: MacHDD-only boot
#   FORCE_RESTORE_BASESYSTEM=1 ...         # via persist-disks (QEMU must be stopped first)
#
# Install target rule (F-B1 / Gate B2):
#   Guest disk *indices* vary. Erase ONLY the physical disk ≥50G (MacHDD).
#   NEVER erase BaseSystem (~3G) or OpenCore (<1G). Size beats index.

set -euo pipefail

qemu_live_pids() {
  # PIDs of non-zombie qemu-system (zombies still match plain pgrep)
  local p state
  for p in $(pgrep -x qemu-system-x86 2>/dev/null || true) $(pgrep -x qemu-system-x86_64 2>/dev/null || true); do
    state=$(awk '{print $3}' /proc/$p/stat 2>/dev/null || echo Z)
    if [[ "$state" != "Z" ]]; then
      echo "$p"
    fi
  done
}
qemu_is_live() {
  [[ -n "$(qemu_live_pids | head -1)" ]]
}


export DISPLAY="${DISPLAY:-:0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/weston-run}"
export HOME="${HOME:-/home/arch}"
export RAM="${RAM:-4}"
export SMP="${SMP:-2}"
export CORES="${CORES:-2}"
export SCREEN_SHARE_PORT="${SCREEN_SHARE_PORT:-5901}"
# Volume BaseSystem from dmg convert is often raw (not qcow2)
export BASESYSTEM_FORMAT="${BASESYSTEM_FORMAT:-raw}"

OSX_KVM=/home/arch/OSX-KVM
cd "$OSX_KVM"

if [[ ! -e /tmp/.X11-unix/X0 ]]; then
  echo "DISPLAY not ready — starting Weston first..."
  /usr/local/bin/start-display.sh
fi

# Ensure MacHDD ≫196KB stub on /data; never wipe BaseSystem (unless FORCE_RESTORE_BASESYSTEM=1)
/usr/local/bin/persist-disks.sh
# Detect real BaseSystem format on volume (raw after dmg convert)
if [[ -e "$OSX_KVM/BaseSystem.img" ]]; then
  det=$(qemu-img info "$OSX_KVM/BaseSystem.img" 2>/dev/null | sed -n 's/^file format: *//p' | head -1 || true)
  export BASESYSTEM_FORMAT="${det:-${BASESYSTEM_FORMAT:-raw}}"
  echo "BASESYSTEM_FORMAT=$BASESYSTEM_FORMAT"
fi
/usr/local/bin/apply-launch-patches.sh || true
# Hardcode InstallMedia format after patches (env expansion is flaky with ${BASESYSTEM_FORMAT:-qcow2})
if [[ -n "${BASESYSTEM_FORMAT:-}" ]]; then
  sed -i -E "s|(file=/home/arch/OSX-KVM/BaseSystem.img),format=\$\{BASESYSTEM_FORMAT:-[^}]+\}|\1,format=${BASESYSTEM_FORMAT}|g" "$OSX_KVM/Launch.sh" || true
  sed -i -E "s|(file=/home/arch/OSX-KVM/BaseSystem.img),format=[a-z0-9]+|\1,format=${BASESYSTEM_FORMAT}|g" "$OSX_KVM/Launch.sh" || true
fi

# After install: drop InstallMedia from Launch for MacHDD-only boot
if [[ "${DROP_INSTALL_MEDIA:-0}" == "1" ]]; then
  sed -i '/InstallMedia/d' Launch.sh || true
  export USE_NOPICKER=1
  /usr/local/bin/apply-launch-patches.sh || true
  sed -i '/InstallMedia/d' Launch.sh || true
fi

# Guard: refuse start with empty MacHDD (F-B1)
MAC_PATH="${IMAGE_PATH:-$OSX_KVM/mac_hdd_ng.img}"
if [[ -L "$MAC_PATH" ]]; then
  MAC_REAL=$(readlink -f "$MAC_PATH" 2>/dev/null || readlink "$MAC_PATH")
else
  MAC_REAL="$MAC_PATH"
fi
MAC_SZ=$(stat -c%s "$MAC_REAL" 2>/dev/null || echo 0)
MAC_VIRT=$(qemu-img info --output=json "$MAC_REAL" 2>/dev/null | grep -oE '"virtual-size": *[0-9]+' | grep -oE '[0-9]+' | sort -n | tail -1 || echo 0)
MIN_VIRT=$((50 * 1024 * 1024 * 1024))
if [[ "${MAC_VIRT:-0}" -lt "$MIN_VIRT" ]]; then
  echo "ERROR: MacHDD virtual-size too small (on_disk=${MAC_SZ} virt=${MAC_VIRT}) at $MAC_REAL — run persist-disks ensure"
  exit 1
fi
BS_PATH="$OSX_KVM/BaseSystem.img"
if [[ ! -e "$BS_PATH" ]] && [[ "${DROP_INSTALL_MEDIA:-0}" != "1" ]]; then
  echo "WARNING: BaseSystem.img missing — install media not available (post-install boot OK with DROP_INSTALL_MEDIA=1)"
fi

killall -9 qemu-system-x86_64 2>/dev/null || true
# reap zombies from prior Launch.sh parent if still around
sleep 2

if [[ ! -e /dev/kvm ]]; then
  echo "ERROR: /dev/kvm missing — recreate container with --device /dev/kvm --privileged"
  exit 1
fi

echo "Starting Launch.sh RAM=${RAM}G SMP=${SMP} CORES=${CORES} MacHDD on_disk=${MAC_SZ} virt=${MAC_VIRT}"
echo "  REMINDER: format/install LARGEST disk (MacHDD >=50G) only — never BaseSystem (~3G) / OpenCore (<1G)"
# nohup reaper survives docker exec exit; logs exit code if QEMU dies
: > /tmp/qemu.log
nohup bash -c 'cd /home/arch/OSX-KVM && bash ./Launch.sh >> /tmp/qemu.log 2>&1; ec=$?; echo "QEMU_EXIT:$ec $(date -u +%Y%m%dT%H%M%SZ)" >> /tmp/qemu.log' >/tmp/qemu_reaper.log 2>&1 &
disown || true
# Wait up to ~20s for monitor
for i in $(seq 1 20); do
  sleep 1
  if qemu_is_live && (echo "info status" | socat -t 1 - TCP:127.0.0.1:4444 2>/dev/null | grep -q running); then
    break
  fi
done

if qemu_is_live; then
  echo "QEMU RUNNING pid=$(qemu_live_pids | head -1)"
  echo "Monitor: telnet 127.0.0.1 4444 (socat -t 2)"
  echo "SSH host: localhost:50922 (after macOS boot + Remote Login)"
else
  echo "QEMU FAILED — /tmp/qemu.log:"
  tail -50 /tmp/qemu.log || true
  cat /tmp/qemu_reaper.log 2>/dev/null || true
  exit 1
fi
