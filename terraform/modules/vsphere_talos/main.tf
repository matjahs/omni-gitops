locals {
  # Use the static IPs supplied in the control_nodes / worker_nodes maps rather than
  # relying on the VM guest IP attribute. The latter depends on VMware tools and
  # the guest reporting its address, which is not available during bootstrap.
  # Prefer explicit static IPs from the input maps (var.control_nodes / var.worker_nodes).
  # If those are not present, fallback to the VM-reported guest IP (default_ip_address).
  primary_control_node_key = keys(var.control_nodes)[0]
  # Prefer the VM-reported IP (via VMware tools) when available; otherwise use
  # the static ip_addr from the input map.
  primary_control_node_ip = coalesce(vsphere_virtual_machine.talos_control_vm[local.primary_control_node_key].default_ip_address, lookup(var.control_nodes[local.primary_control_node_key], "ip_addr", null))

  control_node_ips = [for k in keys(var.control_nodes) : coalesce(vsphere_virtual_machine.talos_control_vm[k].default_ip_address, lookup(var.control_nodes[k], "ip_addr", null))]
  worker_node_ips  = [for k in keys(var.worker_nodes) : coalesce(vsphere_virtual_machine.talos_worker_vm[k].default_ip_address, lookup(var.worker_nodes[k], "ip_addr", null))]
  node_ips = concat(
    local.control_node_ips,
    local.worker_node_ips
  )

  # Resolved endpoints per node (prefer vm default_ip_address, then ip_addr, then endpoint)
  resolved_control_endpoints = {
    for k in keys(var.control_nodes) : k => coalesce(
      try(vsphere_virtual_machine.talos_control_vm[k].default_ip_address, null),
      lookup(var.control_nodes[k], "ip_addr", null),
      lookup(var.control_nodes[k], "endpoint", null)
    )
  }

  resolved_worker_endpoints = {
    for k in keys(var.worker_nodes) : k => coalesce(
      try(vsphere_virtual_machine.talos_worker_vm[k].default_ip_address, null),
      lookup(var.worker_nodes[k], "ip_addr", null),
      lookup(var.worker_nodes[k], "endpoint", null)
    )
  }

  # Only include nodes that actually have a resolved endpoint (non-null)
  control_nodes_with_endpoint = { for k, v in var.control_nodes : k => v if local.resolved_control_endpoints[k] != null }
  worker_nodes_with_endpoint  = { for k, v in var.worker_nodes  : k => v if local.resolved_worker_endpoints[k]  != null }

  # load all patch files from the patches directories
  # we sort each fileset to get a consistent list each time
  common_patch_paths       = sort(fileset(path.module, "patches/common/*.yaml"))
  controlplane_patch_paths = sort(fileset(path.module, "patches/controlplane/*.yaml"))
  worker_patch_paths       = sort(fileset(path.module, "patches/worker/*.yaml"))
  # Combine common and controlplane patches to ensure all required configurations are applied to controlplane nodes.
  default_control_patches = sort(concat(local.common_patch_paths, local.controlplane_patch_paths))
  # Combine common and worker patches so that all worker nodes receive both the shared (common) patches and the worker-specific patches.
  default_worker_patches = sort(concat(local.common_patch_paths, local.worker_patch_paths))
  control_patch_contents = [for p in local.default_control_patches : file("${path.module}/${p}")]
  worker_patch_contents  = [for p in local.default_worker_patches : file("${path.module}/${p}")]
}


resource "vsphere_virtual_machine" "talos_control_vm" {
  for_each         = var.control_nodes
  name             = each.key
  folder           = var.vsphere.folder
  datacenter_id    = data.vsphere_datacenter.main.id
  host_system_id   = data.vsphere_host.main.id
  resource_pool_id = data.vsphere_compute_cluster.main.resource_pool_id
  datastore_id     = data.vsphere_datastore.main.id
  guest_id         = var.vsphere_guest_id

  wait_for_guest_net_routable = false
  wait_for_guest_net_timeout  = 0
  wait_for_guest_ip_timeout   = 0

  # enable_disk_uuid = true

  num_cpus             = var.vsphere_control_vm_cores
  num_cores_per_socket = var.vsphere_control_vm_cores
  memory               = var.vsphere_control_vm_memory

  scsi_type = "pvscsi"
  firmware  = "efi"

  network_interface {
    network_id   = data.vsphere_network.main.id
    adapter_type = "vmxnet3"
    # mac_address    = lookup(each.value, "mac_addr", null)
    # use_static_mac = true
  }

  ovf_deploy {
    remote_ovf_url    = var.talos_image_factory_url
    disk_provisioning = "thin"
    ip_protocol       = "IPv4"

    ovf_network_map = {
      "VM Network" = data.vsphere_network.main.id
    }
  }

  disk {
    label       = "disk0"
    size        = 12
    unit_number = 0
  }

  # Optional extra disk attached to the VM (thin provisioned). Controlled by module variable.
  dynamic "disk" {
    for_each = var.extra_disk_enabled ? [1] : []
    content {
      label            = "extra-disk-1"
      size             = var.extra_disk_size_gb
      controller_type  = "scsi"
      unit_number      = 1
      eagerly_scrub    = false
      thin_provisioned = true
    }
  }

  extra_config = {
    "guestinfo.talos.config"   = base64encode(data.talos_machine_configuration.controlplane.machine_configuration)
    "guestinfo.talos.platform" = "vmware"
    "guestinfo.talos.hostname" = each.key
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      ovf_deploy,
      ept_rvi_mode,
      hv_mode,
    ]
  }
}

resource "vsphere_virtual_machine" "talos_worker_vm" {
  for_each         = var.worker_nodes
  name             = each.key
  folder           = var.vsphere.folder
  datacenter_id    = data.vsphere_datacenter.main.id
  host_system_id   = data.vsphere_host.main.id
  resource_pool_id = data.vsphere_compute_cluster.main.resource_pool_id
  datastore_id     = data.vsphere_datastore.main.id
  guest_id         = var.vsphere_guest_id

  wait_for_guest_net_routable = false
  wait_for_guest_net_timeout  = 0
  wait_for_guest_ip_timeout   = 0

  # enable_disk_uuid = true

  num_cpus             = var.vsphere_control_vm_cores
  num_cores_per_socket = var.vsphere_control_vm_cores
  memory               = var.vsphere_control_vm_memory

  scsi_type = "pvscsi"
  firmware  = "efi"

  network_interface {
    network_id   = data.vsphere_network.main.id
    adapter_type = "vmxnet3"
    # mac_address    = lookup(each.value, "mac_addr", null)
    # use_static_mac = true
  }

  ovf_deploy {
    allow_unverified_ssl_cert = true
    local_ovf_path            = "/Users/matjah/Downloads/vmware-amd64.ova"
    # Ensure the provider requests thin provisioning and uses IPv4 for OVF
    # deployment. This avoids reconfiguration attempts that vSphere may
    # reject for the template disk/device.
    disk_provisioning = "thin"
    ip_protocol       = "IPv4"

    ovf_network_map = {
      "VM Network" = data.vsphere_network.main.id
    }
  }

  disk {
    label       = "disk0"
    size        = 12
    unit_number = 0
  }

  # Optional extra disk attached to the VM (thin provisioned). Controlled by module variable.
  dynamic "disk" {
    for_each = var.extra_disk_enabled ? [1] : []
    content {
      label            = "extra-disk-1"
      size             = var.extra_disk_size_gb
      controller_type  = "scsi"
      unit_number      = 1
      eagerly_scrub    = false
      thin_provisioned = true
    }
  }

  extra_config = {
    "guestinfo.talos.config"   = base64encode(data.talos_machine_configuration.worker.machine_configuration)
    "guestinfo.talos.platform" = "vmware"
    "guestinfo.talos.hostname" = each.key
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      ovf_deploy,
      ept_rvi_mode,
      hv_mode,
    ]
  }
}

resource "talos_machine_secrets" "main" {}

data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.talos_cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = "https://${var.talos_cluster_endpoint}:6443"
  machine_secrets  = talos_machine_secrets.main.machine_secrets
  config_patches   = local.control_patch_contents
}

data "talos_machine_configuration" "worker" {
  cluster_name     = var.talos_cluster_name
  machine_type     = "worker"
  cluster_endpoint = "https://${var.talos_cluster_endpoint}:6443"
  machine_secrets  = talos_machine_secrets.main.machine_secrets
  config_patches   = local.worker_patch_contents
}

data "talos_client_configuration" "talos_client_config" {
  cluster_name         = var.talos_cluster_name
  client_configuration = talos_machine_secrets.main.client_configuration
  endpoints            = local.control_node_ips
  nodes                = local.node_ips
}

resource "talos_machine_configuration_apply" "controlplane" {
  for_each = local.control_nodes_with_endpoint

  endpoint = local.resolved_control_endpoints[each.key]
  node     = local.resolved_control_endpoints[each.key]

  client_configuration        = talos_machine_secrets.main.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  # Only include any extra patches passed in via module inputs here. The base
  # patches are already included in the data.talos_machine_configuration above.
  config_patches = var.control_machine_config_patches
  # Ensure we wait until the Talos RPC endpoint is reachable before applying
  # the configuration to avoid race conditions where the VM is not yet
  # listening on port 50000.
  # depends_on must not use dynamic indexing with each.key; reference the
  # null_resource collection instead so Terraform accepts a static resource
  # reference. This will wait for all waiters before applying, which is
  # acceptable for now and avoids invalid HCL expressions.
  depends_on = [null_resource.wait_for_talos_control]
}

resource "talos_machine_configuration_apply" "worker" {
  for_each = local.worker_nodes_with_endpoint

  endpoint = local.resolved_worker_endpoints[each.key]
  node     = local.resolved_worker_endpoints[each.key]

  client_configuration        = talos_machine_secrets.main.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  config_patches = var.worker_machine_config_patches
  # See note above for why we reference the collection rather than indexing
  depends_on = [null_resource.wait_for_talos_worker]
}


// Per-node waiters: poll the Talos RPC port until it becomes reachable.
resource "null_resource" "wait_for_talos_control" {
  for_each = local.control_nodes_with_endpoint

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      endpoint=$${local.resolved_control_endpoints[each.key]}
      # strip possible scheme and port - allow 'ip' or 'ip:port'
      addr=$${endpoint#*://}
      # default port 50000 if not provided
      host=$${addr%%:*}
      port=$${addr##*:}
      if [ "$${port}" = "$${host}" ]; then port=50000; fi
      echo "Waiting for Talos RPC at $${host}:$${port}..."
      for i in $(seq 1 60); do
        nc -z $${host} $${port} && exit 0 || true
        sleep 5
      done
      echo "Timed out waiting for Talos RPC at $${host}:$${port}" >&2
      exit 1
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "null_resource" "wait_for_talos_worker" {
  for_each = local.worker_nodes_with_endpoint

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      endpoint=$${local.resolved_worker_endpoints[each.key]}
      addr=$${endpoint#*://}
      host=$${addr%%:*}
      port=$${addr##*:}
      if [ "$${port}" = "$${host}" ]; then port=50000; fi
      echo "Waiting for Talos RPC at $${host}:$${port}..."
      for i in $(seq 1 60); do
        nc -z $${host} $${port} && exit 0 || true
        sleep 5
      done
      echo "Timed out waiting for Talos RPC at $${host}:$${port}" >&2
      exit 1
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "talos_machine_bootstrap" "main" {
  depends_on           = [talos_machine_configuration_apply.worker, talos_machine_configuration_apply.controlplane]
  node                 = local.primary_control_node_ip == null ? "" : local.primary_control_node_ip
  client_configuration = talos_machine_secrets.main.client_configuration
}

resource "talos_cluster_kubeconfig" "main" {
  depends_on           = [talos_machine_bootstrap.main]
  client_configuration = talos_machine_secrets.main.client_configuration
  # Use the primary control node IP for kubeconfig retrieval
  node = local.primary_control_node_ip
}
