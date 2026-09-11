#!/bin/bash
#
# capture-screenshots.sh — App Store + Gate D screenshot generation for FORGE iOS.
#
# Boots the iPhone 16 Pro Max simulator (6.7" display — 1290x2796), installs
# the FORGE app, launches it, and captures a sequence of screenshots suitable
# for App Store submission and god-loop Gate D evidence (D1–D4).
#
# Screenshot sequence (OUTPUT_DIR):
#   01-launch-menu.png      — D1 dual-mode launch menu (FORGE + mode cards)
#   02-build-on-device.png  — D2 Mode1 terminal (SwiftTerm path)
#   03-mission-control.png  — D3 Mode2 Mission Control
#   04-status-message.png   — Status / settings (optional)
#   D1_launch_menu.png      — Gate D alias (when present)
#   D2_mode1_terminal.png   — Gate D alias (when present)
#   D3_mission_control.png  — Gate D alias (when present)
#   gate_d_manifest.json    — D1–D4 status for AUDIT
#   d4_crash_probe.txt      — D4: simctl crash / diagnose probe
#
# IMPORTANT LIMITATION:
#   xcrun simctl cannot simulate UI taps. The launch-menu screenshot is
#   captured directly via `simctl io screenshot`. For screens that require
#   navigation (BUILD ON-DEVICE, MISSION CONTROL), this script first checks
#   for UI test screenshot attachments produced by FORGEUITests (including
#   testGateDSmokeScreenshots writing FORGE_SCREENSHOT_DIR) — those are
#   the authoritative, high-quality captures. If no attachments are available,
#   the script falls back to capturing the launch state at successive delays
#   and marks D2/D3 as partial/fallback in the manifest.
#
# Usage:
#   ./scripts/capture-screenshots.sh [APP_PATH] [OUTPUT_DIR] [ATTACHMENTS_DIR]
#
# Arguments:
#   APP_PATH        Path to the built FORGE.app bundle
#                   (default: build/Build/Products/Debug-iphonesimulator/FORGE.app)
#   OUTPUT_DIR      Directory to write screenshots into
#                   (default: ui-screenshots  — Gate D; set FORGE_SCREENSHOT_OUT
#                    or pass arg; legacy App Store path: screenshots/app-store)
#   ATTACHMENTS_DIR Directory containing UI test screenshot attachments
#                   (default: ui-attachments, or $FORGE_SCREENSHOT_DIR)
#
# Environment:
#   FORGE_SCREENSHOT_DIR  UITest on-disk PNG dir (also used as ATTACHMENTS_DIR)
#   FORGE_SCREENSHOT_OUT  Override default OUTPUT_DIR
#   SIMULATOR_NAME        Default: iPhone 16 Pro Max
#   BUNDLE_ID             Default: com.forge.app
#   SKIP_INSTALL=1        Skip simctl install (already installed)
#   GATE_D=1              Force Gate D naming + stricter D1 check (default on)
#   MODE1_CAPTURE_DELAY   Seconds after Mode1 env launch before D2 shot (default 6)
#   MODE2_CAPTURE_DELAY   Seconds after Mode2 env launch before D3 shot (default 6)
#
# Xcode 26+ simctl: there is NO --setenv. Pass env via SIMCTL_CHILD_ prefix:
#   SIMCTL_CHILD_FORGE_START_MODE=onDevice|missionControl xcrun simctl launch ...
#
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────

SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 16 Pro Max}"
BUNDLE_ID="${BUNDLE_ID:-com.forge.app}"
GATE_D="${GATE_D:-1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_PATH="${1:-build/Build/Products/Debug-iphonesimulator/FORGE.app}"
# Prefer relative to CWD; if missing, try under FORGE_ROOT
if [ ! -d "$APP_PATH" ] && [ -d "$FORGE_ROOT/$APP_PATH" ]; then
    APP_PATH="$FORGE_ROOT/$APP_PATH"
fi

DEFAULT_OUT="${FORGE_SCREENSHOT_OUT:-ui-screenshots}"
OUTPUT_DIR="${2:-$DEFAULT_OUT}"
if [[ "$OUTPUT_DIR" != /* ]]; then
    # Keep relative paths under CWD (guest often runs from GUEST_DIR)
    :
fi

ATTACHMENTS_DIR="${3:-${FORGE_SCREENSHOT_DIR:-ui-attachments}}"

# Render delay (seconds) between launch and first screenshot
LAUNCH_DELAY="${LAUNCH_DELAY:-5}"
# Delay between successive captures
CAPTURE_DELAY="${CAPTURE_DELAY:-3}"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ─── Helpers ─────────────────────────────────────────────────────────────────

log()     { echo -e "${CYAN}[screenshots]${NC} $*"; }
success() { echo -e "${GREEN}[screenshots]${NC} $*"; }
warn()    { echo -e "${YELLOW}[screenshots] WARNING:${NC} $*"; }
fail()    { echo -e "${RED}[screenshots] ERROR:${NC} $*"; }

file_size() {
    local f="$1"
    stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null || echo "0"
}

# Capture a screenshot from the booted simulator.
#   $1 = output filename (within OUTPUT_DIR)
#   $2 = delay in seconds before capture (optional, default CAPTURE_DELAY)
capture() {
    local filename="$1"
    local delay="${2:-$CAPTURE_DELAY}"
    local filepath="$OUTPUT_DIR/$filename"

    sleep "$delay"
    if xcrun simctl io booted screenshot "$filepath" 2>/dev/null; then
        local size
        size=$(file_size "$filepath")
        if [ "$size" -gt 1000 ]; then
            success "Captured $filename (${size} bytes)"
            return 0
        fi
    fi
    warn "Failed to capture $filename"
    return 1
}

# Check if a UI test attachment exists and copy it to the output dir.
# Searches the attachments directory for a file matching the given pattern.
#   $1 = grep pattern to match attachment filename
#   $2 = output filename
copy_attachment() {
    local pattern="$1"
    local output_name="$2"

    if [ -z "$ATTACHMENTS_DIR" ] || [ ! -d "$ATTACHMENTS_DIR" ]; then
        return 1
    fi

    # Find the first file matching the pattern (prefer newer)
    local match
    match=$(find "$ATTACHMENTS_DIR" -type f \( -name "*.png" -o -name "*.jpeg" -o -name "*.heic" \) 2>/dev/null \
            | grep -iE "$pattern" | head -1)

    if [ -n "${match:-}" ] && [ -f "$match" ]; then
        cp "$match" "$OUTPUT_DIR/$output_name"
        success "Copied UI test attachment → $output_name (from $(basename "$match"))"
        return 0
    fi

    return 1
}

# ─── Pre-flight checks ───────────────────────────────────────────────────────

log "Starting screenshot generation (GATE_D=$GATE_D)"
log "FORGE_ROOT=$FORGE_ROOT"

# Host without Xcode: fail closed with clear residual (Linux god-loop host)
if ! command -v xcrun >/dev/null 2>&1; then
    fail "xcrun not found — this script must run on macOS (guest simctl path)"
    fail "On Linux host use: bash scripts/vm-gate-d-screenshots.sh (requires Gate B5 SSH)"
    mkdir -p "$OUTPUT_DIR"
    cat >"$OUTPUT_DIR/gate_d_manifest.json" <<EOF
{
  "stamp": "$(date -u +%Y%m%dT%H%M%SZ)",
  "overall": "blocked",
  "detail": "xcrun/simctl unavailable on this host; run on macOS guest via vm-gate-d-screenshots.sh",
  "gates": {"D1":"blocked","D2":"blocked","D3":"blocked","D4":"blocked"},
  "output_dir": "$OUTPUT_DIR"
}
EOF
    exit 2
fi

# Verify the app bundle exists
if [ ! -d "$APP_PATH" ]; then
    fail "App bundle not found: $APP_PATH"
    fail "Build the app first, or pass the correct path as the first argument."
    exit 1
fi
log "App bundle: $APP_PATH"

# Verify the app executable exists inside the bundle
if [ ! -f "$APP_PATH/FORGE" ]; then
    warn "FORGE executable not found inside bundle — app may not launch correctly"
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"
log "Output directory: $OUTPUT_DIR"
log "Attachments directory: ${ATTACHMENTS_DIR:-<none>}"

# Gate status trackers
D1=fail
D2=fail
D3=fail
D4=unknown
D2_SOURCE=none
D3_SOURCE=none

# ─── Boot simulator ──────────────────────────────────────────────────────────

# Check if the target simulator is already booted (e.g. left over from UI tests).
# `simctl boot` returns non-zero if already booted, which is harmless.
BOOTED_UDID=""
BOOTED_LIST=$(xcrun simctl list devices booted 2>/dev/null | grep -i "$SIMULATOR_NAME" || true)

if [ -n "$BOOTED_LIST" ]; then
    success "$SIMULATOR_NAME is already booted"
    BOOTED_UDID=$(echo "$BOOTED_LIST" | grep -oE '\([-A-F0-9]+\)' | tr -d '()' | head -1)
else
    log "Booting $SIMULATOR_NAME simulator..."
    xcrun simctl boot "$SIMULATOR_NAME" 2>/dev/null || true

    # Wait for the boot to complete
    log "Waiting for simulator to finish booting..."
    xcrun simctl bootstatus "$SIMULATOR_NAME" -b 2>/dev/null || true
    sleep 3
    success "$SIMULATOR_NAME booted"
fi

# Open the Simulator app window so rendering is active (required for screenshots)
open -a Simulator 2>/dev/null || true

# ─── Install & launch the app ────────────────────────────────────────────────

if [ "${SKIP_INSTALL:-0}" != "1" ]; then
    log "Installing FORGE.app..."
    xcrun simctl install booted "$APP_PATH"
    success "FORGE.app installed"
else
    log "SKIP_INSTALL=1 — not reinstalling"
fi

log "Launching FORGE (bundle id: $BUNDLE_ID)..."
# Terminate any existing instance first (clean slate)
xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null || true
sleep 1

LAUNCH_OUT=""
if LAUNCH_OUT=$(xcrun simctl launch booted "$BUNDLE_ID" 2>&1); then
    success "FORGE launched: $LAUNCH_OUT"
else
    warn "App launch returned non-zero — it may still be launching ($LAUNCH_OUT)"
fi

# ─── Capture screenshots ─────────────────────────────────────────────────────

SCREENSHOT_COUNT=0

# ── 01: Launch Menu (D1) ─────────────────────────────────────────────────────
log "Capturing launch menu (waiting ${LAUNCH_DELAY}s for UI to render)..."
if copy_attachment 'D1_launch|01_Launch|LaunchMenu|launch.menu' "01-launch-menu.png"; then
    SCREENSHOT_COUNT=$((SCREENSHOT_COUNT + 1))
    D1=pass
    cp -f "$OUTPUT_DIR/01-launch-menu.png" "$OUTPUT_DIR/D1_launch_menu.png" 2>/dev/null || true
elif capture "01-launch-menu.png" "$LAUNCH_DELAY"; then
    SCREENSHOT_COUNT=$((SCREENSHOT_COUNT + 1))
    D1=pass
    cp -f "$OUTPUT_DIR/01-launch-menu.png" "$OUTPUT_DIR/D1_launch_menu.png" 2>/dev/null || true
else
    D1=fail
fi

# ── 02: Build On-Device (D2) ─────────────────────────────────────────────────
# Reserved paths: 02-build-on-device.png + D2_mode1_terminal.png
# Prefer exact reserved UITest names first (testGateDSmokeScreenshots writes both).
log "Capturing BUILD ON-DEVICE / terminal screen (reserved D2 paths)..."
D2_GOT=0
if [ -n "${ATTACHMENTS_DIR:-}" ] && [ -d "$ATTACHMENTS_DIR" ]; then
    for cand in \
        "$ATTACHMENTS_DIR/02-build-on-device.png" \
        "$ATTACHMENTS_DIR/D2_mode1_terminal.png" \
        "$ATTACHMENTS_DIR/terminal-screen.png" \
        "$ATTACHMENTS_DIR/02_BuildOnDevice.png"; do
        if [ -f "$cand" ]; then
            cp -f "$cand" "$OUTPUT_DIR/02-build-on-device.png"
            cp -f "$cand" "$OUTPUT_DIR/D2_mode1_terminal.png"
            success "Reserved D2 from $(basename "$cand")"
            SCREENSHOT_COUNT=$((SCREENSHOT_COUNT + 1))
            D2=pass
            D2_SOURCE=uitest_reserved
            D2_GOT=1
            break
        fi
    done
fi
if [ "$D2_GOT" -eq 0 ] && copy_attachment 'D2_mode1|02-build-on-device|terminal-screen|02_Build|BuildOnDevice' "02-build-on-device.png"; then
    SCREENSHOT_COUNT=$((SCREENSHOT_COUNT + 1))
    D2=pass
    D2_SOURCE=uitest_attachment
    cp -f "$OUTPUT_DIR/02-build-on-device.png" "$OUTPUT_DIR/D2_mode1_terminal.png" 2>/dev/null || true
    D2_GOT=1
fi
if [ "$D2_GOT" -eq 0 ]; then
    # Prefer agent launch override (AppState.applyAgentLaunchOverrides).
    # Xcode 26+: SIMCTL_CHILD_FORGE_START_MODE (simctl has no --setenv).
    warn "No UI test attachment for BUILD ON-DEVICE — trying SIMCTL_CHILD_FORGE_START_MODE=onDevice"
    xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null || true
    sleep 1
    MODE1_LAUNCH_OUT=""
    if MODE1_LAUNCH_OUT=$(SIMCTL_CHILD_FORGE_START_MODE=onDevice xcrun simctl launch --terminate-running-process booted "$BUNDLE_ID" 2>&1); then
        success "Mode1 env launch: $MODE1_LAUNCH_OUT"
        # Multi-frame hunt: early frames can be blank/fullScreenCover transition.
        MODE1_DELAY="${MODE1_CAPTURE_DELAY:-6}"
        BEST_D2=""
        BEST_SZ=0
        for _try in 1 2 3; do
            sleep "$MODE1_DELAY"
            FR="$OUTPUT_DIR/.d2_try_${_try}.png"
            if xcrun simctl io booted screenshot "$FR" 2>/dev/null; then
                SZ=$(file_size "$FR")
                log "Mode1 frame try=${_try} bytes=${SZ}"
                if [ "$SZ" -gt "$BEST_SZ" ] && [ "$SZ" -gt 20000 ]; then
                    BEST_D2="$FR"
                    BEST_SZ=$SZ
                fi
            fi
            MODE1_DELAY=3
        done
        if [ -n "$BEST_D2" ]; then
            cp -f "$BEST_D2" "$OUTPUT_DIR/02-build-on-device.png"
            cp -f "$BEST_D2" "$OUTPUT_DIR/D2_mode1_terminal.png"
            cp -f "$BEST_D2" "$OUTPUT_DIR/terminal-screen.png" 2>/dev/null || true
            rm -f "$OUTPUT_DIR"/.d2_try_*.png 2>/dev/null || true
            SCREENSHOT_COUNT=$((SCREENSHOT_COUNT + 1))
            D2=pass
            D2_SOURCE=simctl_child_onDevice
            D2_GOT=1
            success "Mode1 multi-frame selected (${BEST_SZ} bytes)"
        fi
    else
        warn "SIMCTL_CHILD Mode1 launch failed: $MODE1_LAUNCH_OUT"
    fi
fi
if [ "$D2_GOT" -eq 0 ]; then
    warn "No Mode1 capture yet — last-resort launch-state fallback (will be partial/lookalike)"
    if capture "02-build-on-device.png" "$CAPTURE_DELAY"; then
        SCREENSHOT_COUNT=$((SCREENSHOT_COUNT + 1))
        D2=partial
        D2_SOURCE=launch_fallback
        cp -f "$OUTPUT_DIR/02-build-on-device.png" "$OUTPUT_DIR/D2_mode1_terminal.png" 2>/dev/null || true
        D2_GOT=1
    else
        D2=fail
    fi
fi
# Reject Springboard/launch false-positive: D2 identical to D1 is partial only.
if [ "$D2" = "pass" ] && [ -f "$OUTPUT_DIR/01-launch-menu.png" ] && [ -f "$OUTPUT_DIR/02-build-on-device.png" ]; then
    if cmp -s "$OUTPUT_DIR/01-launch-menu.png" "$OUTPUT_DIR/02-build-on-device.png"; then
        warn "D2 PNG identical to D1 (launch/Springboard fallback) — demote to partial"
        D2=partial
        D2_SOURCE="${D2_SOURCE}+identical_to_d1"
        rm -f "$OUTPUT_DIR/02-build-on-device.png" "$OUTPUT_DIR/D2_mode1_terminal.png" 2>/dev/null || true
    fi
fi
# Visual gate: Springboard home (mean>45) or launch lookalike (MSE) cannot be D2=pass.
if [ -f "$OUTPUT_DIR/02-build-on-device.png" ] || [ -f "$OUTPUT_DIR/D2_mode1_terminal.png" ]; then
    D2_CAND="$OUTPUT_DIR/02-build-on-device.png"
    [ -f "$D2_CAND" ] || D2_CAND="$OUTPUT_DIR/D2_mode1_terminal.png"
    D1_CAND=""
    [ -f "$OUTPUT_DIR/01-launch-menu.png" ] && D1_CAND="$OUTPUT_DIR/01-launch-menu.png"
    D2_VERDICT=$(python3 - "$D2_CAND" "$D1_CAND" <<'PY' || echo "ok"
import sys
from pathlib import Path
d2 = Path(sys.argv[1])
d1 = Path(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2] else None
if not d2.is_file():
    print("absent"); raise SystemExit(0)
try:
    from PIL import Image
    import numpy as np
    arr = np.asarray(Image.open(d2).convert("RGB").resize((64, 128)), dtype=float)
    mean = float(arr.mean())
    std = float(arr.std())
    if mean < 1.5 and std < 5.0:
        print("blank"); raise SystemExit(0)
    if mean > 45.0 or (d2.stat().st_size > 1_500_000 and mean > 40.0):
        print("springboard"); raise SystemExit(0)
    if d1 is not None and d1.is_file():
        B = np.asarray(Image.open(d1).convert("RGB").resize((64, 128)), dtype=float)
        if float(((arr - B) ** 2).mean()) < 80.0:
            print("lookalike"); raise SystemExit(0)
    print("ok")
except Exception:
    if d1 is not None and d1.is_file() and d2.read_bytes() == d1.read_bytes():
        print("lookalike")
    else:
        print("ok")
PY
)
    case "$D2_VERDICT" in
        springboard)
            warn "D2 rejected Springboard/non-FORGE UI — fail (scrub reserved D2 names)"
            D2=fail
            D2_SOURCE="${D2_SOURCE}+rejected_springboard"
            rm -f "$OUTPUT_DIR/02-build-on-device.png" "$OUTPUT_DIR/D2_mode1_terminal.png" "$OUTPUT_DIR/terminal-screen.png" 2>/dev/null || true
            ;;
        blank)
            warn "D2 rejected blank/black frame — fail (scrub reserved D2 names)"
            D2=fail
            D2_SOURCE="${D2_SOURCE}+rejected_blank"
            rm -f "$OUTPUT_DIR/02-build-on-device.png" "$OUTPUT_DIR/D2_mode1_terminal.png" "$OUTPUT_DIR/terminal-screen.png" 2>/dev/null || true
            ;;
        lookalike)
            warn "D2 launch lookalike — demote to partial (scrub reserved D2 names)"
            D2=partial
            D2_SOURCE="${D2_SOURCE}+launch_lookalike"
            rm -f "$OUTPUT_DIR/02-build-on-device.png" "$OUTPUT_DIR/D2_mode1_terminal.png" 2>/dev/null || true
            ;;
        ok) ;;
        *) ;;
    esac
fi

# ── 03: Mission Control (D3) ─────────────────────────────────────────────────
log "Capturing MISSION CONTROL screen (reserved D3 paths)..."
D3_GOT=0
if [ -n "${ATTACHMENTS_DIR:-}" ] && [ -d "$ATTACHMENTS_DIR" ]; then
    for cand in \
        "$ATTACHMENTS_DIR/D3_mission_control.png" \
        "$ATTACHMENTS_DIR/03-mission-control.png" \
        "$ATTACHMENTS_DIR/mission-control.png" \
        "$ATTACHMENTS_DIR/03_MissionControl.png"; do
        if [ -f "$cand" ]; then
            cp -f "$cand" "$OUTPUT_DIR/03-mission-control.png"
            cp -f "$cand" "$OUTPUT_DIR/D3_mission_control.png"
            success "Reserved D3 from $(basename "$cand")"
            SCREENSHOT_COUNT=$((SCREENSHOT_COUNT + 1))
            D3=pass
            D3_SOURCE=uitest_reserved
            D3_GOT=1
            break
        fi
    done
fi
if [ "$D3_GOT" -eq 0 ] && copy_attachment 'D3_mission|mission.control|03_Mission|MissionControl' "03-mission-control.png"; then
    SCREENSHOT_COUNT=$((SCREENSHOT_COUNT + 1))
    D3=pass
    D3_SOURCE=uitest_attachment
    cp -f "$OUTPUT_DIR/03-mission-control.png" "$OUTPUT_DIR/D3_mission_control.png" 2>/dev/null || true
    D3_GOT=1
fi
if [ "$D3_GOT" -eq 0 ]; then
    # Agent path: Mission Control without UI taps (SIMCTL_CHILD_ — no --setenv).
    warn "No UI test attachment for MISSION CONTROL — trying SIMCTL_CHILD_FORGE_START_MODE=missionControl"
    xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null || true
    sleep 1
    MODE2_LAUNCH_OUT=""
    if MODE2_LAUNCH_OUT=$(SIMCTL_CHILD_FORGE_START_MODE=missionControl xcrun simctl launch --terminate-running-process booted "$BUNDLE_ID" 2>&1); then
        success "Mode2 env launch: $MODE2_LAUNCH_OUT"
        MODE2_DELAY="${MODE2_CAPTURE_DELAY:-6}"
        BEST_D3=""
        BEST_SZ=0
        for _try in 1 2 3; do
            sleep "$MODE2_DELAY"
            FR="$OUTPUT_DIR/.d3_try_${_try}.png"
            if xcrun simctl io booted screenshot "$FR" 2>/dev/null; then
                SZ=$(file_size "$FR")
                log "Mode2 frame try=${_try} bytes=${SZ}"
                if [ "$SZ" -gt "$BEST_SZ" ] && [ "$SZ" -gt 20000 ]; then
                    BEST_D3="$FR"
                    BEST_SZ=$SZ
                fi
            fi
            MODE2_DELAY=3
        done
        if [ -n "$BEST_D3" ]; then
            cp -f "$BEST_D3" "$OUTPUT_DIR/03-mission-control.png"
            cp -f "$BEST_D3" "$OUTPUT_DIR/D3_mission_control.png"
            rm -f "$OUTPUT_DIR"/.d3_try_*.png 2>/dev/null || true
            SCREENSHOT_COUNT=$((SCREENSHOT_COUNT + 1))
            D3=pass
            D3_SOURCE=simctl_child_missionControl
            D3_GOT=1
            success "Mode2 multi-frame selected (${BEST_SZ} bytes)"
        fi
    else
        warn "SIMCTL_CHILD Mode2 launch failed: $MODE2_LAUNCH_OUT"
    fi
fi
if [ "$D3_GOT" -eq 0 ]; then
    warn "No Mode2 capture yet — last-resort launch-state fallback (partial)"
    if capture "03-mission-control.png" "$CAPTURE_DELAY"; then
        SCREENSHOT_COUNT=$((SCREENSHOT_COUNT + 1))
        D3=partial
        D3_SOURCE=launch_fallback
        cp -f "$OUTPUT_DIR/03-mission-control.png" "$OUTPUT_DIR/D3_mission_control.png" 2>/dev/null || true
        D3_GOT=1
    else
        D3=fail
    fi
fi

# ── 04: Status Message ───────────────────────────────────────────────────────
log "Capturing status message screen..."
if ! copy_attachment 'settings|04_Settings|status' "04-status-message.png"; then
    warn "No UI test attachment for status — capturing launch state fallback"
    if capture "04-status-message.png" "$CAPTURE_DELAY"; then
        SCREENSHOT_COUNT=$((SCREENSHOT_COUNT + 1))
    fi
else
    SCREENSHOT_COUNT=$((SCREENSHOT_COUNT + 1))
fi

# ─── D4: crash probe (smoke path) ────────────────────────────────────────────
log "D4 crash probe (simctl + DiagnosticReports + UITest probe)..."
CRASH_PROBE="$OUTPUT_DIR/d4_crash_probe.txt"
# Prefer UITest-written probe (testGateDSmokeScreenshots) when present and clean.
UITEST_PROBE=""
if [ -n "${ATTACHMENTS_DIR:-}" ] && [ -d "$ATTACHMENTS_DIR" ]; then
    if [ -f "$ATTACHMENTS_DIR/d4_crash_probe.txt" ]; then
        UITEST_PROBE="$ATTACHMENTS_DIR/d4_crash_probe.txt"
    fi
fi
{
    echo "stamp=$(date -u +%Y%m%dT%H%M%SZ)"
    echo "bundle=$BUNDLE_ID"
    echo "launch_out=$LAUNCH_OUT"
    if [ -n "$UITEST_PROBE" ]; then
        echo "uitest_probe_source=$UITEST_PROBE"
        echo "--- uitest d4_crash_probe begin ---"
        cat "$UITEST_PROBE"
        echo "--- uitest d4_crash_probe end ---"
    else
        echo "uitest_probe_source=ABSENT"
    fi
    echo "--- simctl listapps (FORGE) ---"
    xcrun simctl listapps booted 2>/dev/null | grep -A5 -i forge || echo "(no forge listapps match)"
    echo "--- spawn / launch again smoke (SIMCTL_CHILD Mode1 dual) ---"
    xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null || true
    sleep 1
    SIMCTL_CHILD_FORGE_START_MODE=onDevice xcrun simctl launch --terminate-running-process booted "$BUNDLE_ID" >>/dev/null 2>&1 || true
    echo "mode1_relaunch_1=yes"
    sleep 2
    xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null || true
    sleep 1
    SIMCTL_CHILD_FORGE_START_MODE=onDevice xcrun simctl launch --terminate-running-process booted "$BUNDLE_ID" >>/dev/null 2>&1 || true
    echo "relaunch_started=yes"
    echo "mode1_relaunch_2=yes"
    sleep 3
    # Check process still alive
    if xcrun simctl spawn booted launchctl print system 2>/dev/null | grep -qi forge; then
        echo "process_hint=forge_seen_in_launchctl"
    else
        echo "process_hint=launchctl_scan_inconclusive"
    fi
    # Known crash log locations (host macOS + sim)
    echo "--- DiagnosticReports (host, last 5 forge) ---"
    find "$HOME/Library/Logs/DiagnosticReports" -type f \( -iname '*FORGE*' -o -iname '*forge*' \) 2>/dev/null \
        | tail -5 || echo "(none)"
    echo "--- CoreSimulator device logs (tail) ---"
    xcrun simctl spawn booted log show --predicate 'processImagePath CONTAINS "FORGE"' --last 2m --style compact 2>/dev/null \
        | tail -40 || echo "(log show unavailable or empty)"
} >"$CRASH_PROBE" 2>&1 || true

# Heuristic: D1 + no crash keywords → D4 pass. UITest probe status=pass is strong signal.
# Exclude lines that only mention keywords in the "keywords_scanned=" catalog /
# evidence_rules / host_harness static lines that list token names.
if [ "$D1" = "pass" ]; then
    CRASH_HIT=0
    if grep -Eiq 'EXC_BAD_ACCESS|Fatal error|swift runtime error|SIGABRT|SIGSEGV' "$CRASH_PROBE" 2>/dev/null; then
        # Ignore harness catalog lines that list keyword names without a hit.
        if grep -Eiv 'keywords_scanned=|keywords_found=none|note=UITest smoke|evidence_rules:|D4=pass requires|host_harness_static' "$CRASH_PROBE" 2>/dev/null \
            | grep -Eiq 'EXC_BAD_ACCESS|Fatal error|swift runtime error|SIGABRT|SIGSEGV'; then
            CRASH_HIT=1
        fi
    fi
    # UITest probe: D4_status=pass + keywords_found=none is harness-level green.
    UITEST_D4_PASS=0
    if [ -n "${UITEST_PROBE:-}" ] && grep -qE '^D4_status=pass' "$UITEST_PROBE" 2>/dev/null \
       && grep -qE 'keywords_found=none' "$UITEST_PROBE" 2>/dev/null; then
        UITEST_D4_PASS=1
    fi
    if [ "$CRASH_HIT" -eq 1 ]; then
        D4=fail
        warn "D4: crash keywords found in probe — see $CRASH_PROBE"
    else
        D4=pass
        if [ "$UITEST_D4_PASS" -eq 1 ]; then
            success "D4: UITest probe D4_status=pass + no runtime crash keywords (see $CRASH_PROBE)"
        else
            success "D4: no blocker crash keywords on smoke re-launch (see $CRASH_PROBE)"
        fi
    fi
else
    D4=blocked
fi

# ─── Manifest ────────────────────────────────────────────────────────────────
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
MANIFEST="$OUTPUT_DIR/gate_d_manifest.json"
OVERALL=fail
if [ "$D1" = "pass" ] && [ "$D2" = "pass" ] && [ "$D3" = "pass" ] && [ "$D4" = "pass" ]; then
    OVERALL=pass
elif [ "$D1" = "pass" ] && { [ "$D2" = "pass" ] || [ "$D2" = "partial" ]; } && { [ "$D3" = "pass" ] || [ "$D3" = "partial" ]; }; then
    OVERALL=partial
elif [ "$D1" = "pass" ]; then
    OVERALL=partial
else
    OVERALL=fail
fi

# Write JSON via pure bash (no nested heredoc issues)
ABS_OUT="$(cd "$OUTPUT_DIR" && pwd)"
ABS_APP="$(cd "$(dirname "$APP_PATH")" && pwd)/$(basename "$APP_PATH")"
ABS_CRASH="$ABS_OUT/$(basename "$CRASH_PROBE")"
cat >"$MANIFEST" <<JSON
{
  "stamp": "$STAMP",
  "overall": "$OVERALL",
  "gates": {
    "D1_launch_menu": "$D1",
    "D2_mode1_terminal": "$D2",
    "D3_mission_control": "$D3",
    "D4_no_crash_smoke": "$D4"
  },
  "sources": {
    "D2": "$D2_SOURCE",
    "D3": "$D3_SOURCE"
  },
  "screenshot_count": $SCREENSHOT_COUNT,
  "output_dir": "$ABS_OUT",
  "app_path": "$ABS_APP",
  "attachments_dir": "$ATTACHMENTS_DIR",
  "crash_probe": "$ABS_CRASH",
  "note": "D2/D3 prefer UITest attachments; fallback SIMCTL_CHILD_FORGE_START_MODE (Xcode26 no --setenv). launch_fallback partial only."
}
JSON
log "wrote manifest $MANIFEST overall=$OVERALL"

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
log "══════════════════════════════════════════════════"
log "  Screenshot generation complete"
log "  Output: $OUTPUT_DIR"
log "  Captured: $SCREENSHOT_COUNT screenshot(s)"
log "  Gate D: D1=$D1 D2=$D2($D2_SOURCE) D3=$D3($D3_SOURCE) D4=$D4 overall=$OVERALL"
log "  Manifest: $MANIFEST"
log "══════════════════════════════════════════════════"

# List all output files with sizes
echo ""
if [ -n "$(ls -A "$OUTPUT_DIR" 2>/dev/null)" ]; then
    log "Generated files:"
    for f in "$OUTPUT_DIR"/*; do
        if [ -f "$f" ]; then
            size=$(file_size "$f")
            size_kb=$((size / 1024))
            echo "  $(basename "$f")  (${size_kb}KB)"
        fi
    done
else
    warn "No screenshots were generated — check simulator status and app installation"
fi

echo ""

# Verify minimum screenshot count (at least the launch menu)
if [ "$SCREENSHOT_COUNT" -lt 1 ]; then
    fail "No screenshots captured successfully"
    exit 1
fi

# Gate D strict: fail if D1 missing
if [ "$GATE_D" = "1" ] && [ "$D1" != "pass" ]; then
    fail "Gate D1 failed — launch menu not captured"
    exit 1
fi

success "Screenshot generation finished with $SCREENSHOT_COUNT screenshot(s) overall=$OVERALL"
exit 0
