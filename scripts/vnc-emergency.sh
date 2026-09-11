#!/usr/bin/env bash
# Emergency low-FPS VNC for forge-vm when the host is under heavy load.
# Use this instead of stock TigerVNC defaults.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/docker/run-forge-vm.sh" vnc-host >/dev/null
# Prove RFB
timeout 2 bash -c 'printf "" | nc -w 1 127.0.0.1 5901' | head -c 3 | grep -q RFB \
  || { echo "VNC proxy dead — run: $ROOT/docker/run-forge-vm.sh vnc-host"; exit 1; }

echo "WARNING: Host load may still make this laggy. Prefer SSH: ssh -p 50922 user@127.0.0.1 (alpine)"
echo "Local login: user / alpine"
echo "Launching ultra-low-quality Tight VNC (fullscreen)…"

exec vncviewer \
  -QualityLevel=0 \
  -CompressLevel=9 \
  -PreferredEncoding=Tight \
  -FullColour=0 \
  -AutoSelect=0 \
  -FullScreen \
  127.0.0.1::5901
