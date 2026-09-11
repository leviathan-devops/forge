#!/usr/bin/env bash
# Mechanical waiter: 1 QEMU + phase by PNG size + SSH. Do NOT Enter on SSV.
set -euo pipefail
MAX_H="${1:-6}"
INTERVAL="${INTERVAL:-60}"
SCRATCH="${SCRATCH:-/tmp/grok-goal-499335baf2a8/implementer}"
PROJ="${PROJ:-/home/leviathan/OPENCODE_WORKSPACE/FORGE}"
LOG="${PROJ}/tmp/wait-ssh.log"
PROOF="${PROJ}/tmp/evidence/ssh-50922.txt"
STATUS="${PROJ}/tmp/VM_GOAL_STATUS.md"
EVDIR="${PROJ}/tmp/evidence"
mkdir -p "$SCRATCH" "$EVDIR"
end=$(( $(date +%s) + MAX_H*3600 ))
prev_hash=""
prev_phase=""
echo "[$(date -u -Iseconds)] START wait max=${MAX_H}h interval=${INTERVAL}s" | tee -a "$LOG"

while [ "$(date +%s)" -lt "$end" ]; do
  n=$(ps -eo cmd | awk "/qemu-system-x86_64/ && !/awk/" | wc -l); n=${n// /}
  if [ "$n" -eq 0 ]; then echo "[$(date -u -Iseconds)] QEMU_DEAD" | tee -a "$LOG"; exit 2; fi
  if [ "$n" -gt 1 ]; then echo "[$(date -u -Iseconds)] ERROR multi_qemu=$n" | tee -a "$LOG"; exit 3; fi
  cpu=$(ps -o pcpu= -C qemu-system-x86_64 2>/dev/null | head -1 | tr -d ' ' || echo 0)
  docker exec forge-vm bash -c '
    echo "screendump /tmp/w.ppm" | socat -t 2 - TCP:127.0.0.1:4444 >/dev/null 2>&1
    sleep 1
    convert /tmp/w.ppm /tmp/w.png 2>/dev/null || magick /tmp/w.ppm /tmp/w.png 2>/dev/null || true
  ' 2>/dev/null || true
  h=$(docker exec forge-vm md5sum /tmp/w.png 2>/dev/null | awk '{print $1}' || echo none)
  psz=$(docker exec forge-vm stat -c%s /tmp/w.ppm 2>/dev/null || echo 0)
  gsz=$(docker exec forge-vm stat -c%s /tmp/w.png 2>/dev/null || echo 0)
  chg="same"; [ "$h" != "$prev_hash" ] && [ -n "$prev_hash" ] && chg="CHANGED"; prev_hash="$h"
  # Phase by PNG size (not PPM — full FB is always ~6MB)
  # black/transition <8k; ssv ~12-25k; opencore picker ~50-90k; desktop often >90k
  phase="unknown"
  if [ "${gsz:-0}" -lt 8000 ]; then phase="black"
  elif [ "${gsz:-0}" -lt 35000 ]; then phase="ssv"
  elif [ "${gsz:-0}" -lt 100000 ]; then phase="opencore"
  else phase="gui"
  fi
  if [ "$phase" = "opencore" ]; then
    echo "[$(date -u +%H:%M:%SZ)] OPENCORE sendkey ret (png=$gsz)" | tee -a "$LOG"
    docker exec forge-vm bash -c 'echo "sendkey ret" | socat -t 2 - TCP:127.0.0.1:4444 >/dev/null 2>&1' 2>/dev/null || true
  fi
  # Save evidence on phase change to gui
  if [ "$phase" = "gui" ] && [ "$prev_phase" != "gui" ]; then
    docker cp forge-vm:/tmp/w.png "$EVDIR/desktop_$(date -u +%Y%m%dT%H%M%SZ).png" 2>/dev/null || true
    echo "[$(date -u -Iseconds)] DESKTOP_OR_SETUP evidence saved" | tee -a "$LOG"
  fi
  prev_phase="$phase"
  out=$(ssh -o BatchMode=yes -o ConnectTimeout=4 -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null -p 50922 user@127.0.0.1 hostname 2>&1 || true)
  line="[$(date -u +%H:%M:%SZ)] n=$n cpu=$cpu png=$gsz phase=$phase screen=$chg ssh=$(echo "$out" | tr '\n' ' ' | cut -c1-80)"
  echo "$line" | tee -a "$LOG"
  echo "- $line" >> "$STATUS"
  if echo "$out" | head -1 | grep -qE '^[A-Za-z0-9][A-Za-z0-9._-]{0,62}$' \
     && ! echo "$out" | grep -qiE 'timed out|refused|Connection|Permission|error|Warning'; then
    echo "$out" | tee "$PROOF" | tee "$SCRATCH/ssh-50922.txt"
    echo "[$(date -u -Iseconds)] SSH_OK" | tee -a "$LOG"
    exit 0
  fi
  sleep "$INTERVAL"
done
echo "[$(date -u -Iseconds)] TIMEOUT" | tee -a "$LOG"
exit 1
