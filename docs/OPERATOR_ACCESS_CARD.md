# FORGE macOS VM — Operator access (agent-first)

**Updated:** 2026-07-31  
**Goal:** Agent can work cleanly over SSH; you only use VNC for GUI auth (Apple ID, license, MiniBuddy).

---

## Credentials (verified)

| Surface | Value |
|---------|--------|
| **SSH (agent path)** | `ssh -p 50922 user@127.0.0.1` |
| **Local macOS user** | **`user`** |
| **Local macOS password** | **`alpine`** (verified working on SSH) |
| **VNC** | No password — `vncviewer 127.0.0.1:5901` |
| **Apple ID (if macOS asks)** | `copyresearch111@gmail.com` + the password you set for that Apple ID (not the same as local `alpine` unless you made them match) |

> Local login is still **`user` / `alpine`**.
> The Apple-ID password is operator-held (never stored here) — type it when the GUI asks for Apple credentials.

---

## Agent path (clean — preferred)

```bash
ssh -p 50922 user@127.0.0.1   # alpine
# Toolchain already green:
xcodebuild -version            # Xcode 26.6
cd ~/FORGE && ls
```

Agents should **not** depend on VNC for builds. SSH is the ship path.

---

## Human path (auth / GUI only)

```bash
cd /home/leviathan/OPENCODE_WORKSPACE/FORGE
./docker/run-forge-vm.sh vnc-host
./scripts/launch-vnc-fast.sh full    # better than raw vncviewer
# Login: user / alpine
# Complete any Continue / Apple ID prompts
```

**Expect lag.** This is QEMU + VNC of Tahoe, not a real Mac. For auth clicks only, lag is annoying but usable; for daily use, use SSH.

---

## Why it feels “2007 bootleg”

| Reality | Why |
|---------|-----|
| Nested KVM + VNC | Every pixel is remote-streamed |
| 6 GB / 8 vCPU | Host is shared; not a full Mac |
| `-vga vmware` | Only stable path (svga went pure black) |
| 1920×1080 | Heavy stream; fit-to-screen is client-side scale |

That is **expected** for Docker-OSX. Agent value is **SSH + xcodebuild**, not buttery GUI.

---

## Status snapshot

- Guest OS: macOS **26.6** Tahoe  
- Xcode: **26.6** (17F113) installed  
- Boot: `start-tahoe` · **Haswell-noTSX** · **OpenCore-tahoe** · **n=1** · **`-m 6000`** (sim-proof profile)  
- QEMU contract log: `tmp/w1_qemu_contract.txt`  
- Container VNC proof: `tmp/evidence/xcode/container-vnc-test.txt` **PASS**  
- **Do not** use `FORGE_GUEST_RAM=4` for sim proof waves

---

## If VNC is 1 FPS / unusable (2026-07-31)

**Root cause on this machine (measured):** host load average **~17**, including:
- Kronos fine-tune `finetune_v11.py` at **~99% CPU**
- Multiple OpenCode sessions + forge QEMU (~50% CPU)
- **30 GiB swap in use**

VNC cannot be smooth under that. Guest is locked to **single mode 1920×1080** (VMware VGA only offers that).

### What to do for 10 minutes of usable GUI auth
1. **Pause** Kronos / heavy training:  
   `pkill -STOP -f finetune_v11.py`   (resume later: `pkill -CONT -f finetune_v11.py`)
2. Close extra OpenCode / browser containers you don’t need.
3. Connect with:  
   `./scripts/vnc-emergency.sh`  
   Login: **user / alpine**
4. Click **Continue** on MiniBuddy; do Apple ID if prompted.

### Agents do not need VNC
```bash
ssh -p 50922 user@127.0.0.1   # alpine
xcodebuild -version
```

---

## QEMU contract (assert every sim/proof wave)

| Check | Required |
|-------|----------|
| **n** live `qemu-system-x86_64` | **1** (zombies OK to reap; multi-live FAIL) |
| CPU | **Haswell-noTSX** (never Penryn / image ENV default) |
| OpenCore | **OpenCore-tahoe.qcow2** |
| Guest RAM (sim proof) | **≥6G** (`-m 6000`) |

**FORBIDDEN for sim / CoreSimulator proof waves:** `FORGE_GUEST_RAM=4`  
Agent-light 4G leaves macOS with &lt;4 GB free → `simctl boot` fails (“insufficient system memory”).  
Evidence: `tmp/evidence/full-verify/sim-residual.txt` · live assert: `tmp/w1_qemu_contract.txt`

```bash
# Assert live contract (pid + cmdline)
docker exec forge-vm bash -c 'for p in /proc/[0-9]*; do c=$(cat $p/comm 2>/dev/null); case $c in qemu-system-x86*) s=$(awk "{print \$3}" $p/stat); [ "$s" = Z ] && continue; echo PID=${p#/proc/}; tr "\0" " " < $p/cmdline; echo; esac; done'
# Expect: n=1 · Haswell-noTSX · OpenCore-tahoe · -m 6000
```

### Profiles

| Profile | RAM/SMP | When |
|---------|---------|------|
| **Sim / xcodebuild proof (default for DoD)** | **FORGE_GUEST_RAM=6** SMP=4 | CoreSimulator, Gate C/D, full-verify |
| Agent-light (SSH-only, **no sim**) | RAM=4 SMP=4 | Hygiene / idle SSH only — **not** sim proof |
| Heavy GUI auth | RAM=6 SMP=8 + `FORGE_NEED_DISPLAY=1` | Human VNC Apple ID / MiniBuddy |

```bash
# Reap zombies + reboot (volume kept). For sim work, force 6G:
FORGE_GUEST_RAM=6 FORGE_GUEST_SMP=4 ./scripts/forge-vm-hygiene.sh
# or:
FORGE_GUEST_RAM=6 FORGE_GUEST_SMP=4 ./docker/run-forge-vm.sh hygiene

# Sim-proof boot:
FORGE_GUEST_RAM=6 FORGE_GUEST_SMP=4 ./docker/run-forge-vm.sh start-tahoe

# Heavy GUI session only when needed:
FORGE_NEED_DISPLAY=1 FORGE_GUEST_RAM=6 FORGE_GUEST_SMP=8 ./docker/run-forge-vm.sh start-tahoe
```
