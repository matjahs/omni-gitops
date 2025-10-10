terraform {
  required_providers {
    vsphere = {
      source  = "vmware/vsphere"
      version = ">=2.15.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = ">=0.9.0"
    }
  }
}

resource "vsphere_virtual_machine" "main" {
  for_each       = var.desired_names
  name           = each.key
  folder         = var.vsphere.folder
  datacenter_id  = data.vsphere_datacenter.main.id
  host_system_id = data.vsphere_host.main.id

  resource_pool_id = data.vsphere_compute_cluster.main.resource_pool_id
  datastore_id     = data.vsphere_datastore.main.id
  scsi_type        = "pvscsi"
  firmware         = "efi"

  num_cpus = var.flavor.cpu
  memory   = var.flavor.mem_mb

  network_interface {
    network_id   = data.vsphere_network.main.id
    adapter_type = "vmxnet3"
  }

  disk {
    label            = "disk0"
    size             = var.flavor.disk_gb
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
    # "guestinfo.talos.config"   = base64encode(local.machinecfg[each.key])
    "guestinfo.talos.platform" = "vmware"
    "guestinfo.talos.hostname" = each.value
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [ovf_deploy]
  }

  wait_for_guest_net_timeout  = 0
  wait_for_guest_ip_timeout   = 0
  wait_for_guest_net_routable = false
}

resource "null_resource" "vm_reboot" {
  for_each = var.desired_names

  triggers = {
    vm_id       = vsphere_virtual_machine.main[each.key].id
    config_hash = local.machinecfg[each.key]
  }

  provisioner "local-exec" {
    environment = {
      GOVC_URL      = var.vsphere.server
      GOVC_USERNAME = var.vsphere.username
      GOVC_PASSWORD = var.vsphere.password
      GOVC_INSECURE = "1"
    }
    command = "govc vm.power -reset ${vsphere_virtual_machine.main[each.key].name}"
  }
}
