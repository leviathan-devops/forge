# FORENSIC REPORT: opencode serve Memory Catastrophe (2026-08-05/06)

**Author:** Hermes system-admin profile
**Date:** 2026-08-06
**Severity:** CRITICAL — single process consumed ~27 GB (90% of 30 GB RAM + swap), caused kernel-level full-stall, major device-wide lag
**Status:** Mitigated (process killed, 16 GB freed); root cause documented here

---

## 1. EXECUTIVE SUMMARY

A single `opencode serve` process (PID 3647685, `--port 8090 --hostname 0.0.0.0 --mdns`) ballooned to:

| Metric | Value |
|--------|-------|
| VmRSS (resident RAM) | 17.2 GB |
| VmSwap (paged out) | 8.8 GB |
| **Total footprint** | **~26-27 GB** |
| Threads | 671 |
| File descriptors | 1,395 |
| VmSize (virtual) | 116 GB |

The system has 30 GB RAM. This ONE process held ~90% of the device's memory budget,
forcing the kernel into permanent reclaim mode: `/proc/pressure/memory` `full avg10=30.23`
(any value > 2.0 = kernel stalling ALL processes; 30 is catastrophic). That stall was
the "major lag" the user experienced.

After SIGKILL: memory 29→13 GB used, swap 48→36 GB, `full avg10` 30.23→0.32, load 21→5.9.
Six user opencode sessions and all agent sessions survived — none were children of the serve.

---

## 2. TIMELINE

| Time | Event |
|------|-------|
| 2026-07-31 23:23 | serve process started (`opencode serve --port 8090 --hostname 0.0.0.0 --mdns`) |
| 2026-08-05 01:53 | process still running, 11.2 GB RSS (first observed) |
| 2026-08-05 ~20:00 | 16.7 GB RSS + 8.8 GB swap; 309 CLOSE-WAIT sockets to forge-vm (172.17.0.3) |
| 2026-08-05 20:02 | SIGTERM failed (D state); SIGKILL succeeded |
| 2026-08-05 20:05 | Memory freed: 29→13 GB used; pressure full avg10 30.23→0.32 |
| 2026-08-06 00:05 | Forensic analysis complete; no auto-respawn observed |

**Why SIGTERM failed:** process was in `D` (uninterruptible kernel sleep) state — blocked
on I/O (likely SQLite WAL writes against the 15 GB DB or socket teardown). Only SIGKILL works
on D-state processes stuck in kernel paths. Additionally, an `oc-firewall.service` exists that
installs kill-blocking wrappers for `pkill/kill/killall/pgrep/pidof` — it was INACTIVE at kill
time, but if ever enabled it would have blocked even the SIGKILL.

---

## 3. ROOT CAUSE — FOUR LAYERS

### Layer 1: The SQLite DB is pathologically bloated (15 GB)

```
opencode.db:              15 GB  (334,668 messages = 10.4 GB of message data)
storage/session_diff:     3.6 GB
storage (total):          3.6 GB
hive-mind:                650 MB
snapshot:                 376 MB
tool-output:              113 MB
─────────────────────────────────
~/.local/share/opencode:  20 GB total
```

**The smoking gun — single messages over 200 MB:**

| Message ID | Size | Content |
|------------|------|---------|
| msg_d82e1110... | **234.8 MB** | `role=user`, `summary.diffs` list of **244 MB** |
| msg_e6986ab5... | **208.1 MB** | `role=user`, summary.diffs |
| msg_e697b575... | **208.1 MB** | `role=user`, summary.diffs |
| msg_e1bcd86a... | **195.6 MB** | `role=user`, summary.diffs |
| msg_d831e5a6... | **165.5 MB** | `role=user`, summary.diffs |
| + 5 more > 140 MB | | |

These are **compaction summaries** — opencode's session-compaction feature writes the full
diff of everything changed in a session into a `summary.diffs` array stored inline in a
single message row. For long-running build/agent sessions, that diff list grows to hundreds
of MB. The DB also holds 1,430,702 `part` rows (streamed chunks), 9,845 sessions,
2,979 todos.

**Key numbers:**
- 334,668 messages × average ~31 KB = 10.4 GB
- The DB is 15 GB on disk; the serve process loads message/session data into memory on access
- `opencode.db-wal` (write-ahead log) was 15 MB at inspection — the DB is actively written

### Layer 2: The serve holds loaded session data in memory (JS object overhead)

`opencode serve` is a Bun/Node.js process. When any client (TUI, forge-vm, browser) requests
a session or the config, the server loads session/message data from SQLite into JS objects.

**Why this explodes:** JSON/JS object representation has 3-10× overhead over raw bytes.
A 10.4 GB raw DB becomes 25-30+ GB of live JS heap once loaded and retained. The serve
process never evicts loaded sessions — it keeps every session it has ever touched in memory.
With 9,845 sessions and 334K messages, the memory ceiling is effectively unbounded.

### Layer 3: forge-vm connection pileup (309 CLOSE-WAIT + 315 FIN-WAIT-2)

The forge-vm container (172.17.0.3) — the macOS VM running the iOS build — was repeatedly
connecting to the serve on port 8090. At kill time:

- **309 CLOSE-WAIT sockets** on the host side (server received FIN, never finished closing)
- **315 FIN-WAIT-2 connections** from the forge-vm side (client sent FIN, waiting for server)
- The opencode serve had **1,395 open file descriptors** — mostly these half-dead sockets

Each half-open socket retains kernel buffers + JS-side connection objects in the serve.
This is a classic server-side socket leak: a client (the VM) connects, the connection
dies or the client half-closes, and the server never reaps the socket. Over hours, hundreds
of these accumulate — each holding memory and preventing GC.

### Layer 4: 9 plugins loaded into the serve process

The serve loads the full plugin stack (config `plugin[]`):
superpowers, hive-mind, manta-agent, trident, shark-agent, spider-agent-v2.3,
vc-subagent, omni-vision, omni-canvas. Each plugin keeps its own module state,
event listeners, and — in the case of hive-mind (650 MB of shadow-agent data) —
substantial session bookkeeping in the same process.

---

## 4. WHY IS opencode NOT DATA-EFFICIENT BY DEFAULT?

This is the critical question for the forge app. The architectural reasons:

1. **Everything is one process.** `opencode serve` is a single Bun process holding the
   HTTP server + plugin runtime + session cache + SQLite client. There is no process
   isolation between "server" and "session data" — a bloated session cache bloats the
   whole server.

2. **Session data is loaded eagerly and retained indefinitely.** The server caches
   sessions/messages on access and never evicts. There is no LRU, no TTL, no
   "close session, free memory" path in the serve loop. Memory grows monotonically
   with sessions touched.

3. **Compaction writes giant diffs inline.** The `summary.diffs` mechanism stores
   entire session diff histories as one JSON blob in a message row. A 200+ MB single
   row is pathological — that one message, loaded into JS, costs 1-2+ GB of heap.

4. **No socket lifecycle management for half-closed connections.** 309 CLOSE-WAIT
   sockets show the server doesn't enforce socket timeouts/keepalives that would
   reap dead connections. Every VM connection attempt that dies leaks a socket + buffers.

5. **JS object overhead is inherent.** Bun/V8 JSON objects cost 3-10× their raw size.
   A 10 GB DB is 25-30+ GB of potential heap. Without explicit eviction, the process
   will always trend toward consuming all available memory.

6. **No memory limits, no watchdog.** The process had no rlimit, no cgroup limit,
   no OOM protection. Nothing stopped it from growing until the whole system stalled.

---

## 5. HOW TO RUN A LIGHTWEIGHT opencode SERVER (forge app guidance)

### Immediate operational mitigations (today)

1. **Run the serve with `--pure`** to skip ALL external plugins when the forge app
   doesn't need agent plugins:
   ```bash
   opencode serve --port 8090 --hostname 0.0.0.0 --mdns --pure
   ```
   This removes the 9-plugin memory tax from the server process.

2. **Don't bind 0.0.0.0 with mdns unless needed.** `--mdns` forces hostname to
   0.0.0.0 (all interfaces), widening the attack/connection surface. If only the
   forge-vm container needs it, bind to the docker bridge IP, or use the default
   127.0.0.1 and port-forward from the container explicitly.

3. **Add a hard memory cap + auto-restart watchdog:**
   ```bash
   # systemd unit with MemoryMax
   [Service]
   ExecStart=/usr/local/bin/opencode serve --port 8090 --hostname 127.0.0.1 --pure
   MemoryMax=4G
   MemoryHigh=3G
   Restart=on-failure
   RestartSec=10
   ```
   With `MemoryMax=4G`, systemd OOM-kills the serve at 4 GB instead of letting it
   eat the machine. `Restart=on-failure` brings it back clean.

4. **Periodically compact/prune the DB.** The 15 GB DB is the fuel. Options:
   - Archive old sessions (`session_share`/archive tooling, or prune sessions older
     than N days from `session` + `message` + `part`)
   - `VACUUM` after pruning to reclaim disk
   - The 200+ MB summary messages are the single highest-value cleanup target —
     deleting even 10 of them frees ~2 GB of DB + up to 10+ GB of potential heap

### Architectural recommendations for the forge app

1. **Run one serve per tenant/workspace with `--pure`**, not one giant shared serve.
   Separate processes = separate memory ceilings + crash isolation.

2. **Enforce a session cache eviction policy.** If forking/embedding opencode, add a
   cache wrapper that drops sessions > X MB or idle > Y minutes. Memory must be bounded.

3. **Cap session size at the source.** Long-running agent sessions that produce
   200 MB diff summaries should be split (new session per build phase) or their
   summaries truncated. A single message > 50 MB is a design smell.

4. **Socket hygiene.** Set TCP keepalive + connection timeout on the serve's HTTP
   server (server.keepAliveTimeout, server.requestTimeout in Node/Bun). Reap
   CLOSE-WAIT sockets: a watchdog that finds > 50 CLOSE-WAIT and restarts the serve.

5. **Measure, don't guess.** Add a memory watchdog (this Hermes profile can host one):
   alert at RSS > 6 GB, restart at > 8 GB. The system already has the
   `linux-resource-debugging` skill patterns for this.

6. **Never let a single process own the box.** systemd `MemoryMax` is non-negotiable
   for any long-running serve. Also set `TasksMax` to bound thread growth
   (671 threads is a thread leak — bound to e.g. 256).

---

## 6. WHAT WAS DONE / NOT DONE

**Done (with authorization):**
- Killed `display-battlefront` container (193% CPU — was compounding the issue)
- SIGKILL of opencode serve PID 3647685 (SIGTERM failed on D state)
- Verified all 6 user sessions + agent sessions survived
- Verified forge-vm active qemu (PID 2317040) untouched — iOS build safe

**Not done (requires user decision):**
- Did NOT restart forge-vm — the zombie qemu (PID 2141961) is a child of forge-vm's
  PID 1 and can only be reaped by a forge-vm restart (which would kill the active iOS
  build VM). Zombie burns 0 CPU/RAM; it will clear on next natural forge-vm restart.
- Did NOT prune the DB (15 GB) — destructive, needs explicit authorization + backup plan.
- Did NOT add the systemd MemoryMax unit — proposed above, needs user approval.

---

## 7. KEY FILES / DATA

| Path | Size | Notes |
|------|------|-------|
| `~/.local/share/opencode/opencode.db` | 15 GB | 334,668 msgs / 9,845 sessions / 1.43M parts |
| `~/.local/share/opencode/storage/session_diff` | 3.6 GB | diff storage |
| `~/.local/share/opencode/hive-mind` | 650 MB | shadow-agent state |
| `~/.config/opencode/opencode.json` | — | 9 plugins loaded into serve |
| `/etc/systemd/system/oc-firewall.service` | — | kill-blocking wrappers, currently INACTIVE |

---

## 8. RECOMMENDED NEXT STEPS (in priority order)

1. **Deploy the systemd `MemoryMax=4G` unit** for any future opencode serve
   (prevents recurrence — this is the single most important fix).
2. **Decide DB pruning strategy** for the 15 GB opencode.db (archive old sessions,
   delete 200+ MB summary messages, VACUUM).
3. **Add a memory watchdog cron** (Hermes can host): alert if any single process
   exceeds 8 GB RSS.
4. **Consider `--pure`** for forge-app servers that don't need agent plugins.
5. **On next forge-vm restart** (when iOS build completes), the zombie qemu and
   remaining CLOSE-WAIT sockets will clear naturally.

---

*End of report. Prepared by Hermes system-admin profile, 2026-08-06.*
