"""WAVE 1b: Mode 1 preview chrome (toggle + isolated pane + nav sandbox).

Reads the three shipped Swift files only. Asserts chrome labels TERMINAL,
SPLIT, PREVIEW and the isolated-preview contract (fresh WKProcessPool,
nonPersistent store). No xcodebuild.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHROME_DIR = ROOT / "iOS/FORGE/Presentation/Mode1_BuildOnDevice"
TOGGLE = CHROME_DIR / "PreviewModeToggle.swift"
PANE = CHROME_DIR / "PreviewPaneView.swift"
NAV = CHROME_DIR / "PreviewNavigationDelegate.swift"
SHIPPED = (TOGGLE, PANE, NAV)


def _read(path: Path) -> str:
    assert path.is_file(), f"missing shipped preview-chrome file: {path}"
    text = path.read_text(encoding="utf-8")
    assert text.strip(), f"empty shipped preview-chrome file: {path}"
    return text


def _all_shipped() -> str:
    return "\n".join(_read(p) for p in SHIPPED)


def test_preview_chrome_files_exist():
    for path in SHIPPED:
        assert path.is_file(), f"missing {path}"
        assert path.stat().st_size > 200, f"{path.name} too small"


def test_toggle_labels_terminal_split_preview():
    text = _all_shipped()
    for label in ("TERMINAL", "SPLIT", "PREVIEW"):
        assert label in text, f"preview chrome missing label {label}"
    toggle = _read(TOGGLE)
    assert "enum PreviewMode" in toggle
    assert 'case terminal = "TERMINAL"' in toggle
    assert 'case split    = "SPLIT"' in toggle or 'case split = "SPLIT"' in toggle
    assert 'case preview  = "PREVIEW"' in toggle or 'case preview = "PREVIEW"' in toggle
    assert "struct PreviewModeToggle" in toggle


def test_isolated_wkprocesspool_and_nonpersistent():
    pane = _read(PANE)
    assert "WKProcessPool" in pane
    assert "nonPersistent" in pane
    assert "WKWebsiteDataStore.nonPersistent()" in pane or ".nonPersistent()" in pane
    assert "config.processPool = WKProcessPool()" in pane
    # Isolation contract — never share the hidden agent WebView's pool.
    lowered = pane.lower()
    assert "never share" in lowered
    assert "fresh" in lowered
    assert "struct PreviewPaneView" in pane
    assert "isOpaque = false" in pane
    assert "forgeBackground" in pane


def test_navigation_delegate_sandboxes_unexpected_nav():
    nav = _read(NAV)
    assert "final class PreviewNavigationDelegate" in nav
    assert "WKNavigationDelegate" in nav
    assert "decisionHandler(.cancel)" in nav
    assert "isFileURL" in nav
    assert 'scheme == "about"' in nav or 'scheme == "about"' in nav.replace(" ", "")
    assert "data" in nav
    assert "previewConsole" in nav
    assert "previewError" in nav


def test_swift_syntax_sanity():
    """Brace/paren/bracket balance + no leftover placeholders. Linux-safe."""
    for path in SHIPPED:
        text = _read(path)
        assert "TODO" not in text
        assert "FIXME" not in text
        assert "<#T##" not in text
        for opener, closer in (("{", "}"), ("(", ")"), ("[", "]")):
            assert text.count(opener) == text.count(closer), (
                f"{path.name}: unbalanced {opener}{closer} "
                f"({text.count(opener)} vs {text.count(closer)})"
            )
        assert text.count("/*") == text.count("*/"), f"{path.name}: unbalanced block comment"
        assert '"""' not in text, f"{path.name}: unexpected python-style triple quote"
