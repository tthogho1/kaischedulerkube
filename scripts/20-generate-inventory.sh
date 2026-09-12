#!/usr/bin/env bash
# Generate the Ansible inventory from terraform output.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_cmd terraform jq

cd "${TF_DIR}"
OUT_JSON="$(terraform output -json)"

CP_IP="$(echo "${OUT_JSON}" | jq -r '.control_plane_public_ip.value')"
GPU_IPS=()
while IFS= read -r ip; do
  GPU_IPS+=("${ip}")
done < <(echo "${OUT_JSON}" | jq -r '.gpu_worker_public_ips.value[]')

INVENTORY_FILE="${ANSIBLE_DIR}/inventory/hosts.ini"

{
  echo "# Auto-generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "[control_plane]"
  echo "cp1 ansible_host=${CP_IP}"
  echo
  echo "[gpu_workers]"
  i=1
  for ip in "${GPU_IPS[@]}"; do
    echo "gpu${i} ansible_host=${ip}"
    i=$((i + 1))
  done
  echo
  echo "[k8s_cluster:children]"
  echo "control_plane"
  echo "gpu_workers"
  echo
  echo "[all:vars]"
  echo "ansible_user=ubuntu"
  echo "ansible_ssh_private_key_file=${SSH_PRIVATE_KEY}"
  echo "ansible_ssh_common_args='-o StrictHostKeyChecking=no'"
} > "${INVENTORY_FILE}"

mkdir -p "${ANSIBLE_DIR}/.generated"

echo "Inventory generated: ${INVENTORY_FILE}"
cat "${INVENTORY_FILE}"
