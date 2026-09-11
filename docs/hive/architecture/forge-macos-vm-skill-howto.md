# forge-macos-vm skill architecture

## Purpose
Zero-theater reattach/boot/SSH/VNC for FORGE Sonoma KVM.

## Agent procedure
1. Using forge-macos-vm skill
2. `cd /home/leviathan/OPENCODE_WORKSPACE/FORGE && ./docker/run-forge-vm.sh up`
3. `./docker/run-forge-vm.sh ssh`
4. Optional: `vnc-host` → `vncviewer 127.0.0.1:5901`
5. Deploy: `./scripts/deploy-to-vm.sh` → guest `~/FORGE`
6. Boot only `start-sonoma`; force Haswell-noTSX; never wipe `forge-vm-data`

## Paths
- Skill: `Grok_Build/.grok/skills/forge-macos-vm/SKILL.md`
- Slash: `/forge-macos-vm` · `/macos-vm`
- Access: `projects/forge/docs/MACOS_VM_ACCESS.md`
