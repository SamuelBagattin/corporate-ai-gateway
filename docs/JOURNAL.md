# Journal

Append-only log. Newest entries on top. Cap ~80 entries; archive older ones to `docs/journal-archive/YYYY-QN.md`.

## 2026-10-20 — LiteLLM agents work with vLLM (empty tools, tool calling)
- **Did:** Agent chat failed: the UI sends `tools: []`, which vLLM rejects (400). Added a LiteLLM pre-call hook (`gitops/apps/litellm/templates/custom-hooks.yaml`) that drops empty tools; enabled vLLM tool calling (`--enable-auto-tool-choice --tool-call-parser=hermes`). Verified both through the API.
- **Open:** Remove the hook once LiteLLM omits empty tools itself (BerriAI/litellm#31522).

## 2026-10-20 — LiteLLM UI can save models and agents
- **Did:** Agent builder failed with "failed to save agent": `/model/new` returned 500 because `STORE_MODEL_IN_DB` was off. Set `general_settings.store_model_in_db: true`; verified create/delete through the API.
- **Decisions:** UI-created models/agents live in LiteLLM's Postgres; `model_list` in Git stays the baseline (see ARCHITECTURE.md).

## 2026-10-20 — End-to-end verified: LiteLLM → vLLM → trace in Langfuse
- **Did:** First real sleep/wake cycle (`sleep.sh` overnight, `wake.sh` this morning: all 13 apps healthy again). `wake.sh` now forces a refresh of the karpenter app; without it the NodePool limits only came back after ~6 min.
- **Did:** Closed the "missing traces" issue: traces were ingested all along; the check used `/api/public/traces`, removed in Langfuse v4. Observations API v2 shows the generation with model, usage (21/7/28) and I/O. README documents the v2 query.
- **Open:** Move the Cloudflare `ai-gateway` NS delegation into Terraform (Cloudflare provider + token) and drop the Route53 parent-zone record.
- **Lessons:** Check API deprecations of the deployed major version before concluding data is missing.

## 2026-10-20 — First deploy: stack up, LiteLLM → vLLM works, Langfuse traces missing
- **Did:** `terraform apply` (135 resources); all 13 ArgoCD apps Synced/Healthy. Chat completion through `https://litellm.ai-gateway.samuelbagattin.com` answered by vLLM. Cluster put to sleep overnight (`scripts/sleep.sh`).
- **Did:** Fixes pushed to main: vLLM `--enforce-eager` (Inductor gcc segfault on arm64), KV cache 1 GiB + memory 6Gi/6912Mi, pinned vLLM v0.30.0 (v0.31/v0.32 crash on first request on CPU without Triton, fixed upstream by vllm#61992); Langfuse web/worker 2Gi + `NODE_OPTIONS=--max-old-space-size=1536`; ArgoCD ingress hostname set explicitly.
- **Decisions:** none architectural.
- **Open:** No traces in Langfuse although LiteLLM's LangfuseOtelLogger is active. Delegation `ai-gateway` NS records were added manually in Cloudflare (the real DNS for samuelbagattin.com): not in Terraform, and they change on every destroy/create. The Route53 parent-zone NS record is useless and should be removed.
- **Lessons:** Check where a domain's DNS is actually served before delegating. Helm parent `global.*` overrides a subchart's `global.*`.

## 2026-10-19 — Cost cuts + sleep/wake/destroy/create scripts (not applied)
- **Did:** Published the repo (public, github.com/SamuelBagattin/corporate-ai-gateway).
- **Did:** Cut always-on cost from ~260 to ~183 USD/month: fck-nat instead of NAT gateway, S3 gateway endpoint, one r7g.large system node for everything but vLLM (prefix delegation, maxPods 110), vLLM on Graviton, smaller disks, no KMS key.
- **Did:** Added `scripts/sleep.sh` / `wake.sh` (manual scale to zero, ~120 USD/month asleep) and `create.sh` / `destroy.sh` (full rebuild for long breaks). Plan: 135 to add.
- **Why:** User asked for lower cost; shutdown must be manual, plus a destroy/recreate option.
- **Decisions:** ARCHITECTURE.md compute, networking and operations entries.
- **Open:** First `scripts/create.sh`; scripts untested against a live cluster.

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
