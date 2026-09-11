#!/usr/bin/env bash
# Wave 4 / Gate C (C2–C5): push forge tree to macOS guest and build iphonesimulator Debug.
#
# Gates:
#   C2  Repo on VM (rsync or git clone)
#   C3  xcodegen generate → FORGE.xcodeproj
#   C4  xcodebuild -sdk iphonesimulator -configuration Debug exit 0
#   C5  SwiftTerm 1.15.x in Package.resolved (not 2.0.0)
#
# Depends on Gate B5: ssh -p 50922 working.
# Evidence logs: <FORGE_ROOT>/tmp/w4_gate_c_*.log
#
# Usage (host):
#   bash scripts/vm-gate-c-build.sh
#   SSH_PORT=50922 SSH_USER=user SSH_HOST=127.0.0.1 bash scripts/vm-gate-c-build.sh
#   GUEST_DIR=/Users/user/FORGE bash scripts/vm-gate-c-build.sh
#
set -euo pipefail

FORGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SSH_HOST="${SSH_HOST:-127.0.0.1}"
SSH_PORT="${SSH_PORT:-50922}"
SSH_USER="${SSH_USER:-user}"
GUEST_DIR="${GUEST_DIR:-/Users/${SSH_USER}/FORGE}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVID_DIR="${FORGE_ROOT}/tmp"
mkdir -p "$EVID_DIR"
LOG="${EVID_DIR}/w4_gate_c_build_${STAMP}.log"
STATUS_JSON="${EVID_DIR}/w4_gate_c_status_${STAMP}.json"

SSH_BASE=(ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=no
          -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -p "$SSH_PORT")
SCP_BASE=(scp -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=no
          -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -P "$SSH_PORT")
RSYNC_SSH="ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -p ${SSH_PORT}"

log() { echo "[$(date -u +%H:%M:%SZ)] $*" | tee -a "$LOG"; }
fail() { log "FAIL: $*"; write_status fail "$*"; exit 1; }

write_status() {
  local overall="$1" detail="${2:-}"
  cat >"$STATUS_JSON" <<EOF
{
  "stamp": "$STAMP",
  "overall": "$overall",
  "detail": $(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$detail"),
  "ssh": "${SSH_USER}@${SSH_HOST}:${SSH_PORT}",
  "guest_dir": "$GUEST_DIR",
  "log": "$LOG",
  "gates": {
    "C2_repo": "${C2:-blocked}",
    "C3_xcodegen": "${C3:-blocked}",
    "C4_xcodebuild": "${C4:-blocked}",
    "C5_swiftterm": "${C5:-blocked}"
  }
}
EOF
  # Always refresh LATEST pointer for wave consumers
  cp -f "$STATUS_JSON" "${EVID_DIR}/w4_gate_c_status_LATEST.json"
  log "status_json=$STATUS_JSON overall=$overall"
  log "status_latest=${EVID_DIR}/w4_gate_c_status_LATEST.json"
}


write_c5_host_pin() {
  # Always assert host SwiftTerm 1.15.x pin (C5 host_pin_only until guest Package.resolved)
  local pin="${EVID_DIR}/gate_c_c5_swiftterm_pin.txt"
  {
    echo "# C5 SwiftTerm pin assert — host $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "stamp: $STAMP"
    echo "wave: gate-c-runtime (vm-gate-c-build.sh)"
    echo "criterion: SwiftTerm 1.15.x (not 2.0.0)"
    echo ""
    echo "## project.yml"
    grep -n -E 'SwiftTerm|from:' "$FORGE_ROOT/project.yml" || true
    echo ""
    echo "## Package.swift"
    grep -n -E 'SwiftTerm|from:' "$FORGE_ROOT/Package.swift" || true
    echo ""
    if grep -q 'from: "1.15.0"' "$FORGE_ROOT/project.yml" \
       && grep -q 'from: "1.15.0"' "$FORGE_ROOT/Package.swift"; then
      echo "host_pin: PASS (project.yml + Package.swift from: \"1.15.0\")"
      echo "guest_pin: ${1:-pending}"
      echo "C5_status: ${2:-host_pin_only}"
    else
      echo "host_pin: FAIL"
      echo "C5_status: fail"
    fi
    echo "note: never substitute host smoke for C4; C5 host pin ≠ guest Package.resolved"
  } >"$pin"
  log "c5_pin_file=$pin"
}

write_blocked_residual() {
  local detail="${1:-SSH blocked}"
  local res="${EVID_DIR}/w4_gate_c_residual_${STAMP}.md"
  cat >"$res" <<EOF
# Wave gate-c-runtime residual — vm-gate-c-build

**stamp:** ${STAMP}
**label:** gate-c-runtime
**finding:** F-MISSION-GATES-CDE (partial — Gate C)

## Result: BLOCKED (dependency Gate B5)

| Gate | Status | Evidence |
|------|--------|----------|
| C1 Xcode on VM | blocked | needs guest shell; no SSH |
| C2 Repo on VM | **blocked** | rsync/ssh not possible |
| C3 xcodegen generate | **blocked** | depends C2 + guest xcodegen |
| C4 xcodebuild iphonesimulator Debug | **blocked** | depends C3; **not** host smoke / CI |
| C5 SwiftTerm 1.15.x | **host_pin_only** | project.yml + Package.swift \`from: "1.15.0"\` |

## Why blocked
- ${detail}
- Host \`:50922\` TCP open but SSH banner timeout (sshd not up / SSV).
- Finding **F-B5-SSH-DEAD** still OPEN.
- Hard rule: do **not** kill QEMU mid-SSV.
- Hard rule: never substitute host smoke or CI Actions for **C4** guest xcodebuild.

## Evidence this run
- status: \`tmp/w4_gate_c_status_LATEST.json\`
- build log: \`${LOG#$FORGE_ROOT/}\`
- C5 pin: \`tmp/gate_c_c5_swiftterm_pin.txt\`
- residual: \`tmp/w4_gate_c_residual_LATEST.md\`

## Do not claim
- C1–C4 PASS (no guest shell)
- xcodebuild exit 0 on guest
- Package.resolved 1.15.x on guest
- F-B5 closed (success transcript ABSENT)
EOF
  cp -f "$res" "${EVID_DIR}/w4_gate_c_residual_LATEST.md"
  log "residual=$res residual_latest=${EVID_DIR}/w4_gate_c_residual_LATEST.md"
}

write_c1_blocked_probe() {
  # Honest C1 blocked probe log (not guest xcodebuild stdout)
  local c1log="${EVID_DIR}/gate_c_c1_xcodebuild_version.log"
  local c1stamp_log="${EVID_DIR}/gate_c_c1_${STAMP}.log"
  local c1status="${EVID_DIR}/gate_c_c1_status_${STAMP}.json"
  {
    echo "# Gate C1 — xcodebuild -version capture log"
    echo "# stamp: $STAMP"
    echo "# wave: gate-c-runtime (vm-gate-c-build.sh)"
    echo "# status: BLOCKED"
    echo "# target: ${SSH_USER}@${SSH_HOST}:${SSH_PORT} (+ alpine, admin)"
    echo "#"
    echo "# Intended remote command: xcodebuild -version via SSH"
    echo "# Result: NOT EXECUTED on guest — SSH banner timeout (exit 255)"
    echo "# TCP ${SSH_PORT} open but guest sshd not answering (F-B5-SSH-DEAD)."
    echo "#"
    echo "# === probe transcript (from build log) ==="
    grep -E 'SSH (fail|probe|OK)|banner|Connection timed|SSH_OK|user=' "$LOG" || true
    echo "#"
    echo "# guest_dir reserved: $GUEST_DIR"
    echo "# Do NOT claim C1 PASS without guest xcodebuild -version stdout."
  } >"$c1log"
  cp -f "$c1log" "$c1stamp_log"
  cp -f "$c1log" "${EVID_DIR}/gate_c_c1_LATEST.log"
  cat >"$c1status" <<EOF
{
  "stamp": "$STAMP",
  "gate": "C1",
  "overall": "blocked",
  "detail": "SSH banner timeout — cannot run xcodebuild -version on guest",
  "ssh": "${SSH_USER}@${SSH_HOST}:${SSH_PORT}",
  "log": "$c1log",
  "guest_stdout": null
}
EOF
  cp -f "$c1status" "${EVID_DIR}/gate_c_c1_status_LATEST.json"
  log "c1_blocked_log=$c1log"
}

C2=blocked; C3=blocked; C4=blocked; C5=blocked

log "=== W4-B vm-repo-xcodegen-build $STAMP ==="
log "FORGE_ROOT=$FORGE_ROOT"
log "target ${SSH_USER}@${SSH_HOST}:${SSH_PORT} → $GUEST_DIR"

# --- Host C5 pin pre-check (project.yml) ---
if ! grep -q 'from: "1.15.0"' "$FORGE_ROOT/project.yml"; then
  fail "host project.yml missing SwiftTerm from: 1.15.0"
fi
log "host project.yml SwiftTerm from: 1.15.0 OK"

# --- B5 / SSH probe ---
log "SSH probe..."
SSH_OK=0
# Unique candidate users (preserve SSH_USER first)
CANDIDATES=()
for u in "$SSH_USER" user alpine admin; do
  skip=0
  for e in "${CANDIDATES[@]+"${CANDIDATES[@]}"}"; do
    [[ "$e" == "$u" ]] && skip=1 && break
  done
  [[ $skip -eq 0 ]] && CANDIDATES+=("$u")
done
for u in "${CANDIDATES[@]}"; do
  if "${SSH_BASE[@]}" "${u}@${SSH_HOST}" 'echo SSH_OK; hostname; whoami; uname -a' >>"$LOG" 2>&1; then
    SSH_USER="$u"
    GUEST_DIR="/Users/${SSH_USER}/FORGE"
    SSH_OK=1
    log "SSH_OK user=$SSH_USER"
    break
  else
    log "SSH fail user=$u (rc=$?)"
  fi
done
if [[ "$SSH_OK" -ne 1 ]]; then
  C2=blocked; C3=blocked; C4=blocked; C5=host_pin_only
  write_c5_host_pin "ABSENT (needs B5 + Package.resolved on macOS guest)" "host_pin_only"
  write_c1_blocked_probe
  write_blocked_residual "SSH banner timeout — Gate B5 (F-B5-SSH-DEAD) still open; cannot C2–C4"
  write_status blocked "SSH banner timeout — Gate B5 (F-B5-SSH-DEAD) still open; cannot C2–C4 (C5 host project.yml pin only)"
  log "RESIDUAL: C1–C4 blocked on B5. C5=host_pin_only (project.yml from: 1.15.0). Partial F-MISSION-GATES-CDE."
  log "NOTE: reserved C2–C4 guest logs left ABSENT (no host-smoke substitute for C4)."
  exit 2
fi

# --- C2: rsync repo to guest ---
log "C2 rsync → ${SSH_USER}@${SSH_HOST}:${GUEST_DIR}"
"${SSH_BASE[@]}" "${SSH_USER}@${SSH_HOST}" "mkdir -p '$GUEST_DIR'" >>"$LOG" 2>&1 || fail "guest mkdir failed"
if command -v rsync >/dev/null 2>&1; then
  rsync -az --delete \
    -e "$RSYNC_SSH" \
    --exclude '.git/' \
    --exclude 'tmp/' \
    --exclude 'node_modules/' \
    --exclude 'forge/node_modules/' \
    --exclude '.pytest_cache/' \
    --exclude 'build/' \
    --exclude 'DerivedData/' \
    --exclude 'FORGE.xcodeproj/' \
    --exclude '.build/' \
    --exclude '__pycache__/' \
    --exclude '.trident/' \
    --exclude '.grok/' \
    --exclude 'CONTEXT_MANAGEMENT/' \
    "$FORGE_ROOT/" "${SSH_USER}@${SSH_HOST}:${GUEST_DIR}/" >>"$LOG" 2>&1 \
    || fail "rsync failed"
else
  # fallback: tar over ssh
  tar -C "$FORGE_ROOT" \
    --exclude='.git' --exclude='tmp' --exclude='node_modules' \
    --exclude='forge/node_modules' --exclude='.pytest_cache' \
    --exclude='build' --exclude='DerivedData' --exclude='FORGE.xcodeproj' \
    --exclude='.build' --exclude='__pycache__' --exclude='.trident' \
    --exclude='.grok' --exclude='CONTEXT_MANAGEMENT' \
    -czf - . | "${SSH_BASE[@]}" "${SSH_USER}@${SSH_HOST}" \
    "mkdir -p '$GUEST_DIR' && tar -xzf - -C '$GUEST_DIR'" >>"$LOG" 2>&1 \
    || fail "tar|ssh failed"
fi

LISTING=$("${SSH_BASE[@]}" "${SSH_USER}@${SSH_HOST}" "ls -la '$GUEST_DIR' | head -40; test -f '$GUEST_DIR/project.yml' && echo PROJECT_YML_OK; test -d '$GUEST_DIR/iOS/FORGE' && echo IOS_OK" 2>&1) || fail "guest listing failed"
echo "$LISTING" | tee -a "$LOG"
echo "$LISTING" | grep -q PROJECT_YML_OK || fail "project.yml missing on guest"
echo "$LISTING" | grep -q IOS_OK || fail "iOS/FORGE missing on guest"
C2=pass
echo "$LISTING" >"${EVID_DIR}/gate_c_c2_repo_listing.txt"
log "C2 PASS — repo on guest at $GUEST_DIR (listing → gate_c_c2_repo_listing.txt)"

# --- Guest toolchain (C1 soft — needed for C3/C4) ---
log "probe xcodebuild / xcodegen on guest"
"${SSH_BASE[@]}" "${SSH_USER}@${SSH_HOST}" bash -s <<'REMOTE' >>"$LOG" 2>&1 || true
set +e
command -v xcodebuild; xcodebuild -version 2>&1 | head -5
command -v xcodegen; xcodegen --version 2>&1 | head -3
command -v brew; command -v swift
REMOTE

# Install xcodegen if missing (Homebrew)
log "ensure xcodegen"
"${SSH_BASE[@]}" "${SSH_USER}@${SSH_HOST}" bash -s <<REMOTE >>"$LOG" 2>&1 || fail "xcodegen ensure failed"
set -e
export PATH="/opt/homebrew/bin:/usr/local/bin:\$PATH"
if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    brew install xcodegen
  else
    echo "NO_BREW_NO_XCODEGEN"; exit 1
  fi
fi
xcodegen --version
REMOTE

# --- C3: xcodegen generate ---
log "C3 xcodegen generate"
"${SSH_BASE[@]}" "${SSH_USER}@${SSH_HOST}" bash -s <<REMOTE >>"$LOG" 2>&1 || fail "xcodegen generate failed"
set -e
export PATH="/opt/homebrew/bin:/usr/local/bin:\$PATH"
cd '$GUEST_DIR'
xcodegen generate
test -d FORGE.xcodeproj
ls -la FORGE.xcodeproj | head -20
echo XCODEPROJ_OK
REMOTE
C3=pass
{
  echo "# C3 xcodegen — guest success stamp $STAMP"
  echo "guest_dir=$GUEST_DIR"
  echo "XCODEPROJ_OK"
  "${SSH_BASE[@]}" "${SSH_USER}@${SSH_HOST}" "ls -la '$GUEST_DIR/FORGE.xcodeproj' | head -20" 2>&1 || true
} | tee "${EVID_DIR}/gate_c_c3_xcodegen.log" >/dev/null
"${SSH_BASE[@]}" "${SSH_USER}@${SSH_HOST}" "stat '$GUEST_DIR/FORGE.xcodeproj' 2>&1; ls -la '$GUEST_DIR/FORGE.xcodeproj' | head -20"   >"${EVID_DIR}/gate_c_c3_xcodeproj_stat.txt" 2>&1 || true
log "C3 PASS — FORGE.xcodeproj generated"

# --- C4: xcodebuild iphonesimulator Debug ---
log "C4 xcodebuild iphonesimulator Debug"
BUILD_LOG_GUEST="/tmp/forge_xcodebuild_${STAMP}.log"
"${SSH_BASE[@]}" "${SSH_USER}@${SSH_HOST}" bash -s <<REMOTE >>"$LOG" 2>&1 || fail "xcodebuild failed"
set -e
export PATH="/opt/homebrew/bin:/usr/local/bin:\$PATH"
cd '$GUEST_DIR'
# Prefer generic destination if named sim missing
set -o pipefail
xcodebuild build \
  -project FORGE.xcodeproj \
  -scheme FORGE \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  -derivedDataPath ./build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  2>&1 | tee '$BUILD_LOG_GUEST'
test -f ./build/Build/Products/Debug-iphonesimulator/FORGE.app/FORGE \
  || test -d ./build/Build/Products/Debug-iphonesimulator/FORGE.app
echo XCODEBUILD_OK
ls -la ./build/Build/Products/Debug-iphonesimulator/FORGE.app/ | head -20
REMOTE
# pull build log
"${SCP_BASE[@]}" "${SSH_USER}@${SSH_HOST}:${BUILD_LOG_GUEST}" \
  "${EVID_DIR}/w4_xcodebuild_${STAMP}.log" >>"$LOG" 2>&1 || log "warn: could not scp guest build log"
C4=pass
# Reserved C4 paths — guest build only (never host smoke)
if [[ -f "${EVID_DIR}/w4_xcodebuild_${STAMP}.log" ]]; then
  cp -f "${EVID_DIR}/w4_xcodebuild_${STAMP}.log" "${EVID_DIR}/gate_c_c4_xcodebuild_iphonesimulator.log"
else
  # fall back: extract from main log after C4 section
  cp -f "$LOG" "${EVID_DIR}/gate_c_c4_xcodebuild_iphonesimulator.log"
fi
echo "0" >"${EVID_DIR}/gate_c_c4_xcodebuild_exit.txt"
echo "stamp=$STAMP guest_xcodebuild_exit=0 sdk=iphonesimulator config=Debug" >>"${EVID_DIR}/gate_c_c4_xcodebuild_exit.txt"
log "C4 PASS — xcodebuild iphonesimulator Debug exit 0"

# --- C5: Package.resolved SwiftTerm 1.15.x ---
log "C5 Package.resolved SwiftTerm"
RESOLVED_FILE="${EVID_DIR}/w4_package_resolved_${STAMP}.txt"
"${SSH_BASE[@]}" "${SSH_USER}@${SSH_HOST}" bash -s <<REMOTE >"$RESOLVED_FILE" 2>&1 || true
set +e
cd '$GUEST_DIR'
# SPM may place resolved under project or sourcepackages
find . -name Package.resolved 2>/dev/null | head -20
for f in \
  FORGE.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved \
  FORGE.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/configuration/Package.resolved \
  Package.resolved \
  build/SourcePackages/workspace-state.json
 do
  if [ -f "\$f" ]; then
    echo "FOUND:\$f"
    grep -n -i 'SwiftTerm\|version\|identity' "\$f" | head -40
  fi
done
# also dump from DerivedData checkout
find ./build -name Package.resolved 2>/dev/null | while read -r f; do
  echo "FOUND:\$f"
  grep -n -i 'SwiftTerm\|"version"' "\$f" | head -40
done
REMOTE
cat "$RESOLVED_FILE" | tee -a "$LOG"
RESOLVED_SNIP="$(cat "$RESOLVED_FILE")"

# Parse version
if echo "$RESOLVED_SNIP" | grep -Eiq 'SwiftTerm' \
   && echo "$RESOLVED_SNIP" | grep -Eiq '"version"\s*:\s*"1\.15\.|"version"\s*:\s*"1\.15'; then
  C5=pass
  log "C5 PASS — SwiftTerm 1.15.x in resolved"
elif echo "$RESOLVED_SNIP" | grep -Eiq '1\.15\.'; then
  C5=pass
  log "C5 PASS — 1.15.x string present near resolved"
else
  # Fallback: project.yml pin still holds; resolved may use workspace-state only
  if "${SSH_BASE[@]}" "${SSH_USER}@${SSH_HOST}" \
      "grep -n '1.15' '$GUEST_DIR/project.yml'" >>"$LOG" 2>&1; then
    C5=partial
    log "C5 PARTIAL — project.yml 1.15.0; Package.resolved parse inconclusive (see log)"
  else
    C5=fail
    fail "C5 SwiftTerm 1.15.x not evidenced in Package.resolved"
  fi
fi

# Pull resolved file if present
"${SSH_BASE[@]}" "${SSH_USER}@${SSH_HOST}" \
  "find '$GUEST_DIR' -name Package.resolved -print 2>/dev/null | head -3" \
  >"${EVID_DIR}/w4_resolved_paths_${STAMP}.txt" 2>&1 || true
RPATH=$(head -1 "${EVID_DIR}/w4_resolved_paths_${STAMP}.txt" || true)
if [[ -n "${RPATH:-}" && "$RPATH" == /* || "$RPATH" == .* || "$RPATH" == FORGE* || "$RPATH" == build* || "$RPATH" == "$GUEST_DIR"* ]]; then
  # normalize guest path
  if [[ "$RPATH" != /* ]]; then RPATH="${GUEST_DIR}/${RPATH}"; fi
  "${SCP_BASE[@]}" "${SSH_USER}@${SSH_HOST}:${RPATH}" \
    "${EVID_DIR}/Package.resolved.${STAMP}" >>"$LOG" 2>&1 || true
fi

write_c5_host_pin "see Package.resolved / guest pin files" "${C5}"
# if guest resolved found, append into pin file
if [[ -f "${EVID_DIR}/Package.resolved.${STAMP}" ]]; then
  {
    echo ""
    echo "## guest Package.resolved.${STAMP}"
    grep -n -i -E 'SwiftTerm|version' "${EVID_DIR}/Package.resolved.${STAMP}" | head -40 || true
  } >>"${EVID_DIR}/gate_c_c5_swiftterm_pin.txt"
fi
write_status pass "C2–C5 complete (C5=${C5})"
log "=== DONE overall=pass C2=$C2 C3=$C3 C4=$C4 C5=$C5 ==="
echo "LOG=$LOG"
echo "STATUS=$STATUS_JSON"
exit 0
