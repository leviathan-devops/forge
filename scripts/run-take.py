#!/usr/bin/env python3
"""SC-11 proof driver: provision key file, run ConnectProofUITests on the sim.

The key travels guest-file-only (never printed, never in repo). Test names
are stable: FORGEUITests/ConnectProofUITests/testConnectFlowAndPersistence.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time

HOST = "127.0.0.1"
PORT = 50922
USER = "user"
PASSWORD = "alpine"
UDID = "0DE1D698-8187-497A-8EAC-4CF80441F62D"
TAKE = sys.argv[1] if len(sys.argv) > 1 else "t78"
TEST = sys.argv[2] if len(sys.argv) > 2 else "ConnectProofUITests/testConnectFlowAndPersistence"
STILLDIR = sys.argv[3] if len(sys.argv) > 3 else "connect-proof"
KEEP_APP = len(sys.argv) > 4 and sys.argv[4] == "--no-uninstall"
SCRATCH = f"/tmp/forge-{TAKE}-scratch"

import paramiko  # noqa: E402


def connect():
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, port=PORT, username=USER, password=PASSWORD,
              allow_agent=False, look_for_keys=False, timeout=20)
    t = c.get_transport()
    t.set_keepalive(10)
    return c


def run(c, cmd, timeout=60):
    _, o, e = c.exec_command(cmd, timeout=timeout)
    out = o.read().decode("utf-8", "replace")
    err = e.read().decode("utf-8", "replace")
    return o.channel.recv_exit_status(), out, err


def main() -> int:
    # Sim-mutex (t104): the sim is a shared resource across sessions. A second
    # driver mid-take backgrounds the app (home screen, no crash) and voids
    # the take. Refuse instead of burning it.
    try:
        me = str(os.getpid())
        ps = subprocess.run(["pgrep", "-f", "run-connect-proof.py"],
                            capture_output=True, text=True, timeout=15)
        others = [p for p in ps.stdout.split() if p.strip() and p.strip() != me]
        if others:
            print(f"REFUSE concurrent take driver already running: PIDs {','.join(others)}")
            return 2
    except Exception as ex:
        print("mutex probe failed open:", ex)
    key = os.environ.get("FORGE_GO_KEY", "")
    if not key:
        print("REFUSE: FORGE_GO_KEY env required (never logged)")
        return 2
    # Authoritative anchor (operator order 2026-09-10): sync product from the
    # MIMOCODE anchor, never the legacy live tree.
    tree = "/home/leviathan/OPENCODE_WORKSPACE/Shared Workspace Context/MIMOCODE/Forge"
    for args in (
        ["sshpass", "-p", PASSWORD, "rsync", "-az",
         "-e", "ssh -p 50922 -o StrictHostKeyChecking=no "
               "-o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no",
         f"{tree}/iOS/FORGE/", "user@127.0.0.1:/Users/useruser/FORGE/iOS/FORGE/"],
        ["sshpass", "-p", PASSWORD, "rsync", "-az",
         "-e", "ssh -p 50922 -o StrictHostKeyChecking=no "
               "-o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no",
         f"{tree}/project.yml", f"{tree}/tests/",
         "user@127.0.0.1:/Users/useruser/FORGE/"],
    ):
        subprocess.check_call(args)
    print("RSYNC done")
    c = connect()
    sftp = c.open_sftp()
    with sftp.file("/tmp/connect-proof-env.json", "w") as f:
        f.write(json.dumps({"api_key": key}))
    sftp.chmod("/tmp/connect-proof-env.json", 0o600)
    print("KEYFILE provisioned (content never printed)")
    # Minimal ad-hoc entitlements: keychain group ONLY. The full dev file
    # (sandbox/icloud keys) gets launch-denied under ad-hoc (t78 lesson).
    with sftp.file("/tmp/forge-kc-ent.plist", "w") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n<dict>\n\t<key>com.apple.keychain-access-groups</key>\n\t<array>\n\t\t<string>FAKETEAMID.com.forge.app</string>\n\t</array>\n</dict>\n</plist>\n')
    print("ENTPLIST provisioned (keychain group only)")
    # Clean provider state for a true zero-override proof — unless --no-uninstall
    # (connected-state takes reuse the Keychain from a prior take on the sim).
    if not KEEP_APP:
        run(c, "xcrun simctl uninstall 0DE1D698-8187-497A-8EAC-4CF80441F62D com.forge.app || true",
            timeout=60)
    else:
        print("KEEP_APP: skipping uninstall, Keychain state carries")
    for stale in (TAKE,):
        local = os.path.join(tree, "Evidence/play/cycle-forge-" + stale, "seg-01.mp4")
        if os.path.exists(local) and os.path.getsize(local) > 1000:
            print(f"REFUSE overwrite {local}")
            return 2
    os.makedirs(os.path.join(tree, "Evidence/play/cycle-forge-" + TAKE), exist_ok=True)
    # Backup device mux during the test (stills are the primary evidence).
    run(c, "pkill -INT -f 'simctl io .*recordVideo' || true; sleep 2", timeout=30)
    run(c, "pkill -KILL -f 'simctl io .*recordVideo' || true; sleep 1", timeout=30)
    run(c, "caffeinate -dims -t 1500 >/dev/null 2>&1 < /dev/null & echo CAFFEINATED", timeout=15)
    run(c, f"rm -rf /tmp/{STILLDIR} /tmp/connect-proof-{TAKE}.mp4; mkdir -p /tmp/{STILLDIR}",
        timeout=30)
    rec = c.get_transport().open_session()
    rec.get_pty(term="xterm", width=120, height=40)
    rec.settimeout(5)
    rec.exec_command(
        "xcrun simctl io " + UDID + f" recordVideo --codec=h264 --force /tmp/connect-proof-{TAKE}.mp4"
    )
    rec_started = False
    rec_buf = ""
    t_rec_wait = time.time()
    while time.time() - t_rec_wait < 30:
        try:
            chunk = rec.recv(4096).decode("utf-8", "replace")
        except Exception:
            chunk = ""
        if chunk:
            rec_buf += chunk
            if "Recording started" in rec_buf or "Recording" in rec_buf:
                rec_started = True
                break
        if rec.exit_status_ready():
            print("REC_EXIT_EARLY", rec.recv_exit_status(), rec_buf[:300])
            break
        time.sleep(0.5)
    print("recording_started_log", rec_started, "buf", rec_buf[:200])
    if not rec_started:
        run(c, "pkill -KILL -f 'simctl io .*recordVideo' || true")
        print("REFUSE recordVideo did not start; orphan cleared, retry")
        return 2
    print("RECORDER live")
    # t78: Xcode ad-hoc signing ONLY (CLI overrides). Manual re-signs break
    # launch or Keychain group derivation; Xcode's own empty-entitlement
    # ad-hoc is the baseline under test for -34018.
    build = (
        "cd /Users/useruser/FORGE && "
        "/Users/useruser/bin/xcodegen/bin/xcodegen generate && "
        "xcodebuild build-for-testing -scheme FORGE "
        "-destination 'platform=iOS Simulator,id=" + UDID + "' "
        "-configuration Debug -sdk iphonesimulator "
        "ARCHS=x86_64 ONLY_ACTIVE_ARCH=NO EXCLUDED_ARCHS=arm64 "
        "-skipPackagePluginValidation -skipMacroValidation "
        "CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- AD_HOC_CODE_SIGNING_ALLOWED=YES "
        "-only-testing:FORGEUITests/" + TEST
    )
    rc, out, err = run(c, build + " > /tmp/connect-proof-xcodebuild.log 2>&1; "
                                  "echo XCODEBUILD_RC=$?",
                       timeout=2400)
    print("REMOTE rc=", rc)
    testrun = (
        "cd /Users/useruser/FORGE && "
        "XCTESTRUN=$(ls -t /Users/useruser/Library/Developer/Xcode/DerivedData/FORGE-*/Build/Products/*.xctestrun | head -1); "
        "xcodebuild test-without-building -xctestrun \"$XCTESTRUN\" "
        "-destination 'platform=iOS Simulator,id=" + UDID + "' "
        "-only-testing:FORGEUITests/" + TEST
    )
    rc, out, err = run(c, testrun + " >> /tmp/connect-proof-xcodebuild.log 2>&1; "
                                    "echo XCODEBUILD_RC=$?",
                       timeout=2400)
    print("REMOTE rc=", rc)
    _, tail, _ = run(c, "grep -a -E 'Test Suite|testConnectFlow|TEST FAILED|TEST PASSED|BUILD SUCCEEDED|BUILD FAILED|error:' "
                        "/tmp/connect-proof-xcodebuild.log | tail -25", timeout=60)
    print(tail)
    try:
        rec.send("\x03")
    except Exception as ex:
        print("send ctrl-c fail", ex)
    time.sleep(1)
    run(c, "pkill -INT -f 'simctl io .*recordVideo' || true")
    for _i in range(40):
        if rec.exit_status_ready():
            print("REC_EXIT", rec.recv_exit_status())
            break
        time.sleep(0.5)
    time.sleep(8)
    out_dir = os.path.join(tree, "Evidence/play/cycle-forge-" + TAKE)
    os.makedirs(SCRATCH, exist_ok=True)
    try:
        sftp.get("/tmp/connect-proof-xcodebuild.log",
                 os.path.join(SCRATCH, "connect-proof-xcodebuild.log"))
        sftp.get("/tmp/connect-proof-xcodebuild.log",
                 os.path.join(out_dir, "xcodebuild-test.log"))
        print("LOG saved to scratch + evidence")
    except Exception as ex:
        print("LOG fetch failed:", ex)
    # Key hygiene by construction (t78 lesson): XCTest echoes the typed key
    # into the xcodebuild log. Scrub exact + prefix from BOTH copies using
    # the env-only key (never persisted, never printed).
    _gokey = os.environ.get("FORGE_GO_KEY", "")
    if _gokey and len(_gokey) > 20:
        for _lp in (os.path.join(SCRATCH, "connect-proof-xcodebuild.log"),
                    os.path.join(out_dir, "xcodebuild-test.log")):
            try:
                _lt = open(_lp, errors="replace").read()
                _lt = _lt.replace(_gokey, "[REDACTED-KEY]").replace(
                    _gokey[:18], "[REDACTED-KEY-PREFIX]")
                open(_lp, "w").write(_lt)
                print("REDACTED", _lp)
            except Exception as ex:
                print("REDACT failed (treat log as contaminated):", _lp, ex)
    try:
        names = sftp.listdir(f"/tmp/{STILLDIR}")
    except Exception:
        names = []
    for name in sorted(names):
        if not name.endswith(".png"):
            continue
        try:
            sftp.get(f"/tmp/{STILLDIR}/" + name, os.path.join(out_dir, name))
            print("STILL", name)
        except Exception as ex:
            print("STILL fetch failed:", name, ex)
    try:
        sftp.get(f"/tmp/connect-proof-{TAKE}.mp4", os.path.join(out_dir, "seg-01.mp4"))
        print("MUX saved")
    except Exception as ex:
        print("MUX fetch failed (stills carry the proof):", ex)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
