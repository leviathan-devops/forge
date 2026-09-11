# FIX PLAN v3 — Serve-per-Workspace: the 12-parallel model, made durable

**Status:** PLAN ONLY — no edits made.
**Supersedes:** v2 (single-serve hardening — now the fallback, not the primary).
**The operator's own evidence:** "I have like 12 parallel opencodes right now and
never have any issues with it." That IS the correct architecture. This plan
replicates it for the serve.

---

## 0. WHY THE 12 PARALLEL OPENCODES NEVER LEAK (the model to copy)

Every opencode instance you run is its own process bound to its own workspace:
- Memory = that workspace's active working set (bounded by the work, not by history)
- When you close one, the **OS reclaims 100% of its memory** — process death is
  the perfect eviction: zero retention, zero fragmentation, zero watchdogs needed
- Each process only touches its own workspace's sessions — it can never accumulate
  the global 9,845-session history
- They all share the one SQLite DB safely (multi-process WAL access — proven daily)

The 27 GB catastrophe came from the ONE process that was the opposite: a single
long-lived daemon that (a) touched every workspace's sessions and (b) never died.
**Fix = stop running a universal daemon. Run serves the way you run opencodes:
one per workspace, spawned on demand, exited when idle.**

---

## 1. THE ARCHITECTURE

```
┌─ Supervisor (systemd template + registry) ─────────────────────────────┐
│  workspace A → opencode-serve@A.service  (port 8090, cwd=/ws/A)        │
│  workspace B → opencode-serve@B.service  (port 8091, cwd=/ws/B)        │
│  workspace C → opencode-serve@C.service  (port 8092, cwd=/ws/C)        │
│  … one per workspace, ALL with the SAME flags/features/lifecycle       │
└─────────────────────────────────────────────────────────────────────────┘
        │ mDNS _opencode._tcp (name = workspace)      │ aggregate
        ▼                                            ▼
   FORGE MC app ── discovers ALL serves ──► one unified session list
        (multi-server plumbing ALREADY EXISTS: savedServers, discovery,
         mergeSessions per server, per-server RemoteSession, server.name
         on every card)
```

### Why this is "functionally exactly the same" for every server

| Property | Per-workspace serve | The 12 parallel opencodes |
|---|---|---|
| Process per workspace | ✅ | ✅ |
| Same opencode, same flags, same features | ✅ | ✅ |
| Memory = workspace working set | ✅ | ✅ |
| OS reclaims on exit | ✅ (idle-exit) | ✅ (you close them) |
| Never touches other workspaces' sessions | ✅ (cwd-bound + directory filter) | ✅ |
| Shared global SQLite, multi-process safe | ✅ (proven by your 12) | ✅ |
| App treats them uniformly | ✅ (one discovery + one aggregate) | n/a |

### Verified server capabilities that make this work (from /doc spec)

- `GET /session` params: **`directory`, `workspace`, `scope`, `path`, `roots`, `limit`** —
  a serve can list ONLY its workspace's sessions.
- `GET /session/{id}/message` params: **`limit`, `before`** — the app can fetch
  the LAST N messages instead of a 96 MB transcript. (NOTE: an earlier live probe
  of `?limit=5` returned an error envelope — pagination must be re-verified against
  a live serve with the exact param names before relying on it. Fallback = the
  existing >20 MB client guard.)
- Sessions carry `directory` — the app can route a session to its owning serve.

---

## 2. IMPLEMENTATION

### 2.1 The supervisor (systemd template + port registry)

```ini
# /etc/systemd/system/opencode-serve@.service  (%i = workspace path, escaped)
[Unit]
Description=opencode serve for workspace %i
After=network-online.target

[Service]
# Run FROM the workspace: the serve is cwd-bound, exactly like a TUI you open
# in that directory.
WorkingDirectory=%i
# Port from the registry: /etc/opencode/serves.conf maps workspace→port.
# The wrapper below reads it and execs the serve.
ExecStart=/usr/local/lib/opencode/run-serve.sh %i
Environment=NODE_OPTIONS=--max-old-space-size=3072
MemoryMax=4G
MemoryHigh=3G
TasksMax=128
Restart=on-failure
RestartSec=5
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
```

```bash
#!/bin/bash
# /usr/local/lib/opencode/run-serve.sh — per-workspace serve launcher
WS="$1"
PORT=$(grep -F "$WS" /etc/opencode/serves.conf | cut -d: -f2)   # e.g. 8090..8110
exec opencode serve --port "$PORT" --hostname 0.0.0.0 --mdns \
     --mdns-domain "opencode-$(basename "$WS").local"
```
- `serves.conf`: `workspace:port` lines, one per workspace. Deterministic,
  operator-maintained (the app ALSO lists them in its saved-servers UI — the
  Add Server form already exists).
- Same flags for every workspace = "functionally exactly the same".

### 2.2 Idle-exit companion (the OS-reclaim trigger — the whole point)

```bash
#!/bin/bash
# /usr/local/lib/opencode/idle-watch.sh — run every 2 min for each unit
# If a workspace's serve has had NO connections for 10 minutes, stop it →
# the OS frees 100% of its memory (the 12-parallel eviction, automated).
PORT=$(grep -F "$1" /etc/opencode/serves.conf | cut -d: -f2)
ACTIVE=$(ss -tn sport = :$PORT state established | wc -l)
if [ "$ACTIVE" -eq 0 ]; then
  AGE=$(stat -c %Y /proc/$(systemctl show -p MainPID --value "opencode-serve@$1")/comm 2>/dev/null)
  NOW=$(date +%s)
  [ $((NOW - AGE)) -gt 600 ] && systemctl stop "opencode-serve@$1"
fi
```
- Access pattern: user opens MC → serve for that workspace starts (on-demand via
  `systemctl start` when the app pings a dead port — see 2.3) → user works →
  idle 10 min → stopped → memory reclaimed. Exactly like closing a TUI.
- Spawn-on-demand: the app pings the port; if refused, `systemctl start` (or the
  app's "connect" just works after the supervisor auto-starts on first request —
  systemd `Restart=on-failure` + a socket-activated port would make this seamless:
  systemd socket units per workspace port that pull in the serve unit).

### 2.3 App changes (all small, most already exist)

| # | Change | Status |
|---|---|---|
| 1 | Use `GET /session?directory=<ws>` per discovered serve | plumbing exists (per-server refresh); add the directory param |
| 2 | Use `GET /session/{id}/message?limit=20&before=<cursor>` for chat/eagle fetches | NEW — replaces the >20 MB guard with real pagination (verify param shape on a live serve first) |
| 3 | Poller consolidation: ONE shared `ServePoller` per screen, 8 s cadence, backoff 8→60 s, pause on background | v2 plan — still applies |
| 4 | Socket timeouts (`timeoutIntervalForRequest=10`, resource=30), `httpMaximumConnectionsPerHost=4` | v2 plan — still applies |
| 5 | Discovery already lists every mDNS serve; session cards already show `server.name` — the aggregate view is DONE | ✅ existing |
| 6 | On-demand start: when a saved/discovered server's port is closed, ping → supervisor starts the unit | NEW (small) |

### 2.4 Per-workspace memory safety (belt & braces on top of the model)

- Each unit: `MemoryMax=4G` + V8 heap cap 3.5 G. A workspace's serve with a few
  active sessions uses well under 1 G; 4 G is generous headroom.
- Watchdog per unit: RSS > 3 G → restart (lossless — SQLite is the truth).
- The box's total = Σ(workspace working sets) — exactly what the 12-parallel
  model already sustains daily.

### 2.5 Data (archival, not destruction — per owning workspace)

- The 10 giant (140–234 MB) `summary.diffs` messages belong to specific
  workspaces. For each owning workspace: backup global DB → archive those
  messages to `opencode-archive.db` (sidecar) → remove from hot DB → VACUUM.
  History preserved; the owning serve can never load a 234 MB blob again.
- Compaction cap going forward (config `compaction` freeform — set the documented
  cap if this version supports one; else the app guidance: split long builds per
  phase).
- Old-session archival (90 d) to the sidecar = OPTIONAL, speed-only. Memory is
  already handled by the process model.

### 2.6 The current 8090 serve

- Either becomes the "host workspace" unit (cwd = OPENCODE_WORKSPACE) under the
  same template, or is retired in favor of the per-workspace units.
- The app's saved-servers list + Add Server form can hold ANY mix of serves —
  no app change needed to point at new ports.

---

## 3. WHY THIS CANNOT REPEAT THE CATASTROPHE

| Former failure | Killed by |
|---|---|
| One process accumulates all 9,845 sessions | Per-workspace processes each see only their own workspace (cwd + directory filter) |
| Retention never evicted | Idle-exit → OS reclaims 100% (the proven 12-parallel mechanism) |
| One 234 MB message balloons the heap | Archived to sidecar; compaction capped |
| 96 MB transcript fetches | `limit`+`before` pagination (or the >20 MB guard as fallback) |
| 309 CLOSE-WAIT sockets | App timeouts + kernel keepalive/fin_timeout + per-unit restart |
| No ceiling | MemoryMax=4G per unit (system total = Σ workspace sets, bounded by count) |
| Thread explosion | TasksMax=128 per unit |

---

## 4. EXECUTION ORDER

| # | Action | Risk | When |
|---|---|---|---|
| 1 | `serves.conf` registry + `run-serve.sh` + systemd template unit | none (new units) | IMMEDIATELY |
| 2 | Idle-exit companion cron | none | IMMEDIATELY |
| 3 | Verify pagination (`limit`/`before`) on a live serve; implement in app | code (app) | NEXT BUILD PASS |
| 4 | App: shared poller + timeouts + directory filter + on-demand start | code (app) | NEXT BUILD PASS |
| 5 | DB backup + integrity check | none | BEFORE ANY ARCHIVAL |
| 6 | Archive the 10 giant summary messages (per owning workspace) + VACUUM | low (post-backup) | THIS WEEK |
| 7 | Compaction cap + long-session split guidance | low | THIS WEEK |
| 8 | (Optional) old-session archival 90 d — speed only | medium | OPERATOR CHOICE |
| 9 | Retire or re-home the current 8090 serve | low | WITH 1 |

## VERIFICATION (after 1–2)

- N serves running for N workspaces, all with identical flags/features
- MC shows ONE aggregated session list across all serves (server names on cards)
- Enter a session → routes to its workspace's serve; chat loads (paginated)
- Eagle cards show live streams per workspace
- Idle 10 min → serve stops → RSS of that unit = 0 (OS reclaimed)
- Re-open MC → session list identical (SQLite survived the exit)
- Box pressure: full avg10 < 1.0 with all serves active

## OPERATOR DECISIONS REQUIRED

1. **Workspace list** for the registry: which directories get serves (default:
   every distinct `directory` in the session DB)?
2. **Idle-exit window**: 10 min? 30? (Shorter = tighter memory; longer = faster
   re-open.)
3. **Approve backup + ARCHIVAL (not deletion) of the 10 giant summary messages?**
4. **Current 8090 serve**: re-home as the host-workspace unit, or retire?

*No edits made. v2's single-serve hardening remains the fallback if a workspace
ever needs a persistent daemon; v3's per-workspace model is the primary answer and
it is literally the operator's own proven pattern, automated.*
