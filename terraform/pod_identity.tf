# One IAM role per controller, bound to its service account with EKS Pod Identity.
# Namespaces / service account names must match gitops/ values.
#
# Pod Identity injects credentials at pod creation only: an association must
# exist before its pods start. EKS add-ons get theirs through the add-on itself
# (eks.tf); ArgoCD-managed controllers are covered by depends_on in argocd.tf.

module "aws_ebs_csi_driver_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.10.0"

  name            = "${var.cluster_name}-aws-ebs-csi-driver"
  use_name_prefix = false

  attach_aws_ebs_csi_policy = true

  # Association created by the aws-ebs-csi-driver add-on (eks.tf).
}

module "aws_load_balancer_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.10.0"

  name            = "${var.cluster_name}-aws-load-balancer-controller"
  use_name_prefix = false

  attach_aws_lb_controller_policy = true

  associations = {
    main = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
    }
  }
}

module "external_dns_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.10.0"

  name            = "${var.cluster_name}-external-dns"
  use_name_prefix = false

  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = [aws_route53_zone.main.arn]

  associations = {
    main = {
      cluster_name    = module.eks.cluster_name
      namespace       = "external-dns"
      service_account = "external-dns"
    }
  }
}

module "external_secrets_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.10.0"

  name            = "${var.cluster_name}-external-secrets"
  use_name_prefix = false

  attach_external_secrets_policy        = true
  external_secrets_secrets_manager_arns = ["arn:aws:secretsmanager:${var.region}:${local.account_id}:secret:${local.secrets_prefix}/*"]
  external_secrets_create_permission    = false

  associations = {
    main = {
      cluster_name    = module.eks.cluster_name
      namespace       = "external-secrets"
      service_account = "external-secrets"
    }
  }
}

module "langfuse_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.10.0"

  name            = "${var.cluster_name}-langfuse"
  use_name_prefix = false

  attach_custom_policy = true
  policy_statements = [
    {
      sid       = "ListBucket"
      actions   = ["s3:ListBucket"]
      resources = [aws_s3_bucket.langfuse.arn]
    },
    {
      sid       = "ReadWriteObjects"
      actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
      resources = ["${aws_s3_bucket.langfuse.arn}/*"]
    },
  ]

  associations = {
    main = {
      cluster_name    = module.eks.cluster_name
      namespace       = "langfuse"
      service_account = "langfuse"
    }
  }
}
