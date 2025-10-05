# AGENTS.md

## Repository Architecture

### Hybrid GitOps: Flux CD + ArgoCD

This repository uses a **hybrid GitOps approach** with clear separation between tools:

**Flux CD** manages infrastructure (`flux/` directory):
- Platform-level resources (CRDs, cluster-wide configs)
- Base infrastructure services (secrets, networking, storage)
- Bootstraps ArgoCD itself
- Path: `./flux` (restricted via Kustomization)

**ArgoCD** manages applications (`apps/`, `applications/` directories):
- Application workloads and microservices
- Environment-specific deployments
- App-of-Apps pattern for multi-app orchestration
- Better UI for application visibility

### ⚠️ Two-Way Protection Mechanisms

**ArgoCD cannot deploy from `flux/`:**
- `.argocdignore` excludes `flux/` and `flux/**`
- `flux/.argocd-source.yaml` explicit exclusion marker
- `flux/.gitkeep` warning documentation

**Flux cannot deploy from `apps/`, `applications/`, `clusters/`:**
- `.sourceignore` excludes these directories
- `.fluxignore` markers in each directory
- `flux-apps` Kustomization uses `path: ./flux` (explicit scope limit)

**Why this matters:**
Running both tools on the same resources causes reconciliation loops, deployment conflicts, and audit confusion. Two-way protection ensures clear ownership boundaries and predictable behavior.

### Directory Structure

```
.
├── flux/                  # ⚠️ FLUX CD ONLY
│   ├── infrastructure/    # Platform resources (CRDs, secrets, networking)
│   └── apps/             # Flux-managed apps (minimal - mostly infra)
├── apps/                  # ⚠️ ARGOCD ONLY - Application manifests
│   ├── argocd/           # ArgoCD deployment
│   ├── monitoring/       # Prometheus/Grafana
│   └── ...               # Other applications
├── applications/          # ⚠️ ARGOCD ONLY - ArgoCD Application definitions
└── clusters/             # ⚠️ ARGOCD ONLY - Cluster-specific configs
```

### Adding Resources

**For infrastructure/platform resources:**
- Add to `flux/infrastructure/` or `flux/apps/`
- See: `flux/README.md`

**For application workloads:**
- Add manifests to `apps/<app-name>/`
- Create ArgoCD Application in `applications/<app-name>.yaml`
- See: `apps/README.md` and `applications/README.md`

## Code Style

- Avoid abbreviations in variable names
- Use descriptive names for Kubernetes resources

## Testing

- All commits must pass lint checks via Prettier
- Validate Kustomize builds: `kubectl kustomize flux/`
- Check ArgoCD Application syntax before committing

## PR Instructions

- Title format: "fix: <short description>" or "feat: <description>"
- Include a one-line summary and a "Testing done" section
- For GitOps changes, validate with dry-run before merging
