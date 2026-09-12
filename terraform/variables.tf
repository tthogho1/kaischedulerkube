variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Prefix used for resource names/tags"
  type        = string
  default     = "kai-k8s"
}

variable "availability_zone" {
  description = "AZ to use. If empty, one is chosen automatically"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.60.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.60.1.0/24"
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed for SSH/management access (recommend your own global IP/32)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "public_key_path" {
  description = "Path to the SSH public key used to log into EC2 (e.g. ~/.ssh/id_rsa.pub)"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "control_plane_instance_type" {
  description = "Instance type for the control plane (2 vCPU / 8GB)"
  type        = string
  default     = "t3.large"
}

variable "control_plane_root_volume_size" {
  description = "Root volume size (GB) for the control plane"
  type        = number
  default     = 50
}

variable "gpu_worker_instance_type" {
  description = "Instance type for GPU workers (4 vCPU / 16GB / 1x T4)"
  type        = string
  default     = "g4dn.xlarge"
}

variable "gpu_worker_count" {
  description = "Number of GPU worker nodes"
  type        = number
  default     = 1
}

variable "gpu_worker_root_volume_size" {
  description = "Root volume size (GB) for GPU workers. Larger is recommended for container images/models"
  type        = number
  default     = 150
}
