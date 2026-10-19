# shellcheck shell=bash
# Shared helpers for scripts/*.sh. Sourced, not executed.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$REPO_ROOT/terraform"

tf() { terraform -chdir="$TF_DIR" "$@"; }

tf_init() {
  tf init -input=false -backend-config=backend_vars/s3.tfvars >/dev/null
}

# Reads the `ops` Terraform output, exports AWS_PROFILE / AWS_REGION and
# points kubectl at the cluster.
load_outputs() {
  [[ -d "$TF_DIR/.terraform" ]] || tf_init
  local ops profile
  ops=$(tf output -json ops)
  CLUSTER=$(jq -r .cluster_name <<<"$ops")
  REGION=$(jq -r .region <<<"$ops")
  NODE_GROUP=$(jq -r .system_node_group <<<"$ops")
  profile=$(jq -r '.aws_profile // empty' <<<"$ops")
  [[ -z "$profile" ]] || export AWS_PROFILE="$profile"
  export AWS_REGION="$REGION"
  aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" >/dev/null
}

system_nodes_desired() {
  aws eks describe-nodegroup --cluster-name "$CLUSTER" --nodegroup-name "$NODE_GROUP" \
    --query nodegroup.scalingConfig.desiredSize --output text
}

# Terraform ignores desired_size, so changing it here causes no drift.
scale_system_nodes() {
  local desired=$1 min max
  read -r min max < <(aws eks describe-nodegroup --cluster-name "$CLUSTER" --nodegroup-name "$NODE_GROUP" \
    --query 'nodegroup.scalingConfig.[minSize,maxSize]' --output text)
  aws eks update-nodegroup-config --cluster-name "$CLUSTER" --nodegroup-name "$NODE_GROUP" \
    --scaling-config "minSize=$min,maxSize=$max,desiredSize=$desired" >/dev/null
  aws eks wait nodegroup-active --cluster-name "$CLUSTER" --nodegroup-name "$NODE_GROUP"
}

wait_system_node_ready() {
  local selector=karpenter.sh/controller=true
  for _ in $(seq 60); do
    [[ -n "$(kubectl get nodes -l "$selector" -o name 2>/dev/null)" ]] && break
    sleep 10
  done
  kubectl wait --for=condition=Ready nodes -l "$selector" --timeout=10m
}

# argocd_autosync on|off <app>...
argocd_autosync() {
  local mode=$1 app
  shift
  for app in "$@"; do
    if [[ "$mode" == off ]]; then
      kubectl -n argocd patch applications.argoproj.io "$app" --type json \
        -p '[{"op":"remove","path":"/spec/syncPolicy/automated"}]' 2>/dev/null || true
    else
      kubectl -n argocd patch applications.argoproj.io "$app" --type merge \
        -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
    fi
  done
}
