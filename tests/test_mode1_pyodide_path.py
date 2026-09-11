"""WAVE 1b: shipped Pyodide runtime + ForgeBridge runPython is not a phase1-stub.

Pins:
  - iOS/FORGE/Bridge/ForgeBridge.swift no longer throws phase1-stub
  - loadPyodide({indexURL}) from the bundled pyodide folder (main frame, no importScripts)
  - iOS/FORGE/Resources/pyodide/pyodide.js (+ wasm/stdlib) exists
  - project.yml packs Resources/pyodide as buildPhase resources
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BRIDGE = ROOT / "iOS/FORGE/Bridge/ForgeBridge.swift"
PYODIDE_DIR = ROOT / "iOS/FORGE/Resources/pyodide"
PYODIDE_JS = PYODIDE_DIR / "pyodide.js"
PROJECT_YML = ROOT / "project.yml"

REQUIRED_PYODIDE_FILES = (
    "pyodide.js",
    "pyodide.asm.wasm",
    "python_stdlib.zip",
)


def test_forgebridge_runpython_is_not_phase1_stub():
    text = BRIDGE.read_text(encoding="utf-8")
    assert "phase1-stub" not in text
    assert "Pyodide not available (phase1-stub)" not in text
    assert "func runPython" in text
    assert "loadPyodide" in text
    assert "indexURL" in text
    assert "importScripts" not in text
    assert "__forgeNative.output" in text
    assert "Python execution timeout (90s)" in text


def test_pyodide_js_and_wasm_vendored():
    assert PYODIDE_DIR.is_dir(), "Resources/pyodide/ missing"
    assert PYODIDE_JS.is_file(), "pyodide.js missing"
    assert PYODIDE_JS.stat().st_size > 1_000, f"pyodide.js too small: {PYODIDE_JS.stat().st_size}"
    js = PYODIDE_JS.read_text(encoding="utf-8", errors="replace")
    assert "loadPyodide" in js
    missing = [name for name in REQUIRED_PYODIDE_FILES if not (PYODIDE_DIR / name).is_file()]
    assert not missing, f"pyodide runtime missing {missing}"
    wasm = PYODIDE_DIR / "pyodide.asm.wasm"
    assert wasm.stat().st_size > 100_000, f"wasm too small: {wasm.stat().st_size}"
    stdlib = PYODIDE_DIR / "python_stdlib.zip"
    assert stdlib.stat().st_size > 10_000, f"stdlib too small: {stdlib.stat().st_size}"


def test_project_yml_packs_pyodide_resources():
    text = PROJECT_YML.read_text(encoding="utf-8")
    assert "Resources/pyodide" in text
    idx = text.find("Resources/pyodide")
    window = text[idx : idx + 180]
    assert "buildPhase: resources" in window
