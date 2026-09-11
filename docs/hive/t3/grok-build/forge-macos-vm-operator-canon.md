# FORGE macOS VM — Operator Canon (Hive L2 organized)

# FORGE macOS VM — Access & Launch (post-2026-07-30 PASS)

**Status:** Working Sonoma guest with SSH.  
**Image:** `macos-forge:master`  
**Volume:** `forge-vm-data` (MacHDD + OpenCore-sonoma + serial — **do not wipe**)  
**Container:** `forge-vm`

---

## Is it 100% working?

| Surface | Status | Notes |
|---------|--------|--------|
| Boot (Haswell-noTSX + sonoma OC) | **Yes** | No SSV loop when using `start-sonoma` |
| Desktop / login | **Yes** | Account `user` / `alpine` |
| SSH host `:50922` | **Yes** | Proven `hostname` → `users-iMac-Pro.local` |
| First-time install | Manual/history | Disk already installed on volume |
| Keyboard Setup Assistant | Cosmetic | May pop once after login; Continue/Quit |

**Daily use is working.** Recreating the *install* is still multi-hour; **reattaching** a stopped container + Sonoma boot is minutes.

---

## Credentials

```
SSH:      ssh -p 50922 user@127.0.0.1
Password: alpine
Guest:    users-iMac-Pro.local / macOS 14.8.x (Sonoma)
```

---

## One-command reattach (preferred)

From project root:

```bash
cd /home/leviathan/OPENCODE_WORKSPACE/FORGE

# Reattach container, sync scripts, boot Sonoma if QEMU dead, print access
./docker/run-forge-vm.sh up

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
3. If no QEMU: `start-display.sh` + **`start-sonoma-boot.sh`** (forces Haswell-noTSX)  
4. Prints SSH/VNC hints  

---

## SSH access (host)

```bash
ssh -p 50922 user@127.0.0.1
# password: alpine

# one-shot
ssh -p 50922 user@127.0.0.1 'hostname; sw_vers'
```

Python (no sshpass needed):

```python
import paramiko
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("127.0.0.1", port=50922, username="user", password="alpine",
          allow_agent=False, look_for_keys=False)
_, o, _ = c.exec_command("hostname")
print(o.read().decode())
c.close()
```

Port map: **host 50922 → container 10022 → guest 22** (QEMU user netdev).

---

## See the GUI

### A) Host VNC viewer (recommended)

QEMU listens on VNC inside the container. Publish or proxy to the host:

```bash
# Proxy (works even if QEMU bound 127.0.0.1 only)
./docker/run-forge-vm.sh vnc-host

# Viewer on host
vncviewer 127.0.0.1:5901
# or remote-viewer / Remmina / TigerVNC
```

On **new** containers, `run-forge-vm.sh` also publishes `-p 5901:5900` and `start-sonoma-boot.sh` rewrites Launch to `-vnc 0.0.0.0:0`.

Screendump without viewer:

```bash
./docker/run-forge-vm.sh status
# → projects/forge/tmp/status.png (if convert/PIL available)
```

### B) Container virtual display (Weston — optional)

Used for headless compositor / automation, **not** required to view macOS once VNC works.

```bash
# Inside container: Weston headless + XWayland
docker exec -u root forge-vm /usr/local/bin/start-display.sh
# WESTON_BACKEND=intel only with Intel DRI devices (never NVIDIA training GPU)

# Env
#   DISPLAY=:0
#   XDG_RUNTIME_DIR=/tmp/weston-run
```

Intel headed (host must pass DRI):

```bash
WESTON_BACKEND=intel ./docker/run-forge-vm.sh recreate
# requires --device /dev/dri/card2 --device /dev/dri/renderD129
```

**Reality (2026-07-30):** Production path is **VNC + QEMU monitor sendkey**, not GTK/Weston pointer. Weston remains available for future headed tooling.

---

## Fresh machine / new container (minutes if volume exists)

```bash
cd /home/leviathan/OPENCODE_WORKSPACE/FORGE

# Image must exist
docker images | grep macos-forge

# Create or reattach (volume forge-vm-data holds the installed MacHDD)
./docker/run-forge-vm.sh up

# If you destroyed the container but kept the volume:
./docker/run-forge-vm.sh recreate
./docker/run-forge-vm.sh sync-scripts
./docker/run-forge-vm.sh start-sonoma
./docker/run-forge-vm.sh vnc-host
```

Boot time after install: **~1–3 minutes** to login.  
First-time macOS install from BaseSystem: **hours** — do not use wait-theater; use `start-sonoma` after install.

---

## NEVER do this again (root causes)

| Bug | Wrong | Right |
|-----|-------|-------|
| CPU | Image ENV `Penryn` / `${CPU:-Haswell}` | **Force** `export CPU=Haswell-noTSX` in `start-sonoma-boot.sh` |
| OpenCore | stock / nopicker | `OpenCore-sonoma.qcow2` + `config-custom-sonoma.plist` |
| Serial | none | `GENERATE_UNIQUE` → `/data/sonoma-serial.env` |
| Multi-QEMU | second Launch while first lives | `killall` then single start; assert `n=1` |
| Volume wipe | `docker volume rm forge-vm-data` | **Never** after install |
| SIP/AMFI | disable for “SSH” | Forbidden — enable Remote Login only |

Upstream contract: [sickcodes/Docker-OSX](https://github.com/sickcodes/Docker-OSX) Sonoma block.

---

## Resource pins (this host)

| Pin | Value |
|-----|--------|
| cpuset | `0-3,16-19` |
| container memory | `6g` |
| memory-swap | `≥12g` |
| guest RAM | `4G` |
| guest SMP | `4` |

---

## File map

| Path | Role |
|------|------|
| `docker/run-forge-vm.sh` | Host CLI: up / start-sonoma / ssh / vnc-host |
| `docker/start-sonoma-boot.sh` | **Only** safe QEMU boot path |
| `docker/start-display.sh` | Weston headless/intel |
| `docker/Dockerfile.macos-forge` | Image build |
| volume `forge-vm-data` | `/data` MacHDD + OpenCore-sonoma + serial |
| `tmp/evidence/` | SSH + screenshot proof |
| `tmp/VM_GOAL_STATUS.md` | PASS log |

---

## Quick status

```bash
./docker/run-forge-vm.sh status
./docker/run-forge-vm.sh ssh
docker exec forge-vm bash -c 'pgrep -af qemu-system | head -1'
```

---
# INDEX
# FORGE operator doc index

| Doc | Purpose |
|-----|---------|
| [MACOS_VM_ACCESS.md](MACOS_VM_ACCESS.md) | Launch, SSH, VNC, Sonoma contract |
| [FORGE_ENGINEERING_SPECIFICATION.md](FORGE_ENGINEERING_SPECIFICATION.md) | Product SoT — Mode 1 + Mode 2 iOS app |
| [../LAUNCH_GOAL.txt](../LAUNCH_GOAL.txt) | TV /goal paste product phase |
| [../AGENTS.md](../AGENTS.md) | Scope + DoD for god-loop-forge |
| Reports E2E | `/home/leviathan/Grok_Build/Reports/FORGE_MACOS_VM_20260730_E2E_FORENSIC_REPORT.md` |
| Failure log | `…/FORGE_MACOS_VM_20260730_FAILURE_DEBUG_LOG.md` |

## Skills / commands

| Trigger | Action |
|---------|--------|
| `/forge-macos-vm` or `/macos-vm` | Zero-bullshit VM up |
| Skill `forge-macos-vm` | Agent auto-invoke on launch macos language |
| `./docker/run-forge-vm.sh up` | Same without slash |
| `./scripts/deploy-to-vm.sh` | Sync host tree → guest `~/FORGE` |
| `/workflow god-loop-forge {…}` | Product god-loop |

## Access cheat

```
ssh -p 50922 user@127.0.0.1   # alpine
./docker/run-forge-vm.sh vnc-host && vncviewer 127.0.0.1:5901
```

---
# SKILL
---
name: forge-macos-vm
description: >
  Launch and operate the FORGE macOS Sonoma KVM container with zero theater.
  One command reattach, Haswell-noTSX Sonoma boot, SSH user/alpine :50922, host VNC :5901.
  Use when: launch macos vm, start forge-vm, forge macOS, docker-osx, Sonoma VM, reattach forge,
  vnc forge, ssh 50922, boot macos, start-sonoma, /forge-macos-vm, /macos-vm.
metadata:
  short-description: "Zero-bullshit forge-vm Sonoma launch + SSH/VNC"
---

# forge-macos-vm — zero-bullshit Sonoma launch

**Announce:** `Using forge-macos-vm skill` then execute. Do **not** re-debug Penryn/SSV install history unless `ps` shows wrong CPU or SSV loop returns.

## Absolute paths

| Item | Path |
|------|------|
| Project | `/home/leviathan/OPENCODE_WORKSPACE/FORGE` |
| CLI | `…/forge/docker/run-forge-vm.sh` |
| Boot | `…/forge/docker/start-sonoma-boot.sh` only |
| Access doc | `…/forge/docs/MACOS_VM_ACCESS.md` |
| Evidence | `…/forge/tmp/evidence/` |
| Volume | Docker `forge-vm-data` → container `/data` |
| Image | `macos-forge:master` |

## Credentials (live PASS 2026-07-30)

```
ssh -p 50922 user@127.0.0.1
password: alpine
guest: users-iMac-Pro.local · macOS 14.8.x Sonoma
```

## ONE command (always start here)

```bash
cd /home/leviathan/OPENCODE_WORKSPACE/FORGE
./docker/run-forge-vm.sh up
```

That: starts `forge-vm` if stopped, syncs scripts, runs **start-sonoma** only if no QEMU, prints access.

Wrappers (same thing):

```bash
./scripts/launch-macos-vm.sh
./scripts/launch-macos-vm.sh --vnc
```

## See GUI (host)

```bash
./docker/run-forge-vm.sh vnc-host
vncviewer 127.0.0.1:5901
# or remote-viewer vnc://127.0.0.1:5901
```

## SSH probe

```bash
./docker/run-forge-vm.sh ssh
# or: ssh -p 50922 user@127.0.0.1
```

## Sonoma contract (never violate)

| Must | Value |
|------|--------|
| CPU | **Force** `Haswell-noTSX` (never `${CPU:-…}` — image ENV is Penryn) |
| OpenCore | `OpenCore-sonoma.qcow2` + config-custom-sonoma.plist |
| GENERATE_UNIQUE | true → `/data/sonoma-serial.env` |
| Guest RAM | ≤4G |
| cpuset | `0-3,16-19` |
| QEMU count | exactly **1** |
| Volume wipe | **FORBIDDEN** after install |

Boot path only: `start-sonoma` / `start-sonoma-boot.sh`.  
**FORBIDDEN:** stock `start-qemu` as primary, Penryn Launch, SSV wait-theater, `docker volume rm forge-vm-data`.

## Agent procedure (when invoked)

1. `./docker/run-forge-vm.sh up` (cwd project root or abs path).  
2. `./docker/run-forge-vm.sh ssh` — require banner + shell or document login needed.  
3. Optional: `vnc-host` if operator wants GUI.  
4. If QEMU missing Haswell or n≠1: stop multi-QEMU, run `start-sonoma` once, recheck.  
5. If SSH fails but login desktop works: enable Remote Login via guest Terminal  
   `echo alpine | sudo -S /usr/sbin/systemsetup -f -setremotelogin on` and launchctl kickstart sshd.  
6. Do **not** reinstall macOS unless disk is gone or operator orders wipe.

## Deploy code into VM (for FORGE iOS build)

```bash
# Preferred (password auth; no ssh-agent key failures)
/home/leviathan/OPENCODE_WORKSPACE/FORGE/scripts/deploy-to-vm.sh
# Guest path: ~/FORGE
```

Do **not** use plain `scp -r` without `IdentitiesOnly=yes` / password — host keys cause "Too many authentication failures".

Xcode: guest may have `/usr/bin/xcodebuild` stub without Xcode.app — install full Xcode before iOS build PASS.

## References

- Full operator bible: `references/MACOS_VM_ACCESS.md` (copy of project docs)  
- Failure log: `Grok_Build/Reports/FORGE_MACOS_VM_20260730_FAILURE_DEBUG_LOG.md`  
- Upstream: https://github.com/sickcodes/Docker-OSX (Sonoma block)

## Slash

`/forge-macos-vm` · `/macos-vm` · automatic on “launch macos vm” / “start forge-vm”
