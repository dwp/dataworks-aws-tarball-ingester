variable "costcode" {
  type    = string
  default = ""
}

variable "assume_role" {
  type        = string
  default     = "ci"
  description = "IAM role assumed by Concourse when running Terraform"
}

variable "region" {
  type    = string
  default = "eu-west-2"
}

variable "al2_hardened_ami_id" {
  description = "The AMI ID of the latest/pinned Hardened AMI AL2 Image"
  type        = string
}

variable "tarball_ingester_ec2_size" {
  default = {
    development = "t3.medium"
    qa          = "t3.medium"
    integration = "t3.medium"
    preprod     = "t3.medium"
    production  = "t3.medium"
  }
}

variable "tarball_ingester_release" {
  description = "Release number for the Tarball ingester release"
  type        = string
}

variable "tarball_ingester_asg_desired" {
  description = "Desired tarball_ingester equality ASG size"
  default = {
    development = 1
    qa          = 1
    integration = 1
    preprod     = 1
    production  = 1
  }
}

variable "tarball_ingester_asg_max" {
  description = "Max tarball_ingester ASG size."
  default = {
    development = 1
    qa          = 1
    integration = 1
    preprod     = 1
    production  = 1
  }
}

variable "tarball_ingester_ebs_volume_size" {
  description = "Tarball ingester EBS volume size."
  default = {
    development = "2500"
    qa          = "2500"
    integration = "2500"
    preprod     = "2500"
    production  = "2500"
  }
}


variable "tarball_ingester_ebs_iops" {
  description = "Tarball ingester EBS IOPs."
  default = {
    development = "8000"
    qa          = "8000"
    integration = "8000"
    preprod     = "8000"
    production  = "8000"
  }
}

variable "minio_s3_bucket_name" {
  description = "The name of the S3 bucket created by MinIO"
  default     = "ucfs-business-data-tarballs"
}
