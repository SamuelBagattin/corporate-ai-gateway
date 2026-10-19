#!/usr/bin/env bash
# Scale the cluster down to zero nodes, keeping everything else: control plane,
# NAT instance, ALB, DNS, and the EBS volumes holding Postgres/ClickHouse data.
# Resume with scripts/wake.sh.
source "$(dirname "$0")/lib.sh"
load_outputs

echo "==> Pausing ArgoCD auto-sync (bootstrap, karpenter) so it doesn't undo the next steps"
argocd_autosync off bootstrap karpenter

echo "==> Stopping Karpenter from launching nodes, then removing its nodes"
for nodepool in $(kubectl get nodepools.karpenter.sh -o name); do
  kubectl patch "$nodepool" --type merge -p '{"spec":{"limits":{"cpu":"0"}}}'
done
kubectl delete nodeclaims.karpenter.sh --all --timeout=15m

echo "==> Draining the system node (pods are deleted, PDBs can't block)"
kubectl drain -l karpenter.sh/controller=true --ignore-daemonsets --delete-emptydir-data \
  --disable-eviction --force --timeout=5m

echo "==> Scaling the system node group to 0"
scale_system_nodes 0

echo "Asleep. Run scripts/wake.sh to resume."
