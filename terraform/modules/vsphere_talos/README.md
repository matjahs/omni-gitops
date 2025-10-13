# Terraform module for deploying Talos on vSphere

This Terraform module automates the deployment of Talos Linux on a vSphere environment. It provisions the necessary resources, including virtual machines, networking, and storage, to run Talos clusters efficiently.

## Usage

```hcl
module "talos" {
  source = "path/to/this/module"

  vsphere_user           = var.vsphere_user
  vsphere_password       = var.vsphere_password
  vsphere_server         = var.vsphere_server
  datacenter             = var.datacenter
  cluster                = var.cluster
  network                = var.network
  datastore              = var.datastore
  talos_image_path       = var.talos_image_path
  master_count           = var.master_count
  worker_count           = var.worker_count
  talos_version          = var.talos_version
  ssh_public_key         = file(var.ssh_public_key_path)
  talos_config_template  = file(var.talos_config_template_path)
}
```
