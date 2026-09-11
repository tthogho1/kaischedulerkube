#!/usr/bin/env bash
# Runs everything from infra creation through k8s cluster configuration.
# To also install Run:ai in one go: RUNAI=true ./scripts/deploy-all.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${SCRIPT_DIR}/10-deploy-infra.sh"
"${SCRIPT_DIR}/20-generate-inventory.sh"
"${SCRIPT_DIR}/30-wait-for-ssh.sh"
"${SCRIPT_DIR}/40-configure-k8s.sh"

echo
echo "=== Done ==="
echo "To check the cluster with kubectl, SSH into the control plane:"
echo "  ssh -i <private-key> ubuntu@\$(cd terraform && terraform output -raw control_plane_public_ip)"
echo "  kubectl get nodes"
