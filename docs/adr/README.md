# Architecture Decision Records (ADR)

This directory contains Architecture Decision Records for the omni-gitops repository.

## What is an ADR?

An Architecture Decision Record (ADR) captures an important architectural decision made along with its context and consequences.

## Format

Each ADR follows this structure:

- **Title**: Short descriptive title
- **Status**: Proposed | Accepted | Deprecated | Superseded
- **Date**: When the decision was made
- **Context**: What is the issue we're trying to solve?
- **Decision**: What did we decide?
- **Consequences**: What are the implications?

## Index

### Repository Structure
- [ADR-0001](0001-namespace-first-repository-structure.md) - Namespace-First Repository Structure
- [ADR-0005](0005-hybrid-gitops-flux-argocd-separation.md) - Hybrid GitOps with Flux CD and ArgoCD Separation
- [ADR-0006](0006-flux-directory-restructuring.md) - Flux Directory Restructuring for Infrastructure and Applications

### Infrastructure & Platform
- [ADR-0002](0002-external-secrets-operator-for-vault.md) - External Secrets Operator for Vault Integration
- [ADR-0004](0004-vault-ip-address-instead-of-hostname.md) - Use IP Address for Vault Server
- [ADR-0007](0007-synology-csi-for-persistent-storage.md) - Synology CSI Driver for Persistent Storage
- [ADR-0008](0008-cilium-gateway-api-migration.md) - Migrate from Traefik IngressRoute to Cilium Gateway API

### Application Deployment
- [ADR-0003](0003-argocd-multi-source-for-helm.md) - ArgoCD Multi-Source Applications for Helm Charts
