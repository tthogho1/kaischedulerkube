#!/usr/bin/env bash
# Destroy all AWS resources created by this project.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_cmd terraform

cd "${TF_DIR}"

echo "The following resources will be destroyed (EC2, VPC, SecurityGroup, KeyPair, etc.):"
terraform plan -destroy

read -r -p "Are you sure you want to destroy them? [y/N]: " confirm
if [ "${confirm}" != "y" ] && [ "${confirm}" != "Y" ]; then
  echo "Aborted."
  exit 0
fi

terraform destroy -auto-approve
