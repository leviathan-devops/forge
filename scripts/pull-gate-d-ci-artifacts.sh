#!/usr/bin/env bash
# pull-gate-d-ci-artifacts.sh — Host-side Gate D evidence from GitHub Actions
# when macOS guest SSH (B5) is unavailable.
#
# Maps real UITest PNGs into OUTPUT_DIR:
#   D1_launch_menu.png / 01-launch-menu.png
#   D2_mode1_terminal.png / 02-build-on-device.png  (only if not launch-duplicate)
#   D3_mission_control.png / 03-mission-control.png
#   gate_d_manifest.json + SOURCE.txt
#
# Usage: bash scripts/pull-gate-d-ci-artifacts.sh [OUTPUT_DIR] [STAMP_DIR]
# Auth: $GITHUB_TOKEN | $GH_TOKEN | ~/.netrc (machine github.com password …)
#
set -euo pipefail

FORGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$FORGE_ROOT/ui-screenshots}"
STAMP_DIR="${2:-}"
REPO="${GITHUB_REPOSITORY:-leviathan-devops/forge}"
WORKFLOW="${GATE_D_CI_WORKFLOW:-ios-build-test.yml}"
RUN_ID="${GATE_D_CI_RUN_ID:-}"
API="https://api.github.com"
TMP="${FORGE_ROOT}/tmp/ci_artifacts_gate_d_pull_$$"
mkdir -p "$OUT" "$TMP"
trap 'rm -rf "$TMP"' EXIT

log() { echo "[pull-gate-d-ci] $*"; }

resolve_token() {
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then printf '%s' "$GITHUB_TOKEN"; return; fi
  if [[ -n "${GH_TOKEN:-}" ]]; then printf '%s' "$GH_TOKEN"; return; fi
  if [[ -f "$HOME/.netrc" ]]; then
    python3 -c 'from pathlib import Path; import re,sys; t=Path.home().joinpath(".netrc").read_text(); m=re.search(r"machine\s+github\.com[\s\S]{0,200}?password\s+(\S+)", t); sys.stdout.write(m.group(1) if m else "")'
    return
  fi
  printf ''
}

TOKEN="$(resolve_token)"
if [[ -z "$TOKEN" ]]; then
  log "ERROR: no GitHub token (GITHUB_TOKEN/GH_TOKEN/.netrc)"
  exit 4
fi

AUTH_HDR=( -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" )

if [[ -z "$RUN_ID" ]]; then
  log "resolve latest completed workflow run for $WORKFLOW"
  RUN_ID=$(curl -sS "${AUTH_HDR[@]}" \
    "$API/repos/$REPO/actions/workflows/$WORKFLOW/runs?per_page=20" \
    | python3 -c 'import json,sys
d=json.load(sys.stdin)
for r in d.get("workflow_runs") or []:
    if r.get("status")=="completed":
        print(r["id"]); break
else:
    raise SystemExit("no completed runs")
')
fi
log "run_id=$RUN_ID repo=$REPO"

ART_JSON="$TMP/artifacts.json"
curl -sS "${AUTH_HDR[@]}" "$API/repos/$REPO/actions/runs/$RUN_ID/artifacts" >"$ART_JSON"
python3 - "$ART_JSON" "$TMP/ids.txt" <<'PY'
import json, sys
from pathlib import Path
arts = json.loads(Path(sys.argv[1]).read_text()).get("artifacts") or []
want = {"ui-test-attachments", "app-store-screenshots", "screenshots", "ui-test-log"}
lines = []
for a in arts:
    if a["name"] in want and not a.get("expired"):
        lines.append("%s\t%s" % (a["id"], a["name"]))
Path(sys.argv[2]).write_text("\n".join(lines) + ("\n" if lines else ""))
print("artifacts", [(a["name"], a["id"], a.get("expired")) for a in arts])
PY

if [[ ! -s "$TMP/ids.txt" ]]; then
  log "ERROR: no usable artifacts on run $RUN_ID"
  exit 5
fi

while IFS=$'\t' read -r id name; do
  [[ -z "${id:-}" ]] && continue
  log "download $name ($id)"
  curl -sS -L "${AUTH_HDR[@]}" -o "$TMP/${name}.zip" \
    "$API/repos/$REPO/actions/artifacts/${id}/zip"
  mkdir -p "$TMP/$name"
  unzip -qo "$TMP/${name}.zip" -d "$TMP/$name"
done < "$TMP/ids.txt"

export GATE_D_PULL_TMP="$TMP" GATE_D_PULL_OUT="$OUT" GATE_D_PULL_REPO="$REPO" GATE_D_PULL_RUN="$RUN_ID"
python3 <<'PY'
import json, hashlib, shutil, os
from pathlib import Path
from datetime import datetime, timezone

tmp = Path(os.environ["GATE_D_PULL_TMP"])
out = Path(os.environ["GATE_D_PULL_OUT"])
repo = os.environ.get("GATE_D_PULL_REPO", "")
run_id = os.environ.get("GATE_D_PULL_RUN", "")
out.mkdir(parents=True, exist_ok=True)

att_root = tmp / "ui-test-attachments"
cands = list(att_root.rglob("manifest.json"))
manifest = None
base = att_root
if cands:
    manifest = json.loads(cands[0].read_text())
    base = cands[0].parent

def sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()

mapped = {}
mapped_src = {}
if isinstance(manifest, list):
    for entry in manifest:
        for att in entry.get("attachments") or []:
            name = (att.get("suggestedHumanReadableName") or "")
            fn = att.get("exportedFileName") or ""
            if not fn.lower().endswith(".png"):
                continue
            src = base / fn
            if not src.exists():
                continue
            low = name.lower()
            if "d1_launch" in low or "01_launch" in low or low.startswith("launchmenu"):
                mapped.setdefault("D1", src); mapped_src.setdefault("D1", "uitest:"+name)
            if "d2_mode1" in low or "terminal-screen" in low or "02_build" in low or "buildondevice" in low:
                mapped.setdefault("D2", src); mapped_src.setdefault("D2", "uitest:"+name)
            if "d3_mission" in low or "mission-control" in low or "03_mission" in low:
                mapped.setdefault("D3", src); mapped_src.setdefault("D3", "uitest:"+name)

# App-store only for D1 if missing; never promote app-store D2/D3 without visual check
app_store = tmp / "app-store-screenshots"
app_map = {}
for pth in app_store.rglob("*.png"):
    n = pth.name.lower()
    if n.startswith("01-launch") or n.startswith("d1"):
        app_map.setdefault("D1", pth)
    if n.startswith("02-build") or n.startswith("d2"):
        app_map.setdefault("D2", pth)
    if n.startswith("03-mission") or n.startswith("d3"):
        app_map.setdefault("D3", pth)
if "D1" not in mapped and "D1" in app_map:
    mapped["D1"] = app_map["D1"]; mapped_src["D1"] = "app-store"

def lookalike(a: Path, b: Path, mse_thresh: float = 80.0) -> bool:
    """True if images are visually near-identical (launch-fallback trap)."""
    try:
        from PIL import Image
        import numpy as np
        A = np.asarray(Image.open(a).convert("RGB").resize((64, 128)), dtype=float)
        B = np.asarray(Image.open(b).convert("RGB").resize((64, 128)), dtype=float)
        return float(((A - B) ** 2).mean()) < mse_thresh
    except Exception:
        return sha(a) == sha(b)

# Promote app-store D3 only if not a launch lookalike
if "D3" not in mapped and "D3" in app_map:
    if "D1" in mapped and lookalike(app_map["D3"], mapped["D1"]):
        mapped_src["D3_rejected"] = "app-store_launch_lookalike"
    else:
        mapped["D3"] = app_map["D3"]; mapped_src["D3"] = "app-store"

# Promote app-store D2 only if NOT launch lookalike (usually is)
if "D2" not in mapped and "D2" in app_map:
    if "D1" in mapped and lookalike(app_map["D2"], mapped["D1"]):
        mapped_src["D2_rejected"] = "app-store_launch_lookalike"
    else:
        mapped["D2"] = app_map["D2"]; mapped_src["D2"] = "app-store"

results = {"D1": "fail", "D2": "fail", "D3": "fail", "D4": "fail"}
files = {}

if "D1" in mapped:
    for name in ("D1_launch_menu.png", "01-launch-menu.png"):
        shutil.copy2(mapped["D1"], out / name)
    results["D1"] = "pass"
    files["D1"] = {"src": str(mapped["D1"]), "origin": mapped_src.get("D1"), "sha256": sha(mapped["D1"]), "bytes": mapped["D1"].stat().st_size}

if "D3" in mapped:
    # if D3 is lookalike of D1, fail
    if "D1" in mapped and lookalike(mapped["D3"], mapped["D1"]):
        results["D3"] = "partial"
        files["D3"] = {"src": str(mapped["D3"]), "origin": mapped_src.get("D3"), "sha256": sha(mapped["D3"]), "bytes": mapped["D3"].stat().st_size, "note": "launch_lookalike"}
    else:
        for name in ("D3_mission_control.png", "03-mission-control.png"):
            shutil.copy2(mapped["D3"], out / name)
        results["D3"] = "pass"
        files["D3"] = {"src": str(mapped["D3"]), "origin": mapped_src.get("D3"), "sha256": sha(mapped["D3"]), "bytes": mapped["D3"].stat().st_size}

if "D2" in mapped:
    d2 = mapped["D2"]
    if "D1" in mapped and (sha(d2) == sha(mapped["D1"]) or lookalike(d2, mapped["D1"])):
        results["D2"] = "partial"
        files["D2"] = {
            "src": str(d2),
            "origin": mapped_src.get("D2"),
            "sha256": sha(d2),
            "bytes": d2.stat().st_size,
            "note": "launch_lookalike_or_identical",
        }
        # do NOT copy as D2_mode1_terminal.png
    else:
        for name in ("D2_mode1_terminal.png", "02-build-on-device.png"):
            shutil.copy2(d2, out / name)
        results["D2"] = "pass"
        files["D2"] = {"src": str(d2), "origin": mapped_src.get("D2"), "sha256": sha(d2), "bytes": d2.stat().st_size}
else:
    if mapped_src.get("D2_rejected"):
        files["D2"] = {"note": mapped_src["D2_rejected"]}

if results["D2"] == "pass" and results["D1"] == "pass":
    results["D4"] = "pass"
elif results["D1"] == "pass":
    results["D4"] = "fail"

if results["D1"] == "pass" and results["D2"] == "pass" and results["D3"] == "pass":
    overall = "pass"
elif results["D1"] == "pass" or results["D3"] == "pass":
    overall = "partial"
else:
    overall = "fail"

stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
man = {
    "stamp": stamp,
    "overall": overall,
    "source": "ci_artifact_pull",
    "repo": repo,
    "run_id": run_id,
    "gates": {
        "D1_launch_menu": results["D1"],
        "D2_mode1_terminal": results["D2"],
        "D3_mission_control": results["D3"],
        "D4_no_crash_smoke": results["D4"],
    },
    "files": files,
    "note": "Host pull via pull-gate-d-ci-artifacts.sh; D2 pass requires non-launch Mode1 PNG",
}
(out / "gate_d_manifest.json").write_text(json.dumps(man, indent=2) + "\n")
(out / "SOURCE.txt").write_text(
    "Gate D CI artifact pull %s\nrepo=%s\nrun_id=%s\noverall=%s D1=%s D2=%s D3=%s D4=%s\nfiles=%s\n"
    % (stamp, repo, run_id, overall, results["D1"], results["D2"], results["D3"], results["D4"], json.dumps(files, indent=2))
)
rb = out / "README_BLOCKED.txt"
if rb.exists() and (results["D1"] == "pass" or results["D3"] == "pass"):
    rb.unlink()
print(json.dumps(man, indent=2))
if overall == "fail":
    raise SystemExit(1)
PY

if [[ -n "$STAMP_DIR" ]]; then
  mkdir -p "$STAMP_DIR"
  cp -a "$OUT"/. "$STAMP_DIR"/ 2>/dev/null || true
fi
log "done OUT=$OUT"
