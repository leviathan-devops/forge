# FORGE MODE-1 ENGINEERING REPORT v1
**Project:** FORGE iOS (Mode 1 on-device Trident + Pyodide + Preview)
**Date:** 2026-09-08
**Author:** Grok Build Poseidon (gauntlet orch, this loop)
**Baseline:** git branch `master` @ `ce9ff282a15133e2f26ae6898ba8c68b6d77ee18`
**Commit:** `ce9ff282a15133e2f26ae6898ba8c68b6d77ee18` — working tree has uncommitted Mode-1 takeover (bundle/preview/pyodide). HEAD message is residual Wave4-transport; do not treat that commit as THIS-build product SHA.
**Container:** `display-forge` · **Image:** `runtime-grade-container-sandbox:master`
**Guest VM:** `forge-vm` · **Image:** `macos-forge:master`

## ONE-PARAGRAPH SUMMARY

FORGE Mode 1 is a native iOS app whose agent brain is a hidden 0x0 WKWebView running `forge-bundle.js` with on-device tools (read/write/edit/python/bash/grep) and LLM `fetch()` only — `runForgeServeTurn` and host `/session` streaming are gone from the shipped bundle (grep index `-1`). Python executes in that same hidden WebView via vendored Pyodide 0.27.7 (wasm 9.7M) loaded over custom scheme `forgepy://localhost/pyodide/` because `file://` fetch of wasm from `loadHTMLString` does not complete; the numeric result returns to Swift by `webkit.messageHandlers.native.postMessage({method:'__pythonResult'})` rather than JS-only `__forgeNative.resolve`. A second isolated WKWebView (fresh `WKProcessPool`, `nonPersistent` store) is the Preview tab. THIS-build on Tahoe sim (`xcodebuild` `** BUILD SUCCEEDED **` 2026-09-08T09:25:02, install+`SIMCTL_CHILD_FORGE_TEST_MODE1_E2E=1`) produced PREVIEW pixels that read **ANSWER 42** (still SHA `3638e304…`, unlabeled critic 3–0 vs the `ANSWER running…` fixture). That path is proven. The pin is **not** WAVE-4-closed: tape is 80.511667s at 66301 bps (need ≥90s ≥400kbps), `PLAYED:NO` `VIDEO_WATCHED:NO`, live LLM Mode-1 turn was not run (no sim API key), TestFlight residual without Apple ID. So: write-run-preview machinery is functional on the simulator; the product is **not** fully ship-ready.

## THE LIFECYCLE MAP

```
┌────────────────────────────────────────────────────────────────────┐
│FORGE MODE-1 LIFECYCLE  this loop  2026-09-08                       │
│Product = iPhone FORGE.app.  VM = test bench only.                  │
└────────────────────────────────────────────────────────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│WAVE 1a  on-device-agent  SINGULAR                                  │
│write-set  iOS/FORGE/Resources/forge-bundle.js                      │
│kill runForgeServeTurn / host /session stream                       │
│AGENT_TOOLS = read write edit python bash grep                      │
│SHA 65179905cd77a8df578bc00a5c1383673634e8a9e8                      │
│critic  mode1-sessions.png  PASS 3-0 vs BAR                         │
└────────────────────────────────────────────────────────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│WAVE 1b  python + preview chrome  PARALLEL                          │
│pyodide 0.27.7 UMD in Resources/pyodide/                            │
│wasm 9.7M  stdlib 2.3M  pyodide.js 15K                              │
│PreviewModeToggle TERMINAL / SPLIT / PREVIEW                        │
│PreviewPaneView  fresh WKProcessPool + nonPersistent                │
│PreviewBridge  5 methods  5MB jail cap                              │
└────────────────────────────────────────────────────────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│WAVE 2  mode1-glue  SINGULAR                                        │
│BuildOnDeviceScreen + ForgeEngine cases                             │
│SPLIT 60/40  lazy preview  kill 25s sheet-as-only                   │
│hook  SIMCTL_CHILD_FORGE_TEST_MODE1_E2E=1                           │
│write hello.py -> runPython -> write HTML -> Preview                │
└────────────────────────────────────────────────────────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│pyodide-callback INNER  CLOSED this cycle                           │
│JS postMessage __pythonResult to Swift                              │
│scheme forgepy://localhost/pyodide/ + handler                       │
│guest xcodebuild  BUILD SUCCEEDED  09:25:02 PDT                     │
│sim still  ANSWER 42  critic PASS 3-0                               │
└────────────────────────────────────────────────────────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│WAVE 3 fusion  OPEN                                                 │
│tape 80.511667s @ 66301 bps  need >=90s >=400kbps                   │
│PLAYED=NO  VIDEO_WATCHED=NO                                         │
└────────────────────────────────────────────────────────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│WAVE 4 soak  ILLEGAL until WAVE 3 dual critic                       │
│TestFlight / device  residual  no Apple ID                          │
└────────────────────────────────────────────────────────────────────┘
```

## THE ARCHITECTURE

### Dual WebView (spec FORGE-PREVIEW-SPEC-V1.0 §2.1)

```
┌────────────────────────────────────────────────────────────────────┐
│BuildOnDeviceScreen.swift  1202 lines  Mode 1 chrome                │
└────────────────────────────────────────────────────────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│LAYER 3a EXECUTION  hidden agent WKWebView  0x0                     │
│ForgeEngine.swift:161  setURLSchemeHandler forgepy                  │
│ForgeBridge.swift:661  runPython                                    │
│forge-bundle.js  AGENT_TOOLS + native.call(runPython)               │
│PyodideSchemeHandler.swift  serves wasm/js/zip/json                 │
│process pool  THIS config  NEVER given to Preview                   │
└────────────────────────────────────────────────────────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│LAYER 3b PREVIEW  visible WKWebView  isolated                       │
│PreviewPaneView.swift:117  makeIsolatedConfiguration                │
│processPool = WKProcessPool()  FRESH  AP1                           │
│websiteDataStore = nonPersistent  AP2                               │
│PreviewBridge.swift:83  handleMethod  5 names                       │
│maxPreviewFileBytes = 5 * 1024 * 1024                               │
└────────────────────────────────────────────────────────────────────┘
```

The hidden agent view is constructed in `ForgeEngine.configureWebView` (`ForgeEngine.swift:125`). JavaScript is enabled, `websiteDataStore` is non-persistent (`:145`), the `native` script-message handler is registered via `WeakScriptMessageHandler` (`:151-153`), `injectNativeAPI` runs at document start (`:157`), then **before** `WKWebView(frame:configuration:)` the custom scheme is registered:

```
config.setURLSchemeHandler(PyodideSchemeHandler(), forURLScheme: "forgepy")
```

Anchor: `ForgeEngine.swift:161`. Registration after WKWebView init would not apply to that instance.

Preview isolation is a different object. `PreviewPaneView.makeIsolatedConfiguration` (`PreviewPaneView.swift:117-135`) sets `config.processPool = WKProcessPool()` (new instance, AP1) and `config.websiteDataStore = WKWebsiteDataStore.nonPersistent()` (AP2). Host background is `UIColor.forgeBackground` so the pane does not flash white before the WebView exists (AP8, `PreviewPaneHostView.applyForgeBackground` `:20-24`). Lazy: `isActive` false keeps `webView` nil (AP4). WAVE 2 sets `previewPaneActive = true` on first `renderPreview` or E2E (`BuildOnDeviceScreen.swift:411`, `:718-720`).

### Agent tools (bundle)

`iOS/FORGE/Resources/forge-bundle.js:1474-1491` declares `AGENT_TOOLS` as OpenAI-style function tools: `read`, `write`, `write_file`, `edit`, `python`, `bash`, `run_command`, `grep`. The python tool description is verbatim `Run Python on-device via Pyodide`. The live call is `native.call("runPython", { code: pyCode })` at `forge-bundle.js:1674`. `runForgeServeTurn` is absent (`str.find == -1`). `192.168.100` is absent. LLM payload uses `stream: true` for **model tokens**, with `tools: AGENT_TOOLS` (`:1816`) — that is allowed; host session stream is not.

### Python runtime (bridge + scheme)

`ForgeBridge.runPython` (`ForgeBridge.swift:661`) requires `args["code"]` and a callbackId. Missing pyodide directory rejects with `Pyodide runtime not found in app bundle`. Index URL is hardcoded:

```
let indexURL = "forgepy://localhost/pyodide/"
```

Anchor: `:678`. JS loads `pyodide.js` then `pyodide.asm.js` (UMD `_createPyodideModule` preload so `loadPyodide` does not dynamic-import a module URL), then `window.__pyodide = await loader({ indexURL: indexURL })`. Stdout batched handler appends `window.__pyStdout` and posts `__output` **directly** to `messageHandlers.native`, bypassing `window.__forgeTerminalVisible` (that gate is `ForgeEngine.swift:247`: `if (!window.__forgeTerminalVisible) return;`). Execution is `Promise.race` against a 90s timeout (`ForgeBridge.swift` timeout string `Python execution timeout (90s)`). Success posts:

```
method: '__pythonResult'
args: { result: String(result), stdout: String(window.__pyStdout || '') }
callbackId: <Swift id>
```

Anchor: `ForgeBridge.swift:760`. Errors post `__pythonError` (`:768`). `evaluateJavaScript` completionHandler rejects the Swift callback on eval error (`:782-785`).

`PyodideSchemeHandler` (`PyodideSchemeHandler.swift:20`, 272 lines) implements `WKURLSchemeHandler`. `start` dispatches serve onto `ioQueue`. URL `forgepy://localhost/pyodide/pyodide.asm.wasm` maps path `/pyodide/<file>` onto `Bundle.main.url(forResource:withExtension:subdirectory: "pyodide")` with a resourceURL fallback. `..` is rejected. MIME: `.js` `text/javascript`, `.wasm` `application/wasm`, `.zip` `application/zip`, `.json` `application/json`. Response includes `Access-Control-Allow-Origin: *` (`:98`) because the agent document is not same-origin with `forgepy`. `stop` marks the `ObjectIdentifier` cancelled under `NSRecursiveLock` so a later `didFinish` does not trap.

`ForgeEngine` switch (`:756-764`):

```
case "__pythonResult":
    let result = (args["result"] as? String) ?? ""
    let stdout = (args["stdout"] as? String) ?? ""
    if !stdout.isEmpty { handleANSIOutput(stdout) }
    if let cbId = callbackId { resolveCallback(cbId, result: result.isEmpty ? stdout : result) }
case "__pythonError":
    let msg = (args["message"] as? String) ?? "python error"
    if let cbId = callbackId { rejectCallback(cbId, error: msg) }
```

`resolveCallback` (`:1001-1014`) still evals JS `__forgeNative.resolve` for **JS-originated** `native.call` promises, and intercepts E2E ids: `forge-e2e-write-py` / `forge-e2e-write-html` → `e2eWriteCompleted`; `forge-e2e-python` → `e2ePythonFinished`.

### Preview bridge (five methods, jail)

`PreviewBridge.swift:9-15` names the contract: `renderPreview`, `injectPreviewCode`, `setPreviewTitle`, `previewConsole`, `previewError`. `handleMethod` is `:83`. Jail: `resolvePreviewPath` mirrors ForgeBridge (standardize, require descendant of project root). Cap: `static let maxPreviewFileBytes = 5 * 1024 * 1024` (`:27`). ForgeEngine cases dispatch to `previewBridge.handleMethod` (`ForgeEngine.swift:901` comment: NEVER share hidden agent WKProcessPool).

### E2E fixture (no LLM)

```
┌────────────────────────────────────────────────────────────────────┐
│E2E DATA PATH  (no LLM)  proven 2026-09-08                          │
└────────────────────────────────────────────────────────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│1. simctl launch  SIMCTL_CHILD_FORGE_TEST_MODE1_E2E=1               │
│   BuildOnDeviceScreen.applyTestHooks  :747-750                     │
└────────────────────────────────────────────────────────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│2. scheduleMode1E2E  wait isReady + previewWebView                  │
│   attachPreviewWebView  runMode1WriteRunPreviewFixture             │
└────────────────────────────────────────────────────────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│3. writeFile hello.py  callbackId=forge-e2e-write-py                │
│   jail  Documents/projects/FORGE-Demo/hello.py                     │
│   source  print PYODIDE_HELLO; x=6*7; print ANSWER,x; x            │
└────────────────────────────────────────────────────────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│4. resolveCallback -> e2eWriteCompleted                             │
│   runPython(code, callbackId=forge-e2e-python)                     │
│   NO placeholder HTML  (running fixture DELETED)                   │
└────────────────────────────────────────────────────────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│5. ForgeBridge.runPython  :661                                      │
│   indexURL = forgepy://localhost/pyodide/                          │
│   loadScript pyodide.js + pyodide.asm.js                           │
│   loadPyodide({indexURL})  runPython(code)  90s race               │
└────────────────────────────────────────────────────────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│6. PyodideSchemeHandler  start WKURLSchemeTask                      │
│   map URL path -> Bundle pyodide/<file>                            │
│   wasm Content-Type application/wasm  CORS *                       │
└────────────────────────────────────────────────────────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│7. JS postMessage  method=__pythonResult                            │
│   args {result: String(x)=42, stdout}                              │
│   callbackId=forge-e2e-python                                      │
│   NOT window.__forgeNative.resolve  (JS-only no-op)                │
└────────────────────────────────────────────────────────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│8. ForgeEngine case __pythonResult  :756                            │
│   resolveCallback -> e2ePythonFinished(result: 42)                 │
│   HTML  <p class=ans>ANSWER 42</p>  write index.html               │
└────────────────────────────────────────────────────────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│9. previewBridge.renderPreview path=index.html mode=html            │
│   isolated Preview WKWebView loads jailed file                     │
└────────────────────────────────────────────────────────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│10. PIXELS  cycle-forge-py42-sim/mode1-e2e-answer42.png             │
│    SHA 3638e3040d76fb01cf96c6c48ea1bc724d612c31                    │
│    ViL  ANSWER 42  critic 3-0 vs running fixture                   │
└────────────────────────────────────────────────────────────────────┘
```

Python under test (`ForgeEngine.swift:508-512`):

```
print("PYODIDE_HELLO")
x = 6 * 7
print("ANSWER", x)
x
```

Last expression `x` is what Pyodide returns; `String(result)` is `"42"`. Success HTML (`:552`) is `ANSWER \(shown)` with `shown` escaped from that result — not a hardcoded `PYODIDE_HELLO` paragraph and not `ANSWER running…`. Guest jail `Documents/projects/FORGE-Demo/index.html` contained `<p class="ans">ANSWER 42</p>` after the run. `hello.py` on disk was the same four-line source.

### Test rig (container + VM)

```
┌────────────────────────────────────────────────────────────────────┐
│TEST RIG  (not the product)                                         │
└────────────────────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────────────────────┐
│display-forge   image runtime-grade-container-sandbox:master        │
│status running  started 2026-09-08T14:07:31Z  Up 4h                 │
│GPU DeviceRequests capabilities=gpu  DISPLAY=:0  Xvfb               │
└────────────────────────────────────────────────────────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│LOOKS AT  VNC :5901  (look-glass only, not Preview)                 │
└────────────────────────────────────────────────────────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│forge-vm   image macos-forge:master                                 │
│status running  started 2026-09-08T14:07:31Z wait 14:07:26Z         │
│CPU=Haswell-noTSX  docker mem=8589934592  env RAM=4 SMP=4           │
│SSH :50922 user/alpine -> HOME=/Users/useruser                      │
│guest macOS 26.6.2 (25G83)  Xcode iphonesimulator26.5               │
└────────────────────────────────────────────────────────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│iOS Simulator  iPhone 17 Pro                                        │
│UDID 0DE1D698-8187-497A-8EAC-4CF80441F62D  iOS 26.5 Booted          │
│product  com.forge.app  FORGE.app mtime 2026-09-08T09:25:02         │
└────────────────────────────────────────────────────────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│simctl io booted screenshot | recordVideo                           │
│host Evidence/play/cycle-*  then read_file PNG  = ViL               │
└────────────────────────────────────────────────────────────────────┘
```

Measured this session: `docker inspect display-forge` status=running image=`runtime-grade-container-sandbox:master` started `2026-09-08T14:07:31.495404524Z`. `docker inspect forge-vm` status=running image=`macos-forge:master` `HostConfig.Memory=8589934592` started `2026-09-08T14:07:26.948579045Z`. Env: `CPU=Haswell-noTSX` (TAKEOVER forbids Penryn), `RAM=4`, `SMP=4`. Host listens `0.0.0.0:50922` and `0.0.0.0:5901`. SSH `user@127.0.0.1` password alpine lands `HOME=/Users/useruser` `whoami=useruser` macOS 26.6.2 (25G83). Simulator iPhone 17 Pro UDID `0DE1D698-8187-497A-8EAC-4CF80441F62D` iOS 26.5 Booted. Product binary mtime `2026-09-08T09:25:02`. App bundle contains `pyodide.js pyodide.asm.js pyodide.asm.wasm python_stdlib.zip pyodide-lock.json package.json`.

VNC of the Mac desktop is look-glass only. Product stills are `simctl io booted screenshot`. That law is `docs/PRODUCT_CONTRACT.md:38-50`.

## THE BUG LEDGER

| # | bug | root cause | fix | evidence |
|---|---|---|---|---|
| B1 | Mode 1 streamed through host opencode `/session` | `runForgeServeTurn` + `llm-noserve` in bundle | WAVE 1a rewrite AGENT_TOOLS; grep `runForgeServeTurn` = -1 | bundle SHA `65179905…`; `test_no_host_serve_live_path` |
| B2 | Agent tools were write_file + run_command only | incomplete tool table | AGENT_TOOLS at `:1474` includes python/read/edit/bash/grep | `test_agent_tools_include_python_and_core_set` |
| B3 | `runPython` threw phase1-stub | no wasm, stub throw | vendored pyodide 0.27.7 + real loader | `test_forgebridge_runpython_is_not_phase1_stub`; wasm 9.7M |
| B4 | Preview was 25s auto-dismiss sheet | N7 `ProjectPreviewSheet` as only surface | TERMINAL/SPLIT/PREVIEW + isolated WKWebView | `test_not_sheet_only_preview`; still `mode1-toggle.png` |
| B5 | Idle Mode 1 still empty_void vs BAR | no session occupancy / no LLM key | recapture `FORGE_TEST_OPEN_SESSION_LIST=1` | critic PASS 3–0 `mode1-sessions.png` |
| B6 | `SIMCTL_CHILD_` missing, E2E env never entered app | simctl strips unprefixed env | prefix `SIMCTL_CHILD_FORGE_TEST_MODE1_E2E=1` | `BuildOnDeviceScreen.swift:747-748` |
| B7 | E2E ran python before WKWebView ready | `scheduleMode1E2E` did not wait `isReady` + preview attach | wait loop attempt(80) then attach | `BuildOnDeviceScreen.swift:714-730` |
| B8 | Extra `}` / missing class closer in ForgeBridge | edit collision | braces 184/184 then later 189/189 | compile path |
| B9 | Preview HTML showed `ANSWER running…` | JS `__forgeNative.resolve` is not Swift | `__pythonResult` postMessage + Engine case | still SHA `3638e304…`; jail HTML ANSWER 42 |
| B10 | file:// wasm fetch from loadHTMLString blocked | WKWebView file origin | `forgepy` WKURLSchemeHandler | `PyodideSchemeHandler.swift`; indexURL `:678` |
| B11 | stdout silent in chat | `native.output` gated on `__forgeTerminalVisible` | direct `__output` post from setStdout | `ForgeBridge.swift:732-736`; gate remains `:247` |
| B12 | E2E wrote fixture HTML before python finished | `e2ePythonFinished(result: "running…")` | deleted; wait for `__pythonResult` | `ForgeEngine.swift:528-531` |
| B13 | Full `deploy-to-vm.sh` hung packing whole tree | tar walked Evidence/OPENCODE_ACTIVE_PROJECTS | killed; targeted rsync of 3 Bridge files | rsync 5554 bytes sent |
| B14 | Guest `~/bin/xcodegen` is a directory | path confusion | `/Users/useruser/bin/xcodegen/bin/xcodegen generate` | pbxproj 4 hits PyodideSchemeHandler |
| B15 | Host xcodebuild absent | Linux host | guest Tahoe `BUILD SUCCEEDED` | guest log 2026-09-08 09:25:02 |

### B9 detail (the loop closer)

```
┌────────────────────────────────────────────────────────────────────┐
│THE BUG  JS resolve never reached Swift                             │
└────────────────────────────────────────────────────────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│injectNativeAPI resolve  ForgeEngine.swift:229-233                  │
│only completes JS pendingCallbacks[id]                              │
│does NOT postMessage to Swift                                       │
└────────────────────────────────────────────────────────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│runPython used to call                                              │
│window.__forgeNative.resolve(cbId, String(result))                  │
│E2E id forge-e2e-python is NOT in pendingCallbacks                  │
│=> Swift resolveCallback never ran                                  │
└────────────────────────────────────────────────────────────────────┘
                                  ▼
┌────────────────────────────────────────────────────────────────────┐
│FIX  postMessage native handler instead                             │
│method=__pythonResult  callbackId=cbId                              │
│ForgeEngine case __pythonResult -> resolveCallback                  │
└────────────────────────────────────────────────────────────────────┘
```

Mechanism: `injectNativeAPI` (`ForgeEngine.swift:229-233`) implements `resolve` as a JS promise table only. `runPython` is invoked from Swift with callbackId `forge-e2e-python`, which was never inserted into `pendingCallbacks` (those ids are `cb_N` from JS `native.call`). Calling `__forgeNative.resolve('forge-e2e-python', '42')` was a no-op. Meanwhile `e2eWriteCompleted` wrote Preview HTML with `ANSWER running…` so ViL saw a completed-looking page (`cycle-forge-w3-sim/mode1-e2e-late.png` SHA `06eb07b4…`, 153355 bytes) that was a fixture. Fix: JS posts to the same `native` handler Swift already parses (`body["method"]`, `body["callbackId"]`, `body["args"]` at `ForgeEngine.swift:732-733`). Verification: guest THIS-build, simctl E2E, `read_file` of `mode1-e2e-answer42.png` showed green **ANSWER 42**; jailed `index.html` line `<p class="ans">ANSWER 42</p>`; unlabeled critics A/B/C all `VERDICT: PASS` (stamps `projects/forge/.gauntlet-stamps/pyodide-callback{,-a,-b,-c}`).

### B10 detail

Hypothesis confirmed by construction: indexURL was `pyodideDir.absoluteString` (file://). Pyodide then fetch/XHR `file:…/pyodide.asm.wasm`. WKWebView documents created via `loadHTMLString` do not reliably complete those fetches even with allowFileAccess KVC (skipped on simulator, `ForgeEngine.swift:180-183`). Custom scheme is the supported injection of bundle bytes. MIME `application/wasm` is required for `WebAssembly.instantiateStreaming`.

### B13 detail

`scripts/deploy-to-vm.sh` walks the entire forge tree into a gzip tar via paramiko. Process 54952 held ~588MB RSS at 11.5% CPU after 5 minutes with no `pack_bytes` print. Killed. Targeted rsync of `ForgeBridge.swift`, `ForgeEngine.swift`, `PyodideSchemeHandler.swift` to `/Users/useruser/FORGE/iOS/FORGE/Bridge/` (5554 bytes sent). Then xcodegen so the new Swift file entered `FORGE.xcodeproj` (4 pbxproj references). Incremental `xcodebuild` completed in ~1 minute with `** BUILD SUCCEEDED **`.

## THE TESTING LEDGER

| test | scope | how | result |
|---|---|---|---|
| `python3 -m pytest tests/test_mode1_*.py -q` (7 files, 41 tests) | shipped sources, no xcodebuild | host Linux 2026-09-08 this session | **41 passed in 0.20s** |
| `test_no_host_serve_live_path` | bundle must not be serve-session | grep shipped `forge-bundle.js` | PASS (`runForgeServeTurn` index -1) |
| `test_agent_tools_include_python_and_core_set` | AGENT_TOOLS names | parse bundle | PASS |
| `test_forgebridge_runpython_is_not_phase1_stub` | no stub throw; loadPyodide; 90s | read ForgeBridge.swift | PASS |
| `test_pyodide_js_and_wasm_vendored` | pyodide.js + wasm >100k + stdlib | stat Resources/pyodide | PASS |
| `test_runpython_posts_python_result_to_swift` | `__pythonResult` postMessage | read runPython body | PASS (was RED before desks) |
| `test_runpython_indexurl_is_forgepy_scheme` | `forgepy://` | read runPython body | PASS |
| `test_engine_handles_python_result_and_error` | cases + setURLSchemeHandler | read ForgeEngine.swift | PASS |
| `test_e2e_does_not_write_running_fixture_html` | no `running…` | read ForgeEngine.swift | PASS |
| `test_scheme_handler_file_exists` | PyodideSchemeHandler.swift | file + wasm MIME | PASS |
| `test_toggle_labels_terminal_split_preview` | chrome labels | PreviewModeToggle.swift | PASS |
| `test_isolated_wkprocesspool_and_nonpersistent` | AP1 AP2 | PreviewPaneView.swift | PASS |
| `test_preview_bridge_declares_five_spec_methods` | 5 names | PreviewBridge.swift | PASS |
| `test_engine_cases_call_preview_bridge_handle_method` | WAVE 2 switch | ForgeEngine.swift | PASS |
| `test_not_sheet_only_preview` | 25s sheet not only preview | BuildOnDeviceScreen.swift | PASS |
| guest `xcodebuild -scheme FORGE -sdk iphonesimulator -destination "platform=iOS Simulator,name=iPhone 17 Pro" … ARCHS=x86_64 EXCLUDED_ARCHS=arm64` | THIS-build compile | Tahoe guest DerivedData | `** BUILD SUCCEEDED **` 09:25:02 PDT |
| `xcrun simctl install booted FORGE.app` | deploy THIS-build | guest | INSTALL_RC=0 |
| `SIMCTL_CHILD_FORGE_START_MODE=onDevice SIMCTL_CHILD_FORGE_TEST_MODE1_E2E=1 xcrun simctl launch --terminate-running-process booted com.forge.app` | no-LLM write-run-preview | guest | pid 9162 LAUNCH_RC=0 |
| `simctl io booted screenshot` t12/t32/t60/t95 | pixels | four PNGs identical SHA `3638e304…` 146882 bytes | ViL **ANSWER 42** |
| unlabeled critic prepare-critic.py BAR=mode1-e2e-late.png CANDIDATE=mode1-e2e-answer42.png | Gate B vs fixture | 3 explore subagents cwd STAGE | PASS 3–0 |
| `ffprobe` cycle-forge-w3-sim/mode1-e2e.mp4 | WAVE 3 tape | duration/bit_rate | 80.511667s / 66301 bps **FAIL pin bitrate** |
| live LLM Mode 1 turn | thinking+write vs BAR | needs sim API key | **NOT RUN** |

Host pytest is hygiene. Ship-class evidence for python is the sim still + jail HTML + guest BUILD SUCCEEDED, not the 41.

Regression: t12=t32=t60=t95 same SHA means the UI did not regress off ANSWER 42 across ~83s after first paint (first still at t+12s). Previous fixture still remains on disk as FAIL evidence (`cycle-forge-w3-sim/mode1-e2e-late.png` 153355 bytes) and was the BAR for the unlabeled critic.

## THE SPEC MANDATE → ENGINEERING MAP

| the operator said | what was built | evidence |
|---|---|---|
| iPhone is the computer; VM is test only | product = FORGE.app in sim; VM not a runtime dependency | `docs/PRODUCT_CONTRACT.md:3`; stills are simctl not VNC |
| Mode 1 self-contained Trident, no host serve stream | bundle has no `runForgeServeTurn` / `/session` / `192.168.100` | grep index -1; `test_no_host_serve_live_path` |
| tools including write+run Python | AGENT_TOOLS python + `native.call("runPython")` | `forge-bundle.js:1474-1484,1674` |
| Pyodide on device, stub throw is FAIL | vendored 0.27.7 UMD; no `phase1-stub` in ForgeBridge | wasm 9.7M; `test_forgebridge_runpython_is_not_phase1_stub` |
| LLM = WKWebView fetch only | httpRequest / fetch from hidden WV; Keychain ThisDeviceOnly remains | bundle stream:true is model tokens only |
| TERMINAL / SPLIT / PREVIEW | PreviewModeToggle raw values; SPLIT 0.60/0.40 | `PreviewModeToggle.swift:8`; `test_split_60_40_and_preview_full_pane` |
| second isolated WKWebView | fresh WKProcessPool + nonPersistent | `PreviewPaneView.swift:135-131` |
| five preview methods | renderPreview injectPreviewCode setPreviewTitle previewConsole previewError | `PreviewBridge.swift:11-15`; Engine cases |
| ViL on Tahoe sim through headed display | display-forge LOOKS AT forge-vm; simctl stills read_file | still `mode1-e2e-answer42.png`; docker ps both Up |
| never wipe forge-vm-data; never Penryn | volume intact; CPU=Haswell-noTSX | `docker inspect` env CPU=Haswell-noTSX |
| simctl env must use SIMCTL_CHILD_ | hook checks both names | `BuildOnDeviceScreen.swift:747-748` |
| hydra studio desks, min 5, wave law | 7 desks on callback inner; 3 blind critics | subagent ids in session; stamps |
| WAVE 4 critic + 90s 400kbps honest watch | **not done** | ffprobe 80.5s 66kbps; PLAYED=NO |
| TestFlight / physical iPhone | **residual** | no Apple Developer identity |

## THE NUMBERS

```
┌────────────────────────────────────────────────────────────────────┐
│METRIC                              VALUE                           │
│host pytest Mode-1                  41 passed / 0.20s               │
│guest xcodebuild                    BUILD SUCCEEDED                 │
│FORGE.app mtime                     2026-09-08T09:25:02             │
│bundle SHA256                       65179905cd77a8df...             │
│ForgeBridge SHA256                  7216377ad28fc9d4...             │
│ForgeEngine SHA256                  00a8c9b5d6f41edb...             │
│PyodideSchemeHandler SHA256         33094ad4e200f9bd...             │
│ANSWER-42 still SHA256              3638e3040d76fb01...             │
│fixture still SHA256                06eb07b4dd39379c...             │
│pyodide.asm.wasm                    9.7M                            │
│python_stdlib.zip                   2.3M                            │
│pyodide.js                          15K                             │
│tape duration                       80.511667 s                     │
│tape bit_rate                       66301 bps                       │
│tape size                           667254 bytes                    │
│critic pyodide-callback             PASS 3-0                        │
│docker forge-vm memory              8589934592 bytes                │
│sim UDID                            0DE1D698-8187-...               │
│git HEAD                            ce9ff282a15133e2                │
└────────────────────────────────────────────────────────────────────┘
```

Full SHAs (measured `sha256sum` this session):

- `forge-bundle.js` `65179905cd77a8df578bc00a5c1383673634e8a9e896ca801a484694b0130c99`
- `ForgeBridge.swift` `7216377ad28fc9d466b511f2ab945b7031d33621ccf1dede13028ddf527ebdf5`
- `ForgeEngine.swift` `00a8c9b5d6f41edb6e6e1f47bc930274be8fe1d9078cf91e466d83f99970a1da`
- `PyodideSchemeHandler.swift` `33094ad4e200f9bd47741861b92bc4606146de1d4874755af25b7f1b06a498fc`
- `mode1-e2e-answer42.png` `3638e3040d76fb01cf96c6c48ea1bc724d612c31c178f84642eaf3d8eea7d814`
- `mode1-e2e-late.png` (fixture) `06eb07b4dd39379cfefbbf3bcd980be2e73133cdeca7d0977fa9e82e2916490f`

Line counts (`wc -l`): ForgeBridge 850, ForgeEngine 1150, PyodideSchemeHandler 272, BuildOnDeviceScreen 1202, seven test files 725.

## THE FILE MANIFEST

```
projects/forge/
├── iOS/FORGE/Resources/forge-bundle.js          MODIFIED  WAVE 1a
├── iOS/FORGE/Resources/pyodide/                 NEW       WAVE 1b
│   ├── pyodide.js           15K
│   ├── pyodide.asm.js       1.2M
│   ├── pyodide.asm.wasm     9.7M
│   ├── python_stdlib.zip    2.3M
│   └── pyodide-lock.json    110K
├── iOS/FORGE/Resources/preview-bootstrap.js     NEW       WAVE 1b
├── iOS/FORGE/Bridge/ForgeBridge.swift           MODIFIED  runPython
├── iOS/FORGE/Bridge/ForgeEngine.swift           MODIFIED  scheme+E2E+preview
├── iOS/FORGE/Bridge/PyodideSchemeHandler.swift  NEW       this cycle
├── iOS/FORGE/Bridge/PreviewBridge.swift         NEW       WAVE 1b
├── iOS/FORGE/Presentation/Mode1_BuildOnDevice/
│   ├── BuildOnDeviceScreen.swift                MODIFIED  WAVE 2 glue
│   ├── PreviewModeToggle.swift                  NEW
│   ├── PreviewPaneView.swift                    NEW
│   ├── PreviewNavigationDelegate.swift          NEW
│   ├── PreviewToolbarView.swift                 NEW
│   └── ConsoleDrawerView.swift                  NEW
├── tests/test_mode1_*.py                        NEW/MOD   41 tests
├── Evidence/play/cycle-forge-w1a-sim/           EXISTING  session critic
├── Evidence/play/cycle-forge-w2-sim/            EXISTING  toggle/html
├── Evidence/play/cycle-forge-w3-sim/            EXISTING  fixture FAIL
├── Evidence/play/cycle-forge-py42-sim/          NEW       ANSWER 42
├── PIN_GAUNTLET_GOAL.txt                        MODIFIED  CURRENT REALITY
├── GAUNTLET_PROGRESS.md                         MODIFIED  live_inner=fusion
└── .gauntlet-stamps/pyodide-callback            NEW       PASS
```

Provenance of THIS-cycle product writes: ForgeBridge / ForgeEngine / PyodideSchemeHandler / test_mode1_pyodide_callback.py. Preview chrome files mtime 2026-09-08 18:55–19:14 (WAVE 1b/2). Bundle SHA unchanged this inner (WAVE 1a already closed).

## WHAT'S NEEDED FROM THE OPERATOR

1. **No action required** to keep the gauntlet looping WAVE 3 (90s ≥400kbps tape + honest watch). Pin stays `projects/forge/PIN_GAUNTLET_GOAL.txt`.
2. **Sim LLM API key** if you want a live Mode-1 thinking/write turn vs BAR `01-agent-thinking.png` (current python proof is the no-LLM E2E hook by design).
3. **Apple Developer identity** if TestFlight / physical iPhone is in scope. Without it that remainder stays residual — not a code defect.
4. **Do not wipe `forge-vm-data`.** Do not switch QEMU to Penryn. Guest home is `/Users/useruser` even though SSH user is `user`.
5. **Do not treat host pytest 41 as ship.** The ship-class python proof is the sim still + jail HTML + guest BUILD SUCCEEDED.
6. **WAVE 4 soak is illegal** until WAVE 3 dual critic PASS + PLAYED:YES + VIDEO_WATCHED:YES (`GAUNTLET_PROGRESS.md` header `live_inner: fusion`).

Tried and rejected: (a) returning python via `__forgeNative.resolve` — JS-only; (b) file:// indexURL — wasm fetch does not complete; (c) writing `ANSWER running…` HTML first — ViL treated fixture as product; (d) full-tree `deploy-to-vm.sh` — hung packing; (e) `/Users/useruser/bin/xcodegen` as binary — it is a directory; (f) critic BAR = Phase-1 STUB screenshot — empty_midfield FAIL, wrong bar.
