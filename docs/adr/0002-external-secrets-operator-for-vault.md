# ADR-0002: External Secrets Operator for Vault Integration

## Status

Accepted

## Date

2025-09-30

## Context

We needed to integrate with an existing HashiCorp Vault server (`http://vault.mxe11.nl:8200` / `http://172.16.0.4:8200`) to manage secrets in Kubernetes without storing them in Git.

Three main options were considered:

### 1. External Secrets Operator (ESO)

**How it works:**
- Kubernetes operator that syncs secrets from external stores to native K8s Secrets
- Uses ClusterSecretStore CRD to define Vault connection
- Uses ExternalSecret CRD to define which secrets to sync

**Pros:**
- Creates native Kubernetes Secrets - works with any application
- Declarative - fully GitOps compatible
- Multi-backend support (Vault, AWS, Azure, GCP, etc.)
- Automatic secret refresh
- Can sync to multiple namespaces from single definition

**Cons:**
- Secrets end up as K8s Secrets (still base64, not encrypted at rest by default)
- Requires operator to be running

### 2. Vault Secrets Operator (VSO)

**How it works:**
- Official HashiCorp operator
- Uses VaultAuth and VaultStaticSecret CRDs
- Similar pattern to ESO but Vault-specific

**Pros:**
- Official HashiCorp solution
- Deep Vault integration

**Cons:**
- Vault-specific - harder to migrate to another secret backend
- Relatively newer/less mature
- More complex authentication setup

### 3. ArgoCD Vault Plugin (AVP)

**How it works:**
- ArgoCD plugin that fetches secrets during sync
- Secrets injected into manifests at deployment time

**Pros:**
- Secrets never stored in cluster
- Tighter ArgoCD integration

**Cons:**
- Only works with ArgoCD - can't use kubectl
- Requires custom ArgoCD configuration
- Secrets fetched on every sync (no caching)
- Can't use with non-ArgoCD tools

## Decision

We will use **External Secrets Operator (ESO)** for Vault integration.

The implementation includes:

1. Deploy ESO via Helm chart (version 0.11.0)
2. Create ClusterSecretStore pointing to Vault
3. Create ExternalSecret resources for each secret needed
4. Store Vault token as Kubernetes Secret (not in Git)

## Consequences

### Positive

- **GitOps-friendly**: ExternalSecret definitions live in Git
- **Portable**: Easy to migrate to different secret backend if needed
- **Native integration**: Apps use standard Kubernetes Secrets
- **Flexible**: Can sync secrets to multiple namespaces
- **Automatic refresh**: Secrets update automatically based on refreshInterval

### Negative

- **K8s Secret limitations**: Secrets still stored as base64 in etcd (mitigated by cluster-level encryption at rest)
- **Operator dependency**: If ESO is down, secret updates won't sync (existing secrets continue to work)
- **Initial token management**: Vault token must be manually created in cluster

### Security Considerations

- Vault token stored as K8s Secret in `external-secrets` namespace
- Token should have minimal required permissions
- ExternalSecret manifests in Git contain only references, not actual secrets
- ClusterSecretStore provides cluster-wide access (namespace-specific SecretStore also available)

### Implementation Notes

- Vault server accessible at `http://172.16.0.4:8200` (IP used due to DNS limitations)
- Vault KV v2 secret engine at path `secret/`
- ClusterSecretStore named `vault-backend`
- Secrets refresh every 1 hour by default
