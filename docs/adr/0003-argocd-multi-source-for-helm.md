# ADR-0003: ArgoCD Multi-Source Applications for Helm Charts

## Status

Accepted

## Date

2025-09-30

## Context

We needed to manage Helm-based applications (like Traefik, MetalLB) while keeping their configuration values in our GitOps repository. Two approaches were considered:

### Single-Source with Inline Values

```yaml
spec:
  source:
    repoURL: https://traefik.github.io/charts
    chart: traefik
    targetRevision: "31.1.1"
    helm:
      values: |
        # Inline YAML values here
        ports:
          web:
            port: 80
```

**Pros:**
- Simple, single source
- Everything in one file

**Cons:**
- Values embedded in Application manifest
- Harder to maintain large values files
- Can't reuse values across environments easily
- Difficult to review changes (mixed with Application definition)

### Multi-Source with External Values

```yaml
spec:
  sources:
  - repoURL: https://traefik.github.io/charts
    chart: traefik
    targetRevision: "31.1.1"
    helm:
      valueFiles:
      - $values/apps/traefik-system/overlays/production/values.yaml
  - repoURL: https://github.com/matjahs/omni-gitops.git
    targetRevision: HEAD
    ref: values
```

**Pros:**
- Values live in Git repository alongside other configs
- Follows namespace-first directory structure
- Easy to review and diff values changes
- Clear separation: Application definition vs configuration
- Can have environment-specific values files
- Values follow same GitOps workflow as other resources

**Cons:**
- Slightly more complex setup
- Requires ArgoCD multi-source feature (available since v2.6)

## Decision

We will use **ArgoCD multi-source applications** with Helm values stored in the GitOps repository.

Pattern:
1. Helm chart source references values via `$values/...`
2. Git repository source provides values with `ref: values`
3. Values files live in `apps/{namespace}/overlays/production/values.yaml`
4. Application manifest lives in `applications/{app-name}.yaml`

## Consequences

### Positive

- **GitOps consistency**: Helm values managed like any other config
- **Better reviews**: Values changes appear in PRs separately from app definitions
- **Environment management**: Easy to add staging/dev overlays
- **Structure alignment**: Follows namespace-first pattern
- **Reusability**: Can reference same values from multiple apps if needed
- **Separation of concerns**: Chart version vs configuration are separate

### Negative

- **Initial complexity**: More moving parts than inline values
- **ArgoCD requirement**: Requires relatively recent ArgoCD version
- **Documentation needed**: Contributors need to understand multi-source pattern

### Implementation Notes

Applications migrated to this pattern:
- Traefik (chart v31.1.1)
- MetalLB (chart v0.15.2)

Template for new Helm-based applications:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {app-name}
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app.kubernetes.io/managed-by: argocd
    app.kubernetes.io/part-of: platform
spec:
  project: default
  sources:
  - repoURL: {helm-chart-repo}
    chart: {chart-name}
    targetRevision: "{chart-version}"
    helm:
      valueFiles:
      - $values/apps/{namespace}/overlays/production/values.yaml
  - repoURL: https://github.com/matjahs/omni-gitops.git
    targetRevision: HEAD
    ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: {namespace}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Ordering Matters

The Git repository source with `ref: values` must come **after** the Helm chart source that references `$values/`.
