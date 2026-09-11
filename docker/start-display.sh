#!/bin/bash
# start-display.sh — Weston + XWayland inside macos-forge container
#
# Backends (env WESTON_BACKEND):
#   headless  — --backend=headless-backend.so  (default, invisible)
#   intel     — --backend=drm-backend.so       (Intel iGPU only)
#
# NEVER use NVIDIA DRI (training GPU). On this host:
#   Intel:  /dev/dri/card2 + renderD129
#   NVIDIA: /dev/dri/card1 + renderD128  ← do not pass into container
#
# Usage: docker exec -u root forge-vm /usr/local/bin/start-display.sh

set -euo pipefail

BACKEND="${WESTON_BACKEND:-headless}"
WIDTH="${WESTON_WIDTH:-1920}"
HEIGHT="${WESTON_HEIGHT:-1080}"

echo "Starting Weston display (backend=${BACKEND})..."

pkill -9 weston 2>/dev/null || true
sleep 1

rm -rf /tmp/wayland-0 /tmp/wayland-1 /tmp/.X11-unix /tmp/.X0-lock 2>/dev/null || true
rm -f /tmp/weston-run/wayland-*.lock 2>/dev/null || true

mkdir -p /tmp/weston-run /tmp/.X11-unix
chmod 0700 /tmp/weston-run
chmod 777 /tmp/.X11-unix

export XDG_RUNTIME_DIR=/tmp/weston-run
export HOME="${HOME:-/root}"

eval $(dbus-launch --sh-syntax) 2>/dev/null || true

case "$BACKEND" in
  headless)
    /usr/bin/weston \
      --backend=headless-backend.so \
      --width="${WIDTH}" --height="${HEIGHT}" \
      --xwayland \
      --log=/tmp/weston.log &
    ;;
  intel)
    # Prefer Intel card if present; refuse if only NVIDIA visible
    if [[ -e /dev/dri/card2 ]]; then
      export WLR_DRM_DEVICES=/dev/dri/card2
    elif [[ -e /dev/dri/card0 ]]; then
      # single-card systems
      export WLR_DRM_DEVICES=/dev/dri/card0
    fi
    # Guard: if card1 is the only card and looks like NVIDIA path alone, fail soft
    if [[ ! -e /dev/dri/card2 && -e /dev/dri/card1 ]] && \
       [[ -f /sys/class/drm/card1/device/vendor ]] && \
       [[ "$(cat /sys/class/drm/card1/device/vendor 2>/dev/null)" == "0x10de" ]]; then
      echo "ERROR: only NVIDIA DRI visible — refuse intel backend (training GPU)."
      echo "Pass --device /dev/dri/card2 --device /dev/dri/renderD129 and retry,"
      echo "or use WESTON_BACKEND=headless."
      exit 1
    fi
    /usr/bin/weston \
      --backend=drm-backend.so \
      --xwayland \
      --log=/tmp/weston.log &
    ;;
  *)
    echo "ERROR: WESTON_BACKEND must be headless or intel (got: $BACKEND)"
    exit 1
    ;;
esac

sleep 5

if [[ -e /tmp/.X11-unix/X0 ]]; then
  echo "WESTON READY — DISPLAY=:0 backend=${BACKEND} (${WIDTH}x${HEIGHT})"
else
  echo "WESTON FAILED — log:"
  tail -40 /tmp/weston.log 2>/dev/null || cat /tmp/weston.log 2>/dev/null || true
  exit 1
fi
