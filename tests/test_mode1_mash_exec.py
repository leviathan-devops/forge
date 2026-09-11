"""Drive the SHIPPED sanitize/extract/newline functions — not a reimplementation.

t7 leftovers (`","path":`, stray quote, print+html concat) are fed into the
functions as they exist in iOS/FORGE/Resources/forge-bundle.js via node.
A test that greps source without calling those functions is VOID here.
"""
from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = ROOT / "iOS/FORGE/Resources/forge-bundle.js"
SCRATCH = Path("/tmp/grok-goal-9a00d16de93e/implementer")


def _shipped() -> str:
    assert BUNDLE.is_file()
    return BUNDLE.read_text(encoding="utf-8", errors="replace")


def _extract_function(text: str, name: str, next_name: str) -> str:
    """Slice shipped source from `function name` to the next named function.

    Brace-counting is VOID here: sanitizeWriteContents contains `/\\}/` in a
    regex, which is still a `}` byte and would truncate the body.
    """
    needle = f"function {name}("
    start = text.find(needle)
    assert start >= 0, f"shipped bundle missing function {name}"
    nxt = f"function {next_name}("
    end = text.find(nxt, start + len(needle))
    assert end > start, f"shipped bundle missing follower {next_name} after {name}"
    return text[start:end].rstrip() + "\n"


def _run_shipped_js(script: str) -> dict:
    node = shutil.which("node") or shutil.which("nodejs")
    assert node, "node required to execute shipped bundle functions"
    SCRATCH.mkdir(parents=True, exist_ok=True)
    path = SCRATCH / "run-shipped-sanitize.js"
    path.write_text(script, encoding="utf-8")
    proc = subprocess.run(
        [node, str(path)],
        check=False,
        capture_output=True,
        text=True,
        timeout=15,
    )
    assert proc.returncode == 0, (
        "shipped JS threw:\n" + (proc.stderr or "") + "\n" + (proc.stdout or "")
    )
    line = (proc.stdout or "").strip().splitlines()[-1]
    return json.loads(line)


def _write_branch(text: str) -> str:
    start = text.find('if (n === "write")')
    assert start >= 0, "shipped executeAgentTool missing write branch"
    end = text.find('if (n === "edit")', start)
    assert end > start, "shipped write branch not followed by edit"
    return text[start:end]


def _progressive_write_block(text: str) -> str:
    start = text.find("PROGRESSIVE WRITE VISIBILITY")
    assert start >= 0, "shipped bundle missing PROGRESSIVE WRITE VISIBILITY"
    end = text.find("tool_calls have no content", start)
    assert end > start, "shipped progressive write block missing terminator"
    return text[start:end]


def _narration_idx(src: str) -> int | None:
    """Index of assistant narration or pendingAssistant flush — not phase."""
    found: list[int] = []
    for needle in (
        'emitChat("assistant"',
        "emitChat('assistant'",
        "flushPendingAssistant",
        "flushPending(",
        "if (pendingAssistant)",
        "if (pendingAssistant &&",
    ):
        i = src.find(needle)
        if i >= 0:
            found.append(i)
    return min(found) if found else None


def test_shipped_sanitize_strips_t7_mash_leftovers():
    """Feed t7 leftover strings into shipped sanitizeWriteContents + extractStreamingWriteContent."""
    text = _shipped()
    san = _extract_function(text, "sanitizeWriteContents", "extractStreamingWriteContent")
    ext = _extract_function(text, "extractStreamingWriteContent", "ensureTrailingNewline")
    script = (
        san
        + "\n"
        + ext
        + r"""
const pathFirst = '{"path":"hello.py","content":"print(\\"ANSWER 42\\")"}';
const contentFirst = '{"content":"print(\\"ANSWER 42\\")","path":"hello.py"}';
const unescapeRest = 'print("ANSWER 42")","path":"hello.py"}';
const strayQuote = 'print("ANSWER 42")\n"';
const printHtml = 'print("ANSWER 42")\n","path":"<p class=\\"ans\\">ANSWER 42</p>"}';
const out = {
  pathFirst: extractStreamingWriteContent(pathFirst),
  contentFirst: extractStreamingWriteContent(contentFirst),
  unescapeRest: sanitizeWriteContents(unescapeRest),
  strayQuote: sanitizeWriteContents(strayQuote),
  printHtml: sanitizeWriteContents(printHtml),
};
console.log(JSON.stringify(out));
"""
    )
    got = _run_shipped_js(script)
    for key, val in got.items():
        assert '","path":' not in val, f"{key} still has path leftover: {val!r}"
        assert '"path"' not in val, f"{key} still has path token: {val!r}"
        assert not val.rstrip().endswith('"}'), f"{key} still has JSON closer: {val!r}"
        assert "ANSWER 42" in val, f"{key} stripped real contents: {val!r}"
    # stray extra quote after print() must not remain as its own line
    assert got["strayQuote"].rstrip().endswith(")")
    assert got["unescapeRest"].rstrip() == 'print("ANSWER 42")'
    assert "<p class" not in got["printHtml"] or "print(" in got["printHtml"]
    # print+html concat leftover path mash must not keep the json glue
    assert '","path"' not in got["printHtml"]


def test_shipped_ensure_trailing_newline_separates_prints_and_assistant():
    """Two print chunks plus following assistant text stay on separate lines."""
    text = _shipped()
    fn = _extract_function(text, "ensureTrailingNewline", "aliasToolName")
    script = (
        fn
        + r"""
const a = ensureTrailingNewline("ANSWER 42");
const b = a + "DONE";
const c = ensureTrailingNewline(b) + "Fixing the second line";
console.log(JSON.stringify({a:a, b:b, c:c}));
"""
    )
    got = _run_shipped_js(script)
    assert got["a"] == "ANSWER 42\n"
    assert got["b"] == "ANSWER 42\nDONE"
    assert "ANSWER 42DONE" not in got["b"]
    assert got["c"] == "ANSWER 42\nDONE\nFixing the second line"
    assert "ANSWER 42DONEFixing" not in got["c"]


def test_shipped_read_assistant_emit_uses_ensure_trailing_newline():
    """t11 t60 pixel: 'read notes.txt (870 bytes)Editing hello.py'.

    Drive shipped ensureTrailingNewline AND pin that the read branch's
    emitChat assistant text wraps with it. A grep-only test is VOID; the
    function must actually separate the t11 leftover concatenation.
    """
    text = _shipped()
    start = text.find('if (n === "read")')
    assert start >= 0, "shipped executeAgentTool missing read branch"
    end = text.find('if (n === "write")', start)
    assert end > start
    branch = text[start:end]
    assert "ensureTrailingNewline" in branch, (
        "read-tool assistant emitChat is missing ensureTrailingNewline; "
        "t11 t60 glues as bytes)Editing"
    )
    fn = _extract_function(text, "ensureTrailingNewline", "aliasToolName")
    script = (
        fn
        + r"""
const readMsg = "read notes.txt (870 bytes)";
const glued = readMsg + "Editing hello.py to add DONE.";
const fixed = ensureTrailingNewline(readMsg) + "Editing hello.py to add DONE.";
console.log(JSON.stringify({glued: glued, fixed: fixed}));
"""
    )
    got = _run_shipped_js(script)
    assert "bytes)Editing" in got["glued"]
    assert "bytes)Editing" not in got["fixed"]
    assert got["fixed"].startswith("read notes.txt (870 bytes)\n")


def test_shipped_write_contents_trailing_newline_is_29_bytes():
    """BAR t9 t22 index.html is 29 bytes; t17 f0032 painted 28 (no trailing newline).

    Eval the shipped `var wcontent = ...;` assignment from the execute write
    branch. A hardcoded 29 without executing that assignment is VOID.
    """
    text = _shipped()
    san = _extract_function(text, "sanitizeWriteContents", "extractStreamingWriteContent")
    nl = _extract_function(text, "ensureTrailingNewline", "aliasToolName")
    branch = _write_branch(text)
    m = re.search(r"var wcontent = .+?;", branch, flags=re.DOTALL)
    assert m, "write branch missing var wcontent assignment"
    assignment = m.group(0)
    p_tag = '<p class="ans">ANSWER 42</p>'
    script = (
        san
        + "\n"
        + nl
        + "\n"
        + "const args = { content: " + json.dumps(p_tag) + " };\n"
        + assignment
        + "\n"
        + "console.log(JSON.stringify({wcontent: wcontent, len: wcontent.length}));\n"
    )
    got = _run_shipped_js(script)
    assert str(got["wcontent"]).startswith('<p class="ans">ANSWER 42</p>'), got
    assert got["len"] == 29, (
        f"28!=29 write contents bytes={got['len']!r} {got['wcontent']!r}"
    )
    assert str(got["wcontent"]).endswith("\n"), (
        f"write contents missing trailing newline: {got['wcontent']!r}"
    )


def test_shipped_progressive_write_also_newlines_content():
    """Progressive emitChat write paints the card during stream (often before execute).

    Drive extractStreamingWriteContent + sanitizeWriteContents on the 28-byte
    p-tag JSON, then the shipped wrap if the progressive path applies
    ensureTrailingNewline to unescaped before emitChat write.
    """
    text = _shipped()
    san = _extract_function(text, "sanitizeWriteContents", "extractStreamingWriteContent")
    ext = _extract_function(text, "extractStreamingWriteContent", "ensureTrailingNewline")
    nl = _extract_function(text, "ensureTrailingNewline", "aliasToolName")
    prog = _progressive_write_block(text)
    write_i = prog.find('emitChat("write"')
    assert write_i >= 0, "progressive block missing emitChat write"
    pre = prog[:write_i]
    assigns = re.findall(r"(?:var\s+)?unescaped\s*=\s*[^;]+;", pre)
    assert assigns, "progressive write missing unescaped pipeline"
    cm = re.search(r"content:\s*([^,}]+)", prog[write_i : write_i + 240])
    assert cm, "progressive emitChat write missing content expression"
    content_expr = cm.group(1).strip()
    args_str = '{"path":"index.html","content":"<p class=\\"ans\\">ANSWER 42</p>"}'
    pipeline = "\n".join(assigns)
    wrap = ""
    if "ensureTrailingNewline" in pipeline or "ensureTrailingNewline" in content_expr:
        wrap = "/* shipped wrap present in unescaped pipeline or content expr */"
    else:
        # Do not invent a wrap — execute the shipped pipeline as-is (28 bytes today).
        wrap = "/* no ensureTrailingNewline on unescaped before emitChat write */"
    script = (
        san
        + "\n"
        + ext
        + "\n"
        + nl
        + "\n"
        + "const t = { args: " + json.dumps(args_str) + " };\n"
        + pipeline
        + "\n"
        + wrap
        + "\n"
        + "const painted = "
        + content_expr
        + ";\n"
        + "console.log(JSON.stringify({painted: painted, len: painted.length}));\n"
    )
    got = _run_shipped_js(script)
    assert str(got["painted"]).startswith('<p class="ans">ANSWER 42</p>'), got
    assert got["len"] == 29, (
        f"28!=29 progressive write bytes={got['len']!r} {got['painted']!r}"
    )
    assert str(got["painted"]).endswith("\n"), (
        f"progressive write contents missing trailing newline: {got['painted']!r}"
    )


def _close_js_braces(chunk: str) -> str:
    depth = 0
    for ch in chunk:
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
    assert depth >= 0, "progressive first-content chunk has extra closing braces"
    return chunk + ("}" * depth)


def test_shipped_write_emits_assistant_narration_before_write_card():
    """BAR narration-before-cards: assistant (not phase) before emitChat write.

    t17 still card-first vs BAR assistant 'Starting with hello.py.'.
    Phase-only 'Writing path...' is NOT enough.
    """
    text = _shipped()
    san = _extract_function(text, "sanitizeWriteContents", "extractStreamingWriteContent")
    ext = _extract_function(text, "extractStreamingWriteContent", "ensureTrailingNewline")
    nl = _extract_function(text, "ensureTrailingNewline", "aliasToolName")
    branch = _write_branch(text)
    prog = _progressive_write_block(text)
    p_tag = '<p class="ans">ANSWER 42</p>'
    args_str = '{"path":"index.html","content":"<p class=\\"ans\\">ANSWER 42</p>"}'

    # Harness first — execute shipped emitChat order (not grep-only).
    exec_script = (
        san
        + "\n"
        + nl
        + r"""
async function main() {
  const kinds = [];
  function emitChat(kind, payload) { kinds.push(kind); }
  const native = { call: async function () { return null; } };
  var pendingAssistant = "Starting with hello.py.";
  function flushPending() {
    if (pendingAssistant) {
      emitChat("assistant", { text: pendingAssistant });
      pendingAssistant = "";
    }
  }
  function flushPendingAssistant() { flushPending(); }
  var n = "write";
  var args = { path: "index.html", content: """
        + json.dumps(p_tag)
        + r""" };
  var CY = "", RS = "", GN = "", YL = "";
  var line = function () {};
  async function runWriteBranch() {
"""
        + branch
        + r"""
  }
  await runWriteBranch();
  console.log(JSON.stringify({kinds: kinds}));
}
main().catch(function (e) {
  console.error(String(e && e.stack || e));
  process.exit(1);
});
"""
    )
    exec_got = _run_shipped_js(exec_script)
    exec_kinds = exec_got["kinds"]

    assigns = re.findall(r"(?:var\s+)?unescaped\s*=\s*[^;]+;", prog)
    assert assigns, "progressive write missing unescaped pipeline"
    started = prog.find("if (!t.contentStarted)")
    assert started >= 0, "progressive first-content path missing contentStarted gate"
    p_write_i = prog.find('emitChat("write"', started)
    assert p_write_i >= 0, "progressive block missing emitChat write"
    p_semi = prog.find(";", p_write_i)
    first_content = _close_js_braces(prog[started : p_semi + 1])
    prog_script = (
        san
        + "\n"
        + ext
        + "\n"
        + nl
        + r"""
const kinds = [];
function emitChat(kind, payload) { kinds.push(kind); }
var pendingAssistant = "Starting with hello.py.";
function flushPending() {
  if (pendingAssistant) {
    emitChat("assistant", { text: pendingAssistant });
    pendingAssistant = "";
  }
}
function flushPendingAssistant() { flushPending(); }
var t = { name: "write", args: """
        + json.dumps(args_str)
        + r""", contentStarted: false, contentEmitted: 0, path: "index.html" };
"""
        + "\n".join(assigns)
        + "\n"
        + first_content
        + r"""
console.log(JSON.stringify({kinds: kinds}));
"""
    )
    prog_got = _run_shipped_js(prog_script)
    prog_kinds = prog_got["kinds"]

    def _asst_before_write(kinds, label):
        if "write" not in kinds:
            return f"{label} never emitChat write: {kinds!r}"
        if "assistant" not in kinds:
            return f"missing assistant-before-write on {label}; kinds={kinds!r}"
        if kinds.index("assistant") >= kinds.index("write"):
            return f"{label} write card before assistant narration; kinds={kinds!r}"
        return None

    order_errs = [
        e
        for e in (
            _asst_before_write(exec_kinds, "execute write branch"),
            _asst_before_write(prog_kinds, "progressive write path"),
        )
        if e
    ]
    assert not order_errs, "missing assistant-before-write: " + " | ".join(order_errs)

    write_i = branch.find('emitChat("write"')
    assert write_i >= 0, "execute write branch missing emitChat write"
    asst_i = _narration_idx(branch)
    assert asst_i is not None, (
        "missing assistant-before-write on execute write branch "
        "(phase-only Preparing/Writing path is NOT narration)"
    )
    assert asst_i < write_i, (
        f"execute write card before assistant narration (assistant@{asst_i} write@{write_i})"
    )
    assert p_write_i >= 0, "progressive block missing emitChat write"
    p_asst_i = _narration_idx(prog)
    assert p_asst_i is not None, (
        "missing assistant-before-write on progressive write path "
        "(phase-only Writing path... is NOT narration)"
    )
    assert p_asst_i < p_write_i, (
        f"progressive write card before assistant narration "
        f"(assistant@{p_asst_i} write@{p_write_i})"
    )


def _run_execute_write_harness(branch, pending_value):
    """Execute the shipped execute-write branch; record emitChat kind+text.

    Mirrors production scope: writeStartedNarration is bundle-defined, so the
    harness defines it too. A harness without it would silently skip the
    injection the shipped code performs.
    """
    text = _shipped()
    san = _extract_function(text, "sanitizeWriteContents", "extractStreamingWriteContent")
    nl = _extract_function(text, "ensureTrailingNewline", "aliasToolName")
    script = (
        san
        + "\n"
        + nl
        + "\n"
        + "const events = [];\n"
        + "var turnProseOut = false;\n"
        + "function emitChat(kind, payload) { if (kind === \"assistant\") turnProseOut = true; events.push({kind: kind, text: (payload && payload.text) || \"\"}); }\n"
        + "const native = { call: async function () { return null; } };\n"
        + "var writeStartedNarration = {};\n"
        + "var pendingAssistant = "
        + json.dumps(pending_value)
        + ";\n"
        + r"""
function flushPending() {
  if (pendingAssistant) {
    emitChat("assistant", { text: pendingAssistant });
    pendingAssistant = "";
  }
}
function flushPendingAssistant() { flushPending(); }
var n = "write";
var args = { path: "index.html", content: '<p class="ans">ANSWER 42</p>' };
var CY = "", RS = "", GN = "", YL = "";
var line = function () {};
async function runWriteBranch() {
"""
        + branch
        + r"""
}
async function main() {
  await runWriteBranch();
  console.log(JSON.stringify({events: events}));
}
main().catch(function (e) {
  console.error(String(e && e.stack || e));
  process.exit(1);
});
"""
    )
    return _run_shipped_js(script)["events"]


def _run_progressive_first_content_harness(prog, pending_value):
    """Run the shipped progressive first-content path; record emitChat kind+text."""
    text = _shipped()
    san = _extract_function(text, "sanitizeWriteContents", "extractStreamingWriteContent")
    ext = _extract_function(text, "extractStreamingWriteContent", "ensureTrailingNewline")
    nl = _extract_function(text, "ensureTrailingNewline", "aliasToolName")
    assigns = re.findall(r"(?:var\s+)?unescaped\s*=\s*[^;]+;", prog)
    assert assigns, "progressive write missing unescaped pipeline"
    started = prog.find("if (!t.contentStarted)")
    assert started >= 0, "progressive first-content path missing contentStarted gate"
    p_write_i = prog.find('emitChat("write"', started)
    assert p_write_i >= 0, "progressive block missing emitChat write"
    p_semi = prog.find(";", p_write_i)
    first_content = _close_js_braces(prog[started : p_semi + 1])
    args_str = '{"path":"index.html","content":"<p class=\\"ans\\">ANSWER 42</p>"}'
    script = (
        san
        + "\n"
        + ext
        + "\n"
        + nl
        + "\n"
        + "const events = [];\n"
        + "var turnProseOut = false;\n"
        + "function emitChat(kind, payload) { if (kind === \"assistant\") turnProseOut = true; events.push({kind: kind, text: (payload && payload.text) || \"\"}); }\n"
        + "var writeStartedNarration = {};\n"
        + "var pendingAssistant = "
        + json.dumps(pending_value)
        + ";\n"
        + r"""
function flushPending() {
  if (pendingAssistant) {
    emitChat("assistant", { text: pendingAssistant });
    pendingAssistant = "";
  }
}
function flushPendingAssistant() { flushPending(); }
var t = { name: "write", args: """
        + json.dumps(args_str)
        + r""", contentStarted: false, contentEmitted: 0, path: "index.html" };
"""
        + "\n".join(assigns)
        + "\n"
        + first_content
        + r"""
console.log(JSON.stringify({events: events}));
"""
    )
    return _run_shipped_js(script)["events"]


def test_prose_first_write_has_no_duplicate_starting_injection():
    """t18 follow-up: Muse pre-narration + bundle injection painted 'Wrote' twice.

    When pendingAssistant already holds model prose, the shipped paths must
    flush THAT line before the card and must NOT add a fixed 'Starting with'.
    """
    text = _shipped()
    branch = _write_branch(text)
    prog = _progressive_write_block(text)
    model_line = "Muse pre narrative."
    for label, events in (
        ("execute", _run_execute_write_harness(branch, model_line)),
        ("progressive", _run_progressive_first_content_harness(prog, model_line)),
    ):
        kinds = [e["kind"] for e in events]
        texts = [e["text"] for e in events if e["kind"] == "assistant"]
        assert "write" in kinds, f"{label} never emitChat write: {kinds!r}"
        assert any(model_line in t for t in texts), (
            f"{label} did not flush model prose before card: {texts!r}"
        )
        assert kinds.index("assistant") < kinds.index("write"), (
            f"{label} card before model prose: {kinds!r}"
        )
        assert not any(t.startswith("Starting with") for t in texts), (
            f"{label} duplicate fixed injection over model prose: {texts!r}"
        )


def test_tools_first_write_injects_starting_narration():
    """t17 card-first: with empty pendingAssistant the shipped paths must still
    put an assistant 'Starting with' line before the card (not phase-only)."""
    text = _shipped()
    branch = _write_branch(text)
    prog = _progressive_write_block(text)
    for label, events in (
        ("execute", _run_execute_write_harness(branch, "")),
        ("progressive", _run_progressive_first_content_harness(prog, "")),
    ):
        kinds = [e["kind"] for e in events]
        texts = [e["text"] for e in events if e["kind"] == "assistant"]
        assert "write" in kinds, f"{label} never emitChat write: {kinds!r}"
        assert "assistant" in kinds, f"{label} no assistant narration: {kinds!r}"
        assert kinds.index("assistant") < kinds.index("write"), (
            f"{label} card before narration: {kinds!r}"
        )
        assert any(t.startswith("Starting with index.html.") for t in texts), (
            f"{label} missing injected Starting line: {texts!r}"
        )


def test_no_post_write_fixed_echoes():
    """t18 pixels: 'Wrote hello.py – now running it.' painted twice (Muse + echo).

    After emitChat write, the shipped write paths must not emit fixed assistant
    echoes. BAR closing copy is the model's own line, not a bundle echo.
    """
    text = _shipped()
    branch = _write_branch(text)
    write_i = branch.find('emitChat("write"')
    assert write_i >= 0, "execute write branch missing emitChat write"
    assert 'emitChat("assistant"' not in branch[write_i:], (
        "execute write branch still emits a fixed assistant echo after the card"
    )
    prog = _progressive_write_block(text)
    p_write_i = prog.find('emitChat("write"')
    assert p_write_i >= 0, "progressive block missing emitChat write"
    assert 'emitChat("assistant"' not in prog[p_write_i:], (
        "progressive write path still emits a fixed assistant echo after the card"
    )

