#!/bin/bash
# persist-disks.sh — keep BaseSystem + MacHDD on Docker volume /data
# CRITICAL: never mount the volume over /home/arch/OSX-KVM (hides Docker-OSX tree).
# Layout:
#   /data/BaseSystem.img  ← volume (install media; NEVER format as install target)
#   /data/mac_hdd_ng.img  ← volume (disk1 install target only)
#   /home/arch/OSX-KVM/{BaseSystem.img,mac_hdd_ng.img} → symlinks to /data
#
# Closes F-B1-EMPTY-MACHDD: ensure MacHDD is a real sparse qcow2 (≫196KB stub),
# grow/recreate as needed WITHOUT wiping BaseSystem.

set -euo pipefail

qemu_live_pids() {
  # PIDs of non-zombie qemu-system (zombies still match plain pgrep)
  local p state
  for p in $(pgrep -x qemu-system-x86 2>/dev/null || true); do
    state=$(awk '{print $3}' /proc/$p/stat 2>/dev/null || echo Z)
    if [[ "$state" != "Z" ]]; then
      echo "$p"
    fi
  done
}
qemu_is_live() {
  [[ -n "$(qemu_live_pids | head -1)" ]]
}


OSX_KVM="${OSX_KVM:-/home/arch/OSX-KVM}"
DATA="${DATA:-/data}"
# On-disk size of a fresh sparse 256G qcow2 is ~196KB (valid pre-install).
# Use virtual-size for stub detection; MIN_MAC_HDD_BYTES only for growth reporting.
MIN_MAC_HDD_BYTES="${MIN_MAC_HDD_BYTES:-1048576}"
# Virtual size for fresh MacHDD (sparse). Sonoma needs tens of GB; 256G matches Docker-OSX default.
MAC_HDD_SIZE="${MAC_HDD_SIZE:-256G}"
# If 1: rebuild BaseSystem.img from BaseSystem.dmg (never delete dmg). QEMU must be stopped.
FORCE_RESTORE_BASESYSTEM="${FORCE_RESTORE_BASESYSTEM:-0}"
# If 1: recreate MacHDD even when larger than MIN (destroys guest install — opt-in only)
FORCE_RECREATE_MAC_HDD="${FORCE_RECREATE_MAC_HDD:-0}"

mkdir -p "$DATA"
cd "$OSX_KVM"

bytes_of() {
  local p="$1"
  if [[ -f "$p" ]] || [[ -L "$p" ]]; then
    stat -c%s "$p" 2>/dev/null || stat -f%z "$p" 2>/dev/null || echo 0
  else
    echo 0
  fi
}

move_or_link() {
  local name="$1"
  local src="${OSX_KVM}/${name}"
  local dst="${DATA}/${name}"

  if [[ -L "$src" ]]; then
    echo "OK symlink: $src → $(readlink -f "$src" 2>/dev/null || readlink "$src")"
    return 0
  fi

  if [[ -f "$dst" ]] && [[ ! -f "$src" ]]; then
    ln -sf "$dst" "$src"
    echo "Linked existing volume file: $src → $dst"
    return 0
  fi

  if [[ -f "$src" ]] && [[ ! -f "$dst" ]]; then
    echo "Moving $src → $dst (persist to volume)..."
    mv "$src" "$dst"
    ln -sf "$dst" "$src"
    echo "Moved + linked: $name"
    return 0
  fi

  if [[ -f "$src" ]] && [[ -f "$dst" ]]; then
    # Prefer volume copy if larger (real disk vs stub)
    local ssz dsz
    ssz=$(bytes_of "$src")
    dsz=$(bytes_of "$dst")
    if [[ "$ssz" -gt "$dsz" ]]; then
      echo "Volume copy smaller; replacing $dst with $src"
      mv -f "$src" "$dst"
    else
      rm -f "$src"
    fi
    ln -sf "$dst" "$src"
    echo "Reconciled $name (src=$ssz dst=$dsz)"
    return 0
  fi

  echo "No $name yet (will appear after SHORTNAME=sonoma make or ensure_mac_hdd)"
}

# virtual-size helper (top-level only; ignore child file node). 0 if unreadable.
mac_virt_bytes() {
  local f="$1"
  [[ -f "$f" ]] || { echo 0; return; }
  if command -v jq >/dev/null 2>&1; then
    qemu-img info --output=json "$f" 2>/dev/null | jq -r '."virtual-size" // 0' || echo 0
  else
    # Prefer the largest virtual-size field (qcow2 top-level >> file child)
    qemu-img info --output=json "$f" 2>/dev/null \
      | grep -oE '"virtual-size": *[0-9]+' \
      | grep -oE '[0-9]+' \
      | sort -n | tail -1 || echo 0
  fi
}

# True if a live (non-zombie) qemu-system is running
qemu_live() {
  local pid state comm
  for pid in /proc/[0-9]*; do
    [[ -r "$pid/comm" ]] || continue
    comm=$(cat "$pid/comm" 2>/dev/null || true)
    case "$comm" in
      qemu-system-x86_64|qemu-system-x86) ;;
      *) continue ;;
    esac
    state=$(awk '{print $3}' "$pid/stat" 2>/dev/null || true)
    [[ "$state" != "Z" ]] || continue
    return 0
  done
  return 1
}

# Create / recreate MacHDD on volume if missing or virtual-size too small.
# Fresh 256G sparse qcow2 is ~196KB on disk — that is VALID pre-install (not a bug).
# NEVER touches BaseSystem.img / BaseSystem.dmg.
ensure_mac_hdd() {
  local dst="${DATA}/mac_hdd_ng.img"
  local src="${OSX_KVM}/mac_hdd_ng.img"
  local sz vsz
  local min_virt=$((50 * 1024 * 1024 * 1024))  # 50GiB

  if qemu_live; then
    if [[ -f "$dst" ]]; then
      sz=$(bytes_of "$dst")
      vsz=$(mac_virt_bytes "$dst")
      if [[ "${vsz:-0}" -ge "$min_virt" ]] && [[ "${FORCE_RECREATE_MAC_HDD}" != "1" ]]; then
        echo "ensure_mac_hdd: QEMU running; MacHDD virt=${vsz} on_disk=${sz} — leave alone"
        ln -sfn "$dst" "$src"
        return 0
      fi
      echo "ERROR: cannot recreate/grow MacHDD while QEMU holds the image (on_disk=${sz} virt=${vsz})"
      echo "  Stop QEMU first: killall -9 qemu-system-x86_64"
      return 1
    fi
    echo "ERROR: MacHDD missing and QEMU running — stop QEMU and re-run"
    return 1
  fi

  sz=$(bytes_of "$dst")
  vsz=$(mac_virt_bytes "$dst")
  if [[ "${FORCE_RECREATE_MAC_HDD}" == "1" ]] || [[ ! -f "$dst" ]] || [[ "${vsz:-0}" -lt "$min_virt" ]]; then
    if [[ -f "$dst" ]]; then
      echo "ensure_mac_hdd: recreating MacHDD (was on_disk=${sz} virt=${vsz}) → ${MAC_HDD_SIZE} sparse qcow2"
      rm -f "$dst"
    else
      echo "ensure_mac_hdd: creating ${MAC_HDD_SIZE} sparse qcow2 at $dst"
    fi
    qemu-img create -f qcow2 "$dst" "$MAC_HDD_SIZE"
    sz=$(bytes_of "$dst")
    vsz=$(mac_virt_bytes "$dst")
    echo "ensure_mac_hdd: created on_disk=${sz} virtual=${vsz} (${MAC_HDD_SIZE})"
  else
    echo "ensure_mac_hdd: OK existing MacHDD on_disk=${sz} virt=${vsz}"
    # Optional grow virtual size if below 200GiB floor
    local grow_floor=$((200 * 1024 * 1024 * 1024))
    if [[ -n "${vsz:-}" ]] && [[ "$vsz" -lt "$grow_floor" ]]; then
      echo "ensure_mac_hdd: virtual-size ${vsz} < 200GiB — resizing to ${MAC_HDD_SIZE}"
      qemu-img resize "$dst" "$MAC_HDD_SIZE" || true
    fi
  fi

  # Symlink into OSX-KVM (replace regular file with link if needed)
  if [[ -e "$src" ]] && [[ ! -L "$src" ]]; then
    local ssz
    ssz=$(bytes_of "$src")
    if [[ "$ssz" -gt "$(bytes_of "$dst")" ]]; then
      echo "ensure_mac_hdd: OSX-KVM file larger than volume — moving to volume"
      mv -f "$src" "$dst"
    else
      rm -f "$src"
    fi
  fi
  ln -sfn "$dst" "$src"
  ls -lah "$src" "$dst" || true
  qemu-img info "$dst" 2>/dev/null | head -20 || true
}

# Restore BaseSystem.img from dmg WITHOUT deleting dmg or MacHDD.
# Use after mistaken disk0 erase (BaseSystem content wiped while Recovery was live).
restore_basesystem_from_dmg() {
  local dmg="${DATA}/BaseSystem.dmg"
  local img="${DATA}/BaseSystem.img"
  local dmg_kvm="${OSX_KVM}/BaseSystem.dmg"
  local img_kvm="${OSX_KVM}/BaseSystem.img"

  if qemu_live; then
    echo "ERROR: restore_basesystem_from_dmg requires QEMU stopped"
    return 1
  fi

  if [[ ! -f "$dmg" ]] && [[ -f "$dmg_kvm" ]]; then
    echo "Moving BaseSystem.dmg → $dmg"
    mv "$dmg_kvm" "$dmg"
  fi
  if [[ ! -f "$dmg" ]]; then
    echo "ERROR: no BaseSystem.dmg on volume or OSX-KVM — run: SHORTNAME=sonoma make"
    return 1
  fi

  echo "Restoring BaseSystem.img from dmg (raw) — MacHDD untouched..."
  # Write to temp then replace so partial convert never leaves a half file as sole copy
  qemu-img convert -f dmg -O raw -p "$dmg" "${img}.new"
  mv -f "${img}.new" "$img"
  ln -sfn "$img" "$img_kvm"
  ln -sfn "$dmg" "$dmg_kvm" 2>/dev/null || true
  ls -lah "$img" "$dmg"
  qemu-img info "$img" 2>/dev/null | head -15 || true
  echo "BaseSystem restored. MacHDD left intact."
}

move_or_link BaseSystem.img
move_or_link mac_hdd_ng.img

# dmg optional persist
if [[ -f "${OSX_KVM}/BaseSystem.dmg" ]] && [[ ! -f "${DATA}/BaseSystem.dmg" ]]; then
  mv "${OSX_KVM}/BaseSystem.dmg" "${DATA}/BaseSystem.dmg"
  ln -sf "${DATA}/BaseSystem.dmg" "${OSX_KVM}/BaseSystem.dmg"
fi
if [[ -f "${DATA}/BaseSystem.dmg" ]] && [[ ! -e "${OSX_KVM}/BaseSystem.dmg" ]]; then
  ln -sf "${DATA}/BaseSystem.dmg" "${OSX_KVM}/BaseSystem.dmg"
fi

if [[ "${FORCE_RESTORE_BASESYSTEM}" == "1" ]]; then
  restore_basesystem_from_dmg
fi

ensure_mac_hdd

echo "=== /data inventory (disks) ==="
ls -lah "$DATA"/BaseSystem.img "$DATA"/mac_hdd_ng.img "$DATA"/BaseSystem.dmg 2>/dev/null || true
echo "=== OSX-KVM disk links ==="
ls -lah "$OSX_KVM"/BaseSystem.img "$OSX_KVM"/mac_hdd_ng.img 2>/dev/null || true

# Hard guard: MacHDD must exist with large virtual size (sparse on-disk ~196K is OK pre-install).
# F-B1-EMPTY-MACHDD fully closes only after install grows size_on_disk ≫196KB.
mac_sz=$(bytes_of "${DATA}/mac_hdd_ng.img")
mac_virt=0
if command -v qemu-img >/dev/null 2>&1 && [[ -f "${DATA}/mac_hdd_ng.img" ]]; then
  mac_virt=$(mac_virt_bytes "${DATA}/mac_hdd_ng.img")
fi
min_virt=$((50 * 1024 * 1024 * 1024))  # 50GiB floor
if [[ ! -f "${DATA}/mac_hdd_ng.img" ]] || [[ "${mac_virt:-0}" -lt "$min_virt" ]]; then
  echo "ERROR: MacHDD missing or virtual-size too small (on_disk=${mac_sz} virt=${mac_virt}) — F-B1 open"
  exit 1
fi
echo "OK: MacHDD on_disk=${mac_sz} virtual=${mac_virt} (sparse header OK pre-install; install must grow on_disk ≫196KB)"
if [[ "$mac_sz" -gt 1048576 ]]; then
  echo "OK: MacHDD has guest data (on_disk ≫1MiB) — install progress / F-B1 growth signal"
else
  echo "NOTE: MacHDD still sparse header-only on disk — run install-macos-disk1 (disk1 only) to grow"
fi
