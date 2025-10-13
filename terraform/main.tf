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
  vsphere = {
    server     = var.vsphere_server
    username   = var.vsphere_user
    password   = var.vsphere_password
    host       = var.vsphere_host
    datacenter = var.vsphere_datacenter
    cluster    = var.vsphere_cluster
    datastore  = var.vsphere_datastore
    network    = var.vsphere_network
    folder     = var.vm_folder
    lib_name   = var.content_library_name
    ova_item   = var.content_library_item
  }
}

module "talos" {
  source = "./modules/vsphere_talos"

  talos_cluster_name = "cluster2"

  kubernetes_version     = var.kubernetes_version
  talos_cluster_endpoint = "api.lab.mxe11.nl"
  control_nodes = {
    "talos-cp01" = { mac = "00:50:56:86:D2:C7", ip_addr = "172.16.20.201" }
    "talos-cp02" = { mac = "00:50:56:86:55:07", ip_addr = "172.16.20.202" }
    "talos-cp03" = { mac = "00:50:56:86:91:3D", ip_addr = "172.16.20.203" }
  }
  control_machine_config_patches = []
  worker_nodes = {
    "talos-w01" = { mac = "00:50:56:86:25:7C", ip_addr = "172.16.20.211" }
    "talos-w02" = { mac = "00:50:56:86:61:E1", ip_addr = "172.16.20.212" }
    "talos-w03" = { mac = "00:50:56:86:F4:D0", ip_addr = "172.16.20.213" }
  }
  worker_machine_config_patches = []
  vsphere                       = local.vsphere
  talos_image_factory_url       = var.image_factory_ova_url
  image_factory_schematic       = var.image_factory_schematic
}

# module "controlplane" {
#   source = "./modules/talos_pool"

#   role                    = "controlplane"
#   base_name               = "${var.cluster_name}-controlplane"
#   desired_names           = toset(var.cp_desired_names)
#   talos_version           = var.talos_version
#   talos_image_factory_url = var.image_factory_url
#   cp_endpoint             = var.talos_endpoint
#   cluster_name            = var.cluster_name
#   cluster_secrets         = jsondecode(vault_kv_secret_v2.cluster_secrets.data_json)
#   vsphere                 = local.vsphere
#   vm_template_name        = var.content_library_name
#   flavor                  = { cpu = 2, mem_mb = 8192, disk_gb = 40 }
# }

# module "workers" {
#   source = "./modules/talos_pool"

#   role                    = "worker"
#   base_name               = "${var.cluster_name}-worker"
#   desired_names           = toset(var.w_desired_names)
#   talos_version           = var.talos_version
#   talos_image_factory_url = var.image_factory_url
#   cp_endpoint             = var.talos_endpoint
#   cluster_name            = var.cluster_name
#   cluster_secrets         = jsondecode(vault_kv_secret_v2.cluster_secrets.data_json)
#   vsphere                 = local.vsphere
#   vm_template_name        = var.content_library_name
#   flavor                  = { cpu = 4, mem_mb = 16384, disk_gb = 40 }
# }

resource "talos_machine_secrets" "main" {
  talos_version = var.talos_version
}

# locals {
#   cluster_endpoint = "https://${var.vip}:6443"

#   cluster_api_host = "kube.cluster1.lab.mxe11.nl"
#   cert_SANs = []
#   cluster_config = {
#     cluster = {
#       allowSchedulingOnControlPlane = true
#       network = {
#         dnsDomain = "cluster1.lab.mxe11.nl"
#         cni = {
#           name = "none"
#         }
#       }
#       proxy       = { disabled = true }
#       coreDNS     = { disabled = true }
#       clusterName = var.cluster_name
#       extraManifests = [
#         "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml",
#         "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.1/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml",
#         "https://raw.githubusercontent.com/alex1989hu/kubelet-serving-cert-approver/main/deploy/standalone-install.yaml",
#         "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
#       ]
#       inlineManifests = [
#         {
#           name     = "cilium"
#           contents = data.helm_template.cilium_default[0].manifest
#         },
#         {
#           name     = "coredns"
#           contents = data.helm_template.coredns_default[0].manifest
#         }
#       ]
#     }
#   }
#   controlplane_config = {
#     machine = {
#       kubelet = {
#         clusterDNS = [ "172.16.0.53" ]
#         extraArgs = {
#           rotate-server-certificates = true
#         }
#       }
#       extraMounts = [
#         {
#           destination = "/var/lib/longhorn"
#           type = "bind"
#           source = "/var/lib/longhorn"
#           options = [
#             "bind",
#             "rshared",
#             "rw"
#           ]
#         }
#       ]
#       sysctls = {
#         "vm.nr_hugepages" = "1024"
#       }
#       kernel = {
#         modules = [
#           { name = "nvme_tcp" },
#           { name = "vfio_pci" }
#         ]
#       }
#       install = {
#         disk = "/dev/sda"
#         extraKernelArgs = [
#           "net.ifnames=0",
#           "ipv6.disable=1"
#         ]
#       }
#       certSANs = local.cert_SANs
#       network = {
#         interfaces = [
#           {
#             deviceSelector = {
#               physical = true
#             }
#             dhcp = true
#             vip = {
#               ip = "172.16.20.250"
#             }
#           }
#         ]
#       }
#     }
#   }
#   worker_config = {
#     machine = {
#       kubelet = {
#         extraMounts = [
#           {
#             destination = "/var/lib/longhorn"
#             type = "bind"
#             source = "/var/lib/longhorn"
#             options = ["bind", "rshared", "rw"]
#           }
#         ]
#       }
#       sysctl = {
#         "vm.nr_hugepages" = "1024"
#       }
#       kernel = {
#         modules = [
#           { name = "nvme_tcp" },
#           { name = "vfio_pci" }
#         ]
#         extraArgs = {
#           rotate-server-certificates = true
#         }
#       }
#       install = {
#         extraKernelArgs = ["net.ifnames=0", "ipv6.disable=1"]
#       }
#       nodeLabels = {
#         "topology.kubernetes.io/region" = "eu-west-1"
#         "topology.kubernetes.io/zone" = "az1"
#       }
#     }
#   }
# }

# data "talos_machine_configuration" "controlplane" {
#   for_each = module.controlplane.virtual_machines

#   talos_version      = var.talos_version
#   cluster_name       = var.cluster_name
#   cluster_endpoint   = local.cluster_endpoint
#   kubernetes_version = var.kubernetes_version
#   machine_type       = "controlplane"
#   machine_secrets    = talos_machine_secrets.main.machine_secrets
#   config_patches = concat(
#     [
#       yamlencode(local.controlplane_yaml[each.value.name])
#     ],
#     var.talos_controlplane_extra_config_patches
#   )
#   docs     = false
#   examples = false

#   depends_on = [talos_machine_secrets.main]
# }

# resource "talos_machine_configuration" "worker" {
#   for_each = module.workers.virtual_machines



#   depends_on = [talos_machine_secrets.main]
# }

# resource "talos_machine_configuration_apply" "main" {
#   for_each = module.controlplane.virtual_machines

#   node                        = each.value.name
#   client_configuration        = talos_machine_secrets.main.client_configuration
#   machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
#   config_patches = yamlencode({
#     cluster = {
#       allowSchedulingOnControlPlane = true
#       network = {
#         dnsDomain = "cluster1.lab.mxe11.nl"
#         cni = {
#           name = "none"
#         }
#       }
#       proxy       = { disabled = true }
#       coreDNS     = { disabled = true }
#       clusterName = var.cluster_name
#       extraManifests = [
#         "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml",
#         "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.1/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml",
#         "https://raw.githubusercontent.com/alex1989hu/kubelet-serving-cert-approver/main/deploy/standalone-install.yaml",
#         "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
#       ]
#       inlineManifests = [
#         {
#           name     = "cilium-values"
#           contents = file("${path.root}/files/cilium-values.yaml")
#         },
#         {
#           name     = "cilium-bootstrap"
#           contents = file("${path.root}/files/cilium-install.yaml")
#         },
#         {
#           name     = "coredns-bootstrap"
#           contents = file("${path.root}/files/coredns-install.yaml")
#         }
#       ]
#     }
#   })
# }
