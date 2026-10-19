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
   │ vLLM (CPU, x86 spot)   │   Karpenter NodePools: "general" (Graviton, spot) / "inference" (x86 AVX-512, spot)
   └────────────────────────┘   System managed node group: Karpenter, ArgoCD, CoreDNS
```

## Layout

| Path | What |
|---|---|
| `terraform/` | VPC, EKS, Karpenter IAM, Pod Identity roles, Route53 sub-zone + ACM, Langfuse S3 bucket, Secrets Manager secrets, ArgoCD bootstrap |
| `gitops/bootstrap/` | App-of-apps: one ArgoCD Application per component, fed with Terraform outputs |
| `gitops/platform/` | Cluster add-ons: argocd, karpenter, cluster-config, aws-load-balancer-controller, external-dns, external-secrets, cert-manager, cloudnative-pg, clickhouse-operator |
| `gitops/apps/` | Workloads: vllm, litellm, langfuse |
| `scripts/teardown.sh` | Clean teardown (removes controller-created ALB / EBS / EC2 first) |

## Deploy

Prerequisites: Terraform ≥ 1.12, Helm ≥ 3.17, AWS CLI v2, kubectl, an existing public
Route53 zone in the account, and this repository pushed to the URL in
`terraform/terraform.tfvars` (`gitops_repo_url`) — ArgoCD syncs from it.

```bash
cd terraform
terraform init -backend-config=backend_vars/s3.tfvars
terraform plan -out=tf.plan
terraform apply tf.plan
```

Then:

```bash
$(terraform output -raw configure_kubectl)
kubectl -n argocd get applications -w
```

Everything converges in ~15–20 minutes after `apply` (EKS ~10 min, then ArgoCD waves).

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

## Teardown

```bash
./scripts/teardown.sh
```

## Cost (eu-west-1, always on, estimate)

| Item | ~USD / month |
|---|---|
| EKS control plane | 73 |
| NAT gateway (single) | 35 + traffic |
| ALB | 20 |
| System nodes, 2× t4g.medium spot | 26 |
| General Karpenter node(s), Graviton spot | 25–40 |
| Inference node, x86 2 vCPU / 8 GiB spot | 40 |
| EBS, public IPv4, Route53, Secrets Manager | 30 |
| **Total** | **≈ 250–270** (≈ 0.35 USD/h) |

Biggest levers: destroy when idle, scale `gitops/apps/vllm` replicas to 0, replace
the NAT gateway with a NAT instance.
