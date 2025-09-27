#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
BASE_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

usage() {
  cat <<EOF
Usage: $0 <component-name>

ARGUMENTS:
  <component-name>   The name of the platform component to add (e.g., monitoring, logging).

FLAGS:
  --deploy          Apply the changes to the cluster immediately after adding the component.

EXAMPLE:
  ${BASH_SOURCE[0]} monitoring --deploy
This will create the necessary directory structure for the 'monitoring' component,
add it to platform/kustomization.yaml, and apply the changes to the cluster.
  ${BASH_SOURCE[0]} logging
This will create the necessary directory structure for the 'logging' component
and add it to platform/kustomization.yaml without applying the changes.
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

tmp_file=""
cleanup() {
  if [[ -n "$tmp_file" && -f "$tmp_file" ]]; then
    rm -f "$tmp_file"
  fi
}
trap cleanup EXIT

# parse command line args
COMPONENT_NAME="$1"

if [[ ! -f platform/kustomization.yaml ]]; then
  log "platform/kustomization.yaml not found. Run this script from the repository root." error
  exit 1
fi

log "Adding platform component ${COMPONENT_NAME}..."

log "Creating directory structure..."
mkdir -p "apps/${COMPONENT_NAME}/base"
mkdir -p "apps/${COMPONENT_NAME}/overlays/production"
touch "platform/${COMPONENT_NAME}.yaml"

log "Adding component to platform Kustomization..."
resource_line="  - ${COMPONENT_NAME}.yaml"
if ! grep -q -F -x "$resource_line" platform/kustomization.yaml; then
  log "Registering ${COMPONENT_NAME}.yaml in platform/kustomization.yaml..."
  tmp_file=$(mktemp)
  awk -v resource="$resource_line" '
    /^resources:/ && !added {
      print
      print resource
      added = 1
      next
    }
    { print }
  ' platform/kustomization.yaml > "$tmp_file"
  if [[ ! -s "$tmp_file" ]]; then
    log "Failed to update platform/kustomization.yaml" error
    exit 1
  fi
  mv "$tmp_file" platform/kustomization.yaml
  tmp_file=""
  if ! grep -q -F -x "$resource_line" platform/kustomization.yaml; then
    log "Failed to add ${COMPONENT_NAME}.yaml to platform/kustomization.yaml" error
    exit 1
  fi
else
  log "${COMPONENT_NAME}.yaml already listed in platform/kustomization.yaml; skipping registration." warn
fi

# deploy

if [[ "${2:-}" == "--deploy" ]]; then
  log "Applying platform kustomization..."
  # only if --deploy is passed

  if ! kubectl apply -k platform/; then
    log "Failed to apply platform kustomization" error
    exit 1
  fi
  log "Platform component ${COMPONENT_NAME} added and deployed successfully."
else
  log "Platform component ${COMPONENT_NAME} added successfully. Run with --deploy to apply changes."
fi
