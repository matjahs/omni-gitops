data "vsphere_datacenter" "main" {
  name = var.vsphere_datacenter
}

data "vsphere_compute_cluster" "main" {
  name          = var.vsphere_cluster
  datacenter_id = data.vsphere_datacenter.main.id
}

data "vsphere_datastore" "main" {
  name          = var.vsphere_datastore
  datacenter_id = data.vsphere_datacenter.main.id
}

data "vsphere_network" "main" {
  name          = var.vsphere_network
  datacenter_id = data.vsphere_datacenter.main.id
}

data "vsphere_host" "main" {
  name          = var.vsphere_host
  datacenter_id = data.vsphere_datacenter.main.id
}
