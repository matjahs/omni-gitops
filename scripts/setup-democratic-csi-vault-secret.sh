#!/usr/bin/env bash
set -euo pipefail

# Democratic-CSI Vault Secret Setup
# This script stores Synology iSCSI credentials in Vault for democratic-csi

VAULT_ADDR="${VAULT_ADDR:-http://172.16.0.4:8200}"
VAULT_SECRET_PATH="secret/democratic-csi/synology"  # pragma: allowlist secret

# Synology Configuration
# Set these environment variables before running this script
SYNOLOGY_HOST="${SYNOLOGY_HOST:-172.16.0.189}"
SYNOLOGY_USERNAME="${SYNOLOGY_USERNAME:-}"
SYNOLOGY_PASSWORD="${SYNOLOGY_PASSWORD:-}"
SYNOLOGY_VOLUME="${SYNOLOGY_VOLUME:-/volume1}"
SYNOLOGY_IQN="${SYNOLOGY_IQN:-iqn.2000-01.com.synology:kubernetes-storage}"

# iSCSI CHAP Configuration
CHAP_USERNAME="${CHAP_USERNAME:-}"
CHAP_PASSWORD="${CHAP_PASSWORD:-}"

echo "Setting up democratic-csi secrets in Vault..."
echo "Vault Address: $VAULT_ADDR"
echo "Secret Path: $VAULT_SECRET_PATH"
echo ""

# Check if vault CLI is available
if ! command -v vault &> /dev/null; then
    echo "ERROR: vault CLI not found. Please install it first."
    exit 1
fi

# Check if VAULT_TOKEN is set
if [ -z "${VAULT_TOKEN:-}" ]; then
    echo "ERROR: VAULT_TOKEN environment variable is not set."
    echo "Please authenticate to Vault first:"
    echo "  export VAULT_TOKEN=<your-token>"
    exit 1
fi

# Validate required variables
MISSING_VARS=()
[ -z "$SYNOLOGY_USERNAME" ] && MISSING_VARS+=("SYNOLOGY_USERNAME")
[ -z "$SYNOLOGY_PASSWORD" ] && MISSING_VARS+=("SYNOLOGY_PASSWORD")
[ -z "$CHAP_USERNAME" ] && MISSING_VARS+=("CHAP_USERNAME")
[ -z "$CHAP_PASSWORD" ] && MISSING_VARS+=("CHAP_PASSWORD")

if [ ${#MISSING_VARS[@]} -ne 0 ]; then
    echo "ERROR: Required environment variables are not set:"
    for var in "${MISSING_VARS[@]}"; do
        echo "  - $var"
    done
    echo ""
    echo "Example usage:"
    echo "  export SYNOLOGY_USERNAME='vsphere'"
    echo "  export SYNOLOGY_PASSWORD='your-password'"  # pragma: allowlist secret
    echo "  export CHAP_USERNAME='k8siscsi'"
    echo "  export CHAP_PASSWORD='your-chap-password'"  # pragma: allowlist secret
    echo "  export VAULT_TOKEN='your-vault-token'"
    echo "  $0"
    exit 1
fi

# Write secret to Vault
vault kv put "$VAULT_SECRET_PATH" \
  host="$SYNOLOGY_HOST" \
  username="$SYNOLOGY_USERNAME" \
  password="$SYNOLOGY_PASSWORD" \
  volume="$SYNOLOGY_VOLUME" \
  iqn="$SYNOLOGY_IQN" \
  chap_username="$CHAP_USERNAME" \
  chap_password="$CHAP_PASSWORD"

echo ""
echo "✅ Secret created successfully!"
echo ""
echo "Verify with:"
echo "  vault kv get $VAULT_SECRET_PATH"
echo ""
echo "Next steps:"
echo "  1. Commit and push the democratic-csi Flux configuration"
echo "  2. Wait for Flux to reconcile"
echo "  3. Verify democratic-csi pods are running:"
echo "     kubectl get pods -n democratic-csi"
