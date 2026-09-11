"""Zen catalog must track live OpenCode Zen models, not the August freeze.

Pins:
  - default is muse-spark-1.3-contributor (operator lockdown: single allowed model)
  - deepseek-v4-flash-free is retired (not default)
  - muse-spark-1.3-contributor-free is retired (not default)
  - live GET https://opencode.ai/zen/v1/models
  - DialogModelView reads ZenModelCatalog, not a frozen 1.2 list
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "iOS/FORGE/Core/ZenModelCatalog.swift"
DIALOG = ROOT / "iOS/FORGE/Presentation/Shared/DialogModelView.swift"
APP = ROOT / "iOS/FORGE/App/AppState.swift"
ENGINE = ROOT / "iOS/FORGE/Bridge/ForgeEngine.swift"
BUNDLE = ROOT / "iOS/FORGE/Resources/forge-bundle.js"

DEFAULT = "muse-spark-1.3-contributor"
RETIRED = "deepseek-v4-flash-free"
RETIRED_FREE_13 = "muse-spark-1.3-contributor-free"
OLD_MUSE = "muse-spark-1.2-contributor-free"


def test_catalog_file_fetches_live_zen_models():
    text = CATALOG.read_text(encoding="utf-8")
    assert "https://opencode.ai/zen/v1/models" in text
    assert DEFAULT in text
    assert "retiredIDs" in text
    assert RETIRED in text
    assert "Bearer public" in text


def test_dialog_uses_live_catalog_not_frozen_august_list():
    text = DIALOG.read_text(encoding="utf-8")
    assert "ZenModelCatalog.shared" in text
    assert "catalogStore.refresh" in text
    assert OLD_MUSE not in text
    assert 'id: "deepseek-v4-flash-free"' not in text


def test_defaults_are_muse_13_not_deepseek():
    app = APP.read_text(encoding="utf-8")
    engine = ENGINE.read_text(encoding="utf-8")
    bundle = BUNDLE.read_text(encoding="utf-8")
    assert "ZenModelCatalog.defaultModelID" in app
    assert "ZenModelCatalog.defaultModelID" in engine
    assert DEFAULT in bundle
    assert 'modelName: String = "muse-spark-1.2-contributor-free"' not in app
    assert '?? "deepseek-v4-flash-free"' not in app


def test_appstate_refreshes_live_catalog_on_launch():
    app = APP.read_text(encoding="utf-8")
    assert "ZenModelCatalog.shared.refresh" in app
    assert "migrateModelToLiveCatalog" in app


IDENTITY = ROOT / "iOS/FORGE/Core/ZenClientIdentity.swift"
BRIDGE = ROOT / "iOS/FORGE/Bridge/ForgeBridge.swift"


def test_zen_client_identity_stamps_opencode_session_headers():
    ident = IDENTITY.read_text(encoding="utf-8")
    assert "x-opencode-session" in ident
    assert "x-opencode-request" in ident
    assert "x-opencode-project" in ident
    assert "x-opencode-client" in ident
    assert 'userAgent = "opencode/' in ident
    # Header *key* must be stamped, not only the constant name.
    assert '"User-Agent": userAgent' in ident or '"User-Agent"' in ident
    bridge = BRIDGE.read_text(encoding="utf-8")
    assert bridge.count("ZenClientIdentity.apply(to: &request)") >= 2
    engine = ENGINE.read_text(encoding="utf-8")
    assert "sessionID" in engine
    assert "userAgent" in engine
    bundle = BUNDLE.read_text(encoding="utf-8")
    assert "zenIdentityHeaders" in bundle
    assert "x-opencode-session" in bundle
    # Live fetch fallback in the bundle must stamp the same session header.
    assert 'h["x-opencode-session"]' in bundle or "x-opencode-session" in bundle
    assert 'h["User-Agent"]' in bundle
    assert "opencode/1.14.51" in bundle
    ident_apply = bridge.count("ZenClientIdentity.apply(to: &request)")
    assert ident_apply >= 2, f"ForgeBridge must stamp identity on httpRequest+stream, got {ident_apply}"


def test_single_model_lockdown_muse_13_paid_only():
    catalog = CATALOG.read_text(encoding="utf-8")
    assert 'allowedModelID = "muse-spark-1.3-contributor"' in catalog
    assert RETIRED_FREE_13 in catalog
    bridge = BRIDGE.read_text(encoding="utf-8")
    assert "allowedModelID" in bridge
    assert "only model allowed" in bridge
    bundle = BUNDLE.read_text(encoding="utf-8")
    assert "only model allowed: muse-spark-1.3-contributor" in bundle
    assert "muse-spark-1.3-contributor-free" not in bundle
    assert "configured (" in bundle and "chars)" in bundle
    assert "python stdout bytes:" in bundle
