# CONNECT Spec — in-TUI provider auth for FORGE Mode 1 (SC-11)

## Problem (one sentence)
The Mode 1 TUI has no way to connect an API key + endpoint from inside the app: no slash-command framework exists in `forge-bundle.js`, so a typed `/connect` falls through to the LLM as a prompt, and `SettingsSheet` has provider + key + model but no base-URL field while `ForgeEngine` hardcodes `https://opencode.ai/zen/v1`.

## Verified current state (file:line, read 2026-09-09)
- Live input path: `forge-bundle.js` `inputHandler` → `processWithAgent` → stub `process()` (no vendor `.js` in `Resources/`, so `createPhase1TridentStub` IS the live surface).
- Live command surface: stub `switch (cmd)` — `help/about/status/clear/agent`, `NATIVE_COMMANDS` → `runCommand`, default → `runForgeAgent` (LLM). No `/`-routing; `/connect` would leak to the model.
- Live credentials: `runForgeAgent` reads ONLY `window.__forgeConfig`, set ONLY by Swift `ForgeEngine.injectAPICredentials` (UserDefaults provider/model + Keychain key + launch-env overrides). `forge-config.json` is plugin registry, not credentials.
- Bridge already exposes Keychain: `ForgeBridge.getSecret/setSecret` (Keychain-backed). No `openSettings`, no `promptSecret`, no base-URL anywhere in Settings/UserDefaults/JS-config.
- Request shape (provider `openai` + muse model): POST `<base>/responses`, `Authorization: Bearer <key>`, Zen identity headers attached (ignored by non-Zen hosts). Verified live against OpenCode Go.

## Design
1. **Slash routing (bundle, `process()`)**: intercept inputs starting with `/` before the bare-word switch. Dispatch table: `/help`, `/connect ...`. Unknown slash → local error text, NEVER the LLM (a mistyped key must not reach the model).
2. **`/connect` flow (bundle)**: `/connect` (no args) prints provider-auth status (provider/model/URL/key-presence only, values never printed except non-secret fields) + usage. `/connect provider <id>`, `/connect model <id>`, `/connect url <base>` set non-secret fields (typed text is safe). `/connect key` triggers secure entry (see 4). `/connect test` runs a live minimal model call and reports PASS/FAIL with status code. `/connect status` reprints presence-only status.
3. **Persistence (existing plumbing, no new stores)**: provider/model/URL → `UserDefaults` via `ForgeSettingsKeys` (+ new `apiBaseUrl` key); key → Keychain via existing `setSecret` with `ForgeSettingsKeys.apiKey`. After any change, re-run the `injectAPICredentials` merge and hot-swap `window.__forgeConfig` (no relaunch needed for the session; Keychain gives relaunch persistence).
4. **Secure key entry (Swift, new)**: `promptSecret({title})` bridge method presenting a native `SecureField` alert; returns the value to JS memory only. The key is NEVER written to terminal pixels, logs, meta, or rows (AP-18: a leak fails the wave and rotates the key).
5. **Settings UI (Swift)**: add base-URL `TextField` to `SettingsSheet` `apiConfigurationSection`, saved through the existing `saveSettings()` path.
6. **Only Muse 1.3 contributor.** No other-model support in this wave (operator order).

## Known-bad cases (must refuse with local error text, never hang, never leak)
- Bad/revoked key (401): report + hint to re-run `/connect key`.
- Unreachable endpoint (timeout/DNS): report, keep prior working config.
- Retired model id (deepseek-*, Muse 1.2): refuse at set-time per `ZenModelCatalog.isRetired`.
- Key-like string typed as a slash arg: refuse with leak warning, do not store, do not echo.
- Empty key on a provider that requires one: refuse; session keeps prior config.

## Acceptance (SC-11, all in sim pixels)
Typed `/connect` opens the flow; key + endpoint connect (live model call, zero launch-env overrides); key persists via Keychain across relaunch (quit, relaunch, `/connect status` shows configured, live call succeeds). Watched end-to-end by the vision subagent; row names the take.

## Test plan (repo style: node drives shipped functions)
New `tests/test_mode1_connect.py`: slash-parse table, provider normalize incl. baseUrl, secret routing (key → `setSecret forge.apiKey`, never into log strings), plus every known-bad case above. Green suite that never checks the change fails the gate.
