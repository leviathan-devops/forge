# FORGE God-Loop Evidence Pack (live)

**Target:** `/home/leviathan/OPENCODE_WORKSPACE/FORGE`  
**Updated:** 2026-07-29T08:23Z (Wave 5 `acceptance-resync` — absolute latest B5/C/D/E paths)  
**Resync probe:** `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w5_acceptance_resync_20260729T082307Z_presence.txt`  
**SSH re-probe:** `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w5_acceptance_resync_20260729T082307Z_ssh.txt`  
**Acceptance SoT:** `/home/leviathan/OPENCODE_WORKSPACE/FORGE/docs/GOD_LOOP_ACCEPTANCE.md`  
**Score (state.json):** `81` · phase=`PLAN` · `mission_pass=False` · **E3 OPEN** · **no ship report**

## Gate A — Master image & VM infra

| ID | Status | Absolute evidence |
|----|--------|-------------------|
| A1 | **PASS** | Image `macos-forge:master` sha256:5f001b25…; Dockerfile `/home/leviathan/OPENCODE_WORKSPACE/FORGE/docker/Dockerfile.macos-forge` |
| A2 | **PASS** | `docker inspect forge-vm` privileged/cpuset/6g/50922; runner `/home/leviathan/OPENCODE_WORKSPACE/FORGE/docker/run-forge-vm.sh` |
| A3 | **PASS** | `/dev/kvm` inside forge-vm |
| A4 | **PASS** | `/data/BaseSystem.img` 3215118336 B; `/data/mac_hdd_ng.img` 32187416576 B; OSX-KVM symlinks |
| A5 | **PASS** | Weston headless; `/tmp/.X11-unix/X0` |
| A6 | **PASS** | Launch.sh + `/home/leviathan/OPENCODE_WORKSPACE/FORGE/docker/apply-launch-patches.sh`; monitor :4444 |
| A7 | **PASS** | `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/a7_manifest_20260729T012457Z.txt` + typer PNGs |

## Gate B — macOS Sonoma (B5 latest)

| ID | Status | Absolute evidence |
|----|--------|-------------------|
| B1 | **PASS** | `/data/BaseSystem.img` ~3.0G on volume `forge-vm-data` |
| B2 | **PASS** | Install PNGs under `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/install/`; mac_hdd 32187416576 B (F-B1 CLOSED; W10 HOLD) |
| B3 | **IN_PROGRESS** | `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w7_ssv_status_LATEST.md`; live `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w7_live.png`; setup `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w7_setup_status_LATEST.txt` (`WAIT_SSV`); polls `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/ssv_ssh_20260729T044110Z/`; QEMU pid 14826; forge-vm **Up 7 hours**; **no** SIP/AMFI/SSV disable |
| B4 | **SKIP** | raw disk deferred |
| B5 | **OPEN (F-B5-SSH-DEAD)** | Live **2026-07-29T08:23Z** EXIT 255 banner timeout. This wave: `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w5_acceptance_resync_20260729T082307Z_ssh.txt`. W14: `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w14_b5_ssh_probe_LATEST.txt`. W16: `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w16_scrub_ssh_probe_20260729T082307Z.txt`. W7: `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w7_b5_ssh_probe_LATEST.txt`, `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w7_ssh_probe.txt`. W8: `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w8_c_ssh_probe_20260729T063011Z.txt`. W9: `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w9_d_ssh_probe_20260729T063420Z.txt`. Fail: `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/ssh_hostname_attempt_fail.txt`, `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/b5_ssh_probe_20260729T062551Z.txt`. Live PNG: `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/b5_live_LATEST.png` → `b5_live_20260729T062551Z.png`. **ABSENT** success: `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/ssh_hostname_transcript.txt` |

## Gate C — Xcode / build toolchain (absolute latest)

| ID | Status | Absolute evidence |
|----|--------|-------------------|
| C1 | **BLOCKED** | `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/forge-xcode-version.txt` (909 B); `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/gate_c_c1_xcodebuild_version.log` (honest blocked probe, not guest version); `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/gate_c_c1_status_LATEST.json` (stamp **080441Z**, overall=blocked); W4 live: `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w4_c1_ssh_probe_20260729T053911Z.txt`, `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w4_c1_live_20260729T053911Z.png` |
| C2 | **BLOCKED** | staged `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/forge_guest_tree_20260729T054043Z.tar.gz` (778162 B); automation `/home/leviathan/OPENCODE_WORKSPACE/FORGE/scripts/vm-gate-c-build.sh`; W8 refuse `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w8_c_preflight.txt`; **ABSENT** `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/gate_c_c2_repo_listing.txt`; **ABSENT** `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/gate_c_c2_rsync_or_clone.log` |
| C3 | **BLOCKED** | status `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w4_gate_c_status_LATEST.json` (stamp **080441Z**, overall=blocked); residual `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w4_gate_c_residual_LATEST.md`; build `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w4_gate_c_build_20260729T080441Z.log`; preflight `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w4_gate_c_preflight_20260729T053921Z.log`; **ABSENT** `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/gate_c_c3_xcodegen.log`; **ABSENT** `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/gate_c_c3_xcodeproj_stat.txt` |
| C4 | **BLOCKED** | **ABSENT** `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/gate_c_c4_xcodebuild_iphonesimulator.log`; **ABSENT** `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/gate_c_c4_xcodebuild_exit.txt`; CI Actions is Gate **E1** only — not substituted for guest C4 |
| C5 | **PARTIAL (host_pin_only)** | pin assert `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/gate_c_c5_swiftterm_pin.txt`; pins `/home/leviathan/OPENCODE_WORKSPACE/FORGE/project.yml` + `/home/leviathan/OPENCODE_WORKSPACE/FORGE/Package.swift` from 1.15.0; W10 HOLD `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w10_closed_regression.txt`; **ABSENT** `/home/leviathan/OPENCODE_WORKSPACE/FORGE/Package.resolved` |

**Path map:** `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/gate_c_evidence_paths.txt` (MAP_MISMATCHES=0 @ gate-c-evidence-map 080624Z)  
**Presence:** `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/gate_c_presence_latest.txt`  
**Rule:** overall=pass only with real guest logs — **REAL_GUEST_LOGS=0** → overall remains **blocked**.

## Gate D — App functional UI/UX (absolute latest)

| ID | Status | Absolute evidence |
|----|--------|-------------------|
| D1 | **PASS (CI UITest)** | `/home/leviathan/OPENCODE_WORKSPACE/FORGE/ui-screenshots/D1_launch_menu.png` + `01-launch-menu.png` (**474075 B**, sha256 `6af3b8254809cdc63e8359a7e12070dc47adda858237af3a3f1ada92a64eabeb`); SOURCE `/home/leviathan/OPENCODE_WORKSPACE/FORGE/ui-screenshots/SOURCE.txt` (run **30430296561**, stamp 081915Z); host shots stamp dir `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/ui-screenshots_20260729T081803Z/` |
| D2 | **BLOCKED/FAIL** | **ABSENT** canonical `/home/leviathan/OPENCODE_WORKSPACE/FORGE/ui-screenshots/D2_mode1_terminal.png`; **ABSENT** `02-build-on-device.png`; **ABSENT** `terminal-screen.png`. Rejected residual **PRESENT** (NOT pass): `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/ui-screenshots_20260729T065918Z/D2_mode1_terminal.png` (2408947 B); `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/ui-screenshots_postci_20260729T065840Z/D2_mode1_terminal.png`; `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/ci_artifacts_gate_d/app-store-screenshots/02-build-on-device.png` (519939 B). Manifest notes rejected D2 sha256 `80e6faa3412fc789…` |
| D3 | **PASS (CI UITest)** | `/home/leviathan/OPENCODE_WORKSPACE/FORGE/ui-screenshots/D3_mission_control.png` + `03-mission-control.png` (**114942 B**, sha256 `31b3a8b560a494c746eaf04ef60e0daa4013b5042026d2f23676a0c6969133ab`) |
| D4 | **BLOCKED** | `/home/leviathan/OPENCODE_WORKSPACE/FORGE/ui-screenshots/d4_crash_probe.txt` (861 B, D4_status=blocked stamp **081803Z**); placeholders `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/gate_d_d4_uitest_exit.txt` (exit_code=blocked); `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/gate_d_d4_xcodebuild_test.log`; smoke `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w5_gate_d_d4_crash_smoke_LATEST.log`; CI log `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/ci_artifacts_gate_d/ui-test-log/ui-test.log`. **ABSENT** green `/home/leviathan/OPENCODE_WORKSPACE/FORGE/ui-screenshots/D4_smoke_final.png`; **ABSENT** `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/gate_d_d4_crash_probe.txt` |
| D5 | **PARTIAL** | phase1-stub bundle **47917 B** `/home/leviathan/OPENCODE_WORKSPACE/FORGE/iOS/FORGE/Resources/forge-bundle.js`; five vendor `.js` **ABSENT** under `/home/leviathan/OPENCODE_WORKSPACE/FORGE/forge/src/vendor/`; inventory `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w13_phase2_inventory_LATEST.txt` |

**Manifest:** `/home/leviathan/OPENCODE_WORKSPACE/FORGE/ui-screenshots/gate_d_manifest.json` (overall=**partial**, stamp **081915Z**, D1=pass D2=fail D3=pass D4=fail)  
**Status LATEST:** `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w5_gate_d_status_LATEST.json` (overall=**partial**, stamp **081803Z**, D1=pass D2=fail D3=pass D4=blocked)  
**Residual LATEST:** `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w5_gate_d_residual_LATEST.md` · W15 `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w15_gate_d_residual_LATEST.md`  
**Path map:** `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/gate_d_evidence_paths.txt` (MAP_MISMATCHES=0 @ gate-d-evidence-map 081601Z)  
**Presence:** `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/gate_d_presence_latest.txt`  
**W9 preflight:** `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w9_d_preflight.txt`  
**Automation:** `/home/leviathan/OPENCODE_WORKSPACE/FORGE/scripts/vm-gate-d-screenshots.sh` · `scripts/capture-screenshots.sh` · `scripts/pull-gate-d-ci-artifacts.sh`

## Gate E — Ship readiness

| ID | Status | Absolute evidence |
|----|--------|-------------------|
| E1 | **PASS** | https://github.com/leviathan-devops/forge/actions/runs/30220688277 @ de2d7f2; D recovery run https://github.com/leviathan-devops/forge/actions/runs/30430296561; mirror `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/E1_CI_PROOF_LATEST.md` · `/home/leviathan/OPENCODE_WORKSPACE/FORGE/docs/E1_CI_PROOF.md` |
| E2 | **E2_FILLED + RESYNCED** | this pack + `/home/leviathan/OPENCODE_WORKSPACE/FORGE/docs/GOD_LOOP_ACCEPTANCE.md` (Wave 5 `acceptance-resync` 082307Z) |
| E3 | **OPEN** | Mission not PASS — **no** forge ship report under `Grok_Build/Reports/`. Prep only: `/home/leviathan/OPENCODE_WORKSPACE/FORGE/docs/REPORTS_PREP.md`. Probe: `NO_FORGE_SHIP_REPORT` |
| E4 | **PASS** | `./docker/run-forge-vm.sh`; `/home/leviathan/OPENCODE_WORKSPACE/FORGE/docs/E4_VM_REATTACH.md`; `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w5_e4_reattach_20260729T054734Z.log`; live forge-vm **Up 7 hours** 50922→10022 |

## W10 closed-regression (9/9 HOLD)

| Path | Result |
|------|--------|
| `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/w10_closed_regression.txt` | closed_hold=9/9; regressed=0 |
| `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/host_smoke_w5_acceptance_resync_20260729T082307Z.log` | **SMOKE PASS** (bundle 47917 B) |
| `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/pytest_w5_acceptance_resync_20260729T082307Z.log` | **8 passed** |
| `/home/leviathan/OPENCODE_WORKSPACE/FORGE/tmp/host_smoke_latest.log` | → `host_smoke_w5_acceptance_resync_20260729T082307Z.log` |

## Host re-probe (acceptance-resync 082307Z)

| Probe | Result |
|-------|--------|
| SSH :50922 hostname | **EXIT 255** banner timeout |
| `tmp/ssh_hostname_transcript.txt` | **ABSENT** |
| forge-vm | Up 7h; 50922→10022 |
| QEMU | pid 14826 (`qemu-system-x86_64` -m 4000 -smp 2) |
| smoke | **exit 0** bundle **47917** B |
| pytest dual-mode | **8 passed** |
| score | **81** (need ≥96) |
| Reports forge ship | **NO_FORGE_SHIP_REPORT** (correct pre-PASS) |

## Deviations (carry-forward)

1. BASESYSTEM_FORMAT=raw required  
2. Install target disk0 (not handover disk1)  
3. --runtime=runc (daemon default nvidia)  
4. Concurrent god-loop wiped MacHDD once mid-install; re-ran install  
5. Gate D D1/D3 recovered via CI UITest attachments (run 30430296561 / prior 30429569068), not guest simctl (B5 still open)

## Hard rules still held

- No SIP/AMFI/SSV disable  
- No mid-SSV QEMU kill  
- No mission PASS claim  
- No F-B5 closed claim  
- No ship report under Reports/ until mission PASS (E3 remains OPEN)

**Do not claim mission PASS.**
