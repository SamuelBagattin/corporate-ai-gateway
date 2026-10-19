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

  # No customer-managed KMS key (1 USD/month): EKS already envelope-encrypts
  # Kubernetes secrets with an AWS-owned key.
  encryption_config = null

  # Single replicas: everything shares one system node anyway.
  addons = {
    vpc-cni = {
      addon_version  = "v1.22.4-eksbuild.3"
      before_compute = true
      configuration_values = jsonencode({
        env = {
          # /28 prefixes per ENI slot: lifts the ENI-based pod limit
          # (29 on a 2 vCPU node), needed to run the whole stack on one node.
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    eks-pod-identity-agent = {
      addon_version  = "v1.3.10-eksbuild.3"
      before_compute = true
    }
    coredns = {
      addon_version        = "v1.14.7-eksbuild.11"
      configuration_values = jsonencode({ replicaCount = 1 })
    }
    kube-proxy = {
      addon_version = "v1.36.0-eksbuild.48"
    }
    aws-ebs-csi-driver = {
      addon_version        = "v1.67.0-eksbuild.1"
      configuration_values = jsonencode({ controller = { replicaCount = 1 } })
      pod_identity_association = [{
        role_arn        = module.aws_ebs_csi_driver_pod_identity.iam_role_arn
        service_account = "ebs-csi-controller-sa"
      }]
    }
    metrics-server = {
      addon_version        = "v0.9.0-eksbuild.13"
      configuration_values = jsonencode({ replicas = 1 })
    }
  }

  # One node that runs Karpenter, ArgoCD, the platform controllers and the
  # Langfuse/LiteLLM stack. Karpenter only adds nodes for vLLM ("inference")
  # and for overflow ("general"). scripts/sleep.sh scales it to 0
  # (desired_size is ignored by the module, so no drift).
  eks_managed_node_groups = {
    system = {
      name            = local.system_node_group_name
      use_name_prefix = false

      ami_type       = "AL2023_ARM_64_STANDARD"
      instance_types = var.system_node_instance_types
      capacity_type  = var.system_node_capacity_type

      # Single AZ: the EBS volumes of Postgres/ClickHouse/Valkey stay next to
      # the node across sleep/wake cycles.
      subnet_ids = [module.vpc.private_subnets[0]]

      min_size     = 0
      max_size     = 2
      desired_size = 1

      labels = {
        "karpenter.sh/controller" = "true"
      }

      # Prefix delegation (vpc-cni above) makes room for more pods than the
      # ENI-based default; 110 is the EKS recommendation for < 30 vCPUs.
      cloudinit_pre_nodeadm = [{
        content_type = "application/node.eks.aws"
        content      = <<-EOT
          ---
          apiVersion: node.eks.aws/v1alpha1
          kind: NodeConfig
          spec:
            kubelet:
              config:
                maxPods: 110
        EOT
      }]
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
