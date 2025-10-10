
locals {
  primary_control_node_ip = vsphere_virtual_machine.talos_control_vm[keys(var.control_nodes)[0]].default_ip_address
  control_node_ips        = [for vm in keys(var.control_nodes) : vsphere_virtual_machine.talos_control_vm[vm].default_ip_address]
  worker_node_ips         = [for vm in keys(var.worker_nodes) : vsphere_virtual_machine.talos_worker_vm[vm].default_ip_address]
  node_ips = concat(
    local.control_node_ips,
    local.worker_node_ips
  )
  common_patch_paths       = sort(fileset(path.module, "patches/common/*.yaml"))
  controlplane_patch_paths = sort(fileset(path.module, "patches/controlplane/*.yaml"))
  worker_patch_paths       = sort(fileset(path.module, "patches/worker/*.yaml"))
  default_control_patches = [
    for patch in concat(local.common_patch_paths, local.controlplane_patch_paths) :
    file("${path.module}/${patch}")
  ]
  default_worker_patches = [
    for patch in concat(local.common_patch_paths, local.worker_patch_paths) :
    file("${path.module}/${patch}")
  ]
}



resource "vsphere_virtual_machine" "talos_control_vm" {
  for_each       = var.control_nodes
  name           = each.key
  folder         = var.vsphere.folder
  datacenter_id  = data.vsphere_datacenter.main.id
  host_system_id = data.vsphere_host.main.id
  resource_pool_id = data.vsphere_compute_cluster.main.resource_pool_id
  datastore_id = data.vsphere_datastore.main.id
  extra_config_reboot_required = true
  scsi_type  = "pvscsi"
  firmware   = "efi"
  guest_id = "otherGuest64"

  num_cpus = var.vsphere_control_vm_cores
  memory   = var.vsphere_control_vm_memory

  network_interface {
    network_id   = data.vsphere_network.main.id
    adapter_type = "vmxnet3"
  }

  disk {
    label            = "disk0"
    size             = var.vsphere_control_vm_disk_size
    thin_provisioned = true
  }

  ovf_deploy {
    remote_ovf_url    = var.talos_image_factory_url
    disk_provisioning = "thin"

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

  wait_for_guest_net_timeout  = 0
  wait_for_guest_ip_timeout   = 0
  wait_for_guest_net_routable = false
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
  for_each       = var.worker_nodes
  name           = each.key
  folder         = var.vsphere.folder
  datacenter_id  = data.vsphere_datacenter.main.id
  host_system_id = data.vsphere_host.main.id
  datastore_id = data.vsphere_datastore.main.id
  resource_pool_id = data.vsphere_compute_cluster.main.resource_pool_id
  guest_id = "otherGuest64"
  extra_config_reboot_required = true
  num_cpus = var.vsphere_control_vm_cores
  memory   = var.vsphere_control_vm_memory

  network_interface {
    network_id   = data.vsphere_network.main.id
    adapter_type = "vmxnet3"
  }

  disk {
    label            = "disk0"
    size             = var.vsphere_control_vm_disk_size
    thin_provisioned = true
  }

  ovf_deploy {
    remote_ovf_url    = var.talos_image_factory_url
    disk_provisioning = "thin"

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

  wait_for_guest_net_timeout  = 5
  wait_for_guest_net_routable = true
}

resource "talos_machine_secrets" "main" {}

data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.talos_cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = var.talos_cluster_endpoint
  machine_secrets  = talos_machine_secrets.main.machine_secrets
}

data "talos_machine_configuration" "worker" {
  cluster_name     = var.talos_cluster_name
  machine_type     = "worker"
  cluster_endpoint = var.talos_cluster_endpoint
  machine_secrets  = talos_machine_secrets.main.machine_secrets
}

data "talos_client_configuration" "talos_client_config" {
  cluster_name         = var.talos_cluster_name
  client_configuration = talos_machine_secrets.main.client_configuration
  endpoints            = local.control_node_ips
  nodes                = local.node_ips

  depends_on = [
    talos_machine_secrets.main
  ]
}

resource "talos_machine_configuration_apply" "controlplane" {
  for_each                    = var.control_nodes

  client_configuration        = talos_machine_secrets.main.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = vsphere_virtual_machine.talos_control_vm[each.key].name
  config_patches              = concat(local.default_control_patches, var.control_machine_config_patches)

  depends_on = [vsphere_virtual_machine.talos_control_vm]
}

resource "talos_machine_configuration_apply" "worker" {
  for_each                    = var.worker_nodes

  client_configuration        = talos_machine_secrets.main.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = vsphere_virtual_machine.talos_worker_vm[each.key].name
  config_patches              = concat(local.default_worker_patches, var.worker_machine_config_patches)

  depends_on = [vsphere_virtual_machine.talos_worker_vm]
}

resource "talos_machine_bootstrap" "main" {
  node                 = local.primary_control_node_ip == null ? "" : local.primary_control_node_ip
  client_configuration = talos_machine_secrets.main.client_configuration

  depends_on = [
    talos_machine_configuration_apply.controlplane,
    talos_machine_configuration_apply.worker
  ]
}

resource "talos_cluster_kubeconfig" "main" {
  client_configuration = talos_machine_secrets.main.client_configuration
  node                 = local.primary_control_node_ip == null ? "" : local.primary_control_node_ip

  depends_on           = [talos_machine_bootstrap.main]
}
