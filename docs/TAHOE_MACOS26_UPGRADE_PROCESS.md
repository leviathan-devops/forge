# Forge-VM → macOS Tahoe (26.x) for Xcode 26.6 + current iPhones

## Why

| Goal | Requirement |
|------|-------------|
| Xcode **26.6** | Guest macOS **≥ 26.2** (Tahoe) |
| Current-gen iPhone / App Store floor (2026) | Modern **Xcode 26 + iOS 26 SDK** |
| Current forge-vm | **Sonoma 14.8** — **cannot** run Xcode 26.6 |

This is **not** “install older Xcode on Sonoma.”  
This is **new guest OS (Tahoe)** then **Xcode 26.6**.

Upstream Docker-OSX (sickcodes) documents:

```bash
-e SHORTNAME=tahoe \
-e CPU=Haswell-noTSX \
-e CPUID_FLAGS='kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on' \
-e GENERATE_UNIQUE=true \
-e MASTER_PLIST_URL='https://raw.githubusercontent.com/sickcodes/osx-serial-generator/master/config-custom-sonoma.plist'
```

(Same Haswell + serial pattern as Sonoma; **SHORTNAME=tahoe** pulls Tahoe BaseSystem.)

Naming note: Docker-OSX README labels the block “Tahoe (16)” in places; Apple product versioning for your Xcode is **macOS 26.x Tahoe**. What matters: **`SHORTNAME=tahoe`** + guest `sw_vers` ≥ **26.2**.

---

## Do NOT

- Put Xcode 26.6 on Sonoma 14  
- Use **Penryn** CPU  
- Wipe `forge-vm-data` without renaming Sonoma disk first  
- Dual QEMU / parallel god-loops during install  
- “Wait theater” multi-day SSV sleep as strategy  

---

## Process (ordered)

### Phase 0 — Prep (you + host) — ~15 min

1. Finish download of **Xcode_26.6.xip** onto Leviathan; note full path.  
2. Free host RAM if needed (`free -h`; guest uses ~4G, container ~6G).  
3. Confirm KVM: `ls -l /dev/kvm`.  
4. Keep Sonoma disk as backup (do **not** delete until Tahoe SSH works).

### Phase 1 — Preserve Sonoma, new Tahoe disk — ~15–30 min

On host:

```bash
cd /home/leviathan/OPENCODE_WORKSPACE/FORGE
./docker/run-forge-vm.sh up   # ensure container up
```

Inside container (as root), **rename** Sonoma disk; create empty Tahoe disk:

```bash
docker exec -u root forge-vm bash -c '
set -e
# stop qemu first
killall qemu-system-x86_64 2>/dev/null || true
sleep 2
# backup sonoma HDD (do not delete)
if [ -f /data/mac_hdd_ng.raw ]; then
  mv /data/mac_hdd_ng.raw /data/mac_hdd_ng.sonoma14.raw.bak
fi
if [ -f /data/mac_hdd_ng.img ]; then
  mv /data/mac_hdd_ng.img /data/mac_hdd_ng.sonoma14.img.bak 2>/dev/null || true
fi
# fresh sparse disk for Tahoe (256G raw ok; grows with use)
qemu-img create -f raw /data/mac_hdd_ng.raw 256G
# clear sonoma-only OpenCore if we regenerate on boot
ls -la /data/
'
```

### Phase 2 — Fetch Tahoe BaseSystem — ~30–90 min (network)

Docker-OSX pulls installer via `SHORTNAME=tahoe`. On forge image, restore/fetch BaseSystem:

```bash
# Prefer image-native fetch if present; else use OSX-KVM fetch script
docker exec -u root -e SHORTNAME=tahoe forge-vm bash -c '
set -e
export SHORTNAME=tahoe
# If persist/restore-basesystem path exists:
if [ -x /usr/local/bin/persist-disks.sh ]; then
  # project-specific: may need restore-basesystem adapted for tahoe
  true
fi
# Standard OSX-KVM path inside image:
cd /home/arch/OSX-KVM
# Many images use fetch-macOS-v2.py or similar — run the image’s documented fetch for $SHORTNAME
# Example pattern (exact script name may vary in macos-forge image):
if [ -f fetch-macOS-v2.py ]; then
  python3 fetch-macOS-v2.py --shortname tahoe || python3 fetch-macOS-v2.py
fi
# Result should include BaseSystem.dmg/img for Tahoe
ls -lah BaseSystem* mac_hdd* 2>/dev/null | head
# Persist to volume
cp -a BaseSystem.img /data/BaseSystem.img 2>/dev/null || \
  qemu-img convert -O raw BaseSystem.dmg /data/BaseSystem.img 2>/dev/null || true
ls -lah /data/BaseSystem.img
'
```

**Gate:** `/data/BaseSystem.img` exists and is multi-GB (Tahoe installer).

### Phase 3 — Boot contract (Haswell + serial + Tahoe) — ~15 min

Force (same mistakes as Sonoma = death):

```bash
export SHORTNAME=tahoe
export CPU=Haswell-noTSX
export CPUID_FLAGS='kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on'
export GENERATE_UNIQUE=true
export MASTER_PLIST_URL='https://raw.githubusercontent.com/sickcodes/osx-serial-generator/master/config-custom-sonoma.plist'
export RAM=4 SMP=4 CORES=4
```

Implement as `docker/start-tahoe-boot.sh` (clone of `start-sonoma-boot.sh` with `SHORTNAME=tahoe`, serial file `/data/tahoe-serial.env`, OpenCore-tahoe if generated).

Boot **installer** (BaseSystem + empty MacHDD), **not** old Sonoma disk.

### Phase 4 — Install macOS Tahoe to MacHDD — ~1–3 hours

Via VNC (`./docker/run-forge-vm.sh vnc-host` → `:5901`):

1. Boot **macOS Base System**  
2. Disk Utility → erase **largest** disk (MacHDD) as APFS **Macintosh HD**  
3. Reinstall / continue install to that disk  
4. Wait through install reboots  

Or Recovery Terminal `startosinstall` (same pattern as Sonoma install we already ran).

**Gate:** install completes; no InstallMedia-only loop.

### Phase 5 — First boot Tahoe + Setup Assistant — ~1–4 hours wall

1. Boot **only** MacHDD + OpenCore (Haswell), no install media  
2. SSV/first boot — **do not** Penryn; poll with screendump/SSH, no 3-day god-loop theater  
3. Create account (e.g. `user` / `alpine` or keep consistent)  
4. Enable Remote Login  
5. Prove: `ssh -p 50922 user@127.0.0.1` → `sw_vers` shows **26.x**

**Gate:**

```bash
ssh -p 50922 user@127.0.0.1 'sw_vers'
# ProductVersion must be 26.2 or higher
```

### Phase 6 — Xcode 26.6 — ~30–90 min

```bash
# Host → guest (password auth / paramiko as deploy-to-vm)
# scp Xcode_26.6.xip to guest ~/Downloads/
# Guest:
cd ~/Downloads
xip -x Xcode_26.6.xip    # or double-click / archive util
sudo mv Xcode.app /Applications/
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
xcodebuild -version
```

**Gate:** `xcodebuild -version` shows **26.6**.

### Phase 7 — FORGE product build — ~15–45 min

```bash
# host
./scripts/deploy-to-vm.sh
# guest
cd ~/FORGE
~/bin/xcodegen generate   # if available
xcodebuild -scheme FORGE -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

**Gate:** `BUILD SUCCEEDED` + evidence under `tmp/evidence/vm-build/`.

---

## Time budget (expected, not fantasy)

| Total | When |
|-------|------|
| **4–8 h** | Smooth network + clean Haswell boot |
| **8–14 h** | One install/SSV hitch |
| Multi-day | Only if Tahoe KVM regression — then debug **that**, not Sonoma again |

---

## Compatibility (iPhone)

| Stack | Role |
|-------|------|
| macOS **26.2+** guest | Runs Xcode 26.6 |
| Xcode **26.6** | iOS **26.x** SDK, current devices / App Store floor |
| FORGE app | Built with that SDK → current-gen iPhones |

Sonoma + old Xcode was a **temporary** VM floor. **Tahoe + Xcode 26.6 is the proper target.**

---

## Operator “go” checklist

- [ ] Xcode 26.6 `.xip` path on Leviathan: `________________`  
- [ ] Confirm: backup Sonoma disk, new empty MacHDD  
- [ ] Run Phase 2–7 with **one** agent owning forge-vm  
- [ ] Prove `sw_vers` ≥ 26.2 then `xcodebuild -version` 26.6  
- [ ] FORGE sim build green  

---

## Refs

- https://github.com/sickcodes/Docker-OSX (SHORTNAME=tahoe block)  
- https://developer.apple.com/documentation/xcode-release-notes/xcode-26_6-release-notes  
- Local: `docs/MACOS_VM_ACCESS.md`, `docker/start-sonoma-boot.sh` (template for tahoe)
