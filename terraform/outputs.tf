output "cluster_name" {
  value = module.eks.cluster_name
}

output "configure_kubectl" {
  description = "Command to add the cluster to your kubeconfig."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}${var.aws_profile == null ? "" : " --profile ${var.aws_profile}"}"
}

output "urls" {
  value = {
    argocd   = "https://argocd.${local.domain}"
    litellm  = "https://litellm.${local.domain}"
    langfuse = "https://langfuse.${local.domain}"
  }
}

output "secrets_manager_secrets" {
  description = "Read with: aws secretsmanager get-secret-value --secret-id <name>"
  value = {
    litellm  = aws_secretsmanager_secret.litellm.name
    langfuse = aws_secretsmanager_secret.langfuse.name
  }
}
