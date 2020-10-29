resource "aws_vpc_endpoint_service" "tarball_ingester" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.tarball_ingester.arn]
  tags                       = local.common_tags
}

data "aws_caller_identity" "current" {}

resource "aws_vpc_endpoint_service_allowed_principal" "tarball_ingester" {
  vpc_endpoint_service_id = aws_vpc_endpoint_service.tarball_ingester.id
  principal_arn           = format("arn:aws:iam::%s:root", local.account[local.environment])
}
