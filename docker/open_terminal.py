#!/usr/bin/env python3
"""Open Terminal on macOS guest and (optionally) enable Remote Login.

Prefer QEMU monitor sendkey (reliable for Recovery + Sonoma guest).
VNC pointer path kept as secondary for Utilities menu coordinates.

Hard constraints:
  - Never disable SIP / AMFI / SSV / authenticated-root.
  - Keyboard-first; no csrutil / amfi / nvram security mutators.

Usage (inside forge-vm):
  python3 open_terminal.py                  # open Terminal best-effort
  python3 open_terminal.py --enable-ssh     # open + systemsetup Remote Login
  python3 open_terminal.py --drive-setup    # dump evidence + setup path helper
"""
from __future__ import annotations

import argparse
import filecmp
import os
import socket
import struct
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

# Reuse qemu_typer when co-located (container: /usr/local/bin or /tmp)
_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))
for _extra in ("/usr/local/bin", "/tmp"):
    if _extra not in sys.path:
        sys.path.insert(0, _extra)

try:
    from qemu_typer import (  # type: ignore
        ACCOUNT_PASS,
        QEMUTyper,
        assert_safe_text,
        capture_pair,
        classify_ui,
        convert_ppm,
        drive_setup,
        screen_mean,
        utc_stamp,
    )
except ImportError:
    QEMUTyper = None  # type: ignore
    drive_setup = None  # type: ignore

    def utc_stamp() -> str:  # type: ignore
        return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

    def assert_safe_text(s: str) -> None:  # type: ignore
        low = s.lower()
        for bad in (
            "csrutil",
            "amfi_get_out_of_my_way",
            "authenticated-root disable",
            "nvram boot-args",
        ):
            if bad in low:
                raise SystemExit(f"REFUSED forbidden pattern {bad!r}")


MONITOR_HOST = os.environ.get("QEMU_MONITOR_HOST", "127.0.0.1")
MONITOR_PORT = int(os.environ.get("QEMU_MONITOR_PORT", "4444"))
VNC_HOST = os.environ.get("VNC_HOST", "127.0.0.1")
VNC_PORT = int(os.environ.get("VNC_PORT", "5900"))
EVIDENCE_DIR = Path(os.environ.get("EVIDENCE_DIR", "/tmp/w7_setup"))


def qmon(cmd: str) -> None:
    """Fire-and-forget QEMU monitor command via socat (fallback when no QEMUTyper)."""
    try:
        subprocess.run(
            f'echo "{cmd}" | socat -t 2 - TCP:{MONITOR_HOST}:{MONITOR_PORT}',
            shell=True,
            capture_output=True,
            check=False,
        )
    except (OSError, socket.timeout, subprocess.SubprocessError) as e:
        print(f"qmon failed for {cmd!r}: {type(e).__name__}: {e}", file=sys.stderr)
    time.sleep(0.3)


def vnc_connect():
    s = socket.socket()
    s.settimeout(3)
    s.connect((VNC_HOST, VNC_PORT))
    s.recv(12)
    s.sendall(b"RFB 003.008\n")
    n = s.recv(1)[0]
    s.recv(n)
    s.sendall(bytes([1]))
    s.recv(4)
    s.sendall(bytes([1]))
    s.recv(1024)
    return s


def ptr(s, x, y, mask=0):
    s.sendall(struct.pack(">BBHH", 5, mask, int(x), int(y)))


def click(s, x, y):
    ptr(s, x, y, 0)
    time.sleep(0.03)
    ptr(s, x, y, 1)
    time.sleep(0.03)
    ptr(s, x, y, 0)


def open_terminal_keyboard(typer: "QEMUTyper | None" = None) -> None:
    """Primary: keyboard menu bar + Spotlight Terminal."""
    if typer is not None:
        typer.open_terminal_menu()
        time.sleep(1.0)
        typer.open_terminal_spotlight()
        return
    # socat fallback
    print("keyboard open_terminal via qmon sendkey")
    qmon("sendkey ctrl-f2")
    time.sleep(0.5)
    for _ in range(4):
        qmon("sendkey right")
        time.sleep(0.15)
    for _ in range(7):
        qmon("sendkey down")
        time.sleep(0.12)
    qmon("sendkey ret")
    time.sleep(2.0)
    qmon("sendkey cmd-spc")
    time.sleep(1.0)
    # type Terminal char-by-char via sendkey
    for ch in "Terminal":
        qmon(f"sendkey {ch.lower()}")
        time.sleep(0.08)
    qmon("sendkey ret")
    time.sleep(2.0)


def open_terminal_vnc() -> bool:
    """Secondary: VNC click Utilities → Terminal (Recovery-style menu bar)."""
    try:
        s = vnc_connect()
    except OSError as e:
        print(f"VNC connect failed: {e}", file=sys.stderr)
        return False

    print("VNC connected — probing Utilities menu")
    qmon("screendump /tmp/terminal_attempt.ppm")

    found = False
    try:
        for mx in [250, 270, 290]:
            print(f"Clicking Utilities menu at ({mx}, 10)...")
            click(s, mx, 10)
            time.sleep(0.5)
            for ty in [35, 55, 75, 95, 115, 135, 155, 175]:
                ptr(s, mx, ty, 0)
                time.sleep(0.05)
            for ty in [35, 75, 115, 155, 175]:
                print(f"  Clicking Terminal at ({mx}, {ty})...")
                click(s, mx, ty)
                time.sleep(1.5)
                qmon("screendump /tmp/terminal_check.ppm")
                try:
                    if os.path.exists("/tmp/terminal_attempt.ppm") and os.path.exists(
                        "/tmp/terminal_check.ppm"
                    ):
                        if not filecmp.cmp(
                            "/tmp/terminal_attempt.ppm",
                            "/tmp/terminal_check.ppm",
                            shallow=False,
                        ):
                            print(f"  CHANGE at ({mx}, {ty}) — possible Terminal")
                            subprocess.run(
                                "convert /tmp/terminal_check.ppm /tmp/terminal_result.png",
                                shell=True,
                                check=False,
                            )
                            found = True
                            break
                except (OSError, socket.timeout, subprocess.SubprocessError) as e:
                    print(
                        f"  screendump compare failed at ({mx}, {ty}): "
                        f"{type(e).__name__}: {e}",
                        file=sys.stderr,
                    )
                click(s, mx, 10)
                time.sleep(0.4)
            if found:
                break
    finally:
        try:
            s.close()
        except OSError:
            pass
    return found


def enable_remote_login(typer: "QEMUTyper | None" = None) -> None:
    """Type systemsetup Remote Login on into Terminal. Never SIP/AMFI/SSV."""
    cmds = [
        "sudo systemsetup -setremotelogin on",
        "sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist",
        "sudo launchctl load -w /System/Library/LaunchDaemons/com.openssh.sshd.plist",
    ]
    if typer is not None:
        typer.enable_ssh_via_terminal()
        return
    for c in cmds:
        assert_safe_text(c)
        print(f"qmon-type: {c}")
        for ch in c:
            if ch == " ":
                qmon("sendkey spc")
            elif ch == "/":
                qmon("sendkey slash")
            elif ch == "-":
                qmon("sendkey minus")
            elif ch == ".":
                qmon("sendkey dot")
            elif ch.isupper():
                qmon(f"sendkey shift-{ch.lower()}")
            else:
                qmon(f"sendkey {ch}")
            time.sleep(0.05)
        qmon("sendkey ret")
        time.sleep(1.5)
        for ch in os.environ.get("MACOS_PASS", "alpine"):
            qmon(f"sendkey {ch}")
            time.sleep(0.05)
        qmon("sendkey ret")
        time.sleep(2.0)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Open Terminal + optional Remote Login")
    ap.add_argument(
        "--enable-ssh",
        action="store_true",
        help="After opening Terminal, enable Remote Login via systemsetup",
    )
    ap.add_argument(
        "--drive-setup",
        action="store_true",
        help="Run full drive-setup (capture + Setup Assistant + enable ssh)",
    )
    ap.add_argument(
        "--force",
        action="store_true",
        help="With --drive-setup, force Setup even if screen dark/SSV",
    )
    ap.add_argument(
        "--work",
        default=str(EVIDENCE_DIR),
        help="Evidence directory for dumps (default /tmp/w7_setup)",
    )
    ap.add_argument(
        "--vnc",
        action="store_true",
        help="Also try VNC Utilities menu click path",
    )
    ap.add_argument(
        "--no-keyboard",
        action="store_true",
        help="Skip keyboard path (VNC only)",
    )
    args = ap.parse_args(argv)

    work = Path(args.work)
    work.mkdir(parents=True, exist_ok=True)

    typer = None
    if QEMUTyper is not None:
        try:
            typer = QEMUTyper(host=MONITOR_HOST, port=MONITOR_PORT)
        except SystemExit:
            typer = None
            print("WARNING: QEMUTyper connect failed; falling back to qmon", file=sys.stderr)

    try:
        if args.drive_setup:
            if drive_setup is not None and typer is not None:
                return int(drive_setup(typer, work, force=bool(args.force)))
            print("drive_setup unavailable without qemu_typer; doing open+enable only")
            stamp = utc_stamp()
            qmon(f"screendump {work}/w7_setup_before_{stamp}.ppm")
            open_terminal_keyboard(typer)
            if args.vnc:
                open_terminal_vnc()
            enable_remote_login(typer)
            qmon(f"screendump {work}/w7_setup_after_ssh_{stamp}.ppm")
            return 0

        # Capture before
        stamp = utc_stamp()
        before_ppm = work / f"w7_setup_term_before_{stamp}.ppm"
        if typer is not None:
            typer.screendump(str(before_ppm))
        else:
            qmon(f"screendump {before_ppm}")

        if not args.no_keyboard:
            open_terminal_keyboard(typer)

        if args.vnc:
            open_terminal_vnc()

        if args.enable_ssh:
            enable_remote_login(typer)

        after_ppm = work / f"w7_setup_term_after_{stamp}.ppm"
        if typer is not None:
            typer.screendump(str(after_ppm))
            convert_ppm(before_ppm, work / f"w7_setup_term_before_{stamp}.png")
            convert_ppm(after_ppm, work / f"w7_setup_term_after_{stamp}.png")
            # stable names
            for src, name in (
                (before_ppm, "w7_setup_term_before.ppm"),
                (after_ppm, "w7_setup_term_after.ppm"),
            ):
                if src.exists():
                    try:
                        (work / name).write_bytes(src.read_bytes())
                    except OSError:
                        pass
            mean = screen_mean(after_ppm) if after_ppm.exists() else -1.0
            print(f"open_terminal done mean_after={mean:.1f} phase={classify_ui(mean)}")
        else:
            qmon(f"screendump {after_ppm}")

        print("Terminal open path complete")
        return 0
    finally:
        if typer is not None:
            typer.close()


if __name__ == "__main__":
    raise SystemExit(main())
