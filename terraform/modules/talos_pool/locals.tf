locals {
  machinecfg = {
    for name in var.desired_names :
    name => templatefile("${path.root}/templates/${var.role}.yaml.tmpl", {
      hostname        = name
      role            = var.role
      cluster_name    = var.cluster_name
      cp_endpoint     = var.cp_endpoint
      install_disk    = var.install_disk
      network_mode    = var.network_mode
      static_ip       = try(var.static[name].ip, null)
      static_gw       = try(var.static[name].gw, null)
      static_mask     = try(var.static[name].mask, null)
      cluster_secrets = var.cluster_secrets
      vip             = var.vip
    })
  }
}
