# Prerequisites

## Infrastructure Requirements

### Virtualization Platform
- **vSphere 7.0+** with vCenter Server
- **Resource allocation:**
  - 3 VMs minimum (control planes)
  - 4 vCPU, 8GB RAM per VM minimum
  - 100GB storage per VM
  - VM hardware version 15+

### Network Requirements
- **IP range:** 172.16.20.0/24 available
- **Internet connectivity** for:
  - Container image pulls
  - Let's Encrypt certificate requests
  - GitHub repository access
  - Sidero Omni API access
- **DNS resolution** for:
  - `*.apps.lab.mxe11.nl` (wildcard domain)
  - External package repositories
  - Container registries

### Storage Requirements
- **Shared storage** recommended for VM live migration
- **Backup solution** for VM snapshots
- **Fast disk** (SSD preferred) for etcd performance

## Access Requirements

### Sidero Omni
- **Account** at [Omni Cloud](https://omni.siderolabs.io/)
- **Cluster management permissions**
- **Machine registration** capabilities
- **API access** for automation (optional)

### GitHub Access
- **Repository access** to https://github.com/matjahs/omni-gitops
- **Personal access token** for ArgoCD integration (optional)
- **Organization membership** for SSO (if using GitHub auth)

### Domain & DNS
- **Domain ownership** of `lab.mxe11.nl`
- **DNS management** capabilities for:
  - `cd.apps.lab.mxe11.nl` (ArgoCD)
  - `traefik.apps.lab.mxe11.nl` (Traefik dashboard)
  - Wildcard or individual app subdomains

## Client Tools

### Required Tools
```bash
# Kubernetes CLI
kubectl version --client

# Git client
git --version

# curl for testing
curl --version

# base64 for secret decoding
base64 --version
```

### Optional Tools
```bash
# ArgoCD CLI
argocd version

# Helm CLI (for debugging Helm apps)
helm version

# k9s for cluster navigation
k9s version

# Talosctl for cluster debugging
talosctl version
```

### Tool Installation

**kubectl:**
```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

**ArgoCD CLI:**
```bash
# macOS
brew install argocd

# Linux
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
```

## Network Configuration

### Required Ports
| Port | Protocol | Source | Destination | Purpose |
|------|----------|--------|-------------|---------|
| 6443 | TCP | Admin workstation | Kubernetes API | kubectl access |
| 50000 | TCP | Omni | Cluster nodes | Talos API |
| 80/443 | TCP | Internet | Load balancer IPs | Application access |

### Firewall Rules
- **Outbound HTTPS (443)** from cluster to internet
- **Inbound HTTP/HTTPS** to load balancer range
- **Internal cluster communication** (all ports between nodes)

### Load Balancer IP Pool
Reserve IP range for MetalLB:
- **Range:** 172.16.20.100-172.16.20.150
- **Gateway:** 172.16.20.1
- **DNS servers:** 172.16.0.53

## Security Requirements

### Certificates
- **Let's Encrypt** account (automatic via ACME)
- **CA certificates** trusted by client browsers
- **TLS 1.2+** support required

### Authentication
- **GitHub OAuth app** (optional, for ArgoCD SSO)
- **Service accounts** with appropriate RBAC
- **Pod security standards** enforcement

### Network Security
- **Network policies** supported by CNI (Cilium)
- **Firewall rules** for cluster ingress/egress
- **Private networks** recommended for node communication

## Performance Requirements

### Compute Resources
| Component | CPU | Memory | Replicas | Total CPU | Total RAM |
|-----------|-----|--------|----------|-----------|-----------|
| Kubernetes | 2 vCPU | 4GB | 3 nodes | 6 vCPU | 12GB |
| ArgoCD | 250m | 256Mi | 3 pods | 750m | 768Mi |
| Traefik | 200m | 100Mi | 2 pods | 400m | 200Mi |
| MetalLB | 100m | 100Mi | 1 pod | 100m | 100Mi |
| Metrics Server | 100m | 200Mi | 1 pod | 100m | 200Mi |
| **Total Platform** | | | | **7.35 vCPU** | **13.3GB** |

### Storage Performance
- **etcd:** Low latency storage (< 10ms)
- **Container images:** Fast pull times
- **Application data:** Based on application requirements

### Network Bandwidth
- **Inter-node:** 1Gbps minimum
- **Internet:** 100Mbps for image pulls
- **Client access:** Based on application load

## Environment Preparation

### vSphere Preparation
1. **Create VM templates** for Talos OS
2. **Configure networks** with appropriate VLANs
3. **Set up storage** policies for performance
4. **Prepare resource pools** for cluster VMs

### DNS Configuration
```bash
# Example DNS records
cd.apps.lab.mxe11.nl.     IN  A  172.16.20.100
traefik.apps.lab.mxe11.nl. IN  A  172.16.20.101
*.apps.lab.mxe11.nl.      IN  A  172.16.20.102
```

### Omni Preparation
1. **Register machines** in Omni inventory
2. **Prepare cluster template** with appropriate patches
3. **Configure machine classes** for consistent provisioning
4. **Set up backup schedules** for cluster state

## Validation Checklist

### Infrastructure
- [ ] vSphere environment ready with sufficient resources
- [ ] Network connectivity tested from proposed node IPs
- [ ] DNS resolution working for required domains
- [ ] Storage performance meets requirements

### Access
- [ ] Sidero Omni account configured
- [ ] GitHub repository access confirmed
- [ ] Domain DNS management available
- [ ] Client tools installed and configured

### Network
- [ ] IP range 172.16.20.0/24 available
- [ ] Load balancer range 172.16.20.100-150 reserved
- [ ] Firewall rules configured
- [ ] Internet connectivity verified

### Security
- [ ] Certificate requirements understood
- [ ] Authentication method chosen
- [ ] Security policies defined
- [ ] Network security configured

## Next Steps

After meeting all prerequisites:

1. **[Installation Guide](installation.md)** - Deploy the platform
2. **[Architecture Overview](architecture.md)** - Understand the design
3. **[Platform Components](platform-components.md)** - Learn about services
4. **[Application Deployment](application-deployment.md)** - Add applications
