provider "vsphere" {
  user           = var.vsphere_user
  password       = var.vsphere_password
  vsphere_server = var.vsphere_server

  # If you have a self-signed cert
  allow_unverified_ssl = true
}

provider "vault" {
  auth_login {
    path = "auth/userpass/login/${var.login_username}"
    parameters = {
      password = var.login_password
    }
  }
}

provider "talos" {
  image_factory_url = var.image_factory_ova_url
}

locals {
  nodes_config  = yamldecode(file("${path.module}/nodes.yaml"))
  control_nodes = lookup(local.nodes_config, "control_nodes", [])
  worker_nodes  = lookup(local.nodes_config, "worker_nodes", [])
}
