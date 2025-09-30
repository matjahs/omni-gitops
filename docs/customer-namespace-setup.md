# Customer Namespace Setup Guide

This guide outlines how to provision and manage customer/tenant namespaces for ops and application teams.

## Overview

**Model:**
- **Platform Team**: Owns the cluster, manages platform services (ArgoCD, cert-manager, Traefik, etc.)
- **Ops/Apps Teams**: Get dedicated namespaces with resource quotas and RBAC policies

## Namespace Template

Each customer namespace includes:
- Namespace with labels
- ResourceQuota (CPU, memory, storage limits)
- LimitRange (default/min/max resource requests)
- NetworkPolicy (isolation)
- RoleBinding (team access)
- ServiceAccount (for CI/CD)

## Creating a Customer Namespace

### Step 1: Create Namespace Directory

```bash
mkdir -p apps/customer-{name}/base
mkdir -p apps/customer-{name}/overlays/production
```

### Step 2: Base Resources

**apps/customer-{name}/base/namespace.yaml:**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: customer-{name}
  labels:
    managed-by: platform-team
    tenant: customer-{name}
    environment: production
```

**apps/customer-{name}/base/resource-quota.yaml:**
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: customer-quota
  namespace: customer-{name}
spec:
  hard:
    # Compute resources
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    # Storage
    requests.storage: 100Gi
    persistentvolumeclaims: "10"
    # Objects
    pods: "50"
    services: "20"
    configmaps: "50"
    secrets: "50"
    services.loadbalancers: "2"
```

**apps/customer-{name}/base/limit-range.yaml:**
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: customer-limits
  namespace: customer-{name}
spec:
  limits:
  - max:
      cpu: "2"
      memory: 4Gi
    min:
      cpu: "100m"
      memory: 128Mi
    default:
      cpu: "500m"
      memory: 512Mi
    defaultRequest:
      cpu: "250m"
      memory: 256Mi
    type: Container
  - max:
      storage: 20Gi
    min:
      storage: 1Gi
    type: PersistentVolumeClaim
```

**apps/customer-{name}/base/network-policy.yaml:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: customer-{name}
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-traefik
  namespace: customer-{name}
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: traefik-system
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: customer-{name}
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
  - to:
    - podSelector: {}
    ports:
    - protocol: TCP
    - protocol: UDP
```

**apps/customer-{name}/base/serviceaccount.yaml:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: deployer
  namespace: customer-{name}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: deployer-admin
  namespace: customer-{name}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admin
subjects:
- kind: ServiceAccount
  name: deployer
  namespace: customer-{name}
```

**apps/customer-{name}/base/rbac.yaml:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: team-access
  namespace: customer-{name}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admin
subjects:
- kind: Group
  name: customer-{name}-team
  apiGroup: rbac.authorization.k8s.io
# Or use specific users:
- kind: User
  name: user@customer.com
  apiGroup: rbac.authorization.k8s.io
```

**apps/customer-{name}/base/kustomization.yaml:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- namespace.yaml
- resource-quota.yaml
- limit-range.yaml
- network-policy.yaml
- serviceaccount.yaml
- rbac.yaml
```

### Step 3: Create ArgoCD Application

**applications/customer-{name}.yaml:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: customer-{name}
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app.kubernetes.io/managed-by: argocd
    app.kubernetes.io/part-of: customer-namespaces
    tenant: customer-{name}
spec:
  project: default
  source:
    repoURL: https://github.com/matjahs/omni-gitops.git
    targetRevision: HEAD
    path: apps/customer-{name}/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: customer-{name}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## Automated Namespace Provisioning Script

Create a script to automate customer namespace creation:

**scripts/create-customer-namespace.sh:**
```bash
#!/bin/bash

set -e

CUSTOMER_NAME=$1

if [ -z "$CUSTOMER_NAME" ]; then
  echo "Usage: $0 <customer-name>"
  exit 1
fi

NAMESPACE="customer-${CUSTOMER_NAME}"

echo "Creating customer namespace: ${NAMESPACE}"

# Create directory structure
mkdir -p "apps/${NAMESPACE}/base"
mkdir -p "apps/${NAMESPACE}/overlays/production"

# Generate base resources
cat > "apps/${NAMESPACE}/base/namespace.yaml" <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
  labels:
    managed-by: platform-team
    tenant: ${NAMESPACE}
    environment: production
EOF

# Copy template files
cp templates/customer-namespace/resource-quota.yaml "apps/${NAMESPACE}/base/"
cp templates/customer-namespace/limit-range.yaml "apps/${NAMESPACE}/base/"
cp templates/customer-namespace/network-policy.yaml "apps/${NAMESPACE}/base/"
cp templates/customer-namespace/serviceaccount.yaml "apps/${NAMESPACE}/base/"
cp templates/customer-namespace/rbac.yaml "apps/${NAMESPACE}/base/"
cp templates/customer-namespace/kustomization.yaml "apps/${NAMESPACE}/base/"

# Update namespace references
sed -i '' "s/customer-{name}/${NAMESPACE}/g" apps/${NAMESPACE}/base/*.yaml

# Create overlay
cat > "apps/${NAMESPACE}/overlays/production/kustomization.yaml" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base
EOF

# Create ArgoCD application
cat > "applications/${NAMESPACE}.yaml" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${NAMESPACE}
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app.kubernetes.io/managed-by: argocd
    app.kubernetes.io/part-of: customer-namespaces
    tenant: ${NAMESPACE}
spec:
  project: default
  source:
    repoURL: https://github.com/matjahs/omni-gitops.git
    targetRevision: HEAD
    path: apps/${NAMESPACE}/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: ${NAMESPACE}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

echo "Customer namespace ${NAMESPACE} created!"
echo "Files created:"
echo "  - apps/${NAMESPACE}/"
echo "  - applications/${NAMESPACE}.yaml"
echo ""
echo "Next steps:"
echo "1. Review and customize resource quotas in apps/${NAMESPACE}/base/resource-quota.yaml"
echo "2. Update RBAC in apps/${NAMESPACE}/base/rbac.yaml with actual users/groups"
echo "3. Commit and push changes"
echo "4. ArgoCD will automatically deploy the namespace"
```

## Resource Tiers

Define different tiers for different customer sizes:

### Small Tier
- CPU: 2 cores (requests), 4 cores (limits)
- Memory: 4Gi (requests), 8Gi (limits)
- Storage: 50Gi
- Pods: 25

### Medium Tier (Default)
- CPU: 4 cores (requests), 8 cores (limits)
- Memory: 8Gi (requests), 16Gi (limits)
- Storage: 100Gi
- Pods: 50

### Large Tier
- CPU: 8 cores (requests), 16 cores (limits)
- Memory: 16Gi (requests), 32Gi (limits)
- Storage: 500Gi
- Pods: 100

## Monitoring and Alerting

Track namespace resource usage:

```bash
# View resource quota usage
kubectl describe resourcequota -n customer-{name}

# View current resource consumption
kubectl top pods -n customer-{name}
kubectl top nodes

# View namespace events
kubectl get events -n customer-{name} --sort-by='.lastTimestamp'
```

## Self-Service Portal (Optional)

Consider implementing a self-service portal where teams can:
- Request new namespaces
- View resource usage
- Manage RBAC
- View logs and metrics

Tools:
- **Backstage**: Developer portal with Kubernetes plugin
- **Rancher**: Multi-cluster management UI
- **Custom Portal**: Built with K8s API

## Security Best Practices

1. **Network Policies**: Always include default-deny + allow-specific policies
2. **Resource Quotas**: Prevent resource exhaustion
3. **Pod Security Standards**: Enforce restricted pod security
4. **Image Pull Secrets**: Store registry credentials per namespace
5. **Secret Management**: Use External Secrets Operator for Vault integration
6. **Audit Logging**: Enable audit logs for namespace activities

## Troubleshooting

### Quota Exceeded
```bash
kubectl describe resourcequota -n customer-{name}
# Increase quota or optimize resource requests
```

### Network Policy Issues
```bash
# Temporarily disable to test
kubectl delete networkpolicy default-deny-ingress -n customer-{name}
# Check logs for connection errors
kubectl logs -n customer-{name} <pod-name>
```

### RBAC Permission Denied
```bash
# Check user permissions
kubectl auth can-i --list --as=user@customer.com -n customer-{name}
```

## Cleanup

To remove a customer namespace:

```bash
# Delete ArgoCD application (will cascade delete all resources)
kubectl delete application customer-{name} -n argocd

# Or manually delete namespace
kubectl delete namespace customer-{name}

# Remove from Git
rm -rf apps/customer-{name}
rm applications/customer-{name}.yaml
```
