# Migration to Cilium Gateway API with L2-IPAM

This document tracks the successful migration from Traefik + MetalLB to Cilium's integrated Gateway API with L2-IPAM.

## Summary

**Date**: 2025-10-04
**Status**: ✅ Complete and Verified

### Components Removed
- ❌ **Traefik** - Ingress controller (replaced by Cilium Gateway API)
- ❌ **MetalLB** - LoadBalancer IP management (replaced by Cilium L2-IPAM)

### New Solution
- ✅ **Cilium Gateway API** - Native Kubernetes Gateway API implementation
- ✅ **Cilium L2-IPAM** - Integrated LoadBalancer IP allocation and L2 announcements
- ✅ **Single Component** - Both ingress and LoadBalancer handled by Cilium

### IP Allocation
- **Previous (MetalLB)**: 172.16.20.100-172.16.20.150
- **New (Cilium L2-IPAM)**: 172.16.20.208/28 (16 addresses)

## What Changed

### 1. Cilium Configuration

Added L2 announcements support to Cilium Helm values:

```yaml
l2announcements:
  enabled: true
  leaseDuration: 15s
  leaseRenewDeadline: 5s
  leaseRetryPeriod: 2s

externalIPs:
  enabled: true
```

**Applied via:**
```bash
helm upgrade cilium cilium/cilium \
  --namespace kube-system \
  --version 1.18.1 \
  --reuse-values \
  --set l2announcements.enabled=true \
  --set externalIPs.enabled=true \
  --wait

kubectl rollout restart daemonset/cilium -n kube-system
```

### 2. IP Pool Configuration

Created `CiliumLoadBalancerIPPool`:
- **Pool Name**: cilium-gateway-pool
- **CIDR**: 172.16.20.208/28 (16 addresses)
- **Selector**: Matches services with label `io.cilium.gateway/owning-gateway`

### 3. L2 Announcement Policy

Created `CiliumL2AnnouncementPolicy`:
- **Interfaces**: `^eth[0-9]+`, `^ens[0-9]+`
- **Node Selector**: All Linux nodes
- **Service Selector**: Gateway-owned services only

### 4. Gateway IP Addresses

| Gateway | Previous IP (MetalLB) | New IP (Cilium L2-IPAM) |
|---------|----------------------|-------------------------|
| cilium-web-gateway | 172.16.20.100 | 172.16.20.209 |
| cilium-secure-gateway | 172.16.20.101 | 172.16.20.208 |

## Verification Steps

### Check IP Pool Status
```bash
kubectl get ciliumloadbalancerippool
# Should show 16 IPs available, 2 used
```

### Check L2 Announcement Leases
```bash
kubectl get leases -n kube-system | grep cilium-l2announce
# Should show 2 leases (one per Gateway service)
```

### Check Gateway IPs
```bash
kubectl get gateway -n cilium-gateway-system
# Should show:
# cilium-secure-gateway: 172.16.20.208
# cilium-web-gateway: 172.16.20.209
```

### Test Connectivity
```bash
# Test HTTPS Gateway (should return HTTP 200)
curl --resolve hubble.apps.lab.mxe11.nl:443:172.16.20.208 \
  https://hubble.apps.lab.mxe11.nl -k -I

# Test with other applications
curl --resolve grafana.apps.lab.mxe11.nl:443:172.16.20.208 \
  https://grafana.apps.lab.mxe11.nl -k -I
```

## MetalLB Removal (Optional)

Since only Gateway services were using MetalLB, it can be safely removed:

### 1. Check for Dependencies
```bash
# Verify no other services use LoadBalancer type
kubectl get svc -A --field-selector spec.type=LoadBalancer
```

### 2. Remove MetalLB
```bash
# If installed via Helm
helm list -A | grep metallb
helm uninstall metallb -n metallb-system

# If installed via manifests
kubectl delete namespace metallb-system

# Remove IPAddressPools CRD (if no longer needed)
kubectl delete ipaddresspool -A --all
kubectl delete crd ipaddresspools.metallb.io
```

### 3. Clean Up Annotations
MetalLB may have left annotations on services. These are harmless and will be ignored:
```yaml
annotations:
  metallb.io/ip-allocated-from-pool: default-pool  # Safe to ignore
```

## DNS Updates Required

If you have DNS records pointing to the old IPs, update them:

| Hostname | Old IP (MetalLB) | New IP (Cilium) | Record Type |
|----------|------------------|-----------------|-------------|
| *.apps.lab.mxe11.nl | 172.16.20.100/101 | 172.16.20.208/209 | A |

### Option 1: Manual DNS Update
Update your DNS server (Technitium/Cloudflare) to point to new IPs.

### Option 2: Use external-dns
Uncomment the external-dns annotation in Gateway manifests:
```yaml
metadata:
  annotations:
    external-dns.alpha.kubernetes.io/hostname: "*.apps.lab.mxe11.nl"
```

## Troubleshooting

### IPs Not Being Assigned

**Symptom**: LoadBalancer services show `<pending>` EXTERNAL-IP

**Solution**:
1. Check IP pool selector matches service labels:
   ```bash
   kubectl describe ciliumloadbalancerippool cilium-gateway-pool
   kubectl get svc -n cilium-gateway-system -o yaml | grep -A 5 "labels:"
   ```

2. Verify L2 announcements are enabled:
   ```bash
   helm get values cilium -n kube-system | grep l2announcements
   ```

### L2 Announcements Not Working

**Symptom**: IPs assigned but not reachable on network

**Solution**:
1. Check for announcement leases:
   ```bash
   kubectl get leases -n kube-system | grep l2announce
   ```

2. Verify network interfaces match policy:
   ```bash
   kubectl exec -n kube-system ds/cilium -- ip link show
   ```

3. Check Cilium logs:
   ```bash
   kubectl logs -n kube-system -l k8s-app=cilium | grep -i l2
   ```

### Gateway Not Routing Traffic

**Symptom**: Connection resets or timeouts

**Solution**:
1. Verify TLS certificate exists:
   ```bash
   kubectl get secret wildcard-apps-lab-mxe11-nl-tls -n cilium-gateway-system
   ```

2. Check HTTPRoute status:
   ```bash
   kubectl get httproute -A
   kubectl describe httproute <name> -n <namespace>
   ```

3. Test with proper SNI:
   ```bash
   curl --resolve app.apps.lab.mxe11.nl:443:172.16.20.208 \
     https://app.apps.lab.mxe11.nl -k
   ```

## Rollback Procedure

If you need to rollback to MetalLB:

1. **Reinstall MetalLB**:
   ```bash
   helm install metallb metallb/metallb -n metallb-system --create-namespace
   ```

2. **Recreate IPAddressPool**:
   ```yaml
   apiVersion: metallb.io/v1beta1
   kind: IPAddressPool
   metadata:
     name: default-pool
     namespace: metallb-system
   spec:
     addresses:
       - 172.16.20.100-172.16.20.150
   ```

3. **Delete Cilium IP Pool**:
   ```bash
   kubectl delete ciliumloadbalancerippool cilium-gateway-pool
   ```

4. **Delete Gateways** (to force re-creation with MetalLB IPs):
   ```bash
   kubectl delete gateway -n cilium-gateway-system --all
   kubectl apply -k apps/cilium-gateway/gateway/base
   ```

## Benefits of Cilium Gateway API + L2-IPAM

### Infrastructure Simplification
1. **Removed Two Components**: Eliminated both Traefik and MetalLB from the stack
2. **Single Control Plane**: Cilium now handles CNI, Gateway API, and LoadBalancer IPAM
3. **Reduced Complexity**: Fewer components to upgrade, monitor, and troubleshoot
4. **Lower Resource Usage**: Consolidated functionality reduces pod count and resource consumption

### Technical Improvements
5. **Native Integration**: Gateway API and L2-IPAM are first-class Cilium features
6. **Better Performance**: Direct eBPF-based routing without extra proxy hops
7. **Consistent IPAM**: Single source of truth for all IP allocation
8. **Automatic Failover**: Node failures trigger automatic IP announcement from another node
9. **Advanced Routing**: eBPF-based L7 routing with full observability via Hubble

### Operational Benefits
10. **GitOps Native**: IP pools, L2 policies, Gateways, and HTTPRoutes all managed as Kubernetes resources
11. **Standard API**: Uses Kubernetes Gateway API (vendor-neutral, community standard)
12. **Migration Path**: Easy migration from Traefik IngressRoute to Gateway API HTTPRoute
13. **Future-Proof**: Gateway API is the future of Kubernetes ingress (replacing Ingress resources)

## References

- [Cilium L2 Announcements Documentation](https://docs.cilium.io/en/stable/network/l2-announcements/)
- [Cilium LoadBalancer IPAM](https://docs.cilium.io/en/stable/network/lb-ipam/)
- [Gateway API Specification](https://gateway-api.sigs.k8s.io/)
