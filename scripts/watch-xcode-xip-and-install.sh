#!/usr/bin/env bash
# Watch host Downloads for Xcode *.xip completion, transfer to forge-vm guest, expand, select.
# Zero theater: refuses 0-byte / still-.part files.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DL="${XCODE_DL_DIR:-/home/leviathan/Downloads}"
EV="$ROOT/tmp/evidence/xcode"
GUEST_USER=user
GUEST_PASS=alpine
GUEST_HOST=127.0.0.1
GUEST_PORT=50922
MIN_BYTES=$((8 * 1024 * 1024 * 1024))  # 8 GiB floor for full Xcode xip
STABLE_SECS="${STABLE_SECS:-45}"
mkdir -p "$EV" "$DL"

log() { echo "[$(date -u +%Y-%m-%dT%H%M%SZ)] $*"; }
find_xip() {
  # Prefer final names; ignore zero-byte placeholders next to .part
  local f
  for f in "$DL"/Xcode*.xip; do
    [[ -f "$f" ]] || continue
    local sz
    sz=$(stat -c%s "$f" 2>/dev/null || echo 0)
    if [[ "$sz" -ge "$MIN_BYTES" ]]; then
      echo "$f"
      return 0
    fi
  done
  return 1
}

wait_complete() {
  log "watching $DL for Xcode*.xip ≥8GiB stable ${STABLE_SECS}s"
  local last=0 last_path="" stable=0
  while true; do
    local part_sz=0 part_path=""
    if compgen -G "$DL"/Xcode*.xip.part >/dev/null; then
      part_path=$(ls -1t "$DL"/Xcode*.xip.part 2>/dev/null | head -1)
      part_sz=$(stat -c%s "$part_path" 2>/dev/null || echo 0)
    fi
    if xip=$(find_xip); then
      local sz
      sz=$(stat -c%s "$xip")
      if [[ "$xip" == "$last_path" && "$sz" -eq "$last" && "$sz" -ge "$MIN_BYTES" ]]; then
        stable=$((stable + 5))
        if [[ "$stable" -ge "$STABLE_SECS" ]]; then
          log "COMPLETE path=$xip size=$sz"
          echo "$xip" >"$EV/host-xip-path.txt"
          echo "size_bytes=$sz" >"$EV/host-xip-size.txt"
          date -u +%Y-%m-%dT%H:%M:%SZ >"$EV/host-xip-ready-at.txt"
          return 0
        fi
      else
        stable=0
        last=$sz
        last_path=$xip
        log "growing/final candidate $xip size=$sz stable=${stable}s"
      fi
    else
      stable=0
      log "waiting… part=${part_path:-none} part_sz=${part_sz} (need final .xip ≥${MIN_BYTES})"
    fi
    sleep 5
  done
}

ssh_py() {
  local cmd="$1"
  python3 - "$cmd" <<'PY'
import sys, paramiko
cmd = sys.argv[1]
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("127.0.0.1", port=50922, username="user", password="alpine",
          allow_agent=False, look_for_keys=False, timeout=30, banner_timeout=60)
_, o, e = c.exec_command(cmd, timeout=3600)
out = o.read().decode(errors="replace")
err = e.read().decode(errors="replace")
rc = o.channel.recv_exit_status()
sys.stdout.write(out)
sys.stderr.write(err)
c.close()
sys.exit(rc)
PY
}

transfer() {
  local xip="$1"
  local base
  base=$(basename "$xip")
  log "ensuring guest Downloads"
  ssh_py 'mkdir -p ~/Downloads && df -h / System/Volumes/Data 2>/dev/null | head -5' | tee "$EV/guest-df-before.txt" || true
  log "transfer via rsync/scp (long) → guest ~/Downloads/$base"
  # Prefer rsync with progress; fall back to scp with sshpass-less expect via python sftp
  if command -v rsync >/dev/null; then
    RSYNC_RSH="ssh -p $GUEST_PORT -o StrictHostKeyChecking=no -o PreferredAuthentications=password -o PubkeyAuthentication=no" \
      rsync -avP --inplace 2>/dev/null || true
  fi
  python3 - "$xip" "$base" <<'PY' | tee "$EV/transfer.log"
import sys, os, paramiko, time
from pathlib import Path
src, base = sys.argv[1], sys.argv[2]
size = Path(src).stat().st_size
print(f"SFTP start {src} -> ~/Downloads/{base} size={size}", flush=True)
t = paramiko.Transport(("127.0.0.1", 50922))
t.connect(username="user", password="alpine")
sftp = paramiko.SFTPClient.from_transport(t)
try:
    sftp.chdir("/Users/user/Downloads")
except IOError:
    sftp.mkdir("/Users/user/Downloads")
    sftp.chdir("/Users/user/Downloads")
remote = f"/Users/user/Downloads/{base}"
# resume if partial
try:
    st = sftp.stat(remote)
    offset = st.st_size
    print(f"resume offset={offset}", flush=True)
except IOError:
    offset = 0
mode = "ab" if offset else "wb"
with open(src, "rb") as f:
    f.seek(offset)
    with sftp.file(remote, mode) as rf:
        rf.set_pipelined(True)
        sent = offset
        chunk = 8 * 1024 * 1024
        t0 = time.time()
        while True:
            buf = f.read(chunk)
            if not buf:
                break
            rf.write(buf)
            sent += len(buf)
            if sent % (256 * 1024 * 1024) < chunk or sent == size:
                elapsed = max(time.time() - t0, 1e-6)
                rate = (sent - offset) / elapsed / (1024 * 1024)
                print(f"progress {sent}/{size} ({100*sent/size:.1f}%) {rate:.1f} MiB/s", flush=True)
print("SFTP_DONE", flush=True)
sftp.close()
t.close()
PY
}

expand_and_select() {
  local base="$1"
  log "expand xip on guest (can take 20–60+ min)"
  # run expand in background log on guest
  ssh_py "set -e; cd ~/Downloads; ls -lah '$base'; if [[ ! -d /Applications/Xcode.app ]]; then echo EXPAND_START; xip -x '$base' 2>&1 | tee ~/Downloads/xip-expand.log; echo alpine | sudo -S mv -f Xcode.app /Applications/Xcode.app; fi; echo alpine | sudo -S xcode-select -s /Applications/Xcode.app/Contents/Developer; echo alpine | sudo -S xcodebuild -license accept || true; xcodebuild -version; ls -la /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild" | tee "$EV/guest-xcode-install.txt"
}

main() {
  wait_complete
  local xip
  xip=$(cat "$EV/host-xip-path.txt")
  transfer "$xip"
  expand_and_select "$(basename "$xip")"
  log "DONE — see $EV"
}

main "$@"
