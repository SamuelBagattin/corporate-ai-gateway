#!/usr/bin/env bash
# Destroy everything (for long breaks). Re-create with scripts/create.sh.
# All data (traces, keys, databases) is lost.
#
# Some AWS resources are created by in-cluster controllers, not by Terraform:
#   - the shared ALB (aws-load-balancer-controller, from Ingresses)
#   - EBS volumes (EBS CSI driver, from PVCs)
#   - EC2 instances (Karpenter, from NodePools)
# They are deleted first, while those controllers still run; otherwise
# `terraform destroy` leaves them behind (and fails on the VPC).
source "$(dirname "$0")/lib.sh"
load_outputs

if [[ "$(system_nodes_desired)" == 0 ]]; then
  echo "==> Cluster is asleep: starting the system node (controllers needed for cleanup)"
  scale_system_nodes 1
  wait_system_node_ready
fi

echo "==> Turning off ArgoCD auto-sync so nothing gets recreated"
for app in $(kubectl -n argocd get applications.argoproj.io -o name); do
  argocd_autosync off "${app#*/}"
done

echo "==> Deleting workloads (cascades to their Ingresses and PVCs)"
for app in litellm langfuse vllm; do
  kubectl -n argocd delete applications.argoproj.io "$app" --ignore-not-found --timeout=10m
done

echo "==> Deleting leftover PVCs (StatefulSet claims outlive their pods)"
kubectl delete pvc --all -n langfuse --ignore-not-found --timeout=5m
kubectl delete pvc --all -n litellm --ignore-not-found --timeout=5m

echo "==> Deleting remaining Ingresses (the controller removes the ALB)"
kubectl delete ingress --all -A --timeout=5m

echo "==> Deleting Karpenter NodePools (Karpenter terminates its instances)"
kubectl delete nodepools.karpenter.sh --all --timeout=15m
kubectl wait --for=delete nodeclaims.karpenter.sh --all --timeout=15m || true

echo "==> Making the remaining Applications non-cascading"
for app in $(kubectl -n argocd get applications.argoproj.io -o name); do
  kubectl -n argocd patch "$app" --type json \
    -p '[{"op":"remove","path":"/metadata/finalizers"}]' 2>/dev/null || true
done

echo "==> terraform destroy"
tf destroy "$@"
