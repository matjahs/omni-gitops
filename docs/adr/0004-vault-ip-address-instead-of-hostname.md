# ADR-0004: Use IP Address for Vault Server Connection

## Status

Accepted

## Date

2025-09-30

## Context

The HashiCorp Vault server is accessible via hostname `vault.mxe11.nl` which resolves to `172.16.0.4` from external networks. However, when the External Secrets Operator tried to connect using the hostname, it failed with a DNS resolution error:

```
dial tcp: lookup vault.mxe11.nl on 10.96.0.10:53: no such host
```

This occurred because:
- The `.mxe11.nl` domain is a local domain
- Kubernetes cluster DNS (CoreDNS at `10.96.0.10`) doesn't have records for this domain
- The domain is not publicly resolvable
- External DNS resolution (from outside the cluster) works via local DNS server

Two solutions were considered:

### 1. Configure CoreDNS with Custom Forwarding

Add a CoreDNS ConfigMap entry to forward `.mxe11.nl` queries to the local DNS server:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        # ... existing config ...
    }
    mxe11.nl:53 {
        forward . 172.16.0.1  # local DNS server
    }
```

**Pros:**
- More maintainable - can use hostname everywhere
- Works for all services in `.mxe11.nl` domain
- Closer to production-like setup

**Cons:**
- Requires cluster-level DNS configuration changes
- Potential impact on all DNS queries
- Need to maintain custom CoreDNS config
- Adds complexity to cluster setup

### 2. Use Direct IP Address

Configure ClusterSecretStore to use `http://172.16.0.4:8200` instead of hostname:

```yaml
spec:
  provider:
    vault:
      server: "http://172.16.0.4:8200"
```

**Pros:**
- Simple, no cluster changes needed
- Works immediately
- No DNS dependency
- Clear and explicit

**Cons:**
- IP could change (though unlikely for infrastructure service)
- Less readable than hostname
- Doesn't scale if many services need `.mxe11.nl` resolution

## Decision

We will use the **direct IP address** (`http://172.16.0.4:8200`) for Vault server connection in the ClusterSecretStore.

## Consequences

### Positive

- **Immediate solution**: No cluster-wide changes required
- **Reliable**: Bypasses DNS resolution issues
- **Explicit**: Clear what IP is being used
- **No side effects**: Doesn't affect other services

### Negative

- **IP coupling**: Configuration coupled to specific IP
- **Documentation needed**: Must document why IP is used instead of hostname
- **Future consideration**: If more `.mxe11.nl` services are added, may need to revisit DNS solution

### Implementation

ClusterSecretStore configuration:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "http://172.16.0.4:8200"
      path: "secret"
      version: "v2"
      auth:
        tokenSecretRef:
          name: vault-token
          namespace: external-secrets
          key: token
```

### Future Considerations

If the cluster needs to access multiple services in the `.mxe11.nl` domain, we should revisit this decision and implement proper DNS forwarding in CoreDNS.

For now, this is a pragmatic solution that:
- Solves the immediate problem
- Requires no cluster-level changes
- Keeps the scope limited to Vault integration
