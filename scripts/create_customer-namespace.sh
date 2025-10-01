#!/usr/bin/env bash
#
# Create a new customer namespace in the cluster
# and set up the necessary resources.

set -euo pipefail

usage() {
  # heredoc for usage
  cat <<EOF
Usage: $0 <customer-name> <namespace>
Example: $0 acme acme-namespace
EOF
    exit 1
}
# ---- args --------------------------------------------------------------------
SHORT="c:,h"
LONG="customer:,help"
VALID_ARGS=$(getopt --options $SHORT --longoptions $LONG -- "$@")
if [[ $? -ne 0 ]]; then
  exit 1;
fi

eval set -- "$VALID_ARGS"
while :
do
  case "$1" in
    -c | --customer )
      customer="$2"
      shift 2
      ;;
    -h | --help )
      usage
      ;;
    --) shift;
      break
      ;;
    * )
      usage
      ;;
  esac
done

echo "$customer";

# ---- main --------------------------------------------------------------------
main() {
  parse_args "$@"
  mktempdir

  debug "VERBOSE_LEVEL=${VERBOSE_LEVEL}"
  debug "QUIET=${QUIET} DRY_RUN=${DRY_RUN} RETRIES=${RETRIES} TIMEOUT=${TIMEOUT} OUTFILE=${OUTFILE}"

  # Example: ensure a dependency (add more as needed)
  # require curl "curl (for HTTP calls)"

  # If you need the script directory for relative assets:
  trace "SCRIPT_DIR=${SCRIPT_DIR}"

  # Subcommand (default: run)
  if ((${#POSITIONAL[@]})); then
    dispatch "${POSITIONAL[0]}" "${POSITIONAL[@]:1}"
  else
    dispatch "run"
  fi

  info "Done."
}

# Only run main if executed, not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
