# POST-COMPACTION RECOVERY PROMPT — FORGE iOS Build

**Last Updated:** 2026-07-27 Wave 7

## YOU ARE BUILDING FORGE

FORGE is an iOS app that runs opencode with Trident as the sole agent on an iPhone.
The app is REAL — it compiles, builds, and renders in the iOS Simulator. CI is GREEN.

## IMMEDIATE RECOVERY STEPS

1. Read `01_COMPACTION_SURVIVAL.md` for full context
2. Read `03_TASK_QUEUE.md` for prioritized tasks
3. Read `17_MACOS_VM_OPERATING_MANUAL.md` for VM setup guide

## THE #1 BLOCKER

macOS Sonoma kernel gets STUCK in verbose boot inside QEMU/Docker.
You need a working macOS VM to test the iOS app visually.

**Fix to try FIRST:** Download macOS Ventura (option 6 in fetch script) instead of Sonoma (option 7). Ventura is older and more QEMU-compatible.

**Fix to try SECOND:** Use `-cpu host` instead of `-cpu Penryn,...` for CPU passthrough.

**Fix to try THIRD:** Increase RAM from `-m 7192` to `-m 8192` or higher.

## THE WORKING macOS VM TOOLKIT (verified)

```bash
# Screenshot (from host):
vncsnapshot -quiet localhost:0 /tmp/snap.jpg

# Keyboard (from INSIDE container via docker exec):
docker exec forge-vm python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('127.0.0.1', 4444))
time.sleep(0.5); s.recv(4096)
s.send(b'sendkey ret\n')
time.sleep(0.5); s.close()
"

# Check if QEMU is alive:
docker exec forge-vm pgrep -c qemu

# Check if VNC is accessible:
nc -z -w3 localhost 5900
```

## KEY FACTS (DO NOT REDISCOVER)

- SwiftTerm version: **1.15.0** (NOT 2.0.0)
- Always use **SwiftUI.Color** (never bare Color)
- SwiftTerm.Color takes **UInt16** (raw hex values)
- TerminalView **IS** a UIScrollView
- swift-libgit2 needs **Swift 6.1** (removed, ForgeGitManager stubbed)
- **No FORGE symlink** in project dir
- CI runner: **macos-14 M1, Xcode 16.2**
- Push to **master** branch
- GitHub auth: `gh auth status` → leviathan-devops
- macOS VM keyboard: **sendkey** via QEMU monitor (NOT VNC key events)
- macOS VM screenshots: **vncsnapshot** (NOT scrot/vncdotool/grim)
- macOS VM monitor: Port 4444 INSIDE container only
- macOS VM: VNC on localhost:5900, monitor on container 127.0.0.1:4444

## WHAT "DONE" MEANS

1. ✅ App builds on CI (ACHIEVED — 9+ successes)
2. ✅ App renders in Simulator (ACHIEVED — launch menu confirmed)
3. ❌ macOS VM fully working (BLOCKED — kernel stuck)
4. ❌ FORGE tested in macOS VM iOS Simulator
5. ❌ Full opencode+Trident bundle (Phase 2)
6. ❌ TestFlight submission (needs Apple Developer account)
7. ❌ App Store review submission

## SUBAGENT RULES

- Use subagents for 90% of work
- Direct execution ONLY for: auditing, surgical fixes, context docs, container testing
- After EVERY wave: update ALL docs in context_management/
- macOS VM work should be done DIRECTLY (not subagent) — requires real-time monitoring
