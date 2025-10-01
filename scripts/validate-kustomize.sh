#!/usr/bin/env bash
# Copyright (c) 2024 Matjah
# SPDX-License-Identifier: MIT

# Validate all kustomization.yaml files can build successfully

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "🔍 Validating Kustomize builds..."

# Find all kustomization.yaml files
kustomization_files=$(find "${REPO_ROOT}" -name "kustomization.yaml" -o -name "kustomization.yml")

failed=0
total=0

for kustomization in ${kustomization_files}; do
  dir=$(dirname "${kustomization}")
  relative_path="${dir#${REPO_ROOT}/}"

  total=$((total + 1))

  echo -n "  Checking ${relative_path}... "

  if kustomize build "${dir}" > /dev/null 2>&1; then
    echo "✅"
  else
    echo "❌"
    echo "    Error building ${relative_path}"
    kustomize build "${dir}" 2>&1 | sed 's/^/    /'
    failed=$((failed + 1))
  fi
done

echo ""
echo "Results: $((total - failed))/${total} passed"

if [ ${failed} -gt 0 ]; then
  echo "❌ ${failed} kustomization(s) failed to build"
  exit 1
fi

echo "✅ All kustomizations built successfully"
