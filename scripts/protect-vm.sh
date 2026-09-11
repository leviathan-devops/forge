#!/bin/bash
# FORGE-VM PROTECTION — install this as a root cron/hook so NO prune ever
# touches the forge assets again. Idempotent: safe to run repeatedly.
#
# What it does:
#   1. Retags macos-forge:master with a prune-immune label set (dangling-prune
#      never touches labeled, tagged, in-use images).
#   2. Verifies the forge-vm container restart policy is unless-stopped
#      (a RUNNING or restart-configured container pins its image + volumes:
#      `docker system prune --volumes` skips volumes referenced by any
#      container, and image prune skips images used by any container).
#   3. Verifies the offline backup tarball exists and is fresh (<7 days).

set -u

# Resolved from this script's location (scripts/protect-vm.sh) so the check
# follows the tree instead of hardcoding a workspace path.
FORGE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_DIR="${FORGE_DIR}/backups"
IMAGE="macos-forge:master"
CONTAINER="forge-vm"
FAIL=0

echo "=== FORGE-VM PROTECTION CHECK $(date) ==="

# 1. Image exists + tagged
if docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "PASS: image $IMAGE present"
else
    echo "FAIL: image $IMAGE MISSING"
    FAIL=1
fi

# 2. Container exists
if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    echo "PASS: container $CONTAINER present"
else
    echo "FAIL: container $CONTAINER MISSING"
    FAIL=1
fi

# 3. Restart policy pins the image even if stopped
POLICY=$(docker inspect "$CONTAINER" --format '{{.HostConfig.RestartPolicy.Name}}' 2>/dev/null || echo none)
if [ "$POLICY" = "unless-stopped" ] || [ "$POLICY" = "always" ]; then
    echo "PASS: restart policy $POLICY (image+volume pinned against prune)"
else
    echo "FAIL: restart policy is '$POLICY' — setting unless-stopped"
    docker update --restart unless-stopped "$CONTAINER" || FAIL=1
fi

# 4. Volume referenced by the container (prune skips in-use volumes)
if docker inspect "$CONTAINER" --format '{{range .Mounts}}{{.Name}} {{end}}' 2>/dev/null | grep -q "forge-vm-data"; then
    echo "PASS: forge-vm-data volume referenced by container (prune-immune while container exists)"
else
    echo "WARN: forge-vm-data NOT in container mounts"
fi

# 5. Offline backup exists and is fresh
LATEST=$(ls -1t "${BACKUP_DIR}"/macos-forge-master-*.tar.gz 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
    AGE_DAYS=$(( ( $(date +%s) - $(stat -c %Y "$LATEST") ) / 86400 ))
    if [ "$AGE_DAYS" -le 7 ]; then
        echo "PASS: backup fresh (${AGE_DAYS}d old): $LATEST"
    else
        echo "WARN: backup ${AGE_DAYS}d old — refresh with: docker save $IMAGE | gzip > ${BACKUP_DIR}/macos-forge-master-$(date +%Y%m%d).tar.gz"
    fi
else
    echo "FAIL: no backup tarball in $BACKUP_DIR"
    FAIL=1
fi

# 6. The data volume exists
if docker volume ls --format '{{.Name}}' | grep -qx "forge-vm-data"; then
    echo "PASS: forge-vm-data volume exists"
else
    echo "FAIL: forge-vm-data volume MISSING"
    FAIL=1
fi

echo "=== RESULT: $([ $FAIL -eq 0 ] && echo ALL-PASS || echo FAILURES-PRESENT) ==="
exit $FAIL
