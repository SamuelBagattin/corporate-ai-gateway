# Bootstrap only: Terraform installs ArgoCD once, then the "argocd" Application
# (gitops/bootstrap) takes over and ArgoCD manages itself from Git.

resource "helm_release" "argocd" {
  name              = "argocd"
  namespace         = "argocd"
  create_namespace  = true
  chart             = "${path.module}/../gitops/platform/argocd"
  dependency_update = true
  timeout           = 900

  lifecycle {
    ignore_changes = all
  }

  depends_on = [module.eks]
}

locals {
  # Account-specific values handed to every Application through the root app,
  # so nothing account-specific is committed under gitops/.
  gitops_global = {
    repoURL             = var.gitops_repo_url
    targetRevision      = var.gitops_target_revision
    clusterName         = module.eks.cluster_name
    region              = var.region
    accountId           = local.account_id
    vpcId               = module.vpc.vpc_id
    domain              = local.domain
    certificateArn      = aws_acm_certificate_validation.main.certificate_arn
    ingressAllowedCidrs = join(",", var.ingress_allowed_cidrs)
    secretsPrefix       = local.secrets_prefix
    karpenter = {
      nodeRoleName      = module.karpenter.node_iam_role_name
      interruptionQueue = module.karpenter.queue_name
    }
    langfuse = {
      bucket = aws_s3_bucket.langfuse.bucket
    }
  }
}

resource "helm_release" "argocd_root" {
  name       = "argocd-root"
  namespace  = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = "2.0.7"

  values = [yamlencode({
    applications = {
      # No resources finalizer: deleting the root app (e.g. terraform destroy)
      # must not cascade into every child app, ArgoCD included.
      bootstrap = {
        namespace = "argocd"
        project   = "default"
        source = {
          repoURL        = var.gitops_repo_url
          targetRevision = var.gitops_target_revision
          path           = "gitops/bootstrap"
          helm = {
            valuesObject = {
              global = local.gitops_global
            }
          }
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "argocd"
        }
        syncPolicy = {
          automated = {
            prune    = true
            selfHeal = true
          }
        }
      }
    }
  })]

  # Everything the GitOps workloads need at first start: Pod Identity
  # associations (read at pod creation) and the secrets External Secrets syncs.
  depends_on = [
    helm_release.argocd,
    module.karpenter,
    module.aws_load_balancer_controller_pod_identity,
    module.external_dns_pod_identity,
    module.external_secrets_pod_identity,
    module.langfuse_pod_identity,
    aws_secretsmanager_secret_version.litellm,
    aws_secretsmanager_secret_version.langfuse,
  ]
}
