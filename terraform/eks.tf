data "aws_iam_roles" "sso_administrator" {
  name_regex  = "^AWSReservedSSO_AdministratorAccess"
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.29.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  endpoint_public_access       = true
  endpoint_private_access      = true
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  # Control plane logs cost money; enable "api"/"audit" when debugging.
  enabled_log_types                      = []
  cloudwatch_log_group_retention_in_days = 7

  addons = {
    vpc-cni = {
      addon_version  = "v1.22.4-eksbuild.3"
      before_compute = true
    }
    eks-pod-identity-agent = {
      addon_version  = "v1.3.10-eksbuild.3"
      before_compute = true
    }
    coredns = {
      addon_version = "v1.14.7-eksbuild.11"
    }
    kube-proxy = {
      addon_version = "v1.36.0-eksbuild.48"
    }
    aws-ebs-csi-driver = {
      addon_version = "v1.67.0-eksbuild.1"
      pod_identity_association = [{
        role_arn        = module.aws_ebs_csi_driver_pod_identity.iam_role_arn
        service_account = "ebs-csi-controller-sa"
      }]
    }
    metrics-server = {
      addon_version = "v0.9.0-eksbuild.13"
    }
  }

  # Small fixed node group for cluster-critical controllers. Everything else
  # runs on Karpenter-provisioned nodes (see gitops/platform/karpenter).
  eks_managed_node_groups = {
    system = {
      ami_type       = "AL2023_ARM_64_STANDARD"
      instance_types = var.system_node_instance_types
      capacity_type  = var.system_node_capacity_type

      min_size     = 2
      max_size     = 3
      desired_size = 2

      labels = {
        "karpenter.sh/controller" = "true"
      }

      taints = {
        critical_addons_only = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }

  node_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = false
  access_entries = {
    administrator = {
      principal_arn = tolist(data.aws_iam_roles.sso_administrator.arns)[0]
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
}
