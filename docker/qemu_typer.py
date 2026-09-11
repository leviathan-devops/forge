#!/usr/bin/env python3
"""Type keys / drive macOS Setup Assistant / enable Remote Login via QEMU monitor.

Hard constraints (NEVER violate):
  - Do NOT disable SIP, AMFI, SSV, authenticated-root, or csrutil.
  - Do NOT send boot-args that weaken security.
  - Keyboard-only guest input (QEMU sendkey).

Subcommands:
  type <text>              Type a string + Enter (default if no subcmd)
  key <name>               Single sendkey (e.g. ret, tab, cmd-spc)
  screendump <path>        QEMU screendump
  setup [--rounds N]       Tab/Return through Setup Assistant; local account
  enable-ssh               Open Terminal (best-effort) + systemsetup Remote Login
  drive-setup              Full path: dump → classify → setup and/or enable-ssh
                           Evidence under EVIDENCE_DIR (default /tmp/w7_setup; prefix from dir name)
"""
from __future__ import annotations

import argparse
import os
import socket
import statistics
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

# QEMU monitor telnet (inside container only)
DEFAULT_HOST = os.environ.get("QEMU_MONITOR_HOST", "127.0.0.1")
DEFAULT_PORT = int(os.environ.get("QEMU_MONITOR_PORT", "4444"))
CONNECT_RETRIES = 3
CONNECT_RETRY_DELAY_S = 0.5
BANNER_TIMEOUT_S = 1.0

ACCOUNT_USER = os.environ.get("MACOS_USER", "user")
ACCOUNT_PASS = os.environ.get("MACOS_PASS", "alpine")
ACCOUNT_FULL = os.environ.get("MACOS_FULLNAME", "Forge User")

# Forbidden substrings — refuse to type these (SIP/AMFI/SSV disable paths)
_FORBIDDEN = (
    "csrutil",
    "amfi_get_out_of_my_way",
    "amfi=",
    "authenticated-root disable",
    "nvram boot-args",
    "disable-ssv",
    "ssv disable",
    "sip disable",
    "csr-active-config",
)

# US keyboard sendkey map for printable ASCII used in Recovery/Terminal automation
_CHAR_KEYS = {
    " ": "spc",
    "/": "slash",
    "-": "minus",
    ".": "dot",
    ",": "comma",
    "=": "equal",
    ";": "semicolon",
    "'": "apostrophe",
    "\\": "backslash",
    "[": "bracket_left",
    "]": "bracket_right",
    "`": "grave_accent",
    "\t": "tab",
    # shifted
    ":": "shift-semicolon",
    "_": "shift-minus",
    '"': "shift-apostrophe",
    "|": "shift-backslash",
    "(": "shift-9",
    ")": "shift-0",
    "*": "shift-8",
    ">": "shift-dot",
    "<": "shift-comma",
    "&": "shift-7",
    "$": "shift-4",
    "!": "shift-1",
    "@": "shift-2",
    "#": "shift-3",
    "%": "shift-5",
    "^": "shift-6",
    "+": "shift-equal",
    "?": "shift-slash",
    "{": "shift-bracket_left",
    "}": "shift-bracket_right",
    "~": "shift-grave_accent",
}


def utc_stamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def assert_safe_text(s: str) -> None:
    low = s.lower()
    for bad in _FORBIDDEN:
        if bad.lower() in low:
            raise SystemExit(
                f"REFUSED: text contains forbidden SIP/AMFI/SSV pattern {bad!r}. "
                "Never disable SIP/AMFI/SSV."
            )


class QEMUTyper:
    def __init__(self, host=DEFAULT_HOST, port=DEFAULT_PORT):
        self.host = host
        self.port = port
        self.sock = None
        last_err = None
        for attempt in range(1, CONNECT_RETRIES + 1):
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(BANNER_TIMEOUT_S)
                sock.connect((host, port))
                self.sock = sock
                break
            except OSError as e:
                last_err = e
                try:
                    sock.close()
                except OSError:
                    pass
                if attempt < CONNECT_RETRIES:
                    print(
                        f"qemu_typer: connect {host}:{port} failed "
                        f"(attempt {attempt}/{CONNECT_RETRIES}): {e}; retrying…",
                        file=sys.stderr,
                    )
                    time.sleep(CONNECT_RETRY_DELAY_S)
                else:
                    print(
                        f"ERROR: cannot connect to QEMU monitor at {host}:{port} "
                        f"after {CONNECT_RETRIES} attempts: {e}",
                        file=sys.stderr,
                    )
                    raise SystemExit(1) from last_err

        # Consume initial banner / telnet negotiation (timeout is expected)
        time.sleep(0.3)
        try:
            self.sock.recv(8192)
        except socket.timeout:
            pass
        except OSError as e:
            print(
                f"WARNING: monitor banner recv failed: {e}",
                file=sys.stderr,
            )

    def close(self) -> None:
        if self.sock is not None:
            try:
                self.sock.close()
            except OSError:
                pass
            self.sock = None

    def key(self, keyname: str) -> None:
        """Send a single sendkey command (fire-and-forget)."""
        self.sock.sendall(f"sendkey {keyname}\n".encode())
        time.sleep(0.08)

    def type_str(self, s: str) -> None:
        """Type a string character by character. Refuses SIP/AMFI/SSV disable text."""
        assert_safe_text(s)
        for ch in s:
            if ch.isupper():
                self.key(f"shift-{ch.lower()}")
            elif ch.islower() or ch.isdigit():
                self.key(ch)
            elif ch in _CHAR_KEYS:
                self.key(_CHAR_KEYS[ch])
            else:
                print(f"WARNING: unknown char {ch!r}", file=sys.stderr)

    def enter(self) -> None:
        self.key("ret")

    def tab(self) -> None:
        self.key("tab")

    def screendump(self, path: str) -> None:
        self.sock.sendall(f"screendump {path}\n".encode())
        time.sleep(1.2)

    # ---- Setup Assistant / Remote Login automation ----

    def setup_assistant_pass(self, rounds: int = 8) -> None:
        """Best-effort Tab/Return through Setup Assistant; create local account if focused."""
        print(f"setup_assistant_pass rounds={rounds}")
        for i in range(rounds):
            # Continue / next on focused button
            self.enter()
            time.sleep(1.2)
            self.tab()
            time.sleep(0.3)
            if i in (1, 2, 3, 4):
                # "Set Up Later" / "Not Now" / "Skip" style choices
                self.key("down")
                time.sleep(0.2)
                self.enter()
                time.sleep(0.8)
                # also try Space on checkboxes
                if i == 2:
                    self.key("spc")
                    time.sleep(0.3)
            if i == 5:
                # Account fields: full name → account → pass → verify
                self.type_str(ACCOUNT_FULL)
                self.tab()
                time.sleep(0.3)
                self.type_str(ACCOUNT_USER)
                self.tab()
                time.sleep(0.3)
                self.type_str(ACCOUNT_PASS)
                self.tab()
                time.sleep(0.3)
                self.type_str(ACCOUNT_PASS)
                self.tab()
                time.sleep(0.3)
                self.enter()
                time.sleep(2.0)
            if i == 6:
                # Apple ID skip: often Tab to "Set Up Later" / "Other Options"
                for _ in range(4):
                    self.tab()
                    time.sleep(0.2)
                self.enter()
                time.sleep(1.0)
                self.key("down")
                time.sleep(0.2)
                self.enter()
                time.sleep(1.0)

    def open_terminal_menu(self) -> None:
        """Keyboard path: menu bar (Ctrl-F2) → Utilities-ish → Terminal."""
        print("open_terminal_menu (ctrl-f2 path)")
        self.key("ctrl-f2")
        time.sleep(0.5)
        for _ in range(4):
            self.key("right")
            time.sleep(0.15)
        self.key("down")
        time.sleep(0.2)
        for _ in range(6):
            self.key("down")
            time.sleep(0.12)
        self.enter()
        time.sleep(2.0)

    def open_terminal_spotlight(self) -> None:
        """Desktop Spotlight → type Terminal → Enter."""
        print("open_terminal_spotlight (cmd-spc)")
        self.key("meta_l-spc")
        time.sleep(0.15)
        # Some QEMU builds want cmd-spc
        self.key("cmd-spc")
        time.sleep(1.0)
        self.type_str("Terminal")
        time.sleep(0.5)
        self.enter()
        time.sleep(2.0)

    def enable_ssh_via_terminal(self) -> None:
        """Type systemsetup + launchctl fallback into focused Terminal.

        Safe only: enable Remote Login. Never touches SIP/AMFI/SSV.
        """
        cmds = [
            "sudo systemsetup -setremotelogin on",
            "sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist",
            "sudo launchctl load -w /System/Library/LaunchDaemons/com.openssh.sshd.plist",
        ]
        for c in cmds:
            assert_safe_text(c)
            print(f"typing enable cmd: {c}")
            self.type_str(c)
            self.enter()
            time.sleep(1.5)
            # password prompt for sudo
            self.type_str(ACCOUNT_PASS)
            self.enter()
            time.sleep(2.0)

    def enable_remote_login(self) -> None:
        """Open Terminal (menu + Spotlight) then enable Remote Login."""
        self.open_terminal_menu()
        time.sleep(1.0)
        self.open_terminal_spotlight()
        time.sleep(1.5)
        self.enable_ssh_via_terminal()


def convert_ppm(ppm: Path, png: Path) -> bool:
    for tool in ("convert", "magick"):
        try:
            r = subprocess.run(
                [tool, str(ppm), str(png)],
                capture_output=True,
                timeout=30,
                check=False,
            )
            if r.returncode == 0 and png.exists() and png.stat().st_size > 500:
                return True
        except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
            continue
    return False


def screen_mean(ppm: Path) -> float:
    """Rough mean luminance from P6 PPM (stdlib, no PIL required)."""
    try:
        raw = ppm.read_bytes()
    except OSError:
        return -1.0
    if not raw.startswith(b"P6"):
        return -1.0
    try:
        # header: P6\nW H\n255\n
        nl = raw.find(b"\n", raw.find(b"255"))
        if nl < 0:
            return -1.0
        data = raw[nl + 1 :]
        samples = []
        step = 48  # sparse sample
        for off in range(0, min(len(data) - 2, 3_000_000), step):
            r, g, b = data[off], data[off + 1], data[off + 2]
            samples.append((r + g + b) / 3.0)
        return float(statistics.mean(samples)) if samples else -1.0
    except Exception:
        return -1.0


def classify_ui(mean: float) -> str:
    """Coarse phase from brightness: ssv / setup / desktop-ish."""
    if mean < 0:
        return "unknown"
    if mean >= 55:
        return "setup_or_desktop"
    if mean >= 35:
        return "gui_mid"
    return "ssv_or_verbose"


def capture_pair(typer: QEMUTyper, work: Path, tag: str) -> tuple[Path, Path, float]:
    work.mkdir(parents=True, exist_ok=True)
    ppm = work / f"{tag}.ppm"
    png = work / f"{tag}.png"
    typer.screendump(str(ppm))
    convert_ppm(ppm, png)
    mean = screen_mean(ppm)
    return ppm, png, mean


def evidence_prefix(work: Path) -> str:
    """Stable artifact basename from EVIDENCE_PREFIX or work dir name.

    Examples: /tmp/w12_setup → w12_setup; env EVIDENCE_PREFIX=w12_setup overrides.
    Falls back to w_setup when work is generic (/tmp).
    """
    env = os.environ.get("EVIDENCE_PREFIX", "").strip()
    if env:
        return env
    name = work.resolve().name if work else ""
    if name and name not in (".", "tmp", "temp", "var"):
        return name
    return "w_setup"


def _stable_copy(src: Path, dest: Path) -> None:
    if not src.exists():
        return
    try:
        dest.write_bytes(src.read_bytes())
    except OSError as e:
        print(f"WARNING copy {dest.name}: {e}", file=sys.stderr)


def drive_setup(typer: QEMUTyper, work: Path, force: bool = False) -> int:
    """Capture → classify → Setup Assistant + Remote Login (or WAIT_SSV).

    Hard stop on dark/SSV screens: one optional gentle Return nudge only,
    write WAIT_SSV evidence, exit 2. Never thrash Setup/Terminal on SSV.
    Never disables SIP/AMFI/SSV.
    """
    work.mkdir(parents=True, exist_ok=True)
    stamp = utc_stamp()
    prefix = evidence_prefix(work)
    print(f"drive-setup evidence_dir={work} prefix={prefix} stamp={stamp}")

    ppm0, png0, mean0 = capture_pair(typer, work, f"{prefix}_before_{stamp}")
    _stable_copy(ppm0, work / f"{prefix}_before.ppm")
    _stable_copy(png0, work / f"{prefix}_before.png")
    # also keep live alias for host pull conventions
    _stable_copy(png0, work / f"{prefix}_live.png")
    _stable_copy(ppm0, work / f"{prefix}_live.ppm")

    phase = classify_ui(mean0)
    print(f"before mean={mean0:.1f} phase={phase} png={png0}")

    note = work / f"{prefix}_status_{stamp}.txt"
    lines = [
        f"# setup-remote-login drive {stamp}",
        f"prefix={prefix}",
        f"mean_before={mean0:.1f}",
        f"phase={phase}",
        f"force={force}",
        "policy: never disable SIP/AMFI/SSV; no Setup thrash on SSV",
    ]

    if phase == "ssv_or_verbose" and not force:
        lines.append("action=WAIT_SSV")
        lines.append("status=WAIT_SSV")
        lines.append(
            "note: first-boot libignition/cryptex still active; "
            "re-run drive-setup only when mean>=35 (setup_or_desktop/gui_mid)"
        )
        lines.append("thrash=STOPPED (no Setup Assistant / enable-ssh typing)")
        # Single gentle Return only — dismiss rare progress dialogs; no further keys
        print("SSV/verbose still dark — WAIT_SSV: one ret nudge, no Setup typing")
        typer.enter()
        time.sleep(1.0)
        ppm1, png1, mean1 = capture_pair(typer, work, f"{prefix}_ssv_still_{stamp}")
        _stable_copy(ppm1, work / f"{prefix}_ssv_still.ppm")
        _stable_copy(png1, work / f"{prefix}_ssv_still.png")
        lines.append(f"mean_after_nudge={mean1:.1f}")
        body = "\n".join(lines) + "\n"
        note.write_text(body, encoding="utf-8")
        (work / f"{prefix}_status_LATEST.txt").write_text(body, encoding="utf-8")
        # Machine-readable marker for wave gates
        (work / "WAIT_SSV").write_text(
            f"WAIT_SSV stamp={stamp} mean={mean1:.1f} phase={phase}\n",
            encoding="utf-8",
        )
        print(f"STATUS: WAIT_SSV mean={mean1:.1f}; evidence written under {work}")
        return 2  # not ready — stop thrashing

    # Setup / mid / force: keyboard-drive Setup Assistant
    print("Running setup_assistant_pass…")
    typer.setup_assistant_pass(rounds=8)
    ppm_s, png_s, mean_s = capture_pair(typer, work, f"{prefix}_after_setup_{stamp}")
    _stable_copy(ppm_s, work / f"{prefix}_after_setup.ppm")
    _stable_copy(png_s, work / f"{prefix}_after_setup.png")
    lines.append(f"mean_after_setup={mean_s:.1f}")

    # Enable Remote Login
    print("Running enable_remote_login…")
    typer.enable_remote_login()
    ppm_e, png_e, mean_e = capture_pair(typer, work, f"{prefix}_after_ssh_{stamp}")
    _stable_copy(ppm_e, work / f"{prefix}_after_ssh.ppm")
    _stable_copy(png_e, work / f"{prefix}_after_ssh.png")
    lines.append(f"mean_after_ssh={mean_e:.1f}")
    lines.append("action=SETUP_AND_ENABLE_SSH_ATTEMPTED")
    lines.append("status=SETUP_AND_ENABLE_SSH_ATTEMPTED")
    body = "\n".join(lines) + "\n"
    note.write_text(body, encoding="utf-8")
    (work / f"{prefix}_status_LATEST.txt").write_text(body, encoding="utf-8")
    # Clear WAIT_SSV marker if we progressed
    wait_m = work / "WAIT_SSV"
    if wait_m.exists():
        try:
            wait_m.unlink()
        except OSError:
            pass
    print(f"STATUS: setup+enable attempted mean_end={mean_e:.1f}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="QEMU keyboard typer + Setup/Remote Login driver")
    p.add_argument("--host", default=DEFAULT_HOST)
    p.add_argument("--port", type=int, default=DEFAULT_PORT)
    sub = p.add_subparsers(dest="cmd")

    t = sub.add_parser("type", help="Type string + Enter")
    t.add_argument("text", nargs="+")

    k = sub.add_parser("key", help="Single sendkey")
    k.add_argument("name")

    s = sub.add_parser("screendump", help="screendump path")
    s.add_argument("path")

    su = sub.add_parser("setup", help="Setup Assistant keyboard pass")
    su.add_argument("--rounds", type=int, default=8)

    sub.add_parser("enable-ssh", help="Open Terminal + enable Remote Login")

    d = sub.add_parser("drive-setup", help="Capture + classify + setup/enable")
    d.add_argument(
        "--work",
        default=os.environ.get("EVIDENCE_DIR", "/tmp/w7_setup"),
        help="evidence directory (basename → artifact prefix; or EVIDENCE_PREFIX)",
    )
    d.add_argument(
        "--force",
        action="store_true",
        help="run setup even if screen looks like SSV (dark)",
    )

    # backward-compat: bare args → type
    return p


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)

    # Backward compatible: `qemu_typer.py diskutil list` still types the line
    if not argv or (argv[0] not in (
        "type", "key", "screendump", "setup", "enable-ssh", "drive-setup",
        "-h", "--help",
    ) and not argv[0].startswith("-")):
        # treat entire argv as text to type
        text = " ".join(argv) if argv else "diskutil list"
        assert_safe_text(text)  # refuse before connect
        typer = QEMUTyper()
        try:
            print(f"Typing: {text}")
            typer.type_str(text)
            typer.enter()
            print("Command sent!")
            time.sleep(3)
            typer.screendump("/tmp/terminal_output.ppm")
            print("Screenshot taken")
        finally:
            typer.close()
        return 0

    parser = build_parser()
    args = parser.parse_args(argv)
    # Pre-connect safety for type payloads
    if getattr(args, "cmd", None) == "type":
        assert_safe_text(" ".join(args.text))
    typer = QEMUTyper(host=args.host, port=args.port)
    try:
        if args.cmd == "type":
            text = " ".join(args.text)
            print(f"Typing: {text}")
            typer.type_str(text)
            typer.enter()
            return 0
        if args.cmd == "key":
            typer.key(args.name)
            return 0
        if args.cmd == "screendump":
            typer.screendump(args.path)
            print(f"screendump {args.path}")
            return 0
        if args.cmd == "setup":
            typer.setup_assistant_pass(rounds=args.rounds)
            return 0
        if args.cmd == "enable-ssh":
            typer.enable_remote_login()
            return 0
        if args.cmd == "drive-setup":
            return drive_setup(typer, Path(args.work), force=bool(args.force))
        parser.print_help()
        return 1
    finally:
        typer.close()


if __name__ == "__main__":
    raise SystemExit(main())
