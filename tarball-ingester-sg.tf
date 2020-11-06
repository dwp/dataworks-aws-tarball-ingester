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
  description       = "Allow outbound requests to DKS"
  type              = "egress"
  from_port         = 8443
  to_port           = 8443
  protocol          = "tcp"
  cidr_blocks       = data.terraform_remote_state.crypto.outputs.dks_subnet.cidr_blocks
  security_group_id = aws_security_group.tarball_ingester.id
}

resource "aws_security_group_rule" "tarball_ingester_ingress_dks" {
  provider          = aws.management-crypto
  description       = "Allow inbound requests to DKS from Tarball ingester"
  type              = "ingress"
  from_port         = 8443
  to_port           = 8443
  protocol          = "tcp"
  cidr_blocks       = data.terraform_remote_state.ingest.outputs.ingestion_subnets.cidr_block
  security_group_id = data.terraform_remote_state.crypto.outputs.dks_sg_id[local.environment]
}

resource "aws_security_group_rule" "tarball_ingester_to_vpc_endpoints" {
  description              = "Allow HTTPS traffic to VPC endpoints"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.tarball_ingester.id
  to_port                  = 443
  type                     = "egress"
  source_security_group_id = data.terraform_remote_state.ingest.outputs.vpc.vpc.interface_vpce_sg_id
}

resource "aws_security_group_rule" "vpc_endpoints_from_tarball_ingester" {
  description              = "Allow HTTPS traffic from Tarball Ingester"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = data.terraform_remote_state.ingest.outputs.vpc.vpc.interface_vpce_sg_id
  to_port                  = 443
  type                     = "ingress"
  source_security_group_id = aws_security_group.tarball_ingester.id
}

resource "aws_security_group_rule" "tarball_ingester_inbound_healthcheck" {
  description       = "Allow traffic from LB CIDR for Instance Healthcheck"
  type              = "ingress"
  from_port         = 9000
  to_port           = 9000
  protocol          = "tcp"
  cidr_blocks       = data.terraform_remote_state.ingest.outputs.ingestion_subnets.cidr_block
  security_group_id = aws_security_group.tarball_ingester.id
}
