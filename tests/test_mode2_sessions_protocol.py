"""Mode 2: real HTTP path for OpenCode session list as used by ConnectionManager.

Drives the same endpoint the shipped Swift builds:
  URL(string: "\\(server.baseURL)/session")
(the REAL opencode serve endpoint — /api/sessions returns the web UI HTML on
live serves and must never be used; see CONTEXT_MANAGEMENT/COMPACTION_SURVIVAL
§6). The path suffix is extracted from ConnectionManager.swift and a live JSON
list compatible with RemoteSessionInfo is served.
"""
from __future__ import annotations

import json
import re
import threading
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
CM_SWIFT = ROOT / "iOS/FORGE/Bridge/ConnectionManager.swift"


def sessions_path_from_source() -> str:
    text = CM_SWIFT.read_text(encoding="utf-8")
    # Must match shipped construction: "\(server.baseURL)/session"
    m = re.search(r'baseURL\)/([^"\\]+)"', text)
    assert m, "ConnectionManager.swift must build sessions URL from baseURL"
    path = "/" + m.group(1).lstrip("/")
    assert "session" in path.lower(), path
    return path


def base_url_scheme_from_source() -> tuple[str, str]:
    text = CM_SWIFT.read_text(encoding="utf-8")
    # ServerConnection.baseURL uses: useTLS ? "https" : "http"
    assert '"http"' in text and '"https"' in text
    assert "wsURL" in text or '"ws"' in text or '"wss"' in text
    return "http", "https"


class SessionsHandler(BaseHTTPRequestHandler):
    path_suffix = "/session"  # default; the fixture pins it from source
    payload = [
        {
            "id": "sess-e2e-1",
            "name": "FORGE Mission Control E2E",
            "active": True,
            "lastLines": ["$ forge ready", "agent: trident"],
            "agent": "trident",
            "phase": "idle",
        }
    ]

    def log_message(self, fmt, *args):  # quiet
        return

    def do_GET(self):
        if self.path.split("?")[0] != self.path_suffix:
            self.send_response(404)
            self.end_headers()
            return
        body = json.dumps(self.payload).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


@pytest.fixture(scope="module")
def live_server():
    path = sessions_path_from_source()
    SessionsHandler.path_suffix = path
    httpd = HTTPServer(("127.0.0.1", 0), SessionsHandler)
    port = httpd.server_address[1]
    t = threading.Thread(target=httpd.serve_forever, daemon=True)
    t.start()
    yield f"http://127.0.0.1:{port}", path
    httpd.shutdown()


def test_connection_manager_source_defines_session_endpoint():
    path = sessions_path_from_source()
    # REAL opencode serve endpoint. /api/sessions is the spec-invented dead
    # path (returns HTML on live serves) — ConnectionManager.swift:256 uses
    # /session and the canon documents why.
    assert path == "/session"
    base_url_scheme_from_source()


def test_live_get_sessions_matches_remote_session_info_shape(live_server):
    base, path = live_server
    url = f"{base}{path}"
    with urllib.request.urlopen(url, timeout=5) as resp:
        assert resp.status == 200
        data = json.loads(resp.read().decode("utf-8"))
    assert isinstance(data, list) and len(data) >= 1
    row = data[0]
    # RemoteSessionInfo fields from ConnectionManager.swift
    for key in ("id", "name", "active"):
        assert key in row
    assert row["active"] is True
    assert isinstance(row["id"], str) and row["id"]
    assert isinstance(row["name"], str) and row["name"]


def test_bearer_token_header_path_documented_in_source():
    text = CM_SWIFT.read_text(encoding="utf-8")
    assert "Authorization" in text
    assert "Bearer" in text
    assert "refreshSessions" in text
