#!/usr/bin/env bash
# Copyright (c) 2024 Matjah
# SPDX-License-Identifier: MIT

# Export the active Omni cluster template and materialise inline patches into omni/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_TEMPLATE_PATH="${REPO_ROOT}/omni/cluster-template.yaml"
DEFAULT_PATCHES_DIR="${REPO_ROOT}/omni/patches"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--cluster <name>] [--output <path>] [--patches-dir <path>]

Options:
  -c, --cluster        Omni cluster name (defaults to name found in omni/cluster-template.yaml)
  -o, --output         Destination for exported template (default: omni/cluster-template.yaml)
  -p, --patches-dir    Directory for patch files (default: omni/patches)
  -h, --help           Show this help message

Notes:
  • Authenticate with Omni first (e.g. 'omnictl login' or environment variables).
  • Requires omnictl, yq, and python3 available locally.
USAGE
}

error() {
  echo "❌ $*" >&2
  exit 1
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Missing dependency: $1"
  fi
}

resolve_path() {
  # resolve_path <base> <relative>
  python3 - "$1" "$2" <<'PY'
import os, sys
base, rel = sys.argv[1:3]
print(os.path.abspath(os.path.join(base, rel)))
PY
}

rel_path() {
  # rel_path <from> <to>
  python3 - "$1" "$2" <<'PY'
import os, sys
print(os.path.relpath(sys.argv[2], start=sys.argv[1]))
PY
}

join_rel_path() {
  # join_rel_path <base> <addition>
  python3 - "$1" "$2" <<'PY'
import os, sys
print(os.path.normpath(os.path.join(sys.argv[1], sys.argv[2])))
PY
}

require_cmd omnictl
require_cmd yq
require_cmd python3

OUTPUT_PATH="${DEFAULT_TEMPLATE_PATH}"
PATCHES_DIR="${DEFAULT_PATCHES_DIR}"
CLUSTER_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--cluster)
      shift || error "Missing value for --cluster"
      CLUSTER_NAME="$1"
      ;;
    -o|--output)
      shift || error "Missing value for --output"
      OUTPUT_PATH="$(resolve_path "${REPO_ROOT}" "$1")"
      ;;
    -p|--patches-dir)
      shift || error "Missing value for --patches-dir"
      PATCHES_DIR="$(resolve_path "${REPO_ROOT}" "$1")"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      error "Unknown argument: $1"
      ;;
  esac
  shift
done

TEMPLATE_DIR="$(dirname "${OUTPUT_PATH}")"
PATCH_RELATIVE_DIR="$(rel_path "${TEMPLATE_DIR}" "${PATCHES_DIR}")"
USE_EXISTING_PATHS=0
if [[ "${OUTPUT_PATH}" == "${DEFAULT_TEMPLATE_PATH}" && "${PATCHES_DIR}" == "${DEFAULT_PATCHES_DIR}" ]]; then
  USE_EXISTING_PATHS=1
fi

# Derive cluster name if not provided
if [[ -z "${CLUSTER_NAME}" && -f "${DEFAULT_TEMPLATE_PATH}" ]]; then
  if CLUSTER_NAME=$(yq eval 'select(documentIndex == 0).name' "${DEFAULT_TEMPLATE_PATH}" 2>/dev/null); then
    CLUSTER_NAME="${CLUSTER_NAME:-}"
  fi
fi
[[ -n "${CLUSTER_NAME}" ]] || error "Cluster name not provided and could not be inferred"

mkdir -p "${PATCHES_DIR}" "${TEMPLATE_DIR}"

# Map existing patch IDs to relative file paths to keep stable filenames
declare -A EXISTING_PATCH_MAP
if [[ ${USE_EXISTING_PATHS} -eq 1 && -f "${DEFAULT_TEMPLATE_PATH}" ]]; then
  while IFS='|' read -r patch_id patch_file; do
    [[ -z "${patch_id}" || -z "${patch_file}" ]] && continue
    EXISTING_PATCH_MAP["${patch_id}"]="${patch_file}"
  done < <(yq eval-all 'select(has("patches")).patches[] | select(has("file")) | ((.idOverride // .id) + "|" + .file)' "${DEFAULT_TEMPLATE_PATH}" 2>/dev/null || true)
fi

TMP_TEMPLATE=$(mktemp)
trap 'rm -f "${TMP_TEMPLATE}"' EXIT

echo "📥 Exporting cluster template for '${CLUSTER_NAME}'..."
omnictl cluster template export --cluster "${CLUSTER_NAME}" > "${TMP_TEMPLATE}"

# Clean up old patch files if using default paths
if [[ ${USE_EXISTING_PATHS} -eq 1 && -d "${PATCHES_DIR}" ]]; then
  echo "🧹 Cleaning old patches from ${PATCHES_RELATIVE}..."
  rm -f "${PATCHES_DIR}"/*.yaml 2>/dev/null || true
fi

mapfile -t INLINE_PATCHES < <(yq eval-all 'select(has("patches")).patches | to_entries[] | select(.value.inline) | "" + (documentIndex|tostring) + "|" + (.key|tostring) + "|" + ((.value.idOverride // .value.id) // ("patch-" + (.key|tostring))) + "|" + ((.value.annotations.name // "") | sub("^$"; "none"))' "${TMP_TEMPLATE}")

for entry in "${INLINE_PATCHES[@]:-}"; do
  [[ -z "${entry}" ]] && continue
  IFS='|' read -r doc_idx patch_idx patch_id annotation_name <<< "${entry}"
  [[ -z "${patch_id}" ]] && patch_id="patch-${doc_idx}-${patch_idx}"

  patch_rel_path=""
  if [[ ${USE_EXISTING_PATHS} -eq 1 ]]; then
    patch_rel_path="${EXISTING_PATCH_MAP[${patch_id}]:-}"
  fi
  if [[ -z "${patch_rel_path}" ]]; then
    # Extract priority prefix (e.g., "500-" from "500-uuid")
    priority_prefix=""
    if [[ "${patch_id}" =~ ^([0-9]+-) ]]; then
      priority_prefix="${BASH_REMATCH[1]}"
    fi

    # Use annotation name if available, otherwise use full patch ID
    if [[ -n "${annotation_name}" && "${annotation_name}" != "none" ]]; then
      base_name="${annotation_name}"
    else
      base_name="${patch_id}"
    fi

    # Sanitize the name (use printf to avoid trailing newline issues)
    safe_name="$(printf '%s' "${base_name}" | tr -s '[:space:]/' '-')"
    safe_name="$(printf '%s' "${safe_name}" | tr -c 'A-Za-z0-9._-/' '-')"
    safe_name="${safe_name#-}"
    # Remove all trailing hyphens
    while [[ "${safe_name}" == *- ]]; do
      safe_name="${safe_name%-}"
    done
    [[ -z "${safe_name}" ]] && safe_name="patch-${doc_idx}-${patch_idx}"

    # Combine priority prefix with safe name (only if using annotation name)
    if [[ -n "${priority_prefix}" && -n "${annotation_name}" && "${annotation_name}" != "none" ]]; then
      safe_name="${priority_prefix}${safe_name}"
    fi

    patch_rel_path="$(join_rel_path "${PATCH_RELATIVE_DIR}" "${safe_name}.yaml")"
  fi

  patch_abs_path="$(resolve_path "${TEMPLATE_DIR}" "${patch_rel_path}")"
  case "${patch_abs_path}" in
    "${REPO_ROOT}"/*) ;;
    *) error "Refusing to write outside repository: ${patch_abs_path}" ;;
  esac

  echo "  ↳ Writing ${patch_rel_path}"
  mkdir -p "$(dirname "${patch_abs_path}")"

  yq eval "select(documentIndex == ${doc_idx}) | .patches[${patch_idx}].inline" "${TMP_TEMPLATE}" \
    | yq eval -P '.' - > "${patch_abs_path}"

  DOC_IDX=${doc_idx} PATCH_IDX=${patch_idx} PATCH_PATH="${patch_rel_path}" \
    yq eval --inplace 'with(select(documentIndex == (env(DOC_IDX)|tonumber)).patches[(env(PATCH_IDX)|tonumber)]; .file = strenv(PATCH_PATH))' "${TMP_TEMPLATE}"

  DOC_IDX=${doc_idx} PATCH_IDX=${patch_idx} \
    yq eval --inplace 'with(select(documentIndex == (env(DOC_IDX)|tonumber)).patches[(env(PATCH_IDX)|tonumber)]; del(.inline))' "${TMP_TEMPLATE}"
done

yq eval -P '.' "${TMP_TEMPLATE}" > "${OUTPUT_PATH}"

TEMPLATE_RELATIVE="$(rel_path "${REPO_ROOT}" "${OUTPUT_PATH}")"
PATCHES_RELATIVE="$(rel_path "${REPO_ROOT}" "${PATCHES_DIR}")"

echo "✅ Export complete"
echo "  Template: ${TEMPLATE_RELATIVE}"
echo "  Patches : ${PATCHES_RELATIVE}"
