#!/usr/bin/env bash
# Deploy forge tree to macOS guest over SSH (password auth; avoids ssh-agent key spam).
# Usage: ./scripts/deploy-to-vm.sh
# Wave2/hardened: atomic swap extract, park DerivedData, require project.yml + xcodegen.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST="${FORGE_VM_HOST:-127.0.0.1}"
PORT="${FORGE_SSH_PORT:-50922}"
USER="${FORGE_VM_USER:-user}"
PASS="${FORGE_VM_PASS:-alpine}"

"$ROOT/docker/run-forge-vm.sh" up >/dev/null || true

# NOTE: unquoted <<PY so ${ROOT@Q} expands; remote shell $vars must be written as \$var
python3 - <<PY
import os, sys, tarfile, io, paramiko
root = ${ROOT@Q}
buf = io.BytesIO()
exclude_dirs = {
    "node_modules", ".git", "tmp", "__pycache__", ".checkpoints",
    "DerivedData", "DerivedDataFullVerify", "DerivedDataBuild",
}
must = ["project.yml", "iOS/FORGE/Resources/forge-bundle.js"]
for rel in must:
    p = os.path.join(root, rel)
    if not os.path.isfile(p):
        print("HOST_MISSING", rel, file=sys.stderr)
        sys.exit(2)

with tarfile.open(fileobj=buf, mode="w:gz") as tar:
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in exclude_dirs and not d.startswith("DerivedData")]
        for fn in filenames:
            if fn.endswith((".ppm", ".pyc")):
                continue
            fp = os.path.join(dirpath, fn)
            arc = os.path.join("FORGE", os.path.relpath(fp, root))
            try:
                tar.add(fp, arcname=arc)
            except OSError as e:
                print("skip", fp, e, file=sys.stderr)

buf.seek(0)
payload = buf.getvalue()
print("pack_bytes", len(payload))

tcheck = tarfile.open(fileobj=io.BytesIO(payload), mode="r:gz")
names = set(tcheck.getnames())
tcheck.close()
for rel in must:
    arc = "FORGE/" + rel
    if arc not in names:
        print("TAR_MISSING", arc, file=sys.stderr)
        sys.exit(3)
print("tar_ok project.yml+bundle")

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(${HOST@Q}, port=int(${PORT@Q}), username=${USER@Q}, password=${PASS@Q},
          allow_agent=False, look_for_keys=False, timeout=30)
sftp = c.open_sftp()
with sftp.file("/tmp/forge.tgz", "wb") as f:
    f.write(payload)
sftp.close()

remote = r"""
set -e
export PATH="\$HOME/bin:/usr/bin:/bin:\$PATH"

pkill -f 'FORGE.app/FORGE' 2>/dev/null || true
sleep 1

ts=\$(date +%Y%m%dT%H%M%S)
for d in DerivedData DerivedDataFullVerify DerivedDataBuild DerivedDataW2; do
  if [ -d "/Users/user/FORGE/\$d" ]; then
    mv "/Users/user/FORGE/\$d" "/Users/user/\${d}.parked.\$ts" 2>/dev/null \
      || rm -rf "/Users/user/FORGE/\$d" 2>/dev/null || true
  fi
done

rm -rf /Users/user/FORGE.new /Users/user/FORGE.old /Users/user/FORGE.swap
mkdir -p /Users/user/FORGE.new
tar xzf /tmp/forge.tgz -C /Users/user/FORGE.new
if [ -d /Users/user/FORGE.new/FORGE ] && [ ! -f /Users/user/FORGE.new/project.yml ]; then
  mv /Users/user/FORGE.new/FORGE /Users/user/FORGE.swap
  rm -rf /Users/user/FORGE.new
  mv /Users/user/FORGE.swap /Users/user/FORGE.new
fi

test -f /Users/user/FORGE.new/project.yml
test -f /Users/user/FORGE.new/iOS/FORGE/Resources/forge-bundle.js

if [ -d /Users/user/FORGE ]; then
  mv /Users/user/FORGE /Users/user/FORGE.old
fi
mv /Users/user/FORGE.new /Users/user/FORGE
rm -rf /Users/user/FORGE.old 2>/dev/null || true

chmod +x /Users/user/FORGE/scripts/*.sh 2>/dev/null || true

latest=\$(ls -1d /Users/user/DerivedDataFullVerify.parked.* 2>/dev/null | tail -1 || true)
if [ -n "\${latest:-}" ] && [ ! -d /Users/user/FORGE/DerivedDataFullVerify ]; then
  mv "\$latest" /Users/user/FORGE/DerivedDataFullVerify 2>/dev/null || true
fi

if [ -x /Users/user/bin/xcodegen ]; then
  (cd /Users/user/FORGE && /Users/user/bin/xcodegen generate) >/tmp/xcodegen-post-deploy.log 2>&1 \
    && echo XCODEGEN_OK \
    || { echo XCODEGEN_FAIL; tail -40 /tmp/xcodegen-post-deploy.log; exit 4; }
  test -d /Users/user/FORGE/FORGE.xcodeproj && echo XCODEPROJ_OK || { echo XCODEPROJ_MISSING; exit 5; }
else
  echo XCODEGEN_SKIP
fi

echo DEPLOY_OK
ls /Users/user/FORGE | head -20
test -f /Users/user/FORGE/project.yml && echo PROJECT_YML_OK
test -f /Users/user/FORGE/iOS/FORGE/Resources/forge-bundle.js && echo BUNDLE_OK
"""

_, o, e = c.exec_command(remote, timeout=180)
out = o.read().decode()
err = e.read().decode()
rc = o.channel.recv_exit_status()
print(out)
if err.strip():
    print(err, file=sys.stderr)
c.close()
if rc != 0 or "DEPLOY_OK" not in out:
    print("DEPLOY_FAILED rc=", rc, file=sys.stderr)
    sys.exit(rc or 1)
if "XCODEGEN_FAIL" in out:
    sys.exit(4)
print("done")
PY
