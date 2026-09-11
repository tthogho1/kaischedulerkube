output "control_plane_public_ip" {
  value = aws_instance.control_plane.public_ip
}

output "control_plane_private_ip" {
  value = aws_instance.control_plane.private_ip
}

output "gpu_worker_public_ips" {
  value = aws_instance.gpu_worker[*].public_ip
}

output "gpu_worker_private_ips" {
  value = aws_instance.gpu_worker[*].private_ip
}

output "ssh_user" {
  value = "ubuntu"
}
