# ADR-0008: Migrate from Traefik IngressRoute to Cilium Gateway API

## Status

Accepted

## Date

2025-10-03

## Context

The cluster was using Traefik as the ingress controller with IngressRoute CRDs for routing HTTP/HTTPS traffic. As the Kubernetes Gateway API matured and gained widespread adoption, we needed to decide whether to continue with Traefik or migrate to the standard Gateway API.

### Current State (Before Migration)

- **Ingress Controller**: Traefik v2.x
- **Routing**: Traefik IngressRoute CRDs
- **TLS**: cert-manager with Traefik integration
- **Load Balancer**: MetalLB providing external IPs
- **Services**: Multiple apps using IngressRoutes (ArgoCD, Grafana, Hubble, etc.)

### Problems with Current Approach

1. **Vendor lock-in**: IngressRoute is Traefik-specific (not portable)
2. **Non-standard**: Not following Kubernetes API standards
3. **Limited portability**: Hard to migrate to other ingress solutions
4. **Less community support**: Gateway API becoming the standard
5. **Missing features**: Newer Gateway API features unavailable

### Options Considered

#### Option 1: Continue with Traefik IngressRoutes
Keep the current Traefik setup unchanged.

**Pros:**
- No migration effort
- Familiar to current team
- Working solution
- Mature and stable

**Cons:**
- Vendor lock-in with Traefik CRDs
- Not using Kubernetes standards
- Harder to migrate in future
- Missing newer Gateway API features
- Community moving to Gateway API

#### Option 2: Migrate to NGINX Ingress with Gateway API
Switch to NGINX Ingress Controller with Gateway API support.

**Pros:**
- Industry standard
- Mature and well-supported
- Gateway API compatible
- Large community

**Cons:**
- Separate ingress controller needed
- Duplicate network policies
- More resource overhead
- Doesn't leverage Cilium

#### Option 3: Adopt Cilium Gateway API
Use Cilium's native Gateway API implementation.

**Pros:**
- **Already running Cilium**: No new component needed
- **Standards-based**: Native Kubernetes Gateway API
- **Network policy integration**: Leverages existing Cilium policies
- **Future-proof**: Gateway API is the Kubernetes standard
- **Better observability**: Integrated with Hubble
- **Resource efficiency**: No separate ingress controller
- **Portability**: Standard API, vendor-neutral routing

**Cons:**
- Migration effort required
- Team needs to learn Gateway API
- Some Traefik-specific features lost
- Requires Cilium 1.13+ for full Gateway API support

#### Option 4: Hybrid Approach
Run both Traefik and Cilium Gateway during migration.

**Pros:**
- Gradual migration
- Rollback possible
- Test before committing

**Cons:**
- Resource overhead
- Complexity during transition
- IP address management conflicts
- Temporary solution only

## Decision

We will **migrate from Traefik IngressRoutes to Cilium Gateway API** (Option 3) using a phased approach:

### Phase 1: Gateway Infrastructure (Completed Oct 3, 2025)

1. Create `cilium-gateway-system` namespace
2. Deploy two Gateway resources:
   - **cilium-web-gateway**: HTTP (port 80) for ACME challenges and redirects
   - **cilium-secure-gateway**: HTTPS (port 443) with wildcard TLS
3. Configure ReferenceGrant for cross-namespace certificate access
4. Enable Gateway API support in cert-manager
5. Verify Gateway provisioning and LoadBalancer IPs

### Phase 2: Service Migration (Completed Oct 3, 2025)

Migrate services from IngressRoute to HTTPRoute:
- Vault UI
- Hubble Relay
- AlertManager
- Flux Controllers (source-controller, notification-controller)
- Ceph Dashboard (before removal)
- Uptime Kuma
- Grafana
- Prometheus
- ArgoCD

### Phase 3: Traefik Removal (Completed)

- Remove Traefik deployment
- Delete IngressRoute CRDs
- Clean up Traefik configurations

## Consequences

### Positive

- **Standards compliance**: Using Kubernetes Gateway API standard
- **Vendor neutrality**: Not locked into Traefik-specific CRDs
- **Future-proof**: Gateway API is the path forward for Kubernetes
- **Resource efficiency**: No separate ingress controller needed
- **Better observability**: Hubble integration for traffic visibility
- **Simpler architecture**: One less component (no Traefik)
- **Network policy integration**: Cilium policies apply to Gateway traffic
- **Portability**: Can migrate to other Gateway API implementations

### Negative

- **Migration effort**: All HTTPRoutes had to be created
- **Learning curve**: Team needs to understand Gateway API concepts
- **Feature gaps**: Some Traefik middleware features not directly available
- **Newer technology**: Gateway API still evolving (though stable)
- **Cilium dependency**: Tied to Cilium CNI (acceptable trade-off)

### Neutral

- **Certificate management**: cert-manager works same way, just different annotations
- **Load balancer**: MetalLB still provides external IPs
- **DNS**: External-DNS works with HTTPRoute (added support)

### Gateway Configuration

**HTTP Gateway (cilium-web-gateway)**:
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: cilium-web-gateway
  namespace: cilium-gateway-system
spec:
  gatewayClassName: cilium
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      hostname: "*.apps.lab.mxe11.nl"
```

**HTTPS Gateway (cilium-secure-gateway)**:
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: cilium-secure-gateway
  namespace: cilium-gateway-system
spec:
  gatewayClassName: cilium
  listeners:
    - name: https
      protocol: HTTPS
      port: 443
      hostname: "*.apps.lab.mxe11.nl"
      tls:
        mode: Terminate
        certificateRefs:
          - kind: Secret
            name: wildcard-tls
```

**Example HTTPRoute**:
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: grafana
  namespace: monitoring
spec:
  parentRefs:
    - name: cilium-secure-gateway
      namespace: cilium-gateway-system
  hostnames:
    - grafana.apps.lab.mxe11.nl
  rules:
    - backendRefs:
        - name: kube-prometheus-stack-grafana
          port: 80
```

### Migration Checklist

- [x] Deploy Gateway resources
- [x] Configure ReferenceGrant for cross-namespace certs
- [x] Enable cert-manager Gateway API support
- [x] Migrate all services to HTTPRoute
- [x] Update external-dns to support HTTPRoute
- [x] Verify all services accessible
- [x] Remove Traefik deployment
- [x] Delete old IngressRoute resources
- [x] Update documentation

### Verification

Test Gateway functionality:
```bash
# Check Gateway status
kubectl get gateway -n cilium-gateway-system

# Check HTTPRoutes
kubectl get httproute -A

# Check LoadBalancer IPs
kubectl get svc -n cilium-gateway-system

# Test HTTPS endpoint
curl -k https://grafana.apps.lab.mxe11.nl
```

## References

- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [Cilium Gateway API Support](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/)
- [cert-manager Gateway API](https://cert-manager.io/docs/usage/gateway/)
- [Migration Plan Document](../gateway-api-migration-plan.md) (removed after completion)
- Commits: dd19d7b (Phase 1), 0166fea (Phase 2), cb4f1be (external-dns support)
