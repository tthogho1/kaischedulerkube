resource "aws_instance" "gpu_worker" {
  count = var.gpu_worker_count

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.gpu_worker_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.k8s.id]
  key_name               = aws_key_pair.this.key_name

  root_block_device {
    volume_type = "gp3"
    volume_size = var.gpu_worker_root_volume_size
  }

  tags = {
    Name = "${var.project_name}-gpu-worker-${count.index + 1}"
    Role = "gpu-worker"
  }
}
