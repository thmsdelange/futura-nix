set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: host-info <user> <hostname/IP>"
    exit 1
fi

USER="$1"
HOST="$2"

ssh -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "$USER@$HOST" << 'EOF'
    set -euo pipefail

    echo "===== Network Controllers ====="
    if command -v lspci >/dev/null 2>&1; then
    lspci -v | grep -iA8 'network\|ethernet' || true
    else
    echo "lspci not installed"
    fi
    echo ""

    echo "===== Physical Drives ====="
    lsblk -d -o NAME,SIZE,TYPE,MODEL | grep -E "(disk|nvme)" || true
    echo ""

    echo "===== Generated ZFS hostid ====="
    HOST_ID=$(echo "$(date +%s)$(hostname)" | md5sum | cut -c1-8)
    echo "hostid = $HOST_ID"
EOF
