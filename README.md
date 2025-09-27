# omni-ops




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
