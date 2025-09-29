# Omni GitOps Platform

A production-ready Kubernetes platform running on Talos OS with GitOps automation via ArgoCD.

## Overview

This repository contains the complete infrastructure-as-code for a homelab Kubernetes cluster built with:

- **Talos OS** - Immutable Kubernetes OS
- **Sidero Omni** - Cluster lifecycle management
- **ArgoCD** - GitOps continuous delivery
- **Traefik** - Ingress controller with automatic HTTPS
- **MetalLB** - Load balancer for bare metal
- **vSphere** - Virtualization platform

## Quick Start

```bash
# Bootstrap the entire platform
./bootstrap.sh

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

> If this keeps dropping the port-forward, use a NodePort instead.

Open https://localhost:8080 and retrieve admin password:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Platform Access

| Service | URL                                                      | Purpose            |
| ------- | -------------------------------------------------------- | ------------------ |
| ArgoCD  | https://cd.apps.lab.mxe11.nl                             | GitOps dashboard   |
| Traefik | https://traefik.apps.lab.mxe11.nl/dashboard              | Ingress dashboard  |
| Omni    | https://matjahs.eu-central-1.omni.siderolabs.io/cluster1 | Cluster management |
| vCenter | https://vc01.lab.mxe11.nl/ui                             | Infrastructure     |
| ESX     | https://esxi.mxe11.nl                                    | Infrastructure     |

## Repository Structure

```
├── bootstrap.sh              # Single-command platform deployment
├── platform/                 # Core platform applications (ArgoCD manages these)
│   ├── argocd.yaml           # ArgoCD manages itself
│   ├── traefik.yaml          # Ingress controller
│   ├── metallb.yaml          # Load balancer
│   └── metrics-server.yaml   # Resource metrics
├── apps/                     # Application definitions
│   ├── traefik/base/         # Base Traefik configuration
│   ├── metrics-server/base/  # Base metrics-server setup
│   └── */overlays/production # Environment-specific overrides
├── clusters/dev/             # Talos cluster configuration
└── bootstrap/argocd/         # ArgoCD bootstrap manifests
```

## How It Works

1. **Bootstrap** - `./bootstrap.sh` installs ArgoCD and applies platform applications
2. **GitOps Loop** - ArgoCD monitors this repository and automatically deploys changes
3. **Self-Managing** - ArgoCD manages its own configuration via the `platform/argocd.yaml` application
4. **Environment Promotion** - Changes flow from `base/` → `overlays/production`

## Adding New Applications

1. Create application structure in `apps/your-app/`
2. Add ArgoCD Application manifest to `platform/your-app.yaml`
3. Commit and push - ArgoCD handles the rest

## Prerequisites

- Talos OS cluster managed by Sidero Omni
- kubectl configured for cluster access
- Internet connectivity for image pulls

## Documentation

- [Architecture & Design](architecture.md)
- [Installation Guide](installation.md)
- [Platform Components](platform-components.md)
- [Application Deployment](application-deployment.md)
- [Troubleshooting](troubleshooting.md)

## Cluster Information

- **Nodes**: 3x control planes (HA setup)
- **Network**: 172.16.20.0/24
- **Load Balancer Range**: 172.16.20.100-150
- **Kubernetes Version**: v1.34.1
- **Talos Version**: v1.11.1
- **Omni Version**: v1.4.1
