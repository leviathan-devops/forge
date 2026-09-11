#!/usr/bin/env bash
# Reap forge-vm zombies + reboot QEMU. Volume forge-vm-data KEPT.
# product_vm_sim default: FORGE_GUEST_RAM=6 (-m 6000) so CoreSimulator has free headroom.
# Agent-light override (SSH/xcodebuild only, no sim): FORGE_GUEST_RAM=4 FORGE_MEMORY=5g
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export FORGE_NEED_DISPLAY="${FORGE_NEED_DISPLAY:-0}"
export FORGE_GUEST_RAM="${FORGE_GUEST_RAM:-6}"
export FORGE_GUEST_SMP="${FORGE_GUEST_SMP:-4}"
export FORGE_GUEST_CORES="${FORGE_GUEST_CORES:-4}"
# Container cgroup headroom must exceed guest -m (6G guest → ≥8g container)
export FORGE_MEMORY="${FORGE_MEMORY:-8g}"
export FORGE_MEMORY_SWAP="${FORGE_MEMORY_SWAP:-16g}"
export FORGE_CPUSET="${FORGE_CPUSET:-0-3}"
exec "$ROOT/docker/run-forge-vm.sh" hygiene
