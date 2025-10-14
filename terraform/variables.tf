variable "github_owner" {
  description = "The GitHub owner (user or organization) for the repository."
  type        = string
}
variable "github_token" {
  description = "The GitHub token with appropriate permissions."
  type        = string
  sensitive   = true
}

variable "login_username" {
  description = "The username for Vault authentication."
  type        = string
}

variable "login_password" {
  description = "The address of the Vault server."
  type        = string
}

variable "image_factory_ova_url" {
  description = "The Talos image factory URL."
  type        = string
}

variable "image_factory_schematic" {
  description = "The Talos image factory schematic ID."
  type        = string
}

variable "vsphere_user" {
  description = "The username for vSphere API operations."
  type        = string
}

variable "vsphere_password" {
  description = "The password for vSphere API operations."
  type        = string
  sensitive   = true
}

variable "vsphere_server" {
  description = "The vCenter server name for vSphere API operations."
  type        = string
}

variable "vsphere_host" {
  description = "The ESXi host name for vSphere API operations."
  type        = string
}

variable "vsphere_datacenter" {
  description = "The name of the vSphere Datacenter into which resources will be created."
  type        = string
  default     = "Datacenter"
}

variable "vsphere_cluster" {
  description = "The name of the vSphere Cluster into which resources will be created."
  type        = string
  default     = "Cluster"
}

variable "vsphere_datastore" {
  description = "The name of the vSphere Datastore into which resources will be created."
  type        = string
  default     = "vsanDatastore"
}

variable "vsphere_network" {
  description = "The name of the vSphere Network into which resources will be created."
  type        = string
  default     = "VM Network"
}

variable "content_library_name" {
  description = "The name of the vSphere Content Library containing the Talos OVA."
  type        = string
  default     = "talos"
}

variable "content_library_item" {
  description = "The name of the Talos OVA item in the vSphere Content Library."
  type        = string
  default     = "omni-talos-1.11.2"
}

variable "vm_template_name" {
  description = "The name of the vSphere Template to use for vm creation."
  type        = string
}

variable "vm_folder" {
  description = "The name of the vSphere Folder into which VMs will be created."
  type        = string
  default     = "Talos"
}

variable "vm_disk_size" {
  description = "The default disk size for the vm."
  type        = number
  default     = 10
}

# variable "ssh_authorized_keys" {
#   description = "List of ssh authorized key entry to add to the vm."
#   type        = list(string)
# }

# variable "userdata_file" {
#   description = "Relative path from root to the userdata template file to use."
#   type        = string
# }

# variable "virtual_machines" {
#   type = list(object({
#     fqdn        = string,
#     cpu         = number,
#     memory      = number,
#     ip          = string,
#     gateway     = string,
#     nameservers = list(string)
#   }))
# }

# variable "addl_disks" {
#   type = list(object({
#     label            = string,
#     size             = number,
#     eagerly_scrub    = bool,
#     thin_provisioned = bool,
#     unit_number      = string
#   }))
# }

# variable "talos_library_item" {
#   description = "The name of the vSphere Content Library Item to use for Talos ISO."
#   type        = string
# }

variable "talos_endpoint" {
  description = "The Talos control plane endpoint."
  type        = string
  default     = "172.16.20.250"
  validation {
    // either a valid url (http(s)://...) or IPv4 address
    condition     = can(regex("^(https?://)?((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$", var.talos_endpoint)) || can(regex("^(https?://)?([a-zA-Z0-9.-]+\\.[a-zA-Z]{2,})$", var.talos_endpoint))
    error_message = "talos_endpoint must be a valid URL or IPv4 address"
  }
}

variable "talos_version" {
  description = "The Talos version to deploy."
  type        = string
  default     = "v1.11.2"
  validation {
    condition     = can(regex("^v\\d+\\.\\d+\\.\\d+$", var.talos_version))
    error_message = "talos_version must be in the format X.Y.Z, e.g. 1.11.2"
  }
}

variable "cp_desired_names" {
  description = "List of desired control plane node names."
  type        = list(string)
  default     = ["cluster1-cp-0", "cluster1-cp-1", "cluster1-cp-2"]
}

variable "w_desired_names" {
  description = "List of desired worker node names."
  type        = list(string)
  default     = ["cluster1-w-0", "cluster1-w-1"]
}

variable "cluster_name" {
  description = "The name of the Talos cluster."
  type        = string
  default     = "cluster1"
}

variable "kubernetes_version" {
  description = "The Kubernetes version to deploy."
  type        = string
  default     = "1.34.1"
  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+$", var.kubernetes_version))
    error_message = "kubernetes_version must be in the format X.Y.Z, e.g. 1.28.2"
  }
}

variable "vip" {
  description = "The virtual IP address for the control plane endpoint."
  type        = string
  default     = "172.16.20.250"
}

variable "talos_controlplane_extra_config_patches" {
  description = "Additional configuration patches for control plane nodes."
  type        = list(string)
  default     = []
}

variable "talos_worker_extra_config_patches" {
  description = "Additional configuration patches for worker nodes."
  type        = list(string)
  default     = []
}

# variable "control_nodes" {
#   description = "Map of control plane nodes with their MAC and IP addresses."
#   type = map(object({
#     mac_addr = string
#     ip_addr  = string
#   }))
# }

# variable "worker_nodes" {
#   description = "Map of worker nodes with their MAC and IP addresses."
#     type = map(object({
#       mac_addr = string
#       ip_addr  = string
#   }))
# }

variable "cluster_node_network" {
  type = string
}
