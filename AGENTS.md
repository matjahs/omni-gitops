# Repository Guidelines

## Project Structure & Module Organization
- `flux/`: Flux CD infrastructure primitives, with `flux/infrastructure/` for cluster services and `flux/apps/` for platform add-ons.
- `apps/`: ArgoCD workloads organized per app; each keeps a `base/` plus `overlays/production` Kustomize stack.
- `applications/`: ArgoCD `Application` manifests implementing the App-of-Apps entrypoint.
- `clusters/` and `docs/`: Environment notes and manuals only; do not place Flux-managed assets here.
- Keep binaries, generated files, and secrets out of git; rely on registries or secret managers.

## Build, Test, and Development Commands
- `task deps` – install local tooling (Homebrew, TalHelper).
- `kubectl kustomize flux/` – lint Flux manifests before committing.
- `kubectl kustomize apps/<app>/overlays/production` – check production payloads, e.g. `kubectl kustomize apps/external-dns/overlays/production`.
- `flux reconcile kustomization flux-apps --with-source` – pull the latest infra changes after merges.

## Coding Style & Naming Conventions
- Use two-space YAML indentation and group resources by namespace, source, release, then config.
- Prefer descriptive resource names (`external-dns`, not abbreviations).
- Run `npx prettier --write` (or editor integration) on YAML, JSON, and Markdown prior to commit.
- Add concise comments only for non-obvious Kustomize patches, especially RBAC changes.

## Testing Guidelines
- Dry-run ArgoCD manifests with `kubectl kustomize` before touching `applications/`.
- Template Helm-driven Flux apps with `helm template` when adjusting values.
- Validate External Secrets references in a non-production cluster early.
- Capture evidence (commands, logs, screenshots) in the PR “Testing done” checklist.

## Commit & Pull Request Guidelines
- Commits follow `feat: <context>` or `fix: <context>`; squash cleanups before pushing.
- PRs include a one-line summary, linked issues, and completed testing notes.
- Confirm linting and kustomize outputs locally; document follow-ups in the PR body.
- Keep Flux and Argo roles separate—Flux owns infrastructure, Argo owns workloads; maintain ignore rules when adding directories.

## Hybrid GitOps Responsibilities
- Flux bootstraps ArgoCD and cluster primitives; never point ArgoCD at `flux/`.
- Raise questions when ownership feels ambiguous to avoid reconciliation loops.
