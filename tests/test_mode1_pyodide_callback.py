"""WAVE: runPython posts __pythonResult to Swift; E2E does not write "ANSWER running…".

Host-side pins against ForgeBridge.swift / ForgeEngine.swift / PyodideSchemeHandler.swift.
No xcodebuild. Complements WAVE 1b pyodide-path tests.

FAIL-closed on the old no-op: success must postMessage, not window.__forgeNative.resolve.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BRIDGE = ROOT / "iOS/FORGE/Bridge/ForgeBridge.swift"
ENGINE = ROOT / "iOS/FORGE/Bridge/ForgeEngine.swift"
SCHEME = ROOT / "iOS/FORGE/Bridge/PyodideSchemeHandler.swift"


def _runpython_body(text: str) -> str:
    assert "func runPython" in text, "ForgeBridge missing func runPython"
    body = text.split("func runPython", 1)[1]
    for sentinel in ("// MARK: - Resolve", "private func resolve("):
        if sentinel in body:
            body = body.split(sentinel, 1)[0]
            break
    return body


def _runpython_success_path(body: str) -> str:
    """JS try-branch before catch — the old no-op lived here as __forgeNative.resolve."""
    idx = body.find("catch (error)")
    if idx == -1:
        idx = body.find("} catch")
    if idx == -1:
        return body
    return body[:idx]


def test_runpython_posts_python_result_to_swift():
    text = BRIDGE.read_text(encoding="utf-8")
    body = _runpython_body(text)
    assert "messageHandlers.native.postMessage" in body
    assert "__pythonResult" in body
    success = _runpython_success_path(body)
    assert "messageHandlers.native.postMessage" in success
    assert "__pythonResult" in success
    assert "window.__forgeNative.resolve" not in success, (
        "runPython success path must postMessage __pythonResult, "
        "not window.__forgeNative.resolve"
    )


def test_runpython_indexurl_is_forgepy_scheme():
    text = BRIDGE.read_text(encoding="utf-8")
    body = _runpython_body(text)
    assert "forgepy://" in body
    assert "pyodide" in body


def test_engine_handles_python_result_and_error():
    text = ENGINE.read_text(encoding="utf-8")
    assert 'case "__pythonResult"' in text
    assert 'case "__pythonError"' in text
    assert "setURLSchemeHandler" in text
    assert "PyodideSchemeHandler" in text


def test_e2e_does_not_write_running_fixture_html():
    text = ENGINE.read_text(encoding="utf-8")
    assert "running…" not in text
    assert "ANSWER running" not in text


def test_e2e_html_uses_answer_plus_result():
    text = ENGINE.read_text(encoding="utf-8")
    assert "func e2ePythonFinished" in text
    fn = text.split("func e2ePythonFinished", 1)[1]
    for sentinel in ("func e2eEscape", "func renderJailedPreviewFixture"):
        if sentinel in fn:
            fn = fn.split(sentinel, 1)[0]
            break
    success = fn
    if "else {" in fn:
        success = fn.split("else {", 1)[1]
    assert "ANSWER" in success, "e2ePythonFinished success HTML missing visible ANSWER label"


def test_python_result_prefers_stdout_over_undefined():
    """print() returns JS undefined; TUI must show __pyStdout, not the word undefined.

    cycle-forge-t1/t30.png: `python hello.py` then `undefined`. Root: String(result)
    of runPython(None) is 'undefined', which is nonempty so Swift skipped stdout.
    """
    bridge = BRIDGE.read_text(encoding="utf-8")
    body = _runpython_success_path(_runpython_body(bridge))
    assert "pyStdout" in body
    assert "delivered" in body
    assert "'undefined'" in body or '"undefined"' in body
    engine = ENGINE.read_text(encoding="utf-8")
    py_case = engine.split('case "__pythonResult"', 1)[1].split("case ", 1)[0]
    assert 'result == "undefined"' in py_case or '== "undefined"' in py_case
    assert "stdout" in py_case


def test_pyodide_stdout_batched_appends_newline():
    """t7: two print() calls painted ANSWER 42DONE (no newline in __pyStdout).

    batched() must append a trailing newline to __pyStdout when the chunk
    does not already end with one. Do not double-dump stdout on __pythonResult
    if chunks already posted via __output.
    """
    bridge = BRIDGE.read_text(encoding="utf-8")
    body = _runpython_body(bridge)
    assert "__pyStdout" in body
    assert "batched" in body
    # Must add newline to stdout accumulator, not only to the native __output post.
    assert "charAt" in body or "endsWith" in body or ".last ===" in body or "trailing" in body.lower() or "+ '\\n'" in body or '+ "\\n"' in body or "+ `\\n`" in body
    # Accumulator uses the newline-normalized chunk `t`, not raw String(text).
    assert "var t = String(text)" in body
    assert "__pyStdout" in body and "+ t" in body
    engine = ENGINE.read_text(encoding="utf-8")
    py_case = engine.split('case "__pythonResult"', 1)[1].split("case ", 1)[0]
    # Already streamed via __output; skip duplicate ANSI dump.
    assert "handleANSIOutput(stdout)" not in py_case
    assert "delivered" in py_case
    assert "stdout" in py_case


def test_scheme_handler_file_exists():
    assert SCHEME.is_file(), f"missing {SCHEME}"
    text = SCHEME.read_text(encoding="utf-8")
    assert text.strip(), f"empty {SCHEME}"
    assert "WKURLSchemeHandler" in text
    assert "application/wasm" in text
