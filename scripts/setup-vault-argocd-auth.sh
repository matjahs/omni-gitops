#!/bin/bash
set -e

# Setup Vault Kubernetes Auth for ArgoCD
# This script configures Vault to allow ArgoCD to authenticate using Kubernetes ServiceAccount tokens

VAULT_ADDR=${VAULT_ADDR:-"http://172.16.0.4:8200"}
VAULT_NAMESPACE=${VAULT_NAMESPACE:-""}
K8S_NAMESPACE="argocd"
SA_NAME="argocd-repo-server"

echo "🔐 Setting up Vault Kubernetes Auth for ArgoCD"
echo "Vault Address: $VAULT_ADDR"

# 1. Enable Kubernetes auth method (if not already enabled)
echo "📝 Enabling Kubernetes auth method..."
vault auth enable -path=kubernetes kubernetes 2>/dev/null || echo "Kubernetes auth already enabled"

# 2. Get Kubernetes cluster info
echo "🔍 Getting Kubernetes cluster information..."
K8S_HOST=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.server}')
K8S_CA_CERT=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d)

# Get the ServiceAccount token (K8s 1.24+)
echo "🎫 Creating ServiceAccount token for Vault..."
SA_TOKEN=$(kubectl create token $SA_NAME -n $K8S_NAMESPACE --duration=8760h)

# 3. Configure Kubernetes auth method
echo "⚙️  Configuring Kubernetes auth method..."
vault write auth/kubernetes/config \
    token_reviewer_jwt="$SA_TOKEN" \
    kubernetes_host="$K8S_HOST" \
    kubernetes_ca_cert="$K8S_CA_CERT" \
    disable_local_ca_jwt=true

# 4. Create a policy for ArgoCD
echo "📋 Creating ArgoCD policy..."
vault policy write argocd - <<EOF
# Allow ArgoCD to read secrets from specific paths
path "secret/data/argocd/*" {
  capabilities = ["read", "list"]
}

path "secret/data/applications/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/argocd/*" {
  capabilities = ["list"]
}

path "secret/metadata/applications/*" {
  capabilities = ["list"]
}
EOF

# 5. Create Kubernetes auth role for ArgoCD
echo "👤 Creating Kubernetes auth role..."
vault write auth/kubernetes/role/argocd \
    bound_service_account_names=$SA_NAME \
    bound_service_account_namespaces=$K8S_NAMESPACE \
    policies=argocd \
    ttl=24h

echo "✅ Vault Kubernetes Auth configured successfully!"
echo ""
echo "📚 Usage in ArgoCD manifests:"
echo "   Use placeholders like: <path:secret/data/argocd/myapp#password>"
echo ""
echo "🧪 Test authentication:"
echo "   export VAULT_ADDR=$VAULT_ADDR"
echo "   kubectl exec -n argocd deploy/argocd-repo-server -- env VAULT_ADDR=$VAULT_ADDR argocd-vault-plugin version"
