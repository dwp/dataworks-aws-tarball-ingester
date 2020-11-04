resource "aws_vpc_peering_connection" "crypto" {
  peer_owner_id = local.account[local.management_account[local.environment]]
  peer_vpc_id   = data.terraform_remote_state.crypto.outputs.crypto_vpc.id
  vpc_id        = data.terraform_remote_state.ingest.outputs.vpc.vpc.vpc.id
  tags          = local.common_tags
}

resource "aws_vpc_peering_connection_accepter" "crypto" {
  provider                  = aws.management-crypto
  vpc_peering_connection_id = aws_vpc_peering_connection.crypto.id
  tags                      = local.common_tags
}

resource "aws_vpc_peering_connection_options" "crypto_accepter" {
  provider                  = aws.management-crypto
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.crypto.id

  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "aws_vpc_peering_connection_options" "crypto_requester" {
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.crypto.id

  requester {
    allow_remote_vpc_dns_resolution = true
  }
}

//resource "aws_route" "tarball_ingester_dks" {
//  count          = length(data.terraform_remote_state.ingest.outputs.ingestion_subnets.id)
//  route_table_id = data.terraform_remote_state.ingest.outputs.ingestion_subnets.rtb
//  destination_cidr_block = element(
//    data.terraform_remote_state.ingest.outputs.ingestion_subnets.cidr_block,
//    count.index,
//  )
//  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.crypto.id
//}
//
//resource "aws_route" "dks_tarball_ingester" {
//  provider                  = aws.management-crypto
//  count                     = length(data.terraform_remote_state.ingest.outputs.ingestion_subnets.cidr_block)
//  route_table_id            = data.terraform_remote_state.crypto.outputs.dks_route_table.id
//  destination_cidr_block    = element(data.terraform_remote_state.ingest.outputs.ingestion_subnets.cidr_block, count.index)
//  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.crypto.id
//}
