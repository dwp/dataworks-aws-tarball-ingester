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
    sid = "AllowPutToHTMEBucket"
    actions = [
      "s3:DeleteObject*",
      "s3:PutObject"
    ]
    resources = ["${data.terraform_remote_state.internal_compute.outputs.htme_s3_bucket.arn}/*"]
  }

  statement {
    sid = "AllowListHTMEBucket"
    actions = [
      "s3:ListBucket"
    ]
    resources = [data.terraform_remote_state.internal_compute.outputs.htme_s3_bucket.arn]
  }

  statement {
    sid = "AllowKMSEncryptionOfHTMEBucketObject"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*"
    ]
    resources = [data.terraform_remote_state.internal_compute.outputs.compaction_bucket_cmk.arn]
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

data "aws_iam_policy_document" "tarball_ingester_describe_autoscaling" {
  statement {
    effect = "Allow"

    actions = [
      "autoscaling:DescribeAutoScalingInstances",
    ]

    resources = ["*"]
  }
}

data "aws_iam_policy_document" "tarball_ingester_set_desired_capacity_autoscaling" {
  statement {
    sid = "AllowSetDesiredCapacityOnASG"
    actions = [
      "autoscaling:SetDesiredCapacity",
    ]

    resources = [aws_autoscaling_group.tarball_ingester.arn]
  }
}

resource "aws_iam_policy" "tarball_ingester" {
  name        = "tarball_ingester"
  description = "Policy to allow access for Tarball ingester"
  policy      = data.aws_iam_policy_document.tarball_ingester.json
}

resource "aws_iam_policy" "minio_credentials_secretsmanager" {
  name        = "MiniIOSecretsManager"
  description = "Allow reading of MinIO Access and Secret Keys"
  policy      = data.aws_iam_policy_document.minio_credentials_secretsmanager.json
}

resource "aws_iam_policy" "tarball_ingester_describe_autoscaling" {
  name        = "TarballIngesterDescribeASG"
  description = "Allow Tarball Ingester Instances to describe their own ASG"
  policy      = data.aws_iam_policy_document.tarball_ingester_describe_autoscaling.json
}

resource "aws_iam_policy" "tarball_ingester_set_desired_capacity_autoscaling" {
  name        = "TarballIngesterSetDesiredCapacityASG"
  description = "Allow Tarball Ingester Instances to set desired capacity on ASG"
  policy      = data.aws_iam_policy_document.tarball_ingester_set_desired_capacity_autoscaling.json
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
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "tarball_ingester_minio" {
  role       = aws_iam_role.tarball_ingester.name
  policy_arn = aws_iam_policy.minio_credentials_secretsmanager.arn
}

resource "aws_iam_role_policy_attachment" "tarball_ingester_describe_autoscaling" {
  role       = aws_iam_role.tarball_ingester.name
  policy_arn = aws_iam_policy.tarball_ingester_describe_autoscaling.arn
}

resource "aws_iam_role_policy_attachment" "tarball_ingester_set_desired_capacity_autoscaling" {
  role       = aws_iam_role.tarball_ingester.name
  policy_arn = aws_iam_policy.tarball_ingester_set_desired_capacity_autoscaling.arn
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
