# Omni / Talos Cluster Configuration

This directory contains the Talos Linux cluster configuration managed via Omni (SaaS Talos management platform).

## Overview

The cluster is defined using Omni's declarative template format, which generates the underlying Talos machine configurations. The configuration is split into:

- **cluster-template.yaml**: Main cluster definition
- **patches/**: Modular configuration patches applied to control plane and/or worker nodes

## Cluster Specification

| Property | Value |
|----------|-------|
| Cluster Name | cluster1 |
| Kubernetes Version | v1.34.1 |
| Talos Version | v1.11.1 |
| Control Plane Nodes | 3 (node01, node02, node03) |
| Worker Nodes | 0 (control planes are schedulable) |
| CNI | Cilium (managed separately) |
| Kube-proxy | Disabled (Cilium replaces it) |

## Architecture Decisions

### CNI: Cilium

The cluster uses Cilium as the Container Network Interface, installed via a bootstrap job:

- **Why Cilium?**
  - eBPF-based for superior performance
  - Integrated kube-proxy replacement
  - Advanced features: BGP, Gateway API, Hubble observability
  - Excellent Talos Linux compatibility

- **Installation Method**: Kubernetes Job running `cilium-cli install`
  - Runs on first control plane boot
  - See: [`patches/60-cilium.yaml`](patches/60-cilium.yaml)

### Kube-Proxy: Disabled

Kube-proxy is explicitly disabled because Cilium provides a more efficient replacement:

- **Benefits of Cilium kube-proxy replacement**:
  - Lower latency (eBPF vs iptables)
  - Better scalability (no iptables rule explosion)
  - More features (DSR, Maglev hashing, etc.)

- **Configuration**:
  - Disabled in Talos: [`patches/31-no-default-proxy.yaml`](patches/31-no-default-proxy.yaml)
  - Cilium configured with `kubeProxyReplacement: true`

### Control Plane Scheduling

Control plane nodes are configured to allow regular workloads:

```yaml
cluster:
  allowSchedulingOnControlPlanes: true
```

This is suitable for homelab/small clusters where dedicated workers aren't needed.

## Configuration Patches

Patches are applied in order. The patch ID prefix (e.g., `10-`, `20-`) determines application order.

### Network Configuration

| Patch | Purpose | Details |
|-------|---------|---------|
| `10-kubespan.yaml` | KubeSpan WireGuard mesh | Encrypted node-to-node communication |
| `30-no-default-cni.yaml` | Disable default CNI | Sets `cni.name: none` |
| `31-no-default-proxy.yaml` | Disable kube-proxy | Sets `proxy.disabled: true` |
| `60-cilium.yaml` | Install Cilium | Bootstrap job with Helm-based install |

### System Configuration

| Patch | Purpose | Details |
|-------|---------|---------|
| `20-sysctls.yaml` | Kernel parameters | System-level tuning (if present) |
| `50-loadbalancer-exclusion.yaml` | VIP configuration | Excludes certain IPs from load balancing |
| `70-node-labels.yaml` | Node labels | Custom Kubernetes node labels |
| `80-data-paths.yaml` | Storage paths | Custom volume mount paths |

### Bootstrap Configuration

| Patch | Purpose | Details |
|-------|---------|---------|
| `40-extra-manifests-flux.yaml` | Flux GitOps | Bootstrap Flux CD (if used) |

## Patch Details

### 60-cilium.yaml - Cilium Installation

This is the most critical patch. It creates a Kubernetes Job that:

1. Runs on a control plane node (using node affinity)
2. Uses the `quay.io/cilium/cilium-cli:latest` image
3. Executes `cilium install` with specific flags
4. Configures Cilium for Talos compatibility

**Key Configuration Values**:

```yaml
- ipam.mode=kubernetes
- kubeProxyReplacement=true
- k8sServiceHost=localhost
- k8sServicePort=7445
- cgroup.autoMount.enabled=false
- cgroup.hostRoot=/sys/fs/cgroup
- gatewayAPI.enabled=true
- hubble.enabled=true
- bgpControlPlane.enabled=true
```

**Talos-Specific Settings**:

- `k8sServiceHost=localhost` and `k8sServicePort=7445`: Points to local API server
- `cgroup.autoMount.enabled=false`: Talos manages cgroups
- Custom security context capabilities for Talos

**Why a Job instead of Helm/manifests?**

- Ensures Cilium is installed before other workloads
- `cilium-cli` handles CRD installation and validation
- Retries automatically on failure (backoffLimit: 10)

## Control Plane Configuration

The control plane consists of 3 nodes with a Virtual IP (VIP) for HA:

- **VIP**: `172.16.20.250`
- **Nodes**:
  - node01: `172.16.20.51`
  - node02: `172.16.20.52`
  - node03: `172.16.20.53`

The VIP is configured in the inline patch `400-cluster1-control-planes` and provides a stable endpoint for the Kubernetes API server.

## Machine Configuration

Each machine has individual configuration for:

- **Install disk**: `/dev/sda`
- **Static networking**: Fixed IP addresses
- **DNS servers**: `172.16.0.53`
- **Search domains**: `lab.mxe11.nl`, `corp.mxe11.nl`, `mxe11.nl`

### System Extensions

All machines are configured with:

- `siderolabs/iscsi-tools`: For iSCSI storage
- `siderolabs/mdadm`: For software RAID
- `siderolabs/util-linux-tools`: Additional Linux utilities
- `siderolabs/vmtoolsd-guest-agent`: VMware guest tools (if running on VMware)

## Upgrade Process

### Kubernetes Upgrade

```bash
# In Omni UI:
# 1. Update cluster-template.yaml with new kubernetes.version
# 2. Apply the template
# 3. Omni will perform rolling upgrade
```

### Talos Upgrade

```bash
# In Omni UI:
# 1. Update cluster-template.yaml with new talos.version
# 2. Apply the template
# 3. Omni will perform rolling upgrade of nodes
```

### Cilium Upgrade

After bootstrap, Cilium is managed by ArgoCD:

1. Update `applications/cilium.yaml` with new `targetRevision`
2. Commit and push to Git
3. ArgoCD will perform rolling upgrade

See: [docs/cilium-argocd-handoff.md](../docs/cilium-argocd-handoff.md)

## Backup Configuration

Omni is configured to backup etcd automatically:

```yaml
features:
  backupConfiguration:
    interval: 1h0m0s
```

Backups are stored in Omni's managed S3 bucket and can be restored via the Omni UI.

## Network Topology

```
┌─────────────────────────────────────────────────┐
│          VIP: 172.16.20.250                     │
│    (Kubernetes API Server LoadBalancer)         │
└─────────────────────────────────────────────────┘
                      │
        ┌─────────────┼─────────────┐
        │             │             │
   ┌────▼───┐    ┌───▼────┐    ┌───▼────┐
   │ node01 │    │ node02 │    │ node03 │
   │ .51    │    │ .52    │    │ .53    │
   └────────┘    └────────┘    └────────┘
        │             │             │
        └─────────────┼─────────────┘
                      │
              ┌───────▼────────┐
              │ Cilium VXLAN   │
              │  Mesh Network  │
              │   (Pod CIDR)   │
              └────────────────┘
```

## Troubleshooting

### Cilium fails to install

1. Check the cilium-install Job logs:
   ```bash
   kubectl logs -n kube-system job/cilium-install
   ```

2. Verify the inline manifest is correct:
   ```bash
   talosctl get machineconfig -o yaml | grep -A 100 cilium-install
   ```

3. Manually run cilium install:
   ```bash
   cilium install --set ipam.mode=kubernetes --set kubeProxyReplacement=true ...
   ```

### VIP not responding

1. Check node health:
   ```bash
   talosctl health --nodes 172.16.20.51,172.16.20.52,172.16.20.53
   ```

2. Verify VIP configuration:
   ```bash
   talosctl get machineconfig -o yaml | grep -A 5 vip
   ```

### Node can't join cluster

1. Check if CNI is working:
   ```bash
   kubectl get pods -n kube-system -l k8s-app=cilium
   ```

2. Verify node can reach API server:
   ```bash
   talosctl -n <node-ip> get members
   ```

## References

- [Talos Documentation](https://www.talos.dev/)
- [Omni Documentation](https://omni.siderolabs.com/docs/)
- [Cilium on Talos](https://www.talos.dev/latest/kubernetes-guides/network/deploying-cilium/)
- [KubeSpan](https://www.talos.dev/latest/talos-guides/network/kubespan/)
