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
CONTROL_PLANE_CPU=4
CONTROL_PLANE_MEM=8192
#CONTROL_PLANE_DISK="10G"
CONTROL_PLANE_MACHINE_CONFIG_PATH="./machine-config.yaml"

WORKER_COUNT=${WORKER_COUNT:=2}
WORKER_CPU=${WORKER_CPU:=2}
WORKER_MEM=${WORKER_MEM:=4096}
WORKER_DISK=${WORKER_DISK:=10G}
WORKER_MACHINE_CONFIG_PATH="./machine-config.yaml"

upload_ova () {
    ## Import desired Talos Linux OVA into a new content library
    govc library.create "${CLUSTER_NAME}"
    govc library.import -n "talos-${TALOS_VERSION}" ${CLUSTER_NAME} ${OVA_PATH}
}

create () {
    echo
    ## Encode machine configs
    CONTROL_PLANE_B64_MACHINE_CONFIG=$(base64 "${CONTROL_PLANE_MACHINE_CONFIG_PATH}" | tr -d '\n')
    WORKER_B64_MACHINE_CONFIG=$(base64 "${WORKER_MACHINE_CONFIG_PATH}" | tr -d '\n')

    ## Create control plane nodes and edit their settings
    for i in $(seq 1 ${CONTROL_PLANE_COUNT}); do
        node_name="${CLUSTER_NAME}-control-plane-${i}"
        echo ""
        echo "launching control plane node: $node_name"
        echo ""

        govc library.deploy '/talos/omni-talos-1.11.2' "$node_name"

        govc vm.change \
        -c ${CONTROL_PLANE_CPU}\
        -m ${CONTROL_PLANE_MEM} \
        -e "guestinfo.talos.config=${CONTROL_PLANE_B64_MACHINE_CONFIG}" \
        -e "disk.enableUUID=1" \
        -vm "$node_name"

#        govc vm.disk.change -vm "$node_name" -disk.name disk-1000-0 -size "${CONTROL_PLANE_DISK}"

        vm_path=$(govc vm.info "$node_name" | grep Path | awk '{print $2}')
        vm_json=$(govc vm.info -vm.ipath="$vm_path" -json=true)
        disk_num=$(echo "$vm_json" | jq -r '.virtualMachines[0].layout.disk[].diskFile[0]' | awk '{print $2}' | wc -l)

        next_disk_num=$((disk_num - 1))
        base_disk=$(echo "$vm_json" | jq -r '.virtualMachines[0].layout.disk[].diskFile[0]' | awk -F/ '{print $2}')
        next_disk_name="$base_disk/_$next_disk_num"
        echo "Creating additional disk with name: $next_disk_name"

        ds=$(echo "$vm_json" | jq -r '.virtualMachines[0].layout.disk[].diskFile[0]' | head -1 | awk '{print $1}' | tr -d '[]')
        ds_path=$(govc ls -t datastore '*/*' | grep "$ds")
        echo "$ds_path"

        govc vm.disk.create -vm "$node_name" -name="$next_disk_name" -ds="$ds_path" -size "150G"

        if [ -z "${GOVC_NETWORK+x}" ]; then
             echo "GOVC_NETWORK is unset, assuming default VM Network";
        else
            echo "GOVC_NETWORK set to ${GOVC_NETWORK}";
            govc vm.network.change -vm "$node_name" -net "${GOVC_NETWORK}" ethernet-0
        fi

        govc vm.power -on "$node_name"
    done

    ## Create worker nodes and edit their settings
    for i in $(seq 1 "${WORKER_COUNT}"); do
        node_name="${CLUSTER_NAME}-worker-${i}"
        echo ""
        echo "launching worker node: $node_name"
        echo ""

        govc library.deploy '/talos/omni-talos-1.11.2' "$node_name"

        govc vm.change \
        -c "${WORKER_CPU}" \
        -m "${WORKER_MEM}" \
        -e "guestinfo.talos.config=${WORKER_B64_MACHINE_CONFIG}" \
        -e "disk.enableUUID=1" \
        -vm "$node_name"

        vm_path=$(govc vm.info "$node_name" | grep Path | awk '{print $2}')
        vm_json=$(govc vm.info -vm.ipath="$vm_path" -json=true)
        disk_num=$(echo "$vm_json" | jq -r '.virtualMachines[0].layout.disk[].diskFile[0]' | awk '{print $2}' | wc -l)

        next_disk_num=$((disk_num - 1))
        base_disk=$(echo "$vm_json" | jq -r '.virtualMachines[0].layout.disk[].diskFile[0]' | awk -F/ '{print $2}')
        next_disk_name="$base_disk/_$next_disk_num"
        echo "Creating additional disk with name: $next_disk_name"

        ds=$(echo "$vm_json" | jq -r '.virtualMachines[0].layout.disk[].diskFile[0]' | head -1 | awk '{print $1}' | tr -d '[]')
        ds_path=$(govc ls -t datastore '*/*' | grep "$ds")
        echo "$ds_path"

        govc vm.disk.create -vm "$node_name" -name="$next_disk_name" -ds="$ds_path" -size "150G"

        if [ -z "${GOVC_NETWORK+x}" ]; then
             echo "GOVC_NETWORK is unset, assuming default VM Network";
        else
            echo "GOVC_NETWORK set to ${GOVC_NETWORK}";
            govc vm.network.change -vm "$node_name" -net "${GOVC_NETWORK}" ethernet-0
        fi


        govc vm.power -on "$node_name"
    done

}

destroy() {
    for i in $(seq 1 ${CONTROL_PLANE_COUNT}); do
        echo ""
        echo "destroying control plane node: ${CLUSTER_NAME}-control-plane-${i}"
        echo ""

        govc vm.destroy "${CLUSTER_NAME}-control-plane-${i}"
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
