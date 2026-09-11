# FAILURE FIXED: Forge SSV→OpenCore multi-day loop (2026-07-30)

## Root cause
Penryn + stock OpenCore vs Docker-OSX Sonoma (Haswell-noTSX + config-custom-sonoma.plist + GENERATE_UNIQUE).
Secondary: `${CPU:-Haswell}` inherits image Penryn.

## Fix
`start-sonoma-boot.sh` force `CPU=Haswell-noTSX`; OpenCore-sonoma; `run-forge-vm.sh start-sonoma|up`.

## Proof
SSH :50922 user/alpine; hostname users-iMac-Pro.local; Sonoma 14.8.8.

## NEVER
Penryn boot; wipe forge-vm-data; SSV wait theater as strategy.
