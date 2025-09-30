# Repository Structure Guide

## Overview

This repository follows a **namespace-first** organizational pattern for managing Kubernetes resources with GitOps. Each application is organized by its target namespace, making it intuitive to locate resources and establish RBAC boundaries.

## Directory Structure

```
omni-gitops/
├── apps/                           # All application configurations
│   ├── {namespace}/                # One directory per namespace
│   │   ├── base/                   # Base manifests for the namespace
│   │   │   ├── kustomization.yaml
│   │   │   └── *.yaml              # Resource manifests
│   │   └── overlays/               # Environment-specific customizations
│   │       └── production/
│   │           ├── kustomization.yaml
│   │           ├── values.yaml     # Helm values (if using Helm)
│   │           └── *.yaml          # Patches and additional resources
│   ├── argocd/
│   ├── cert-manager/
│   ├── external-secrets/
│   ├── metallb-system/
│   ├── traefik-system/
│   └── default/                    # For workload apps
├── applications/                   # ArgoCD Application manifests
│   ├── cert-manager.yaml
│   ├── traefik.yaml
│   └── ...
├── clusters/                       # Cluster-specific configurations
│   └── cluster1/
│       ├── kustomization.yaml
│       └── overlays/
└── docs/                           # Documentation

```

## Application Types

### Platform Applications
Infrastructure and platform services that other applications depend on.

**Examples:**
- ArgoCD (gitops/cd)
- Cert-Manager (certificate management)
- External Secrets (secret management)
- Traefik (ingress controller)
- MetalLB (load balancer)
- Rook-Ceph (storage)

**Location:** `apps/{namespace}/`
**Application Manifest:** `applications/{app-name}.yaml`

### Workload Applications
End-user applications and services.

**Examples:**
- Web applications
- APIs
- Databases
- Custom services

**Location:** `apps/default/` or create a dedicated namespace directory
**Application Manifest:** `applications/{app-name}.yaml`

## Adding New Applications

### Decision Tree

```
Is this a platform service?
├─ YES → Create apps/{namespace}/ (use actual namespace name)
└─ NO → Is it part of a multi-tenant setup?
    ├─ YES → Create apps/{tenant-namespace}/
    └─ NO → Use apps/default/
```

### Option 1: Kustomize-Based Application

Use this for applications where you have raw Kubernetes YAML manifests.

#### Step 1: Create Directory Structure

```bash
mkdir -p apps/{namespace}/base
mkdir -p apps/{namespace}/overlays/production
```

#### Step 2: Create Base Manifests

**apps/{namespace}/base/kustomization.yaml:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: {namespace}

resources:
- deployment.yaml
- service.yaml
- ingress.yaml
```

**apps/{namespace}/base/deployment.yaml:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: my-app
        image: my-app:latest
        ports:
        - containerPort: 8080
```

#### Step 3: Create Overlay

**apps/{namespace}/overlays/production/kustomization.yaml:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: {namespace}

resources:
- ../../base

patches:
- path: replica-patch.yaml
  target:
    kind: Deployment
    name: my-app
```

**apps/{namespace}/overlays/production/replica-patch.yaml:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3
```

#### Step 4: Create ArgoCD Application

**applications/my-app.yaml:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app.kubernetes.io/managed-by: argocd
    app.kubernetes.io/part-of: platform  # or 'workload'
spec:
  project: default
  source:
    repoURL: https://github.com/matjahs/omni-gitops.git
    targetRevision: HEAD
    path: apps/{namespace}/overlays/production
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

### Option 2: Helm-Based Application

Use this for applications available as Helm charts.

#### Step 1: Create Directory Structure

```bash
mkdir -p apps/{namespace}/overlays/production
```

#### Step 2: Create Helm Values File

**apps/{namespace}/overlays/production/values.yaml:**
```yaml
# Helm chart values
replicaCount: 3

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: true
  className: traefik
  hosts:
    - host: my-app.lab.mxe11.nl
      paths:
        - path: /
          pathType: Prefix
```

#### Step 3: Create ArgoCD Application (Multi-Source)

**applications/my-app.yaml:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app.kubernetes.io/managed-by: argocd
    app.kubernetes.io/part-of: platform  # or 'workload'
spec:
  project: default
  sources:
  - repoURL: https://charts.example.com
    chart: my-app
    targetRevision: "1.0.0"
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

**Key Points:**
- Use `sources` (plural) for multi-source applications
- The Helm chart source references `$values/...` for the values file
- The Git repo source has `ref: values` to make it available as `$values`

### Option 3: Mixed Approach (Helm + Kustomize)

For Helm charts that need additional Kubernetes resources.

#### Step 1: Create Structure

```bash
mkdir -p apps/{namespace}/base
mkdir -p apps/{namespace}/overlays/production
```

#### Step 2: Base Resources

**apps/{namespace}/base/kustomization.yaml:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: {namespace}

resources:
- configmap.yaml
- secret-external.yaml
```

#### Step 3: Overlay with Helm Values

**apps/{namespace}/overlays/production/kustomization.yaml:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: {namespace}

resources:
- ../../base
```

**apps/{namespace}/overlays/production/values.yaml:**
```yaml
# Helm values
replicaCount: 3
```

#### Step 4: Multi-Source ArgoCD Application

**applications/my-app.yaml:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  sources:
  - repoURL: https://charts.example.com
    chart: my-app
    targetRevision: "1.0.0"
    helm:
      valueFiles:
      - $values/apps/{namespace}/overlays/production/values.yaml
  - repoURL: https://github.com/matjahs/omni-gitops.git
    targetRevision: HEAD
    path: apps/{namespace}/overlays/production
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

## Best Practices

### Naming Conventions

- **Namespace directories:** Use the actual Kubernetes namespace name (e.g., `traefik-system`, `cert-manager`)
- **ArgoCD Applications:** Use descriptive names matching the app (e.g., `traefik`, `cert-manager`)
- **Files:** Use lowercase with hyphens (e.g., `cluster-secret-store.yaml`)

### Secret Management

**Never commit secrets to Git.** Use External Secrets Operator:

1. Store secrets in Vault at `http://172.16.0.4:8200`
2. Create ExternalSecret resource in `apps/{namespace}/base/`
3. Reference ClusterSecretStore: `vault-backend`

**Example ExternalSecret:**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-secret
  namespace: my-namespace
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: my-secret
    creationPolicy: Owner
  data:
  - secretKey: password
    remoteRef:
      key: my-app
      property: password
```

### ArgoCD Sync Waves

Use sync waves for dependencies:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"  # Deploy first
```

**Common waves:**
- `-1`: Namespaces, CRDs
- `0`: Operators, controllers (default)
- `1`: Operator configurations, clusters
- `2`: Applications

### Labels

Standardize labels on ArgoCD Applications:

```yaml
metadata:
  labels:
    app.kubernetes.io/managed-by: argocd
    app.kubernetes.io/part-of: platform  # or 'workload'
    app.kubernetes.io/component: ingress  # optional
```

## Common Patterns

### Pattern: Platform Service

```
apps/traefik-system/
├── base/                    # Usually empty for pure Helm
└── overlays/
    └── production/
        ├── kustomization.yaml
        └── values.yaml      # Helm values

applications/traefik.yaml    # Multi-source application
```

### Pattern: Operator + Configuration

```
apps/external-secrets/
├── base/
│   ├── kustomization.yaml
│   ├── cluster-secret-store.yaml
│   └── vault-token-secret.yaml.example
└── overlays/
    └── production/
        └── kustomization.yaml

applications/external-secrets.yaml         # Helm chart for operator
applications/external-secrets-config.yaml  # Configuration resources
```

### Pattern: Workload Application

```
apps/default/
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
└── overlays/
    └── production/
        ├── kustomization.yaml
        └── replica-patch.yaml

applications/my-workload.yaml
```

## Troubleshooting

### Application Won't Sync

1. Check ArgoCD UI for specific errors
2. Verify paths in Application manifest match directory structure
3. Check kustomization.yaml files are valid
4. Ensure namespace exists or `CreateNamespace=true` is set

### Helm Values Not Applied

1. Verify multi-source setup with `ref: values`
2. Check valueFiles path starts with `$values/`
3. Ensure Git repo source comes after Helm chart source
4. Validate YAML syntax in values.yaml

### Secrets Not Syncing

1. Check ClusterSecretStore status: `kubectl get clustersecretstore vault-backend -o yaml`
2. Verify Vault connectivity from cluster
3. Check External Secrets Operator logs
4. Validate secret path in Vault

## Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kustomize Documentation](https://kustomize.io/)
- [External Secrets Operator](https://external-secrets.io/)
- [Helm Documentation](https://helm.sh/docs/)
