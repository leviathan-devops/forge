# FORGE macOS compact card
SSH: `ssh -p 50922 user@127.0.0.1` / alpine
Launch: `projects/forge/docker/run-forge-vm.sh up`
Skill: forge-macos-vm · /forge-macos-vm
VNC: `run-forge-vm.sh vnc-host` → 127.0.0.1:5901
Deploy: `scripts/deploy-to-vm.sh`
Boot: start-sonoma ONLY · Haswell-noTSX · OpenCore-sonoma
Never: Penryn, wipe forge-vm-data, dual QEMU
Product: god-loop-forge Mode1+Mode2 iPhone
Hive URIs (OpenViking):
- viking://resources/hive-mind/shared/t3/grok-build/forge-macos-vm-operator-canon.md
- viking://resources/hive-mind/shared/architecture/forge-macos-vm-skill-howto.md
- viking://resources/hive-mind/shared/failures/forge-macos-penryn-ssv-root-cause.md
- viking://resources/hive-mind/shared/t1/compaction-survival/forge-macos-vm-access-cheatsheet.md
