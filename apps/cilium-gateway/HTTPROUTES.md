# HTTPRoute Services Documentation

This document lists all HTTPRoutes configured in the cluster, organized by category.

## Overview

All HTTPRoutes use the `cilium-secure-gateway` (HTTPS on 172.16.20.208) unless otherwise specified.
Base domain: `*.apps.lab.mxe11.nl`

**Total Routes**: 12

---

## Core Infrastructure

### ArgoCD
- **URL**: https://cd.apps.lab.mxe11.nl
- **Service**: `argocd-server` (namespace: `argocd`)
- **Port**: 443
- **Purpose**: GitOps continuous deployment platform
- **File**: `apps/argocd/overlays/production/httproute.yaml`

### HashiCorp Vault
- **URL**: https://vault.apps.lab.mxe11.nl
- **Service**: `external-vault` (namespace: `default`)
- **Port**: 8200
- **Purpose**: Secrets management and encryption as a service
- **File**: `apps/external-vault/httproute.yaml`

---

## Monitoring & Observability

### Grafana
- **URL**: https://grafana.apps.lab.mxe11.nl
- **Service**: `kube-prometheus-stack-grafana` (namespace: `monitoring`)
- **Port**: 80
- **Purpose**: Metrics visualization and dashboards
- **File**: `apps/monitoring/kube-prometheus-stack/overlays/production/grafana-httproute.yaml`

### Prometheus
- **URL**: https://prometheus.apps.lab.mxe11.nl
- **Service**: `kube-prometheus-stack-prometheus` (namespace: `monitoring`)
- **Port**: 9090
- **Purpose**: Metrics collection and time-series database
- **File**: `apps/monitoring/kube-prometheus-stack/overlays/production/prometheus-httproute.yaml`

### AlertManager
- **URL**: https://alertmanager.apps.lab.mxe11.nl
- **Service**: `kube-prometheus-stack-alertmanager` (namespace: `monitoring`)
- **Port**: 9093
- **Purpose**: Alert routing and management
- **File**: `apps/monitoring/kube-prometheus-stack/overlays/production/alertmanager-httproute.yaml`

### Kube-State-Metrics
- **URL**: https://kube-state-metrics.apps.lab.mxe11.nl
- **Service**: `kube-prometheus-stack-kube-state-metrics` (namespace: `monitoring`)
- **Port**: 8080
- **Purpose**: Kubernetes cluster state metrics endpoint
- **File**: `apps/monitoring/kube-prometheus-stack/overlays/production/kube-state-metrics-httproute.yaml`

### Uptime Kuma
- **URL**: https://uptime.apps.lab.mxe11.nl
- **Service**: `uptime-kuma` (namespace: `monitoring`)
- **Port**: 3001
- **Purpose**: Uptime monitoring and status page
- **File**: `apps/monitoring/uptime-kuma/overlays/production/httproute.yaml`
- **Note**: Also includes HTTP→HTTPS redirect route

---

## Network & Service Mesh

### Hubble UI
- **URL**: https://hubble.apps.lab.mxe11.nl
- **Service**: `hubble-ui` (namespace: `kube-system`)
- **Port**: 80
- **Purpose**: Cilium network observability UI
- **File**: `apps/kube-system/hubble-ui/overlays/production/httproute.yaml`

### Hubble Relay
- **URL**: https://hubble-relay.apps.lab.mxe11.nl
- **Service**: `hubble-relay` (namespace: `kube-system`)
- **Port**: 80
- **Purpose**: Hubble gRPC API server for programmatic access
- **File**: `apps/kube-system/hubble-ui/overlays/production/hubble-relay-httproute.yaml`

---

## Flux GitOps Controllers

### Flux Source Controller
- **URL**: https://flux-source.apps.lab.mxe11.nl
- **Service**: `source-controller` (namespace: `flux-system`)
- **Port**: 80
- **Purpose**: Flux source management API (Git, Helm, OCI repositories)
- **File**: `flux/httproutes/source-controller-httproute.yaml`

### Flux Notification Controller
- **URL**: https://flux-notifications.apps.lab.mxe11.nl
- **Service**: `notification-controller` (namespace: `flux-system`)
- **Port**: 80
- **Purpose**: Flux webhook receiver and event notifications
- **File**: `flux/httproutes/notification-controller-httproute.yaml`

---

## Gateway Dashboard

### Cilium Gateway Status Dashboard
- **URL**: https://gw.apps.lab.mxe11.nl
- **Service**: `cilium-gateway-dashboard` (namespace: `cilium-gateway-system`)
- **Port**: 80
- **Purpose**: Real-time status dashboard for all HTTPRoutes and Gateways
- **File**: `apps/cilium-gateway/dashboard/httproute.yaml`

---

## DNS Configuration

All routes use external-dns annotations to automatically create DNS records:

```yaml
annotations:
  external-dns.alpha.kubernetes.io/hostname: <service>.apps.lab.mxe11.nl
```
containerd config default > /etc/containerd/config.tomnl && sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml && sudo systemctl restart containerd

DNS records should point to the secure gateway IP: **172.16.20.208**

---

## Gateway Configuration

### Cilium Secure Gateway (HTTPS)
- **Name**: `cilium-secure-gateway`
- **Namespace**: `cilium-gateway-system`
- **IP**: 172.16.20.208
- **Port**: 443 (HTTPS)
- **Listeners**: https (TLS with cert-manager)

### Cilium Web Gateway (HTTP)
- **Name**: `cilium-web-gateway`
- **Namespace**: `cilium-gateway-system`
- **IP**: 172.16.20.209
- **Port**: 80 (HTTP)
- **Purpose**: HTTP→HTTPS redirects

---

## Adding New HTTPRoutes

To expose a new service via HTTPRoute:

1. Create HTTPRoute manifest:
```yaml
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-service
  namespace: my-namespace
  annotations:
    external-dns.alpha.kubernetes.io/hostname: my-service.apps.lab.mxe11.nl
spec:
  parentRefs:
    - name: cilium-secure-gateway
      namespace: cilium-gateway-system
  hostnames:
    - my-service.apps.lab.mxe11.nl
  rules:
    - backendRefs:
        - name: my-service
          port: 8080
```

2. Add to kustomization.yaml in the service's overlay directory

3. Update the gateway dashboard at `apps/cilium-gateway/dashboard/index.html`:
```javascript
{ hostname: 'my-service.apps.lab.mxe11.nl', service: 'my-service', namespace: 'my-namespace', gateway: 'cilium-secure-gateway' }
```

4. Commit and push - Flux will automatically apply the changes

---

## Troubleshooting

### Route Not Accessible

1. Check HTTPRoute status:
```bash
kubectl get httproute -A
kubectl describe httproute <name> -n <namespace>
```

2. Verify Gateway is ready:
```bash
kubectl get gateway -n cilium-gateway-system
```

3. Check DNS resolution:
```bash
dig <service>.apps.lab.mxe11.nl
```

4. Test backend service:
```bash
kubectl port-forward svc/<service> -n <namespace> 8080:<port>
```

5. View Cilium Gateway logs:
```bash
kubectl logs -n cilium-gateway-system -l gateway.networking.k8s.io/gateway-name=cilium-secure-gateway
```

### Certificate Issues

All HTTPS routes use cert-manager with Let's Encrypt. Check certificate status:
```bash
kubectl get certificate -n cilium-gateway-system
kubectl describe certificate -n cilium-gateway-system
```

---

## Related Documentation

- [Gateway Architecture](README.md)
- [Dashboard Guide](DASHBOARDS.md)
- [Migration from Traefik](MIGRATION.md)
