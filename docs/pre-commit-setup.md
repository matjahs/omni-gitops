# Pre-Commit Hooks Setup

This repository uses [pre-commit](https://pre-commit.com/) to validate changes before committing.

## What Gets Validated

- ✅ **YAML syntax** - Ensures all YAML files are valid
- ✅ **Kustomize builds** - Validates all kustomization.yaml files build successfully
- ✅ **ArgoCD Applications** - Checks Application manifests have required fields and valid paths
- ✅ **Kubernetes schemas** - Validates manifests against Kubernetes API schemas
- ✅ **Secrets detection** - Prevents committing sensitive data
- ✅ **Shell scripts** - Runs shellcheck on bash scripts
- ✅ **Conventional commits** - Enforces commit message format
- ✅ **File hygiene** - Trailing whitespace, end-of-file, merge conflicts

## Installation

### 1. Install Dependencies

```bash
# Install pre-commit
pip install pre-commit

# Install additional tools
brew install kustomize yq shellcheck

# For Kubernetes validation (optional but recommended)
brew install kubeconform
```

### 2. Install Git Hooks

```bash
# Install pre-commit hooks
pre-commit install

# Install commit-msg hook for conventional commits
pre-commit install --hook-type commit-msg
```

### 3. Test Installation

```bash
# Run all hooks on all files
pre-commit run --all-files
```

## Usage

### Automatic (Recommended)

Once installed, hooks run automatically on `git commit`:

```bash
git add .
git commit -m "feat: add new application"
# Hooks run automatically ✓
```

### Manual

Run hooks manually without committing:

```bash
# Run all hooks
pre-commit run --all-files

# Run specific hook
pre-commit run yamllint --all-files
pre-commit run kustomize-build
```

### Skip Hooks (Use Sparingly)

```bash
# Skip all hooks (not recommended)
git commit --no-verify -m "emergency fix"

# Skip specific hook
SKIP=yamllint git commit -m "fix: update config"
```

## Commit Message Format

This repo uses [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `refactor`: Code refactoring
- `chore`: Maintenance tasks
- `test`: Test changes
- `ci`: CI/CD changes

**Examples:**
```bash
git commit -m "feat(monitoring): add prometheus alerting rules"
git commit -m "fix(cert-manager): correct ClusterIssuer configuration"
git commit -m "docs: update repository structure guide"
git commit -m "refactor: implement namespace-first directory structure"
```

## Troubleshooting

### Hook Fails on Kustomize Build

If a kustomize build fails:

```bash
# Manually test the build
kustomize build apps/monitoring/kube-prometheus-stack/overlays/production

# Check for syntax errors in kustomization.yaml
yq eval '.' apps/monitoring/kube-prometheus-stack/overlays/production/kustomization.yaml
```

### Secret Detected

If detect-secrets finds a potential secret:

```bash
# Audit and update baseline
detect-secrets scan --baseline .secrets.baseline

# Review and mark as false positive if needed
detect-secrets audit .secrets.baseline
```

### YAML Lint Failures

Adjust yamllint rules in `.pre-commit-config.yaml`:

```yaml
- id: yamllint
  args: ['-d', '{extends: relaxed, rules: {line-length: {max: 120}}}']
```

### Update Hooks

```bash
# Update to latest versions
pre-commit autoupdate

# Reinstall hooks
pre-commit install --install-hooks
```

## Custom Validation Scripts

Custom validation scripts are located in `scripts/`:

- **validate-kustomize.sh** - Validates all Kustomize builds
- **validate-argocd-apps.sh** - Validates ArgoCD Application manifests
- **check-namespace.sh** - Checks namespace declarations

You can run these directly:

```bash
./scripts/validate-kustomize.sh
./scripts/validate-argocd-apps.sh
```

## CI/CD Integration

Pre-commit hooks also run in CI pipelines. Add to GitHub Actions:

```yaml
- name: Run pre-commit
  uses: pre-commit/action@v3.0.0
```

## Configuration

Edit `.pre-commit-config.yaml` to:
- Add/remove hooks
- Adjust hook arguments
- Exclude files/patterns
- Change hook versions

See [pre-commit documentation](https://pre-commit.com/) for details.
