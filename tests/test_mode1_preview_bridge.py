"""WAVE 1b: PreviewBridge + toolbar + console drawer + preview-bootstrap.

Host-side pins against shipped files (no Xcode required). Complements the
ForgeEngine WAVE 2 switch that will case the five preview methods.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IOS = ROOT / "iOS" / "FORGE"
BRIDGE = IOS / "Bridge" / "PreviewBridge.swift"
TOOLBAR = IOS / "Presentation" / "Mode1_BuildOnDevice" / "PreviewToolbarView.swift"
DRAWER = IOS / "Presentation" / "Mode1_BuildOnDevice" / "ConsoleDrawerView.swift"
BOOTSTRAP = IOS / "Resources" / "preview-bootstrap.js"
ENGINE = IOS / "Bridge" / "ForgeEngine.swift"

METHODS = (
    "renderPreview",
    "injectPreviewCode",
    "setPreviewTitle",
    "previewConsole",
    "previewError",
)


def _read(path: Path) -> str:
    assert path.is_file(), f"missing shipped file: {path.relative_to(ROOT)}"
    return path.read_text(encoding="utf-8")


def test_shipped_preview_files_exist():
    missing = [
        str(p.relative_to(ROOT))
        for p in (BRIDGE, TOOLBAR, DRAWER, BOOTSTRAP)
        if not p.is_file()
    ]
    assert not missing, f"WAVE 1b files missing: {missing}"


def test_preview_bridge_declares_five_spec_methods():
    text = _read(BRIDGE)
    for name in METHODS:
        assert name in text, f"{name} missing from PreviewBridge.swift"
        assert re.search(rf"\bfunc {name}\b", text), f"func {name} missing"
    # Engine-must-case comment lists every method (WAVE 2 wiring contract).
    header = text.split("final class PreviewBridge", 1)[0]
    for name in METHODS:
        assert name in header, f"Engine-must-case comment missing {name}"


def test_preview_bridge_jail_mirrors_forge_bridge():
    text = _read(BRIDGE)
    assert "func resolvePreviewPath" in text
    assert "standardizingPath" in text
    assert "hasPrefix" in text
    assert "path escapes project root" in text
    assert ".." in text or "traversal" in text.lower()


def test_preview_bridge_five_mb_cap_and_unsupported_reject():
    text = _read(BRIDGE)
    assert "5 * 1024 * 1024" in text or "maxPreviewFileBytes" in text
    assert "file too large (max 5MB)" in text
    assert "file not found" in text
    assert "unsupported file type" in text
    assert "loadFileURL" in text
    assert "evaluateJavaScript" in text


def test_preview_bridge_isolated_process_pool_not_agent():
    text = _read(BRIDGE)
    assert "WKProcessPool()" in text
    assert "previewProcessPool" in text
    assert "nonPersistent()" in text or "nonPersistent" in text
    # Must not steal the hidden agent WKWebView's pool.
    assert "engine.webView.configuration.processPool" not in text
    assert "ForgeEngine.webView.configuration.processPool" in text or "NEVER share" in text or "never share" in text.lower()
    lowered = text.lower()
    assert "isolated" in lowered or "never share" in lowered or "fresh" in lowered


def test_preview_toolbar_spec_controls():
    text = _read(TOOLBAR)
    assert "struct PreviewToolbarView" in text
    for ident in (
        "previewReload",
        "previewHome",
        "previewConsoleToggle",
        "previewOpenSafari",
    ):
        assert ident in text, ident
    assert "arrow.clockwise" in text
    assert '"house"' in text
    assert '"safari"' in text
    assert '"terminal"' in text
    assert "no content" in text
    assert "consoleBadge" in text
    assert "forgeSurface" in text or "forgeAccent" in text


def test_console_drawer_spec_surface():
    text = _read(DRAWER)
    assert "struct ConsoleDrawerView" in text
    assert "struct ConsoleEntry" in text
    assert "enum ConsoleLevel" in text
    assert "struct PreviewError" in text
    assert "CONSOLE" in text
    assert "no console output" in text
    assert "Clear" in text
    assert "frame(height: 220)" in text
    for level in ("log", "warn", "error", "info", "debug"):
        assert level in text


def test_preview_bootstrap_hooks_console_to_preview_console():
    text = _read(BOOTSTRAP)
    assert "previewConsole" in text
    assert "previewError" in text
    assert "messageHandlers.previewConsole.postMessage" in text
    assert "messageHandlers.previewError.postMessage" in text
    assert "console.log" in text
    assert "sendConsole" in text
    assert "unhandledrejection" in text
    assert "addEventListener('error'" in text or 'addEventListener("error"' in text
    # Console hook must not be a no-op: it forwards level+message.
    assert "level:" in text or "level :" in text
    assert "message:" in text or "message :" in text


def test_preview_bootstrap_injects_readable_default_occupancy():
    """t2/t3/t4 Preview HTML was tiny dark-on-dark. Defaults must be in shipped bootstrap."""
    text = _read(BOOTSTRAP)
    assert 'data-forge-preview-defaults' in text
    assert "font:22px" in text or "font-size:28px" in text
    assert ".ans" in text
    assert "createElement('style')" in text or 'createElement("style")' in text


def test_wave2_must_wire_engine_switch_not_yet_required():
    """WAVE 1b does not edit ForgeEngine; WAVE 2 cases the five methods."""
    engine = _read(ENGINE)
    # Honesty pin: Engine switch is still unwired this wave.
    # PreviewBridge is the handler WAVE 2 will call.
    bridge = _read(BRIDGE)
    assert "handleMethod" in bridge
    for name in METHODS:
        assert f'case "{name}"' in bridge
    # Do not fail if Engine is still missing cases — that is WAVE 2.
    assert "userContentController" in engine
