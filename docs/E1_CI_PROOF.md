# E1 CI Proof — FORGE ios-build-test.yml

**Captured:** 2026-07-29T05:48:00Z  
**Evidence dir:** `tmp/w5_e1_ci_20260729T054734Z/` (API JSON)  
**Stamp:** Wave 5 `ci-or-local-e1`

## Result

| Field | Value |
|-------|-------|
| conclusion | **success** |
| status | completed |
| run_id | 30220688277 |
| run_number | 19 |
| head_branch | master |
| head_sha | `de2d7f2fbcec81c855c3627239c5b240c10b1ef1` |
| event | push |
| created_at | 2026-07-26T21:15:15Z |
| updated_at | 2026-07-26T21:23:48Z |
| **html_url** | **https://github.com/leviathan-devops/forge/actions/runs/30220688277** |
| workflow | `.github/workflows/ios-build-test.yml` |

## Jobs

### TypeScript Shims Check — **success**
- url: https://github.com/leviathan-devops/forge/actions/runs/30220688277/job/89842491884
- steps: Checkout, Setup Bun, Install, TypeScript Type Check, esbuild Bundle Test — all **success**

### Build & Test — **success**
- url: https://github.com/leviathan-devops/forge/actions/runs/30220688277/job/89842491957
- Critical sim steps (all **success**):
  - Generate Xcode Project
  - **Build for iOS Simulator**
  - Check Build Result
  - Boot iOS Simulator & Install
  - **Run UI Tests**
  - Generate App Store Screenshots
  - Upload Build Log / Screenshots / FORGE.app

## E1 acceptance mapping

| Criterion | Status |
|-----------|--------|
| CI green on GitHub (`ios-build-test.yml`) for current master | **PASS** — run 30220688277 conclusion=success on origin/master `@de2d7f2` |
| OR equivalent local sim proof | N/A (Linux host; no xcodebuild). VM Gate C blocked on F-B5 SSH (SSV). Actions is the sim path. |

**Honest residual:** Local working tree has unpushed W1–W2 edits (UI hard-fail, fonts, smoke, docker/). E1 is proven for **current remote master** (`origin/master` = `de2d7f2` = HEAD). Re-push + re-run Actions required before claiming green for the dirty tree.

## How re-verified (Wave 5)

```bash
curl -sS "https://api.github.com/repos/leviathan-devops/forge/actions/workflows/ios-build-test.yml/runs?per_page=20"
curl -sS "https://api.github.com/repos/leviathan-devops/forge/actions/runs/30220688277"
curl -sS "https://api.github.com/repos/leviathan-devops/forge/actions/runs/30220688277/jobs"
git rev-parse HEAD origin/master   # both de2d7f2…
```

Artifacts under `tmp/w5_e1_ci_20260729T054734Z/`:
- `workflow_runs.json`
- `run_30220688277.json`
- `run_30220688277_jobs.json`
