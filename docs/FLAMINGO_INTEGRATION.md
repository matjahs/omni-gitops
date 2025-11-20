# Flamingo Integration Guide

This document explains how Flux Subsystem for Argo (Flamingo) is integrated into the omni-gitops platform.

## What is Flamingo?

Flamingo (Flux Subsystem for Argo) combines the best of both GitOps tools:
- **ArgoCD**: Excellent UI, RBAC, multi-tenancy, and application management
- **Flux**: Superior GitOps engine with OCI support, drift detection, and source management

Instead of choosing one or the other, Flamingo lets ArgoCD delegate reconciliation to Flux while maintaining its UI and access control.

## Architecture

```
┌─────────────────────────────────────────────────┐
│             ArgoCD UI & API                     │
│  (Application visualization, RBAC, SSO)         │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│         Flamingo Integration Layer              │
│  (Translates ArgoCD Apps ↔ Flux Resources)      │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│           Flux Controllers                      │
│  (source-controller, kustomize-controller,       │
│   helm-controller, notification-controller)     │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│         Kubernetes Cluster                      │
└─────────────────────────────────────────────────┘
```

## Installation

### Current Status

✅ **Flux**: Installed (v2.7.0)
✅ **Flamingo**: Installed (v0.10.2, FSA v2.10.2-fl.23-main-d2c9a8cb)
✅ **ArgoCD Images**: Updated to use Flamingo fork

### Verification

```bash
# Check Flux installation
flux check

# Check Flamingo version
flamingo --version

# List Flamingo applications
flamingo get --all-namespaces

# Check ArgoCD is using Flamingo images
kubectl get deploy -n argocd argocd-repo-server -o jsonpath='{.spec.template.spec.containers[*].image}'
```

## Creating Flamingo Applications

### Method 1: Generate from Existing Flux Resources

If you already have a Flux Kustomization or HelmRelease:

```bash
# Generate ArgoCD Application from Flux Kustomization
flamingo generate-app ks/podinfo -n flux-system

# Generate from HelmRelease
flamingo generate-app hr/external-dns -n external-dns

# Custom app name and namespace
flamingo generate-app \
  --app-name=my-app \
  --app-ns=argocd \
  -n my-namespace \
  ks/my-kustomization
```

### Method 2: Create Flux Kustomization First

1. Create a Flux Kustomization:

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: monitoring
  namespace: flux-system
spec:
  interval: 10m
  path: ./apps/monitoring/kube-prometheus-stack/overlays/production
  prune: true
  sourceRef:
    kind: GitRepository
    name: omni-gitops
  wait: true
  timeout: 5m
```

2. Apply it:

```bash
kubectl apply -f kustomization.yaml
```

3. Generate ArgoCD Application:

```bash
flamingo generate-app ks/monitoring -n flux-system
```

### Method 3: Create Both Together

Create a directory structure like this:

```
apps/my-app/
├── flux-kustomization.yaml    # Flux Kustomization
├── source.yaml                # Optional: GitRepository/OCI source
└── manifests/                 # Your application manifests
    ├── deployment.yaml
    ├── service.yaml
    └── kustomization.yaml
```

Then:

```bash
kubectl apply -f apps/my-app/flux-kustomization.yaml
flamingo generate-app ks/my-app -n flux-system
```

## Migration Strategy

### Phase 1: Parallel Operation (CURRENT)

- Keep existing ArgoCD Applications as-is
- Flux runs alongside for selected workloads
- Both tools coexist without conflict
- ArgoCD manages its own installation + core platform apps
- Flux manages external-dns (via HelmRelease)

### Phase 2: Gradual Migration (RECOMMENDED)

1. **Start with new applications**: Create new apps using Flamingo pattern
2. **Migrate non-critical apps**: Convert monitoring, observability tools
3. **Migrate remaining apps**: Core platform components
4. **Keep ArgoCD self-management**: ArgoCD continues to manage its own deployment

### Phase 3: Full Integration (FUTURE)

- All applications use Flux backend
- ArgoCD provides UI and RBAC only
- Unified GitOps workflow

## Repository Structure

### Recommended Layout

```
omni-gitops/
├── applications/              # ArgoCD Application manifests
│   ├── argocd.yaml           # ArgoCD self-management
│   ├── monitoring.yaml        # Points to Flux Kustomization
│   └── external-dns.yaml      # Points to HelmRelease
│
├── flux/                      # Flux-managed resources
│   ├── sources/              # GitRepository, HelmRepository, OCI
│   │   ├── omni-gitops.yaml
│   │   └── external-dns.yaml
│   ├── releases/             # HelmReleases
│   │   └── external-dns.yaml
│   ├── kustomizations/       # Kustomizations
│   │   ├── monitoring.yaml
│   │   └── cilium-gateway.yaml
│   └── configs/              # ConfigMaps, Secrets
│       └── cluster-secret-store.yaml
│
├── apps/                      # Actual application manifests
│   ├── monitoring/
│   │   └── kube-prometheus-stack/
│   │       ├── base/
│   │       └── overlays/production/
│   └── cilium-gateway/
│       ├── gateway/
│       └── dashboard/
│
└── clusters/                  # Cluster-specific configs
    └── cluster1/
        ├── base/
        └── overlays/production/
```

### Current Issues to Clean Up

❌ **Duplicate external-dns**: Managed by both ArgoCD Application AND Flux HelmRelease
❌ **Broken Flux Kustomizations**: flux-apps pointing to non-existent GitRepository
❌ **Mixed patterns**: Some apps in /flux, some in /applications

## Cleaning Up the Repository

### Step 1: Fix Flux GitRepository

Create the missing GitRepository:

```bash
flux create source git omni-gitops \
  --url=ssh://git@github.com/matjahs/omni-gitops \
  --branch=main \
  --export > flux/sources/omni-gitops.yaml
```

### Step 2: Decide on external-dns

Choose ONE of:
- **Option A (Recommended)**: Keep Flux HelmRelease, remove ArgoCD Application
- **Option B**: Keep ArgoCD Application, remove Flux HelmRelease

### Step 3: Migrate HTTPRoutes

The newly created HTTPRoutes (alertmanager, kube-state-metrics, flux controllers, vault, hubble-relay) should be:
- Moved out of `/flux/httproutes/`
- Placed in their respective app directories
- Referenced by Flux Kustomizations
- Visualized in ArgoCD via Flamingo

### Step 4: Consolidate Patterns

All new applications should follow this pattern:

1. Create manifests in `/apps/<app-name>/`
2. Create Flux Kustomization in `/flux/kustomizations/<app-name>.yaml`
3. (Optional) Generate ArgoCD Application with `flamingo generate-app`
4. ArgoCD shows status, Flux performs reconciliation

## Benefits of Flamingo

### Compared to ArgoCD Alone

✅ **OCI Registry support**: Pull Helm charts and Kustomizations from OCI
✅ **Better drift detection**: Flux's three-way merge vs ArgoCD's two-way
✅ **Multi-tenancy**: Native Flux support for tenant isolation
✅ **Source flexibility**: Git, Helm repos, OCI, S3 buckets
✅ **Notification webhooks**: Flux's advanced notification system

### Compared to Flux Alone

✅ **Visual UI**: ArgoCD's beautiful dashboard
✅ **RBAC**: Fine-grained access control
✅ **SSO Integration**: OIDC, LDAP, SAML support
✅ **Application abstraction**: Logical grouping of resources
✅ **Rollback UI**: Easy rollback from web interface

## Troubleshooting

### Application Not Appearing in ArgoCD

```bash
# Check if Flux resource exists
kubectl get kustomization -n flux-system
kubectl get helmrelease -n flux-system

# Generate ArgoCD Application
flamingo generate-app ks/<name> -n flux-system
```

### Flux Kustomization Failing

```bash
# Check Kustomization status
flux get kustomizations

# Get detailed errors
kubectl describe kustomization <name> -n flux-system

# Check source
flux get sources git
```

### ArgoCD Shows Out of Sync

This is normal with Flamingo! ArgoCD delegates to Flux, so:
- **Status**: Check Flux Kustomization/HelmRelease status
- **Sync**: Trigger via Flux, not ArgoCD
- **Logs**: Check Flux controller logs

```bash
# Check Flux status
kubectl get kustomization <name> -n flux-system -o yaml

# Force reconciliation
flux reconcile kustomization <name>
```

## CLI Commands Reference

### Flamingo CLI

```bash
# Install/Upgrade Flamingo
flamingo install --version=v2.10.2

# List applications
flamingo get --all-namespaces

# Generate application from Flux resource
flamingo generate-app ks/<name> -n <namespace>
flamingo generate-app hr/<name> -n <namespace>

# Port forward to ArgoCD
flamingo port-fwd

# Show initial password
flamingo show-init-password
```

### Flux CLI

```bash
# Check installation
flux check

# Get all resources
flux get all

# Reconcile immediately
flux reconcile kustomization <name>
flux reconcile helmrelease <name>

# Suspend/Resume
flux suspend kustomization <name>
flux resume kustomization <name>
```

## Next Steps

1. ✅ Flamingo installed and integrated
2. ⏳ Create GitRepository for omni-gitops
3. ⏳ Resolve external-dns duplication
4. ⏳ Move HTTPRoutes to proper locations
5. ⏳ Create Flux Kustomizations for all apps
6. ⏳ Generate ArgoCD Applications via Flamingo
7. ⏳ Clean up repository structure
8. ⏳ Update documentation

## References

- [Flamingo Documentation](https://flux-subsystem-argo.github.io/website/)
- [Flux Documentation](https://fluxcd.io/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Gateway API HTTPRoutes](../apps/cilium-gateway/HTTPROUTES.md)
