# ${local.resource-prefix}
locals {
  resource-prefix      = "${var.env}-${var.app_name}"
  launch-template-name = "${local.resource-prefix}-LaunchTemplate"
  auto-scaling-group-name = "${local.resource-prefix}-ASG"
}