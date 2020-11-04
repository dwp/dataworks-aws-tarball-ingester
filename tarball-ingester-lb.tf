resource "aws_lb" "tarball_ingester" {
  name               = "tarball-ingester"
  internal           = true
  load_balancer_type = "network"
  subnets            = data.terraform_remote_state.ingest.outputs.ingestion_subnets.id
  tags               = local.common_tags

  access_logs {
    bucket  = data.terraform_remote_state.security-tools.outputs.logstore_bucket.id
    prefix  = "ELBLogs/tarball-ingester"
    enabled = true
  }
}

resource "aws_lb_target_group" "tarball_ingester" {
  name_prefix = "ti-"
  port        = 9000
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = data.terraform_remote_state.ingest.outputs.vpc.vpc.vpc.id

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.common_tags,
    { Name = "tarball-ingester" },
  )
}

resource "aws_lb_listener" "tarball_ingester_listener" {
  load_balancer_arn = aws_lb.tarball_ingester.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tarball_ingester.arn
  }
}
