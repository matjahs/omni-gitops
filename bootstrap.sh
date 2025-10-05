#!/usr/bin/env bash
# Copyright (c) 2024 Matjah
# SPDX-License-Identifier: MIT

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
1. Verify Flux CD is installed and bootstrapped
2. Reconcile Flux to deploy ArgoCD and infrastructure
3. Deploy ArgoCD Applications for platform services
4. Set up GitOps automation

Prerequisites:
- kubectl configured for target cluster
- Flux CD installed and bootstrapped (see: flux bootstrap)
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

NOTE: ArgoCD is now deployed by Flux. This script assumes Flux is already installed.
      For new clusters, run: flux bootstrap github --owner=matjahs --repository=omni-gitops

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
FLUX_NAMESPACE="flux-system"
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

  # Check if Flux is installed
  if ! kubectl get namespace "$FLUX_NAMESPACE" >/dev/null 2>&1; then
    log "Flux namespace not found. Please bootstrap Flux first:" error
    log "  flux bootstrap github --owner=matjahs --repository=omni-gitops --path=flux" error
    exit 1
  fi

  if ! kubectl get deployment source-controller -n "$FLUX_NAMESPACE" >/dev/null 2>&1; then
    log "Flux controllers not found. Please install Flux first." error
    exit 1
  fi

  # Check if we're in the right directory
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

# Reconcile Flux to deploy ArgoCD
reconcile_flux() {
  log "Checking Flux status..."

  # Check Flux Kustomizations
  local flux_ready
  flux_ready=$(kubectl get kustomization -n "$FLUX_NAMESPACE" flux-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")

  if [[ "$flux_ready" != "True" ]]; then
    log "Flux system kustomization is not ready. Status: $flux_ready" warn
    log "Attempting to reconcile Flux..." warn
  fi

  log "Reconciling Flux to deploy infrastructure and ArgoCD..."
  flux reconcile source git flux-system --with-source || true
  flux reconcile kustomization flux-system --with-source || true

  if [[ "$SKIP_WAIT" == "false" ]]; then
    log "Waiting for ArgoCD HelmRelease to be ready (timeout: ${TIMEOUT}s)..."

    # Wait for ArgoCD namespace to exist
    local wait_count=0
    while ! kubectl get namespace "$ARGOCD_NAMESPACE" >/dev/null 2>&1; do
      if [[ $wait_count -gt 60 ]]; then
        log "ArgoCD namespace not created after 60s. Check Flux logs:" error
        log "  kubectl logs -n $FLUX_NAMESPACE -l app=helm-controller" error
        exit 1
      fi
      sleep 1
      ((wait_count++))
    done

    # Wait for ArgoCD server deployment
    if kubectl wait --for=condition=available --timeout="${TIMEOUT}s" deployment/argocd-server -n "$ARGOCD_NAMESPACE" 2>/dev/null; then
      log "ArgoCD server is ready ✓"
    else
      log "ArgoCD server failed to become ready within ${TIMEOUT}s" error
      log "Check HelmRelease status: kubectl describe helmrelease argocd -n $ARGOCD_NAMESPACE" error
      log "Check pod status: kubectl get pods -n $ARGOCD_NAMESPACE" error
      exit 1
    fi
  fi
}

# Deploy platform applications via ArgoCD
deploy_platform() {
  log "Deploying platform applications..."

  # Apply ArgoCD Applications
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
  echo "GitOps Architecture:"
  echo "  Flux CD:     Manages infrastructure (ArgoCD, storage, networking)"
  echo "  ArgoCD:      Manages platform applications"
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
  echo "  # ArgoCD"
  echo "  kubectl get applications -n argocd"
  echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
  echo
  echo "  # Flux"
  echo "  flux get kustomizations"
  echo "  flux get helmreleases -A"
  echo "  flux reconcile kustomization flux-apps --with-source"
  echo
  echo "  # General"
  echo "  kubectl get pods --all-namespaces"
  echo
  echo "Next Steps:"
  echo "  1. Access ArgoCD UI and verify applications are syncing"
  echo "  2. Check platform component status"
  echo "  3. Add new applications via GitOps workflow"
  echo "  4. Review documentation in docs/"
  echo
  echo "Documentation:"
  echo "  - Flux/ArgoCD Hybrid: flux/README.md"
  echo "  - Migration Guide:    docs/ARGOCD_FLUX_MIGRATION.md"
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
  reconcile_flux
  deploy_platform
  get_access_info
}

# Run main function
main "$@"
