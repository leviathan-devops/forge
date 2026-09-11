# E4 — One-command macOS VM reattach

**Gate E4:** Operator can describe one-command VM reattach (`docker/run-forge-vm.sh`).  
**Stamp:** 2026-07-29 Wave 5 `ci-or-local-e1`

## One command (reattach / ensure running)

```bash
cd /home/leviathan/OPENCODE_WORKSPACE/FORGE
./docker/run-forge-vm.sh
```

| Container state | What the script does | Exit |
|-----------------|----------------------|------|
| **Running** | Prints `Container forge-vm already running.` + image/privileged/memory; **no restart** | 0 |
| **Stopped** (exists) | `docker start forge-vm` | 0 |
| **Missing** | `docker run -d` from `macos-forge:master` with KVM, volume `forge-vm-data:/data`, port `50922:10022`, cpuset `0-1,16`, mem 6g | 0 |

**Proven this wave:** container already Up → reattach exit 0; log `tmp/w5_e4_reattach_*.log`.

## Optional follow-ups (not required for reattach)

```bash
./docker/run-forge-vm.sh status          # disks, QEMU, Weston, F-B1 growth, screendump → tmp/
./docker/run-forge-vm.sh sync-scripts    # docker cp host docker/* into container
./docker/run-forge-vm.sh start-qemu      # only if QEMU not running (never mid-SSV kill)
```

## Hard rules (fail closed)

- Never `docker rm forge-vm` unless `/data` holds BaseSystem + mac_hdd (use volume `forge-vm-data`).
- Never restart QEMU during SSV first-boot.
- Never `runtime=nvidia` / NVIDIA DRI for forge-vm.
- Prefer `WESTON_BACKEND=headless` (default) or `intel` (card2 + renderD129 only).

## Env knobs

| Var | Default | Meaning |
|-----|---------|---------|
| `FORGE_IMAGE` | `macos-forge:master` | Image tag |
| `FORGE_NAME` | `forge-vm` | Container name |
| `WESTON_BACKEND` | `headless` | `headless` \| `intel` |
| `FORGE_CPUSET` | `0-1,16` | Host CPU pin |
| `FORGE_MEMORY` | `6g` | Container memory |

## Operator crib

> “To reattach the FORGE macOS Sonoma VM: `./docker/run-forge-vm.sh` from the forge project root. If it is already up, that is a no-op success; if stopped, it starts; if missing, it recreates from `macos-forge:master` with the persistent `forge-vm-data` volume.”
