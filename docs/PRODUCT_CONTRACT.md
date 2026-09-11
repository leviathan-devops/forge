# FORGE product contract (operator-corrected 2026-09-08)

The iPhone **is** the computer. The macOS VM is **only** a test bench.

## Mode 1 — what ships on the phone

A **self-contained Trident coding agent** inside a hidden WKWebView. Same tool class as the Trident example in `docs/FORGE_ENGINEERING_SPECIFICATION.md` §5–§6 + §14.

| Surface | On device | Network |
|---------|-----------|---------|
| Agent brain (Trident + tools + God Loop + subagents) | YES — JS in hidden WKWebView | none |
| Files / git / curated bash | YES — ForgeBridge jail under Documents | none |
| **Python write + run** | YES — write `.py` via bridge; execute via **Pyodide WASM** | none |
| Preview tab | YES — second WKWebView of sandbox HTML/Canvas/WebGL | none |
| LLM tokens | fetch() from device to provider (Keychain, `ThisDeviceOnly`) | **API only** |

**FORBIDDEN in Mode 1**

- Streaming a session off a host `opencode serve` (`runForgeServeTurn`, PTY, `/session` POST).
- Requiring a desktop daemon for the agent to think or write files.
- Shipping code or prompts to a host process to “be the agent.”
- Treating Linux Weston/Chrome as the product.

Device security: no `Process` / `posix_spawn` / real shell; curated `ForgeCommandRunner`; path jail; Pyodide cannot touch iOS FS except through the bridge; secrets in Keychain `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`; no hardcoded servers.

### Tools (parity with Trident/opencode, shimmed)

`read` / `write` / `edit` · `bash` (whitelist: ls/cat/grep/find/mkdir/rm/cp/mv/wc/head/tail/pwd/echo/touch) · `grep`/`glob` · `git` · `http` (LLM fetch) · **`python` (`runPython` + Pyodide)** · Trident: code-audit, deep-planning, problem-solving, context-synthesis, poseidon, gate, status · subagents `trident_build` / `trident_explore` / `trident_planner` as Effect fibers.

Python is **core**: agent writes `foo.py`, then runs it on-device. Soft-reject `Pyodide not available (phase1-stub)` is a product FAIL.

LLM: WKWebView `fetch()` to the configured Zen/API endpoint. Streaming **tokens from the model** is fine. Streaming **the agent session from a host OpenCode** is not.

## Preview tab (same app)

TERMINAL / SPLIT / PREVIEW. Isolated second WKWebView. `renderPreview` / `injectPreviewCode`. This is how you **see** what the on-device agent built — not a VNC of the test VM.

## Test rig (not the product)

```
container-virtual-display  (Weston + NVIDIA, headed, not the host desktop)
        │  vncviewer / scrot of
        ▼
forge-vm  (macos-forge:master, Tahoe, iOS Simulator, FORGE.app)
        │  simctl screenshot / recordVideo
        ▼
host Evidence/play/cycle-*  →  read_file  →  ViL verdict
```

`forge-vm` exists so we can **look** at the iPhone UI. It is not a runtime the phone depends on.
