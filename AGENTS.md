# Repository Guidelines

## Project Structure & Module Organization
- `flux/`: Flux CD-only infrastructure, including cluster CRDs, secrets, and base services (`flux/infrastructure/`) plus infra apps (`flux/apps/`).
- `apps/`: ArgoCD-only workload manifests organized by app; each app favors `base/` + `overlays/production` Kustomize layout.
- `applications/`: Declarative ArgoCD `Application` resources implementing the App-of-Apps pattern.
- `clusters/` & `docs/`: Environment-specific configs and manual references; avoid placing Flux-managed assets here.
- Binary assets or generated artifacts should stay out of the repo; prefer external registries or secrets managers.

## Build, Test, & Development Commands
- `task deps`: Bootstrap local tooling via Homebrew and install TalHelper.
- `kubectl kustomize flux/`: Validate Flux renders cleanly before commit.
- `kubectl kustomize apps/<app>/overlays/production`: Confirm ArgoCD payloads build for production overlays.
- `flux reconcile kustomization flux-apps --with-source`: Trigger Flux to pull the latest infra changes after merge.
- Example: Run `kubectl kustomize apps/external-dns/overlays/production` to validate external-dns manifests.

## Coding Style & Naming Conventions
- Apply Prettier formatting (`npx prettier --write` or editor integration) to YAML, JSON, and Markdown prior to committing.
- Use descriptive Kubernetes resource names; avoid abbreviations (`external-dns`, not `extdns`).
- Maintain two-space indentation in YAML and keep manifests grouped logically (namespace, source, release, config).
- Document non-obvious intent with brief comments near complex Kustomize patches only when essential.
- Example: Add comments for patches that modify sensitive RBAC roles.

## Testing Guidelines
- Dry-run ArgoCD manifests with `kubectl kustomize` before creating or updating an `Application` spec.
- For Helm-based Flux apps, run `helm template` against referenced charts when adjusting values.
- Validate secret references using External Secrets tooling in a non-production cluster before rollout.
- Capture test evidence in the PR "Testing done" section (commands, screenshots, or log excerpts).
- Example: Use `kubectl apply --dry-run=client` to test changes locally before committing.

## Commit & Pull Request Guidelines
- Commits follow `fix: <context>` or `feat: <context>`; squash small tweaks before pushing.
- PRs include a one-line summary, linked issues (if any), and the "Testing done" checklist.
- Verify linting and Kustomize outputs locally; note any deviations or follow-up tasks in the PR body.
- Respect Flux/Argo boundaries: infra lives under `flux/`, application workloads under `apps/` + `applications/`.
- Example: Ensure Flux ignores are in place when adding new ArgoCD directories.

## Hybrid GitOps Responsibilities
- Flux bootstraps ArgoCD and cluster primitives; do not point ArgoCD sources at `flux/`.
- ArgoCD owns workloads; ensure Flux ignores remain intact when adding new directories.
- When unsure which tool should manage a resource, raise the question before opening a PR to avoid reconciliation loops.
- Example: Use Flux for cluster-level CRDs and ArgoCD for application-level resources.
