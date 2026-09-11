"""Mode 1: forge-bundle rebuild integrity + shipped wiring for terminal/settings."""
from __future__ import annotations

import hashlib
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = ROOT / "iOS/FORGE/Resources/forge-bundle.js"
ENTRY = ROOT / "forge/src/forge-entry.ts"
BOD = ROOT / "iOS/FORGE/Presentation/Mode1_BuildOnDevice/BuildOnDeviceScreen.swift"
APP = ROOT / "iOS/FORGE/App/FORGEApp.swift"


def test_forge_bundle_exists_and_nontrivial():
    assert BUNDLE.is_file(), "forge-bundle.js missing — run npm run build in forge/"
    size = BUNDLE.stat().st_size
    assert size > 10_000, f"bundle too small: {size}"
    text = BUNDLE.read_text(encoding="utf-8", errors="replace")
    # esbuild IIFE output
    assert "=>" in text or "function" in text


def test_bundle_matches_committed_head():
    """WAVE 1a F1 invert: do NOT require working-tree bytes == git HEAD.

    HEAD byte-equality was the Aug-5 anti-overwrite check, but its failure
    message told operators to `git checkout HEAD -- …/forge-bundle.js`, which
    would wipe honest WAVE 1a edits that are not yet committed.

    Real F1 guard is test_bundle_rebuild_to_temp_only (rebuild must not write
    Resources). This test only pins that the working shipped bundle still
    contains the on-device agent: runForgeAgent + executeAgentTool/python.
    """
    text = BUNDLE.read_text(encoding="utf-8", errors="replace")
    assert "runForgeAgent" in text, "working bundle lost runForgeAgent"
    assert "executeAgentTool" in text, "working bundle lost executeAgentTool"
    assert 'name: "python"' in text, "working bundle lost python tool name"
    assert 'n === "python"' in text or "n === 'python'" in text, (
        "working bundle lost executeAgentTool python dispatch"
    )


def test_bundle_rebuild_to_temp_only():
    """Rebuild to a TEMP path; never write into Resources.

    Asserts (a) the esbuild pipeline still runs, (b) the run did NOT touch the
    committed Resources artifact. Byte-parity between the rebuild and the
    committed engine is intentionally NOT asserted until F2 closes (the engine
    TS sources were never committed; forge/src is stub-era — reconstructing it
    from the committed bundle is tracked as F2 in the 2026-08-15 audit).
    """
    before = hashlib.sha256(BUNDLE.read_bytes()).hexdigest()
    tmp_out = ROOT / "tmp/bundle-check/forge-bundle.js"
    tmp_out.parent.mkdir(parents=True, exist_ok=True)
    if tmp_out.exists():
        tmp_out.unlink()
    r = subprocess.run(
        ["node", "scripts/build-forge-bundle.mjs", "--out", str(tmp_out)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=120,
    )
    assert r.returncode == 0, r.stdout + r.stderr
    assert tmp_out.is_file() and tmp_out.stat().st_size > 10_000
    after = hashlib.sha256(BUNDLE.read_bytes()).hexdigest()
    assert after == before, "rebuild wrote into Resources/ — FORBIDDEN (F1)"


def test_mode1_terminal_and_wiring():
    bod = BOD.read_text(encoding="utf-8")
    # ChatStore-era Mode 1 (post Aug-4 overhaul): the raw terminal lives in a
    # .sheet via TerminalSheet (anti-pattern AP3), the chat surface is
    # ChatStore/TranscriptView, and the screen owns the engine + bridge.
    assert "TerminalSheet" in bod
    assert "ForgeTerminalView" in bod
    assert "ChatStore" in bod
    assert "SettingsSheet()" in bod
    assert ".environmentObject(appState)" in bod
    assert "ForgeEngine" in bod or "engine" in bod


def test_root_sheets_inject_app_state():
    app = APP.read_text(encoding="utf-8")
    assert "SettingsSheet()" in app
    assert "ProjectManagerSheet()" in app
    # both sheets must receive appState
    assert app.count(".environmentObject(appState)") >= 2
