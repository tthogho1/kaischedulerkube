#!/usr/bin/env bash
# Wait until all nodes are reachable over SSH (avoids connection errors
# right after the instances boot).
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_cmd ansible

echo "Checking SSH connectivity..."
for i in $(seq 1 30); do
  if ansible -i "${ANSIBLE_DIR}/inventory/hosts.ini" all -m ping >/dev/null 2>&1; then
    echo "All nodes are now reachable over SSH."
    exit 0
  fi
  echo "  Waiting... (${i}/30)"
  sleep 10
done

echo "Error: timed out. Check the instance boot state and Security Group rules." >&2
exit 1
