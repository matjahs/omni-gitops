# Gateway API Dashboards

This document describes the dashboards available for monitoring your Cilium Gateway API implementation, replacing the functionality previously provided by Traefik's dashboard.

## Overview

We've created **three complementary dashboards** that together provide better visibility than Traefik's single dashboard:

1. **Gateway Status Dashboard** - Visual overview of all routes and gateways (web-based)
2. **Grafana Metrics Dashboard** - Technical metrics and performance data (Grafana)
3. **Hubble UI** - Real-time traffic flow visualization (already deployed)

---

## 1. Gateway Status Dashboard 🎨

**URL**: `https://gw.apps.lab.mxe11.nl`

A beautiful, real-time dashboard showing all your HTTPRoutes, gateways, and their health status.

### Features

- **Real-time Status**: Auto-refreshes every 30 seconds
- **Visual Health Indicators**: Green (healthy), Yellow (checking), Red (unhealthy)
- **Gateway Overview**: Shows all gateways with their IPs and ports
- **Route Details**: Displays each HTTPRoute with:
  - Hostname
  - Backend service and namespace
  - Gateway assignment
  - Current health status

### Screenshots

```
┌─────────────────────────────────────────────────────────────┐
│  🚀 Gateway Dashboard                                       │
│  Cilium Gateway API - Real-time monitoring                  │
├─────────────────────────────────────────────────────────────┤
│  Total Routes: 7    Healthy: 6    Gateways: 2              │
├─────────────────────────────────────────────────────────────┤
│  📡 Gateways                                                │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ cilium-web-gateway      HTTP:80    172.16.20.209   │   │
│  │ cilium-secure-gateway   HTTPS:443  172.16.20.208   │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  🔀 HTTP Routes                                             │
│  ┌──────────────────┐  ┌──────────────────┐               │
│  │ hubble.apps...   │  │ grafana.apps...  │               │
│  │ via cilium-se... │  │ via cilium-se... │               │
│  │ Service: hubble  │  │ Service: grafana │               │
│  │ ✓ Healthy        │  │ ✓ Healthy        │               │
│  └──────────────────┘  └──────────────────┘               │
└─────────────────────────────────────────────────────────────┘
```

### How to Access

1. **Add DNS entry** (if not using external-dns):
   ```
   gw.apps.lab.mxe11.nl → 172.16.20.208
   ```

2. **Open in browser**:
   ```
   https://gw.apps.lab.mxe11.nl
   ```

3. **Or use curl** for testing:
   ```bash
   curl --resolve gw.apps.lab.mxe11.nl:443:172.16.20.208 \
     https://gw.apps.lab.mxe11.nl -k
   ```

### Customization

To add more routes to the dashboard, edit the HTML file:

```bash
# Edit the routes array in index.html
vim apps/cilium-gateway/dashboard/index.html
```

Then rebuild the ConfigMap:

```bash
kubectl create configmap gateway-dashboard-html \
  --from-file=index.html=apps/cilium-gateway/dashboard/index.html \
  --namespace cilium-gateway-system \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart the pod to pick up changes
kubectl rollout restart deployment/gateway-dashboard -n cilium-gateway-system
```

---

## 2. Grafana Metrics Dashboard 📊

**URL**: `https://grafana.apps.lab.mxe11.nl/d/cilium-gateway-api`

A technical dashboard showing detailed metrics from Cilium and Envoy (the L7 proxy used by Cilium Gateway API).

### Features

- **Request Rate**: Requests per second by service
- **Latency**: p95 and p50 latency percentiles
- **HTTP Status Codes**: 2xx, 4xx, 5xx response distribution
- **Gateway Status**: Current state of all gateways
- **Active Services**: Count of services behind gateways
- **Total Throughput**: Aggregate requests/sec across all routes

### Metrics Available

```
Cilium Metrics:
- cilium_proxy_upstream_reply_seconds_count   (request count)
- cilium_proxy_upstream_reply_seconds_bucket  (latency histogram)

Envoy Metrics:
- envoy_cluster_upstream_rq_xx                (HTTP status codes)
- envoy_cluster_upstream_rq_time              (request duration)

Gateway API Metrics:
- gateway_api_gateway_status                  (gateway health)
```

### How to Access

1. **Login to Grafana**:
   ```
   https://grafana.apps.lab.mxe11.nl
   ```

2. **Navigate to Dashboard**:
   - Click "Dashboards" → "Browse"
   - Look for "Cilium Gateway API" (or use search)
   - Or go directly: `/d/cilium-gateway-api`

3. **Import Dashboard** (if not auto-loaded):
   ```bash
   # The dashboard JSON is at:
   apps/monitoring/kube-prometheus-stack/dashboards/cilium-gateway-api.json

   # Import via Grafana UI:
   # Home → Dashboards → Import → Upload JSON file
   ```

### Dashboard Panels

1. **Gateway Request Rate by Service**
   - Time series showing req/s for each backend service
   - Helps identify traffic patterns and hotspots

2. **Request Latency (p95 & p50)**
   - 95th and 50th percentile response times
   - Useful for SLA monitoring

3. **HTTP Response Codes**
   - Breakdown of 2xx, 4xx, 5xx responses
   - Quickly spot errors and issues

4. **Active Gateway Services**
   - Gauge showing number of services with Gateway labels
   - Instant view of scale

5. **Total Requests/sec**
   - Aggregate throughput across all gateways
   - Overall system load indicator

6. **Gateway Status Table**
   - Shows each Gateway's programmed status
   - Color-coded: Green (Programmed), Yellow (Pending), Red (Error)

### Alerting (Optional)

You can create Grafana alerts based on these metrics:

```yaml
# Example: Alert on high error rate
alert: HighGatewayErrorRate
expr: |
  sum(rate(envoy_cluster_upstream_rq_xx{envoy_response_code_class="5"}[5m])) /
  sum(rate(envoy_cluster_upstream_rq_xx[5m])) > 0.05
for: 5m
annotations:
  summary: "Gateway 5xx error rate above 5%"
```

---

## 3. Hubble UI 🌐

**URL**: `https://hubble.apps.lab.mxe11.nl`

Real-time network flow visualization using Cilium Hubble.

### Features

- **Traffic Flow Visualization**: See requests flowing through gateways to pods
- **Service Map**: Visual representation of service dependencies
- **HTTP/2 and gRPC**: Full L7 protocol visibility
- **Policy Enforcement**: See network policies in action
- **DNS Monitoring**: Track DNS queries and responses

### How Hubble Complements Gateway Metrics

Hubble provides **request-level observability** that complements the dashboard:

1. **Trace Individual Requests**: Follow a specific request from Gateway → Service → Pod
2. **Identify Bottlenecks**: See where requests are being delayed
3. **Debug Routing Issues**: Verify traffic is reaching the right backends
4. **Security Monitoring**: Detect unexpected traffic patterns

### Example Use Cases

**Scenario 1: Route Not Working**
1. Check Gateway Dashboard → Route shows unhealthy
2. Check Hubble UI → No traffic reaching backend service
3. Investigate HTTPRoute configuration or backend health

**Scenario 2: High Latency**
1. Grafana shows high p95 latency for a service
2. Hubble UI shows requests timing out at pod level
3. Scale up pods or investigate pod performance

**Scenario 3: 5xx Errors**
1. Grafana shows spike in 5xx responses
2. Hubble UI identifies specific pods returning errors
3. Check pod logs for application errors

---

## Comparison: Traefik Dashboard vs. Cilium Dashboards

| Feature | Traefik Dashboard | Cilium Dashboards |
|---------|-------------------|-------------------|
| **Route Status** | ✅ Single view | ✅ Status Dashboard |
| **Request Metrics** | ✅ Basic | ✅✅ Advanced (Grafana) |
| **Latency Tracking** | ⚠️ Limited | ✅ Percentile-based |
| **Traffic Flow Viz** | ❌ None | ✅ Hubble UI |
| **HTTP Status Codes** | ✅ Basic | ✅ Detailed breakdown |
| **Service Health** | ⚠️ Basic | ✅ Comprehensive |
| **Historical Data** | ⚠️ Limited | ✅ Full Prometheus retention |
| **Alerting** | ❌ Not available | ✅ Grafana alerts |
| **eBPF Metrics** | ❌ Not available | ✅ Full eBPF visibility |

### Key Improvements Over Traefik

1. **Separation of Concerns**:
   - Status overview (HTML dashboard)
   - Technical metrics (Grafana)
   - Traffic flows (Hubble)

2. **Better Metrics**:
   - eBPF-level visibility (no sidecar needed)
   - Detailed latency percentiles
   - Full HTTP/2 and gRPC support

3. **Historical Analysis**:
   - Prometheus retention (typically 15 days)
   - Time-series analysis and trend detection
   - Long-term capacity planning

4. **Alerting**:
   - Grafana alerting on metrics
   - Integration with Alertmanager
   - Slack/PagerDuty/Email notifications

---

## Quick Access Links

Once DNS is configured, all dashboards are accessible at:

```
🎨 Gateway Status:  https://gw.apps.lab.mxe11.nl
📊 Grafana:         https://grafana.apps.lab.mxe11.nl/d/cilium-gateway-api
🌐 Hubble UI:       https://hubble.apps.lab.mxe11.nl
🚀 ArgoCD:          https://cd.apps.lab.mxe11.nl
📈 Prometheus:      https://prometheus.apps.lab.mxe11.nl
⏱️ Uptime Kuma:     https://uptime.apps.lab.mxe11.nl
💾 Ceph Dashboard:  https://ceph.apps.lab.mxe11.nl
```

---

## Troubleshooting

### Gateway Dashboard Not Loading

1. **Check pod status**:
   ```bash
   kubectl get pods -n cilium-gateway-system -l app=gateway-dashboard
   ```

2. **Check HTTPRoute**:
   ```bash
   kubectl get httproute gateway-dashboard -n cilium-gateway-system
   kubectl describe httproute gateway-dashboard -n cilium-gateway-system
   ```

3. **Test service directly**:
   ```bash
   kubectl port-forward svc/gateway-dashboard -n cilium-gateway-system 8080:80
   # Open http://localhost:8080
   ```

### Grafana Dashboard Not Showing Metrics

1. **Verify Prometheus is scraping Cilium**:
   ```bash
   # Check Prometheus targets
   kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
   # Open http://localhost:9090/targets
   # Look for "cilium" targets
   ```

2. **Check if metrics exist**:
   ```bash
   # Query Prometheus directly
   curl -s http://prometheus.apps.lab.mxe11.nl/api/v1/query?query=cilium_proxy_upstream_reply_seconds_count
   ```

3. **Verify dashboard ConfigMap**:
   ```bash
   kubectl get configmap -n monitoring | grep cilium-gateway
   ```

### Hubble UI Not Showing Gateway Traffic

1. **Enable L7 visibility**:
   ```bash
   # Hubble needs L7 visibility enabled
   kubectl annotate namespace cilium-gateway-system \
     io.cilium/proxy-visibility="<Ingress/80/TCP/HTTP>,<Ingress/443/TCP/HTTP>"
   ```

2. **Check Hubble relay**:
   ```bash
   kubectl get pods -n kube-system -l k8s-app=hubble-relay
   ```

---

## Maintenance

### Updating the Status Dashboard

To add/remove routes from the status dashboard:

1. Edit `apps/cilium-gateway/dashboard/index.html`
2. Update the `routes` array with new entries
3. Apply changes:
   ```bash
   kubectl apply -k apps/cilium-gateway/dashboard
   kubectl rollout restart deployment/gateway-dashboard -n cilium-gateway-system
   ```

### Updating Grafana Dashboard

1. Edit dashboard in Grafana UI
2. Export JSON: Dashboard Settings → JSON Model → Copy
3. Save to `apps/monitoring/kube-prometheus-stack/dashboards/cilium-gateway-api.json`
4. Commit to Git for GitOps

---

## Additional Resources

- **Cilium Metrics**: https://docs.cilium.io/en/stable/observability/metrics/
- **Hubble Documentation**: https://docs.cilium.io/en/stable/observability/hubble/
- **Gateway API Observability**: https://gateway-api.sigs.k8s.io/guides/observability/
- **Grafana Dashboards**: https://grafana.com/docs/grafana/latest/dashboards/

---

## Summary

Your new dashboard setup provides **superior visibility** compared to Traefik:

✅ **Gateway Status Dashboard** - At-a-glance overview
✅ **Grafana Metrics** - Deep technical analysis
✅ **Hubble UI** - Request-level tracing

This multi-layered approach gives you operational, performance, and debugging insights that weren't possible with Traefik's single dashboard!
