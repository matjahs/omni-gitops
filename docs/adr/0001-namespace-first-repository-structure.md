# ADR-0001: Namespace-First Repository Structure

## Status

Accepted

## Date

2025-09-30

## Context

We needed to decide on an organizational pattern for the GitOps repository. Three patterns were considered:

### Environment-First Pattern
```
apps/
├── base/
│   ├── cert-manager/
│   └── traefik/
└── overlays/
    └── production/
        ├── cert-manager/
        └── traefik/
```

**Pros:**
- Clear separation of base vs environment-specific configs
- Common in Kustomize examples
- Easy to see what's shared vs customized

**Cons:**
- Namespace information not immediately visible
- Difficult to understand which namespace an app belongs to
- Hard to establish RBAC boundaries by namespace

### App-First Pattern
```
apps/
├── cert-manager/
│   ├── base/
│   └── overlays/production/
└── traefik/
    ├── base/
    └── overlays/production/
```

**Pros:**
- Everything for an app in one place
- Easy to navigate to a specific app

**Cons:**
- App names don't always match namespace names
- Multiple apps in same namespace are separated
- Doesn't reflect Kubernetes namespace organization

### Namespace-First Pattern
```
apps/
├── cert-manager/           # namespace
│   ├── base/
│   └── overlays/production/
└── traefik-system/         # namespace
    ├── base/
    └── overlays/production/
```

**Pros:**
- Intuitive mapping: directory name = namespace name
- Natural RBAC boundaries (can grant access per namespace directory)
- Easy to see all resources in a namespace
- Aligns with Kubernetes' namespace-based organization
- Supports multi-tenancy well

**Cons:**
- Less common in examples/tutorials
- Requires namespace-aware naming

## Decision

We will use the **namespace-first** pattern where:

1. Each directory under `apps/` represents a Kubernetes namespace
2. Directory name matches the target namespace exactly
3. Each namespace directory contains `base/` and `overlays/` subdirectories
4. The namespace is specified in each kustomization.yaml file

## Consequences

### Positive

- **Intuitive navigation**: Finding resources is straightforward - go to the namespace directory
- **RBAC alignment**: Access control can be granted per directory/namespace
- **Multi-tenancy ready**: Easy to add new tenant namespaces
- **Clear ownership**: Teams can own entire namespace directories
- **Kubernetes-aligned**: Structure mirrors actual cluster organization

### Negative

- **Migration required**: Existing apps needed to be restructured
- **Learning curve**: Contributors need to understand namespace-first thinking
- **Documentation needs**: Requires clear documentation for new contributors

### Migration Completed

The following applications were migrated to the new structure:

- `argocd` namespace
- `cert-manager` namespace
- `external-secrets` namespace
- `kube-system` namespace
- `metallb-system` namespace
- `monitoring` namespace
- `rook-ceph` namespace
- `traefik-system` namespace
- `default` namespace (for workload apps)

All ArgoCD Application manifests were updated with new paths.
