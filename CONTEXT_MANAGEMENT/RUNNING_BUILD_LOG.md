# RUNNING_BUILD_LOG — FORGE anchor (append-only, per work unit)

## [2026-09-10T–anchor-migration] — Authoritative anchor created
- WHAT: `git clone --local` live FORGE @ ce9ff28 + rsync of untracked control/product + symlinked bulk (tmp/Evidence/backups/OPENCODE_ACTIVE_PROJECTS/forge-tmp/node_modules) → `Shared Workspace Context/MIMOCODE/Forge` (3.4G vs 20G live).
- WHY: LIVE-vs-workspace ambiguity; every SHA/take/seal needed one referent.
- HOW: clone (hardlinked objects) + rsync excludes + symlinks; tracked-bulk mistake (4285 deletions) caught by status and fixed with real copies.
- EVIDENCE: bundle SHA `90279713` identical both trees; 71 Swift / 19677 lines; pytest 87 collected.
- NEXT: all wave work anchors here; live tree is reference + bulk host only.

## [2026-09-10T–SC-11-close] — Second-call 401 root-caused and fixed
- WHAT: migrate guard + paid-only lockdown (3 layers) + tripwire status marker.
- WHY: t76/t78 identical 200→401 shape across two keys demanded mechanism, not retry.
- HOW: length tripwires exonerated Keychain (67 chars both sides); dump showed free model post-relaunch → migrate culprit.
- EVIDENCE: t80 PASS 184s, 06 stills, mux 207.8s/543kbps; suite 88/88.
- NEXT: T-9 battery on the same rig.

## [2026-09-11T–F5-close] — Live-agent stdout proven on pixels
- WHAT: tight/connected take tiers, done-check signal, native watchdog, preview mount fix, AX container fix.
- WHY: t90-t93 showed spinner/blank/silence; DIAG proved 15-byte resolve in 15s; model skips python on multi-file prompts.
- HOW: split-leg prompts, stable-retry harness, sim-mutex, cools between takes.
- EVIDENCE: t121 PASS 224s (stdout 42/DONE ×3, gear rows, done banner, paid footer) + watcher PASS; t125 PASS 359s (stdout+preview, mux both gates) + watcher 2/2.
- NEXT: soak numerics, seal, device handoffs.

## [2026-09-11T–air-drop-push] — GitHub continuity for the Air
- WHAT: orphan `air-drop` branch (product tree only) pushed after redacting 2 committed secrets (Apple-ID pw, PAT) that push-protection named.
- WHY: master push dies (3.5GB pack, HTTP 500s); Air needs full history-free tree.
- HOW: orphan + staged paths only; ancestry-checked secrets never reached GitHub; API-verified (FORGEApp.swift + handoff present).
- EVIDENCE: branch live; suite 88/88; AGENT_MACBOOK_AIR.md contract in-tree.
- NEXT: Air clones air-drop, compiles, signs, runs; VM stays test rig.
