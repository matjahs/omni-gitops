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


## Cilium & Flux Recovery Cheatsheet

### Full Flux Reset
1. flux suspend kustomization flux-system || true
2. flux uninstall --namespace flux-system --keep-namespace=false
3. kubectl delete namespace flux-system --ignore-not-found
4. (Optional) Remove Flux CRDs:
   kubectl get crds | grep -E 'kustomize.toolkit.fluxcd.io|source.toolkit.fluxcd.io|helm.toolkit.fluxcd.io|notification.toolkit.fluxcd.io' | awk '{print $1}' | xargs -r kubectl delete crd
5. Re-bootstrap:
   flux bootstrap github --owner matjahs --repository omni-gitops --branch main --path flux --personal
6. Verify & force sync:
   flux get kustomizations
   flux reconcile kustomization flux-system --with-source

### Cilium CRDs Missing / Agent Timeouts
Symptoms: Pod sandbox create failures, cilium-agent logs show 'could not find the requested resource' for Cilium* CRDs.

Fix (manual quick):
1. kubectl get crds | grep cilium || echo "No Cilium CRDs"
2. helm repo add cilium https://helm.cilium.io && helm repo update
3. helm upgrade --install cilium cilium/cilium \
   -n kube-system --create-namespace \
   --set k8sServiceHost=<API_SERVER_IP> --set k8sServicePort=6443 \
   --set kubeProxyReplacement=strict
4. kubectl -n kube-system get pods -l k8s-app=cilium
5. After Ready: kubectl delete pod -n kube-system -l k8s-app=cilium (to recreate any failed endpoints)

GitOps-managed approach:
- Manage a Cilium HelmRelease under flux/infrastructure first; ensure its CRDs apply before app namespaces depending on Cilium policies.
- If reinstalling via Flux, delete leftover cilium* CRDs only if versions drift, then let HelmRelease recreate.

### ExternalSecret Ordering
- Managed entirely by ArgoCD; operator + CRDs installed via applications/external-secrets.yaml.
- Flux no longer deploys external-secrets; remove any stale HelmRelease before relying on Argo config.

## Flux Layered Kustomization Flow

Text diagram:

GitRepository flux-system
  ├─ Kustomization flux-gateway (Gateway API CRDs)
  │    provides: gateway.networking.k8s.io/* (HTTPRoute, Gateway, etc.)
  ├─ Kustomization flux-secrets-config (ClusterSecretStore, ExternalSecrets references)  # now only ESO consumer manifests if any remain under flux/
  ├─ Kustomization flux-infra (remaining infra: snapshot CRDs, etc.)
  │    independent but ordered before apps
  └─ Kustomization flux-apps (workload HelmReleases / manifests)
       dependsOn: flux-infra

Mermaid:

```mermaid
graph TD
  A[GitRepository flux-system]
  A --> B[flux-gateway\nGateway API CRDs]
  B --> D[flux-secrets-config\n(ClusterSecretStore / ExternalSecrets)]
  D --> E[flux-infra\nOther infra]
  E --> F[flux-apps\nWorkloads]
```

Readiness contract:
1. CRDs first (gateway, external-secrets via ArgoCD)
2. Configuration objects referencing those CRDs
3. Supporting infra controllers
4. Application workloads

Troubleshooting order:
1. flux get kustomization flux-gateway
2. (deprecated) remove any leftover flux-external-secrets Kustomization if present
3. kubectl get crds | grep -E 'gateway.networking|external-secrets'
4. flux get kustomization flux-secrets-config
5. flux get kustomization flux-infra
6. flux get kustomization flux-apps
