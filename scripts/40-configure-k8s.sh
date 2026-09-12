#!/usr/bin/env bash
# Configure the k8s cluster (control-plane + GPU workers) with Ansible,
# then install the KAI Scheduler.
# Set KAI=false to skip the KAI Scheduler install.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_cmd ansible-playbook

cd "${ANSIBLE_DIR}"

ansible-playbook -i inventory/hosts.ini playbooks/01-control-plane.yml
ansible-playbook -i inventory/hosts.ini playbooks/02-gpu-worker.yml

if [ "${KAI:-true}" = "true" ]; then
  ansible-playbook -i inventory/hosts.ini playbooks/03-kai-scheduler.yml
else
  echo "KAI=false was set, so the KAI Scheduler install (03-kai-scheduler.yml) was skipped."
  echo "To install it later, run:"
  echo "  cd ${ANSIBLE_DIR} && ansible-playbook -i inventory/hosts.ini playbooks/03-kai-scheduler.yml"
fi
