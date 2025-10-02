# Cilium Operations Guide

Quick reference for common Cilium operations and troubleshooting.

## Quick Status Checks

### Overall Health

```bash
# Get high-level status
cilium status

# Detailed status with wait
cilium status --wait

# Check connectivity
cilium connectivity test
```

### Component Status

```bash
# Check Cilium agents
kubectl get pods -n kube-system -l k8s-app=cilium

# Check Cilium operator
kubectl get pods -n kube-system -l name=cilium-operator

# Check Hubble
kubectl get pods -n kube-system -l k8s-app=hubble-relay
kubectl get pods -n kube-system -l k8s-app=hubble-ui
```

## Configuration Inspection

### View Current Config

```bash
# All configuration
cilium config view

# Specific key
cilium config view | grep kube-proxy-replacement

# Export configuration as YAML
kubectl get cm -n kube-system cilium-config -o yaml
```

### Compare with Expected

```bash
# Run validation script
./scripts/validate-cilium.sh

# Check Helm values
helm get values cilium -n kube-system
```

## Observability

### Hubble CLI

```bash
# Watch flows in real-time
cilium hubble observe

# Filter by pod
cilium hubble observe --pod <pod-name>

# Filter by namespace
cilium hubble observe --namespace <namespace>

# Filter by verdict (dropped packets)
cilium hubble observe --verdict DROPPED

# DNS queries
cilium hubble observe --type l7 --protocol dns
```

### Hubble UI

Access via the configured ingress hostname (see `applications/cilium.yaml`):

```bash
# Get the hostname
kubectl get ingress -n kube-system hubble-ui -o jsonpath='{.spec.rules[0].host}'

# Port forward if ingress not working
kubectl port-forward -n kube-system svc/hubble-ui 8080:80
# Then visit: http://localhost:8080
```

### Metrics

```bash
# Check enabled metrics
kubectl get cm -n kube-system cilium-config -o yaml | grep hubble-metrics

# View Prometheus metrics endpoint
kubectl port-forward -n kube-system ds/cilium 9962:9962
# Then visit: http://localhost:9962/metrics
```

## Network Policies

### List Policies

```bash
# All network policies
kubectl get cnp --all-namespaces  # Cilium Network Policies
kubectl get ccnp --all-namespaces # Cilium Cluster-wide Network Policies
kubectl get networkpolicy --all-namespaces # K8s Network Policies

# Policy endpoints
cilium endpoint list
```

### Debug Policy

```bash
# Check which policies affect a pod
cilium endpoint get <endpoint-id>

# Policy enforcement status
cilium policy get

# Validate policy
cilium policy validate <policy-file.yaml>
```

## Service Load Balancing

### List Services

```bash
# All Cilium-managed services
cilium service list

# BPF load balancer map
cilium bpf lb list
```

### Debug Service Issues

```bash
# Check if service is in BPF map
cilium service list | grep <service-name>

# Inspect service backend endpoints
kubectl describe svc <service-name>

# Check for backend connectivity
cilium endpoint list
```

## BGP Configuration

```bash
# Check BGP peers (if BGP enabled)
kubectl get bgppeeringpolicies -n kube-system
kubectl get bgpadvertisements -n kube-system

# BGP status via Cilium CLI (requires Cilium >= 1.14)
cilium bgp peers
cilium bgp routes
```

## Gateway API

```bash
# List Gateway API resources
kubectl get gateways --all-namespaces
kubectl get httproutes --all-namespaces
kubectl get tcproutes --all-namespaces

# Check Cilium Envoy pods (for Gateway API)
kubectl get pods -n kube-system -l k8s-app=cilium-envoy
```

## Troubleshooting

### Pod Can't Reach Services

```bash
# 1. Check if Cilium is running on the node
kubectl get pods -n kube-system -l k8s-app=cilium -o wide

# 2. Check pod endpoint
POD_IP=$(kubectl get pod <pod-name> -o jsonpath='{.status.podIP}')
cilium endpoint list | grep $POD_IP

# 3. Check service load balancing
cilium service list | grep <service-name>

# 4. Test connectivity from Cilium agent
kubectl exec -n kube-system ds/cilium -- cilium-health status
```

### DNS Not Working

```bash
# Check DNS policy
kubectl get networkpolicies -n kube-system | grep dns
kubectl get cnp -n kube-system | grep dns

# Check DNS traffic in Hubble
cilium hubble observe --type l7 --protocol dns

# Verify CoreDNS is reachable
cilium service list | grep kube-dns
```

### High Packet Drops

```bash
# Observe dropped packets
cilium hubble observe --verdict DROPPED

# Check drop reasons
cilium monitor --type drop

# BPF drop stats
cilium bpf metrics list | grep drop
```

### Node Connectivity Issues

```bash
# Check node-to-node connectivity
cilium node list

# Cluster mesh status (if enabled)
cilium clustermesh status

# KubeSpan status (for Talos)
talosctl -n <node-ip> get members
```

### Performance Issues

```bash
# Check BPF map sizes
cilium bpf config get

# View BPF program stats
cilium bpf metrics list

# Check for BPF map pressure
cilium bpf metrics list | grep -E "(policy|conntrack|nat)"

# Monitor BPF CPU usage
cilium monitor --type debug
```

## Maintenance Operations

### Restart Cilium

```bash
# Rolling restart of all Cilium agents
kubectl rollout restart ds/cilium -n kube-system

# Watch restart progress
kubectl rollout status ds/cilium -n kube-system

# Restart operator
kubectl rollout restart deployment/cilium-operator -n kube-system
```

### Upgrade Cilium

Cilium is managed by ArgoCD, so upgrades are done via Git:

```bash
# 1. Update version in applications/cilium.yaml
vim applications/cilium.yaml
# Change: targetRevision: 1.18.3

# 2. Commit and push
git add applications/cilium.yaml
git commit -m "chore: upgrade Cilium to 1.18.3"
git push

# 3. Watch ArgoCD sync
argocd app get cilium-helm-release
argocd app wait cilium-helm-release

# 4. Verify upgrade
cilium version
cilium status
```

### Clean Up Old BPF Maps

```bash
# Cilium automatically manages BPF maps, but if needed:
cilium cleanup
```

## Emergency Procedures

### Cilium Agent Crash Loop

```bash
# 1. Check logs
kubectl logs -n kube-system -l k8s-app=cilium --tail=100

# 2. Common causes:
#    - BPF map size exceeded
#    - Kernel incompatibility
#    - Configuration error

# 3. Emergency fix: disable kube-proxy replacement temporarily
kubectl set env ds/cilium -n kube-system KUBE_PROXY_REPLACEMENT=false

# 4. After investigation, re-enable
kubectl set env ds/cilium -n kube-system KUBE_PROXY_REPLACEMENT=true
```

### Complete Network Loss

```bash
# 1. Check Cilium health on all nodes
kubectl get pods -n kube-system -l k8s-app=cilium -o wide

# 2. Check for BPF program issues
kubectl exec -n kube-system ds/cilium -- cilium status --verbose

# 3. Nuclear option: restart all Cilium pods simultaneously
# ⚠️ WARNING: Will cause brief network outage
kubectl delete pods -n kube-system -l k8s-app=cilium

# 4. Wait for recovery
kubectl wait --for=condition=ready pod -l k8s-app=cilium -n kube-system --timeout=300s
```

### Rollback Cilium Upgrade

If an upgrade goes wrong:

```bash
# 1. Via ArgoCD - revert the git commit
git revert HEAD
git push

# 2. Via Helm directly (emergency only)
helm rollback cilium -n kube-system

# 3. Verify rollback
helm history cilium -n kube-system
cilium version
```

## Useful Cilium CLI Commands

### Endpoint Management

```bash
# List all endpoints
cilium endpoint list

# Get endpoint details
cilium endpoint get <endpoint-id>

# Regenerate endpoint (fixes some issues)
cilium endpoint regenerate <endpoint-id>
```

### BPF Management

```bash
# List BPF maps
cilium bpf tunnel list
cilium bpf lb list
cilium bpf nat list
cilium bpf endpoint list

# BPF filesystem
cilium bpf fs show
```

### Identity Management

```bash
# List security identities
cilium identity list

# Get specific identity
cilium identity get <identity-id>
```

## Monitoring Best Practices

1. **Enable Prometheus scraping** for Cilium metrics
2. **Set up alerts** for:
   - Cilium agent down
   - High packet drop rate
   - BPF map pressure
   - Policy enforcement errors
3. **Regular checks**:
   - Weekly: Run `cilium connectivity test`
   - Daily: Review Hubble drops
   - Monthly: Review and clean up unused policies

## Performance Tuning

### BPF Map Sizes

```bash
# Check current limits
cilium config view | grep -E "map-max"

# Common tuning (via Helm values):
# bpf-lb-map-max: 65536 (default)
# bpf-policy-map-max: 16384 (default)
# bpf-nat-map-max: 524288 (default)
```

### kube-proxy Replacement Modes

```bash
# Current mode
cilium config view | grep kube-proxy-replacement

# Available modes:
# - "true": Full replacement (current setup)
# - "partial": Hybrid mode
# - "false": Disabled (use kube-proxy)
```

## References

- [Cilium Documentation](https://docs.cilium.io/)
- [Hubble Documentation](https://docs.cilium.io/en/stable/gettingstarted/hubble/)
- [Cilium Troubleshooting Guide](https://docs.cilium.io/en/stable/operations/troubleshooting/)
- [Cilium CLI Reference](https://docs.cilium.io/en/stable/cmdref/)

## Quick Troubleshooting Checklist

When things go wrong, run through this checklist:

- [ ] Are all Cilium pods running? (`kubectl get pods -n kube-system -l k8s-app=cilium`)
- [ ] Is kube-proxy disabled? (`kubectl get pods -n kube-system -l k8s-app=kube-proxy` should be empty)
- [ ] Is Cilium status healthy? (`cilium status`)
- [ ] Are there any dropped packets? (`cilium hubble observe --verdict DROPPED`)
- [ ] Is the Cilium operator running? (`kubectl get pods -n kube-system -l name=cilium-operator`)
- [ ] Are services in the BPF map? (`cilium service list`)
- [ ] Is ArgoCD synced? (`argocd app get cilium-helm-release`)
- [ ] Check recent logs: (`kubectl logs -n kube-system -l k8s-app=cilium --tail=50`)
