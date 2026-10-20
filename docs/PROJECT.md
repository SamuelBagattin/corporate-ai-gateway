# Project: Corporate AI Gateway

## Purpose
this project is about creating a corporate ai gateway hosted in eks, that will be at least composed of litellm + langfuse + vllm with open weight models as backend (amazon bedrock in a v2 also)
The goal is to provide a reference architecture.

## Users
_TODO: who specifically uses this — fill in as the project evolves._

## Scope — in
- EKS cluster and AWS foundations in Terraform (personal AWS account, eu-west-1).
- GitOps (ArgoCD app-of-apps) for platform add-ons and workloads.
- LiteLLM gateway → vLLM (CPU, open-weight model), traced in Langfuse.
- Public HTTPS endpoints under `*.ai-gateway.samuelbagattin.com`.

## Scope — out (non-goals)
- Cloudflare automation: the `ai-gateway` NS delegation in Cloudflare (the real DNS of the parent domain) stays manual.

## Status
- **Phase:** POC verified end to end, then destroyed (2026-10-20). Recreate with `scripts/create.sh`.
- **Started:** 2026-10-19
- **Next milestone:** _TODO_ (v2: Amazon Bedrock backend)
