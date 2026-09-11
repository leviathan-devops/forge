# FORGE TV Launch Prompt — copy-paste into Grok TUI

**Use block B (TV / walk-away).** Paste after `cd /home/leviathan/Grok_Build` / open Grok Build TUI.

---

## A) One-cycle (watch / debug)

```text
/workflow god-loop {"target":"/home/leviathan/OPENCODE_WORKSPACE/FORGE"}
```

---

## B) TV / walk-away (default — sleep / leave)

```text
/goal Drive God Loop PASS for target:
/home/leviathan/OPENCODE_WORKSPACE/FORGE

EXECUTION RULE (mandatory):
- All implementation work MUST go through workflow god-loop.
- Each round: /workflow god-loop {"target":"/home/leviathan/OPENCODE_WORKSPACE/FORGE"}
- If complete status is LOOP → immediately re-run the same workflow (state under target).
- Do NOT freestyle multi-hour coding outside workflow phases.
- Outer /goal ends only when the workflow returns PASS.

SPEC / ACCEPTANCE (what AUDIT/VERIFY/smoke must make true):
/home/leviathan/OPENCODE_WORKSPACE/FORGE/docs/GOD_LOOP_ACCEPTANCE.md

MISSION (operator intent — not freestyle scope creep):
1) macOS Sonoma VM working in Docker-OSX with Weston (container-virtual-display skill: WESTON_BACKEND=headless OR intel; NEVER NVIDIA).
2) Master image macos-forge:master fully baked (docker/Dockerfile.macos-forge) so containers need NO multi-hour package installs.
3) Build/test FORGE Swift iOS app in that VM (xcodegen + xcodebuild simulator).
4) Debug until functional UI/UX: dual-mode launch (Build On-Device + Mission Control), SwiftTerm path, no ship-blockers.
5) Battle-ready ship bar: usable coding agent on iPhone with Trident-in-opencode TUI per FORGE engineering spec; Mission Control path for remote OpenCode piloting.
6) Evidence: SSH :50922, sim screenshots, build logs, filled acceptance checklist. After PASS: skill generate-build-report → Grok_Build/Reports/.

LIVE HOST TRUTH (start here — do not invent green state):
- Project: /home/leviathan/OPENCODE_WORKSPACE/FORGE (origin leviathan-devops/forge)
- Skill: ~/.grok/skills/container-virtual-display (and Grok_Build/.grok/skills/…) headless|intel
- Image to build/use: macos-forge:master from docker/Dockerfile.macos-forge (retag macos-forge:weston if needed)
- Existing forge-vm may be MISWIRED (no KVM, no /data mount, nvidia runtime, disks in writable layer). RESCUE BaseSystem to volume forge-vm-data BEFORE docker rm.
- Host has Docker + /dev/kvm + Intel DRI card2/renderD129; QEMU/OpenCore live inside docker-osx base (not required on host).
- Handover: context_management/19_COMPREHENSIVE_HANDOVER_MACOS_VM.md
- Spec read-only ref: /home/leviathan/OPENCODE_WORKSPACE/FORGE_ENGINEERING_SPECIFICATION.md
- Host launcher: docker/run-forge-vm.sh

CONSTRAINTS:
- Writes under /home/leviathan/Grok_Build and ~/.grok only.
- Never write OPENCODE_WORKSPACE (read-only reference OK).
- Never disable SIP/AMFI/SSV; never restart QEMU mid-SSV; never format disk0.
- Never pass NVIDIA DRI or runtime=nvidia to forge-vm (training GPU).
- Volume at /data only — never hide /home/arch/OSX-KVM.
- Prefer stock Launch.sh + apply-launch-patches.sh; start-qemu.sh is thin wrapper only.
- Guest input: keyboard/sendkey only.
- Resource pin: --cpuset-cpus=0-1,16 --memory=6g; guest RAM=4 SMP=2 CORES=2.
- No trident-container-test on Arch.
- Autonomous. Prefer Aether recall/working_set for continuity after compact.
- Kill only true stale FORGE leftovers after volume rescue; do not kill unrelated parallel build containers without cause.

Stop only on workflow PASS + short verify steps in the final message (SSH proof, sim screenshots, acceptance gates A–E).
```

---

## C) Ops one-liners

```text
/workflows
```

```text
/workflow stop <display-name>
```

Rebuild master image only (manual host, not a substitute for god-loop):

```bash
cd /home/leviathan/OPENCODE_WORKSPACE/FORGE/docker
docker build -t macos-forge:master -f Dockerfile.macos-forge .
docker tag macos-forge:master macos-forge:weston
./run-forge-vm.sh recreate
```

---

## Dashboard

- Workflow: `god-loop`  
- Target: `/home/leviathan/OPENCODE_WORKSPACE/FORGE`  
- DoD: `docs/GOD_LOOP_ACCEPTANCE.md`  
