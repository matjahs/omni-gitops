# Gateway API Migration Plan: Traefik → Cilium Gateway API

## Executive Summary

This document outlines a comprehensive plan to migrate all ingress routing from Traefik IngressRoutes to Cilium's native Gateway API implementation.

### Why Migrate?

**Benefits of Cilium Gateway API:**
- ✅ **Native CNI integration**: Traffic handling directly in the datapath (eBPF)
- ✅ **Better performance**: Eliminates extra proxy hop
- ✅ **Unified stack**: One component (Cilium) vs two (Traefik + Cilium)
- ✅ **Modern standard**: Gateway API is the future of Kubernetes ingress
- ✅ **Simplified operations**: Fewer moving parts, less complexity
- ✅ **Network policy integration**: L7 policies at the Gateway level
- ✅ **Reduced resource usage**: No separate ingress controller pods

**Tradeoffs:**
- ⚠️ **Less mature**: Gateway API is newer than Ingress/IngressRoute
- ⚠️ **Fewer middlewares**: Traefik has extensive middleware ecosystem
- ⚠️ **Migration effort**: All ingresses need to be rewritten

## Current State Analysis

### Existing Ingress Controllers

| Component | Type | Status |
|-----------|------|--------|
| **Traefik** | IngressRoute (CRD) | Primary ingress controller |
| **Cilium** | Gateway API | Partially configured (1 HTTPRoute exists) |

### Current Ingress Inventory

| Service | Type | Hostname | Namespace | TLS Secret | Features |
|---------|------|----------|-----------|------------|----------|
| **ArgoCD** | TraefikIngressRoute | `cd.apps.lab.mxe11.nl` | `argocd` | `argocd-tls-cert` | HTTP→HTTPS redirect, external-dns |
| **Grafana** | TraefikIngressRoute | `grafana.apps.lab.mxe11.nl` | `monitoring` | `grafana-tls-cert` | TLS, external-dns |
| **Prometheus** | TraefikIngressRoute | `prometheus.apps.lab.mxe11.nl` | `monitoring` | `prometheus-tls-cert` | TLS, external-dns |
| **Hubble UI** | TraefikIngressRoute | `hubble.apps.lab.mxe11.nl` | `kube-system` | `hubble-ui-tls` | TLS, external-dns |
| **Ceph Dashboard** | TraefikIngressRoute | `ceph.apps.lab.mxe11.nl` | `rook-ceph` | `ceph-dashboard-tls` | TLS, external-dns |
| **Uptime Kuma** | Gateway API HTTPRoute | `uptime.apps.lab.mxe11.nl` | `monitoring` | (via Gateway) | Already using Gateway API! ✅ |
| **Whoami** | Gateway API HTTPRoute | `whoami.docker.localhost` | `default` | None | Test service |

### External Dependencies

- **MetalLB**: Provides LoadBalancer IPs for both Traefik and Cilium Gateways
- **cert-manager**: Issues TLS certificates (currently for Traefik)
- **external-dns**: Creates DNS records (supports both Traefik and Gateway API)
- **Cloudflare**: DNS provider via external-dns

### Current Cilium Gateway API Configuration

**Enabled**: Yes (see [applications/cilium.yaml:89-92](../applications/cilium.yaml#L89-92))

```yaml
gatewayAPI:
  enabled: true
  enableAlpn: true
  enableAppProtocol: true
```

**Status**: Already partially implemented:
- `uptime-kuma` is using HTTPRoute → `traefik-gateway` (mixed mode)
- No Cilium Gateway defined yet (only Traefik gateway exists)

## Target Architecture

### Gateway API Resources

```
┌─────────────────────────────────────────────────┐
│           GatewayClass: cilium                  │
│       (Managed by Cilium control plane)         │
└─────────────────────────────────────────────────┘
                      │
        ┌─────────────┼─────────────┐
        │                           │
   ┌────▼──────────┐        ┌───────▼──────────┐
   │ Gateway: web  │        │ Gateway: secure  │
   │ HTTP (80)     │        │ HTTPS (443)      │
   │ Redirect→HTTPS│        │ TLS Termination  │
   └───────────────┘        └──────────────────┘
                                     │
        ┌────────────────────────────┼────────────────────────┐
        │                            │                        │
   ┌────▼────┐              ┌────────▼─────┐        ┌────────▼─────┐
   │HTTPRoute│              │  HTTPRoute   │        │  HTTPRoute   │
   │ArgoCD   │              │  Grafana     │        │  Prometheus  │
   └─────────┘              └──────────────┘        └──────────────┘
```

### Gateway Configuration Design

**Two Gateway Strategy:**

1. **`cilium-web-gateway`**: HTTP-only, port 80
   - Handles ACME challenges
   - Redirects all HTTP → HTTPS

2. **`cilium-secure-gateway`**: HTTPS-only, port 443
   - TLS termination
   - Routes to backend services
   - Supports multiple hostnames via HTTPRoutes

**Alternative Single Gateway Strategy:**

One `cilium-gateway` with two listeners (HTTP:80, HTTPS:443) - simpler but less explicit.

### TLS Certificate Strategy

**Option 1: Gateway-Attached Certificates (Recommended)**
- Annotate Gateway with `cert-manager.io/cluster-issuer`
- cert-manager creates TLS secret automatically
- Gateway references the secret
- **Pros**: Centralized certificate management, fewer secrets
- **Cons**: All routes on a Gateway share certificates (requires wildcard or SAN)

**Option 2: Per-Service Certificates**
- HTTPRoute references TLS via ReferenceGrant if needed
- Each service has its own certificate
- **Pros**: Fine-grained control, separate lifecycles
- **Cons**: More complexity, more secrets to manage

**Recommended**: Use wildcard certificate `*.apps.lab.mxe11.nl` attached to Gateway, managed by cert-manager with ClusterIssuer.

### External-DNS Integration

external-dns supports Gateway API resources via annotations:

```yaml
annotations:
  external-dns.alpha.kubernetes.io/hostname: grafana.apps.lab.mxe11.nl
  external-dns.alpha.kubernetes.io/target: cilium-gateway.lab.mxe11.nl
```

Applied to either:
- Gateway (creates DNS for Gateway's LoadBalancer IP)
- HTTPRoute (creates DNS pointing to Gateway)

**Recommended**: Annotate Gateway with target DNS, annotate HTTPRoutes with service-specific hostnames.

## Migration Steps

### Phase 0: Preparation (Week 1)

**Tasks:**

1. **Deploy Cilium GatewayClass**
   ```bash
   # Verify GatewayClass exists
   kubectl get gatewayclass
   # Should show: cilium (from Cilium installation)
   ```

2. **Enable cert-manager Gateway API support**
   ```yaml
   # Add to cert-manager values
   config:
     enableGatewayAPI: true
   ```

3. **Test Gateway in non-production namespace**
   - Create test Gateway in `default` namespace
   - Create test HTTPRoute
   - Verify TLS provisioning
   - Validate external-dns integration

4. **Document rollback procedure**
   - Keep Traefik running in parallel
   - Document DNS cutover process

**Deliverables:**
- [ ] GatewayClass verified
- [ ] cert-manager configured for Gateway API
- [ ] Test Gateway working with TLS
- [ ] Rollback procedure documented

### Phase 1: Create Shared Gateway (Week 2)

**Tasks:**

1. **Create Cilium Gateways** in `cilium-gateway-system` namespace

   File: `apps/cilium-gateway/base/gateways.yaml`

   ```yaml
   ---
   apiVersion: v1
   kind: Namespace
   metadata:
     name: cilium-gateway-system
   ---
   apiVersion: gateway.networking.k8s.io/v1
   kind: Gateway
   metadata:
     name: cilium-web-gateway
     namespace: cilium-gateway-system
     annotations:
       external-dns.alpha.kubernetes.io/target: traefik.lab.mxe11.nl  # Initially points to Traefik IP
   spec:
     gatewayClassName: cilium
     listeners:
       - name: http
         protocol: HTTP
         port: 80
         allowedRoutes:
           namespaces:
             from: All  # Allow HTTPRoutes from any namespace
   ---
   apiVersion: gateway.networking.k8s.io/v1
   kind: Gateway
   metadata:
     name: cilium-secure-gateway
     namespace: cilium-gateway-system
     annotations:
       cert-manager.io/cluster-issuer: letsencrypt-prod  # or cloudflare-clusterissuer
       external-dns.alpha.kubernetes.io/hostname: "*.apps.lab.mxe11.nl"
       external-dns.alpha.kubernetes.io/target: traefik.lab.mxe11.nl
   spec:
     gatewayClassName: cilium
     listeners:
       - name: https
         protocol: HTTPS
         port: 443
         hostname: "*.apps.lab.mxe11.nl"
         allowedRoutes:
           namespaces:
             from: All
         tls:
           mode: Terminate
           certificateRefs:
             - kind: Secret
               name: wildcard-apps-tls  # Created by cert-manager
   ```

2. **Wait for Gateway provisioning**
   ```bash
   kubectl wait --for=condition=Programmed gateway/cilium-secure-gateway -n cilium-gateway-system
   ```

3. **Verify LoadBalancer IP assigned**
   ```bash
   kubectl get svc -n cilium-gateway-system
   ```

4. **Update MetalLB IP pool** (if needed)
   - Ensure sufficient IPs available
   - Reserve IP for Cilium Gateway

**Deliverables:**
- [ ] cilium-gateway-system namespace created
- [ ] Both Gateways deployed and Programmed
- [ ] LoadBalancer IP assigned
- [ ] TLS certificate issued by cert-manager
- [ ] DNS records created by external-dns

### Phase 2: Migrate Services One-by-One (Weeks 3-4)

Migrate in order of criticality (least critical first):

#### 2.1 Migrate Whoami (Already done! ✅)

Update to point to Cilium Gateway:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: whoami
  namespace: default
spec:
  parentRefs:
    - name: cilium-secure-gateway
      namespace: cilium-gateway-system
  hostnames:
    - "whoami.apps.lab.mxe11.nl"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: whoami
          port: 80
```

#### 2.2 Migrate Uptime Kuma

File: `apps/monitoring/uptime-kuma/overlays/production/httproute.yaml`

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: uptime-kuma-route
  namespace: monitoring
  annotations:
    external-dns.alpha.kubernetes.io/hostname: uptime.apps.lab.mxe11.nl
spec:
  parentRefs:
    - name: cilium-secure-gateway
      namespace: cilium-gateway-system
  hostnames:
    - uptime.apps.lab.mxe11.nl
  rules:
    - backendRefs:
        - name: uptime-kuma
          port: 3001
```

**Test**: Visit `https://uptime.apps.lab.mxe11.nl` and verify functionality.

#### 2.3 Migrate Hubble UI

File: `apps/kube-system/hubble-ui/base/hubble-ui-httproute.yaml`

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: hubble-ui
  namespace: kube-system
  annotations:
    external-dns.alpha.kubernetes.io/hostname: hubble.apps.lab.mxe11.nl
spec:
  parentRefs:
    - name: cilium-secure-gateway
      namespace: cilium-gateway-system
  hostnames:
    - hubble.apps.lab.mxe11.nl
  rules:
    - backendRefs:
        - name: hubble-ui
          port: 80
```

**Delete old**: `apps/kube-system/hubble-ui/base/hubble-ui-ingressroute.yaml`

#### 2.4 Migrate Ceph Dashboard

File: `apps/rook-ceph/dashboard/base/dashboard-httproute.yaml`

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: ceph-dashboard
  namespace: rook-ceph
  annotations:
    external-dns.alpha.kubernetes.io/hostname: ceph.apps.lab.mxe11.nl
spec:
  parentRefs:
    - name: cilium-secure-gateway
      namespace: cilium-gateway-system
  hostnames:
    - ceph.apps.lab.mxe11.nl
  rules:
    - backendRefs:
        - name: rook-ceph-mgr-dashboard
          port: 7000
```

#### 2.5 Migrate Grafana

File: `apps/monitoring/kube-prometheus-stack/overlays/production/grafana-httproute.yaml`

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: grafana
  namespace: monitoring
  annotations:
    external-dns.alpha.kubernetes.io/hostname: grafana.apps.lab.mxe11.nl
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

#### 2.6 Migrate Prometheus

File: `apps/monitoring/kube-prometheus-stack/overlays/production/prometheus-httproute.yaml`

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: prometheus
  namespace: monitoring
  annotations:
    external-dns.alpha.kubernetes.io/hostname: prometheus.apps.lab.mxe11.nl
spec:
  parentRefs:
    - name: cilium-secure-gateway
      namespace: cilium-gateway-system
  hostnames:
    - prometheus.apps.lab.mxe11.nl
  rules:
    - backendRefs:
        - name: kube-prometheus-stack-prometheus
          port: 9090
```

#### 2.7 Migrate ArgoCD (Most Critical - Do Last!)

File: `apps/argocd/argocd/overlays/production/argocd-httproute.yaml`

```yaml
---
# HTTP Gateway for ACME challenges and redirect
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: argocd-http
  namespace: argocd
spec:
  parentRefs:
    - name: cilium-web-gateway
      namespace: cilium-gateway-system
  hostnames:
    - cd.apps.lab.mxe11.nl
  rules:
    # ACME challenge path
    - matches:
        - path:
            type: PathPrefix
            value: /.well-known/acme-challenge/
      backendRefs:
        - name: argocd-server
          port: 80
    # Redirect all other HTTP to HTTPS
    - filters:
        - type: RequestRedirect
          requestRedirect:
            scheme: https
            statusCode: 301
---
# HTTPS Gateway
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: argocd-https
  namespace: argocd
  annotations:
    external-dns.alpha.kubernetes.io/hostname: cd.apps.lab.mxe11.nl
spec:
  parentRefs:
    - name: cilium-secure-gateway
      namespace: cilium-gateway-system
  hostnames:
    - cd.apps.lab.mxe11.nl
  rules:
    - backendRefs:
        - name: argocd-server
          port: 80  # ArgoCD server runs on HTTP internally
```

**Special considerations for ArgoCD:**
- Test extensively before cutover
- Have rollback plan ready
- May need to configure ArgoCD for running behind proxy:
  ```yaml
  server:
    extraArgs:
      - --insecure  # ArgoCD handles HTTP, Gateway handles HTTPS
  ```

**Deliverables per migration:**
- [ ] HTTPRoute created
- [ ] Service tested via new route
- [ ] Old IngressRoute deleted (after verification)
- [ ] DNS updated (if needed)

### Phase 3: Decommission Traefik (Week 5)

Only after ALL services are migrated:

1. **Monitor for 1 week** to ensure stability
2. **Update external-dns Gateway target** to point to Cilium Gateway LoadBalancer IP
3. **Delete Traefik resources**:
   ```bash
   kubectl delete namespace traefik-system
   kubectl delete application traefik -n argocd
   ```
4. **Release MetalLB IP** previously used by Traefik
5. **Update documentation**

**Deliverables:**
- [ ] All services verified on Cilium Gateway for 7 days
- [ ] Traefik namespace deleted
- [ ] MetalLB IP released
- [ ] Documentation updated

## Risk Mitigation

### Rollback Strategy

**If migration fails at any step:**

1. **HTTPRoute-level rollback**:
   - Delete HTTPRoute
   - Re-apply old IngressRoute
   - DNS will automatically update (external-dns)

2. **Gateway-level rollback**:
   - Delete Cilium Gateway
   - Keep Traefik running
   - All IngressRoutes continue working

3. **Complete rollback**:
   ```bash
   # Keep Traefik, remove all HTTPRoutes
   kubectl delete httproutes --all --all-namespaces
   kubectl delete gateway cilium-secure-gateway -n cilium-gateway-system
   ```

### Parallel Running

**Safe migration approach:**

- Run Traefik and Cilium Gateway in parallel
- Migrate one service at a time
- Each service accessible via both ingress controllers during transition
- Use DNS to cut over traffic (change `target` in external-dns annotation)

### Testing Strategy

**Per-service checklist:**

- [ ] HTTPS works (`curl https://service.apps.lab.mxe11.nl`)
- [ ] TLS certificate valid
- [ ] DNS resolves correctly
- [ ] Application functions normally
- [ ] WebSocket connections work (if applicable)
- [ ] Large file uploads/downloads work
- [ ] Performance acceptable (measure latency)

## Advanced Features

### HTTP→HTTPS Redirect

Gateway API uses `RequestRedirect` filter:

```yaml
rules:
  - filters:
      - type: RequestRedirect
        requestRedirect:
          scheme: https
          statusCode: 301
```

### Path Rewrites

```yaml
rules:
  - matches:
      - path:
          type: PathPrefix
          value: /old-path
    filters:
      - type: URLRewrite
        urlRewrite:
          path:
            type: ReplacePrefixMatch
            replacePrefixMatch: /new-path
```

### Request Headers

```yaml
filters:
  - type: RequestHeaderModifier
    requestHeaderModifier:
      add:
        - name: X-Custom-Header
          value: custom-value
      remove:
        - X-Unwanted-Header
```

### Traffic Splitting (Canary)

```yaml
rules:
  - backendRefs:
      - name: service-v1
        port: 80
        weight: 90
      - name: service-v2
        port: 80
        weight: 10
```

## Limitations & Workarounds

### Current Cilium Gateway API Limitations

1. **No built-in rate limiting**: Use Network Policies or Cilium L7 policies
2. **Limited middleware ecosystem**: Fewer features than Traefik middlewares
3. **No strip-prefix yet**: Workaround: Use path rewrites
4. **No basic auth middleware**: Use authentication proxy or app-level auth

### Traefik Features Not Available

| Traefik Feature | Gateway API Alternative |
|-----------------|-------------------------|
| Middlewares (rate-limit, auth) | App-level or Network Policy |
| Strip Prefix | URLRewrite filter |
| InFlight Requests | No direct equivalent |
| Circuit Breaker | Cilium Service Mesh features |
| Retry | Application-level or service mesh |

## Success Criteria

Migration is considered successful when:

- [ ] All 7 services accessible via Cilium Gateway
- [ ] TLS certificates auto-renewed by cert-manager
- [ ] DNS records managed by external-dns
- [ ] HTTP→HTTPS redirects working
- [ ] No Traefik pods running
- [ ] Monitoring shows acceptable performance
- [ ] 7 days of stable operation

## Timeline

| Phase | Duration | Key Milestone |
|-------|----------|---------------|
| Phase 0: Preparation | Week 1 | Test Gateway working |
| Phase 1: Create Gateways | Week 2 | Gateways programmed, TLS working |
| Phase 2: Migrate Services | Weeks 3-4 | All HTTPRoutes created |
| Phase 3: Decommission Traefik | Week 5 | Traefik deleted |
| **Total** | **5 weeks** | **Migration complete** |

## Monitoring & Observability

### Key Metrics to Track

1. **Gateway API Metrics**:
   ```bash
   kubectl get gateway -A
   kubectl describe httproute -A
   ```

2. **Cilium Observability**:
   ```bash
   cilium hubble observe --type l7 --protocol http
   ```

3. **Certificate Status**:
   ```bash
   kubectl get certificates -A
   ```

4. **External DNS**:
   ```bash
   kubectl logs -n external-dns-system deployment/external-dns
   ```

### Alerts to Configure

- Gateway not Programmed
- HTTPRoute not Accepted
- TLS certificate expiry < 30 days
- 5xx errors on Gateway

## References

- [Cilium Gateway API Docs](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/)
- [Gateway API Spec](https://gateway-api.sigs.k8s.io/)
- [cert-manager Gateway API Support](https://cert-manager.io/docs/usage/gateway/)
- [external-dns Gateway API Support](https://kubernetes-sigs.github.io/external-dns/latest/tutorials/gateway-api/)

---

**Next Steps**: Review this plan with the team, then begin Phase 0 preparation tasks.
