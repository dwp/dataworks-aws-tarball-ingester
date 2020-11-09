resource "aws_acm_certificate" "tarball_ingester" {
  certificate_authority_arn = data.terraform_remote_state.certificate_authority.outputs.root_ca.arn
  domain_name               = "${local.tarball_ingester_name}.${local.env_prefix[local.environment]}dataworks.dwp.gov.uk"

  tags = merge(
    local.common_tags,
    {
      Name = "tarball-ingester"
    },
  )
}

resource "aws_launch_template" "tarball_ingester" {
  name                   = "tarball_ingester"
  image_id               = var.al2_hardened_ami_id
  instance_type          = var.tarball_ingester_ec2_size[local.environment]
  vpc_security_group_ids = [aws_security_group.tarball_ingester.id]

  user_data = base64encode(templatefile("files/tarball_ingester_userdata.tpl", {
    ti_tmp_dir                                       = local.ti_tmp_dir
    ti_src_dir                                       = local.ti_src_dir
    ti_s3_bucket                                     = local.ti_s3_bucket
    ti_s3_prefix                                     = local.ti_s3_prefix
    ti_dks_url                                       = local.dks_endpoint
    ti_format                                        = local.ti_format
    ti_dt                                            = local.ti_dt
    ti_wait                                          = local.ti_wait
    ti_interval                                      = local.ti_interval
    ti_manifest_path                                 = local.ti_manifest_path
    ti_asg                                           = aws_autoscaling_group.tarball_ingester.id
    tarball_ingester_endpoint                        = local.tarball_ingester_endpoint
    environment_name                                 = local.environment
    acm_cert_arn                                     = aws_acm_certificate.tarball_ingester.arn
    truststore_aliases                               = local.tarball_ingester_truststore_aliases[local.environment]
    truststore_certs                                 = local.tarball_ingester_truststore_certs[local.environment]
    private_key_alias                                = "tarball-ingester"
    internet_proxy                                   = data.terraform_remote_state.ingest.outputs.internet_proxy.host
    non_proxied_endpoints                            = join(",", data.terraform_remote_state.ingest.outputs.vpc.vpc.no_proxy_list, [local.tarball_ingester_endpoint])
    cwa_namespace                                    = local.cw_tarball_ingester_agent_namespace
    cwa_metrics_collection_interval                  = local.cw_agent_metrics_collection_interval
    cwa_cpu_metrics_collection_interval              = local.cw_agent_cpu_metrics_collection_interval
    cwa_disk_measurement_metrics_collection_interval = local.cw_agent_disk_measurement_metrics_collection_interval
    cwa_disk_io_metrics_collection_interval          = local.cw_agent_disk_io_metrics_collection_interval
    cwa_mem_metrics_collection_interval              = local.cw_agent_mem_metrics_collection_interval
    cwa_netstat_metrics_collection_interval          = local.cw_agent_netstat_metrics_collection_interval
    cwa_log_group_name                               = aws_cloudwatch_log_group.tarball_ingester_logs.name
    s3_artefact_bucket                               = data.terraform_remote_state.management_artefact.outputs.artefact_bucket.id
    s3_config_bucket                                 = data.terraform_remote_state.common.outputs.config_bucket.id
    s3_file_tarball_ingester_logrotate               = aws_s3_bucket_object.tarball_ingester_logrotate_script.id
    s3_file_tarball_ingester_logrotate_md5           = md5(data.local_file.tarball_ingester_logrotate_script.content)
    s3_file_tarball_ingester_cloudwatch_sh           = aws_s3_bucket_object.tarball_ingester_cloudwatch_script.id
    s3_file_tarball_ingester_cloudwatch_sh_md5       = md5(data.local_file.tarball_ingester_cloudwatch_script.content)
    s3_file_tarball_ingester_minio_sh                = aws_s3_bucket_object.tarball_ingester_minio_script.id
    s3_file_tarball_ingester_minio_sh_md5            = md5(data.local_file.tarball_ingester_minio_script.content)
    s3_file_tarball_ingester_minio_service_file      = aws_s3_bucket_object.tarball_ingester_minio_service_file.id
    s3_file_tarball_ingester_minio_service_file_md5  = md5(data.local_file.tarball_ingester_minio_service_file.content)
    minio_s3_bucket_name                             = var.minio_s3_bucket_name
    tarball_ingester_release                         = var.tarball_ingester_release
  }))

  instance_initiated_shutdown_behavior = "terminate"

  iam_instance_profile {
    arn = aws_iam_instance_profile.tarball_ingester.arn
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 1000
      volume_type           = "io1"
      iops                  = "2000"
      delete_on_termination = true
      encrypted             = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.tarball_ingester_name,
    },
  )

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      local.common_tags,
      {
        Name         = local.tarball_ingester_name,
        Persistence  = "Ignore",
        AutoShutdown = "False",
        SSMEnabled   = local.tarball_ingester_ssmenabled[local.environment]
      },
    )
  }
}

resource "aws_iam_instance_profile" "tarball_ingester" {
  name = "tarball_ingester"
  role = aws_iam_role.tarball_ingester.name
}

resource "aws_autoscaling_group" "tarball_ingester" {
  name_prefix               = "${aws_launch_template.tarball_ingester.name}-lt_ver${aws_launch_template.tarball_ingester.latest_version}_"
  min_size                  = local.tarball_ingester_asg_min[local.environment]
  desired_capacity          = var.tarball_ingester_asg_desired[local.environment]
  max_size                  = var.tarball_ingester_asg_max[local.environment]
  health_check_grace_period = 600
  health_check_type         = "EC2"
  force_delete              = true
  vpc_zone_identifier       = data.terraform_remote_state.ingest.outputs.ingestion_subnets.id
  target_group_arns         = [aws_lb_target_group.tarball_ingester.arn]

  launch_template {
    id      = aws_launch_template.tarball_ingester.id
    version = "$Latest"
  }

  tags = [
    for key, value in local.tarball_ingester_tags_asg :
    {
      key                 = key
      value               = value
      propagate_at_launch = true
    }
  ]

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}

resource "aws_cloudwatch_log_group" "tarball_ingester_logs" {
  name              = "/app/${local.tarball_ingester_name}"
  retention_in_days = 180
  tags = merge(
    local.common_tags,
    {
      Name = "/app/${local.tarball_ingester_name}"
    },
  )
}

resource "aws_secretsmanager_secret" "minio_credentials" {
  name        = "minio"
  description = "MinIO credentials"
  tags = merge(
    local.common_tags,
    {
      Name = "minio",
    },
  )
}
