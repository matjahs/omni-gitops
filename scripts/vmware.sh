#!/bin/bash

set -e

## The following commented environment variables should be set
## before running this script

# export GOVC_USERNAME=
# export GOVC_PASSWORD=
# export GOVC_INSECURE=
# export GOVC_URL=
# export GOVC_DATASTORE=
# export GOVC_NETWORK=

CLUSTER_NAME="cluster1"
TALOS_VERSION="v1.11.2"
OVA_PATH="https://matjahs.eu-central-1.omni.siderolabs.io:443/image/1495aaa4d6d6e1deb7db58faf6738e5d924ce4fad6b58591c84a61c489975519/1.11.2/vmware-amd64.ova"

CONTROL_PLANE_COUNT=3
CONTROL_PLANE_CPU=6
CONTROL_PLANE_MEM=16384
# CONTROL_PLANE_SYS_DISK="10G"
# CONTROL_PLANE_DATA_DISK="50G"
CONTROL_PLANE_MACHINE_CONFIG_PATH="./machine-config.yaml"

WORKER_COUNT=${WORKER_COUNT:=4}
WORKER_CPU=${WORKER_CPU:=4}
WORKER_MEM=${WORKER_MEM:=8192}
# WORKER_SYSTEM_DISK=${WORKER_DISK:=10G}
WORKER_DATA_DISK=${WORKER_DATA_DISK:=50G}
WORKER_MACHINE_CONFIG_PATH="./machine-config.yaml"

created_nodes=()

cleanup() {
  echo "Script failed. Cleaning up created nodes..."
  for node in "${created_nodes[@]}"; do
    echo "Destroying node: $node"
    govc vm.destroy "$node" || echo "Failed to destroy node: $node"
  done
}
trap cleanup ERR

upload_ova () {
    ## Import desired Talos Linux OVA into a new content library
    govc library.create "${CLUSTER_NAME}"
    govc library.import -n "talos-${TALOS_VERSION}" ${CLUSTER_NAME} ${OVA_PATH}
}

create () {
    echo
    # Get the directory where this script is located
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    CREATE_NODE_SCRIPT="${SCRIPT_DIR}/create_node.sh"

    # Verify create_node.sh exists
    if [ ! -f "$CREATE_NODE_SCRIPT" ]; then
        echo "Error: create_node.sh not found at $CREATE_NODE_SCRIPT"
        exit 1
    fi

    ## Create control plane nodes
    for i in $(seq 1 ${CONTROL_PLANE_COUNT}); do
        node_name="${CLUSTER_NAME}-controlplane-${i}"
        "$CREATE_NODE_SCRIPT" \
            -n "$node_name" \
            -c "${CONTROL_PLANE_CPU}" \
            -m "${CONTROL_PLANE_MEM}" \
            -f "${CONTROL_PLANE_MACHINE_CONFIG_PATH}"
        created_nodes+=("$node_name")
    done

    ## Create worker nodes
    for i in $(seq 1 "${WORKER_COUNT}"); do
        node_name="${CLUSTER_NAME}-worker-${i}"
        "$CREATE_NODE_SCRIPT" \
            -n "$node_name" \
            -c "${WORKER_CPU}" \
            -m "${WORKER_MEM}" \
            -f "${WORKER_MACHINE_CONFIG_PATH}"
        created_nodes+=("$node_name")
    done
}

destroy() {
    for i in $(seq 1 ${CONTROL_PLANE_COUNT}); do
        echo ""
        echo "destroying control plane node: ${CLUSTER_NAME}-controlplane-${i}"
        echo ""

        govc vm.destroy "${CLUSTER_NAME}-controlplane-${i}"
    done

    for i in $(seq 1 "${WORKER_COUNT}"); do
        echo ""
        echo "destroying worker node: ${CLUSTER_NAME}-worker-${i}"
        echo ""
        govc vm.destroy "${CLUSTER_NAME}-worker-${i}"
    done
}

delete_ova() {
    govc library.rm "${CLUSTER_NAME}"
}

"$@"
