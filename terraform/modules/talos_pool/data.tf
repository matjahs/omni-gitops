data "vsphere_datacenter" "main" {
  name = var.vsphere.datacenter
}

data "vsphere_compute_cluster" "main" {
  name          = var.vsphere.cluster
  datacenter_id = data.vsphere_datacenter.main.id
}

data "vsphere_datastore" "main" {
  name          = var.vsphere.datastore
  datacenter_id = data.vsphere_datacenter.main.id
}

data "vsphere_network" "main" {
  name          = var.vsphere.network
  datacenter_id = data.vsphere_datacenter.main.id
}

data "vsphere_content_library" "main" {
  name = var.vsphere.lib_name
}

data "vsphere_content_library_item" "main" {
  type       = "ova"
  name       = var.vsphere.ova_item
  library_id = data.vsphere_content_library.main.id
}

data "vsphere_host" "main" {
  name          = var.vsphere.host
  datacenter_id = data.vsphere_datacenter.main.id
}
