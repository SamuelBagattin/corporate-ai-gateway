# Application secrets are generated here, stored in Secrets Manager and synced
# into the cluster by External Secrets (ClusterSecretStore "aws-secrets-manager").
# Helm charts never generate secrets themselves: ArgoCD renders with
# `helm template`, so chart-side `lookup`/`randAlphaNum` would rotate them on
# every sync.

resource "random_password" "litellm_master_key" {
  length  = 48
  special = false
}

resource "random_password" "litellm_salt_key" {
  length  = 48
  special = false
}

resource "random_password" "langfuse_salt" {
  length  = 32
  special = false
}

resource "random_id" "langfuse_encryption_key" {
  byte_length = 32 # 64 hex chars, as required by ENCRYPTION_KEY
}

resource "random_password" "langfuse_nextauth_secret" {
  length  = 32
  special = false
}

resource "random_password" "langfuse_clickhouse" {
  length  = 32
  special = false
}

resource "random_password" "langfuse_redis" {
  length  = 32
  special = false
}

resource "random_password" "langfuse_admin" {
  length  = 24
  special = false
}

resource "random_uuid" "langfuse_project_public_key" {}

resource "random_uuid" "langfuse_project_secret_key" {}

locals {
  langfuse_project_public_key = "pk-lf-${random_uuid.langfuse_project_public_key.result}"
  langfuse_project_secret_key = "sk-lf-${random_uuid.langfuse_project_secret_key.result}"
}

resource "aws_secretsmanager_secret" "litellm" {
  name                    = "${local.secrets_prefix}/litellm"
  description             = "LiteLLM proxy credentials (keys are env var names)."
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "litellm" {
  secret_id = aws_secretsmanager_secret.litellm.id
  secret_string = jsonencode({
    PROXY_MASTER_KEY    = "sk-${random_password.litellm_master_key.result}"
    LITELLM_SALT_KEY    = "sk-${random_password.litellm_salt_key.result}"
    LANGFUSE_PUBLIC_KEY = local.langfuse_project_public_key
    LANGFUSE_SECRET_KEY = local.langfuse_project_secret_key
  })
}

resource "aws_secretsmanager_secret" "langfuse" {
  name                    = "${local.secrets_prefix}/langfuse"
  description             = "Langfuse credentials, datastore passwords and headless-init values."
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "langfuse" {
  secret_id = aws_secretsmanager_secret.langfuse.id
  secret_string = jsonencode({
    salt                    = random_password.langfuse_salt.result
    encryption-key          = random_id.langfuse_encryption_key.hex
    nextauth-secret         = random_password.langfuse_nextauth_secret.result
    clickhouse-password     = random_password.langfuse_clickhouse.result
    redis-password          = random_password.langfuse_redis.result
    init-project-public-key = local.langfuse_project_public_key
    init-project-secret-key = local.langfuse_project_secret_key
    init-user-email         = var.langfuse_admin_email
    init-user-password      = random_password.langfuse_admin.result
  })
}
