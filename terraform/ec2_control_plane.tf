resource "aws_instance" "control_plane" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.control_plane_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.k8s.id]
  key_name               = aws_key_pair.this.key_name

  root_block_device {
    volume_type = "gp3"
    volume_size = var.control_plane_root_volume_size
  }

  tags = {
    Name = "${var.project_name}-control-plane"
    Role = "control-plane"
  }
}
