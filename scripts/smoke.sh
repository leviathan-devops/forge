#!/usr/bin/env bash
# FORGE host smoke — mechanical gate (god-loop CONTAINER_TEST / Wave 1 F-NO-SMOKE)
#
# Usage (from any cwd):
#   bash scripts/smoke.sh
#   /path/to/forge/scripts/smoke.sh
#
# Checks (all must pass; exit non-zero on any fail):
#   1. forge/ npm install + tsc --noEmit (exit 0)
#   2. node scripts/build-forge-bundle.mjs (exit 0) + forge-bundle.js size > 0
#   3. JetBrainsMono fonts required (Regular/Bold/SemiBold .ttf under iOS/)
#   4. docker image macos-forge:master present
#   5. no path hardcodes to external OPENCODE workspace under scripts/
#
# Env:
#   FORGE_ROOT              — optional override; default = parent of scripts/
#   SKIP_NPM_INSTALL=1      — skip npm install if node_modules already present
#   SMOKE_FONTS_REQUIRED=0  — emergency soft-skip fonts (default: required post W2-A)
#
# Closes: F-NO-SMOKE

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -n "${FORGE_ROOT:-}" ]]; then
  ROOT="$(cd "$FORGE_ROOT" && pwd)"
fi
cd "$ROOT"

FAILS=0
pass() { echo "  OK  $*"; }
fail() { echo "  FAIL $*" >&2; FAILS=$((FAILS + 1)); }

echo "== FORGE host smoke =="
echo "ROOT=$ROOT"
echo ""

# ---------------------------------------------------------------------------
# 1) forge/ npm install + tsc
# ---------------------------------------------------------------------------
echo "== 1/5 forge typecheck (npm + tsc) =="
if [[ ! -d "$ROOT/forge" ]]; then
  fail "forge/ directory missing"
else
  if (
    set -euo pipefail
    cd "$ROOT/forge"
    if [[ "${SKIP_NPM_INSTALL:-0}" != "1" ]] || [[ ! -d node_modules ]]; then
      npm install --no-audit --no-fund
    fi
    if [[ -x node_modules/.bin/tsc ]]; then
      ./node_modules/.bin/tsc --noEmit
    else
      npx --no-install tsc --noEmit
    fi
  ); then
    pass "forge tsc --noEmit"
  else
    fail "forge npm install and/or tsc --noEmit"
  fi
fi
echo ""

# ---------------------------------------------------------------------------
# 2) bundle rebuild + size > 0
# ---------------------------------------------------------------------------
echo "== 2/5 forge-bundle rebuild =="
BUNDLE="$ROOT/iOS/FORGE/Resources/forge-bundle.js"
if [[ ! -f "$ROOT/scripts/build-forge-bundle.mjs" ]]; then
  fail "scripts/build-forge-bundle.mjs missing"
else
  if (
    set -euo pipefail
    cd "$ROOT"
    export NODE_PATH="${ROOT}/forge/node_modules${NODE_PATH:+:$NODE_PATH}"
    node "$ROOT/scripts/build-forge-bundle.mjs"
  ); then
    if [[ -f "$BUNDLE" ]]; then
      BSIZE=$(wc -c <"$BUNDLE" | tr -d ' ')
      if [[ "$BSIZE" -gt 0 ]]; then
        pass "bundle rebuild (${BSIZE} bytes -> $BUNDLE)"
      else
        fail "bundle exists but size is 0: $BUNDLE"
      fi
    else
      fail "bundle missing after rebuild: $BUNDLE"
    fi
  else
    fail "node scripts/build-forge-bundle.mjs exited non-zero"
  fi
fi
echo ""

# ---------------------------------------------------------------------------
# 3) JetBrainsMono fonts (required post W2-A / F-MISSING-FONTS)
# ---------------------------------------------------------------------------
echo "== 3/5 JetBrainsMono fonts =="
# Default required after Wave 2 fonts-ship; SMOKE_FONTS_REQUIRED=0 allows emergency soft-skip only.
mapfile -t FONT_HITS < <(find "$ROOT/iOS" -type f \( -name 'JetBrainsMono*.ttf' -o -name 'JetBrainsMono*.otf' \) 2>/dev/null || true)
FONT_COUNT=${#FONT_HITS[@]}
REQUIRED_FACES=(
  "JetBrainsMono-Regular.ttf"
  "JetBrainsMono-Bold.ttf"
  "JetBrainsMono-SemiBold.ttf"
)
MISSING_FACES=()
for face in "${REQUIRED_FACES[@]}"; do
  found=0
  for f in "${FONT_HITS[@]+"${FONT_HITS[@]}"}"; do
    if [[ "$(basename "$f")" == "$face" ]]; then
      found=1
      break
    fi
  done
  if [[ "$found" -eq 0 ]]; then
    MISSING_FACES+=("$face")
  fi
done

if [[ "$FONT_COUNT" -gt 0 && ${#MISSING_FACES[@]} -eq 0 ]]; then
  pass "JetBrainsMono fonts present ($FONT_COUNT file(s); Regular/Bold/SemiBold)"
  for f in "${FONT_HITS[@]}"; do echo "       $f"; done
elif [[ "${SMOKE_FONTS_REQUIRED:-1}" == "0" ]]; then
  echo "  SKIP JetBrainsMono fonts incomplete (SMOKE_FONTS_REQUIRED=0 emergency soft-skip)"
  echo "       found=$FONT_COUNT missing=${MISSING_FACES[*]:-none}"
else
  if [[ "$FONT_COUNT" -eq 0 ]]; then
    fail "JetBrainsMono fonts missing under iOS/ (required post W2-A)"
  else
    fail "JetBrainsMono faces incomplete under iOS/ (missing: ${MISSING_FACES[*]})"
    for f in "${FONT_HITS[@]}"; do echo "       found: $f"; done
  fi
fi
echo ""

# ---------------------------------------------------------------------------
# 4) docker image macos-forge:master
# ---------------------------------------------------------------------------
echo "== 4/5 docker image macos-forge:master =="
if ! command -v docker >/dev/null 2>&1; then
  fail "docker CLI not found"
else
  if docker image inspect macos-forge:master >/dev/null 2>&1; then
    IMG_ID=$(docker image inspect macos-forge:master --format '{{.Id}}' 2>/dev/null | head -c 19)
    pass "macos-forge:master present (${IMG_ID}...)"
  else
    fail "docker image macos-forge:master not found (docker image inspect failed)"
  fi
fi
echo ""

# ---------------------------------------------------------------------------
# 5) no external-workspace path hardcodes under scripts/
# ---------------------------------------------------------------------------
echo "== 5/5 scripts/ free of external-workspace path hardcodes =="
# Assemble token at runtime so documentation lines do not create false positives.
_TOK_A=OPENCODE
_TOK_B=_WORKSPACE
_OC_TOKEN="${_TOK_A}${_TOK_B}"
HARDCODE_HITS="$(
  find "$ROOT/scripts" -type f \( -name '*.sh' -o -name '*.mjs' -o -name '*.js' -o -name '*.ts' \) -print0 \
    | xargs -0 grep -nE "\\\$HOME/${_OC_TOKEN}|/home/[^[:space:]\"']*${_OC_TOKEN}" 2>/dev/null \
    || true
)"

if [[ -z "$HARDCODE_HITS" ]]; then
  pass "no external-workspace path hardcodes under scripts/"
else
  fail "external-workspace path hardcodes under scripts/:"
  printf '%s' "$HARDCODE_HITS" | sed 's/^/       /' >&2
fi
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [[ "$FAILS" -eq 0 ]]; then
  echo "SMOKE PASS (F-NO-SMOKE closed)"
  exit 0
else
  echo "SMOKE FAIL ($FAILS check(s) failed)" >&2
  exit 1
fi
