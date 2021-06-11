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

output "tarball_ingester_endpoint" {
  value = {
    service_name = aws_vpc_endpoint_service.tarball_ingester.service_name
  }
}

output "minio_credentials" {
  value = {
    arn = aws_secretsmanager_secret.minio_credentials.arn
  }
}
