output "tarball_ingester_sg" {
  value = aws_security_group.tarball_ingester
}

output "ingester_asg" {
  value = {
    name = aws_autoscaling_group.tarball_ingester.name
  }
}
