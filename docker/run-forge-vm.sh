#!/bin/bash
# run-forge-vm.sh — host-side launcher + MacHDD/BaseSystem volume ops for macos-forge:master
#
# E4 ONE-COMMAND REATTACH (from project root):
#   ./docker/run-forge-vm.sh
#   → if running: no-op success; if stopped: docker start; if missing: docker run
#   Full doc: docs/E4_VM_REATTACH.md
#
# Usage:
#   ./run-forge-vm.sh                  # REATTACH / start container if missing
#   ./run-forge-vm.sh up               # reattach + sync + start-tahoe (or sonoma residual) if no QEMU
#   ./run-forge-vm.sh start-tahoe      # Haswell-noTSX + SHORTNAME=tahoe (PRIMARY after migration)
#   ./run-forge-vm.sh start-tahoe-install  # tahoe boot WITH InstallMedia for fresh install
#   ./run-forge-vm.sh start-sonoma     # Haswell-noTSX + sonoma OpenCore (legacy residual)
#   ./run-forge-vm.sh ssh              # probe SSH :50922 (user/alpine)
#   ./run-forge-vm.sh vnc-host         # host VNC proxy on :5901 → guest :5900
#   ./run-forge-vm.sh status           # disks, qemu, screendump → project tmp/
#   WESTON_BACKEND=intel ./run-forge-vm.sh
#   ./run-forge-vm.sh recreate         # stop+rm+run (volume forge-vm-data preserved)
#   ./run-forge-vm.sh ensure-disks     # grow/recreate empty MacHDD stub; never wipe BaseSystem
#   ./run-forge-vm.sh restore-basesystem  # QEMU stop + dmg→img; MacHDD untouched
#   ./run-forge-vm.sh recreate-machdd  # QEMU stop + fresh MacHDD (DESTROYS guest OS)
#   ./run-forge-vm.sh start-qemu       # legacy stock path — prefer start-sonoma
#   ./run-forge-vm.sh install-disk1    # Recovery: erase disk1 only + startosinstall
#   ./run-forge-vm.sh sync-scripts     # docker cp local docker/* into running container
#
# Tahoe/Sonoma contract (NEVER Penryn): CPU=Haswell-noTSX, GENERATE_UNIQUE,
# config-custom-sonoma.plist URL, SHORTNAME=tahoe for macOS 26.x.

set -euo pipefail

IMAGE="${FORGE_IMAGE:-macos-forge:master}"
NAME="${FORGE_NAME:-forge-vm}"
BACKEND="${WESTON_BACKEND:-headless}"
# product_vm_sim defaults (guest -m 6000 needs container ≥8g). Agent-light: FORGE_MEMORY=5g FORGE_GUEST_RAM=4
# Heavy GUI: FORGE_CPUSET=0-7 FORGE_NEED_DISPLAY=1 FORGE_GUEST_SMP=8
CPUS="${FORGE_CPUSET:-0-3}"
MEM="${FORGE_MEMORY:-8g}"
# Headroom for host OOM — never set swap equal to mem only
SWAP="${FORGE_MEMORY_SWAP:-16g}"
VNC_HOST_PORT="${FORGE_VNC_PORT:-5901}"
SSH_HOST_PORT="${FORGE_SSH_PORT:-50922}"
# 0 = skip Weston (saves CPU). Set FORGE_NEED_DISPLAY=1 for VNC.
FORGE_NEED_DISPLAY="${FORGE_NEED_DISPLAY:-0}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="${FORGE_TMP:-$ROOT/tmp}"
mkdir -p "$TMP"

cmd_exec() {
  docker exec -u root "$NAME" "$@"
}

sync_scripts() {
  echo "Syncing docker scripts into $NAME:/usr/local/bin ..."
  for f in persist-disks.sh start-qemu.sh start-sonoma-boot.sh start-tahoe-boot.sh \
           apply-launch-patches.sh install-macos-disk1.sh start-display.sh forge-vm-entrypoint.sh \
           qemu_typer.py qemu_control.py open_terminal.py vnc_mouse.py wait-macos-ssh.sh; do
    if [[ -f "$ROOT/docker/$f" ]]; then
      docker cp "$ROOT/docker/$f" "$NAME:/usr/local/bin/$f"
      cmd_exec chmod +x "/usr/local/bin/$f" 2>/dev/null || true
      echo "  synced $f"
    fi
  done
}

maybe_start_display() {
  if [[ "${FORGE_NEED_DISPLAY}" == "1" ]]; then
    cmd_exec /usr/local/bin/start-display.sh || true
  else
    echo "Skipping Weston (agent mode). FORGE_NEED_DISPLAY=1 to enable."
  fi
}

do_start_sonoma() {
  sync_scripts
  maybe_start_display
  echo "Starting Sonoma boot (Haswell-noTSX forced) — residual path..."
  cmd_exec /usr/local/bin/start-sonoma-boot.sh
  sleep 2
  do_status || true
  echo ""
  echo "SSH (after guest login + Remote Login):  ssh -p ${SSH_HOST_PORT} user@127.0.0.1  # alpine"
  echo "VNC host viewer:  FORGE_NEED_DISPLAY=1 $0 vnc-host   then  vncviewer 127.0.0.1:${VNC_HOST_PORT}"
}

do_start_tahoe() {
  sync_scripts
  maybe_start_display
  echo "Starting Tahoe boot (product_vm_sim: 6G/4cpu default → -m 6000; no Weston)..."
  cmd_exec env INSTALL_MEDIA=0 FORGE_NEED_DISPLAY="${FORGE_NEED_DISPLAY}" \
    FORGE_GUEST_RAM="${FORGE_GUEST_RAM:-6}" FORGE_GUEST_SMP="${FORGE_GUEST_SMP:-4}" \
    FORGE_GUEST_CORES="${FORGE_GUEST_CORES:-4}" \
    /usr/local/bin/start-tahoe-boot.sh
  sleep 2
  do_status || true
  echo ""
  echo "SSH:  ssh -p ${SSH_HOST_PORT} user@127.0.0.1  # alpine"
  echo "VNC:  FORGE_NEED_DISPLAY=1 $0 start-tahoe && $0 vnc-host"
}

do_start_tahoe_install() {
  sync_scripts
  maybe_start_display
  echo "Starting Tahoe INSTALLER boot (InstallMedia + empty MacHDD)..."
  cmd_exec env INSTALL_MEDIA=1 FORGE_NEED_DISPLAY="${FORGE_NEED_DISPLAY}" /usr/local/bin/start-tahoe-boot.sh
  sleep 2
  do_status || true
  echo "VNC: FORGE_NEED_DISPLAY=1 $0 vnc-host && vncviewer 127.0.0.1:${VNC_HOST_PORT}"
  echo "Then: Disk Utility erase MacHDD → Install macOS, or install-macos-disk1.sh in Recovery"
}

do_ssh_probe() {
  echo "=== SSH probe host :${SSH_HOST_PORT} → guest :22 ==="
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<PY || true
import socket, sys
try:
    s = socket.create_connection(("127.0.0.1", int("${SSH_HOST_PORT}")), timeout=5)
    s.settimeout(5)
    b = s.recv(256)
    print("banner:", b.decode("utf-8", "replace").strip())
    s.close()
except Exception as e:
    print("banner_fail:", e)
    sys.exit(1)
try:
    import paramiko
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect("127.0.0.1", port=int("${SSH_HOST_PORT}"), username="user", password="alpine",
              timeout=15, allow_agent=False, look_for_keys=False, banner_timeout=20)
    _, o, e = c.exec_command("hostname; whoami; sw_vers")
    print(o.read().decode() + e.read().decode())
    c.close()
    print("SSH_OK user/alpine")
except Exception as e:
    print("SSH_AUTH_OR_PARAMIKO:", e)
    print("Manual: ssh -p ${SSH_HOST_PORT} user@127.0.0.1  # password alpine")
PY
  else
    echo "python3 missing; try: ssh -p ${SSH_HOST_PORT} user@127.0.0.1"
  fi
}

do_vnc_host() {
  # Expose container QEMU VNC on host :5901 without recreate.
  # Live RFB is QEMU -vnc :0 → 5900 or :1 → 5901 (tahoe display-recovery uses :1).
  # Never use `docker exec … nc` — the image has no nc and TigerVNC then reports
  # "reading version failed: not an RFB server".
  if ! docker ps --format '{{.Names}}' | grep -qx "$NAME"; then
    echo "Container $NAME not running"; exit 1
  fi
  mkdir -p "$TMP"
  # Stop any broken/stale host proxy on this port
  pkill -f "socat.*TCP-LISTEN:${VNC_HOST_PORT}" 2>/dev/null || true
  docker rm -f forge-vnc-proxy 2>/dev/null || true
  sleep 0.3

  CIP="$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$NAME" 2>/dev/null || true)"
  ok=0

  rfb_ok() {
    local host="$1" port="$2"
    timeout 2 bash -c "printf '' | nc -w 1 ${host} ${port}" 2>/dev/null | head -c 3 | grep -q RFB
  }

  # Discover live RFB inside the guest (prefer 5901 when QEMU is -vnc :1).
  RFB_PORT=""
  if [[ -n "$CIP" ]]; then
    for p in 5901 5900; do
      if rfb_ok "$CIP" "$p"; then
        RFB_PORT="$p"
        break
      fi
    done
  fi
  # If docker published 5901→5900 but QEMU is :1, bridge 5900 inside the
  # container so existing -p 5901:5900 still speaks RFB (no recreate/wipe).
  if [[ "$RFB_PORT" == "5901" ]] && ! rfb_ok "$CIP" 5900; then
    docker exec -d "$NAME" socat TCP-LISTEN:5900,fork,reuseaddr,bind=0.0.0.0 TCP:127.0.0.1:5901 >/dev/null 2>&1 || true
    sleep 0.3
    rfb_ok "$CIP" 5900 && echo "in-guest socat 0.0.0.0:5900 → 127.0.0.1:5901 (docker -p 5901:5900)"
  fi
  RFB_PORT="${RFB_PORT:-5901}"
  echo "RFB_LIVE=${CIP:-?}:${RFB_PORT}"

  # Host loopback can be RFB via docker-proxy while docker0 (172.17.0.1)
  # is still dead — display-forge must use 172.17.0.1, not 127.0.0.1.
  if rfb_ok 127.0.0.1 "${VNC_HOST_PORT}" && rfb_ok 172.17.0.1 "${VNC_HOST_PORT}"; then
    echo "VNC already RFB on 127.0.0.1+172.17.0.1:${VNC_HOST_PORT} (live ${CIP}:${RFB_PORT})"
    ok=1
  fi

  # 1) Sidecar sharing container netns (works if QEMU bound 127.0.0.1 only)
  if [[ "$ok" -eq 0 ]] && docker run -d --name forge-vnc-proxy --network "container:${NAME}" \
      -p "127.0.0.1:${VNC_HOST_PORT}:5901" \
      alpine/socat \
      TCP-LISTEN:5901,fork,reuseaddr "TCP:127.0.0.1:${RFB_PORT}" >/dev/null 2>&1; then
    sleep 0.5
    if rfb_ok 127.0.0.1 "${VNC_HOST_PORT}"; then
      echo "VNC proxy up: host 127.0.0.1:${VNC_HOST_PORT} → ${NAME}:127.0.0.1:${RFB_PORT} (sidecar)"
      ok=1
    else
      docker rm -f forge-vnc-proxy 2>/dev/null || true
    fi
  fi

  # 2) Host socat → container bridge IP:live RFB (QEMU 0.0.0.0:5900 or :5901)
  if [[ "$ok" -eq 0 ]] && command -v socat >/dev/null 2>&1 && [[ -n "$CIP" ]]; then
    # Bind 0.0.0.0 so host viewers AND Docker bridge containers can reach VNC
    # (127.0.0.1-only broke container virtual-display verification).
    pkill -f "socat.*TCP-LISTEN:${VNC_HOST_PORT}" 2>/dev/null || true
    sleep 0.2
    nohup socat "TCP-LISTEN:${VNC_HOST_PORT},fork,reuseaddr,bind=0.0.0.0" \
      "TCP:${CIP}:${RFB_PORT}" \
      >"$TMP/vnc-proxy.log" 2>&1 &
    sleep 0.4
    if rfb_ok 127.0.0.1 "${VNC_HOST_PORT}" || rfb_ok 172.17.0.1 "${VNC_HOST_PORT}"; then
      echo "VNC host-socat: 0.0.0.0:${VNC_HOST_PORT} → ${CIP}:${RFB_PORT} (log $TMP/vnc-proxy.log)"
      ok=1
    else
      echo "WARN: socat up but RFB probe failed — see $TMP/vnc-proxy.log"
    fi
  fi

  if [[ "$ok" -eq 0 ]]; then
    echo "Could not start RFB proxy. Install socat, ensure forge-vm QEMU is running,"
    echo "or recreate with: docker run ... -p ${VNC_HOST_PORT}:${RFB_PORT}"
    exit 1
  fi
  echo "Open:  vncviewer 127.0.0.1:${VNC_HOST_PORT}"
  echo "   or: remote-viewer vnc://127.0.0.1:${VNC_HOST_PORT}"
  echo "   or: xtightvncviewer 127.0.0.1:${VNC_HOST_PORT}"
  echo "display-forge: vncviewer 172.17.0.1::${VNC_HOST_PORT}  (not 127.0.0.1)"
  echo "No VNC password. Guest macOS login is separate (user account on the Mac desktop)."
}

do_up() {
  # Reattach container, sync scripts, boot Sonoma if no QEMU
  if ! docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
    echo "No container — creating..."
    ACTION=run
    # fall through to docker run below by not exiting — call self recreate path
    "$0" recreate
  elif ! docker ps --format '{{.Names}}' | grep -qx "$NAME"; then
    docker start "$NAME"
  else
    echo "Container $NAME already running."
  fi
  sync_scripts
  if ! docker exec "$NAME" pgrep -x qemu-system-x86 >/dev/null 2>&1; then
    # Prefer Tahoe after migration (mac_hdd_ng.sonoma14*.bak present or explicit FORGE_BOOT=tahoe)
    if docker exec "$NAME" test -f /data/mac_hdd_ng.sonoma14.raw.bak 2>/dev/null \
       || [[ "${FORGE_BOOT:-tahoe}" == "tahoe" ]]; then
      do_start_tahoe
    else
      do_start_sonoma
    fi
  else
    echo "QEMU already running:"
    docker exec "$NAME" bash -c 'ps -eo etime,cmd | awk "/qemu-system/ && !/awk/"'
  fi
  do_ssh_probe || true
  echo ""
  echo "=== ACCESS ==="
  echo "SSH:  ssh -p ${SSH_HOST_PORT} user@127.0.0.1   # password: alpine"
  echo "VNC:  $0 vnc-host && vncviewer 127.0.0.1:${VNC_HOST_PORT}"
  echo "Docs: $ROOT/docs/MACOS_VM_ACCESS.md"
}

host_screendump() {
  local tag="${1:-status}"
  cmd_exec python3 - <<'PY' || true
import socket, time, os
path = "/tmp/forge_status.ppm"
s = socket.socket(); s.settimeout(3)
s.connect(("127.0.0.1", 4444))
time.sleep(0.3)
try: s.recv(8192)
except Exception: pass
s.sendall(f"screendump {path}\n".encode())
time.sleep(0.8)
s.close()
print("ok", path, os.path.getsize(path) if os.path.exists(path) else 0)
PY
  docker cp "$NAME:/tmp/forge_status.ppm" "$TMP/${tag}.ppm" 2>/dev/null || true
  if [[ -f "$TMP/${tag}.ppm" ]] && command -v convert >/dev/null 2>&1; then
    convert "$TMP/${tag}.ppm" "$TMP/${tag}.png" 2>/dev/null || true
  fi
  ls -lah "$TMP/${tag}".* 2>/dev/null || true
}

do_status() {
  echo "=== container ==="
  docker ps -a --filter "name=^/${NAME}$" --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' || true
  echo "=== disks inside ==="
  cmd_exec bash -c '
    echo "BaseSystem.img: $(stat -c%s /data/BaseSystem.img 2>/dev/null || echo MISSING) bytes"
    echo "mac_hdd_ng.img: $(stat -c%s /data/mac_hdd_ng.img 2>/dev/null || echo MISSING) bytes"
    echo "BaseSystem.dmg: $(stat -c%s /data/BaseSystem.dmg 2>/dev/null || echo MISSING) bytes"
    ls -lah /data/BaseSystem.img /data/mac_hdd_ng.img /home/arch/OSX-KVM/BaseSystem.img /home/arch/OSX-KVM/mac_hdd_ng.img 2>/dev/null || true
    qemu-img info /data/mac_hdd_ng.img 2>/dev/null | head -12 || echo "(mac_hdd locked or missing)"
    pgrep -af qemu-system-x86_64 || echo "no qemu"
    pgrep -af weston | head -3 || echo "no weston"
  ' || true
  if docker exec "$NAME" pgrep -x qemu-system-x86 >/dev/null 2>&1; then
    host_screendump "status"
  fi
  # F-B1: growth (on_disk ≫196KB) is definitive while QEMU holds the image (virt may be unreadable).
  local mac_sz mac_virt
  mac_sz=$(cmd_exec stat -c%s /data/mac_hdd_ng.img 2>/dev/null || echo 0)
  mac_virt=$(cmd_exec bash -c 'qemu-img info --output=json /data/mac_hdd_ng.img 2>/dev/null | grep -oE "\"virtual-size\": *[0-9]+" | grep -oE "[0-9]+" | sort -n | tail -1' 2>/dev/null || echo 0)
  # Also accept file(1) virtual size when qemu-img is locked
  if [[ -z "${mac_virt}" || "${mac_virt}" -eq 0 ]]; then
    mac_virt=$(cmd_exec bash -c 'file /data/mac_hdd_ng.img 2>/dev/null | grep -oE "[0-9]{9,}" | head -1' 2>/dev/null || echo 0)
  fi
  if [[ "${mac_sz:-0}" -gt 1048576 ]]; then
    echo "F-B1 growth: CLOSED (on_disk=${mac_sz} ≫196KB virt=${mac_virt:-unknown})"
    return 0
  fi
  if [[ "${mac_virt:-0}" -ge $((50*1024*1024*1024)) ]]; then
    echo "F-B1 capacity: OK sparse pre-install (on_disk=${mac_sz} virt=${mac_virt}) — install must grow on_disk"
    return 2
  fi
  echo "F-B1-EMPTY-MACHDD: STILL OPEN (virt=${mac_virt} on_disk=${mac_sz})"
  return 1
}

do_ensure_disks() {
  sync_scripts
  cmd_exec /usr/local/bin/persist-disks.sh
  do_status
}

do_restore_basesystem() {
  sync_scripts
  echo "Stopping QEMU (if any) for BaseSystem restore..."
  cmd_exec bash -c 'killall -9 qemu-system-x86_64 2>/dev/null || true; sleep 2'
  cmd_exec bash -c 'FORCE_RESTORE_BASESYSTEM=1 /usr/local/bin/persist-disks.sh'
  echo "BaseSystem restored; MacHDD not wiped."
  do_status || true
}

do_recreate_machdd() {
  sync_scripts
  echo "WARNING: recreating MacHDD destroys any guest install on disk1"
  cmd_exec bash -c 'killall -9 qemu-system-x86_64 2>/dev/null || true; sleep 2'
  cmd_exec bash -c 'FORCE_RECREATE_MAC_HDD=1 /usr/local/bin/persist-disks.sh'
  do_status || true
}

do_start_qemu() {
  sync_scripts
  cmd_exec /usr/local/bin/start-display.sh || true
  cmd_exec /usr/local/bin/start-qemu.sh
  sleep 3
  do_status || true
}

do_install_disk1() {
  sync_scripts
  if ! docker exec "$NAME" pgrep -x qemu-system-x86 >/dev/null 2>&1; then
    echo "QEMU not running — starting with InstallMedia + MacHDD..."
    do_start_qemu
    echo "Waiting 90s for Recovery..."
    sleep 90
  fi
  host_screendump "pre_install_disk1"
  cmd_exec bash -c 'DUMP_DIR=/tmp/forge-install OPEN_TERMINAL=1 /usr/local/bin/install-macos-disk1.sh'
  # pull dumps
  mkdir -p "$TMP/install"
  docker cp "$NAME:/tmp/forge-install/." "$TMP/install/" 2>/dev/null || true
  host_screendump "post_install_launch"
  do_status || true
  echo "Install launched. Poll: $0 status  (watch mac_hdd size grow; wait SSV after reboot)"
}

# --- main ---
ACTION="${1:-}"

EXTRA_DEV=()
if [[ "$BACKEND" == "intel" ]]; then
  EXTRA_DEV+=(--device /dev/dri/card2 --device /dev/dri/renderD129)
  echo "Intel DRI passthrough enabled (NVIDIA excluded)"
fi

case "$ACTION" in
  status) do_status; exit $? ;;
  ensure-disks) do_ensure_disks; exit $? ;;
  restore-basesystem) do_restore_basesystem; exit $? ;;
  recreate-machdd) do_recreate_machdd; exit $? ;;
  start-qemu) do_start_qemu; exit $? ;;
  start-sonoma) do_start_sonoma; exit $? ;;
  start-tahoe) do_start_tahoe; exit $? ;;
  start-tahoe-install) do_start_tahoe_install; exit $? ;;
  ssh|ssh-probe) do_ssh_probe; exit $? ;;
  vnc-host|vnc) do_vnc_host; exit $? ;;
  up|attach) do_up; exit $? ;;
  install-disk1) do_install_disk1; exit $? ;;
  sync-scripts) sync_scripts; exit 0 ;;
  hygiene|cleanup|reap)
    # Clear zombies (PID1=sleep infinity never reaps) + reboot. Volume KEPT.
    # Defaults FORGE_GUEST_RAM=6 (-m 6000). Agent-light: FORGE_GUEST_RAM=4.
    echo "=== forge-vm hygiene: soft stop guest + restart container (volume intact) ==="
    python3 - <<'PY' 2>/dev/null || true
import paramiko
try:
  c=paramiko.SSHClient(); c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
  c.connect("127.0.0.1", port=int("${SSH_HOST_PORT}"), username="user", password="alpine",
            allow_agent=False, look_for_keys=False, timeout=8)
  c.exec_command("echo alpine | sudo -S shutdown -h now", timeout=5)
  c.close()
  print("guest_shutdown_sent")
except Exception as e:
  print("guest_shutdown_skip", type(e).__name__)
PY
    sleep 8
    pkill -f "socat.*TCP-LISTEN:${VNC_HOST_PORT}" 2>/dev/null || true
    docker exec -u root "$NAME" bash -c 'killall -9 qemu-system-x86_64 weston weston-keyboard weston-desktop-shell 2>/dev/null || true' || true
    sleep 2
    docker restart "$NAME"
    echo "container restarted (zombies reaped with old PID1)"
    sleep 3
    zc=$(docker exec "$NAME" bash -c 'ps aux | awk "\$8 ~ /Z/ {c++} END{print c+0}"' 2>/dev/null || echo "?")
    echo "zombies_in_container_after_restart=$zc"
    # Agent-light container caps (live update; recreate for full Mem if needed)
    docker update --memory="${MEM}" --memory-swap="${SWAP}" --cpuset-cpus="${CPUS}" --cpu-shares=1024 "$NAME" 2>/dev/null || true
    sync_scripts
    maybe_start_display
    cmd_exec env INSTALL_MEDIA=0 FORGE_NEED_DISPLAY="${FORGE_NEED_DISPLAY}" \
      FORGE_GUEST_RAM="${FORGE_GUEST_RAM:-6}" FORGE_GUEST_SMP="${FORGE_GUEST_SMP:-4}" \
      FORGE_GUEST_CORES="${FORGE_GUEST_CORES:-4}" \
      /usr/local/bin/start-tahoe-boot.sh || true
    sleep 5
    do_status || true
    echo "Wait ~2–3 min for SSH: ssh -p ${SSH_HOST_PORT} user@127.0.0.1  # alpine"
    exit 0
    ;;
  recreate)
    docker rm -f "$NAME" 2>/dev/null || true
    ;;
  ""|run|start) ;;
  *)
    echo "Unknown action: $ACTION"
    echo "Usage: $0 [up|run|recreate|status|start-tahoe|start-sonoma|ssh|vnc-host|hygiene|ensure-disks|sync-scripts|...]"
    exit 2
    ;;
esac

if docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
  if docker ps --format '{{.Names}}' | grep -qx "$NAME"; then
    echo "Container $NAME already running."
    docker inspect "$NAME" --format 'Image={{.Config.Image}} Privileged={{.HostConfig.Privileged}} Memory={{.HostConfig.Memory}} Cpuset={{.HostConfig.CpusetCpus}}'
    echo "Tip: $0 up | start-sonoma | ssh | vnc-host | status"
    exit 0
  fi
  docker start "$NAME"
  exit 0
fi

docker volume create forge-vm-data >/dev/null

docker run -d \
  --name "$NAME" \
  --runtime=runc \
  --privileged \
  --device /dev/kvm \
  "${EXTRA_DEV[@]}" \
  --cpuset-cpus="$CPUS" \
  --memory="$MEM" \
  --memory-swap="$SWAP" \
  -p "${SSH_HOST_PORT}:10022" \
  -p "${VNC_HOST_PORT}:5900" \
  -v forge-vm-data:/data \
  -e WESTON_BACKEND="$BACKEND" \
  -e RAM=4 -e SMP=4 -e CORES=4 \
  -e SHORTNAME=tahoe \
  -e CPU=Haswell-noTSX \
  -e CPUID_FLAGS='kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on' \
  -e GENERATE_UNIQUE=true \
  -e MASTER_PLIST_URL='https://raw.githubusercontent.com/sickcodes/osx-serial-generator/master/config-custom-sonoma.plist' \
  "$IMAGE"

echo "Started $NAME from $IMAGE (backend=$BACKEND cpuset=$CPUS mem=$MEM swap=$SWAP)"
echo "  $0 sync-scripts"
echo "  $0 start-tahoe-install   # fresh Tahoe install (InstallMedia)"
echo "  $0 start-tahoe           # post-install Tahoe boot (Haswell)"
echo "  $0 ssh                   # probe user@127.0.0.1:${SSH_HOST_PORT}"
echo "  $0 vnc-host"
echo "  Docs: $ROOT/docs/TAHOE_MACOS26_UPGRADE_PROCESS.md"
