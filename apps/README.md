# Application Manifests

⚠️ **IMPORTANT**: This directory is managed exclusively by **ArgoCD**. Flux CD is prevented from deploying resources from this directory via `.sourceignore` in the repository root.

This directory contains Kubernetes manifests for application workloads, organized by namespace or application.

## Purpose

The `apps/` directory holds the actual Kubernetes resources (Deployments, Services, ConfigMaps, etc.) that ArgoCD deploys to the cluster. These are referenced by ArgoCD Application definitions in the `applications/` directory.

## Structure

```
apps/
├── argocd/              # ArgoCD deployment manifests
├── cert-manager/        # Certificate management resources
├── cilium-gateway/      # Cilium Gateway API configurations
├── external-dns/        # External DNS resources
├── external-secrets/    # External Secrets Operator config
├── external-vault/      # Vault integration
├── kube-system/         # Core system components
├── metallb-system/      # MetalLB load balancer
└── monitoring/          # Prometheus/Grafana stack
```

Each subdirectory typically contains:
- `base/` - Base Kustomize configurations
- `overlays/` - Environment-specific overlays (dev, staging, production)
- Raw manifests for the application

## Flux Protection

This directory is protected from Flux CD deployment through multiple mechanisms:

1. **`.sourceignore`**: Root-level ignore file excludes `apps/` and `apps/**`
2. **`.fluxignore`**: Explicit Flux exclusion marker in this directory
3. **Flux Kustomization path**: The `flux-apps` Kustomization uses `path: ./flux`, limiting scope

These protections prevent conflicts between Flux CD and ArgoCD.

## How It Works

1. **Application Definition** (in `applications/`):
   ```yaml
   # applications/my-app.yaml
   spec:
     source:
       repoURL: https://github.com/your-org/repo.git
       path: apps/my-app  # Points to this directory
   ```

2. **Application Manifests** (in `apps/my-app/`):
   ```
   apps/my-app/
   ├── base/
   │   ├── kustomization.yaml
   │   ├── deployment.yaml
   │   └── service.yaml
   └── overlays/
       └── production/
           ├── kustomization.yaml
           └── patches.yaml
   ```

3. **Deployment**: ArgoCD syncs the manifests from `apps/my-app/` to the cluster

## Adding a New Application

1. Create application directory structure:
   ```bash
   mkdir -p apps/my-app/base
   mkdir -p apps/my-app/overlays/production
   ```

2. Add base manifests in `apps/my-app/base/`

3. Create base kustomization:
   ```yaml
   # apps/my-app/base/kustomization.yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   resources:
     - deployment.yaml
     - service.yaml
   ```

4. Create overlay kustomization:
   ```yaml
   # apps/my-app/overlays/production/kustomization.yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   resources:
     - ../../base
   ```

5. Create ArgoCD Application definition in `applications/my-app.yaml`:
   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: my-app
     namespace: argocd
   spec:
     source:
       repoURL: https://github.com/your-org/repo.git
       targetRevision: HEAD
       path: apps/my-app/overlays/production
     destination:
       server: https://kubernetes.default.svc
       namespace: my-app
   ```

## GitOps Architecture

This repository uses a **hybrid GitOps approach**:

- **Flux CD**: Manages infrastructure and platform services in `flux/`
  - Bootstraps the cluster
  - Deploys ArgoCD itself
  - Manages platform-level resources (CRDs, secrets, networking)

- **ArgoCD**: Manages application workloads from `apps/`
  - Better UI for application visibility
  - Advanced sync options and health checks
  - App-of-Apps pattern for multi-environment deployments

This separation provides:
- Clear ownership boundaries
- Tool optimization (Flux for infra, ArgoCD for apps)
- Independent upgrade paths
- No reconciliation conflicts

## References

- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [Kustomize Documentation](https://kubectl.docs.kubernetes.io/references/kustomize/)
- [App Structure Guide](https://argo-cd.readthedocs.io/en/stable/user-guide/directory/)
