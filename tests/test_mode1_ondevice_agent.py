"""WAVE 1a: shipped Mode 1 bundle is an on-device agent, not host serve.

Pins acceptance (a) and (c) against iOS/FORGE/Resources/forge-bundle.js:
  (a) live AGENT_TOOLS include read, write, edit, bash, grep, python
  (c) runForgeServeTurn / live POST /session / llm-noserve are gone

Does not assert Pyodide execution (WAVE 1b) or TERMINAL/SPLIT/PREVIEW (WAVE 1b/2).
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = ROOT / "iOS/FORGE/Resources/forge-bundle.js"

REQUIRED_TOOLS = ("read", "write", "edit", "bash", "grep", "python")


def _shipped_bundle_text() -> str:
    assert BUNDLE.is_file(), "forge-bundle.js missing — WAVE 1a ships this artifact"
    return BUNDLE.read_text(encoding="utf-8", errors="replace")


def _agent_tools_block(text: str) -> str:
    marker = "var AGENT_TOOLS = ["
    start = text.find(marker)
    assert start >= 0, "AGENT_TOOLS missing from shipped bundle"
    i = start + len(marker)
    depth = 1
    while i < len(text) and depth:
        ch = text[i]
        if ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
        i += 1
    assert depth == 0, "AGENT_TOOLS array did not close"
    return text[start:i]


def _agent_tool_names(text: str) -> list[str]:
    block = _agent_tools_block(text)
    names = re.findall(r'function:\s*\{\s*name:\s*"([^"]+)"', block)
    assert names, "AGENT_TOOLS has no function.name entries"
    return names


def test_agent_tools_include_python_and_core_set():
    """(a) Live tool list includes python plus read/write/edit/bash/grep."""
    text = _shipped_bundle_text()
    names = _agent_tool_names(text)
    missing = [t for t in REQUIRED_TOOLS if t not in names]
    assert not missing, f"AGENT_TOOLS missing {missing}; have {names}"
    assert "python" in names
    # Dispatch must actually handle python, not just advertise it.
    assert 'n === "python"' in text or "n === 'python'" in text
    assert "executeAgentTool" in text


def test_no_host_serve_live_path():
    """(c) Host opencode serve is not the Mode 1 turn path."""
    text = _shipped_bundle_text()
    assert "runForgeServeTurn" not in text
    assert "serveMode" not in text
    assert "llm-noserve" not in text
    assert "192.168.100" not in text
    # HTTP path literals targeting host /session (native session:chat is not this)
    assert '"/session"' not in text
    assert "'/session'" not in text
    assert "`/session`" not in text
    assert not re.search(r"""['"][^'"]*\/session(?:\?|/|"|'|$)""", text)
    assert not re.search(r"fetch\s*\([^;]{0,400}/session", text, re.DOTALL)
    assert not re.search(r"httpRequest(?:Stream)?\s*\([^;]{0,400}/session", text, re.DOTALL)
    assert not re.search(r"method:\s*[\"']POST[\"'][^;]{0,400}/session", text, re.DOTALL)
    assert "runForgeAgent" in text


def test_swift_input_aliases_oninput_to_run_forge_agent():
    """Live TUI sendMessage → ForgeEngine.sendInput → __forgeInput → __forgeOnInput.

    Bundle listens on __forgeOnInput; Swift injects the alias. Missing alias is
    how a FORGE_TEST_PROMPT launch would never reach runForgeAgent.
    """
    engine = ROOT / "iOS/FORGE/Bridge/ForgeEngine.swift"
    et = engine.read_text(encoding="utf-8")
    assert "window.__forgeInput = function(data)" in et
    assert "window.__forgeOnInput" in et
    assert "func sendInput" in et
    assert "window.__forgeInput && window.__forgeInput" in et
    text = _shipped_bundle_text()
    assert "window.__forgeOnInput" in text
    assert "runForgeAgent" in text
    assert "executeAgentTool" in text


def test_html_write_opens_preview_and_python_drops_undefined():
    """WAVE 3 t1: writes existed but PREVIEW stayed gray and python printed undefined."""
    text = _shipped_bundle_text()
    assert 'native.call("renderPreview"' in text
    assert 'n === "preview"' in text
    write_fn = text.split('if (n === "write")', 1)[1].split('if (n === "edit")', 1)[0]
    assert ".html" in write_fn
    assert "renderPreview" in write_fn
    py_fn = text.split('if (n === "python")', 1)[1].split('if (n === "preview")', 1)[0]
    assert 'pyOut === "undefined"' in py_fn


def test_muse_tool_arg_deltas_do_not_default_to_index_zero():
    """t1 mashed blob: second write's arguments.delta defaulted to index 0."""
    text = _shipped_bundle_text()
    fn = text.split("function museSseToChat", 1)[1].split("window.__forgeStreamChunk", 1)[0]
    assert "museCallIds[iid] : 0" not in fn
    assert "museCallIds[iid] != null ? museCallIds[iid] : 0" not in fn
    assert "parseToolArgs" in text
    assert "__multi" in text
    assert "NEVER default unknown item_id to 0" in fn or "museNextIdx++" in fn


def test_parse_tool_args_splits_concatenated_json_objects():
    """Shipped parseToolArgs must exist and be used at execute time."""
    text = _shipped_bundle_text()
    assert "function parseToolArgs" in text
    body = text.split("function parseToolArgs", 1)[1].split("function aliasToolName", 1)[0]
    assert "JSON.parse" in body
    assert "__multi" in body
    exec_loop = text.split("Object.keys(streamToolCalls)", 1)[1].split("Feed results back", 1)[0]
    assert "parseToolArgs" in exec_loop
    assert "__multi" in exec_loop


def test_write_sanitizes_mashed_path_json_leftover():
    """t4 write panel showed print(...) plus leftover `","path":"hello.py"}`."""
    text = _shipped_bundle_text()
    assert "function sanitizeWriteContents" in text
    san = text.split("function sanitizeWriteContents", 1)[1].split("function aliasToolName", 1)[0]
    assert '","path":' in san
    write_fn = text.split('if (n === "write")', 1)[1].split('if (n === "edit")', 1)[0]
    assert "sanitizeWriteContents" in write_fn
    # t5 mash still painted via writeStream before execute; must sanitize there too.
    stream = text.split("PROGRESSIVE WRITE VISIBILITY", 1)[1].split("tool_calls have no content", 1)[0]
    assert "sanitizeWriteContents(unescaped)" in stream or "unescaped = sanitizeWriteContents" in stream


def test_write_stream_does_not_paint_ghost_file_panel_or_json_closer():
    """t7 t22: ghost `file – 20 bytes` panel with stray quote.

    Stream used path='file' until `"path"` arrived; leftover JSON closer was
    APPENDED and never retracted. Must wait for a real path and extract the
    JSON string (stop at unescaped quote), then emit a replace snapshot
    (emitChat write) not an append-only writeStream delta.
    """
    text = _shipped_bundle_text()
    stream = text.split("PROGRESSIVE WRITE VISIBILITY", 1)[1].split("tool_calls have no content", 1)[0]
    assert "extractStreamingWriteContent" in text
    ext = text.split("function extractStreamingWriteContent", 1)[1].split("function aliasToolName", 1)[0]
    # Stop at unescaped JSON string closer — not unescape-the-rest.
    assert 'ch === \'"\'' in ext or "ch === '\"'" in ext or 'ch === "\\""' in ext or 'case \'"\'' in ext
    # Do not paint a panel titled "file" before path exists.
    assert 't.path = pathMatch[1]' in stream or "pathMatch[1]" in stream
    assert 'pathMatch' in stream
    # Snapshot replace, not append-only leftover.
    assert 'emitChat("write"' in stream
    assert 'emitChat("writeStream"' not in stream


def test_python_stdout_emit_has_trailing_newline():
    """t7: ANSWER 42DONE glued to next assistant tokens.

    emitChat assistant for python stdout must end with a newline so the next
    prose delta cannot concatenate onto the last print.
    """
    text = _shipped_bundle_text()
    py_fn = text.split('if (n === "python")', 1)[1].split('if (n === "preview")', 1)[0]
    assert "ensureTrailingNewline" in py_fn or 'pyOut + "\\n"' in py_fn or "endsWith" in py_fn
