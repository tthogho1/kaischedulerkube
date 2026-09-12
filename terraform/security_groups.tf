resource "aws_security_group" "k8s" {
  name        = "${var.project_name}-k8s-sg"
  description = "Kubernetes control-plane/GPU worker nodes"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-k8s-sg"
  }
}

# --- Management access ---
resource "aws_security_group_rule" "ssh_in" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.ssh_allowed_cidr]
  security_group_id = aws_security_group.k8s.id
  description       = "SSH"
}

resource "aws_security_group_rule" "k8s_api_in" {
  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = [var.ssh_allowed_cidr]
  security_group_id = aws_security_group.k8s.id
  description       = "kube-apiserver"
}

resource "aws_security_group_rule" "nodeport_in" {
  type              = "ingress"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  cidr_blocks       = [var.ssh_allowed_cidr]
  security_group_id = aws_security_group.k8s.id
  description       = "NodePort range (workload services, dashboards, etc.)"
}

# --- Cluster-internal traffic (self-referencing) ---
resource "aws_security_group_rule" "self_all_tcp" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.k8s.id
  security_group_id        = aws_security_group.k8s.id
  description              = "cluster internal tcp (etcd, kubelet, calico BGP, scheduler, etc.)"
}

resource "aws_security_group_rule" "self_all_udp" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "udp"
  source_security_group_id = aws_security_group.k8s.id
  security_group_id        = aws_security_group.k8s.id
  description              = "cluster internal udp (calico vxlan, etc.)"
}

# Calico's default IPPool uses IPIP encapsulation (ipipMode: Always) for
# cross-node pod traffic, not TCP/UDP. Without this, pod-to-pod traffic
# between nodes (e.g. the API server on the control plane calling a
# webhook Service backed by a pod on a worker node) silently times out.
resource "aws_security_group_rule" "self_ipip" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "4" # IP-in-IP
  source_security_group_id = aws_security_group.k8s.id
  security_group_id        = aws_security_group.k8s.id
  description              = "cluster internal ip-in-ip (calico overlay)"
}

resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k8s.id
  description       = "all outbound"
}
