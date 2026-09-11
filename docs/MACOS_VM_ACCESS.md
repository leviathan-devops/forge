# FORGE macOS VM — Access & Launch (Tahoe primary · 2026-07-31)

**Status:** Live **macOS Tahoe 26.6** guest with SSH.  
**Image:** `macos-forge:master`  
**Volume:** `forge-vm-data` (MacHDD + OpenCore-tahoe + serial — **do not wipe**)  
**Container:** `forge-vm`

---

## Is it 100% working?

| Surface | Status | Notes |
|---------|--------|--------|
| Boot (Haswell-noTSX + OpenCore-**tahoe**) | **Yes** | `start-tahoe` / `start-tahoe-boot.sh` |
| Guest OS | **Yes** | ProductVersion **26.6** Build **25G72** |
| Desktop / login | **Yes** | Account `user` / `alpine` |
| SSH host `:50922` | **Yes** | `hostname` → `iMac-Pro.local` |
| Sonoma residual | Backup only | `mac_hdd_ng.sonoma14.raw.bak` — restore via `start-sonoma` if needed |
| Xcode | **Deferred** | Operator delivers `.xip` next cycle |

**Daily use is working.** Reattaching a stopped container + Tahoe boot is minutes.

---

## Credentials

```
SSH:      ssh -p 50922 user@127.0.0.1
Password: alpine
Guest:    iMac-Pro.local / macOS 26.6 (Tahoe)  — PRIMARY
Legacy:   Sonoma 14.8 bak on volume only (not daily boot)
```

---

## One-command reattach (preferred)

From project root:

```bash
cd /home/leviathan/OPENCODE_WORKSPACE/FORGE

# Reattach container, sync scripts, boot Tahoe if QEMU dead, print access
./docker/run-forge-vm.sh up

# Explicit Tahoe boot (post-install MacHDD)
./docker/run-forge-vm.sh start-tahoe

# Probe SSH
./docker/run-forge-vm.sh ssh

# Host VNC on :5901 (viewer sees macOS GUI)
./docker/run-forge-vm.sh vnc-host
vncviewer 127.0.0.1:5901
# or: remote-viewer vnc://127.0.0.1:5901
```

### What `up` does

1. `docker start forge-vm` if stopped (creates volume+container only if missing)  
2. Syncs `docker/*` scripts into `/usr/local/bin`  
3. If no QEMU: prefers **`start-tahoe-boot.sh`** after migration (Sonoma bak present or `FORGE_BOOT=tahoe`)  
4. Prints SSH/VNC hints  

Legacy residual: `./docker/run-forge-vm.sh start-sonoma` (Sonoma bak disk only).

---

## SSH access (host)

```bash
ssh -p 50922 user@127.0.0.1
# password: alpine

# one-shot
ssh -p 50922 user@127.0.0.1 'hostname; sw_vers'
# expect ProductVersion 26.6 (or ≥26.2)
```

Python (no sshpass needed):

```python
import paramiko
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("127.0.0.1", port=50922, username="user", password="alpine",
          allow_agent=False, look_for_keys=False)
_, o, _ = c.exec_command("hostname; sw_vers")
print(o.read().decode())
c.close()
```

Port map: **host 50922 → container 10022 → guest 22** (QEMU user netdev).

---

## See the GUI

### A) Host VNC viewer (recommended — fast / fit-to-screen)

```bash
# Preferred: Tight encoding + scale-to-screen (not raw 1080p full-colour)
cd /home/leviathan/OPENCODE_WORKSPACE/FORGE
./scripts/launch-vnc-fast.sh full     # fullscreen, scaled to your monitor
# or:
./scripts/launch-vnc-fast.sh fit      # windowed, snappier quality settings

# Manual equivalent (TigerVNC):
./docker/run-forge-vm.sh vnc-host
vncviewer -QualityLevel=2 -CompressLevel=6 -PreferredEncoding=Tight -FullColour=0 -FullScreen 127.0.0.1::5901
```

**Do not** open raw `vncviewer 127.0.0.1:5901` with default full-colour 1:1 — that is what feels unusable.

Guest resources (Tahoe interactive profile): **6 GiB RAM / 8 vCPU / 128 MiB VGA / lossy VNC**.

On **new** containers, `run-forge-vm.sh` also publishes `-p 5901:5900` and Tahoe/Sonoma boot scripts rewrite Launch to `-vnc 0.0.0.0:0`.

Screendump without viewer:

```bash
./docker/run-forge-vm.sh status
# → projects/forge/tmp/status.png (if convert/PIL available)
```

### B) Container virtual display (Weston — optional)

Used for headless compositor / automation, **not** required to view macOS once VNC works.

```bash
docker exec -u root forge-vm /usr/local/bin/start-display.sh
```

**Reality:** Production path is **VNC + QEMU monitor sendkey**, not GTK/Weston pointer.

---

## Fresh machine / new container (minutes if volume exists)

```bash
cd /home/leviathan/OPENCODE_WORKSPACE/FORGE
docker images | grep macos-forge
./docker/run-forge-vm.sh up
# or explicit:
./docker/run-forge-vm.sh recreate
./docker/run-forge-vm.sh sync-scripts
./docker/run-forge-vm.sh start-tahoe
./docker/run-forge-vm.sh vnc-host
```

Boot time after install: **~1–3 minutes** to login.  
First-time macOS install from BaseSystem: **hours** — do not use wait-theater; use `start-tahoe` after install.

Upgrade process: `docs/TAHOE_MACOS26_UPGRADE_PROCESS.md`

---

## Tahoe contract (never re-break)

| Must | Value |
|------|--------|
| CPU | **Force** `Haswell-noTSX` (never `${CPU:-…}` — image ENV is Penryn) |
| SHORTNAME | `tahoe` |
| OpenCore | `OpenCore-tahoe.qcow2` |
| Serial | GENERATE_UNIQUE → `/data/tahoe-serial.env` |
| Guest RAM | ≤4G |
| cpuset | `0-3,16-19` |
| QEMU count | exactly **1** |
| Volume wipe | **FORBIDDEN** after install |
| Boot path | `start-tahoe` / `start-tahoe-boot.sh` |

### NEVER do this again

| Bug | Wrong | Right |
|-----|-------|-------|
| CPU | Image ENV `Penryn` / `${CPU:-Haswell}` | **Force** `CPU=Haswell-noTSX` in `start-tahoe-boot.sh` |
| OpenCore | stock / nopicker / only sonoma after migration | `OpenCore-tahoe.qcow2` for daily |
| Multi-QEMU | second Launch while first lives | `killall` then single start; assert `n=1` |
| Volume wipe | `docker volume rm forge-vm-data` | **Never** after install |
| SIP/AMFI | disable for “SSH” | Forbidden — enable Remote Login only |
| Xcode block | Wait on OS for xip | Finish Tahoe SSH first; xip next cycle |

Upstream: [sickcodes/Docker-OSX](https://github.com/sickcodes/Docker-OSX) (`SHORTNAME=tahoe`).

---

## Resource pins (this host)

| Pin | Value |
|-----|--------|
| Guest RAM | 4000 MiB |
| SMP | 4 cores |
| Host VNC | `127.0.0.1:5901` (via `vnc-host`) |
| SSH | `127.0.0.1:50922` |

---

## Evidence (infra PASS)

```
tmp/evidence/tahoe/ssh-50922.txt
tmp/evidence/tahoe/sw_vers.txt      # ProductVersion 26.6
tmp/evidence/tahoe/qemu-cmdline.txt # Haswell-noTSX + OpenCore-tahoe
tmp/evidence/tahoe/disk-backup.txt  # Sonoma bak present
Reports/FORGE_TAHOE_MACOS26_E2E_FORENSIC_REPORT.md
```
