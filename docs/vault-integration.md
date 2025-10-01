# Vault Integration Guide

This guide explains how to integrate HashiCorp Vault (`http://vault.mxe11.nl:8200`) with the cluster using External Secrets Operator.

## Architecture

```
┌─────────────┐      ┌──────────────────────┐      ┌──────────────┐
│   Vault     │◄─────│ External Secrets     │◄─────│   App Pods   │
│  Server     │      │   Operator           │      │              │
└─────────────┘      └──────────────────────┘      └──────────────┘
                              │
                              ▼
                     ┌──────────────────────┐
                     │  K8s Secrets         │
                     │  (auto-generated)    │
                     └──────────────────────┘
```

## Components

1. **External Secrets Operator** - Helm chart deployed via [applications/external-secrets.yaml](../applications/external-secrets.yaml)
2. **ClusterSecretStore** - Connects to Vault at [apps/base/external-secrets/cluster-secret-store.yaml](../apps/base/external-secrets/cluster-secret-store.yaml)
3. **ExternalSecrets** - Define which secrets to sync from Vault

## Setup Steps

### 1. Prepare Vault

Store secrets in Vault KV v2 engine:

```bash
# Enable KV v2 secrets engine (if not already enabled)
vault secrets enable -version=2 -path=secret kv

# Store the Cloudflare API token
vault kv put secret/cloudflare api-token="YOUR_CLOUDFLARE_TOKEN"
```

### 2. Create Vault Token

Create a token with read access to the secrets:

```bash
# Create a policy
vault policy write external-secrets-policy - <<EOF
path "secret/data/*" {
  capabilities = ["read"]
}
EOF

# Create a token
vault token create -policy=external-secrets-policy -ttl=8760h
```

### 3. Configure Kubernetes

Create the vault token secret (not tracked in Git):

```bash
kubectl create secret generic vault-token \
  --namespace=external-secrets \
  --from-literal=token="hvs.YOUR_VAULT_TOKEN_HERE"
```

Or use the template:
```bash
cd apps/base/external-secrets
cp vault-token-secret.yaml.example vault-token-secret.yaml
# Edit the file with your token
vim vault-token-secret.yaml
# Apply manually
kubectl apply -f vault-token-secret.yaml
```

**⚠️ Security Note:** `vault-token-secret.yaml` is gitignored and must be created manually for security.

### 4. Deploy

The External Secrets Operator and configuration will be automatically deployed by ArgoCD:

1. **external-secrets** (wave 0) - Installs the operator
2. **external-secrets-config** (wave 1) - Creates ClusterSecretStore and ExternalSecrets

### 5. Verify

```bash
# Check operator is running
kubectl get pods -n external-secrets

# Check ClusterSecretStore is connected
kubectl get clustersecretstore vault-backend

# Check ExternalSecrets are syncing
kubectl get externalsecrets -A

# Verify secrets were created
kubectl get secret cloudflare-api-token -n argocd
kubectl get secret cloudflare-api-token -n cert-manager
```

## Vault Secret Structure

```
secret/
├── cloudflare/
│   └── api-token       # Cloudflare API token for cert-manager and ArgoCD
```

### Adding More Secrets

To add more secrets from Vault:

1. Store the secret in Vault:
   ```bash
   vault kv put secret/my-app username="admin" password="secret123" # pragma: allowlist secret
   ```

2. Create an ExternalSecret manifest in `apps/base/external-secrets/`:
   ```yaml
   apiVersion: external-secrets.io/v1beta1
   kind: ExternalSecret
   metadata:
     name: my-app-secret
     namespace: my-namespace
   spec:
     refreshInterval: 1h
     secretStoreRef:
       name: vault-backend
       kind: ClusterSecretStore
     target:
       name: my-app-secret
       creationPolicy: Owner
     data:
     - secretKey: username
       remoteRef:
         key: my-app
         property: username
     - secretKey: password
       remoteRef:
         key: my-app
         property: password
   ```

3. Add it to [apps/base/external-secrets/kustomization.yaml](../apps/base/external-secrets/kustomization.yaml)

## Authentication Methods

### Current: Token Authentication
- **Pros:** Simple setup
- **Cons:** Manual token rotation required

### Recommended: Kubernetes Authentication

Configure Vault to authenticate using ServiceAccount tokens:

```bash
# Enable Kubernetes auth
vault auth enable kubernetes

# Configure Kubernetes auth
vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc:443"

# Create a role
vault write auth/kubernetes/role/external-secrets \
    bound_service_account_names=external-secrets \
    bound_service_account_namespaces=external-secrets \
    policies=external-secrets-policy \
    ttl=24h
```

Update ClusterSecretStore to use Kubernetes auth:
```yaml
spec:
  provider:
    vault:
      server: "http://vault.mxe11.nl:8200"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "external-secrets"
          serviceAccountRef:
            name: external-secrets
```

## Troubleshooting

### ExternalSecret shows "SecretSyncedError"
```bash
# Check the ExternalSecret status
kubectl describe externalsecret <name> -n <namespace>

# Check operator logs
kubectl logs -n external-secrets deployment/external-secrets
```

### ClusterSecretStore not ready
```bash
# Check vault connectivity
kubectl run -it --rm debug --image=alpine --restart=Never -- wget -O- http://vault.mxe11.nl:8200/v1/sys/health

# Verify token is valid
vault token lookup <token>
```

### Secret not updating
ExternalSecrets refresh every `refreshInterval` (default 1h). To force refresh:
```bash
kubectl annotate externalsecret <name> -n <namespace> force-sync=$(date +%s)
```

## Migration from Hardcoded Secrets

The following secrets have been migrated to Vault:
- ✅ `cloudflare-api-token` (argocd namespace)
- ✅ `cloudflare-api-token` (cert-manager namespace)

Old hardcoded secret files removed:
- ~~`clusters/cluster1/base/cloudflare-api-token-secret.yaml`~~
- ~~`apps/overlays/production/cert-manager/cloudflare-secret.yaml`~~

## Security Best Practices

1. **Rotate Vault tokens regularly**
2. **Use least-privilege policies** - Only grant read access to required paths
3. **Enable Vault audit logging**
4. **Use Kubernetes auth instead of tokens** for production
5. **Never commit real tokens to Git**
6. **Consider using Vault namespaces** for multi-tenancy
