#!/usr/bin/env bash
# Fast, fit-to-screen VNC for forge-vm macOS.
# Fixes: broken RFB proxy, full-colour 1080p lag, wrong window size.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN="$ROOT/docker/run-forge-vm.sh"
PORT="${FORGE_VNC_PORT:-5901}"
HOST="${FORGE_VNC_HOST:-127.0.0.1}"

# Ensure RFB proxy is healthy (not the old docker-exec-nc path)
"$RUN" vnc-host

# Probe RFB
if ! timeout 2 bash -c "printf '' | nc -w 1 ${HOST} ${PORT}" 2>/dev/null | head -c 3 | grep -q RFB; then
  echo "ERROR: ${HOST}:${PORT} is not an RFB server. Fix proxy first."
  exit 1
fi

# TigerVNC options (fast + scale-to-window)
# QualityLevel 0–9 (lower = faster). CompressLevel 0–9 (higher = smaller).
# FullScreen scales guest framebuffer to your monitor.
TIGHT_OPTS=(
  -QualityLevel="${VNC_QUALITY:-2}"
  -CompressLevel="${VNC_COMPRESS:-6}"
  -PreferredEncoding=Tight
  -FullColour=0
  -AutoSelect=0
)

# Prefer tigervncviewer / vncviewer
VIEWER=""
for c in vncviewer tigervncviewer xtigervncviewer; do
  if command -v "$c" >/dev/null 2>&1; then
    VIEWER="$c"
    break
  fi
done
if [[ -z "$VIEWER" ]]; then
  echo "Install TigerVNC: sudo apt install tigervnc-viewer"
  exit 1
fi

MODE="${1:-fit}"  # fit | full | window
case "$MODE" in
  full|fullscreen)
    echo "Launching FULLSCREEN (scaled to your display)…"
    exec "$VIEWER" "${TIGHT_OPTS[@]}" -FullScreen "${HOST}::${PORT}"
    ;;
  raw|noscale)
    echo "Launching 1:1 pixels (may be huge / laggy)…"
    exec "$VIEWER" "${TIGHT_OPTS[@]}" "${HOST}::${PORT}"
    ;;
  fit|*)
    # Windowed: user can resize; TigerVNC scales when "Scale to window" is on.
    # Geometry starts at a sane size for laptop screens.
    GEOM="${VNC_GEOMETRY:-1440x810}"
    echo "Launching FIT window ${GEOM} (Tight/low-quality = snappier)."
    echo "In viewer: F8 → Options → Scaling → Scale to window (if available)."
    echo "Or: $0 full   for fullscreen fit."
    if "$VIEWER" -help 2>&1 | grep -qi geometry; then
      exec "$VIEWER" "${TIGHT_OPTS[@]}" -geometry "$GEOM" "${HOST}::${PORT}"
    else
      exec "$VIEWER" "${TIGHT_OPTS[@]}" "${HOST}::${PORT}"
    fi
    ;;
esac
