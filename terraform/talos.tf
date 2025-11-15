locals {
  control_node_ips = [
    for k in keys(local.control_nodes) :
    coalesce(vsphere_virtual_machine.talos_control_vm[k].default_ip_address, lookup(local.control_nodes[k], "ip_addr", null))
  ]
  worker_node_ips = [
    for k in keys(local.worker_nodes) :
    coalesce(vsphere_virtual_machine.talos_worker_vm[k].default_ip_address, lookup(local.worker_nodes[k], "ip_addr", null))
  ]
  node_ips = concat(
    local.control_node_ips,
    local.worker_node_ips
  )

  # Resolved endpoints per node (prefer static ip_addr, then vm default_ip_address, then endpoint)
  # We prefer the static configured IP to avoid issues when VMs have multiple IPs configured
  resolved_control_endpoints = {
    for k in keys(local.control_nodes) : k => coalesce(
      lookup(local.control_nodes[k], "ip_addr", null),
      try(vsphere_virtual_machine.talos_control_vm[k].default_ip_address, null),
      lookup(local.control_nodes[k], "endpoint", null)
    )
  }

  resolved_worker_endpoints = {
    for k in keys(local.worker_nodes) : k => coalesce(
      lookup(local.worker_nodes[k], "ip_addr", null),
      try(vsphere_virtual_machine.talos_worker_vm[k].default_ip_address, null),
      lookup(local.worker_nodes[k], "endpoint", null)
    )
  }

  # Only include nodes that actually have a resolved endpoint (non-null)
  control_nodes_with_endpoint = { for k, v in local.control_nodes : k => v if local.resolved_control_endpoints[k] != null }
  worker_nodes_with_endpoint  = { for k, v in local.worker_nodes : k => v if local.resolved_worker_endpoints[k] != null }

  # load all patch files from the patches directories
  # we sort each fileset to get a consistent list each time
  common_patch_paths = sort(fileset(path.root, "patches/common/*.yaml"))
  controlplane_patch_paths = sort([
    for p in fileset(path.root, "patches/controlplane/*.yaml") : p
    if p != "patches/controlplane/cilium-inline-manifests.yaml"
  ])
  worker_patch_paths = sort(fileset(path.root, "patches/worker/*.yaml"))

  # Render Cilium inline manifests patch with Helm template output
  cilium_inline_manifest_patch = templatefile("${path.root}/patches/controlplane/cilium-inline-manifests.yaml", {
    cilium_manifests = indent(8, data.helm_template.cilium.manifest)
  })

  # Combine common and controlplane patches to ensure all required configurations are applied to controlplane nodes.
  default_control_patches = sort(concat(local.common_patch_paths, local.controlplane_patch_paths))
  # Combine common and worker patches so that all worker nodes receive both the shared (common) patches and the worker-specific patches.
  default_worker_patches = sort(concat(local.common_patch_paths, local.worker_patch_paths))
  control_patch_contents = concat(
    [for p in local.default_control_patches : file("${path.root}/${p}")],
    [local.cilium_inline_manifest_patch]
  )
  worker_patch_contents = [for p in local.default_worker_patches : file("${path.root}/${p}")]

  # Generate static IP patches per node with complete interface configuration
  # (dvs-pg-vlan20 provides native VLAN 20, no tagging needed)
  control_static_ip_patches = {
    for k, v in local.control_nodes : k => yamlencode({
      machine = {
        network = {
          interfaces = [{
            deviceSelector = {
              physical = true
            }
            dhcp      = false
            mtu       = 1500
            addresses = ["${lookup(v, "ip_addr", "")}/24"]
            routes = [{
              network = "0.0.0.0/0"
              gateway = "172.16.20.1"
            }]
          }]
        }
      }
    })
  }

  worker_static_ip_patches = {
    for k, v in local.worker_nodes : k => yamlencode({
      machine = {
        network = {
          interfaces = [{
            deviceSelector = {
              physical = true
            }
            dhcp      = false
            mtu       = 1500
            addresses = ["${lookup(v, "ip_addr", "")}/24"]
            routes = [{
              network = "0.0.0.0/0"
              gateway = "172.16.20.1"
            }]
          }]
        }
      }
    })
  }
  endpoint = "172.16.20.250"
}


resource "vsphere_virtual_machine" "talos_control_vm" {
  for_each         = local.control_nodes
  name             = each.key
  folder           = var.vm_folder
  datacenter_id    = data.vsphere_datacenter.main.id
  host_system_id   = data.vsphere_host.main.id
  resource_pool_id = data.vsphere_compute_cluster.main.resource_pool_id
  datastore_id     = data.vsphere_datastore.main.id
  guest_id         = var.vsphere_guest_id

  wait_for_guest_net_routable = false
  wait_for_guest_net_timeout  = 0
  wait_for_guest_ip_timeout   = 0
  enable_disk_uuid            = true
  num_cpus                    = var.vsphere_control_vm_cores
  num_cores_per_socket        = var.vsphere_control_vm_cores
  memory                      = var.vsphere_control_vm_memory

  scsi_type = "pvscsi"
  firmware  = "efi"

  network_interface {
    network_id   = data.vsphere_network.main.id
    adapter_type = "vmxnet3"
  }

  ovf_deploy {
    remote_ovf_url = var.image_factory_ova_url
    ovf_network_map = {
      "VM Network" = data.vsphere_network.main.id
    }
  }

  disk {
    label       = "disk0"
    size        = 12
    unit_number = 0
  }

  disk {
    label            = "disk1"
    thin_provisioned = true
    size             = 150
    unit_number      = 1
  }

  extra_config = {
    "guestinfo.talos.config" = base64encode(data.talos_machine_configuration.controlplane[each.key].machine_configuration)
    "disk.enableUUID"        = "TRUE"
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      ovf_deploy,
      ept_rvi_mode,
      hv_mode,
      disk,
    ]
  }
}

resource "vsphere_virtual_machine" "talos_worker_vm" {
  for_each         = local.worker_nodes
  name             = each.key
  folder           = var.vm_folder
  datacenter_id    = data.vsphere_datacenter.main.id
  host_system_id   = data.vsphere_host.main.id
  resource_pool_id = data.vsphere_compute_cluster.main.resource_pool_id
  datastore_id     = data.vsphere_datastore.main.id
  guest_id         = var.vsphere_guest_id

  wait_for_guest_net_routable = false
  wait_for_guest_net_timeout  = 0
  wait_for_guest_ip_timeout   = 0

  enable_disk_uuid     = true
  num_cpus             = var.vsphere_control_vm_cores
  num_cores_per_socket = var.vsphere_control_vm_cores
  memory               = var.vsphere_control_vm_memory

  scsi_type = "pvscsi"
  firmware  = "efi"

  network_interface {
    network_id   = data.vsphere_network.main.id
    adapter_type = "vmxnet3"
  }

  ovf_deploy {
    remote_ovf_url    = var.image_factory_ova_url
    disk_provisioning = "thin"
    ip_protocol       = "IPv4"

    ovf_network_map = {
      "VM Network" = data.vsphere_network.main.id
    }
  }

  disk {
    label            = "disk0"
    thin_provisioned = true
    size             = 12
    unit_number      = 0
  }

  disk {
    label            = "disk1"
    thin_provisioned = true
    size             = 150
    unit_number      = 1
  }

  extra_config = {
    "guestinfo.talos.config" = base64encode(data.talos_machine_configuration.worker[each.key].machine_configuration)
    "disk.enableUUID"        = "TRUE"
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      ovf_deploy,
      ept_rvi_mode,
      hv_mode,
      disk,
    ]
  }
}

resource "talos_machine_secrets" "main" {}

# Generate per-node machine configurations with static IPs baked in
data "talos_machine_configuration" "controlplane" {
  for_each = local.control_nodes

  cluster_name     = var.talos_cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = "https://${local.endpoint}:6443"
  machine_secrets  = talos_machine_secrets.main.machine_secrets
  config_patches = concat(
    local.control_patch_contents,
    [local.control_static_ip_patches[each.key]]
  )
  examples = false
}

data "talos_machine_configuration" "worker" {
  for_each = local.worker_nodes

  cluster_name     = var.talos_cluster_name
  machine_type     = "worker"
  cluster_endpoint = "https://${local.endpoint}:6443"
  machine_secrets  = talos_machine_secrets.main.machine_secrets
  config_patches = concat(
    local.worker_patch_contents,
    [local.worker_static_ip_patches[each.key]]
  )
  examples = false
}

data "talos_client_configuration" "main" {
  cluster_name         = var.talos_cluster_name
  client_configuration = talos_machine_secrets.main.client_configuration
  endpoints            = ["https://${local.endpoint}:6443"]
  nodes                = local.node_ips
}

resource "talos_machine_configuration_apply" "controlplane" {
  for_each = local.control_nodes_with_endpoint

  endpoint = local.resolved_control_endpoints[each.key]
  node     = local.resolved_control_endpoints[each.key]

  client_configuration        = talos_machine_secrets.main.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane[each.key].machine_configuration
  # Static IPs are already baked into machine_configuration_input, only apply additional patches
  config_patches = var.control_machine_config_patches
}

resource "talos_machine_configuration_apply" "worker" {
  for_each = local.worker_nodes_with_endpoint

  endpoint = local.resolved_worker_endpoints[each.key]
  node     = local.resolved_worker_endpoints[each.key]

  client_configuration        = talos_machine_secrets.main.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[each.key].machine_configuration
  # Static IPs are already baked into machine_configuration_input, only apply additional patches
  config_patches = var.worker_machine_config_patches
}

resource "talos_machine_bootstrap" "main" {
  depends_on           = [talos_machine_configuration_apply.worker, talos_machine_configuration_apply.controlplane]
  node                 = "172.16.20.201"
  client_configuration = talos_machine_secrets.main.client_configuration
}

resource "talos_cluster_kubeconfig" "main" {
  depends_on           = [talos_machine_bootstrap.main]
  client_configuration = talos_machine_secrets.main.client_configuration

  node = "${local.endpoint}:6443"
}
