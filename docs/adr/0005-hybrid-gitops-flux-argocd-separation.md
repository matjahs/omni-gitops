# ADR-0005: Hybrid GitOps with Flux CD and ArgoCD Separation

## Status

Accepted

## Date

2025-10-05

## Context

The cluster uses both Flux CD and ArgoCD for GitOps deployments. Without clear boundaries, these tools can conflict by:
- **Reconciliation loops**: Both tools attempting to manage the same resources
- **Deployment conflicts**: Race conditions during simultaneous updates
- **Audit confusion**: Unclear which tool deployed what
- **Unexpected rollbacks**: One tool undoing the other's changes
- **Resource waste**: Duplicate reconciliation of the same resources

We needed to decide how to structure the repository to leverage both tools' strengths while preventing conflicts.

### Options Considered

#### Option 1: Single Tool (Flux CD Only)
Use only Flux CD for all deployments.

**Pros:**
- Simpler architecture
- No conflict potential
- Single reconciliation loop

**Cons:**
- Less visibility into application status
- Flux UI less mature than ArgoCD
- Limited sync options compared to ArgoCD
- No progressive delivery features

#### Option 2: Single Tool (ArgoCD Only)
Use only ArgoCD for all deployments.

**Pros:**
- Excellent UI for app visibility
- Rich sync policies and health checks
- Progressive delivery support
- Better multi-environment support

**Cons:**
- ArgoCD less suitable for CRD management
- Infrastructure as Code less clean
- No native Helm Controller
- More complex for platform resources

#### Option 3: Hybrid Approach with Clear Separation
Use Flux for infrastructure, ArgoCD for applications, with enforced boundaries.

**Pros:**
- Leverage each tool's strengths
- Flux excellent for infrastructure/CRDs
- ArgoCD excellent for applications
- Clear ownership boundaries
- Tool-specific optimizations

**Cons:**
- More complex architecture
- Requires protection mechanisms
- Two tools to maintain
- Learning curve for both

## Decision

We will use a **hybrid GitOps approach** with strict separation:

**Flux CD** manages infrastructure (`flux/` directory):
- Platform-level resources (CRDs, cluster-wide configurations)
- Base infrastructure services (External Secrets, storage, networking)
- Bootstraps ArgoCD itself
- Volume snapshot CRDs
- Gateway API routes for Flux UI

**ArgoCD** manages applications (`apps/`, `applications/`, `clusters/` directories):
- Application workloads and microservices
- Environment-specific deployments (overlays)
- App-of-Apps pattern for multi-application orchestration
- Better UI for application visibility and status

### Protection Mechanisms

**Two-way protection** prevents conflicts:

#### Flux Protection from ArgoCD
1. **`.argocdignore`**: Root-level file excludes `flux/` and `flux/**`
2. **`flux/.argocd-source.yaml`**: Explicit ArgoCD exclusion marker
3. **`flux/.gitkeep`**: Warning documentation for developers

#### ArgoCD Protection from Flux
1. **`.sourceignore`**: Root-level file excludes `apps/`, `applications/`, `clusters/`
2. **`.fluxignore`**: Explicit Flux exclusion markers in ArgoCD directories
3. **Kustomization path restriction**: `flux-apps` Kustomization uses `path: ./flux`

## Consequences

### Positive

- **Clear ownership**: No ambiguity about which tool manages what
- **No conflicts**: Protection mechanisms prevent reconciliation loops
- **Tool optimization**: Each tool used for its strengths
  - Flux: Infrastructure, CRDs, bootstrapping
  - ArgoCD: Applications, multi-environment, progressive delivery
- **Better visibility**: ArgoCD UI for app status, Flux for infrastructure
- **Scalability**: Can scale each tool's usage independently
- **Audit clarity**: Tool-specific logs and events
- **Team alignment**: Infrastructure team uses Flux, app teams use ArgoCD

### Negative

- **Increased complexity**: Two tools to understand and maintain
- **More protection files**: `.argocdignore`, `.sourceignore`, `.fluxignore` markers
- **Documentation overhead**: Need to document boundaries clearly
- **Onboarding complexity**: New team members must learn both tools
- **Resource usage**: Two reconciliation controllers running

### Neutral

- **Monitoring**: Need to monitor health of both Flux and ArgoCD
- **Upgrades**: Two upgrade paths to maintain
- **RBAC**: Different RBAC models for each tool

### Migration Notes

The following protection files were created:
- `.argocdignore` (root)
- `.sourceignore` (root, updated)
- `flux/.argocd-source.yaml`
- `flux/.gitkeep`
- `apps/.fluxignore`
- `applications/.fluxignore`

Documentation added:
- `flux/README.md` - Flux structure and protection
- `apps/README.md` - Application manifests guide
- `applications/README.md` - ArgoCD Application definitions
- `AGENTS.md` - Repository architecture section

### Verification

To verify protection is working:

```bash
# Verify Flux ignores ArgoCD directories
kubectl get kustomization -n flux-system flux-apps -o yaml | grep path
# Should show: path: ./flux

# Verify no Flux resources in apps/
kubectl get helmrelease,kustomization -A | grep -E "apps/|applications/"
# Should return nothing

# Verify no ArgoCD apps pointing to flux/
kubectl get application -n argocd -o yaml | grep "path: flux"
# Should return nothing
```

## References

- [Flux Best Practices](https://fluxcd.io/flux/guides/repository-structure/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [GitOps with Multiple Tools](https://www.weave.works/blog/managing-helm-releases-the-gitops-way)
