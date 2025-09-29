# Platform Architecture

## Overview

This platform follows cloud-native principles with immutable infrastructure and GitOps automation. The design prioritizes reliability, security, and operational simplicity.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    vSphere Infrastructure               │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐      │
│  │   node01    │ │   node02    │ │   node03    │      │
│  │ 172.16.20.51│ │ 172.16.20.52│ │ 172.16.20.53│      │
│  └─────────────┘ └─────────────┘ └─────────────┘      │
└─────────────────────────────────────────────────────────┘
                             │
┌─────────────────────────────────────────────────────────┐
│                    Talos OS Layer                      │
│  • Immutable OS with API-driven configuration          │
│  • Managed by Sidero Omni                             │
│  • Kubernetes v1.34.1                                 │
└─────────────────────────────────────────────────────────┘
                             │
┌─────────────────────────────────────────────────────────┐
│                   Network Layer                        │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐      │
│  │   Cilium    │ │   MetalLB   │ │   Traefik   │      │
│  │     CNI     │ │Load Balancer│ │   Ingress   │      │
│  └─────────────┘ └─────────────┘ └─────────────┘      │
└─────────────────────────────────────────────────────────┘
                             │
┌─────────────────────────────────────────────────────────┐
│                 Application Layer                      │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐      │
│  │   ArgoCD    │ │Metrics-Server│ │Custom Apps  │      │
│  │   GitOps    │ │   Metrics   │ │  (Future)   │      │
│  └─────────────┘ └─────────────┘ └─────────────┘      │
└─────────────────────────────────────────────────────────┘
```

## Key Design Decisions

### Talos OS + Sidero Omni

**Why Talos OS:**
- Immutable OS designed for Kubernetes
- API-driven configuration (no SSH access)
- Minimal attack surface
- Automatic security updates

**Why Sidero Omni:**
- Centralized cluster lifecycle management
- Declarative cluster configuration
- GitOps-friendly machine management
- Professional support model

### GitOps with ArgoCD

**Self-Managing Pattern:**
- ArgoCD manages its own configuration
- Platform applications managed by ArgoCD
- Single source of truth in Git
- Automatic drift detection and remediation

**Repository Structure:**
- `platform/` - Core infrastructure components
- `apps/` - Application definitions with base/overlay pattern
- `clusters/` - Talos machine configurations
- `bootstrap/` - Initial ArgoCD installation

### Network Architecture

**CNI: Cilium**
- eBPF-based networking and security
- BGP integration capability
- Hubble observability
- Gateway API support

**Load Balancing: MetalLB**
- Layer 2 mode for bare metal
- IP range: 172.16.20.100-150
- Integrates with Cilium BGP (future)

**Ingress: Traefik**
- Automatic HTTPS with Let's Encrypt
- Dashboard for troubleshooting
- Kubernetes Ingress + CRD support
- Metrics integration

## Security Model

### Network Security
- CNI network policies via Cilium
- Traefik TLS termination
- No NodePort services exposed
- Cluster-internal service discovery

### Platform Security
- Talos OS immutable filesystem
- No SSH access to nodes
- Service accounts with minimal permissions
- Container security contexts enforced

### GitOps Security
- GitHub integration with RBAC
- Signed commits (recommended)
- Branch protection rules
- Audit trail in Git history

## High Availability

### Control Plane
- 3 control plane nodes
- etcd distributed across nodes
- VIP for API server access (172.16.20.250)
- Automatic leader election

### Application Resilience
- Multiple replicas for critical services
- Pod disruption budgets
- Priority classes for system components
- Resource requests/limits defined

## Scalability Considerations

### Horizontal Scaling
- Worker nodes can be added via Omni
- MetalLB IP pool can be expanded
- ArgoCD scales with repository size
- Application autoscaling via HPA

### Vertical Scaling
- Talos OS supports live machine reconfiguration
- Resource limits can be adjusted in overlays
- Storage expansion through vSphere

## Observability

### Metrics
- Metrics-server for Kubernetes metrics
- Traefik Prometheus metrics
- Cilium/Hubble metrics
- ArgoCD application health

### Logging
- Talos OS structured logging
- Container logs via kubectl
- ArgoCD event tracking
- GitHub webhook notifications

## Disaster Recovery

### Backup Strategy
- etcd automated backups (1h interval)
- GitOps state in version control
- Talos machine configuration versioned
- Application data (future: Velero)

### Recovery Procedures
- Complete cluster rebuild from Git
- Individual application recovery via ArgoCD
- Machine replacement via Omni
- Configuration rollback capabilities
