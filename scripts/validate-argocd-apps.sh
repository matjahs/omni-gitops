#!/usr/bin/env bash
# Copyright (c) 2024 Matjah
# SPDX-License-Identifier: MIT

# Validate ArgoCD Application manifests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "🔍 Validating ArgoCD Application manifests..."

failed=0
total=0

# Find all Application manifests
app_files=$(find "${REPO_ROOT}/applications" -name "*.yaml" -o -name "*.yml" | grep -v kustomization)

for app_file in ${app_files}; do
  relative_path="${app_file#${REPO_ROOT}/}"
  total=$((total + 1))

  echo -n "  Checking ${relative_path}... "

  # Check if it's a valid YAML
  if ! yq eval '.' "${app_file}" > /dev/null 2>&1; then
    echo "❌ Invalid YAML"
    failed=$((failed + 1))
    continue
  fi

  # Check if it's an ArgoCD Application
  kind=$(yq eval '.kind' "${app_file}")
  if [ "${kind}" != "Application" ]; then
    echo "⚠️  Not an Application (kind: ${kind})"
    continue
  fi

  # Check required fields
  name=$(yq eval '.metadata.name' "${app_file}")
  namespace=$(yq eval '.metadata.namespace' "${app_file}")
  source_path=$(yq eval '.spec.source.path // .spec.sources[0].path' "${app_file}")
  dest_namespace=$(yq eval '.spec.destination.namespace' "${app_file}")

  if [ "${name}" == "null" ]; then
    echo "❌ Missing metadata.name"
    failed=$((failed + 1))
    continue
  fi

  if [ "${namespace}" != "argocd" ]; then
    echo "⚠️  Application not in argocd namespace (${namespace})"
  fi

  if [ "${source_path}" != "null" ] && [ ! -d "${REPO_ROOT}/${source_path}" ]; then
    echo "❌ Source path does not exist: ${source_path}"
    failed=$((failed + 1))
    continue
  fi

  echo "✅"
done

echo ""
echo "Results: $((total - failed))/${total} passed"

if [ ${failed} -gt 0 ]; then
  echo "❌ ${failed} Application(s) failed validation"
  exit 1
fi

echo "✅ All Applications validated successfully"
