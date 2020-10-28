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
    environment_name                                 = local.environment
    acm_cert_arn                                     = aws_acm_certificate.tarball_ingester.arn
    truststore_aliases                               = local.tarball_ingester_truststore_aliases[local.environment]
    truststore_certs                                 = local.tarball_ingester_truststore_certs[local.environment]
    private_key_alias                                = "tarball-ingester"
    internet_proxy                                   = data.terraform_remote_state.ingest.outputs.internet_proxy.host
    non_proxied_endpoints                            = join(",", data.terraform_remote_state.ingest.outputs.vpc.vpc.no_proxy_list)
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
    s3_file_tarball_ingester_cloudwatch_sh           = aws_s3_bucket_object.tarball_ingester_cloudwatch_script.id
    s3_file_tarball_ingester_minio_sh                = aws_s3_bucket_object.tarball_ingester_minio_script.id
    s3_file_tarball_ingester_minio_service_file      = aws_s3_bucket_object.tarball_ingester_minio_service_file.id
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
  vpc_zone_identifier       = data.terraform_remote_state.ingest.outputs.ingestion_subnets.id[0]

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

data "aws_iam_policy_document" "tarball_ingester" {
  statement {
    sid    = "AllowACM"
    effect = "Allow"

    actions = [
      "acm:*Certificate",
    ]

    resources = [aws_acm_certificate.tarball_ingester.arn]
  }

  statement {
    sid    = "GetPublicCerts"
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = [data.terraform_remote_state.certificate_authority.outputs.public_cert_bucket.arn]
  }

  statement {
    sid    = "AllowUseDefaultEbsCmk"
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]


    resources = [data.terraform_remote_state.security-tools.outputs.ebs_cmk.arn]
  }

  statement {
    effect = "Allow"
    sid    = "AllowAccessToConfigBucket"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]


    resources = [data.terraform_remote_state.common.outputs.config_bucket.arn]
  }

  statement {
    effect = "Allow"
    sid    = "AllowAccessToConfigBucketObjects"

    actions = ["s3:GetObject"]

    resources = ["${data.terraform_remote_state.common.outputs.config_bucket.arn}/*"]
  }

  statement {
    sid    = "AllowKMSDecryptionOfS3ConfigBucketObj"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]

    resources = [data.terraform_remote_state.common.outputs.config_bucket_cmk.arn]
  }

  statement {
    sid       = "AllowDescribeASGToCheckLaunchTemplate"
    effect    = "Allow"
    actions   = ["autoscaling:DescribeAutoScalingGroups"]
    resources = ["*"]
  }

  statement {
    sid       = "AllowDescribeEC2LaunchTemplatesToCheckLatestVersion"
    effect    = "Allow"
    actions   = ["ec2:DescribeLaunchTemplates"]
    resources = ["*"]
  }

  statement {
    sid    = "TarballingesterKMS"
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]

    resources = [
      data.terraform_remote_state.ingest.outputs.input_bucket_cmk.arn
    ]
  }

  statement {
    sid     = "AllowAccessToArtefactBucket"
    effect  = "Allow"
    actions = ["s3:GetBucketLocation"]

    resources = [data.terraform_remote_state.management_artefact.outputs.artefact_bucket.arn]
  }

  statement {
    sid       = "AllowPullFromArtefactBucket"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${data.terraform_remote_state.management_artefact.outputs.artefact_bucket.arn}/*"]
  }

  statement {
    sid    = "AllowDecryptArtefactBucket"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
    ]

    resources = [data.terraform_remote_state.management_artefact.outputs.artefact_bucket.cmk_arn]
  }

  statement {
    sid    = "AllowTarballingesterToAccessLogGroups"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = [aws_cloudwatch_log_group.tarball_ingester_logs.arn]
  }
}

data "aws_iam_policy_document" "tarball_ingester_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "tarball_ingester" {
  name                 = "tarball_ingester"
  assume_role_policy   = data.aws_iam_policy_document.tarball_ingester_policy.json
  max_session_duration = local.iam_role_max_session_timeout_seconds
  tags = merge(
    local.common_tags,
    {
      Name = "tarball_ingester"
    },
  )
}

resource "aws_iam_policy" "tarball_ingester" {
  name        = "tarball_ingester"
  description = "Policy to allow access for Tarball ingester"
  policy      = data.aws_iam_policy_document.tarball_ingester.json
}

resource "aws_iam_role_policy_attachment" "tarball_ingester" {
  role       = aws_iam_role.tarball_ingester.name
  policy_arn = aws_iam_policy.tarball_ingester.arn
}

resource "aws_iam_role_policy_attachment" "tarball_ingester_cwasp" {
  role       = aws_iam_role.tarball_ingester.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "tarball_ingester_ssm" {
  role       = aws_iam_role.tarball_ingester.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

resource "aws_iam_role_policy_attachment" "tarball_ingester_minio" {
  role       = aws_iam_role.tarball_ingester.name
  policy_arn = aws_iam_policy.minio_credentials_secretsmanager.arn
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

resource "aws_security_group" "tarball_ingester" {
  name                   = "tarball_ingester"
  description            = "Contains rules for Tarball ingester"
  revoke_rules_on_delete = true
  vpc_id                 = data.terraform_remote_state.ingest.outputs.vpc.vpc.vpc.id

  tags = merge(
    local.common_tags,
    {
      Name = local.tarball_ingester_name
    },
  )
}

resource "aws_security_group_rule" "tarball_ingester_to_s3" {
  description       = "Allow Tarball ingester to reach S3"
  type              = "egress"
  prefix_list_ids   = [data.terraform_remote_state.ingest.outputs.vpc.vpc.prefix_list_ids.s3]
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  security_group_id = aws_security_group.tarball_ingester.id
}

resource "aws_security_group_rule" "egress_tarball_ingester_to_internet" {
  description              = "Allow Tarball ingester access to Internet Proxy (for ACM-PCA)"
  type                     = "egress"
  source_security_group_id = data.terraform_remote_state.ingest.outputs.internet_proxy.sg
  protocol                 = "tcp"
  from_port                = 3128
  to_port                  = 3128
  security_group_id        = aws_security_group.tarball_ingester.id
}

resource "aws_security_group_rule" "ingress_tarball_ingester_to_internet" {
  description              = "Allow Tarball ingester access to Internet Proxy (for ACM-PCA)"
  type                     = "ingress"
  source_security_group_id = aws_security_group.tarball_ingester.id
  protocol                 = "tcp"
  from_port                = 3128
  to_port                  = 3128
  security_group_id        = data.terraform_remote_state.ingest.outputs.internet_proxy.sg
}

resource "aws_security_group_rule" "tarball_ingester_egress_dks" {
  description              = "Allow outbound requests to DKS"
  type                     = "egress"
  from_port                = 8443
  to_port                  = 8443
  protocol                 = "tcp"
  source_security_group_id = data.terraform_remote_state.crypto.outputs.dks_sg_id[local.environment]
  security_group_id        = aws_security_group.tarball_ingester.id
}

resource "aws_security_group_rule" "tarball_ingester_ingress_dks" {
  provider                 = aws.management-crypto
  description              = "Allow inbound requests to DKS from Tarball ingester"
  type                     = "ingress"
  from_port                = 8443
  to_port                  = 8443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.tarball_ingester.id
  security_group_id        = data.terraform_remote_state.crypto.outputs.dks_sg_id[local.environment]
}

resource "aws_security_group_rule" "dataset_generator_to_vpc_endpoints" {
  description              = "Allow HTTPS traffic to VPC endpoints"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.tarball_ingester.id
  to_port                  = 443
  type                     = "egress"
  source_security_group_id = data.terraform_remote_state.ingest.outputs.vpc.vpc.interface_vpce_sg_id
}

resource "aws_security_group_rule" "vpc_endpoints_from_dataset_generator" {
  description              = "Allow HTTPS traffic from Dataset Generator"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = data.terraform_remote_state.ingest.outputs.vpc.vpc.interface_vpce_sg_id
  to_port                  = 443
  type                     = "ingress"
  source_security_group_id = aws_security_group.tarball_ingester.id
}

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

data "aws_iam_policy_document" "minio_credentials_secretsmanager" {
  statement {
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
    ]

    resources = [
      aws_secretsmanager_secret.minio_credentials.arn
    ]
  }
}

resource "aws_iam_policy" "minio_credentials_secretsmanager" {
  name        = "MiniIOSecretsManager"
  description = "Allow reading of MinIO Access and Secret Keys"
  policy      = data.aws_iam_policy_document.minio_credentials_secretsmanager.json
}
