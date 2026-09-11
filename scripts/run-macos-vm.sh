#!/usr/bin/env bash
# DEPRECATED thin wrapper — use docker/run-forge-vm.sh up
# Old version used sickcodes/docker-osx:auto + Penryn-era defaults (WRONG for Sonoma).
exec "$(cd "$(dirname "$0")/.." && pwd)/docker/run-forge-vm.sh" up "$@"
