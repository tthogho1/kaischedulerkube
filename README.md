# KAI Scheduler on Kubernetes (AWS) — Terraform + Ansible

Builds the following setup on AWS.

| Role | Instance type | vCPU | Memory | GPU | Purpose |
|---|---|---|---|---|---|
| Control plane | t3.large | 2 | 8 GB | none | k8s server + KAI Scheduler pods |
| GPU worker | g4dn.xlarge | 4 | 16 GB | T4 x1 | GPU workload execution |

Terraform provisions the infrastructure (VPC/SecurityGroup/EC2), and Ansible configures Kubernetes (kubeadm + containerd + Calico), the NVIDIA driver/container runtime, and the [KAI Scheduler](https://github.com/NVIDIA/KAI-Scheduler).

KAI Scheduler is NVIDIA's open source Kubernetes scheduler for AI workloads (the scheduler core that was open sourced from Run:ai). Unlike Run:ai it needs no tenant, license key, or pull secret, so this repo installs it end to end — there are no placeholders left to fill in.

## Directory layout

```
terraform/   AWS infrastructure definitions
ansible/     k8s / NVIDIA / KAI Scheduler configuration
scripts/     Shell scripts to run the whole workflow
```

## Prerequisites

The following must be installed on the machine you run these scripts from (bash / WSL / Linux / macOS):

- terraform >= 1.5
- aws cli (with credentials configured via `aws configure`)
- ansible / ansible-playbook
- jq

### AWS IAM permissions

The credentials/profile you configure need permission to manage EC2 and VPC
resources — this project only creates a VPC, subnet, internet gateway, route
table, security group, key pair, and two EC2 instances, so the AWS managed
policy `AmazonEC2FullAccess` is sufficient. There is no S3, IAM, or EKS access
required.

### AWS EC2 service quota (GPU instances)

New/unused AWS accounts default to a **0 vCPU quota** for "Running On-Demand
G and VT instances" (quota code `L-DB2E81BA`), which covers the `g4dn.xlarge`
GPU worker. `terraform apply` will fail with a `VcpuLimitExceeded` error until
this is raised to at least `4 * gpu_worker_count`.

Check your current quota:

```bash
aws service-quotas get-service-quota --service-code ec2 --quota-code L-DB2E81BA --region <your-region>
```

If it's below what you need, request an increase (approval is usually
automatic, but can take from minutes to a day):

```bash
aws service-quotas request-service-quota-increase --service-code ec2 --quota-code L-DB2E81BA --desired-value 8 --region <your-region>
```

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
4. `scripts/40-configure-k8s.sh` — bootstraps the cluster with kubeadm, installs the NVIDIA driver, joins the GPU worker(s), then installs the KAI Scheduler

Each script can also be run individually. To stop before the scheduler install, set `KAI=false`:

```bash
KAI=false ./scripts/deploy-all.sh
# ...and install it later with:
cd ansible && ansible-playbook -i inventory/hosts.ini playbooks/03-kai-scheduler.yml
```

### 3. Verifying the cluster

```bash
ssh -i ~/.ssh/id_rsa ubuntu@$(cd terraform && terraform output -raw control_plane_public_ip)
kubectl get nodes
kubectl get pods -n kube-system
kubectl get pods -n kai-scheduler
kubectl get queues
nvidia-smi   # run on the GPU worker
```

### 4. Running a workload on KAI

Two things are required for KAI to schedule a pod:

1. `spec.schedulerName: kai-scheduler`
2. a `kai.scheduler/queue` label naming a **leaf** queue

The playbook creates a `default-parent-queue` / `default-queue` pair (unlimited, no reserved quota) and drops two ready-made examples on the control plane:

```bash
kubectl apply -f ~/kai-examples/cpu-only-pod.yaml
kubectl apply -f ~/kai-examples/gpu-pod.yaml
kubectl logs gpu-pod          # should print nvidia-smi output
```

Don't submit workloads into the `kai-scheduler` namespace itself — use your own namespace.

Minimal pod spec:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
  labels:
    kai.scheduler/queue: default-queue
spec:
  schedulerName: kai-scheduler
  containers:
    - name: main
      image: ubuntu
      command: ["bash", "-c"]
      args: ["nvidia-smi; sleep infinity"]
      resources:
        limits:
          nvidia.com/gpu: "1"
```

### 5. Tearing down

```bash
./scripts/destroy.sh
```

## Customization

- Number of GPU workers: `gpu_worker_count` in `terraform/terraform.tfvars`
- Region / instance types: other variables in the same file
- Kubernetes version / pod network CIDR: `ansible/playbooks/group_vars/all.yml`
- KAI Scheduler chart version, namespace, queue names, GPU sharing: the `kai_*` variables in `ansible/playbooks/group_vars/all.yml` (defaults in `ansible/roles/kai_scheduler/defaults/main.yml`)

### Queues

KAI allocates resources through a hierarchy of queues; workloads always attach to a leaf queue. The defaults here use `quota: 0` / `limit: -1`, meaning no guaranteed reservation and unlimited over-quota use — fine for a single-tenant test cluster. For real multi-team sharing, set per-queue `quota` values so each team gets a guaranteed share. Edit `ansible/roles/kai_scheduler/templates/default-queues.yaml.j2`, or set `kai_create_default_queues: false` and manage queues yourself.

## Notes

- `ssh_allowed_cidr` defaults to `0.0.0.0/0`. For real use, restrict it to your own IP.
- Pin `kai_scheduler_version` to a release from the [releases page](https://github.com/NVIDIA/KAI-Scheduler/releases); the default here is `v0.17.1`.
- GPU sharing (fractional GPUs, `kai_gpu_sharing_enabled: true`) expects the NVIDIA GPU Operator. This setup installs the plain NVIDIA device plugin instead, which handles whole-GPU requests only.
- The control plane is a single-node setup (not highly available).
