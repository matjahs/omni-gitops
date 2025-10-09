# ArgoCD Applications

⚠️ **IMPORTANT**: This directory is managed exclusively by **ArgoCD**. Flux CD is prevented from deploying resources from this directory via `.sourceignore` in the repository root.

This directory contains ArgoCD Application definitions that implement the App-of-Apps pattern.

## Purpose

ArgoCD Applications are meta-resources that define:
- What to deploy (source repository and path)
- Where to deploy (target cluster and namespace)
- How to deploy (sync policy, health checks, etc.)

## Structure

```
applications/
├── kustomization.yaml          # Kustomize wrapper for all applications
├── argocd.yaml                 # ArgoCD deployment
├── argocd-config.yaml          # ArgoCD configuration
├── cert-manager.yaml           # Certificate management
├── cilium-gateway.yaml         # Cilium Gateway API
├── external-dns.yaml   # External DNS with RFC2136
├── external-secrets.yaml       # External Secrets Operator
├── external-secrets-config.yaml # ESO configuration
├── hubble-ui.yaml              # Cilium Hubble observability
├── monitoring.yaml             # Prometheus/Grafana stack
└── uptime-kuma.yaml            # Uptime monitoring
```

## Flux Protection

This directory is protected from Flux CD deployment through multiple mechanisms:

1. **`.sourceignore`**: Root-level ignore file excludes `applications/` and `applications/**`
2. **`.fluxignore`**: Explicit Flux exclusion marker in this directory
3. **Flux Kustomization path**: The `flux-apps` Kustomization uses `path: ./flux`, limiting scope

These protections prevent conflicts between Flux CD and ArgoCD.

## Adding a New Application

1. Create a new Application manifest:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo.git
    targetRevision: HEAD
    path: apps/my-app
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app-namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

2. Add the application to [kustomization.yaml](applications/kustomization.yaml):

```yaml
resources:
  - my-app.yaml  # Add this line
```

3. Commit and push - ArgoCD will automatically detect and deploy the new Application

## GitOps Architecture

This repository uses a **hybrid GitOps approach**:

- **Flux CD**: Manages infrastructure and platform services in `flux/`
- **ArgoCD**: Manages application workloads defined in `applications/` and deployed from various source paths

This separation provides:
- Clear ownership boundaries
- Independent tool lifecycles
- Optimized workflows for different use cases

## References

- [ArgoCD Applications](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#applications)
- [App-of-Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/#app-of-apps-pattern)
