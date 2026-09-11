# FORGE macOS VM Progress Report (not PASS)

**Date:** 2026-07-29  
**Target:** `/home/leviathan/OPENCODE_WORKSPACE/FORGE`  
**Status:** **BLOCKED on Gate B3/B5** — Sonoma installed and booting, first-boot SSV still validating after multi-hour wait; SSH/Xcode/sim not yet reachable.

## What is DONE (evidence-backed)

### Gate A — Master image & VM infra — **PASS**

| Item | Result |
|------|--------|
| Image | `macos-forge:master` baked 2026-07-29T00:58Z (also tagged `:weston`) |
| Container | `forge-vm`: privileged, **runtime=runc**, `/dev/kvm`, cpuset `0-1,16`, memory 6g, port 50922→10022 |
| Volume | `forge-vm-data:/data` (not over OSX-KVM) |
| Weston | headless backend, DISPLAY=:0 |
| QEMU | stock Launch.sh + UHCI + telnet :4444; guest RAM=4 SMP=2 |
| Keyboard | `qemu_typer.py` + sendkey proven |
| Screenshots | screendump → PNG throughout install/boot |

Evidence: `{SCRATCH}/vm-inspect.txt`, `projects/forge/tmp/vm-inspect.txt`

### Gate B1–B2 — Install — **PASS**

| Item | Result |
|------|--------|
| BaseSystem | 3.0G raw on volume |
| MacHDD | ~30G qcow2 after `startosinstall` |
| Disk target | **disk0 ~275GB** (this layout; not handover disk1) |
| Install | Recovery Terminal → erase APFS MacintoshHD → startosinstall to `/Volumes/MacintoshHD` |
| OpenCore | Boot picker showed **MacintoshHD** as bootable volume |

Evidence: install poll PNGs, `install_status.txt`, OpenCore picker screenshots

### Host dual-mode structure — **PASS**

```
pytest projects/forge/tests/test_dual_mode_structure.py → 8 passed
```

Launch menu, Mode1 SwiftTerm path, Mode2 Mission Control sources present; SwiftTerm 1.15.x; forge-bundle.js non-empty; docker master scripts present.

## What is BLOCKED

### Gate B3/B5 — First boot SSV → SSH

- After install, first boot enters verbose **cryptex/SSV** graft (expected).
- Multi-hour wait with QEMU ~150%+ CPU; screenshots change (SSV progress).
- Observed **reboots back to OpenCore picker** ~every 40–50 min during SSV (cycles 43/87/131).
- Clean reboot with **nopicker + no InstallMedia** still in cryptex after additional ~90 min; SSH port 50922 times out.
- **No SIP/AMFI disable. No intentional mid-SSV kill for “speed”.** One QEMU restart only after multi-cycle SSV loops for cleaner nopicker boot.

**SSH:** not available. Transcripts show `Connection timed out during banner exchange` on `:50922`.

### Gates C–E

Blocked on SSH: Xcode, xcodegen, xcodebuild sim, dual-mode UI screenshots, ship report.

## Deviations

1. `BASESYSTEM_FORMAT=raw` (volume img is raw, not qcow2).
2. Install target **disk0** (MacHDD) in this disk enumeration.
3. Forced `--runtime=runc` (daemon default was nvidia).
4. Concurrent god-loop agents wiped growing MacHDD once (~3.9G→196K); re-installed; added install lock discipline.
5. SSV wall-clock on 2 vCPU + qcow2 exceeds single-session 90 min estimate.

## Live operator reattach

```bash
docker ps --filter name=forge-vm
docker exec -u root forge-vm /usr/local/bin/start-display.sh   # if needed
# Do NOT kill QEMU while CPU high + cryptex text scrolling
docker exec forge-vm bash -c 'echo screendump /tmp/s.ppm | socat -t 2 - TCP:127.0.0.1:4444'
# When Setup Assistant appears: complete setup, enable Remote Login, then:
ssh -p 50922 user@127.0.0.1
```

Volume disks: `forge-vm-data` → `/data/BaseSystem.img` + `/data/mac_hdd_ng.img` (survive container recreate).

## Next steps to PASS (sequential)

1. **Do not interrupt** QEMU while SSV runs (CPU high, verbose changing).
2. When Setup Assistant appears: keyboard-only setup → enable Remote Login / SSH.
3. Capture `ssh -p 50922 … hostname` → `{SCRATCH}/ssh-50922.txt`.
4. Xcode CLT/Xcode → rsync forge → xcodegen → xcodebuild iphonesimulator.
5. Sim screenshots dual-mode; fix Swift blockers; fill `docs/GOD_LOOP_ACCEPTANCE.md` gates C–E.
6. Full build report under `Grok_Build/Reports/`.

## Scratch evidence dir

`/tmp/grok-goal-82389daaa98b/implementer` (session scratch; copy durable pieces under `projects/forge/tmp/` / `Reports/` as needed).

---

**Verdict:** Infrastructure + Sonoma **install** are solid. First-boot **SSV → SSH** is the remaining multi-hour wall-clock gate. Not a PASS.
