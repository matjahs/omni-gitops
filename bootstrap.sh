#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
  local msg="$1"
  local level="${2:-info}"
  case "$level" in
    info) echo -e "${GREEN}INFO${NC}: $msg" ;;
    warn) echo -e "${YELLOW}WARN${NC}: $msg" ;;
    error) echo -e "${RED}ERROR${NC}: $msg" ;;
    debug) echo -e "${BLUE}DEBUG${NC}: $msg" ;;
    *) echo -e "${GREEN}INFO${NC}: $msg" ;;
  esac
}

usage() {
  cat <<EOF
Bootstrap Omni GitOps Platform

This script will:
1. Install ArgoCD in the cluster
2. Deploy platform applications (Traefik, MetalLB, Metrics Server)
3. Set up GitOps automation

Prerequisites:
- kubectl configured for target cluster
- Cluster with Talos OS + Cilium CNI
- Internet connectivity for image pulls

Usage: $0 [OPTIONS]

OPTIONS:
  -h, --help          Show this help message
  -d, --debug         Enable debug output
  --skip-wait         Skip waiting for ArgoCD readiness
  --no-port-forward   Don't start port forwarding

Examples:
  $0                  # Bootstrap with default settings
  $0 --debug          # Bootstrap with debug output
  $0 --skip-wait      # Quick bootstrap without waiting

EOF
  exit 0
}

# Parse command line arguments
DEBUG=false
SKIP_WAIT=false
NO_PORT_FORWARD=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      usage
      ;;
    -d|--debug)
      DEBUG=true
      shift
      ;;
    --skip-wait)
      SKIP_WAIT=true
      shift
      ;;
    --no-port-forward)
      NO_PORT_FORWARD=true
      shift
      ;;
    *)
      log "Unknown option: $1" error
      usage
      ;;
  esac
done

# Enable debug output if requested
if [[ "$DEBUG" == "true" ]]; then
  set -x
fi

# Configuration
REPO_URL="https://github.com/matjahs/omni-gitops.git"
ARGOCD_NAMESPACE="argocd"
TIMEOUT=300

log "Starting Omni GitOps Platform Bootstrap"
log "Repository: $REPO_URL"

# Preflight checks
preflight_checks() {
  log "Running preflight checks..."

  # Check kubectl access
  if ! kubectl cluster-info >/dev/null 2>&1; then
    log "kubectl is not configured or cluster is not accessible" error
    exit 1
  fi

  # Check if we're in the right directory
  if [[ ! -f "clusters/cluster1/kustomization.yaml" ]]; then
    log "clusters/cluster1/kustomization.yaml not found. Are you in the repository root?" error
    exit 1
  fi

  if [[ ! -f "applications/kustomization.yaml" ]]; then
    log "applications/kustomization.yaml not found. Are you in the repository root?" error
    exit 1
  fi

  # Check cluster readiness
  local ready_nodes
  ready_nodes=$(kubectl get nodes --no-headers | grep -c " Ready ")
  log "Found $ready_nodes ready nodes"

  if [[ $ready_nodes -lt 1 ]]; then
    log "No ready nodes found in cluster" error
    exit 1
  fi

  log "Preflight checks passed ✓"
}

# Install ArgoCD
install_argocd() {
  log "Checking ArgoCD installation..."

  if kubectl get namespace "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then
    log "ArgoCD namespace already exists, checking deployment status..." warn

    if kubectl get deployment argocd-server -n "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then
      log "ArgoCD server deployment exists, skipping installation"
      return 0
    fi
  fi

  log "Installing ArgoCD..."
  kubectl apply -k clusters/cluster1/

  if [[ "$SKIP_WAIT" == "false" ]]; then
    log "Waiting for ArgoCD server to be ready (timeout: ${TIMEOUT}s)..."
    if kubectl wait --for=condition=available --timeout="${TIMEOUT}s" deployment/argocd-server -n "$ARGOCD_NAMESPACE"; then
      log "ArgoCD server is ready ✓"
    else
      log "ArgoCD server failed to become ready within ${TIMEOUT}s" error
      log "Check pod status: kubectl get pods -n $ARGOCD_NAMESPACE" error
      exit 1
    fi
  fi
}

# Deploy platform applications
deploy_platform() {
  log "Deploying platform applications..."
  kubectl apply -k applications/

  log "Waiting for applications to be created..."
  sleep 5

  # Show application status
  log "Platform application status:"
  kubectl get applications -n "$ARGOCD_NAMESPACE" 2>/dev/null || log "Applications not yet visible (this is normal)"
}

# Get access information
get_access_info() {
  log "Retrieving access information..."

  # Get admin password
  local admin_password
  if admin_password=$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null); then
    log "ArgoCD admin password retrieved ✓"
  else
    log "Could not retrieve admin password (secret may not exist yet)" warn
    admin_password="<not available yet>"
  fi

  # Start port forwarding if requested
  if [[ "$NO_PORT_FORWARD" == "false" ]]; then
    log "Starting port forward to ArgoCD server..."
    kubectl port-forward svc/argocd-server -n "$ARGOCD_NAMESPACE" 8080:443 >/dev/null 2>&1 &
    local pf_pid=$!
    log "Port forward started (PID: $pf_pid)"

    # Give port forward time to establish
    sleep 2
  fi

  # Display access information
  echo
  echo "🚀 Bootstrap Complete!"
  echo "===================="
  echo
  echo "ArgoCD Access:"
  echo "  URL (local):  https://localhost:8080"
  echo "  URL (domain): https://cd.apps.lab.mxe11.nl"
  echo "  Username:     admin"
  echo "  Password:     $admin_password"
  echo
  echo "Platform Services:"
  echo "  Traefik:      https://traefik.apps.lab.mxe11.nl/dashboard"
  echo "  Omni:         https://matjahs.eu-central-1.omni.siderolabs.io/cluster1"
  echo "  vCenter:      https://vc.lab.mxe11.nl/ui"
  echo
  echo "Useful Commands:"
  echo "  kubectl get applications -n argocd"
  echo "  kubectl get pods --all-namespaces"
  echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
  echo
  echo "Next Steps:"
  echo "  1. Access ArgoCD UI and verify applications are syncing"
  echo "  2. Check platform component status"
  echo "  3. Add new applications via GitOps workflow"
  echo "  4. Review documentation in docs/"
  echo
}

# Cleanup function for interrupts
cleanup() {
  log "Cleaning up..." warn
  # Kill any background port-forward processes
  jobs -p | xargs -r kill 2>/dev/null || true
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Main execution
main() {
  preflight_checks
  install_argocd
  deploy_platform
  get_access_info
}

# Run main function
main "$@"
