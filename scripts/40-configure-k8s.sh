#!/usr/bin/env bash
# Configure the k8s cluster (control-plane + GPU workers) with Ansible.
# Set RUNAI=true if you also want to install Run:ai.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_cmd ansible-playbook

cd "${ANSIBLE_DIR}"

ansible-playbook -i inventory/hosts.ini playbooks/01-control-plane.yml
ansible-playbook -i inventory/hosts.ini playbooks/02-gpu-worker.yml

if [ "${RUNAI:-false}" = "true" ]; then
  ansible-playbook -i inventory/hosts.ini playbooks/03-runai.yml -e runai_install_enabled=true
else
  echo "RUNAI=true was not set, so the Run:ai install (03-runai.yml) was skipped."
  echo "Once your Run:ai tenant information is ready, run:"
  echo "  RUNAI=true ansible-playbook -i ${ANSIBLE_DIR}/inventory/hosts.ini ${ANSIBLE_DIR}/playbooks/03-runai.yml"
fi
