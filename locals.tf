locals {
  env_prefix = {
    development = "dev."
    qa          = "qa."
    stage       = "stg."
    integration = "int."
    preprod     = "pre."
    production  = ""
  }

  tarball_ingester_name                = "tarball-ingester"
  iam_role_max_session_timeout_seconds = 43200
  cw_tarball_ingester_agent_namespace  = "/app/${local.tarball_ingester_name}"

  cw_agent_metrics_collection_interval                  = 60
  cw_agent_cpu_metrics_collection_interval              = 60
  cw_agent_disk_measurement_metrics_collection_interval = 60
  cw_agent_disk_io_metrics_collection_interval          = 60
  cw_agent_mem_metrics_collection_interval              = 60
  cw_agent_netstat_metrics_collection_interval          = 60

  tarball_ingester_asg_min = {
    development = 0
    qa          = 0
    integration = 0
    preprod     = 0
    production  = 0
  }

  tarball_ingester_truststore_aliases = {
    development = "dataworks_root_ca,dataworks_mgt_root_ca"
    qa          = "dataworks_root_ca,dataworks_mgt_root_ca"
    integration = "dataworks_root_ca,dataworks_mgt_root_ca"
    preprod     = "dataworks_root_ca,dataworks_mgt_root_ca"
    production  = "dataworks_root_ca,dataworks_mgt_root_ca,ucfs_ca"
  }

  tarball_ingester_truststore_certs = {
    development = "s3://${data.terraform_remote_state.certificate_authority.outputs.public_cert_bucket.id}/ca_certificates/dataworks/dataworks_root_ca.pem,s3://${data.terraform_remote_state.mgmt_ca.outputs.public_cert_bucket.id}/ca_certificates/dataworks/dataworks_root_ca.pem"
    qa          = "s3://${data.terraform_remote_state.certificate_authority.outputs.public_cert_bucket.id}/ca_certificates/dataworks/dataworks_root_ca.pem,s3://${data.terraform_remote_state.mgmt_ca.outputs.public_cert_bucket.id}/ca_certificates/dataworks/dataworks_root_ca.pem"
    integration = "s3://${data.terraform_remote_state.certificate_authority.outputs.public_cert_bucket.id}/ca_certificates/dataworks/dataworks_root_ca.pem,s3://${data.terraform_remote_state.mgmt_ca.outputs.public_cert_bucket.id}/ca_certificates/dataworks/dataworks_root_ca.pem"
    preprod     = "s3://${data.terraform_remote_state.certificate_authority.outputs.public_cert_bucket.id}/ca_certificates/dataworks/dataworks_root_ca.pem,s3://${data.terraform_remote_state.mgmt_ca.outputs.public_cert_bucket.id}/ca_certificates/dataworks/dataworks_root_ca.pem"
    production  = "s3://${data.terraform_remote_state.certificate_authority.outputs.public_cert_bucket.id}/ca_certificates/dataworks/dataworks_root_ca.pem,s3://${data.terraform_remote_state.mgmt_ca.outputs.public_cert_bucket.id}/ca_certificates/dataworks/dataworks_root_ca.pem,s3://${data.terraform_remote_state.certificate_authority.outputs.public_cert_bucket.id}/ca_certificates/ucfs/root_ca.pem"
  }

  tarball_ingester_ssmenabled = {
    development = "True"
    qa          = "True"
    integration = "True"
    preprod     = "False"
    production  = "False"
  }

  tarball_ingester_stub_enabled = {
    development = true
    qa          = true
    integration = true
    preprod     = true
    production  = false
  }

  tarball_ingester_tags_asg = merge(
    local.common_tags,
    {
      Name        = local.tarball_ingester_name,
      Persistence = "Ignore",
    }
  )

  tarball_ingester_endpoint = "${local.tarball_ingester_name}.${local.env_prefix[local.environment]}dataworks.dwp.gov.uk"

  crypto_workspace = {
    management-dev = "management-dev"
    management     = "management"
  }

  dks_endpoint = data.terraform_remote_state.crypto.outputs.dks_endpoint[local.environment]
  dks_fqdn     = data.terraform_remote_state.crypto.outputs.dks_fqdn[local.environment]

  ti_tmp_dir  = "./tmp/"
  ti_src_dir  = "/opt/minio/ucfs-business-data-tarballs/"
  ti_wait     = "540"
  ti_interval = "1"
}
