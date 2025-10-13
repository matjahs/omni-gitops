locals {
  primary_control_node_ip = "172.16.20.201"
  control_node_ips = [
    "172.16.20.201", "172.16.20.202", "172.16.20.203"
  ]
  worker_node_ips = [
    "172.16.20.211", "172.16.20.212", "172.16.20.213"
  ]
  node_ips = concat(
    local.control_node_ips,
    local.worker_node_ips
  )

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
  worker_patch_contents  = [for p in local.default_worker_patches  : file("${path.module}/${p}")]
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

  num_cpus = var.vsphere_control_vm_cores
  memory   = var.vsphere_control_vm_memory

  scsi_type                    = "pvscsi"
  firmware                     = "efi"
  efi_secure_boot_enabled      = false
  enable_disk_uuid             = true
  extra_config_reboot_required = true

  network_interface {
    network_id     = data.vsphere_network.main.id
    adapter_type   = "vmxnet3"
    mac_address    = lookup(each.value, "mac", null)
    use_static_mac = true
  }

  disk {
    label            = "disk0"
    size             = var.vsphere_control_vm_disk_size
    thin_provisioned = true
  }

  ovf_deploy {
    remote_ovf_url            = var.talos_image_factory_url
    disk_provisioning         = "thin"

    ovf_network_map = {
      "VM Network" = data.vsphere_network.main.id
    }
  }

  extra_config = {
    "guestinfo.talos.config"   = base64encode(data.talos_machine_configuration.controlplane.machine_configuration)
    "guestinfo.talos.platform" = "vmware"
    "guestinfo.talos.hostname" = each.key
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [ovf_deploy]
  }
}

# resource "null_resource" "vm_reboot" {
#   for_each = var.worker_nodes

#   triggers = {
#     vm_id = vsphere_virtual_machine.main[each.key].id
#     config_hash = local.[each.key]
#   }

#   provisioner "local-exec" {
#     environment = {
#       GOVC_URL = var.vsphere.server
#       GOVC_USERNAME = var.vsphere.username
#       GOVC_PASSWORD = var.vsphere.password
#       GOVC_INSECURE = "1"
#     }
#     command = "govc vm.power -reset ${vsphere_virtual_machine.main[each.key].name}"
#   }
# }


resource "vsphere_virtual_machine" "talos_worker_vm" {
  for_each         = var.worker_nodes
  name             = each.key
  folder           = var.vsphere.folder
  datacenter_id    = data.vsphere_datacenter.main.id
  host_system_id   = data.vsphere_host.main.id
  resource_pool_id = data.vsphere_compute_cluster.main.resource_pool_id
  datastore_id     = data.vsphere_datastore.main.id
  guest_id         = var.vsphere_guest_id

  num_cpus = var.vsphere_control_vm_cores
  memory   = var.vsphere_control_vm_memory

  scsi_type                    = "pvscsi"
  firmware                     = "efi"


  network_interface {
    network_id     = data.vsphere_network.main.id
    adapter_type   = "vmxnet3"
    mac_address    = lookup(each.value, "mac", null)
    use_static_mac = true
  }

  disk {
    label            = "disk0"
    size             = var.vsphere_control_vm_disk_size
    thin_provisioned = true
  }

  ovf_deploy {
    remote_ovf_url       = var.talos_image_factory_url
    disk_provisioning    = "thin"
    ip_allocation_policy = "DHCP"
    ip_protocol          = "IPv4"
    ovf_network_map = {
      "VM Network" = data.vsphere_network.main.id
    }
  }

  extra_config = {
    "guestinfo.talos.config"   = base64encode(data.talos_machine_configuration.worker.machine_configuration)
    "guestinfo.talos.platform" = "vmware"
    "guestinfo.talos.hostname" = each.key
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [ovf_deploy]
  }
}

resource "talos_machine_secrets" "main" {}

data "talos_machine_configuration" "controlplane" {
  cluster_name       = var.talos_cluster_name
  machine_type       = "controlplane"
  cluster_endpoint   = "https://${var.talos_cluster_endpoint}:6443"
  machine_secrets    = talos_machine_secrets.main.machine_secrets
  config_patches     = local.control_patch_contents
}

data "talos_machine_configuration" "worker" {
  cluster_name       = var.talos_cluster_name
  machine_type       = "worker"
  cluster_endpoint   = "https://${var.talos_cluster_endpoint}:6443"
  machine_secrets    = talos_machine_secrets.main.machine_secrets
  config_patches     = local.worker_patch_contents
}

data "talos_client_configuration" "talos_client_config" {
  cluster_name         = var.talos_cluster_name
  client_configuration = talos_machine_secrets.main.client_configuration
  endpoints            = local.control_node_ips
  nodes                = local.node_ips
}

resource "talos_machine_configuration_apply" "controlplane" {
  for_each = var.control_nodes

  client_configuration        = talos_machine_secrets.main.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = vsphere_virtual_machine.talos_control_vm[each.key].name
  config_patches              = concat(local.control_patch_contents, var.control_machine_config_patches)
}

resource "talos_machine_configuration_apply" "worker" {
  for_each = var.worker_nodes

  client_configuration        = talos_machine_secrets.main.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = vsphere_virtual_machine.talos_worker_vm[each.key].name
  config_patches              = concat(local.worker_patch_contents, var.worker_machine_config_patches)
}

resource "talos_machine_bootstrap" "main" {
  depends_on           = [talos_machine_configuration_apply.worker, talos_machine_configuration_apply.controlplane]
  node                 = local.primary_control_node_ip == null ? "" : local.primary_control_node_ip
  client_configuration = talos_machine_secrets.main.client_configuration
}

resource "talos_cluster_kubeconfig" "main" {
  depends_on = [talos_machine_bootstrap.main]
  client_configuration         = talos_machine_secrets.main.client_configuration
  node = "172.16.20.201"
}
