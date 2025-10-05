# Flux Directory Structure

⚠️ **IMPORTANT**: This directory is managed exclusively by **Flux CD**. ArgoCD is prevented from deploying resources from this directory via `.argocdignore` in the repository root.

This directory contains the GitOps configuration for the Kubernetes cluster using Flux CD.

## Directory Layout

```
flux/
├── kustomization.yaml       # Root kustomization aggregating all components
├── flux-apps.yaml           # Flux Kustomization for continuous deployment
├── infrastructure/          # Base infrastructure and platform services
│   ├── kustomization.yaml
│   ├── cluster-secret-store.yaml   # External Secrets Operator ClusterSecretStore
│   ├── snapshot-crds.yaml          # Volume snapshot CRDs
│   └── httproutes/                 # Gateway API routes for Flux UI
│       ├── kustomization.yaml
│       ├── notification-controller.yaml
│       └── source-controller.yaml
└── apps/                    # Application deployments
    ├── kustomization.yaml
    ├── external-dns/        # External DNS with RFC2136 provider
    │   ├── kustomization.yaml
    │   ├── helmrepository.yaml
    │   ├── config.yaml
    │   └── helmrelease.yaml
    └── synology-csi/        # Synology CSI storage driver
        ├── kustomization.yaml
        ├── namespace.yaml
        ├── helmrepository.yaml
        ├── externalsecret.yaml
        └── helmrelease.yaml
```

## Design Principles

### 1. Separation of Concerns
- **infrastructure/**: Platform-level resources (CRDs, cluster-wide secrets, observability)
- **apps/**: Application workloads and their dependencies

### 2. Per-Application Organization
Each application is self-contained in its own directory with:
- `helmrepository.yaml`: Helm chart source
- `helmrelease.yaml`: Helm release configuration
- `namespace.yaml`: Namespace definition (if needed)
- `externalsecret.yaml`: External secret references (if needed)
- `config.yaml`: ConfigMaps or other configuration (if needed)
- `kustomization.yaml`: Local kustomization listing all resources

### 3. Layered Kustomizations
The structure uses nested kustomizations for better:
- **Dependency management**: Infrastructure deploys before apps
- **Selective syncing**: Individual apps can be synced independently
- **Resource organization**: Clear boundaries between components

## Adding a New Application

To add a new application:

1. Create a new directory under `flux/apps/`:
   ```bash
   mkdir -p flux/apps/my-app
   ```

2. Add the Helm repository source:
   ```bash
   cat > flux/apps/my-app/helmrepository.yaml <<EOF
   ---
   apiVersion: source.toolkit.fluxcd.io/v1
   kind: HelmRepository
   metadata:
     name: my-app
     namespace: flux-system
   spec:
     interval: 24h
     url: https://charts.example.com
   EOF
   ```

3. Add the Helm release:
   ```bash
   cat > flux/apps/my-app/helmrelease.yaml <<EOF
   ---
   # Note: Use 'helm.toolkit.fluxcd.io/v2beta1' for wider compatibility. 'v2' requires Flux >= 0.32.
   apiVersion: helm.toolkit.fluxcd.io/v2beta1
   kind: HelmRelease
   metadata:
     name: my-app
     namespace: flux-system
   spec:
     interval: 30m
     chart:
       spec:
         chart: my-app
         version: 1.0.0
         sourceRef:
           kind: HelmRepository
           name: my-app
   EOF
   ```

4. Create the kustomization:
   ```bash
   cat > flux/apps/my-app/kustomization.yaml <<EOF
   ---
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   resources:
     - helmrepository.yaml
     - helmrelease.yaml
   EOF
   ```

5. Add the app to `flux/apps/kustomization.yaml`:
   ```yaml
   resources:
     - external-dns
     - synology-csi
     - my-app  # Add this line
   ```

## Validation

Validate the kustomization before committing:

```bash
kubectl kustomize flux/
```

## Hybrid GitOps: Flux + ArgoCD Protection

This repository uses a **hybrid GitOps approach** with clear separation between tools:

- **Flux CD** (this directory): Infrastructure and platform services
- **ArgoCD** (`apps/`, `applications/`): Application workloads

### Flux Protection from ArgoCD

This directory is protected from ArgoCD deployment through multiple mechanisms:

1. **`.argocdignore`**: Root-level ignore file excludes `flux/` and `flux/**`
2. **`.argocd-source.yaml`**: Explicit source exclusion marker in this directory
3. **`.gitkeep`**: Warning file documenting Flux-only management

### ArgoCD Protection from Flux

Conversely, ArgoCD-managed directories are protected from Flux:

1. **`.sourceignore`**: Root-level ignore file excludes `apps/`, `applications/`, `clusters/`
2. **`.fluxignore`**: Explicit Flux exclusion markers in ArgoCD directories
3. **Kustomization path**: The `flux-apps` Kustomization uses `path: ./flux`, limiting scope

### Why This Matters

Running both Flux CD and ArgoCD on the same resources can cause:
- **Reconciliation loops**: Both tools fighting to maintain their desired state
- **Deployment conflicts**: Race conditions during resource updates
- **Audit confusion**: Unclear which tool made which changes
- **Unexpected rollbacks**: One tool undoing the other's changes

By maintaining **two-way protection**, we ensure:
- ✅ Clear ownership boundaries
- ✅ No reconciliation conflicts
- ✅ Predictable deployment behavior
- ✅ Tool-specific optimizations (Flux for infra, ArgoCD for apps)

## References

- [Flux Best Practices](https://fluxcd.io/flux/guides/repository-structure/)
- [Kustomize Documentation](https://kubectl.docs.kubernetes.io/references/kustomize/)
