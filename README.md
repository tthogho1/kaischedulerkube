# Run:ai on Kubernetes (AWS) — Terraform + Ansible

Builds the following setup on AWS.

| Role | Instance type | vCPU | Memory | GPU | Purpose |
|---|---|---|---|---|---|
| Control plane | t3.large | 2 | 8 GB | none | k8s server + Run:ai control plane pods |
| GPU worker | g4dn.xlarge | 4 | 16 GB | T4 x1 | GPU workload execution |

Terraform provisions the infrastructure (VPC/SecurityGroup/EC2), and Ansible configures Kubernetes (kubeadm + containerd + Calico) plus the NVIDIA driver/container runtime. Installing Run:ai itself requires tenant-specific information, so only a scaffold/placeholder is provided.

## Directory layout

```
terraform/   AWS infrastructure definitions
ansible/     k8s / NVIDIA / Run:ai configuration
scripts/     Shell scripts to run the whole workflow
```

## Prerequisites

The following must be installed on the machine you run these scripts from (bash / WSL / Linux / macOS):

- terraform >= 1.5
- aws cli (with credentials configured via `aws configure`)
- ansible / ansible-playbook
- jq

### Running via Docker (Windows / Docker Desktop)

If you don't want to install terraform/ansible/aws-cli/jq directly on your machine (e.g. on Windows), a `Dockerfile` and `docker-compose.yml` are provided with everything pre-installed.

```powershell
docker compose build
docker compose run --rm runaikube
```

This mounts the project directory into the container, along with `%USERPROFILE%\.aws` (read-only) and `%USERPROFILE%\.ssh`, and drops you into a bash shell at `/workspace` with `terraform`, `ansible-playbook`, `aws`, and `jq` ready to use. All commands under [Usage](#usage) below are run inside this shell.

- Set your AWS profile name in the `AWS_PROFILE` environment variable in `docker-compose.yml` (defaults to `k8s-handson-tf`).
- If your SSH key isn't named `id_rsa`, set `SSH_PRIVATE_KEY=/root/.ssh/<keyname>` (see `scripts/common.sh`) before running the scripts, or add it to `docker-compose.yml`.
- SSH keys are copied from the read-only mount into `/root/.ssh` inside the container and re-chmod'ed on startup, since bind-mounted files from Windows don't carry the strict permissions `ssh`/`ansible` require.

## Usage

### 1. Preparation

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit ssh_allowed_cidr (your global IP/32), public_key_path, etc.
```

### 2. Full deployment

```bash
cd ..
./scripts/deploy-all.sh
```

This runs the following steps in order:

1. `scripts/10-deploy-infra.sh` — `terraform apply` (creates VPC/SG/EC2)
2. `scripts/20-generate-inventory.sh` — generates the Ansible inventory from `terraform output`
3. `scripts/30-wait-for-ssh.sh` — waits until all nodes are reachable over SSH
4. `scripts/40-configure-k8s.sh` — bootstraps the cluster with kubeadm, installs the NVIDIA driver, joins the GPU worker(s)

Each script can also be run individually.

### 3. Installing Run:ai (optional)

Installing Run:ai requires tenant-specific license/connection information.

1. Edit `ansible/roles/runai_control_plane/files/control-plane-values.yaml` with the values provided by Run:ai.
2. Fill in `ansible/roles/runai_gpu_worker/files/cluster-install-command.sh.example` with the command issued by the Run:ai control-plane UI ("New Cluster"), then rename it to `cluster-install-command.sh`.
3. Run:

```bash
RUNAI=true ./scripts/40-configure-k8s.sh
```

### 4. Verifying the cluster

```bash
ssh -i ~/.ssh/id_rsa ubuntu@$(cd terraform && terraform output -raw control_plane_public_ip)
kubectl get nodes
kubectl get pods -n kube-system
nvidia-smi   # run on the GPU worker
```

### 5. Tearing down

```bash
./scripts/destroy.sh
```

## Customization

- Number of GPU workers: `gpu_worker_count` in `terraform/terraform.tfvars`
- Region / instance types: other variables in the same file
- Kubernetes version / pod network CIDR: `ansible/group_vars/all.yml`

## Notes

- `ssh_allowed_cidr` defaults to `0.0.0.0/0`. For real use, restrict it to your own IP.
- The Run:ai Helm repository URL / chart name are placeholders. Follow Run:ai's official documentation/support for the actual values.
- The control plane is a single-node setup (not highly available).
