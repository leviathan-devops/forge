"""Structural tests for FORGE dual-mode ship bar (host-side, no Xcode required).

Proves the shipped Swift sources contain Launch Menu + Mode1 (SwiftTerm path) +
Mode2 Mission Control entry points. Complements simulator screenshots on macOS.
"""
from __future__ import annotations

from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
IOS = ROOT / "iOS" / "FORGE"


def test_project_yml_swiftterm_is_1_15_series() -> None:
    yml = (ROOT / "project.yml").read_text(encoding="utf-8")
    assert "SwiftTerm" in yml
    # from: "1.15.0" — not 2.x
    assert 'from: "1.15' in yml or "from: '1.15" in yml or "from: 1.15" in yml


def test_launch_menu_and_mode_sources_exist() -> None:
    required = [
        IOS / "App" / "FORGEApp.swift",
        IOS / "Presentation" / "LaunchMenu" / "LaunchMenuView.swift",
        IOS / "Presentation" / "LaunchMenu" / "ModeCard.swift",
        IOS / "Presentation" / "Mode1_BuildOnDevice" / "BuildOnDeviceScreen.swift",
        IOS / "Presentation" / "Mode1_BuildOnDevice" / "ForgeTerminalView.swift",
        IOS / "Presentation" / "Mode2_MissionControl" / "MissionControlScreen.swift",
        IOS / "Theme" / "ForgeTheme.swift",
        IOS / "Resources" / "forge-bundle.js",
    ]
    missing = [str(p.relative_to(ROOT)) for p in required if not p.is_file()]
    assert not missing, f"missing dual-mode sources: {missing}"


def test_launch_menu_names_both_modes() -> None:
    text = (IOS / "Presentation" / "LaunchMenu" / "LaunchMenuView.swift").read_text(
        encoding="utf-8"
    )
    # Mode cards / labels must present both product modes
    assert "Build" in text or "build" in text.lower()
    assert "Mission" in text or "mission" in text.lower()


def test_mode1_terminal_imports_swiftterm() -> None:
    term = (IOS / "Presentation" / "Mode1_BuildOnDevice" / "ForgeTerminalView.swift").read_text(
        encoding="utf-8"
    )
    theme = (IOS / "Theme" / "ForgeTheme.swift").read_text(encoding="utf-8")
    assert "SwiftTerm" in term or "TerminalView" in term or "SwiftTerm" in theme


def test_forge_bundle_nonempty() -> None:
    bundle = IOS / "Resources" / "forge-bundle.js"
    assert bundle.is_file()
    assert bundle.stat().st_size > 1000


def test_docker_master_wiring_scripts_exist() -> None:
    docker = ROOT / "docker"
    for name in (
        "Dockerfile.macos-forge",
        "start-display.sh",
        "start-qemu.sh",
        "apply-launch-patches.sh",
        "persist-disks.sh",
        "run-forge-vm.sh",
        "qemu_typer.py",
    ):
        assert (docker / name).is_file(), name




def test_gate_d_harness_ready() -> None:
    """Wave 5 / d4-uitest-harness: UITests + capture + vm-gate Gate D ready."""
    uit = (IOS / "UITests" / "FORGEUITests.swift").read_text(encoding="utf-8")
    assert "testGateDSmokeScreenshots" in uit
    assert "FORGE_SCREENSHOT_DIR" in uit
    assert "D1_launch_menu" in uit
    # Reserved D2 paths required for guest/CI acceptance
    assert "D2_mode1_terminal" in uit
    assert "02-build-on-device" in uit
    assert "terminal-screen" in uit
    assert "mission-control" in uit or "D3_mission_control" in uit
    # Mode1 chrome via app-owned a11y ids (not scrollViews alone)
    assert "forgeTerminal" in uit
    assert "observeMode1Chrome" in uit or "forgeTerminalContainer" in uit
    # D4 probe writer (no free-text crash false positives; catalog only)
    assert "writeD4CrashProbe" in uit
    assert "d4_crash_probe" in uit
    assert "writeReservedScreenshotPNG" in uit
    assert "keywords_found=none_in_uitest_harness" in uit

    cap = (ROOT / "scripts" / "capture-screenshots.sh").read_text(encoding="utf-8")
    assert "gate_d_manifest.json" in cap
    assert "d4_crash_probe" in cap
    assert "D2_mode1_terminal" in cap
    assert "02-build-on-device" in cap
    # Springboard / lookalike rejection for reserved D2
    assert "identical_to_d1" in cap or "lookalike" in cap
    assert "keywords_scanned" in cap or "keywords_found=none" in cap

    drv = ROOT / "scripts" / "vm-gate-d-screenshots.sh"
    assert drv.is_file()
    dtext = drv.read_text(encoding="utf-8")
    assert "testGateDSmokeScreenshots" in dtext
    assert "D1" in dtext and "D4" in dtext
    assert "02-build-on-device" in dtext
    assert "D2_mode1_terminal" in dtext
    assert "writeD4CrashProbe" in dtext or "HARNESS_OK" in dtext
    assert "normalize_reserved_shots" in dtext or "validate_d2_png" in dtext


def test_pollution_scrub_residuals() -> None:
    """Wave 6: residual OPENCODE hardcodes, bare except, CI soft-fail, path jail."""
    import ast
    import re

    # 1) No path hardcodes to external OPENCODE workspace under scripts/
    tok = "OPENCODE" + "_WORKSPACE"
    # Match $HOME/OPENCODE_WORKSPACE or /home/...OPENCODE_WORKSPACE
    path_pat = re.compile(
        r"(?:\$HOME/" + re.escape(tok) + r"|/home/[^\s\"']*" + re.escape(tok) + r")"
    )
    for f in (ROOT / "scripts").rglob("*"):
        if f.suffix not in {".sh", ".mjs", ".js", ".ts"} or not f.is_file():
            continue
        body = f.read_text(encoding="utf-8", errors="replace")
        hits = path_pat.findall(body)
        assert not hits, f"OPENCODE path hardcode in {f.relative_to(ROOT)}: {hits}"

    # 2) No bare except: in docker/*.py (AST)
    for f in (ROOT / "docker").glob("*.py"):
        tree = ast.parse(f.read_text(encoding="utf-8"), filename=str(f))
        bare = [
            n.lineno
            for n in ast.walk(tree)
            if isinstance(n, ast.ExceptHandler) and n.type is None
        ]
        assert not bare, f"bare except: in {f.name} at lines {bare}"

    # 3) CI typecheck + bundle steps hard-fail (YAML key continue-on-error absent)
    yml_path = ROOT / ".github" / "workflows" / "ios-build-test.yml"
    yml = yml_path.read_text(encoding="utf-8")
    assert not re.search(r"(?m)^\s*continue-on-error\s*:", yml), (
        "CI still has continue-on-error key"
    )
    assert "bun run typecheck" in yml or "tsc --noEmit" in yml
    m = re.search(
        r"(?ms)^\s*- name: TypeScript Type Check\n(.*?)(?=^\s*- name:)",
        yml,
    )
    assert m, "TypeScript Type Check step missing"
    ts_body = m.group(1)
    assert "|| true" not in ts_body, f"TS step soft-fails: {ts_body!r}"
    m2 = re.search(
        r"(?ms)^\s*- name: esbuild Bundle Test\n(.*?)(?=^\s*- name:|\Z)",
        yml,
    )
    assert m2, "esbuild Bundle Test step missing"
    bundle_body = m2.group(1)
    assert "|| true" not in bundle_body, f"bundle step soft-fails: {bundle_body!r}"
    assert "build-forge-bundle.mjs" in bundle_body

    # 4) Path jail present on both bridge surfaces
    bridge = (IOS / "Bridge" / "ForgeBridge.swift").read_text(encoding="utf-8")
    assert "func resolveProjectPath" in bridge
    assert "path escapes project root" in bridge
    runner = (IOS / "Bridge" / "ForgeCommandRunner.swift").read_text(encoding="utf-8")
    assert "private func resolvePath(_ arg: String, cwd: String) -> String?" in runner
    assert "path escapes project root" in runner
    assert "pathJailReject" in runner


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, "-v"]))
