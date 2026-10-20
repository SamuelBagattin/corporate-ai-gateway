# Corporate AI Gateway

Reference architecture for a self-hosted AI gateway on AWS EKS:
**LiteLLM** (OpenAI-compatible gateway, virtual keys, spend tracking) in front of
**vLLM** (open-weight models, CPU in this POC), with every call traced in **Langfuse**.
Amazon Bedrock is planned as a second backend (v2).

```
                 ┌──────────── shared ALB (*.ai-gateway.<domain>, ACM) ────────────┐
                 │                         │                                       │
          litellm.<domain>          langfuse.<domain>                      argocd.<domain>
                 │                         │                                       │
   ┌─────────────▼──────────┐   ┌──────────▼─────────────────────┐      ┌──────────▼──────────┐
   │ LiteLLM proxy          │──▶│ Langfuse web + worker          │      │ ArgoCD (self-managed)│
   │  Postgres (CNPG)       │OTEL│  Postgres (CNPG), Valkey,     │      └─────────────────────┘
   └─────────────┬──────────┘   │  ClickHouse (operator), S3     │
                 │              └────────────────────────────────┘
   ┌─────────────▼──────────┐
   │ vLLM (CPU, Graviton)   │   Karpenter NodePool "inference" (Graviton3+, spot)
   └────────────────────────┘   One system node (r7g.large spot) runs everything else
```

## Layout

| Path | What |
|---|---|
| `terraform/` | VPC (fck-nat, S3 endpoint), EKS, Karpenter IAM, Pod Identity roles, Route53 sub-zone + ACM, Langfuse S3 bucket, Secrets Manager secrets, ArgoCD bootstrap |
| `gitops/bootstrap/` | App-of-apps: one ArgoCD Application per component, fed with Terraform outputs |
| `gitops/platform/` | Cluster add-ons: argocd, karpenter, cluster-config, aws-load-balancer-controller, external-dns, external-secrets, cert-manager, cloudnative-pg, clickhouse-operator |
| `gitops/apps/` | Workloads: vllm, litellm, langfuse |
| `scripts/` | `create.sh`, `sleep.sh`, `wake.sh`, `destroy.sh` |

## Prerequisites

Terraform ≥ 1.12, Helm ≥ 3.17, AWS CLI v2, kubectl, jq, an existing public Route53
zone in the account, and this repository pushed to the URL in
`terraform/terraform.tfvars` (`gitops_repo_url`): ArgoCD syncs from it.

## Operating it

| Command | When | What it does | Takes |
|---|---|---|---|
| `scripts/create.sh` | First deploy, or after `destroy.sh` | `terraform apply`; ArgoCD then deploys everything from Git | ~30 min |
| `scripts/sleep.sh` | End of a work session | Scales all nodes to 0. Keeps the control plane, ALB, DNS and data (EBS) | ~5 min |
| `scripts/wake.sh` | Start of a work session | Starts the system node; ArgoCD restores Karpenter, which starts the vLLM node | ~10 min |
| `scripts/destroy.sh` | Long break | Deletes controller-created AWS resources (ALB, EBS, EC2), then `terraform destroy`. **All data is lost** | ~20 min |

A re-created environment starts with empty databases and new secrets, and a new
Route53 sub-zone: `create.sh` prints its name servers, to be set by hand as the
`ai-gateway` NS records at the parent domain's DNS provider (Cloudflare here). Follow a
deployment with `kubectl -n argocd get applications -w`.

## Access

| | URL | Credentials |
|---|---|---|
| ArgoCD | `https://argocd.<domain>` | `admin` / `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' \| base64 -d` |
| Langfuse | `https://langfuse.<domain>` | `init-user-email` / `init-user-password` in secret `corporate-ai-gateway/langfuse` |
| LiteLLM | `https://litellm.<domain>` | `PROXY_MASTER_KEY` in secret `corporate-ai-gateway/litellm` |

```bash
KEY=$(aws secretsmanager get-secret-value --secret-id corporate-ai-gateway/litellm \
  --query SecretString --output text | jq -r .PROXY_MASTER_KEY)
curl https://litellm.<domain>/v1/chat/completions -H "Authorization: Bearer $KEY" \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen3-0.6b","messages":[{"role":"user","content":"Hello"}]}'
```

Every call is traced in Langfuse (project "LiteLLM"). Langfuse v4 removed the v1
read APIs (`/api/public/traces`); query the Observations API v2 instead:

```bash
S=$(aws secretsmanager get-secret-value --secret-id corporate-ai-gateway/litellm --query SecretString --output text)
curl -s -u "$(jq -r .LANGFUSE_PUBLIC_KEY <<<"$S"):$(jq -r .LANGFUSE_SECRET_KEY <<<"$S")" \
  "https://langfuse.<domain>/api/public/v2/observations?fromStartTime=$(date -u -v-1H +%FT%TZ)&toStartTime=$(date -u +%FT%TZ)" \
  | jq '.data[] | {name, type, startTime}'
```

## Cost (eu-west-1, estimates)

| Item | Awake, USD / month | Asleep, USD / month |
|---|---|---|
| EKS control plane | 73 | 73 |
| ALB + its 3 public IPs | 31 | 31 |
| NAT instance (t4g.nano) + public IP | 7 | 7 |
| System node, r7g.large spot | 35 | 0 |
| vLLM node, m7g.large spot | 28 | 0 |
| EBS, Route53, Secrets Manager | 9 | 9 |
| **Total** | **≈ 183** (0.25 USD/h) | **≈ 120** (4 USD/day) |

Example: awake 50 h/week, asleep otherwise ≈ 140 USD/month. Destroyed: 0.
