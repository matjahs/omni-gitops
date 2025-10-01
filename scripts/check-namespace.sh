#!/usr/bin/env bash
# Copyright (c) 2024 Matjah
# SPDX-License-Identifier: MIT

# Check that Kubernetes manifests have namespace defined

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "🔍 Checking namespaces in manifests..."

# Only check changed files if in git hook
if [ "${PRE_COMMIT:-}" == "1" ]; then
  files=$(git diff --cached --name-only --diff-filter=ACM | grep '^apps/.*\.yaml$' | grep -v kustomization || true)
else
  files=$(find "${REPO_ROOT}/apps" -name "*.yaml" | grep -v kustomization)
fi

if [ -z "${files}" ]; then
  echo "  No manifest files to check"
  exit 0
fi

failed=0
total=0

for file in ${files}; do
  # Skip if file doesn't exist (was deleted)
  [ -f "${file}" ] || continue

  total=$((total + 1))

  # Check if YAML contains Kubernetes resources
  if ! grep -q "^kind:" "${file}"; then
    continue
  fi

  # Skip certain kinds that don't need namespace
  if grep -qE "^kind: (Namespace|ClusterRole|ClusterRoleBinding|CustomResourceDefinition|StorageClass)" "${file}"; then
    continue
  fi

  relative_path="${file#${REPO_ROOT}/}"

  # Check if namespace is defined in metadata
  if ! grep -qE "^  namespace:" "${file}"; then
    echo "  ⚠️  ${relative_path} - No namespace defined"
    # Don't fail, just warn (kustomize might set it)
  fi
done

echo "✅ Namespace check complete"
