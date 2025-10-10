variable "vm_template_name" {
  description = "The name of the vSphere Template to use for vm creation."
  type        = string
}

variable "content_library_name" {
  description = "The name of the vSphere Content Library containing the Talos OVA."
  type        = string
  default     = "talos"
}

variable "talos_library_item" {
  description = "The name of the Talos OVA item in the vSphere Content Library."
  type        = string
  default     = "omni-talos-1.11.2"
}

variable "talos_image_factory_url" {
  description = "The Talos image factory URL for the VMware OVA."
  type        = string

}

variable "role" {
  type    = string
  default = "worker"
  validation {
    condition     = contains(["worker", "controlplane"], var.role)
    error_message = "Role must be one of 'worker' or 'controlplane'."
  }
}

variable "base_name" {
  description = "Base name for the VM."
  type        = string
}

variable "desired_names" {
  type        = set(string)
  description = "Set of desired VM names."
}

variable "talos_version" {
  description = "The Talos version to deploy."
  type        = string
  default     = "v1.11.1"
  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+(-[a-zA-Z0-9]+)?$", var.talos_version))
    error_message = "Talos version must be in the format 'vX.Y.Z' or 'vX.Y.Z-suffix'."
  }
}

variable "cp_endpoint" {
  description = "Control plane endpoint for the Talos cluster."
  type        = string
}

variable "cluster_name" {
  description = "The name of the Talos cluster."
  type        = string
}

variable "cluster_secrets" {
  description = "YAML snippet from talosctl gen config (cluster + token); keep in Vault or similar secret store"
  type = object({
    cluster : object({
      id : string
      secret : string
    }),
    secrets : object({
      bootstraptoken : string
      secretboxencryptionsecret : string
    })
    trustdinfo : object({
      token : string
    })
    certs : object({
      etcd : object({
        crt : string
        key : string
      })
      k8s : object({
        crt : string
        key : string
      })
      k8saggregator : object({
        crt : string
        key : string
      })
      k8sserviceaccount : object({
        key : string
      })
      os : object({
        crt : string
        key : string
      })
    })
  })
}

variable "vsphere" {
  type = object({
    server : string
    username : string
    password : string
    host : string
    datacenter : string
    cluster : string # e.g.
    datastore : string
    network : string
    folder : string
    lib_name : string # e.g. "talos"
    ova_item : string # e.g. "omni-talos-1.11.2"
  })
}

variable "flavor" {
  type = object({
    cpu : number
    mem_mb : number
    disk_gb : number
  })
}

variable "vip" {
  description = "The virtual IP address for the control plane endpoint."
  type        = string
  default     = "172.16.20.250"
}

variable "install_disk" {
  type    = string
  default = "/dev/sda"
}

variable "network_mode" {
  type    = string
  default = "dhcp"
}

variable "static" {
  type = map(object({
    ip : string
    gw : string
    mask : string
  }))
  default = {} # keyed by node name if you want per-node static config
}
