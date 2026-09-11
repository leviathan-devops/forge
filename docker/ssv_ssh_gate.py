#!/usr/bin/env python3
"""Wave 3 SSV wait + Setup Assistant keyboard path + enable SSH + prove :50922.

Runs **inside** forge-vm (has QEMU monitor :4444) OR on host with docker exec.

Phases:
  install  — startosinstall still running (dark recovery Terminal)
  reboot   — screen change / QEMU still up after install
  ssv      — first boot / verbose / progress (wait 60–90+ min; NEVER kill QEMU)
  setup    — Setup Assistant / login (brighter UI)
  desktop  — attempt enable Remote Login via Terminal
  ssh_ok   — host port 50922 answers hostname

Evidence lands under host project tmp/ when HOST_EVIDENCE_DIR is set, else /tmp/ssv_ssh/.
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

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    Image = None  # type: ignore

MONITOR_HOST = os.environ.get("QEMU_MONITOR_HOST", "127.0.0.1")
MONITOR_PORT = int(os.environ.get("QEMU_MONITOR_PORT", "4444"))
SSH_HOST = os.environ.get("SSH_PROBE_HOST", "127.0.0.1")
SSH_PORT = int(os.environ.get("SSH_PROBE_PORT", "10022"))  # in-container; host uses 50922
SSH_USERS = [u.strip() for u in os.environ.get("SSH_USERS", "user,alpine,admin").split(",") if u.strip()]
ACCOUNT_USER = os.environ.get("MACOS_USER", "user")
ACCOUNT_PASS = os.environ.get("MACOS_PASS", "alpine")
ACCOUNT_FULL = os.environ.get("MACOS_FULLNAME", "Forge User")


def utc_stamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def log(msg: str, log_path: Path | None = None) -> None:
    line = f"[{datetime.now(timezone.utc).strftime('%H:%M:%S')}Z] {msg}"
    print(line, flush=True)
    if log_path is not None:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        with log_path.open("a", encoding="utf-8") as f:
            f.write(line + "\n")


class QemuMon:
    def __init__(self, host=MONITOR_HOST, port=MONITOR_PORT):
        self.host = host
        self.port = port

    def _connect(self) -> socket.socket:
        last = None
        for _ in range(3):
            try:
                s = socket.socket()
                s.settimeout(2.0)
                s.connect((self.host, self.port))
                time.sleep(0.25)
                try:
                    s.recv(8192)
                except (socket.timeout, OSError):
                    pass
                return s
            except OSError as e:
                last = e
                time.sleep(0.4)
        raise SystemExit(f"monitor connect failed: {last}")

    def cmd(self, command: str, wait: float = 0.15) -> None:
        s = self._connect()
        try:
            s.sendall((command + "\n").encode())
            time.sleep(wait)
        finally:
            s.close()

    def sendkey(self, key: str, hold: float = 0.08) -> None:
        self.cmd(f"sendkey {key}", wait=hold)

    def screendump(self, path: str) -> None:
        self.cmd(f"screendump {path}", wait=1.2)


def type_str(mon: QemuMon, text: str) -> None:
    for ch in text:
        if ch.isupper():
            mon.sendkey(f"shift-{ch.lower()}")
        elif ch.islower() or ch.isdigit():
            mon.sendkey(ch)
        elif ch == " ":
            mon.sendkey("spc")
        elif ch == "/":
            mon.sendkey("slash")
        elif ch == "-":
            mon.sendkey("minus")
        elif ch == ".":
            mon.sendkey("dot")
        elif ch == ":":
            mon.sendkey("shift-semicolon")
        elif ch == "_":
            mon.sendkey("shift-minus")
        elif ch == "=":
            mon.sendkey("equal")
        elif ch == '"':
            mon.sendkey("shift-apostrophe")
        elif ch == "'":
            mon.sendkey("apostrophe")
        elif ch == "@":
            mon.sendkey("shift-2")
        elif ch == "!":
            mon.sendkey("shift-1")
        else:
            log(f"WARNING skip char {ch!r}")


def convert_ppm(ppm: Path, png: Path) -> bool:
    for tool in ("convert", "magick"):
        try:
            r = subprocess.run(
                [tool, str(ppm), str(png)],
                capture_output=True,
                timeout=30,
                check=False,
            )
            if r.returncode == 0 and png.exists() and png.stat().st_size > 1000:
                return True
        except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
            continue
    return False


def screen_stats(png: Path) -> dict:
    """Brightness stats from PNG (PIL) or sibling .ppm (stdlib)."""
    size = png.stat().st_size if png.exists() else 0
    # Prefer PIL when present
    if Image is not None and png.exists():
        try:
            img = Image.open(png).convert("L")
            w, h = img.size
            data = list(img.resize((max(1, w // 8), max(1, h // 8))).getdata())
            mean = float(statistics.mean(data)) if data else -1.0
            cx0, cy0, cx1, cy1 = w // 4, h // 4, 3 * w // 4, 3 * h // 4
            crop = img.crop((cx0, cy0, cx1, cy1)).resize(
                (max(1, (cx1 - cx0) // 8), max(1, (cy1 - cy0) // 8))
            )
            cdata = list(crop.getdata())
            center = float(statistics.mean(cdata)) if cdata else -1.0
            return {"mean": mean, "center": center, "size": size}
        except Exception:
            pass
    # Fallback: raw PPM P6 from sibling path
    ppm = png.with_suffix(".ppm")
    if not ppm.exists():
        return {"mean": -1.0, "center": -1.0, "size": size}
    try:
        raw = ppm.read_bytes()
        # header: P6\nW H\n255\n
        if not raw.startswith(b"P6"):
            return {"mean": -1.0, "center": -1.0, "size": size}
        # skip comments
        i = 2
        parts = []
        while len(parts) < 3 and i < len(raw):
            if raw[i] == ord("#"):
                while i < len(raw) and raw[i] not in (10, 13):
                    i += 1
                i += 1
                continue
            if raw[i] in (9, 10, 13, 32):
                i += 1
                continue
            j = i
            while j < len(raw) and raw[j] not in (9, 10, 13, 32):
                j += 1
            parts.append(raw[i:j].decode())
            i = j + 1
        w, h, maxv = int(parts[0]), int(parts[1]), int(parts[2])
        # find data start after header newline
        # re-parse carefully
        nl = raw.find(b"\n", raw.find(b"255"))
        if nl < 0:
            return {"mean": -1.0, "center": -1.0, "size": size}
        data = raw[nl + 1 :]
        step = 24  # sample every 8th pixel * 3 channels
        samples = []
        for off in range(0, min(len(data) - 2, w * h * 3), step):
            r, g, b = data[off], data[off + 1], data[off + 2]
            samples.append((r + g + b) / 3.0)
        mean = float(statistics.mean(samples)) if samples else -1.0
        return {"mean": mean, "center": mean, "size": size}
    except Exception:
        return {"mean": -1.0, "center": -1.0, "size": size}


def classify_phase(stats: dict, mac_hdd_bytes: int, prev: str) -> str:
    mean = stats.get("mean", -1)
    center = stats.get("center", -1)
    # Brighter UI → Setup Assistant / Desktop / login
    if mean >= 55 or center >= 60:
        return "setup"
    # Mid brightness can be progress bars / install GUI
    if mean >= 35:
        return "gui_mid"
    # Dark: recovery terminal or verbose boot
    if mac_hdd_bytes > 12 * 1024**3 and prev in ("install", "reboot", "ssv", "gui_mid"):
        # large disk writes finished-ish → likely first boot / SSV
        return "ssv"
    if prev in ("ssv", "reboot") and mean < 40:
        return "ssv"
    if mac_hdd_bytes < 8 * 1024**3:
        return "install"
    return prev or "install"


def mac_hdd_size() -> int:
    for p in (
        Path("/data/mac_hdd_ng.img"),
        Path("/home/arch/OSX-KVM/mac_hdd_ng.img"),
    ):
        try:
            if p.exists():
                return p.stat().st_size
        except OSError:
            continue
    return -1


def qemu_alive() -> bool:
    try:
        r = subprocess.run(
            ["pgrep", "-x", "qemu-system-x86"],
            capture_output=True,
            check=False,
        )
        return r.returncode == 0
    except OSError:
        return False


def probe_ssh(host: str, port: int, user: str, password: str | None = None) -> tuple[bool, str]:
    """Try BatchMode first; optional sshpass if password given."""
    base = [
        "ssh",
        "-o",
        "StrictHostKeyChecking=no",
        "-o",
        "UserKnownHostsFile=/dev/null",
        "-o",
        "GlobalKnownHostsFile=/dev/null",
        "-o",
        "ConnectTimeout=8",
        "-o",
        "PreferredAuthentications=password,keyboard-interactive,publickey",
        "-o",
        "PubkeyAuthentication=no",
        "-p",
        str(port),
        f"{user}@{host}",
        "hostname",
    ]
    # BatchMode no-password attempt
    try:
        r = subprocess.run(
            base[:1]
            + ["-o", "BatchMode=yes", "-o", "PasswordAuthentication=no"]
            + base[1:],
            capture_output=True,
            text=True,
            timeout=20,
            check=False,
        )
        out = (r.stdout or "") + (r.stderr or "")
        if r.returncode == 0 and r.stdout.strip():
            return True, r.stdout.strip()
    except (subprocess.TimeoutExpired, OSError) as e:
        out = str(e)

    if password:
        # sshpass if available
        try:
            r = subprocess.run(
                ["sshpass", "-p", password] + base,
                capture_output=True,
                text=True,
                timeout=25,
                check=False,
            )
            if r.returncode == 0 and (r.stdout or "").strip():
                return True, r.stdout.strip()
            out = (r.stdout or "") + (r.stderr or "")
        except FileNotFoundError:
            out = (out or "") + "\nsshpass not installed"
        except (subprocess.TimeoutExpired, OSError) as e:
            out = str(e)

    # TCP / banner check
    try:
        s = socket.create_connection((host, port), timeout=5)
        s.settimeout(3)
        try:
            banner = s.recv(200).decode("utf-8", "replace")
        except OSError:
            banner = ""
        s.close()
        return False, f"tcp_open banner={banner!r} ssh_out={out[:300]!r}"
    except OSError as e:
        return False, f"tcp_fail: {e}; ssh_out={out[:200]!r}"


def open_terminal_menu(mon: QemuMon) -> None:
    """Keyboard path: menu bar → Utilities-ish → Terminal (best-effort)."""
    mon.sendkey("ctrl-f2")
    time.sleep(0.5)
    for _ in range(4):
        mon.sendkey("right")
        time.sleep(0.15)
    mon.sendkey("down")
    time.sleep(0.2)
    for _ in range(6):
        mon.sendkey("down")
        time.sleep(0.12)
    mon.sendkey("ret")
    time.sleep(2.0)


def enable_ssh_via_terminal(mon: QemuMon) -> None:
    """Type systemsetup + launchctl fallback into focused Terminal."""
    cmds = [
        f"sudo systemsetup -setremotelogin on",
        "sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist",
        "sudo launchctl load -w /System/Library/LaunchDaemons/com.openssh.sshd.plist",
    ]
    for c in cmds:
        type_str(mon, c)
        mon.sendkey("ret")
        time.sleep(1.5)
        # password prompt for sudo
        type_str(mon, ACCOUNT_PASS)
        mon.sendkey("ret")
        time.sleep(2.0)


def setup_assistant_pass(mon: QemuMon, rounds: int = 8) -> None:
    """Best-effort Tab/Return through Setup Assistant screens; create local account if fields focused."""
    for i in range(rounds):
        # Continue / next
        mon.sendkey("ret")
        time.sleep(1.2)
        mon.sendkey("tab")
        time.sleep(0.3)
        if i in (2, 3, 4):
            # Sometimes need to select "Set Up Later" / "Not Now" — Space or arrows
            mon.sendkey("down")
            time.sleep(0.2)
            mon.sendkey("ret")
            time.sleep(0.8)
        if i == 5:
            # Attempt account fields: full name → account → pass → verify
            type_str(mon, ACCOUNT_FULL)
            mon.sendkey("tab")
            time.sleep(0.3)
            type_str(mon, ACCOUNT_USER)
            mon.sendkey("tab")
            time.sleep(0.3)
            type_str(mon, ACCOUNT_PASS)
            mon.sendkey("tab")
            time.sleep(0.3)
            type_str(mon, ACCOUNT_PASS)
            mon.sendkey("tab")
            time.sleep(0.3)
            mon.sendkey("ret")
            time.sleep(2.0)


def capture(mon: QemuMon, work: Path, tag: str) -> tuple[Path, dict]:
    ppm = work / f"{tag}.ppm"
    png = work / f"{tag}.png"
    mon.screendump(str(ppm))
    convert_ppm(ppm, png)
    st = screen_stats(png) if png.exists() else {"mean": -1.0, "center": -1.0, "size": 0}
    return png, st


def main() -> int:
    ap = argparse.ArgumentParser(description="SSV wait + SSH gate for forge-vm")
    ap.add_argument("--interval", type=int, default=120, help="poll seconds (default 120)")
    ap.add_argument("--max-hours", type=float, default=3.0, help="max wall time hours")
    ap.add_argument("--work", default="/tmp/ssv_ssh", help="working dir for dumps")
    ap.add_argument("--ssh-host", default=None)
    ap.add_argument("--ssh-port", type=int, default=None)
    ap.add_argument("--setup-every", type=int, default=5, help="every N polls try setup keys when setup-like")
    ap.add_argument("--enable-ssh-every", type=int, default=3, help="every N setup polls try enable ssh")
    args = ap.parse_args()

    work = Path(args.work)
    work.mkdir(parents=True, exist_ok=True)
    log_path = work / "ssv_ssh_gate.log"
    ssh_host = args.ssh_host or SSH_HOST
    ssh_port = args.ssh_port if args.ssh_port is not None else SSH_PORT

    mon = QemuMon()
    phase = "install"
    setup_tries = 0
    enable_tries = 0
    poll = 0
    t0 = time.time()
    max_s = args.max_hours * 3600

    log(f"START ssv_ssh_gate work={work} ssh={ssh_host}:{ssh_port} interval={args.interval}s", log_path)

    # Initial capture
    png, st = capture(mon, work, f"poll_{poll:04d}_{utc_stamp()}")
    hdd = mac_hdd_size()
    phase = classify_phase(st, hdd, phase)
    log(f"poll={poll} phase={phase} mean={st['mean']:.1f} center={st['center']:.1f} hdd={hdd} png={png}", log_path)

    while time.time() - t0 < max_s:
        time.sleep(args.interval)
        poll += 1
        if not qemu_alive():
            log("FATAL QEMU_DEAD — abort (do not claim SSH)", log_path)
            return 2

        tag = f"poll_{poll:04d}_{utc_stamp()}"
        png, st = capture(mon, work, tag)
        hdd = mac_hdd_size()
        phase = classify_phase(st, hdd, phase)
        elapsed_m = (time.time() - t0) / 60.0
        log(
            f"poll={poll} phase={phase} mean={st['mean']:.1f} center={st['center']:.1f} "
            f"hdd={hdd} elapsed_min={elapsed_m:.1f} png={png.name}",
            log_path,
        )

        # Always probe SSH
        for user in SSH_USERS:
            ok, detail = probe_ssh(ssh_host, ssh_port, user, ACCOUNT_PASS if user in (ACCOUNT_USER, "alpine") else None)
            log(f"ssh_probe user={user} ok={ok} detail={detail[:200]}", log_path)
            if ok:
                transcript = work / "ssh_hostname_transcript.txt"
                body = (
                    f"# SSH proof {utc_stamp()}\n"
                    f"command: ssh -p {ssh_port} {user}@{ssh_host} hostname\n"
                    f"exit: 0\n"
                    f"stdout: {detail}\n"
                    f"phase_elapsed_min: {elapsed_m:.1f}\n"
                    f"poll: {poll}\n"
                )
                transcript.write_text(body, encoding="utf-8")
                log(f"SSH_OK hostname={detail} transcript={transcript}", log_path)
                # final dump
                capture(mon, work, f"ssh_ok_{utc_stamp()}")
                return 0

        # Setup Assistant / brighter UI automation
        if phase in ("setup", "gui_mid") or st["mean"] >= 45:
            setup_tries += 1
            if setup_tries % max(1, args.setup_every) == 0:
                log(f"setup_assistant_pass try #{setup_tries}", log_path)
                setup_assistant_pass(mon, rounds=6)
                capture(mon, work, f"after_setup_{setup_tries}_{utc_stamp()}")

            enable_tries += 1
            if enable_tries % max(1, args.enable_ssh_every) == 0:
                log(f"enable_ssh_via_terminal try #{enable_tries}", log_path)
                open_terminal_menu(mon)
                time.sleep(2)
                # Spotlight fallback
                mon.sendkey("cmd-spc")
                time.sleep(1)
                type_str(mon, "Terminal")
                mon.sendkey("ret")
                time.sleep(2)
                enable_ssh_via_terminal(mon)
                capture(mon, work, f"after_enable_ssh_{enable_tries}_{utc_stamp()}")

        # After long dark SSV, occasionally send Return (in case of login/progress)
        if phase == "ssv" and poll % 10 == 0:
            log("ssv nudge: ret", log_path)
            mon.sendkey("ret")

    log("TIMEOUT without SSH proof", log_path)
    return 1


if __name__ == "__main__":
    sys.exit(main())
