#!/usr/bin/env bash
# Host-side driver for Wave 3 SSV + SSH gate.
# Copies ssv_ssh_gate.py into forge-vm, runs long wait, pulls evidence to project tmp/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="${ROOT}/tmp"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVID="${TMP}/ssv_ssh_${STAMP}"
CONTAINER="${FORGE_VM_CONTAINER:-forge-vm}"
INTERVAL="${SSV_POLL_INTERVAL:-120}"
MAX_HOURS="${SSV_MAX_HOURS:-3.5}"

mkdir -p "$EVID" "$TMP"
LOG="$EVID/host_driver.log"

log() { echo "[$(date -u +%H:%M:%S)Z] $*" | tee -a "$LOG"; }

log "START run-ssv-ssh-gate container=$CONTAINER evid=$EVID"

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  log "FATAL: container $CONTAINER not running"
  exit 2
fi

if ! docker exec "$CONTAINER" pgrep -x qemu-system-x86 >/dev/null; then
  log "FATAL: QEMU not running inside $CONTAINER"
  exit 2
fi

# Copy automation + typer into guest
docker cp "$ROOT/docker/ssv_ssh_gate.py" "$CONTAINER:/tmp/ssv_ssh_gate.py"
docker cp "$ROOT/docker/qemu_typer.py" "$CONTAINER:/tmp/qemu_typer.py" 2>/dev/null || true

# Guest sees SSH on 10022 (QEMU hostfwd); host maps 50922->10022
# Also probe from host in parallel every cycle via side channel file.

# Ensure PIL in container (usually present via pillow/mesa stack — try install soft)
docker exec -u root "$CONTAINER" bash -c '
  python3 -c "from PIL import Image" 2>/dev/null || pip3 install --quiet pillow 2>/dev/null || true
  mkdir -p /tmp/ssv_ssh
'

# Host-side SSH prover (port 50922) in background
HOST_PROBE_LOG="$EVID/host_ssh_probe.log"
(
  while true; do
    ts=$(date -u +%Y%m%dT%H%M%SZ)
    for u in user alpine admin; do
      out=$(timeout 20 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=8 -o BatchMode=yes -p 50922 "${u}@127.0.0.1" hostname 2>&1) || true
      if [[ -n "${out}" ]] && ! echo "$out" | grep -qiE 'connection closed|permission denied|refused|timed out|Connection reset'; then
        if echo "$out" | grep -vqE 'Warning:|Permanently'; then
          {
            echo "# SSH proof (host) $ts"
            echo "command: ssh -p 50922 ${u}@127.0.0.1 hostname"
            echo "stdout:"
            echo "$out"
          } | tee "$EVID/ssh_hostname_transcript.txt" | tee -a "$HOST_PROBE_LOG"
          # marker for guest loop
          echo ok > "$EVID/SSH_OK"
          exit 0
        fi
      fi
      # password path
      if command -v sshpass >/dev/null 2>&1; then
        out=$(timeout 25 sshpass -p alpine ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          -o ConnectTimeout=8 -p 50922 "${u}@127.0.0.1" hostname 2>&1) || true
        if [[ $? -eq 0 && -n "$out" ]] && ! echo "$out" | grep -qiE 'Permission denied|Connection closed|refused'; then
          {
            echo "# SSH proof (host+sshpass) $ts"
            echo "command: sshpass -p '***' ssh -p 50922 ${u}@127.0.0.1 hostname"
            echo "stdout:"
            echo "$out"
          } | tee "$EVID/ssh_hostname_transcript.txt" | tee -a "$HOST_PROBE_LOG"
          echo ok > "$EVID/SSH_OK"
          exit 0
        fi
      fi
      echo "$ts user=$u detail=$(echo "$out" | tr '\n' ' ' | head -c 200)" >> "$HOST_PROBE_LOG"
    done
    # also pull latest guest dump
    docker exec "$CONTAINER" bash -c 'ls -1t /tmp/ssv_ssh/poll_*.png 2>/dev/null | head -1' | while read -r gpng; do
      [[ -n "$gpng" ]] || continue
      bn=$(basename "$gpng")
      docker cp "$CONTAINER:$gpng" "$EVID/$bn" 2>/dev/null || true
    done
    docker exec "$CONTAINER" bash -c 'stat -c "%s" /data/mac_hdd_ng.img 2>/dev/null; date -u' >> "$EVID/hdd_growth.log" 2>/dev/null || true
    if [[ -f "$EVID/SSH_OK" ]]; then exit 0; fi
    sleep "$INTERVAL"
  done
) &
PROBE_PID=$!
log "host SSH probe pid=$PROBE_PID log=$HOST_PROBE_LOG"

# Run guest gate (SSH port 10022 inside container network namespace → guest :22)
set +e
docker exec -u root -e SSH_PROBE_HOST=127.0.0.1 -e SSH_PROBE_PORT=10022 \
  -e MACOS_USER=user -e MACOS_PASS=alpine \
  "$CONTAINER" python3 /tmp/ssv_ssh_gate.py \
  --work /tmp/ssv_ssh \
  --interval "$INTERVAL" \
  --max-hours "$MAX_HOURS" \
  --ssh-host 127.0.0.1 \
  --ssh-port 10022 \
  2>&1 | tee -a "$EVID/guest_gate.log"
GUEST_RC=${PIPESTATUS[0]}
set -e

log "guest gate exit=$GUEST_RC"

# Pull all evidence
docker cp "$CONTAINER:/tmp/ssv_ssh/." "$EVID/" 2>/dev/null || true
docker exec "$CONTAINER" bash -c 'echo "screendump /tmp/ssv_final.ppm" | socat -t 2 - TCP:127.0.0.1:4444; sleep 1; convert /tmp/ssv_final.ppm /tmp/ssv_final.png 2>/dev/null || true'
docker cp "$CONTAINER:/tmp/ssv_final.png" "$EVID/ssv_final.png" 2>/dev/null || true

# Stop host probe if still running
if kill -0 "$PROBE_PID" 2>/dev/null; then
  # give one last probe cycle
  sleep 2
  kill "$PROBE_PID" 2>/dev/null || true
  wait "$PROBE_PID" 2>/dev/null || true
fi

# Final host SSH attempt → transcript
FINAL_TX="$TMP/ssh_hostname_transcript.txt"
set +e
for u in user alpine admin; do
  out=$(timeout 20 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=10 -o BatchMode=yes -p 50922 "${u}@127.0.0.1" hostname 2>&1)
  rc=$?
  echo "=== try $u batch rc=$rc ===" | tee -a "$EVID/final_ssh_attempts.log"
  echo "$out" | tee -a "$EVID/final_ssh_attempts.log"
  if [[ $rc -eq 0 && -n "$out" ]]; then
    {
      echo "# SSH proof $(date -u +%Y%m%dT%H%M%SZ)"
      echo "command: ssh -p 50922 ${u}@127.0.0.1 hostname"
      echo "exit: 0"
      echo "stdout: $out"
    } | tee "$FINAL_TX" | tee "$EVID/ssh_hostname_transcript.txt"
    log "SUCCESS SSH hostname=$out"
    ln -sfn "ssv_ssh_${STAMP}" "$TMP/ssv_ssh_latest" 2>/dev/null || true
    exit 0
  fi
  if command -v sshpass >/dev/null 2>&1; then
    out=$(timeout 25 sshpass -p alpine ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=10 -p 50922 "${u}@127.0.0.1" hostname 2>&1)
    rc=$?
    echo "=== try $u sshpass rc=$rc ===" | tee -a "$EVID/final_ssh_attempts.log"
    echo "$out" | tee -a "$EVID/final_ssh_attempts.log"
    if [[ $rc -eq 0 && -n "$out" ]]; then
      {
        echo "# SSH proof $(date -u +%Y%m%dT%H%M%SZ)"
        echo "command: sshpass -p '***' ssh -p 50922 ${u}@127.0.0.1 hostname"
        echo "exit: 0"
        echo "stdout: $out"
      } | tee "$FINAL_TX" | tee "$EVID/ssh_hostname_transcript.txt"
      log "SUCCESS SSH (sshpass) hostname=$out"
      ln -sfn "ssv_ssh_${STAMP}" "$TMP/ssv_ssh_latest" 2>/dev/null || true
      exit 0
    fi
  fi
done
set -e

log "FAIL: no SSH proof after gate (guest_rc=$GUEST_RC)"
ln -sfn "ssv_ssh_${STAMP}" "$TMP/ssv_ssh_latest" 2>/dev/null || true
# still copy latest screen
cp -f "$EVID"/poll_*.png "$TMP/" 2>/dev/null || true
cp -f "$EVID/ssv_final.png" "$TMP/ssv_final.png" 2>/dev/null || true
exit 1
