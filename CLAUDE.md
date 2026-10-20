# Corporate AI Gateway

this project is about creating a corporate ai gateway hosted in eks, that will be at least composed of litellm + langfuse + vllm with open weight models as backend (amazon bedrock in a v2 also)
The goal is to provide a reference architecture.

## Memory — read at session start in this order
- @docs/PROJECT.md — what this project is, current scope
- @docs/ARCHITECTURE.md — stack, structure, dated decisions
- @docs/JOURNAL.md — recent history (read at least the last 5 entries)

## Hard rules
- Conventional Commits — commit messages and PR titles use `type(scope): description`.
- GitOps / IaC only — all infra changes go through Terraform and Helm/ArgoCD in Git. No manual kubectl or console changes.
- Validate before apply — run `terraform plan` and `helm lint` / `helm template` before any apply or sync.

## Workflow
- At the end of any non-trivial work unit, invoke the `project-memory` skill to update docs.
- When making an architectural decision, update `docs/ARCHITECTURE.md` inline before continuing — do not defer.
- Never edit `docs/JOURNAL.md` retroactively. Only append.
- Before `/clear` or `/compact`, run the `project-memory` skill first.

## Out of scope (non-goals)
- Cloudflare automation: the `ai-gateway` NS delegation in Cloudflare (the real DNS of the parent domain) stays manual.
