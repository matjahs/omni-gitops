# Secrets Management

**⚠️ NEVER commit secrets to Git!**

## Quick Reference

```bash
# Create actual secrets (not committed)
cp apps/cert-manager/cert-manager/overlays/production/cloudflare-secret.yaml.example \
   apps/cert-manager/cert-manager/overlays/production/cloudflare-secret.yaml

# Edit with your actual token
vim apps/cert-manager/cert-manager/overlays/production/cloudflare-secret.yaml

# Apply manually (one-time setup)
kubectl apply -f apps/cert-manager/cert-manager/overlays/production/cloudflare-secret.yaml
```

## What's Protected

The `.gitignore` excludes all files matching:
- `*-secret.yaml`
- `*secret.yaml`

**Exception**: `*.example` files are allowed for documentation.

## Recommended Approach: External Secrets

Use External Secrets Operator instead of committing secrets:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: cloudflare-api-token
  namespace: cert-manager
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: cloudflare-api-token
    creationPolicy: Owner
  data:
  - secretKey: api-token
    remoteRef:
      key: cloudflare
      property: api-token
```

## Pre-Commit Protection

The `detect-secrets` hook scans for:
- API keys
- High-entropy strings (base64)
- Private keys
- Secret keywords

### If Hook Blocks Your Commit

```bash
# Update baseline with new secrets
detect-secrets scan --baseline .secrets.baseline

# Audit and mark false positives
detect-secrets audit .secrets.baseline

# Mark specific line as false positive (select 'n' when prompted)
```

## Emergency: Secret Was Committed

If you accidentally commit a secret:

```bash
# 1. Rotate the secret immediately!
# 2. Remove from git history
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch path/to/secret.yaml" \
  --prune-empty --tag-name-filter cat -- --all

# 3. Force push (if already pushed)
git push origin --force --all

# 4. Contact team to re-clone the repository
```

## Secret Files in This Repo

Example files (safe to commit):
- `*-secret.yaml.example` - Template files with placeholders
- `*secret.yaml.example` - Template files with placeholders

Real secrets (NEVER commit):
- `apps/cert-manager/cert-manager/overlays/production/cloudflare-secret.yaml`
- `clusters/cluster1/base/cloudflare-api-token-secret.yaml`
- Any file matching `*-secret.yaml` or `*secret.yaml`

## See Also

- [External Secrets Documentation](https://external-secrets.io/)
- [Vault Integration](./vault-integration.md)
- [Pre-Commit Setup](./pre-commit-setup.md)
