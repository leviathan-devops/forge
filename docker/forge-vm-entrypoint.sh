#!/bin/bash
# forge-vm-entrypoint.sh — prepare master image runtime; then exec CMD
# Does NOT auto-run full macOS install (multi-hour). Operators / god-loop drive phases.

set -euo pipefail

export DISPLAY="${DISPLAY:-:0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/weston-run}"
export HOME="${HOME:-/home/arch}"
export RAM="${RAM:-4}"
export SMP="${SMP:-2}"
export CORES="${CORES:-2}"
export WESTON_BACKEND="${WESTON_BACKEND:-headless}"
export SCREEN_SHARE_PORT="${SCREEN_SHARE_PORT:-5901}"

mkdir -p /data /tmp/weston-run /tmp/.X11-unix
chmod 0700 /tmp/weston-run 2>/dev/null || true
chmod 777 /tmp/.X11-unix 2>/dev/null || true

# Persist any existing disks onto volume + symlink (safe if empty)
if [[ -x /usr/local/bin/persist-disks.sh ]]; then
  /usr/local/bin/persist-disks.sh || true
fi

# Patch Launch.sh once per container layer if stock present
if [[ -f /home/arch/OSX-KVM/Launch.sh ]] && [[ -x /usr/local/bin/apply-launch-patches.sh ]]; then
  /usr/local/bin/apply-launch-patches.sh || true
fi

echo "[forge-vm] master entrypoint ready"
echo "  WESTON_BACKEND=$WESTON_BACKEND RAM=$RAM SMP=$SMP CORES=$CORES"
echo "  /data: $(ls /data 2>/dev/null | tr '\n' ' ')"
echo "  kvm: $([[ -e /dev/kvm ]] && echo yes || echo MISSING)"
echo "  image: $(cat /opt/forge/IMAGE_VERSION 2>/dev/null || echo unknown)"
echo "  next: start-display.sh → SHORTNAME=sonoma make → Launch.sh"

exec "$@"
