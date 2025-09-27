#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 <node1> [<node2> ...]

ARGUMENTS:
  <node>            The name of a Kubernetes node to reboot. Multiple nodes can be specified.

EOF
  exit 1
}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

log() {
  local msg="$1"
  local level="${2:-info}"
  case "$level" in
    info) echo -e "${GREEN}INFO${NC}: $msg" ;;
    warn) echo -e "${YELLOW}WARN${NC}: $msg" ;;
    error) echo -e "${RED}ERROR${NC}: $msg" ;;
    *) echo -e "${GREEN}INFO${NC}: $msg" ;;
  esac
}

if [[ $# -lt 1 ]]; then
  usage
fi

log "Bootstrapping GitOps platform..."

REPO_URL="https://github.com/matjahs/omni-gitops"
CLUSTER_NAME="matjahs-cluster1"

log "Repository: $REPO_URL"
log "Cluster Name: $CLUSTER_NAME"

# check if argocd is already running
if kubectl get ns argocd >/dev/null 2>&1; then
  log "ArgoCD namespace already exists. Skipping installation." warn
else
  log "Installing ArgoCD..."
  kubectl apply -k apps/argocd/base/

  log "Waiting for ArgoCD server to be ready..."
  kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
fi

log "applying platform applications..."
kubectl apply -k platform/

log "waiting for applications to sync..."
sleep 10

log "Platform status:"
kubectl get applications -n argocd
kubectl get pods -n argocd

# forward argocd-server to localhost:8080
port_forward() {
  log "Forwarding ArgoCD server to localhost:8080..."
  kubectl port-forward svc/argocd-server -n argocd 8080:443 &
  PF_PID=$!
  log "Port forward PID: $PF_PID"
}

# Start port forwarding in the background
port_forward

admin_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

log ""
log "Bootstrapping complete!"
log "Access the ArgoCD UI with the following command:"
log "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
log "Then open your browser to https://localhost:8080"
log ""
log "Get admin password: $admin_password"
log ""


