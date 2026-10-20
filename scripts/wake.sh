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
# Don't wait for the next poll (~3 min, longer while the repo-server starts):
# restoring the NodePool limits is what brings the vLLM node back.
kubectl -n argocd annotate applications.argoproj.io karpenter \
  argocd.argoproj.io/refresh=hard --overwrite >/dev/null

echo "==> Waiting for all applications to be Healthy (vLLM takes the longest)"
kubectl -n argocd wait applications.argoproj.io --all \
  --for=jsonpath='{.status.health.status}'=Healthy --timeout=20m
echo "Awake."
