# ArgoCD Vault Plugin Integration

This guide explains how to use argocd-vault-plugin to inject secrets from HashiCorp Vault into your ArgoCD applications.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│            ArgoCD Repo Server                       │
│  ┌──────────────────────────────────────────────┐  │
│  │  Init Container: Download AVP binary         │  │
│  └──────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────┐  │
│  │  Main Container: argocd-repo-server          │  │
│  │  - Mounts AVP from /custom-tools             │  │
│  │  - Environment: VAULT_ADDR, AVP_TYPE, etc.   │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
                      ↓ Auth via K8s ServiceAccount
┌─────────────────────────────────────────────────────┐
│            HashiCorp Vault                          │
│  - Kubernetes Auth Method                           │
│  - Role: argocd                                     │
│  - Policy: read secret/data/argocd/*               │
│  Address: http://172.16.0.4:8200                   │
└─────────────────────────────────────────────────────┘
```

## Setup

### 1. Configure Vault Authentication

Run the setup script to configure Vault:

```bash
export VAULT_ADDR="http://172.16.0.4:8200"
export VAULT_TOKEN="your-vault-token"
./scripts/setup-vault-argocd-auth.sh
```

This script:
- Enables Kubernetes auth method in Vault
- Creates an `argocd` policy with read access to `secret/data/argocd/*` and `secret/data/applications/*`
- Creates a Kubernetes auth role bound to the `argocd-repo-server` ServiceAccount

### 2. Apply ArgoCD Configuration

The configuration is already in place via kustomize patches:
- `argocd-repo-server-deploy.yaml`: Adds AVP init container and env vars
- `argocd-cm.yaml`: Defines the plugin configurations

Apply changes:
```bash
kubectl apply -k clusters/cluster1
```

### 3. Verify Installation

Check the repo-server pods:
```bash
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-repo-server
```

Verify AVP is available:
```bash
kubectl exec -n argocd deploy/argocd-repo-server -- argocd-vault-plugin version
```

## Usage

### Secret Placeholder Syntax

ArgoCD Vault Plugin uses angle bracket syntax for placeholders:

```yaml
# Format: <path:vault-path#key>
# Example: <path:secret/data/argocd/myapp#database-password>
```

### Available Plugins

Three plugins are configured:

#### 1. **argocd-vault-plugin** (Plain manifests)
For plain Kubernetes YAML files.

```yaml
# Application
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  source:
    plugin:
      name: argocd-vault-plugin
```

#### 2. **argocd-vault-plugin-helm** (Helm charts)
For Helm charts with secret injection.

```yaml
# Application
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  source:
    plugin:
      name: argocd-vault-plugin-helm
      env:
        - name: HELM_ARGS
          value: --values values-prod.yaml
```

#### 3. **argocd-vault-plugin-kustomize** (Kustomize)
For Kustomize overlays with secret injection.

```yaml
# Application
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  source:
    plugin:
      name: argocd-vault-plugin-kustomize
```

## Examples

### Example 1: Plain Secret Manifest

**Vault Secret:**
```bash
vault kv put secret/argocd/database \
  username=admin \
  password=supersecret
```

**Kubernetes Secret (with placeholders):**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: database-credentials
  namespace: myapp
type: Opaque
stringData:
  username: <path:secret/data/argocd/database#username>
  password: <path:secret/data/argocd/database#password>
```

**ArgoCD Application:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/myapp
    targetRevision: main
    path: manifests
    plugin:
      name: argocd-vault-plugin
  destination:
    server: https://kubernetes.default.svc
    namespace: myapp
```

### Example 2: Helm Chart with Values Injection

**Vault Secret:**
```bash
vault kv put secret/applications/postgres \
  adminPassword=p@ssw0rd \
  replicationPassword=repl1c@te
```

**values.yaml (with placeholders):**
```yaml
postgresql:
  auth:
    postgresPassword: <path:secret/data/applications/postgres#adminPassword>
    replicationPassword: <path:secret/data/applications/postgres#replicationPassword>
```

**ArgoCD Application:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: postgres
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.bitnami.com/bitnami
    chart: postgresql
    targetRevision: 12.5.8
    plugin:
      name: argocd-vault-plugin-helm
  destination:
    server: https://kubernetes.default.svc
    namespace: database
```

### Example 3: Kustomize with Secrets

**base/secret.yaml:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-config
type: Opaque
stringData:
  api-key: <path:secret/data/argocd/myapp#api-key>
  db-url: <path:secret/data/argocd/myapp#database-url>
```

**ArgoCD Application:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/myapp
    targetRevision: main
    path: overlays/production
    plugin:
      name: argocd-vault-plugin-kustomize
  destination:
    server: https://kubernetes.default.svc
    namespace: myapp
```

## Vault Secret Organization

Recommended structure:

```
secret/
├── argocd/
│   ├── shared/            # Shared secrets across apps
│   │   ├── docker-registry
│   │   └── tls-certs
│   ├── app1/              # App-specific secrets
│   │   ├── database
│   │   └── api-keys
│   └── app2/
│       └── credentials
└── applications/          # Application-managed secrets
    ├── postgres/
    └── redis/
```

## Troubleshooting

### Check AVP Binary
```bash
kubectl exec -n argocd deploy/argocd-repo-server -- ls -la /usr/local/bin/argocd-vault-plugin
```

### Check Environment Variables
```bash
kubectl exec -n argocd deploy/argocd-repo-server -- env | grep -E 'VAULT|AVP'
```

### Test Vault Authentication
```bash
kubectl exec -n argocd deploy/argocd-repo-server -- sh -c '
  export VAULT_ADDR=http://172.16.0.4:8200
  export AVP_TYPE=vault
  export AVP_AUTH_TYPE=k8s
  export AVP_K8S_ROLE=argocd
  argocd-vault-plugin version
'
```

### View Plugin Logs
```bash
kubectl logs -n argocd deploy/argocd-repo-server -c argocd-repo-server --tail=100
```

### Common Issues

**Issue**: "permission denied" errors
- **Solution**: Check Vault policy and role configuration. Ensure the ServiceAccount token is valid.

**Issue**: "secret not found"
- **Solution**: Verify the secret path in Vault. Remember to use `secret/data/` prefix for KV v2 secrets.

**Issue**: Plugin not found
- **Solution**: Check if the init container successfully downloaded AVP. Check repo-server pod logs.

## Security Best Practices

1. **Use least privilege**: Grant only necessary Vault paths to the argocd policy
2. **Rotate tokens**: ServiceAccount tokens expire after 1 year by default
3. **Audit access**: Enable Vault audit logging
4. **Separate secrets**: Use different Vault paths for dev/staging/prod
5. **Secret rotation**: Plan for secret rotation in applications

## References

- [ArgoCD Vault Plugin Documentation](https://argocd-vault-plugin.readthedocs.io/)
- [Vault Kubernetes Auth](https://developer.hashicorp.com/vault/docs/auth/kubernetes)
- [ArgoCD Config Management Plugins](https://argo-cd.readthedocs.io/en/stable/operator-manual/config-management-plugins/)
