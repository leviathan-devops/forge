#!/bin/bash
set -euo pipefail
export DISPLAY="${DISPLAY:-:0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/weston-run}"
export HOME="${HOME:-/home/arch}"
export RAM=4
export SMP=4
export CORES=4
export BASESYSTEM_FORMAT=raw
export SHORTNAME=sonoma
# FORCE Docker-OSX Sonoma contract (do not inherit Penryn from image ENV)
export CPU=Haswell-noTSX
export CPUID_FLAGS='kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on'
export GENERATE_UNIQUE=true
export MASTER_PLIST_URL='https://raw.githubusercontent.com/sickcodes/osx-serial-generator/master/config-custom-sonoma.plist'

if [ -f /data/sonoma-serial.env ]; then
  # shellcheck disable=SC1091
  source /data/sonoma-serial.env
fi
# re-force after source
export CPU=Haswell-noTSX
export CPUID_FLAGS='kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on'
export BOOTDISK="${BOOTDISK:-/home/arch/OSX-KVM/OpenCore/OpenCore-sonoma.qcow2}"
export IMAGE_PATH=/home/arch/OSX-KVM/mac_hdd_ng.img
export NETWORKING=vmxnet3

if [ ! -e /tmp/.X11-unix/X0 ]; then
  /usr/local/bin/start-display.sh || true
fi

cd /home/arch/OSX-KVM
ln -sfn /data/mac_hdd_ng.raw mac_hdd_ng.img
# restore sonoma OC from volume if needed
if [ -f /data/OpenCore/OpenCore-sonoma.qcow2 ]; then
  cp -a /data/OpenCore/OpenCore-sonoma.qcow2 /home/arch/OSX-KVM/OpenCore/OpenCore-sonoma.qcow2
  cp -a /data/OpenCore/OpenCore-sonoma.qcow2 /home/arch/OSX-KVM/OpenCore/OpenCore.qcow2
fi
[ -f "$BOOTDISK" ] || { echo missing $BOOTDISK; exit 1; }

killall -9 qemu-system-x86_64 2>/dev/null || true
sleep 2

cp -a Launch.sh.orig Launch.sh
/usr/local/bin/apply-launch-patches.sh
sed -i 's|format=qcow2,cache=unsafe,aio=threads|format=raw,cache=unsafe,aio=threads|g' Launch.sh
sed -i '/InstallMedia/d' Launch.sh
# VNC: bind all interfaces so host can map -p 5901:5900 (default image is 127.0.0.1 only)
sed -i 's|-vnc 127\.0\.0\.1:0|-vnc 0.0.0.0:0|g' Launch.sh

echo "BOOT CPU=$CPU FLAGS=$CPUID_FLAGS BOOTDISK=$BOOTDISK MAC=${MAC_ADDRESS:-} RAM=${RAM}G"
bash ./Launch.sh > /tmp/qemu.log 2>&1 &
sleep 10
n=$(ps -eo cmd | awk '/qemu-system-x86_64/ && !/awk/' | wc -l)
echo "qemu_count=$n"
ps -eo pid,stat,pcpu,etime,cmd | awk '/qemu-system-x86_64/ && !/awk/'
# must show Haswell
ps -eo cmd | awk '/qemu-system-x86_64/ && !/awk/' | grep -q Haswell || {
  echo FAIL_STILL_NOT_HASWELL
  ps -eo cmd | awk '/qemu-system-x86_64/ && !/awk/'
  exit 2
}
echo HASWELL_OK
[ "$n" = "1" ] || { echo FAIL_QEMU_COUNT; cat /tmp/qemu.log | tail -50; exit 1; }
# prove VNC is listening (0.0.0.0 or *:5900)
ss -lntp 2>/dev/null | grep -E ':5900' || netstat -lntp 2>/dev/null | grep 5900 || true
echo SONOMA_BOOT_OK
