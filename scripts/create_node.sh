#!/bin/bash

set -e

usage() {
    cat << EOF
Usage: $0 -n <node_name> -c <cpu_count> -m <memory> -f <machine_config_path> [options]
...
EOF
    exit 1
}

generate_mac() {
  local node_name="$1"
  local prefix="00:50:56"
  local hash=""
  local mac=""
  hash=$(echo -n "$node_name" | md5 | awk '{print $1}' | cut -c1-6)
  mac="${prefix}:$(echo "$hash" | sed 's/\(..\)/\1:/g' | cut -c1-8 | sed 's/:$//')"
  echo "$mac"
}

create_node() {
    local node_name="$1"
    local cpu_count="$2"
    local memory="$3"
    local machine_config_b64="$4"
    local additional_disk_size="$5"
    local template_path="$6"

    local mac_address=""
    mac_address=$(generate_mac "$node_name")

    echo ""
    echo "Creating node: $node_name"
    echo "  CPUs: $cpu_count"
    echo "  Memory: ${memory}MB"
    echo "  Additional disk: $additional_disk_size"
    echo "  Template: $template_path"
    echo "  MAC: $mac_address"
    echo "  Datastore: ${GOVC_DATASTORE}"
    echo ""

    govc vm.destroy "$node_name" || echo "No existing VM to destroy"

    local node_type="worker"
    # If the node_name contains "worker", use a different ISO path
    if [[ "$node_name" == *"controlplane"* ]]; then
        node_type="controlplane"
    fi

    govc vm.create \
      -on=false \
      -force=true \
      -m="${memory}" \
      -c="${cpu_count}" \
      -disk=10G \
      -disk.eager=false \
      -net=dvs-pg-vlan20 \
      -ds="/Datacenter/datastore/synology-iscsi-lun01" \
      -iso="library:/talos/talos-1.11.2-${node_type}/talos-1.11.2-${node_type}.iso" \
      "$node_name"

    govc vm.change \
        -c "${cpu_count}" \
        -m "${memory}" \
        -e "guestinfo.talos.config=${machine_config_b64}" \
        -e "disk.enableUUID=1" \
        -vm "$node_name"

    vm_path=$(govc vm.info "$node_name" | grep Path | awk '{print $2}')
    vm_json=$(govc vm.info -vm.ipath="$vm_path" -json=true)
    disk_files=$(echo "$vm_json" | jq -r '.virtualMachines[0].layout.disk // [] | .[].diskFile[0]')
    if [ -z "$disk_files" ]; then
        echo "No disks found for VM, skipping additional disk creation."
    else
        disk_num=$(echo "$disk_files" | wc -l)
        next_disk_num=$((disk_num - 1))
        base_disk=$(echo "$disk_files" | head -1 | awk -F/ '{print $2}')
        next_disk_name="$base_disk/_$next_disk_num"
        echo "Creating additional disk with name: $next_disk_name"
        ds=$(echo "$vm_json" | jq -r '.virtualMachines[0].layout.disk[].diskFile[0]' | head -1 | awk '{print $1}' | tr -d '[]')
        ds_path=$(govc ls -t datastore '*/*' | grep "$ds")
        echo "Datastore path: $ds_path"
        govc vm.disk.create -vm "$node_name" -name="$next_disk_name" -ds="$ds_path" -size "${additional_disk_size}"
    fi

    if [ -z "${GOVC_NETWORK+x}" ]; then
        echo "GOVC_NETWORK is unset, using default VM Network"
    else
        echo "Configuring network: ${GOVC_NETWORK}"
        govc vm.network.change -vm "$node_name" -net "${GOVC_NETWORK}" ethernet-0
    fi

    echo "Powering on $node_name"
    govc vm.power -on "$node_name"
    echo ""
    echo "Successfully created and started node: $node_name"
}

NODE_NAME=""
CPU_COUNT=""
MEMORY=""
MACHINE_CONFIG_PATH=""
DISK_SIZE="150G"
TEMPLATE_PATH="/talos/omni-talos-1.11.2"

while getopts "n:c:m:f:d:t:h" opt; do
    case $opt in
        n) NODE_NAME="$OPTARG" ;;
        c) CPU_COUNT="$OPTARG" ;;
        m) MEMORY="$OPTARG" ;;
        f) MACHINE_CONFIG_PATH="$OPTARG" ;;
        d) DISK_SIZE="$OPTARG" ;;
        t) TEMPLATE_PATH="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

if [ -z "$NODE_NAME" ] || [ -z "$CPU_COUNT" ] || [ -z "$MEMORY" ] || [ -z "$MACHINE_CONFIG_PATH" ]; then
    echo "Error: Missing required parameters"
    echo ""
    usage
fi

if [ ! -f "$MACHINE_CONFIG_PATH" ]; then
    echo "Error: Machine config file not found: $MACHINE_CONFIG_PATH"
    exit 1
fi

if [ -z "${GOVC_URL+x}" ]; then
    echo "Error: GOVC_URL environment variable must be set"
    exit 1
fi

echo "Encoding machine config from: $MACHINE_CONFIG_PATH"
MACHINE_CONFIG_B64=$(base64 < "$MACHINE_CONFIG_PATH" | tr -d '\n')

create_node "$NODE_NAME" "$CPU_COUNT" "$MEMORY" "$MACHINE_CONFIG_B64" "$DISK_SIZE" "$TEMPLATE_PATH"
