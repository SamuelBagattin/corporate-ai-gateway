# Journal

Append-only log. Newest entries on top. Cap ~80 entries; archive older ones to `docs/journal-archive/YYYY-QN.md`.

## 2026-10-19 — Terraform + GitOps scaffold for the full stack (not applied)
- **Did:** Wrote `terraform/` (VPC, EKS 1.36, system node group, Karpenter IAM, Pod Identity roles, Route53 sub-zone + ACM, Langfuse S3, Secrets Manager, ArgoCD install + root app) with state in the S3 bucket of the personal account.
- **Did:** Wrote `gitops/` app-of-apps: 9 platform apps (argocd, karpenter, cluster-config, LB controller, external-dns, external-secrets, cert-manager, cloudnative-pg, clickhouse-operator) + vllm, langfuse, litellm. Added `scripts/teardown.sh` and README.
- **Did:** Validated: `terraform validate` + `plan` (129 to add), every child chart rendered with the exact values the bootstrap passes it.
- **Decisions:** See ARCHITECTURE.md entries dated 2026-10-19 (bootstrap pattern, compute, Pod Identity, secrets, datastores, networking).
- **Open:** Push repo to GitHub (ArgoCD source) and decide its visibility; first `terraform apply`; end-to-end test call; Bedrock (v2).

## 2026-10-19 — Project initialized
- **Did:** Set up project-memory system (CLAUDE.md, PROJECT.md, ARCHITECTURE.md, JOURNAL.md, project-memory skill).
- **Why:** Establish lightweight self-maintaining documentation from day one.
- **Decisions:** Chose minimal 3-file + 1-skill pattern over BMAD-style multi-persona frameworks.
- **Open:** Populate PROJECT.md scope and ARCHITECTURE.md structure as code starts landing.
- **Lessons:** _None yet._
