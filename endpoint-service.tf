resource "aws_vpc_endpoint_service" "tarball_ingester" {
  acceptance_required        = true
  network_load_balancer_arns = [aws_lb.tarball_ingester.arn]
  tags                       = local.common_tags
}


resource "aws_vpc_endpoint_service_allowed_principal" "tarball_ingester" {
  count                   = local.tarball_ingester_uc_connected[local.environment] ? 1 : 0
  vpc_endpoint_service_id = aws_vpc_endpoint_service.tarball_ingester.id
  principal_arn           = format("arn:aws:iam::%s:root", local.ucfs_account[local.environment])
}

resource "aws_vpc_endpoint_service_allowed_principal" "tarball_ingester_stub" {
  count                   = local.tarball_ingester_stub_enabled[local.environment] ? 1 : 0
  vpc_endpoint_service_id = aws_vpc_endpoint_service.tarball_ingester.id
  principal_arn           = format("arn:aws:iam::%s:root", local.account[local.environment])
}
