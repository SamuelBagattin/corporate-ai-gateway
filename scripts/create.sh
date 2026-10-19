#!/usr/bin/env bash
# Create (or re-create after scripts/destroy.sh) the whole environment.
# Terraform builds the AWS side and bootstraps ArgoCD, which deploys the rest
# from Git. Allow ~30 minutes end to end. A re-created environment starts with
# empty databases and freshly generated secrets.
source "$(dirname "$0")/lib.sh"

tf_init
tf apply

load_outputs
echo "Terraform done; ArgoCD is now deploying. Follow with:"
echo "  kubectl -n argocd get applications -w"
tf output urls
