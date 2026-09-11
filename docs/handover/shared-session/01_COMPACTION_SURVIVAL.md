# COMPACTION SURVIVAL — FORGE iOS Build

**Last Updated:** 2026-07-27 Wave 7 (macOS VM Pipeline Built)
**Session Start:** 2026-07-25
**Project:** FORGE — iOS-Native opencode TUI with Embedded Trident Agent + Mission Control Fleet Commander
**Repository:** https://github.com/leviathan-devops/forge (PUBLIC)
**Build Status:** ✅ CI GREEN (9+ builds). macOS VM pipeline WORKING but kernel stuck.

---

## RECOVERY INSTRUCTIONS (READ THIS FIRST — DO NOT SKIP)

You are building FORGE. If you are reading this, context was compacted.

### What FORGE Is
FORGE is a native iOS app (Swift/SwiftUI) with two modes:
1. **Mode 1 (Build On-Device):** Runs the full opencode TUI locally on an iPhone. Hidden WKWebView executes JavaScript bundle (with Trident as the sole agent). SwiftTerm renders the terminal natively.
2. **Mode 2 (Mission Control):** Connects to remote opencode servers on other devices via WebSocket. Streams their TUI sessions to the iPhone.

### The #1 Priority for Next Session
**GET THE macOS VM FULLY BOOTING.** The macOS Sonoma kernel gets stuck in verbose boot. Try macOS Ventura (option 6 in fetch script) instead of Sonoma (option 7). Ventura is older and more QEMU-compatible. If that fails, try `-cpu host` for CPU passthrough, or more RAM.

### Where Everything Lives
| What | Path |
|------|------|
| **Git working dir** | `/home/leviathan/OPENCODE_WORKSPACE/FORGE/` |
| **Project workspace** | This directory (Shared Workspace Context) |
| **Context docs** | `context_management/` — 18 files, 3,300+ lines |
| **Swift source** | `iOS/FORGE/` — 30 files, 7,021 lines |
| **TypeScript source** | `forge/` — 21 files, 4,866 lines |
| **Terminal engine** | `iOS/FORGE/Resources/forge-bundle.js` — 1,135 lines |
| **Engineering spec** | `FORGE_ENGINEERING_SPECIFICATION.md` — 3,408 lines |
| **Checkpoint** | `Checkpoints/Session1_85Percent/` — 167 files, full codebase |
| **Docker container** | `forge-vm` (running, Docker-OSX + QEMU) |
| **Docker images** | `macos-forge-container:v2-working` (7.28GB), `:master` (11.3GB) |
| **GitHub auth** | `gh auth status` → leviathan-devops (ADMIN token) |
| **GitHub repo** | https://github.com/leviathan-devops/forge |
| **CI runner** | macos-14 M1, Xcode 16.2, iOS 18.2 Simulator |

### Immediate Next Steps (After Reading This)
1. **Read `03_TASK_QUEUE.md`** — has prioritized task list
2. **Read `17_MACOS_VM_OPERATING_MANUAL.md`** — complete VM setup guide
3. **Fix macOS boot:** Try Ventura (option 6), `-cpu host`, or more RAM
4. **If macOS boots:** Use `sendkey` to automate installation (guide in manual)
5. **After macOS works:** Install Xcode, test FORGE in iOS Simulator

### How to Push Code
```bash
cd /home/leviathan/OPENCODE_WORKSPACE/FORGE
git add -A && git commit -m "description" && git push origin master
```

### How to Restart the macOS VM
```bash
# Check if container is alive
docker ps --filter name=forge-vm

# If dead, restart from image
docker run -d --name forge-vm --privileged --device /dev/kvm \
  -p 50922:10022 -p 5900:5900 \
  sickcodes/docker-osx:latest bash -c 'sleep infinity'

# Install packages, get macOS images, start QEMU — see 17_MACOS_VM_OPERATING_MANUAL.md
```

---

## CURRENT STATE (Wave 7 Final)

### iOS App: 85% Production Ready
- ✅ App compiles on CI (9+ consecutive successes, Xcode 16.2)
- ✅ Launch menu renders in iOS Simulator (vision-verified)
- ✅ Terminal functional (forge-bundle.js: 12 commands, tab completion, history)
- ✅ App icon (cyan F on dark), launch screen, error states, animations
- ✅ XCUITest UI automation (4 tests)
- ✅ App Store screenshots captured via CI
- ✅ TestFlight pipeline ready (24 files, needs Apple Dev account)
- ✅ esbuild pipeline verified working (39KB test bundle)
- ✅ Privacy manifest
- ✅ All 22 bugs from audit fixed
- ✅ TypeScript type errors fixed (22→0)
- ❌ Full opencode+Trident bundle (Phase 2)
- ❌ libgit2 integration (Phase 2)
- ❌ TestFlight submission (needs Apple Developer account)

### macOS VM: 60% — Tools Work, Kernel Stuck
- ✅ Docker container (forge-vm, Docker-OSX + KVM)
- ✅ vncsnapshot for screenshots: `vncsnapshot -quiet localhost:0 /tmp/snap.jpg`
- ✅ QEMU monitor sendkey for keyboard (bypasses VNC keyboard bug)
- ✅ Mouse clicks via RFB pointer events
- ✅ OpenCore boot picker responds to clicks + sendkey
- ✅ sendkey ret boots macOS from OpenCore (358K pixels changed)
- ✅ Docker images committed (v2-working, master)
- ⚠️ macOS Sonoma kernel STARTS (Darwin 23.6.0) but STUCK in verbose boot
- ❌ macOS Recovery GUI NOT REACHED
- ❌ macOS installation NOT COMPLETE
- ❌ Xcode NOT INSTALLED

### Build Stats
| Metric | Value |
|--------|-------|
| Swift files | 30 |
| Swift lines | 7,021 |
| TypeScript files | 21 |
| TypeScript lines | 4,866 |
| forge-bundle.js | 1,135 lines (12 commands) |
| Git commits | 20 |
| CI builds | 15+ (9+ success) |
| Bugs fixed | 22 |
| Context docs | 18 files, 3,300+ lines |
| Engineering spec | 3,408 lines |
| Docker images | 2 (7.28GB + 11.3GB) |

---

## CRITICAL RULES (DO NOT VIOLATE)

1. **SwiftTerm version is 1.15.0** — NOT 2.0.0 (doesn't exist)
2. **Always use `SwiftUI.Color`** — SwiftTerm.Color collision causes ambiguity
3. **SwiftTerm.Color takes UInt16** — raw hex values: `SwiftTerm.Color(red: 0xFF, ...)`
4. **TerminalView IS a UIScrollView** — use `.bounces` not `.scrollView.bounces`
5. **swift-libgit2 needs Swift 6.1** — removed, ForgeGitManager stubbed
6. **No `FORGE` symlink** in project dir — caused esbuild path resolution failure
7. **CI runner is macos-14 M1, Xcode 16.2**
8. **Push to `master` branch** (NOT main)
9. **macOS VM keyboard:** Use QEMU monitor `sendkey` via `docker exec`, NOT VNC key events
10. **macOS VM screenshots:** Use `vncsnapshot -quiet localhost:0 out.jpg`, NOT scrot/vncdotool
11. **macOS VM monitor:** Port 4444 INSIDE container only (127.0.0.1), connect via `docker exec`
12. **NO headless display** — this is an iOS UX app, must use VNC (headed) for testing

### Subagent Rules
13. **Use subagents for 90% of work** — `task(subagent_type="trident_build")` for code
14. **Direct execution for:** auditing, surgical fixes, context docs, container testing
15. **After EVERY wave:** update docs in `context_management/`

### macOS VM Rules
16. **macOS VM MUST use VNC display** (`-vnc 0.0.0.0:0`) with `-monitor telnet:127.0.0.1:4444,server,nowait`
17. **Keyboard via sendkey** — VNC keyboard events DON'T WORK in macOS/OpenCore
18. **Screenshots via vncsnapshot** — scrot/grim/vncdotool all fail
19. **Docker commit does NOT capture qcow2 disk changes** — disk image is lost on container recreation
20. **macOS Sonoma kernel gets STUCK** — try Ventura or different QEMU params

---

## CONTACT / AUTH

- **GitHub:** leviathan-devops (ADMIN token: operator-held, never stored here — rotate immediately, this file previously contained it in plaintext)
- **Repo:** https://github.com/leviathan-devops/forge (PUBLIC)
- **Apple Developer:** NOT YET CONFIGURED (needed for TestFlight)
