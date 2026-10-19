#!/usr/bin/env bash
# Tear the whole environment down without leaking AWS resources.
#
# Some AWS resources are created by in-cluster controllers, not by Terraform:
#   - the shared ALB (aws-load-balancer-controller, from Ingresses)
#   - EBS volumes (EBS CSI driver, from PVCs)
#   - EC2 instances (Karpenter, from NodePools)
# They must be deleted while those controllers still run, otherwise
# `terraform destroy` leaves them behind (and fails on the VPC).
set -euo pipefail

cd "$(dirname "$0")/../terraform"

eval "$(terraform output -raw configure_kubectl)"

echo "==> Turning off ArgoCD auto-sync so nothing gets recreated"
for app in $(kubectl -n argocd get applications.argoproj.io -o name); do
  kubectl -n argocd patch "$app" --type json \
    -p '[{"op":"remove","path":"/spec/syncPolicy/automated"}]' 2>/dev/null || true
done

echo "==> Deleting workloads (cascades to their Ingresses and PVCs)"
for app in litellm langfuse vllm; do
  kubectl -n argocd delete application "$app" --ignore-not-found --timeout=10m
done

echo "==> Deleting leftover PVCs (StatefulSet claims outlive their pods)"
kubectl delete pvc --all -n langfuse --ignore-not-found --timeout=5m
kubectl delete pvc --all -n litellm --ignore-not-found --timeout=5m

echo "==> Deleting remaining Ingresses (the controller removes the ALB)"
kubectl delete ingress --all -A --timeout=5m

echo "==> Deleting Karpenter NodePools (Karpenter terminates its instances)"
kubectl delete nodepools.karpenter.sh --all --timeout=10m
kubectl wait --for=delete nodeclaims.karpenter.sh --all --timeout=10m || true

echo "==> Making the remaining Applications non-cascading"
for app in $(kubectl -n argocd get applications.argoproj.io -o name); do
  kubectl -n argocd patch "$app" --type json \
    -p '[{"op":"remove","path":"/metadata/finalizers"}]' 2>/dev/null || true
done

echo "==> terraform destroy"
terraform destroy "$@"
