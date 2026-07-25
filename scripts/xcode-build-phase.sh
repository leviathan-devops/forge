#!/bin/bash
#
# xcode-build-phase.sh — FORGE bundle build phase for Xcode.
# Per spec section 4.5.
#
# This script runs before "Compile Sources" in the Xcode build.
# It detects bun/node and runs the esbuild bundler to produce
# forge-bundle.js, then verifies the output exists and is non-empty.
#
# Add this as a "Run Script" phase in Xcode with:
#   Input Files: $(SRCROOT)/../forge/src/forge-entry.ts
#   Output Files: $(SRCROOT)/Resources/forge-bundle.js
#

set -euo pipefail

# --- Configuration ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FORGE_DIR="$PROJECT_ROOT/forge"
RESOURCES_DIR="$PROJECT_ROOT/iOS/FORGE/Resources"
BUNDLE_FILE="$RESOURCES_DIR/forge-bundle.js"
BUILD_SCRIPT="$SCRIPT_DIR/build-forge-bundle.mjs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}[FORGE]${NC} Starting bundle build phase..."

# --- Detect runtime (bun preferred, node fallback) ---

RUNTIME=""
RUNTIME_CMD=""

if command -v bun &> /dev/null; then
    RUNTIME="bun"
    RUNTIME_CMD="bun"
    echo -e "${CYAN}[FORGE]${NC} Using bun runtime"
elif command -v node &> /dev/null; then
    RUNTIME="node"
    RUNTIME_CMD="node"
    echo -e "${CYAN}[FORGE]${NC} Using node runtime"
else
    echo -e "${RED}[FORGE] ERROR:${NC} Neither bun nor node found in PATH"
    echo -e "${YELLOW}[FORGE]${NC} Install bun: curl -fsSL https://bun.sh/install | bash"
    echo -e "${YELLOW}[FORGE]${NC} Or install node: https://nodejs.org/"
    exit 1
fi

# --- Verify source files exist ---

ENTRY_FILE="$FORGE_DIR/src/forge-entry.ts"
IDENTITY_FILE="$FORGE_DIR/src/forge-identity.ts"
RUNTIME_FILE="$FORGE_DIR/src/forge-runtime.ts"
TERMINAL_FILE="$FORGE_DIR/src/forge-terminal-surface.ts"
GLOBALS_FILE="$FORGE_DIR/shims/forge-globals.js"

echo -e "${CYAN}[FORGE]${NC} Checking source files..."

MISSING_FILES=()

for file in "$ENTRY_FILE" "$IDENTITY_FILE" "$RUNTIME_FILE" "$TERMINAL_FILE" "$GLOBALS_FILE"; do
    if [[ ! -f "$file" ]]; then
        MISSING_FILES+=("$file")
    fi
done

# Check shim directory
SHIM_COUNT=$(find "$FORGE_DIR/shims" -name "forge-*.ts" -o -name "forge-*.js" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$SHIM_COUNT" -lt 10 ]]; then
    echo -e "${YELLOW}[FORGE] WARNING:${NC} Only $SHIM_COUNT shim files found (expected 13+)"
fi

if [[ ${#MISSING_FILES[@]} -gt 0 ]]; then
    echo -e "${RED}[FORGE] ERROR:${NC} Missing source files:"
    for file in "${MISSING_FILES[@]}"; do
        echo -e "  - $file"
    done
    exit 1
fi

echo -e "${GREEN}[FORGE]${NC} All source files present"

# --- Check for package.json and node_modules ---

if [[ ! -f "$FORGE_DIR/package.json" ]]; then
    echo -e "${RED}[FORGE] ERROR:${NC} package.json not found in $FORGE_DIR"
    exit 1
fi

# Install dependencies if needed
if [[ ! -d "$FORGE_DIR/node_modules" ]] || [[ ! -d "$FORGE_DIR/node_modules/esbuild" ]]; then
    echo -e "${YELLOW}[FORGE]${NC} Installing dependencies..."
    cd "$FORGE_DIR"
    if [[ "$RUNTIME" == "bun" ]]; then
        bun install
    else
        npm install
    fi
    cd "$SCRIPT_DIR"
    echo -e "${GREEN}[FORGE]${NC} Dependencies installed"
fi

# --- Clean previous build ---

if [[ -f "$BUNDLE_FILE" ]]; then
    rm -f "$BUNDLE_FILE"
    echo -e "${CYAN}[FORGE]${NC} Removed previous bundle"
fi

# Also clean the manifest
MANIFEST_FILE="$RESOURCES_DIR/forge-bundle-manifest.json"
if [[ -f "$MANIFEST_FILE" ]]; then
    rm -f "$MANIFEST_FILE"
fi

# --- Ensure resources directory exists ---

mkdir -p "$RESOURCES_DIR"

# --- Run the esbuild bundler ---

echo -e "${CYAN}[FORGE]${NC} Building forge-bundle.js..."
echo -e "${CYAN}[FORGE]${NC} Runtime: $RUNTIME"
echo -e "${CYAN}[FORGE]${NC} Script: $BUILD_SCRIPT"

START_TIME=$(date +%s)

if [[ "$RUNTIME" == "bun" ]]; then
    (cd "$PROJECT_ROOT" && bun "$BUILD_SCRIPT")
else
    (cd "$PROJECT_ROOT" && node "$BUILD_SCRIPT")
fi

BUILD_EXIT_CODE=$?

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

if [[ $BUILD_EXIT_CODE -ne 0 ]]; then
    echo -e "${RED}[FORGE] BUILD FAILED${NC} (exit code: $BUILD_EXIT_CODE, ${ELAPSED}s)"
    exit $BUILD_EXIT_CODE
fi

# --- Verify output ---

if [[ ! -f "$BUNDLE_FILE" ]]; then
    echo -e "${RED}[FORGE] ERROR:${NC} Bundle file not created: $BUNDLE_FILE"
    exit 1
fi

BUNDLE_SIZE=$(stat -f%z "$BUNDLE_FILE" 2>/dev/null || stat -c%s "$BUNDLE_FILE" 2>/dev/null || echo "0")
BUNDLE_SIZE_KB=$((BUNDLE_SIZE / 1024))

if [[ $BUNDLE_SIZE -lt 1000 ]]; then
    echo -e "${RED}[FORGE] ERROR:${NC} Bundle is suspiciously small: ${BUNDLE_SIZE} bytes"
    exit 1
fi

echo -e "${GREEN}[FORGE] BUILD SUCCESSFUL${NC}"
echo -e "${CYAN}[FORGE]${NC} Bundle: $BUNDLE_FILE"
echo -e "${CYAN}[FORGE]${NC} Size: ${BUNDLE_SIZE_KB}KB (${BUNDLE_SIZE} bytes)"
echo -e "${CYAN}[FORGE]${NC} Build time: ${ELAPSED}s"

# --- Verify manifest ---

if [[ -f "$MANIFEST_FILE" ]]; then
    echo -e "${GREEN}[FORGE]${NC} Manifest written: $MANIFEST_FILE"
fi

# --- Check for WASM files ---

SQL_WASM="$RESOURCES_DIR/sql-wasm.wasm"
TREE_SITTER_WASM="$RESOURCES_DIR/tree-sitter.wasm"

if [[ -f "$SQL_WASM" ]]; then
    SQL_SIZE=$(stat -f%z "$SQL_WASM" 2>/dev/null || stat -c%s "$SQL_WASM" 2>/dev/null || echo "0")
    echo -e "${GREEN}[FORGE]${NC} sql-wasm.wasm present (${SQL_SIZE} bytes)"
else
    echo -e "${YELLOW}[FORGE] WARNING:${NC} sql-wasm.wasm not found — SQLite will use CDN fallback"
fi

if [[ -f "$TREE_SITTER_WASM" ]]; then
    TS_SIZE=$(stat -f%z "$TREE_SITTER_WASM" 2>/dev/null || stat -c%s "$TREE_SITTER_WASM" 2>/dev/null || echo "0")
    echo -e "${GREEN}[FORGE]${NC} tree-sitter.wasm present (${TS_SIZE} bytes)"
fi

# --- Ensure bundle is added to Xcode resources ---

BUNDLE_FILENAME=$(basename "$BUNDLE_FILE")

# Check if the file is referenced in the Xcode project
if [[ -f "$PROJECT_ROOT/iOS/FORGE.xcodeproj/project.pbxproj" ]]; then
    if grep -q "$BUNDLE_FILENAME" "$PROJECT_ROOT/iOS/FORGE.xcodeproj/project.pbxproj"; then
        echo -e "${GREEN}[FORGE]${NC} Bundle is referenced in Xcode project"
    else
        echo -e "${YELLOW}[FORGE] WARNING:${NC} Bundle not referenced in Xcode project. Add $BUNDLE_FILENAME to the Resources build phase."
    fi
fi

echo -e "${CYAN}[FORGE]${NC} Bundle build phase complete."
