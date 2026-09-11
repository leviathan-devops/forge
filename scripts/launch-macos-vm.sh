#!/usr/bin/env bash
# One-shot: reattach forge-vm + Tahoe boot + print access lines.
# Usage: ./scripts/launch-macos-vm.sh [--vnc] [--ssh-only]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN="$ROOT/docker/run-forge-vm.sh"
WANT_VNC=0
SSH_ONLY=0
for a in "$@"; do
  case "$a" in
    --vnc) WANT_VNC=1 ;;
    --ssh-only) SSH_ONLY=1 ;;
  esac
done

if [[ "$SSH_ONLY" -eq 1 ]]; then
  exec "$RUN" ssh
fi

"$RUN" up
if [[ "$WANT_VNC" -eq 1 ]]; then
  "$RUN" vnc-host || true
fi

cat <<EOF

════════════════════════════════════════
 FORGE macOS VM ready (Tahoe 26.x contract)
════════════════════════════════════════
 SSH:   ssh -p 50922 user@127.0.0.1
 Pass:  alpine
 Guest: macOS Tahoe ≥26.2 (primary) · start-tahoe
 VNC:   $RUN vnc-host && vncviewer 127.0.0.1:5901
 Docs:  $ROOT/docs/MACOS_VM_ACCESS.md
 Status:$RUN status
════════════════════════════════════════
EOF
