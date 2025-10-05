# ADR-0006: Flux Directory Restructuring for Infrastructure and Applications

## Status

Accepted

## Date

2025-10-05

## Context

The `flux/` directory had a flat structure that mixed different concerns:
- Sources, releases, configs, and resources were scattered across separate directories
- Invalid file references in kustomization.yaml
- No clear separation between infrastructure and application resources
- Difficult to understand dependencies and deployment order
- Hard to add new applications following inconsistent patterns

### Original Structure

```
flux/
├── configs/
│   └── external-dns-rfc2136.yaml
├── httproutes/
│   ├── notification-controller-httproute.yaml
│   └── source-controller-httproute.yaml
├── releases/
│   ├── external-dns-rfc2136.yaml
│   └── synology-csi.yaml
├── resources/
│   ├── cluster-secret-store.yaml
│   ├── snapshot-crds.yaml
│   ├── synology-csi-external-secret.yaml
│   └── synology-csi-namespace.yaml
└── sources/
    ├── external-dns.yaml
    └── synology-csi.yaml
```

**Problems:**
- Related files scattered (e.g., synology-csi across sources/, releases/, resources/)
- No infrastructure vs application separation
- Invalid kustomization references to non-existent files
- No per-app kustomizations for dependency management
- Flat structure doesn't scale well

### Options Considered

#### Option 1: Keep Flat Structure
Maintain the current sources/releases/configs/resources layout, just fix broken references.

**Pros:**
- Minimal changes required
- Familiar to current maintainers

**Cons:**
- Doesn't solve fundamental organization issues
- Still hard to understand dependencies
- Difficult to add new apps consistently
- No infrastructure/app separation

#### Option 2: Environment-Based Structure
```
flux/
├── base/
└── overlays/
    └── production/
```

**Pros:**
- Standard Kustomize pattern
- Clear environment separation

**Cons:**
- Only one environment currently
- Over-engineered for needs
- Doesn't solve infrastructure vs app separation

#### Option 3: Infrastructure and Apps Separation with Per-App Directories
```
flux/
├── infrastructure/
│   ├── cluster-secret-store.yaml
│   ├── snapshot-crds.yaml
│   └── httproutes/
└── apps/
    ├── external-dns/
    │   ├── helmrepository.yaml
    │   ├── config.yaml
    │   └── helmrelease.yaml
    └── synology-csi/
        ├── namespace.yaml
        ├── helmrepository.yaml
        ├── externalsecret.yaml
        └── helmrelease.yaml
```

**Pros:**
- Clear infrastructure vs application separation
- All resources for an app together
- Self-contained per-app directories
- Layered kustomizations enable dependency management
- Easy to understand and extend
- Follows Flux best practices

**Cons:**
- Significant migration effort
- Existing paths need updating

## Decision

We will **restructure the `flux/` directory** using infrastructure/apps separation with per-application organization:

### New Structure

```
flux/
├── kustomization.yaml              # Root kustomization
├── flux-apps.yaml                  # Flux Kustomization CR
├── infrastructure/                 # Platform-level resources
│   ├── kustomization.yaml
│   ├── cluster-secret-store.yaml  # External Secrets ClusterSecretStore
│   ├── snapshot-crds.yaml         # Volume snapshot CRDs
│   └── httproutes/                # Gateway API routes for Flux UI
│       ├── kustomization.yaml
│       ├── notification-controller.yaml
│       └── source-controller.yaml
└── apps/                          # Application deployments
    ├── kustomization.yaml
    ├── external-dns/
    │   ├── kustomization.yaml
    │   ├── helmrepository.yaml
    │   ├── config.yaml
    │   └── helmrelease.yaml
    └── synology-csi/
        ├── kustomization.yaml
        ├── namespace.yaml
        ├── helmrepository.yaml
        ├── externalsecret.yaml
        └── helmrelease.yaml
```

### Principles

1. **Separation of Concerns**:
   - `infrastructure/`: Platform resources (CRDs, cluster-wide secrets, observability)
   - `apps/`: Application workloads and dependencies

2. **Per-Application Organization**:
   - Each app gets its own directory
   - All related resources together (source + release + config + secrets)
   - Local kustomization.yaml per app

3. **Layered Kustomizations**:
   - Root kustomization aggregates infrastructure + apps
   - Infrastructure kustomization for platform resources
   - Apps kustomization aggregates all applications
   - Per-app kustomization for each application

## Consequences

### Positive

- **Clear organization**: Easy to find all resources for an application
- **Dependency management**: Infrastructure deploys before apps automatically
- **Selective syncing**: Can sync individual apps independently
- **Scalability**: Adding new apps follows clear pattern
- **Mental model**: Developers find everything related to an app in one place
- **Best practices**: Aligns with Flux documentation recommendations
- **Removed invalid references**: kustomization.yaml only references existing files

### Negative

- **Migration effort**: Required moving and renaming 15+ files
- **Path updates**: All kustomization.yaml files needed updating
- **Learning curve**: Team needs to understand new structure
- **Breaking change**: Old bookmarks/documentation paths invalid

### Neutral

- **File count**: Same number of manifest files, different organization
- **Validation required**: Must verify kustomize build still works

### Migration Details

**Files moved:**
- `resources/cluster-secret-store.yaml` → `infrastructure/cluster-secret-store.yaml`
- `resources/snapshot-crds.yaml` → `infrastructure/snapshot-crds.yaml`
- `httproutes/*.yaml` → `infrastructure/httproutes/*.yaml`
- `sources/external-dns.yaml` → `apps/external-dns/helmrepository.yaml`
- `releases/external-dns-rfc2136.yaml` → `apps/external-dns/helmrelease.yaml`
- `configs/external-dns-rfc2136.yaml` → `apps/external-dns/config.yaml`
- `resources/synology-csi-namespace.yaml` → `apps/synology-csi/namespace.yaml`
- `resources/synology-csi-external-secret.yaml` → `apps/synology-csi/externalsecret.yaml`
- `sources/synology-csi.yaml` → `apps/synology-csi/helmrepository.yaml`
- `releases/synology-csi.yaml` → `apps/synology-csi/helmrelease.yaml`

**Directories removed:**
- `flux/sources/`
- `flux/releases/`
- `flux/configs/`
- `flux/resources/`
- `flux/httproutes/`

**Kustomization files created:**
- `flux/infrastructure/kustomization.yaml`
- `flux/infrastructure/httproutes/kustomization.yaml`
- `flux/apps/kustomization.yaml`
- `flux/apps/external-dns/kustomization.yaml`
- `flux/apps/synology-csi/kustomization.yaml`

**Root kustomization updated:**
```yaml
resources:
  - flux-apps.yaml
  - infrastructure
  - apps
```

### Validation

Verified with:
```bash
kustomize build flux/ --enable-helm
```

All 13 resources generated successfully:
- 2 Namespaces
- 2 HelmReleases
- 2 HelmRepositories
- 2 HTTPRoutes
- 1 ClusterSecretStore
- 1 ExternalSecret
- 2 Flux Kustomizations
- 1 GitRepository

### Documentation Created

- `flux/README.md`: Complete structure documentation with examples
- Updated `AGENTS.md`: Repository architecture section
- This ADR

## References

- [Flux Repository Structure Guide](https://fluxcd.io/flux/guides/repository-structure/)
- [Kustomize Best Practices](https://kubectl.docs.kubernetes.io/references/kustomize/glossary/)
- [GitOps Patterns](https://www.weave.works/blog/what-is-gitops-really)
