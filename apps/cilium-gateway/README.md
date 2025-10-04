# Cilium Gateway API with L2-IPAM

This directory contains the configuration for Cilium's Gateway API with L2 announcements (L2-IPAM), providing LoadBalancer IPs and ingress capabilities without external load balancers.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Network (172.16.20.0/24)                     │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │         L2 Announcements (ARP/NDP)                       │  │
│  │  172.16.20.208 (HTTP)  | 172.16.20.209 (HTTPS)          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              ▼                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │          Cilium Gateway Controller                       │  │
│  │  - cilium-web-gateway (HTTP :80)                        │  │
│  │  - cilium-secure-gateway (HTTPS :443)                   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              ▼                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │          HTTPRoute Resources                             │  │
│  │  Route traffic based on:                                 │  │
│  │  - Hostnames (*.apps.lab.mxe11.nl)                      │  │
│  │  - Paths (/api, /admin, etc.)                           │  │
│  │  - Headers (x-api-version, etc.)                        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              ▼                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │          Backend Services                                │  │
│  │  - uptime-kuma (monitoring:3001)                        │  │
│  │  - grafana (monitoring:3000)                            │  │
│  │  - hubble-ui (kube-system:8080)                         │  │
│  │  - argocd (argocd:8080)                                 │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### 1. IP Pool ([ip-pool.yaml](gateway/base/ip-pool.yaml))

Defines the IP address range available for LoadBalancer services:

- **CIDR**: `172.16.20.208/28` (16 addresses: .208-.223)
- **Purpose**: Provides IPs for Gateway LoadBalancer services
- **Selector**: Only assigns IPs to services owned by Gateways

### 2. L2 Announcement Policy ([l2-announcement-policy.yaml](gateway/base/l2-announcement-policy.yaml))

Configures how IPs are announced on the local network:

- **Method**: ARP (IPv4) / NDP (IPv6) announcements
- **Node Selection**: All Linux nodes can participate
- **Interfaces**: Auto-detects eth* and ens* interfaces
- **Redundancy**: Multiple nodes can announce the same IP for failover

### 3. HTTP Gateway ([cilium-web-gateway.yaml](gateway/base/cilium-web-gateway.yaml))

HTTP (port 80) gateway for plain HTTP traffic or redirects:

- **IP**: `172.16.20.208`
- **Protocol**: HTTP
- **Port**: 80
- **Use Case**: HTTP to HTTPS redirects, non-sensitive applications

### 4. HTTPS Gateway ([cilium-secure-gateway.yaml](gateway/base/cilium-secure-gateway.yaml))

HTTPS (port 443) gateway with TLS termination:

- **IP**: `172.16.20.209`
- **Protocol**: HTTPS
- **Port**: 443
- **TLS**: Terminates TLS using cert-manager certificates
- **Hostname**: `*.apps.lab.mxe11.nl`

## Creating HTTPRoutes

### Basic HTTPS Route

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: myapp
  namespace: default
spec:
  parentRefs:
    - name: cilium-secure-gateway
      namespace: cilium-gateway-system
  hostnames:
    - myapp.apps.lab.mxe11.nl
  rules:
    - backendRefs:
        - name: myapp-service
          port: 8080
```

### HTTP to HTTPS Redirect

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: myapp-redirect
  namespace: default
spec:
  parentRefs:
    - name: cilium-web-gateway
      namespace: cilium-gateway-system
  hostnames:
    - myapp.apps.lab.mxe11.nl
  rules:
    - filters:
        - type: RequestRedirect
          requestRedirect:
            scheme: https
            statusCode: 301
```

### Path-Based Routing

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: myapp-paths
  namespace: default
spec:
  parentRefs:
    - name: cilium-secure-gateway
      namespace: cilium-gateway-system
  hostnames:
    - myapp.apps.lab.mxe11.nl
  rules:
    # API traffic
    - matches:
        - path:
            type: PathPrefix
            value: /api
      backendRefs:
        - name: api-service
          port: 8081

    # Admin interface
    - matches:
        - path:
            type: PathPrefix
            value: /admin
      backendRefs:
        - name: admin-service
          port: 8082

    # Default route
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: web-service
          port: 8080
```

## Cross-Namespace Access

To allow HTTPRoutes to reference the Gateway from other namespaces, a [ReferenceGrant](gateway/base/reference-grant.yaml) is configured:

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: cert-manager-to-gateway
  namespace: cert-manager
spec:
  from:
    - group: gateway.networking.k8s.io
      kind: Gateway
      namespace: cilium-gateway-system
  to:
    - group: ""
      kind: Secret
```

This allows the Gateway to access TLS certificates stored in the cert-manager namespace.

## Verification Commands

```bash
# Check Gateway status
kubectl get gateway -n cilium-gateway-system

# Verify LoadBalancer IPs are assigned
kubectl get svc -n cilium-gateway-system

# Check L2 announcement policy
kubectl get ciliuml2announcementpolicy

# View IP pool status
kubectl get ciliumloadbalancerippool

# List all HTTPRoutes
kubectl get httproute -A

# Check specific route details
kubectl describe httproute myapp -n default

# Verify L2 announcements (from a node)
kubectl exec -n kube-system ds/cilium -- cilium service list
```

## Troubleshooting

### Gateway doesn't get an IP

1. Check IP pool: `kubectl describe ciliumloadbalancerippool default-pool`
2. Verify service selector matches: `kubectl get svc -n cilium-gateway-system -o yaml`
3. Check Cilium logs: `kubectl logs -n kube-system ds/cilium -c cilium-agent`

### L2 announcements not working

1. Verify policy: `kubectl describe ciliuml2announcementpolicy default-l2-policy`
2. Check node interfaces: Ensure eth*/ens* interfaces exist
3. Verify Cilium LB-IPAM: `kubectl exec -n kube-system ds/cilium -- cilium status | grep -i lb`

### HTTPRoute doesn't route traffic

1. Check route status: `kubectl describe httproute myapp -n namespace`
2. Verify parent gateway exists: `kubectl get gateway -n cilium-gateway-system`
3. Check hostname matches Gateway listener: Compare `spec.hostnames` in both resources
4. Ensure backend service exists: `kubectl get svc backend-service -n namespace`

### TLS certificates not working

1. Verify cert-manager certificate: `kubectl get certificate -n cilium-gateway-system`
2. Check ReferenceGrant: `kubectl get referencegrant -n cert-manager`
3. Verify secret exists: `kubectl get secret wildcard-apps-lab-mxe11-nl-tls -n cilium-gateway-system`

## Advanced Features

### Traffic Splitting (Canary Deployments)

```yaml
rules:
  - backendRefs:
      - name: app-v1
        port: 8080
        weight: 90  # 90% of traffic
      - name: app-v2
        port: 8080
        weight: 10  # 10% of traffic (canary)
```

### Header-Based Routing

```yaml
rules:
  - matches:
      - headers:
          - name: x-api-version
            value: v2
    backendRefs:
      - name: api-v2-service
        port: 8080
```

### Request/Response Header Manipulation

```yaml
rules:
  - filters:
      - type: RequestHeaderModifier
        requestHeaderModifier:
          add:
            - name: X-Custom-Header
              value: custom-value
          remove:
            - X-Unwanted-Header
    backendRefs:
      - name: backend-service
        port: 8080
```

## External DNS Integration

To automatically create DNS records, uncomment the external-dns annotation in the Gateway resources:

```yaml
metadata:
  annotations:
    external-dns.alpha.kubernetes.io/hostname: "*.apps.lab.mxe11.nl"
```

This requires external-dns to be configured with RFC2136 (for Technitium DNS) or your DNS provider.

## Migration from Traefik

If migrating from Traefik IngressRoute to Cilium HTTPRoute:

1. **IngressRoute** → **HTTPRoute**: Update kind and apiVersion
2. **entryPoints** → **parentRefs**: Reference the Gateway instead of entryPoints
3. **routes.match** → **rules.matches**: Convert Traefik match syntax to Gateway API
4. **services** → **backendRefs**: Update service references

Example migration:

```yaml
# Traefik IngressRoute
kind: IngressRoute
spec:
  entryPoints: [websecure]
  routes:
    - match: Host(`app.example.com`)
      services:
        - name: app-service
          port: 8080

# Cilium HTTPRoute
kind: HTTPRoute
spec:
  parentRefs:
    - name: cilium-secure-gateway
      namespace: cilium-gateway-system
  hostnames: [app.example.com]
  rules:
    - backendRefs:
        - name: app-service
          port: 8080
```

## Resources

- [Cilium Gateway API Documentation](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/)
- [Cilium L2 Announcements](https://docs.cilium.io/en/stable/network/l2-announcements/)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [HTTPRoute Specification](https://gateway-api.sigs.k8s.io/reference/spec/#gateway.networking.k8s.io/v1.HTTPRoute)
