#!/bin/bash
# install-macos-disk1.sh — erase large MacHDD only + startosinstall (Sonoma OR Tahoe)
set -euo pipefail
export DISPLAY="${DISPLAY:-:0}"
DUMP_DIR="${DUMP_DIR:-/tmp/forge-install}"
MIN_TARGET_GB="${MIN_TARGET_GB:-50}"
mkdir -p "$DUMP_DIR"

qmon() {
  python3 - <<PY
import socket, time
cmd = ${1@Q}
s = socket.socket(); s.settimeout(3)
s.connect(("127.0.0.1", 4444))
time.sleep(0.25)
try:
    s.recv(8192)
except Exception:
    pass
s.sendall((cmd + "\n").encode())
time.sleep(0.4)
try:
    print(s.recv(4096).decode(errors="replace")[:200])
except Exception:
    pass
s.close()
PY
}

screendump() {
  local name="$1"
  qmon "screendump ${DUMP_DIR}/${name}.ppm" >/dev/null || true
  if command -v convert >/dev/null 2>&1 && [[ -f "${DUMP_DIR}/${name}.ppm" ]]; then
    convert "${DUMP_DIR}/${name}.ppm" "${DUMP_DIR}/${name}.png" 2>/dev/null || true
  fi
  python3 -c "from PIL import Image; Image.open('${DUMP_DIR}/${name}.ppm').save('${DUMP_DIR}/${name}.png')" 2>/dev/null || true
  ls -lah "${DUMP_DIR}/${name}".* 2>/dev/null || true
}

echo "=== install-macos: MacHDD only (size≥${MIN_TARGET_GB}G) — never BaseSystem ==="
screendump "00_before"

if [[ "${OPEN_TERMINAL:-1}" == "1" ]]; then
  echo "Opening Terminal via Utilities typeahead..."
  qmon "sendkey ctrl-f2" >/dev/null || true
  sleep 0.6
  for _ in 1 2 3 4; do qmon "sendkey right" >/dev/null || true; sleep 0.25; done
  qmon "sendkey down" >/dev/null || true
  sleep 0.3
  for ch in t e r m i n a l; do
    qmon "sendkey $ch" >/dev/null || true
    sleep 0.2
  done
  qmon "sendkey ret" >/dev/null || true
  sleep 5
  screendump "01_terminal"
fi

run_guest() {
  local cmd="$1"
  echo "GUEST> $cmd"
  python3 /usr/local/bin/qemu_typer.py "$cmd"
  sleep "${2:-3}"
}

run_guest "diskutil list" 10
screendump "02_diskutil_list"

if [[ -z "${TARGET_DISK:-}" ]]; then
  run_guest 'TARGET=""; for d in /dev/disk0 /dev/disk1 /dev/disk2 /dev/disk3; do [ -e "$d" ] || continue; info=$(diskutil info "$d" 2>/dev/null); bytes=$(echo "$info" | awk -F"[()]" "/Disk Size/ {print \$2}" | tr -dc "0-9"); echo "CAND $d bytes=$bytes"; if [ -n "$bytes" ] && [ "$bytes" -gt 50000000000 ]; then TARGET=$d; fi; done; if [ -z "$TARGET" ]; then echo "ERROR: no disk >= 50G"; exit 1; fi; echo "ERASING MacHDD $TARGET"; diskutil eraseDisk APFS MacintoshHD GPT "$TARGET"' 45
else
  run_guest "diskutil eraseDisk APFS MacintoshHD GPT ${TARGET_DISK}" 45
fi
screendump "03_erase_machdd"

run_guest "ls /Volumes" 5
screendump "04_volumes"
run_guest "diskutil info /Volumes/MacintoshHD" 8
screendump "05_volume_info"

# Detect installer app (Tahoe / Sequoia / Sonoma / Ventura)
run_guest 'APP=""; for c in "/Install macOS Tahoe.app" "/Install macOS Sequoia.app" "/Install macOS Sonoma.app" "/Install macOS Ventura.app" "/Install macOS"*.app; do [ -d "$c" ] && APP="$c" && break; done; if [ -z "$APP" ]; then ls /; ls /Volumes; ls /System/Volumes 2>/dev/null; find / -maxdepth 3 -name "startosinstall" 2>/dev/null; echo "ERROR no installer app"; exit 1; fi; echo "INSTALLER=$APP"; "$APP/Contents/Resources/startosinstall" --agreetolicense --volume /Volumes/MacintoshHD' 20
screendump "06_startosinstall_launched"

echo "=== startosinstall launched → /Volumes/MacintoshHD ==="
echo "Monitor: du -h /data/mac_hdd_ng.raw"
