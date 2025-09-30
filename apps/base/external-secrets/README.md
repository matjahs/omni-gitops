# External Secrets Configuration

This directory contains External Secrets Operator configuration for syncing secrets from Vault.

## Setup

### 1. Create Vault Token Secret (Required)

This secret is **not tracked in Git** for security reasons. Create it manually:

```bash
# Copy the example file
cp vault-token-secret.yaml.example vault-token-secret.yaml

# Edit with your Vault token
vim vault-token-secret.yaml
```

Or create directly with kubectl:

```bash
kubectl create secret generic vault-token \
  --namespace=external-secrets \
  --from-literal=token="YOUR_VAULT_TOKEN_HERE"
```

### 2. Apply the Configuration

If using the local file approach, create a kustomization overlay:

```bash
cd apps/base/external-secrets
cat > kustomization.local.yaml << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- vault-token-secret.yaml
- cluster-secret-store.yaml
- cloudflare-external-secret.yaml
- cloudflare-external-secret-certmanager.yaml
EOF

kustomize build . | kubectl apply -f -
```

### Alternative: Use Sealed Secrets

For a GitOps-friendly approach, encrypt the token with SealedSecrets:

```bash
# Install kubeseal CLI
# Seal the secret
kubectl create secret generic vault-token \
  --namespace=external-secrets \
  --from-literal=token="YOUR_VAULT_TOKEN" \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > vault-token-sealed.yaml

# Add sealed secret to kustomization.yaml
```

## Files

- `vault-token-secret.yaml.example` - Template (committed to Git)
- `vault-token-secret.yaml` - Your actual token (gitignored)
- `cluster-secret-store.yaml` - Vault connection config
- `cloudflare-external-secret*.yaml` - ExternalSecret definitions

## See Also

- [../../docs/vault-integration.md](../../docs/vault-integration.md) - Complete Vault setup guide