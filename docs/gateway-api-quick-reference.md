# Gateway API Quick Reference

## Essential Commands

### Check Gateway Status
```bash
# List all Gateways
kubectl get gateway -A

# Detailed Gateway info
kubectl describe gateway cilium-secure-gateway -n cilium-gateway-system

# Check if Gateway is ready
kubectl wait --for=condition=Programmed gateway/cilium-secure-gateway -n cilium-gateway-system --timeout=60s
```

### Check HTTPRoutes
```bash
# List all HTTPRoutes
kubectl get httproute -A

# Check route status
kubectl describe httproute <name> -n <namespace>

# Verify route is accepted
kubectl get httproute <name> -n <namespace> -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'
```

### Debug TLS
```bash
# Check certificate status
kubectl get certificate -A

# Certificate details
kubectl describe certificate wildcard-apps-tls -n cilium-gateway-system

# Check TLS secret
kubectl get secret wildcard-apps-tls -n cilium-gateway-system -o yaml
```

### Test Connectivity
```bash
# Test HTTPS
curl -v https://service.apps.lab.mxe11.nl

# Test with specific CA (if self-signed)
curl --cacert ca.crt https://service.apps.lab.mxe11.nl

# Ignore cert errors (testing only)
curl -k https://service.apps.lab.mxe11.nl
```

### Monitor Traffic
```bash
# Watch Gateway API traffic in Hubble
cilium hubble observe --type l7 --protocol http

# Filter by specific service
cilium hubble observe --type l7 --protocol http --to-service <service-name>

# Watch TLS handshakes
cilium hubble observe --type trace --verdict FORWARDED
```

## Common HTTPRoute Patterns

### Basic HTTP Route
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app
  namespace: my-namespace
spec:
  parentRefs:
    - name: cilium-secure-gateway
      namespace: cilium-gateway-system
  hostnames:
    - my-app.apps.lab.mxe11.nl
  rules:
    - backendRefs:
        - name: my-app-service
          port: 80
```

### With Path Matching
```yaml
rules:
  - matches:
      - path:
          type: PathPrefix
          value: /api
    backendRefs:
      - name: api-service
        port: 8080
```

### With HTTP→HTTPS Redirect
```yaml
# Separate HTTPRoute on HTTP Gateway
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app-redirect
spec:
  parentRefs:
    - name: cilium-web-gateway
      namespace: cilium-gateway-system
  hostnames:
    - my-app.apps.lab.mxe11.nl
  rules:
    - filters:
        - type: RequestRedirect
          requestRedirect:
            scheme: https
            statusCode: 301
```

### With Header Modification
```yaml
rules:
  - filters:
      - type: RequestHeaderModifier
        requestHeaderModifier:
          set:
            - name: X-Forwarded-Proto
              value: https
          add:
            - name: X-Custom-Header
              value: my-value
          remove:
            - X-Unwanted-Header
    backendRefs:
      - name: my-service
        port: 80
```

### Canary/Traffic Split
```yaml
rules:
  - backendRefs:
      - name: my-app-v1
        port: 80
        weight: 90
      - name: my-app-v2
        port: 80
        weight: 10
```

## Gateway Configuration Patterns

### Two-Gateway Setup (Recommended)
```yaml
---
# HTTP Gateway - for redirects
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
      allowedRoutes:
        namespaces:
          from: All
---
# HTTPS Gateway - for secure traffic
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: cilium-secure-gateway
  namespace: cilium-gateway-system
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    external-dns.alpha.kubernetes.io/hostname: "*.apps.lab.mxe11.nl"
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
            name: wildcard-apps-tls
```

### Single Gateway with Multiple Listeners
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: cilium-gateway
  namespace: cilium-gateway-system
spec:
  gatewayClassName: cilium
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
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
            name: wildcard-apps-tls
```

## TLS Certificate Configuration

### cert-manager with Gateway API
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    # OR for namespaced issuer:
    # cert-manager.io/issuer: my-issuer
spec:
  listeners:
    - name: https
      protocol: HTTPS
      port: 443
      hostname: "*.apps.lab.mxe11.nl"
      tls:
        mode: Terminate
        certificateRefs:
          - kind: Secret
            name: wildcard-tls  # cert-manager will create this
```

cert-manager will automatically:
1. Detect the annotation
2. Create a Certificate resource
3. Request cert from Let's Encrypt
4. Store in the named secret
5. Keep it renewed

### Manual TLS Secret
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-tls-secret
  namespace: cilium-gateway-system
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-cert>
  tls.key: <base64-encoded-key>
```

## external-dns Annotations

### On Gateway (preferred)
```yaml
metadata:
  annotations:
    external-dns.alpha.kubernetes.io/hostname: "*.apps.lab.mxe11.nl,gateway.lab.mxe11.nl"
    external-dns.alpha.kubernetes.io/target: traefik.lab.mxe11.nl  # Optional: CNAME target
```

### On HTTPRoute
```yaml
metadata:
  annotations:
    external-dns.alpha.kubernetes.io/hostname: my-app.apps.lab.mxe11.nl
    # Will create DNS record pointing to Gateway's LoadBalancer IP
```

## Troubleshooting

### Gateway Not Ready

**Symptom**: Gateway status shows `Programmed: False`

**Check**:
```bash
kubectl describe gateway <name> -n <namespace>
kubectl get svc -n <namespace> | grep gateway
```

**Common Causes**:
- LoadBalancer IP not assigned (check MetalLB)
- Cilium Gateway API not enabled
- GatewayClass not found

### HTTPRoute Not Working

**Symptom**: HTTPRoute status shows `Accepted: False` or traffic doesn't flow

**Check**:
```bash
kubectl describe httproute <name> -n <namespace>

# Check if service exists
kubectl get svc <backend-service> -n <namespace>

# Check Cilium policies
cilium policy get
```

**Common Causes**:
- parentRef references wrong Gateway
- Hostname doesn't match Gateway listener
- Backend service doesn't exist
- Network policy blocking traffic

### TLS Certificate Issues

**Symptom**: Certificate not issued or HTTPS not working

**Check**:
```bash
kubectl get certificate -A
kubectl describe certificate <name> -n <namespace>
kubectl get certificaterequest -A
kubectl logs -n cert-manager deployment/cert-manager
```

**Common Causes**:
- cert-manager Gateway API support not enabled
- Issuer doesn't exist or is not ready
- ACME challenge failing (check external-dns)
- Certificate secret name mismatch

### DNS Not Resolving

**Symptom**: DNS doesn't point to Gateway

**Check**:
```bash
kubectl logs -n external-dns-system deployment/external-dns
dig my-app.apps.lab.mxe11.nl
```

**Common Causes**:
- external-dns annotation missing or wrong
- external-dns doesn't have Gateway API support
- Cloudflare API token invalid
- DNS propagation delay

## Migration Checklist

When migrating a service from Traefik IngressRoute to Gateway API HTTPRoute:

- [ ] Create HTTPRoute pointing to Cilium Gateway
- [ ] Test HTTPS access
- [ ] Verify TLS certificate
- [ ] Check DNS resolution
- [ ] Test application functionality
- [ ] Monitor for errors (Hubble, logs)
- [ ] Run for 24 hours in parallel with old route
- [ ] Delete old IngressRoute
- [ ] Update documentation

## Performance Tuning

### Monitor Gateway Performance
```bash
# Check Gateway endpoint usage
cilium service list | grep gateway

# Check connection count
cilium bpf lb list | grep gateway

# Monitor latency
cilium hubble observe --type l7 --protocol http | grep gateway
```

### Scale Gateway Envoy Pods
```yaml
# In Cilium Helm values
envoy:
  replicas: 3  # Increase for higher load
```

## Useful Links

- **Gateway API Spec**: https://gateway-api.sigs.k8s.io/
- **Cilium Gateway API**: https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/
- **cert-manager Gateway**: https://cert-manager.io/docs/usage/gateway/
- **external-dns Gateway**: https://kubernetes-sigs.github.io/external-dns/latest/tutorials/gateway-api/

## Examples Repository

See full examples in: `apps/*/overlays/production/*httproute.yaml`

- ArgoCD: Complex redirect + HTTPS
- Grafana: Simple HTTPS
- Uptime Kuma: Basic HTTPRoute (already migrated)
