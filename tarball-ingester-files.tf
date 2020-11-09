data "local_file" "tarball_ingester_logrotate_script" {
  filename = "files/tarball_ingester.logrotate"
}

resource "aws_s3_bucket_object" "tarball_ingester_logrotate_script" {
  bucket     = data.terraform_remote_state.common.outputs.config_bucket.id
  key        = "component/tarball-ingester/tarball-ingester.logrotate"
  content    = data.local_file.tarball_ingester_logrotate_script.content
  kms_key_id = data.terraform_remote_state.common.outputs.config_bucket_cmk.arn

  tags = merge(
    local.common_tags,
    {
      Name = "tarball-ingester-logrotate-script"
    },
  )
}

data "local_file" "tarball_ingester_cloudwatch_script" {
  filename = "files/tarball_ingester_cloudwatch.sh"
}

resource "aws_s3_bucket_object" "tarball_ingester_cloudwatch_script" {
  bucket     = data.terraform_remote_state.common.outputs.config_bucket.id
  key        = "component/tarball-ingester/tarball-ingester-cloudwatch.sh"
  content    = data.local_file.tarball_ingester_cloudwatch_script.content
  kms_key_id = data.terraform_remote_state.common.outputs.config_bucket_cmk.arn

  tags = merge(
    local.common_tags,
    {
      Name = "tarball-ingester-cloudwatch-script"
    },
  )
}

data "local_file" "tarball_ingester_minio_script" {
  filename = "files/tarball_ingester_minio.sh"
}

resource "aws_s3_bucket_object" "tarball_ingester_minio_script" {
  bucket     = data.terraform_remote_state.common.outputs.config_bucket.id
  key        = "component/tarball-ingester/tarball-ingester-minio.sh"
  content    = data.local_file.tarball_ingester_minio_script.content
  kms_key_id = data.terraform_remote_state.common.outputs.config_bucket_cmk.arn

  tags = merge(
    local.common_tags,
    {
      Name = "tarball-ingester-minio-script"
    },
  )
}

data "local_file" "tarball_ingester_minio_service_file" {
  filename = "files/minio.service"
}

resource "aws_s3_bucket_object" "tarball_ingester_minio_service_file" {
  bucket     = data.terraform_remote_state.common.outputs.config_bucket.id
  key        = "component/tarball-ingester/minio.service"
  content    = data.local_file.tarball_ingester_minio_service_file.content
  kms_key_id = data.terraform_remote_state.common.outputs.config_bucket_cmk.arn

  tags = merge(
    local.common_tags,
    {
      Name = "tarball-ingester-minio-service-file"
    },
  )
}

data "local_file" "tarball_ingester_manifest_json" {
  filename = "files/tarball_ingester_manifest.json"
}

resource "aws_s3_bucket_object" "tarball_ingester_manifest_json" {
  bucket     = data.terraform_remote_state.common.outputs.config_bucket.id
  key        = "component/tarball-ingester/tarball_ingester_manifest.json"
  content    = data.local_file.tarball_ingester_manifest_json.content
  kms_key_id = data.terraform_remote_state.common.outputs.config_bucket_cmk.arn

  tags = merge(
    local.common_tags,
    {
      Name = "tarball-ingester-manifest-json"
    },
  )
}
