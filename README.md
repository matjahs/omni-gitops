# omni-ops

[![Cert Manager App Status](https://cd.apps.lab.mxe11.nl/api/badge?name=cert-manager&revision=true&showAppName=true)](https://cd.apps.lab.mxe11.nl/applications/cert-manager)
[![MetalLB App Status](https://cd.apps.lab.mxe11.nl/api/badge?name=metallb&revision=true&showAppName=true)](https://cd.apps.lab.mxe11.nl/applications/metallb)
[![Metrics Server App Status](https://cd.apps.lab.mxe11.nl/api/badge?name=metrics-server&revision=true&showAppName=true)](https://cd.apps.lab.mxe11.nl/applications/metrics-server)
[![Traefik App Status](https://cd.apps.lab.mxe11.nl/api/badge?name=traefik&revision=true&showAppName=true)](https://cd.apps.lab.mxe11.nl/applications/traefik)
[![Uptime Kuma App Status](https://cd.apps.lab.mxe11.nl/api/badge?name=uptime-kuma&revision=true&showAppName=true)](https://cd.apps.lab.mxe11.nl/applications/uptime-kuma)
## ArgoCD GitOps Structure

```
├── apps/
│   ├── argocd/
│   │   ├── base/
│   │   │   ├── kustomization.yaml
│   │   │   ├── namespace.yaml
│   │   │   └── install.yaml
│   │   └── overlays/
│   │       └── production/
│   │           ├── kustomization.yaml
│   │           ├── argocd-server-patch.yaml
│   │           └── argocd-config.yaml
│   └── metrics-server/
│       └── ...
└── applications/
    ├── kustomization.yaml
    ├── argocd.yaml           # ArgoCD manages itself
    └── metrics-server.yaml
```
