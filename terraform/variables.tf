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
  description = "The password for Vault authentication."
  type        = string
}

variable "technitium_host" {
  description = "The Technitium DNS server host."
  type        = string
}

variable "technitium_token" {
  description = "The Technitium DNS server API token."
  type        = string
  sensitive   = true
}

variable "image_factory_ova_url" {
  description = "The Talos image factory URL."
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

variable "kubernetes_version" {
  description = "The Kubernetes version to deploy."
  type        = string
  default     = "1.34.1"
  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+$", var.kubernetes_version))
    error_message = "kubernetes_version must be in the format X.Y.Z, e.g. 1.28.2"
  }
}


variable "cluster_node_network" {
  description = "172.16.20.0/24"
  type        = string
}

variable "vsphere_control_vm_cores" {
  description = "Number of CPU cores for the control VMs"
  type        = number
  default     = 4
}

variable "vsphere_control_vm_memory" {
  description = "Memory in MB for the control VMs"
  type        = number
  default     = 4096
}

variable "vsphere_guest_id" {
  description = "vSphere guest ID for the VMs"
  type        = string
  default     = "other3xLinux64Guest"
}

variable "talos_cluster_name" {
  description = "Name of the Talos cluster"
  type        = string
  default     = "cluster1"
}

variable "control_machine_config_patches" {
  description = "List of YAML patches to apply to the control machine configuration"
  type        = list(string)
  default     = []
}

variable "worker_machine_config_patches" {
  description = "List of YAML patches to apply to the worker machine configuration"
  type        = list(string)
  default     = []
}
