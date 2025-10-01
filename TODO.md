## ArgoCD Automation & Templates

- [ ] Create script to generate ArgoCD Applications
- [ ] Create script to generate ArgoCD AppProjects and RBAC policies
- [ ] Add templates for common application patterns
- [ ] Update documentation with helper script usage

## ArgoCD Automation & Templates

- [ ] Create script to generate ArgoCD Applications
- [ ] Create script to generate ArgoCD AppProjects and RBAC policies
- [ ] Add templates for common application patterns
- [ ] Update documentation with helper script usage


- [ ] Create script to generate ArgoCD Applications
- [ ] Create script to generate ArgoCD AppProjects and RBAC policies
- [ ] Add templates for common application patterns
- [ ] Update documentation with helper script usage
# TODO

- [x] deploy HashiCorp Vault integration (http://vault.mxe11.nl:8200)
- [ ] maybe consul?
- [x] ACME (cert-manager with Cloudflare DNS-01)
- [ ] Wildcard certificate for *.apps.lab.mxe11.nl
- [ ] integrate with ADCS/Vault for PKI
- [ ] RBAC
- [ ] customer namespace (vCluster + ?)
- [x] Monitoring stack (Prometheus + Grafana)
- [ ] Create ingress for Longhorn dashboard
- [ ] Uptime Kuma

## ArgoCD Apps

- [x] cert-manager
- [ ] hubble-ui
- [x] metallb
- [x] metrics-server
- [ ] shared
- [x] traefik
- [ ] vault
- [x] monitoring (kube-prometheus-stack)
- [x] persistent storage (Rook Ceph)

## Priority 2: Force Delete Stuck Namespace

- [x] longhorn-system namespace successfully deleted

## Prority 3: Align Applications with repo

- [ ] metallb - Currently points to https://metallb.github.io/metallb
- [ ] traefik - Currently points to https://traefik.github.io/charts
- [ ] rook-ceph-* - Currently points to https://charts.rook.io/release
- [ ] Replace them with your applications/*.yaml files.


## Priority 4: Add Missing Applications

From your repo but not deployed:

- [x] external-secrets
- [x] external-secrets-config
- [ ] hubble-ui

## Wishlist

- [ ] `external-dns` -> technitium server on `172.16.0.53`
- [ ] 1password integration
- [ ] keycloak integration
