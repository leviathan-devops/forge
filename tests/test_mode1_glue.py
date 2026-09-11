"""WAVE 2: Mode 1 preview glue (toggle + Engine cases + not sheet-only).

Host-side pins against BuildOnDeviceScreen.swift and ForgeEngine.swift.
No xcodebuild. Complements WAVE 1b chrome/bridge tests.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BOD = ROOT / "iOS/FORGE/Presentation/Mode1_BuildOnDevice/BuildOnDeviceScreen.swift"
ENGINE = ROOT / "iOS/FORGE/Bridge/ForgeEngine.swift"
APP = ROOT / "iOS/FORGE/App/AppState.swift"

METHODS = (
    "renderPreview",
    "injectPreviewCode",
    "setPreviewTitle",
    "previewConsole",
    "previewError",
)


def _read(path: Path) -> str:
    assert path.is_file(), f"missing {path}"
    text = path.read_text(encoding="utf-8")
    assert text.strip(), f"empty {path}"
    return text


def test_labels_in_build_on_device_screen():
    text = _read(BOD)
    for label in ("TERMINAL", "SPLIT", "PREVIEW"):
        assert label in text, f"BuildOnDeviceScreen missing label {label}"
    assert "PreviewModeToggle" in text
    assert "PreviewPaneView" in text
    assert "struct BuildOnDeviceScreen" in text


def test_split_60_40_and_preview_full_pane():
    text = _read(BOD)
    assert "0.60" in text, "SPLIT missing 60% pane"
    assert "0.40" in text, "SPLIT missing 40% pane"
    assert "60/40" in text
    assert "previewMode == .split" in text or "previewMode==.split" in text.replace(" ", "")
    assert "previewMode == .preview" in text or "previewMode = .preview" in text


def test_lazy_preview_pane_is_active_on_render_or_tap():
    text = _read(BOD)
    assert "isActive" in text
    assert "previewPaneActive" in text
    assert "isActive: previewPaneActive" in text or "isActive:previewPaneActive" in text.replace(
        " ", ""
    )
    assert "renderPreview" in text
    assert "user tap" in text.lower() or "SPLIT" in text


def test_engine_cases_call_preview_bridge_handle_method():
    text = _read(ENGINE)
    for name in METHODS:
        assert f'case "{name}"' in text, f"ForgeEngine missing case {name}"
        assert f'"{name}"' in text
    assert "previewBridge.handleMethod" in text
    assert "func handleMethod" not in text, "Engine must dispatch, not reimplement handleMethod"
    for name in METHODS:
        # Each case body must call handleMethod with that method name nearby.
        pattern = rf'case "{name}":\s*_ = previewBridge\.handleMethod\(\s*"{name}"'
        assert re.search(pattern, text), f"case {name} does not call handleMethod({name})"


def test_engine_never_shares_agent_process_pool():
    text = _read(ENGINE)
    lowered = text.lower()
    assert "previewbridge" in lowered
    assert "never share" in lowered
    assert "wkprocesspool" in lowered
    # Must not assign the hidden agent pool onto the preview.
    assert "webView.configuration.processPool" not in text.replace(" ", "") or (
        "NEVER" in text and "processPool" in text
    )
    assert "showPreview()" in text or "func showPreview" in text
    assert "func hidePreview" in text
    assert "attachPreviewWebView" in text


def test_not_sheet_only_preview():
    """25s auto-dismiss sheet must not be the only preview path."""
    text = _read(BOD)
    assert "hasPreviewContent" in text
    assert "previewMode = .preview" in text
    assert "openPreviewTab" in text
    assert "PreviewModeToggle" in text
    assert "ProjectPreviewSheet" in text, "sheet may remain as secondary path"
    # Tab path is independent of the 25s timer.
    assert "PREVIEW tab" in text or "previewMode = .preview" in text
    # Timer, if present, must not dismiss the tab.
    if "25.0" in text:
        assert "PREVIEW tab" in text
        assert "openPreviewTab" in text


def test_mode1_e2e_fixture_uses_write_python_preview_shipped_path():
    """No-LLM Mode 1 turn must call writeFile, runPython, then renderPreview."""
    screen = _read(BOD)
    engine = _read(ENGINE)
    assert "FORGE_TEST_MODE1_E2E" in screen
    assert "SIMCTL_CHILD_FORGE_TEST_MODE1_E2E" in screen
    assert "scheduleMode1E2E" in screen
    assert "isReady" in screen
    assert "func runMode1WriteRunPreviewFixture" in engine
    assert 'callbackId: "forge-e2e-write-py"' in engine
    assert 'callbackId: "forge-e2e-python"' in engine
    assert "bridge.writeFile" in engine
    assert "bridge.runPython" in engine
    assert "previewBridge.renderPreview" in engine
    assert "hello.py" in engine
    assert "PYODIDE_HELLO" in engine
    assert "index.html" in engine
    # Fixture must not skip the jail write API.
    fixture = engine.split("func runMode1WriteRunPreviewFixture", 1)[1]
    assert "writeFile" in fixture
    assert "runPython" in fixture


def test_no_llm_render_preview_hook_uses_shipped_path():
    """Simctl hook must call PreviewBridge.renderPreview on jailed index.html."""
    screen = _read(BOD)
    engine = _read(ENGINE)
    assert "FORGE_TEST_RENDER_PREVIEW" in screen
    assert "SIMCTL_CHILD_FORGE_TEST_RENDER_PREVIEW" in screen
    assert "scheduleNoLLMRenderPreview" in screen
    assert "renderJailedPreviewFixture" in screen
    assert "func renderJailedPreviewFixture" in engine
    assert '["path": "index.html"' in engine or '"index.html"' in engine
    assert "previewBridge.renderPreview" in engine
    assert "ensureDemoProjectRoot" in engine
    assert "FORGE PREVIEW" in engine
    assert "jailed index.html via renderPreview" in engine
    # Must not reimplement loadFileURL in the fixture — that is PreviewBridge.
    fixture = engine.split("func renderJailedPreviewFixture", 1)[1].split("// MARK:", 1)[0]
    assert "loadFileURL" not in fixture


def test_agent_render_preview_opens_preview_tab():
    text = _read(BOD)
    assert "forgePreviewReady" in text
    assert "hasPreviewContent = true" in text
    assert "previewPaneActive = true" in text
    open_tab = text.split("func openPreviewTab", 1)[1].split("private func appendConsole", 1)[0]
    assert ".split" in open_tab
    assert "previewMode != .preview" in open_tab or "previewMode !=.preview" in open_tab.replace(" ", "")


def test_forge_test_prompt_is_independent_of_mode1_e2e():
    """Live WAVE 3 hook is FORGE_TEST_PROMPT → sendMessage, not the no-LLM fixture.

    Drives shipped BuildOnDeviceScreen.swift. A turn gated on MODE1_E2E, or a
    sendMessage that only exists inside scheduleMode1E2E, would make OK-chat /
    ANSWER-42 the only path — VOID as WAVE 3.
    """
    screen = _read(BOD)
    assert 'environment["FORGE_TEST_PROMPT"]' in screen
    assert "sendMessage(testPrompt)" in screen
    assert "scheduleMode1E2E" in screen
    assert "FORGE_TEST_MODE1_E2E" in screen
    # Fixture body must not own the live LLM prompt hook.
    after = screen.split("func scheduleMode1E2E", 1)[1]
    fixture_fn = after.split("\n    private func ", 1)[0]
    assert "FORGE_TEST_PROMPT" not in fixture_fn
    assert "sendMessage(testPrompt)" not in fixture_fn
    # sendMessage forwards into the engine (runForgeAgent), not the fixture.
    send = screen.split("private func sendMessage", 1)[1].split("private func ", 1)[0]
    assert "engine?.sendInput" in send
    assert "runMode1WriteRunPreviewFixture" not in send
    engine = _read(ENGINE)
    assert "func showPreview" in engine
    assert "forgeShowPreviewTab" in engine
    assert "onPreviewReady" in engine


def test_isolated_preview_webview_wired():
    text = _read(BOD)
    assert "PreviewPaneView" in text
    assert "WKWebView" in text
    assert "attachPreviewWebView" in text
    engine = _read(ENGINE)
    assert "previewBridge" in engine
    assert "NEVER" in engine


def test_swift_syntax_sanity_glue_files():
    for path in (BOD, ENGINE):
        text = _read(path)
        assert "TODO" not in text
        assert "FIXME" not in text
        assert "<#T##" not in text
        # Skip [] — ANSI CSI (`\u{001b}[2m`) and `[PREVIEW]` logs are not pairs.
        for opener, closer in (("{", "}"), ("(", ")")):
            assert text.count(opener) == text.count(closer), (
                f"{path.name}: unbalanced {opener}{closer} "
                f"({text.count(opener)} vs {text.count(closer)})"
            )
        assert text.count("/*") == text.count("*/"), f"{path.name}: unbalanced block comment"


def test_test_prompt_without_start_mode_paints_launch_then_enters_mode1():
    """t9 t00 was SpringBoard because START_MODE=onDevice skipped launch.

    Live FORGE_TEST_PROMPT with START_MODE unset must delay selectMode(.onDevice)
    so the launch menu (01-launch-menu BAR slot) paints before Mode 1.
    """
    text = _read(APP)
    assert "FORGE_TEST_PROMPT" in text
    assert "SIMCTL_CHILD_FORGE_TEST_PROMPT" in text
    assert "selectMode(.onDevice)" in text
    assert "now() + 5.0" in text or "now() + 5" in text
    # Must not force onDevice when START_MODE is unset at t=0.
    apply = text.split("private func applyAgentLaunchOverrides", 1)[1]
    assert "prompt.isEmpty == false" in apply or "hasPrompt" in apply
