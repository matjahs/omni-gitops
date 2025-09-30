# RBAC Configuration Guide

This document outlines the Role-Based Access Control (RBAC) strategy for the cluster.

## Overview

RBAC in Kubernetes controls access to cluster resources based on roles assigned to users, groups, or service accounts.

## Personas and Access Levels

### 1. Cluster Admin
**Who:** Platform team, cluster administrators
**Access:** Full cluster access
**Implementation:** Uses default `cluster-admin` ClusterRole

```bash
# Grant cluster-admin to a user
kubectl create clusterrolebinding admin-user-binding \
  --clusterrole=cluster-admin \
  --user=admin@matjah.dev
```

### 2. Platform Engineer
**Who:** Engineers managing platform services
**Access:**
- Full access to platform namespaces (argocd, cert-manager, traefik-system, etc.)
- Read access to all namespaces
- Can manage CRDs, ClusterIssuers, ClusterSecretStores

### 3. Developer
**Who:** Application developers
**Access:**
- Full access to assigned namespaces
- Can create/update Deployments, Services, ConfigMaps, Secrets
- Cannot modify cluster-level resources
- Cannot access other namespaces

### 4. Read-Only User
**Who:** Auditors, monitoring systems
**Access:**
- Read-only access to all or specific namespaces
- Can view logs
- Cannot modify any resources

## Implementation

### Platform Engineer Role

Create ClusterRole for platform engineers:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: platform-engineer
rules:
# Read access to all resources
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
# Full access to platform CRDs
- apiGroups: ["cert-manager.io"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["external-secrets.io"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["traefik.containo.us", "traefik.io"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["argoproj.io"]
  resources: ["*"]
  verbs: ["*"]
# Can view and manage nodes
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch", "patch"]
```

Bind to platform namespaces:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: platform-engineer-binding
  namespace: argocd
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admin
subjects:
- kind: User
  name: platform-engineer@matjah.dev
  apiGroup: rbac.authorization.k8s.io
```

### Developer Role

Create Role for namespace access:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
  namespace: default
rules:
# Full access to common resources
- apiGroups: ["", "apps", "batch"]
  resources:
    - pods
    - pods/log
    - pods/exec
    - services
    - endpoints
    - configmaps
    - secrets
    - deployments
    - replicasets
    - statefulsets
    - daemonsets
    - jobs
    - cronjobs
  verbs: ["*"]
# Access to ingresses
- apiGroups: ["networking.k8s.io", "traefik.containo.us"]
  resources:
    - ingresses
    - ingressroutes
  verbs: ["*"]
# Can request certificates
- apiGroups: ["cert-manager.io"]
  resources:
    - certificates
    - certificaterequests
  verbs: ["*"]
```

Bind to user:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: developer
subjects:
- kind: User
  name: developer@matjah.dev
  apiGroup: rbac.authorization.k8s.io
```

### Read-Only User

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: readonly-user-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
subjects:
- kind: User
  name: readonly@matjah.dev
  apiGroup: rbac.authorization.k8s.io
```

## Service Account RBAC

### ArgoCD Service Account

ArgoCD needs cluster-wide access to deploy applications:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argocd-application-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: argocd-application-controller
  namespace: argocd
```

**Note:** Already configured by ArgoCD installation.

### External Secrets Operator

External Secrets Operator needs to read ClusterSecretStores and create Secrets:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: external-secrets-operator
rules:
- apiGroups: ["external-secrets.io"]
  resources: ["clustersecretstores", "externalsecrets"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
```

**Note:** Already configured by External Secrets Operator installation.

## Namespace-Specific RBAC

For multi-tenancy, create namespace-specific access:

```bash
# Create namespace
kubectl create namespace customer-acme

# Create service account
kubectl create serviceaccount acme-deployer -n customer-acme

# Bind admin role to namespace
kubectl create rolebinding acme-admin-binding \
  --clusterrole=admin \
  --serviceaccount=customer-acme:acme-deployer \
  -n customer-acme
```

## GitOps-Managed RBAC

Store RBAC configurations in the repository:

```
apps/
└── kube-system/
    └── base/
        ├── rbac/
        │   ├── platform-engineer-clusterrole.yaml
        │   ├── developer-role.yaml
        │   └── readonly-clusterrolebinding.yaml
        └── kustomization.yaml
```

## Authentication Integration

### OIDC Authentication

Configure Kubernetes API server with OIDC (requires cluster configuration):

```yaml
# kube-apiserver flags
--oidc-issuer-url=https://your-idp.com
--oidc-client-id=kubernetes
--oidc-username-claim=email
--oidc-groups-claim=groups
```

### Group-Based RBAC

Map OIDC groups to Kubernetes roles:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: platform-team-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: platform-engineer
subjects:
- kind: Group
  name: platform-team
  apiGroup: rbac.authorization.k8s.io
```

## Best Practices

1. **Principle of Least Privilege**: Grant minimum required permissions
2. **Use Groups**: Assign permissions to groups, not individual users
3. **Namespace Isolation**: Use namespaces for tenant separation
4. **Audit Logs**: Enable audit logging to track access
5. **Regular Reviews**: Periodically review and update RBAC policies
6. **Service Accounts**: Create dedicated service accounts for applications
7. **Avoid cluster-admin**: Limit cluster-admin access to essential personnel

## Verification

Check user permissions:

```bash
# Check what you can do
kubectl auth can-i --list

# Check what a user can do
kubectl auth can-i create deployments --as=developer@matjah.dev -n default

# Check service account permissions
kubectl auth can-i create secrets --as=system:serviceaccount:external-secrets:external-secrets -n default
```

## Troubleshooting

### Permission Denied Errors

1. Check RoleBinding/ClusterRoleBinding:
   ```bash
   kubectl get rolebinding,clusterrolebinding -A | grep username
   ```

2. Verify Role/ClusterRole rules:
   ```bash
   kubectl describe clusterrole platform-engineer
   ```

3. Check effective permissions:
   ```bash
   kubectl auth can-i --list --as=user@example.com
   ```

## Next Steps

- Implement OIDC authentication
- Create group-based RBAC policies
- Set up namespace quotas and limits
- Enable audit logging
- Integrate with organizational directory (AD/LDAP)
