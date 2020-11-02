output "tarball_ingester_sg" {
  value = aws_security_group.tarball_ingester
}

output "tarball_ingester_asg" {
  value = {
    name = aws_autoscaling_group.tarball_ingester.name
  }
}

output "tarball_ingester_fqdn" {
  value = aws_acm_certificate.tarball_ingester.domain_name
}

output "tarball_ingester_minio_s3_bucket_name" {
  value = var.minio_s3_bucket_name
}
