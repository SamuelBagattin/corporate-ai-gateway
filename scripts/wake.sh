#!/usr/bin/env bash
# Resume after scripts/sleep.sh: start the system node, then let ArgoCD restore
# the Karpenter NodePools from Git (Karpenter then starts the vLLM node).
source "$(dirname "$0")/lib.sh"
load_outputs

echo "==> Scaling the system node group to 1"
scale_system_nodes 1
wait_system_node_ready

echo "==> Resuming ArgoCD auto-sync"
argocd_autosync on bootstrap karpenter

echo "==> Waiting for all applications to be Healthy (vLLM takes the longest)"
kubectl -n argocd wait applications.argoproj.io --all \
  --for=jsonpath='{.status.health.status}'=Healthy --timeout=20m
echo "Awake."
