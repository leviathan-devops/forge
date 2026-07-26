#!/bin/bash
#
# capture-screenshots.sh — App Store screenshot generation for FORGE iOS app.
#
# Boots the iPhone 16 Pro Max simulator (6.7" display — 1290x2796), installs
# the FORGE app, launches it, and captures a sequence of screenshots suitable
# for App Store submission.
#
# Screenshot sequence:
#   01-launch-menu.png      — Main launch menu (FORGE title + mode cards)
#   02-build-on-device.png  — BUILD ON-DEVICE mode screen
#   03-mission-control.png  — MISSION CONTROL mode screen
#   04-status-message.png   — Status / connection state
#
# IMPORTANT LIMITATION:
#   xcrun simctl cannot simulate UI taps. The launch-menu screenshot is
#   captured directly via `simctl io screenshot`. For screens that require
#   navigation (BUILD ON-DEVICE, MISSION CONTROL), this script first checks
#   for UI test screenshot attachments produced by FORGEUITests — those are
#   the authoritative, high-quality captures taken during automated UI tests
#   where real navigation occurred. If no attachments are available, the
#   script falls back to capturing the launch state at successive delays.
#
# Usage:
#   ./scripts/capture-screenshots.sh [APP_PATH] [OUTPUT_DIR] [ATTACHMENTS_DIR]
#
# Arguments:
#   APP_PATH        Path to the built FORGE.app bundle
#                   (default: build/Build/Products/Debug-iphonesimulator/FORGE.app)
#   OUTPUT_DIR      Directory to write screenshots into
#                   (default: screenshots/app-store)
#   ATTACHMENTS_DIR Directory containing UI test screenshot attachments
#                   (default: ui-attachments) — set to "" to skip fallback
#
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────

SIMULATOR_NAME="iPhone 16 Pro Max"
BUNDLE_ID="com.forge.app"

APP_PATH="${1:-build/Build/Products/Debug-iphonesimulator/FORGE.app}"
OUTPUT_DIR="${2:-screenshots/app-store}"
ATTACHMENTS_DIR="${3:-ui-attachments}"

# Render delay (seconds) between launch and first screenshot
LAUNCH_DELAY=5
# Delay between successive captures
CAPTURE_DELAY=3

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
        size=$(stat -f%z "$filepath" 2>/dev/null || stat -c%s "$filepath" 2>/dev/null || echo "0")
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

    # Find the first file matching the pattern
    local match
    match=$(find "$ATTACHMENTS_DIR" -type f \( -name "*.png" -o -name "*.jpeg" -o -name "*.heic" \) 2>/dev/null \
            | grep -i "$pattern" | head -1)

    if [ -n "$match" ] && [ -f "$match" ]; then
        cp "$match" "$OUTPUT_DIR/$output_name"
        success "Copied UI test attachment → $output_name (from $(basename "$match"))"
        return 0
    fi

    return 1
}

# ─── Pre-flight checks ───────────────────────────────────────────────────────

log "Starting App Store screenshot generation"

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

log "Installing FORGE.app..."
xcrun simctl install booted "$APP_PATH"
success "FORGE.app installed"

log "Launching FORGE (bundle id: $BUNDLE_ID)..."
# Terminate any existing instance first (clean slate)
xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null || true
sleep 1

xcrun simctl launch booted "$BUNDLE_ID" 2>/dev/null || {
    warn "App launch returned non-zero — it may still be launching"
}
success "FORGE launched"

# ─── Capture screenshots ─────────────────────────────────────────────────────

SCREENSHOT_COUNT=0

# ── 01: Launch Menu ──────────────────────────────────────────────────────────
# The app opens directly to the launch menu showing the FORGE title with the
# cyan underline and the two mode-selection cards. This is captured live via
# simctl — it shows the real launch animation settled state.
log "Capturing launch menu (waiting ${LAUNCH_DELAY}s for UI to render)..."
if capture "01-launch-menu.png" "$LAUNCH_DELAY"; then
    SCREENSHOT_COUNT=$((SCREENSHOT_COUNT + 1))
fi

# ── 02: Build On-Device ──────────────────────────────────────────────────────
# The BUILD ON-DEVICE screen requires tapping the mode card. Since simctl
# cannot tap, we first check for a UI test attachment named "terminal-screen"
# (captured during FORGEUITests when the app navigated to the terminal view).
# If no attachment is found, we fall back to a launch-state capture.
log "Capturing BUILD ON-DEVICE screen..."
if ! copy_attachment "terminal" "02-build-on-device.png"; then
    warn "No UI test attachment for BUILD ON-DEVICE — capturing launch state fallback"
    if capture "02-build-on-device.png" "$CAPTURE_DELAY"; then
        SCREENSHOT_COUNT=$((SCREENSHOT_COUNT + 1))
    fi
else
    SCREENSHOT_COUNT=$((SCREENSHOT_COUNT + 1))
fi

# ── 03: Mission Control ──────────────────────────────────────────────────────
# The MISSION CONTROL screen requires tapping the second mode card. Check for
# a "mission-control" attachment from the UI tests first.
log "Capturing MISSION CONTROL screen..."
if ! copy_attachment "mission" "03-mission-control.png"; then
    warn "No UI test attachment for MISSION CONTROL — capturing launch state fallback"
    if capture "03-mission-control.png" "$CAPTURE_DELAY"; then
        SCREENSHOT_COUNT=$((SCREENSHOT_COUNT + 1))
    fi
else
    SCREENSHOT_COUNT=$((SCREENSHOT_COUNT + 1))
fi

# ── 04: Status Message ───────────────────────────────────────────────────────
# A status/connection state screenshot. Check for a "settings" attachment,
# then fall back to a launch capture.
log "Capturing status message screen..."
if ! copy_attachment "settings" "04-status-message.png"; then
    warn "No UI test attachment for status — capturing launch state fallback"
    if capture "04-status-message.png" "$CAPTURE_DELAY"; then
        SCREENSHOT_COUNT=$((SCREENSHOT_COUNT + 1))
    fi
else
    SCREENSHOT_COUNT=$((SCREENSHOT_COUNT + 1))
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
log "══════════════════════════════════════════════════"
log "  Screenshot generation complete"
log "  Output: $OUTPUT_DIR"
log "  Captured: $SCREENSHOT_COUNT screenshot(s)"
log "══════════════════════════════════════════════════"

# List all output files with sizes
echo ""
if [ -n "$(ls -A "$OUTPUT_DIR" 2>/dev/null)" ]; then
    log "Generated files:"
    for f in "$OUTPUT_DIR"/*; do
        if [ -f "$f" ]; then
            size=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null || echo "?")
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

success "App Store screenshot generation finished with $SCREENSHOT_COUNT screenshot(s)"
