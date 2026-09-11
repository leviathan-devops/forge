# FORGE operator doc index

| Doc | Purpose |
|-----|---------|
| [MACOS_VM_ACCESS.md](MACOS_VM_ACCESS.md) | Launch, SSH, VNC — **Tahoe primary** |
| [TAHOE_MACOS26_UPGRADE_PROCESS.md](TAHOE_MACOS26_UPGRADE_PROCESS.md) | Tahoe 26.x upgrade + Xcode gate |
| [FORGE_ENGINEERING_SPECIFICATION.md](FORGE_ENGINEERING_SPECIFICATION.md) | Product SoT — Mode 1 + Mode 2 iOS app |
| [../LAUNCH_GOAL_TAHOE.txt](../LAUNCH_GOAL_TAHOE.txt) | TV /goal paste Tahoe infra |
| [../AGENTS.md](../AGENTS.md) | Scope + DoD for god-loop-forge |
| Reports E2E Tahoe | `/home/leviathan/Grok_Build/Reports/FORGE_TAHOE_MACOS26_E2E_FORENSIC_REPORT.md` |
| Reports E2E Sonoma residual | `…/FORGE_MACOS_VM_20260730_E2E_FORENSIC_REPORT.md` |
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

## Hive L2 (OpenViking) — organized keys

| Key | Category | Query |
|-----|----------|--------|
| `forge-macos-vm-operator-canon` | t3/grok-build | hive_context scope=t3/grok-build |
| `forge-macos-vm-skill-howto` | architecture | scope=architecture |
| `forge-macos-penryn-ssv-root-cause` | failures | scope=failures |
| `forge-macos-vm-access-cheatsheet` | t1/compaction-survival | scope empty or t1 |

Local mirror (always readable): `projects/forge/docs/hive/`
Catalog: `docs/hive/CATALOG.md`
