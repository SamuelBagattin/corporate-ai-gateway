module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.7.3"

  name = var.cluster_name
  cidr = var.vpc_cidr
  azs  = local.azs

  private_subnets = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]      # /20 each
  public_subnets  = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 8, i + 48)] # /24 each

  # Egress goes through the fck-nat instance below (~3 USD/month) instead of a
  # NAT gateway (~35 USD/month + 0.048 USD/GB).
  enable_nat_gateway = false

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "karpenter.sh/discovery"          = var.cluster_name
  }
}

# NAT instance in an auto-healing ASG of one (ha_mode). Single AZ: an AZ outage
# cuts egress for the whole VPC, acceptable for a POC.
module "fck_nat" {
  source  = "RaJiska/fck-nat/aws"
  version = "1.6.1"

  name          = "${var.cluster_name}-nat"
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.public_subnets[0]
  instance_type = "t4g.nano"
  ha_mode       = true

  update_route_tables = true
  route_tables_ids    = { for i, id in module.vpc.private_route_table_ids : "private-${i}" => id }
}

# Free: S3 traffic (ECR image layers, Langfuse objects) skips the NAT instance.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = {
    Name = "${var.cluster_name}-s3"
  }
}
