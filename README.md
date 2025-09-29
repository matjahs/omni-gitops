# omni-ops

[![Build Status](https://cd.apps.lab.mxe11.nl/api/badge?name=argocd&revision=true&showAppName=true)]


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
└── platform/
    ├── kustomization.yaml
    ├── argocd.yaml           # ArgoCD manages itself
    └── metrics-server.yaml
```
