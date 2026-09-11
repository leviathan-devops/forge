"""Structural wiring checks for the Swift half of /connect (CONNECT_SPEC.md).

Swift cannot compile on this host, so these assert the shipped wiring
strings exist and stay consistent: bridge methods, engine dispatch cases,
settings key, load/save paths, and the base-URL field. Behavior of the
shipped JS half is driven via node in test_mode1_connect.py; the live
sim proof exercises both halves together.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BRIDGE = ROOT / "iOS/FORGE/Bridge/ForgeBridge.swift"
ENGINE = ROOT / "iOS/FORGE/Bridge/ForgeEngine.swift"
APPSTATE = ROOT / "iOS/FORGE/App/AppState.swift"
SETTINGS = ROOT / "iOS/FORGE/Presentation/Shared/SettingsSheet.swift"


def _read(p: Path) -> str:
    assert p.is_file(), f"missing shipped file {p}"
    return p.read_text(encoding="utf-8", errors="replace")


def test_bridge_exposes_prompt_secret_and_save_config():
    src = _read(BRIDGE)
    assert "func promptSecret(_ args:" in src
    assert "func saveProviderConfig(_ args:" in src
    assert "isSecureTextEntry = true" in src
    assert "injectAPICredentials()" in src


def test_engine_dispatches_new_methods_and_base_url():
    src = _read(ENGINE)
    assert '"promptSecret"' in src
    assert '"saveProviderConfig"' in src
    assert "ForgeSettingsKeys.apiBaseUrl" in src


def test_app_state_persists_base_url():
    src = _read(APPSTATE)
    assert 'apiBaseUrl' in src
    assert '"forge.apiBaseUrl"' in src
    assert "removeObject(forKey: ForgeSettingsKeys.apiBaseUrl)" in src


def test_settings_sheet_has_url_field():
    src = _read(SETTINGS)
    assert "apiBaseUrlField" in src
    assert "appState.apiBaseUrl = apiBaseUrl" in src
    assert "apiBaseUrl = appState.apiBaseUrl" in src


def test_no_secret_literals_in_connect_surfaces():
    for p in (BRIDGE, ENGINE, APPSTATE, SETTINGS):
        hits = re.findall(r"sk-[A-Za-z0-9]{8,}", _read(p))
        assert hits == [], f"secret literal in {p.name}"
