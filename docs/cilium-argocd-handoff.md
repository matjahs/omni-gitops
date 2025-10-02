# Cilium Management: Talos Bootstrap → ArgoCD Handoff

## Overview

This cluster uses a **two-phase approach** for managing Cilium:

1. **Phase 1 (Bootstrap)**: Talos installs Cilium via an inline manifest job to establish initial networking
2. **Phase 2 (Ongoing)**: ArgoCD adopts the existing Cilium installation and manages it declaratively

## Architecture

### Talos Bootstrap Configuration

The Talos cluster is configured with:

- **No default CNI**: [`omni/patches/30-no-default-cni.yaml`](../omni/patches/30-no-default-cni.yaml) sets `cni.name: none`
- **No kube-proxy**: [`omni/patches/31-no-default-proxy.yaml`](../omni/patches/31-no-default-proxy.yaml) sets `proxy.disabled: true`
- **Cilium installation job**: [`omni/patches/60-cilium.yaml`](../omni/patches/60-cilium.yaml) runs a Job that uses `cilium-cli` to install Cilium via Helm

### Key Configuration Details

#### Kube-Proxy Replacement

Cilium is configured with `kubeProxyReplacement: true` which means:

- Cilium's eBPF datapath handles all service load balancing
- NodePort services are handled by Cilium
- No kube-proxy pods run in the cluster
- Lower latency and better performance for service routing

This configuration is set in two places:
1. **Bootstrap**: [`omni/patches/60-cilium.yaml:81`](../omni/patches/60-cilium.yaml#L81)
2. **ArgoCD**: [`applications/cilium.yaml:49`](../applications/cilium.yaml#L49)

#### Talos-Specific Settings

Cilium requires special configuration for Talos Linux:

1. **API Server Connection**:
   ```yaml
   k8sServiceHost: localhost
   k8sServicePort: 7445
   ```
   Points to the local control plane node (Talos-specific port)

2. **Security Context**:
   ```yaml
   securityContext:
     capabilities:
       ciliumAgent:
         - CHOWN
         - KILL
         - NET_ADMIN
         # ... (full list in config files)
   ```
   Required capabilities for Cilium to function on Talos

3. **Cgroup Configuration**:
   ```yaml
   cgroup:
     autoMount:
       enabled: false
     hostRoot: /sys/fs/cgroup
   ```
   Talos manages cgroups differently than standard distributions

## ArgoCD Handoff Strategy

### How It Works

1. **Namespace Matching**: ArgoCD targets `kube-system` namespace where Talos installed Cilium
2. **Release Name Matching**: ArgoCD uses `releaseName: cilium` to adopt the existing Helm release
3. **ServerSideApply**: Enabled to handle Talos's unique security context schema
4. **Resource Exclusions**: ArgoCD ignores dynamic Cilium resources like `CiliumIdentity`

### Critical Configuration

**In [`applications/cilium.yaml`](../applications/cilium.yaml):**

```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true    # CRITICAL for Talos
    - ApplyOutOfSync=true
```

**In [`clusters/cluster1/overlays/production/argocd-cm.yaml`](../clusters/cluster1/overlays/production/argocd-cm.yaml):**

```yaml
resource.exclusions: |
  - apiGroups:
    - cilium.io
    kinds:
    - CiliumIdentity
    clusters:
    - "*"
```

### Why ServerSideApply is Required

Talos uses a different security context schema than standard Kubernetes. Without `ServerSideApply=true`, ArgoCD's client-side validation will fail with schema errors when trying to apply Cilium resources.

## Features Enabled

The following Cilium features are enabled in this cluster:

### Core Networking
- ✅ **Tunnel Mode**: VXLAN tunneling for pod networking
- ✅ **Kubernetes IPAM**: IP address management via Kubernetes
- ✅ **Kube-proxy replacement**: Full eBPF-based service load balancing

### Advanced Features
- ✅ **BGP Control Plane**: For advanced routing scenarios
- ✅ **Gateway API**: Kubernetes Gateway API support (ALPN, AppProtocol)
- ✅ **Hubble Observability**:
  - Hubble Relay for distributed observability
  - Hubble UI with ingress (accessible via configured hostname)
  - Metrics: DNS, packet drops, TCP flows, port distribution

### Observability

Hubble UI is exposed via ingress at the hostname specified in the secret variable `cilium_hostname`. The ingress is configured with:

- TLS certificate via cert-manager
- Cluster issuer specified by `global_cluster_issuer` template variable

## Version Management

- **Current Version**: 1.18.1 (installed by Talos)
- **Target Version**: 1.18.2 (managed by ArgoCD)
- **Upgrade Strategy**: ArgoCD will perform a rolling upgrade from 1.18.1 → 1.18.2 on first sync

## Verification Steps

### Check Current Installation

```bash
# View Cilium status
cilium status

# Check Helm release
helm list -n kube-system

# Get current Cilium configuration
cilium config view

# View Hubble metrics
kubectl get pods -n kube-system -l app.kubernetes.io/name=hubble-ui
```

### Verify ArgoCD Adoption

```bash
# Check ArgoCD application status
argocd app get cilium-helm-release

# Verify sync status
argocd app sync cilium-helm-release --dry-run

# Check for any sync issues
kubectl get application cilium-helm-release -n argocd -o yaml
```

### Validate Kube-Proxy Replacement

```bash
# Should return no kube-proxy pods
kubectl get pods -n kube-system -l k8s-app=kube-proxy

# Verify Cilium is handling services
cilium service list

# Check BPF maps
cilium bpf lb list
```

## Troubleshooting

### Issue: ArgoCD Shows OutOfSync

**Symptom**: ArgoCD shows the application as OutOfSync even though no changes were made.

**Cause**: Dynamic Cilium resources (like `CiliumIdentity`) are constantly updated.

**Solution**: Ensure resource exclusions are configured in `argocd-cm` ConfigMap.

### Issue: Sync Fails with Schema Validation Error

**Symptom**: ArgoCD sync fails with errors about invalid security context fields.

**Cause**: Missing `ServerSideApply=true` sync option.

**Solution**: Verify `ServerSideApply=true` is present in [`applications/cilium.yaml`](../applications/cilium.yaml#L30).

### Issue: Dual Cilium Installations

**Symptom**: Two sets of Cilium pods running (in `kube-system` and `cilium` namespaces).

**Cause**: Namespace mismatch between Talos installation and ArgoCD config.

**Solution**: Ensure ArgoCD targets `kube-system` namespace and uses `releaseName: cilium`.

## Configuration References

### Files Involved

| File | Purpose |
|------|---------|
| [`omni/patches/30-no-default-cni.yaml`](../omni/patches/30-no-default-cni.yaml) | Disables Talos default CNI |
| [`omni/patches/31-no-default-proxy.yaml`](../omni/patches/31-no-default-proxy.yaml) | Disables kube-proxy |
| [`omni/patches/60-cilium.yaml`](../omni/patches/60-cilium.yaml) | Cilium bootstrap job |
| [`applications/cilium.yaml`](../applications/cilium.yaml) | ArgoCD ApplicationSet for Cilium |
| [`clusters/cluster1/overlays/production/argocd-cm.yaml`](../clusters/cluster1/overlays/production/argocd-cm.yaml) | ArgoCD resource exclusions |

### Configuration Alignment

The following table shows how configuration values align between Talos bootstrap and ArgoCD:

| Setting | Talos Bootstrap | ArgoCD Managed | Status |
|---------|----------------|----------------|--------|
| `ipam.mode` | `kubernetes` | `kubernetes` | ✅ Aligned |
| `kubeProxyReplacement` | `true` | `true` | ✅ Aligned |
| `k8sServiceHost` | `localhost` | `localhost` | ✅ Aligned |
| `k8sServicePort` | `7445` | `7445` | ✅ Aligned |
| `routingMode` | (default) | `tunnel` | ✅ Aligned |
| `tunnelProtocol` | (default) | `vxlan` | ✅ Aligned |
| `bgpControlPlane.enabled` | `true` | `true` | ✅ Aligned |
| `gatewayAPI.enabled` | `true` | `true` | ✅ Aligned |
| `hubble.enabled` | `true` | `true` | ✅ Aligned |
| `operator.replicas` | (default) | `1` | ✅ Aligned |

## Best Practices

1. **Never edit Cilium resources directly**: All changes should go through ArgoCD
2. **Test upgrades in dev first**: Cilium upgrades can be disruptive
3. **Monitor Hubble metrics**: Watch for packet drops or policy violations
4. **Keep Talos and ArgoCD configs aligned**: Changes to bootstrap config should be reflected in ArgoCD
5. **Use GitOps workflow**: All configuration changes should be committed to Git first

## Future Improvements

Potential enhancements to consider:

- [ ] Enable Cilium Network Policies for pod-to-pod security
- [ ] Configure Cilium Ingress Controller (alternative to existing ingress)
- [ ] Enable ClusterMesh for multi-cluster connectivity
- [ ] Configure service mesh features (mutual TLS, L7 policies)
- [ ] Set up Cilium Tetragon for runtime security
- [ ] Enable IPv6 dual-stack support
- [ ] Configure egress gateway for specific workloads
