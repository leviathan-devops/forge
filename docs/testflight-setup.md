# FORGE — TestFlight Submission Setup

This guide takes you from "no Apple account" to "TestFlight build uploaded"
end to end. Everything in `fastlane/` and `.github/workflows/testflight-upload.yml`
is already configured — you only need to supply credentials and run a handful
of one-time setup commands.

> **TL;DR for the impatient:** Apple Developer account → App ID → `fastlane
> match init` → GitHub Secrets → `git tag v1.0.0-beta.1 && git push --tags`.

---

## 0. Prerequisites

| Requirement | Why |
|-------------|-----|
| Apple Developer Program membership ($99/yr) | Required to sign & distribute |
| A Mac with Xcode 15+ | `fastlane match` / `gym` need the Apple toolchain |
| A **private** empty git repo | Stores encrypted signing certificates |
| Admin access to the GitHub repo | To set Action secrets |
| `brew install fastlane xcodegen` | The build/sign/upload toolchain |

---

## 1. Create an Apple Developer Account

1. Go to **https://developer.apple.com/programs/**
2. Sign in with your Apple ID and enroll ($99/year, auto-renews).
3. Enrollment activates within ~24–48 hours (sometimes instant).

---

## 2. Create an App ID for `com.forge.app`

1. Go to **https://developer.apple.com/account/resources/identifiers/list**
2. Click **+** → **App IDs** → **App**.
3. **Description:** `FORGE`
4. **Bundle ID:** Explicit → `com.forge.app`
5. Under **Capabilities**, enable the ones FORGE uses:
   - **App Sandbox** ✅
   - **iCloud** → check **CloudKit** and use container `iCloud.com.forge.app`
   - **Bonjour Services** (for Mission Control local discovery)
6. Continue → **Register**.

> ⚠️ The Bundle ID **must** be `com.forge.app` (it is hard-coded in
> `project.yml`, the entitlements, and the fastlane config).

---

## 3. Find your Team ID

1. Go to **https://developer.apple.com/account#MembershipDetailsCard**
2. Copy the **Team ID** (a 10-character alphanumeric string, e.g. `A1B2C3D4E5`).
3. Save it — you'll need it for `TEAM_ID` and the `Appfile`.

---

## 4. Create an App Store Connect Record

1. Go to **https://appstoreconnect.apple.com** → **My Apps** → **+** → **New App**.
2. Fill in: Name `FORGE`, Primary Language `English`, Bundle ID `com.forge.app`
   (select from the dropdown — it appears after Step 2), SKU `forge`.
3. **Create.** You can leave all other fields blank for now; `deliver` will
   fill them from `fastlane/deliver/metadata/`.

---

## 5. Set Up fastlane match (Encrypted Certificate Storage)

`match` keeps your distribution certificate + provisioning profile in an
**encrypted** private git repo so every Mac and every CI runner shares one
signing identity. This avoids the nightmare of manual cert management.

### 5a. Create the match repo

Create a **private** git repository, e.g. `your-org/forge-certificates`.
It can be completely empty.

### 5b. Run `match init` (once, on your Mac)

```bash
cd /path/to/FORGE
export MATCH_PASSWORD="<choose-a-strong-passphrase>"   # ENCRYPTS the certs
fastlane match appstore -a com.forge.app \
  --git_url "git@github.com:your-org/forge-certificates.git"
```

`match` will:
1. Create a distribution certificate + provisioning profile in your account.
2. Encrypt them with `MATCH_PASSWORD`.
3. Commit them to the repo.

**Save `MATCH_PASSWORD` somewhere safe** — without it the certs are
unrecoverable. You can also run `fastlane certs` from this repo to do the
same thing via the configured lane.

---

## 6. Create an App-Specific Password

TestFlight upload (`pilot`) needs an **app-specific password** (your normal
Apple ID password will NOT work with fastlane).

1. Go to **https://account.apple.com** → **Sign-In and Security** →
   **App-Specific Passwords**.
2. Generate one labeled `fastlane`.
3. Copy the generated password (format `xxxx-xxxx-xxxx-xxxx`).

---

## 7. Configure GitHub Actions Secrets

In your GitHub repo: **Settings → Secrets and variables → Actions →
New repository secret**. Add:

| Secret name | Value |
|-------------|-------|
| `APPLE_ID` | Your Apple ID email (e.g. `you@example.com`) |
| `FASTLANE_PASSWORD` | The app-specific password from Step 6 |
| `TEAM_ID` | The Team ID from Step 3 |
| `MATCH_GIT_URL` | `git@github.com:your-org/forge-certificates.git` |
| `MATCH_PASSWORD` | The passphrase from Step 5b |

> **If the match repo is private & accessed via HTTPS from CI**, also add
> `MATCH_GIT_BASIC_AUTH` = `your-github-username:your-pat` so fastlane can
> clone it. (Using an SSH deploy key is an alternative.)

---

## 8. (Optional) Fill in the local fastlane config

For running uploads manually from your own Mac, edit these placeholders:

| File | Placeholders to replace |
|------|-------------------------|
| `fastlane/Appfile` | `apple_id`, `team_id`, `itc_team_id` |
| `fastlane/Matchfile` | `git_url` |

The GitHub Actions workflow reads everything from **secrets**, so you only
need to edit these if you run `fastlane beta` locally.

---

## 9. Trigger Your First TestFlight Upload

### From GitHub Actions (recommended)

```bash
git tag v1.0.0-beta.1
git push origin v1.0.0-beta.1
```

The `testflight-upload.yml` workflow fires automatically. Watch it under the
**Actions** tab. On success the build appears in App Store Connect →
**TestFlight** within a few minutes (processing takes ~10–30 min).

### Or, manually from your Mac

```bash
cd /path/to/FORGE
export APPLE_ID="you@example.com"
export FASTLANE_PASSWORD="xxxx-xxxx-xxxx-xxxx"
export TEAM_ID="A1B2C3D4E5"
export MATCH_GIT_URL="git@github.com:your-org/forge-certificates.git"
export MATCH_PASSWORD="<your-match-passphrase>"
fastlane beta
```

---

## 10. Add TestFlight Testers

1. In App Store Connect → **TestFlight** → your build.
2. Add internal testers (up to 100, from your team) or external testers
   (up to 10,000, requires a brief beta review on first submission).
3. FORGE's release notes are pulled from
   `fastlane/deliver/metadata/en-US/release_notes.txt`.

---

## How the Pipeline Fits Together

```
  git tag v* ──────────────────────────────────────┐
                                                   ▼
        ┌─────────────────────────────────────────────────┐
        │            GitHub Actions (macos-14)            │
        │                                                 │
        │  xcodegen generate  ──►  fastlane beta          │
        │                              │                  │
        │         ┌────────────────────┼─────────────┐    │
        │         ▼                    ▼             ▼    │
        │   match (pull certs)   gym (build IPA)  pilot   │
        │   ← MATCH_GIT_URL       scheme: FORGE  upload   │
        │                                                 │
        └─────────────────────────────┬───────────────────┘
                                      ▼
                          ┌─────────────────────┐
                          │   App Store Connect │
                          │      TestFlight     │
                          └─────────────────────┘
```

## Files in This Pipeline

| Path | Purpose |
|------|---------|
| `fastlane/Fastfile` | Lanes: `beta`, `release`, `certs` |
| `fastlane/Appfile` | App identifier + account identity |
| `fastlane/Matchfile` | Encrypted-cert git repo config |
| `fastlane/deliver/Deliverfile` | App Store metadata upload config |
| `fastlane/deliver/metadata/` | App Store text (name, description, …) |
| `fastlane/deliver/screenshots` | Symlink → `screenshots/app-store/` (CI output) |
| `.github/workflows/testflight-upload.yml` | CI trigger on `v*` tags |
| `iOS/FORGE/Resources/PrivacyInfo.xcprivacy` | Apple privacy manifest |
| `docs/testflight-setup.md` | This document |

## Troubleshooting

- **"build number already exists"** → each upload needs a unique build number.
  The Fastfile auto-increments via `git rev-list --count HEAD`; make sure the
  CI checkout uses `fetch-depth: 0` (it does in the workflow).
- **match "Could not unencrypt the repo"** → `MATCH_PASSWORD` is wrong.
- **pilot "authentication failed"** → `FASTLANE_PASSWORD` must be an
  **app-specific** password, not your Apple ID password.
- **"no provisioning profile"** → run `fastlane certs` locally first, or
  ensure the match repo has an `appstore` cert for `com.forge.app`.
