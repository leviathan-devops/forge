"""Drive the SHIPPED /connect functions — not a reimplementation.

Spec: projects/forge/docs/CONNECT_SPEC.md. The bundle must expose three
pure top-level functions (slash parsing, provider normalize incl. baseUrl,
connect-update routing incl. leak refusal), executed here via node exactly
as test_mode1_mash_exec.py drives sanitize/extract/newline.
RED until the bundle implements them; a green suite that never checks the
change fails the gate.
"""
from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = ROOT / "iOS/FORGE/Resources/forge-bundle.js"
SCRATCH = Path("/tmp/grok-goal-fdd9250716fc/implementer")

SHIPPED_FUNCS = (
    ("parseSlashCommand", "normalizeConnectProvider"),
    ("normalizeConnectProvider", "buildConnectUpdate"),
    ("buildConnectUpdate", "runForgeAgent"),
)


def _shipped() -> str:
    assert BUNDLE.is_file()
    return BUNDLE.read_text(encoding="utf-8", errors="replace")


def _extract(text: str, name: str, follower: str) -> str:
    needle = f"function {name}("
    start = text.find(needle)
    assert start >= 0, f"shipped bundle missing function {name}"
    end = text.find(f"function {follower}(", start + len(needle))
    assert end > start, f"shipped bundle missing follower {follower} after {name}"
    chunk = text[start:end].rstrip() + "\n"
    # The follower may be `async function`: the slice then ends with a
    # dangling `async` identifier (ReferenceError at runtime). Drop it —
    # test-harness slicing only; shipped code is untouched.
    chunk = re.sub(r"\basync\s*$", "", chunk).rstrip() + "\n"
    return chunk


def _run(cases: list[dict]) -> list[dict]:
    node = shutil.which("node") or shutil.which("nodejs")
    assert node, "node required to execute shipped bundle functions"
    src = _shipped()
    script = "".join(_extract(src, n, f) for n, f in SHIPPED_FUNCS)
    script += (
        "const cases = " + json.dumps(cases) + ";\n"
        "const out = cases.map((c) => {\n"
        "  try {\n"
        "    if (c.fn === 'parse') return { ok: true, v: parseSlashCommand(c.input) };\n"
        "    if (c.fn === 'norm') return { ok: true, v: normalizeConnectProvider(c.input) };\n"
        "    if (c.fn === 'upd') {\n"
        "      var val = c.value;\n"
        "      if (c.fakekey) val = 'sk-' + 'fake0123456789abcdefTESTKEY';\n"
        "      return { ok: true, v: buildConnectUpdate(c.field, val, c.current || {}) };\n"
        "    }\n"
        "  } catch (e) { return { ok: false, e: String((e && e.message) || e) }; }\n"
        "});\n"
        "console.log(JSON.stringify(out));\n"
    )
    SCRATCH.mkdir(parents=True, exist_ok=True)
    path = SCRATCH / "run-shipped-connect.js"
    path.write_text(script, encoding="utf-8")
    proc = subprocess.run([node, str(path)], check=False, capture_output=True,
                          text=True, timeout=15)
    assert proc.returncode == 0, (
        "shipped JS threw:\n" + (proc.stderr or "") + "\n" + (proc.stdout or "")
    )
    return json.loads((proc.stdout or "").strip().splitlines()[-1])


def _eq(a, b, label):
    assert a == b, f"{label}: {a!r} != {b!r}"


def test_slash_parse_table():
    res = _run([
        {"fn": "parse", "input": "/connect key"},
        {"fn": "parse", "input": "/CONNECT URL https://x.ai/v1"},
        {"fn": "parse", "input": "/help"},
        {"fn": "parse", "input": "help"},
        {"fn": "parse", "input": "/unknown thing here"},
        {"fn": "parse", "input": ""},
    ])
    _eq(res[0]["v"], {"slash": True, "cmd": "connect", "args": ["key"]}, "connect key")
    _eq(res[1]["v"]["cmd"], "connect", "case-insensitive cmd")
    _eq(res[2]["v"], {"slash": True, "cmd": "help", "args": []}, "bare slash help")
    _eq(res[3]["v"], {"slash": False}, "non-slash input")
    _eq(res[4]["v"]["cmd"], "unknown", "unknown slash passthrough")
    _eq(res[5]["v"], {"slash": False}, "empty input")


def test_provider_normalize_with_url_shape():
    res = _run([
        {"fn": "norm", "input": "OpenAI"},
        {"fn": "norm", "input": "zen"},
        {"fn": "norm", "input": "Anthropic"},
        {"fn": "norm", "input": "Custom"},
    ])
    _eq(res[0]["v"], "openai", "OpenAI")
    _eq(res[1]["v"], "openai", "zen alias")
    _eq(res[2]["v"], "anthropic", "Anthropic")
    _eq(res[3]["v"], "custom", "custom passthrough")


def test_connect_update_routing_and_leak_refusal():
    res = _run([
        {"fn": "upd", "field": "url", "value": "https://opencode.ai/zen/go/v1"},
        {"fn": "upd", "field": "model", "value": "muse-spark-1.3-contributor"},
        {"fn": "upd", "field": "model", "value": "deepseek-v4-flash-free"},
        {"fn": "upd", "field": "url", "value": "not a url"},
        {"fn": "upd", "field": "model", "fakekey": True},
        {"fn": "upd", "field": "provider", "value": "openai"},
    ])
    _eq(res[0]["v"]["ok"], True, "good url accepted")
    _eq(res[1]["v"]["ok"], True, "go model accepted")
    _eq(res[2]["v"]["ok"], False, "retired model refused")
    _eq(res[3]["v"]["ok"], False, "bad url refused")
    _eq(res[4]["v"]["ok"], False, "key-like value in model field refused")
    _eq("leak" in (res[4]["v"].get("error") or "").lower(), True, "leak refusal named")
    _eq(res[5]["v"]["ok"], True, "provider accepted")


def test_no_hardcoded_secret_in_bundle():
    import re
    src = _shipped()
    hits = re.findall(r"sk-[A-Za-z0-9]{8,}", src)
    assert hits == [], f"hardcoded secret material in shipped bundle: {len(hits)} hits"
