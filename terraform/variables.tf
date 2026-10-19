variable "aws_profile" {
  description = "AWS CLI profile used by Terraform and by `aws eks get-token`. Null = default credential chain."
  type        = string
  default     = null
}

variable "region" {
  description = "AWS region for the cluster and all workload resources."
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Prefix for shared resources (Secrets Manager paths, S3 bucket, tags)."
  type        = string
  default     = "corporate-ai-gateway"
}

variable "cluster_name" {
  description = "EKS cluster name. Kept short: it prefixes IAM role names (64 char limit)."
  type        = string
  default     = "ai-gateway"
}

variable "kubernetes_version" {
  description = "EKS control plane version."
  type        = string
  default     = "1.36"
}

variable "vpc_cidr" {
  description = "VPC CIDR. Split into 3 private /20 and 3 public /24 subnets."
  type        = string
  default     = "10.0.0.0/16"
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "system_node_instance_types" {
  description = "Instance types for the managed node group hosting Karpenter, ArgoCD and CoreDNS (ARM64)."
  type        = list(string)
  default     = ["t4g.medium", "t4g.large"]
}

variable "system_node_capacity_type" {
  description = "ON_DEMAND or SPOT for the system node group. SPOT keeps the POC cheap."
  type        = string
  default     = "SPOT"
}

variable "parent_domain" {
  description = "Existing public Route53 zone in this account. A sub-zone is delegated from it."
  type        = string
}

variable "subdomain" {
  description = "Sub-zone label: services are exposed under *.<subdomain>.<parent_domain>."
  type        = string
  default     = "ai-gateway"
}

variable "ingress_allowed_cidrs" {
  description = "CIDRs allowed on the shared public ALB (comma-joined into the inbound-cidrs annotation)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "gitops_repo_url" {
  description = "Git repository ArgoCD syncs from (this repository)."
  type        = string
}

variable "gitops_target_revision" {
  description = "Branch, tag or commit ArgoCD tracks."
  type        = string
  default     = "main"
}

variable "langfuse_admin_email" {
  description = "Email of the Langfuse admin user created at first start (headless init)."
  type        = string
}
