#!/usr/bin/env bash
# Create the AWS infrastructure (VPC, SecurityGroup, EC2) with Terraform.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_cmd terraform aws

if [ ! -f "${TF_DIR}/terraform.tfvars" ]; then
  echo "Error: ${TF_DIR}/terraform.tfvars not found."
  echo "  cp terraform/terraform.tfvars.example terraform/terraform.tfvars"
  echo "Run the command above, then edit the file."
  exit 1
fi

cd "${TF_DIR}"
terraform init -input=false
terraform apply -auto-approve

echo
echo "=== Terraform outputs ==="
terraform output
