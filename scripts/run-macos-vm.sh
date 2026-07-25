#!/bin/bash
# FORGE macOS VM — Local iOS Development Environment
# Runs macOS in Docker with KVM acceleration for building/testing Swift apps
#
# Requirements: Docker, KVM (/dev/kvm), 16GB+ RAM
# First boot: ~5-10 minutes. Subsequent boots: ~1 minute.
#
# Inside the VM:
#   SSH: ssh -p 50922 user@localhost (pass: alpine)
#   Install Xcode: Download from Apple or use XCalyze
#   Build FORGE: cd /Users/user/FORGE && xcodegen generate && xcodebuild ...

set -e

VM_NAME="forge-macos"
PORT=50922
RAM_SIZE="8G"  # Adjust based on available RAM
CPU_COUNT=8    # Adjust based on available CPUs

echo "Starting FORGE macOS VM..."
echo "  RAM: $RAM_SIZE"
echo "  CPUs: $CPU_COUNT"
echo "  SSH Port: $PORT"
echo ""

docker run -d \
    --name "$VM_NAME" \
    --privileged \
    --device /dev/kvm \
    -p "$PORT":10022 \
    -e RAM_SIZE="$RAM_SIZE" \
    -e CPU_COUNT="$CPU_COUNT" \
    -e MASTER_PLIST_URL='https://raw.githubusercontent.com/sickcodes/Docker-OSX/master/custom/config-nopicker-custom.plist' \
    -v "$HOME/docker-osx-storage:/mac" \
    sickcodes/docker-osx:auto

echo ""
echo "VM started. Waiting for boot..."
echo "SSH will be available in ~3-5 minutes:"
echo "  ssh -p $PORT user@localhost  (password: alpine)"
echo ""
echo "To install Xcode inside the VM:"
echo "  1. SSH in"
echo "  2. Download Xcode from Apple Developer Portal"
echo "  3. Or use: xcode-select --install (for command line tools)"
echo ""
echo "To copy FORGE source into the VM:"
echo "  scp -P $PORT -r $HOME/OPENCODE_WORKSPACE/FORGE user@localhost:/Users/user/FORGE"
echo ""
echo "To build inside the VM:"
echo "  ssh -p $PORT user@localhost 'cd /Users/user/FORGE && xcodegen generate && xcodebuild build ...'"
