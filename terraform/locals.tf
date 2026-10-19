data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  azs        = slice(data.aws_availability_zones.available.names, 0, 3)

  domain = "${var.subdomain}.${var.parent_domain}"

  # Scaled to 0/1 by scripts/sleep.sh and scripts/wake.sh.
  system_node_group_name = "system"

  # Every secret this project owns lives under this Secrets Manager prefix.
  secrets_prefix = var.project_name

  tags = {
    Project   = var.project_name
    Cluster   = var.cluster_name
    Terraform = "true"
  }
}
