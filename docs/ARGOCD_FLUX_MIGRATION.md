# ArgoCD Migration to Flux Management

This document describes the migration of ArgoCD from self-management (`clusters/cluster1`) to Flux CD management (`flux/apps/argocd`).

## Background

Previously, ArgoCD was bootstrapped using:
- Manual `kubectl apply -k clusters/cluster1/`
- ArgoCD self-managing via `applications/argocd.yaml` pointing to `clusters/cluster1`
- Kustomize patches for configuration

Now, ArgoCD is deployed and managed by Flux CD using:
- Helm Chart from https://argoproj.github.io/argo-helm
- Flux HelmRelease in `flux/apps/argocd/`
- Helm values for configuration (instead of Kustomize patches)

## What Changed

### Removed
- ❌ `clusters/cluster1/` directory (entire directory removed)
- ❌ `applications/argocd.yaml` (ArgoCD self-management Application)
- ❌ `bootstrap.sh` dependency on `kubectl apply -k clusters/cluster1/`

### Added
- ✅ `flux/apps/argocd/` - Complete Flux-based ArgoCD deployment
  - `helmrepository.yaml` - Argo Helm chart repository
  - `helmrelease.yaml` - Helm release configuration
  - `config.yaml` - Helm values (migrated from Kustomize patches)
  - `namespace.yaml` - argocd namespace with pod security labels
  - `kustomization.yaml` - Flux kustomization

### Migrated Configuration

All configuration from `clusters/cluster1/overlays/production/` has been translated to Helm values:

| Old (Kustomize) | New (Helm Values) | Description |
|-----------------|-------------------|-------------|
| `argocd-cm.yaml` | `server.config.*` | Server configuration, plugins, resource exclusions |
| `argocd-cmd-params-cm.yaml` | `server.insecure: true` | Server command parameters |
| `argocd-rbac-cm.yaml` | `server.rbacConfig.*` | RBAC policies |
| `argocd-repo-server-patch.json` | `repoServer.*` | Vault plugin init container, env vars |
| `argocd-server-service.yaml` | `server.service.type: ClusterIP` | Service configuration |
| `argocd-notifications-cm.yaml` | `notifications.*` | Notification templates and triggers |
| `rollouts-extension.yaml` | `extensions.*` | Argo Rollouts UI extension |

## Architecture

### Before
```
Bootstrap: kubectl apply -k clusters/cluster1/
    ↓
ArgoCD installed (HA mode, Kustomize-based)
    ↓
ArgoCD self-manages via applications/argocd.yaml
    ↓
ArgoCD deploys apps from applications/
```

### After
```
Bootstrap: Flux installed (flux bootstrap or Talos machine config)
    ↓
Flux deploys infrastructure (flux/infrastructure/)
    ↓
Flux deploys ArgoCD via Helm (flux/apps/argocd/)
    ↓
ArgoCD deploys apps from applications/
```

## Migration Steps (Already Completed)

1. ✅ Created `flux/apps/argocd/` structure
2. ✅ Migrated all configuration to Helm values in `config.yaml`
3. ✅ Added argocd to `flux/apps/kustomization.yaml`
4. ✅ Removed `clusters/cluster1/` directory
5. ✅ Removed `applications/argocd.yaml`
6. ✅ Updated `applications/kustomization.yaml` to remove argocd.yaml reference

## Deployment

### Prerequisites
- Flux CD installed and bootstrapped on the cluster
- `flux/` GitRepository and Kustomization resources deployed

### Deploy ArgoCD via Flux
```bash
# Flux will automatically reconcile and deploy ArgoCD
flux reconcile kustomization flux-apps --with-source

# Wait for ArgoCD to be ready
kubectl wait --for=condition=ready helmrelease/argocd -n argocd --timeout=5m

# Verify deployment
kubectl get pods -n argocd
kubectl get helmrelease argocd -n argocd
```

### Access ArgoCD UI
```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Port forward (or access via ingress at https://cd.apps.lab.mxe11.nl)
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## Key Benefits

1. **Single Source of Truth**: Flux manages all infrastructure, including ArgoCD
2. **Helm-based**: Leverage official ArgoCD Helm chart with upstream updates
3. **No Circular Dependencies**: ArgoCD no longer self-manages
4. **Simplified Bootstrap**: No manual `kubectl apply` needed for ArgoCD
5. **Better Separation**: Clear boundary between Flux (infra) and ArgoCD (apps)

## Rollback (If Needed)

If you need to rollback to the old approach:

1. Restore `clusters/cluster1/` from git history: `git checkout HEAD~1 -- clusters/cluster1/`
2. Restore `applications/argocd.yaml`: `git checkout HEAD~1 -- applications/argocd.yaml`
3. Update `applications/kustomization.yaml` to include `argocd.yaml`
4. Delete Flux-managed ArgoCD: `kubectl delete helmrelease argocd -n argocd`
5. Deploy old way: `kubectl apply -k clusters/cluster1/`

## Troubleshooting

### Flux HelmRelease Failed
```bash
# Check HelmRelease status
kubectl describe helmrelease argocd -n argocd

# Check Helm chart download
kubectl get helmchart -n argocd

# Check values ConfigMap
kubectl get configmap argocd-values -n argocd -o yaml
```

### ArgoCD Not Starting
```bash
# Check pod logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Check repo-server (Vault plugin)
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server

# Verify Redis HA
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-redis-ha
```

### Missing Configuration
```bash
# Verify ConfigMaps
kubectl get cm -n argocd

# Check if Helm values were applied
kubectl get helmrelease argocd -n argocd -o jsonpath='{.spec.valuesFrom}'
```

## References

- [Flux HelmRelease](https://fluxcd.io/flux/components/helm/helmreleases/)
- [ArgoCD Helm Chart](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd)
- [Hybrid GitOps: Flux + ArgoCD](../flux/README.md)
