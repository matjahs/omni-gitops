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

variable "kubernetes_version" {
  type = string
  default = "1.34.1"
  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+$", var.kubernetes_version))
    error_message = "kubernetes_version must be in the format 'X.Y.Z'"
  }
}

variable "vsphere_control_vm_cores" {
  description = "Number of CPU cores for the control VMs"
  type        = number
  default     = 4
}

variable "vsphere_worker_vm_cores" {
  description = "Number of CPU cores for the worker VMs"
  type        = number
  default     = 4
}

variable "vsphere_control_vm_memory" {
  description = "Memory in MB for the control VMs"
  type        = number
  default     = 4096
}

variable "vsphere_worker_vm_memory" {
  description = "Memory in MB for the worker VMs"
  type        = number
  default     = 4096
}

variable "vsphere_guest_id" {
  description = "vSphere guest ID for the VMs"
  type        = string
  default     = "other3xLinux64Guest"
}

variable "vsphere_control_vm_disk_size" {
  description = "vSphere control VM disk size in GB"
  type        = number
  default     = 32
}

variable "vsphere_worker_vm_disk_size" {
  description = "vSphere worker VM disk size in GB"
  type        = number
  default     = 100
}

variable "vsphere_network" {
  description = "vSphere network for the VMs"
  type        = string
  default     = "dvs-pg-vlan20"
}

variable "talos_cluster_name" {
  description = "Name of the Talos cluster"
  type        = string
}

variable "talos_cluster_endpoint" {
  description = "Endpoint used by Talos nodes to reach the control plane (include scheme, e.g. https://vip:6443)"
  type        = string
}

variable "talos_schematic_id" {
  # Generate your own at https://factory.talos.dev/
  # The this id has these extensions:
  # qemu-guest-agent (required)
  # If you make your own make sure you check this extension
  # The ID is independent of the version and architecture of the image
  description = "Schematic ID for the Talos cluster"
  type        = string
}

variable "talos_image_factory_url" {
  description = "URL for the Talos image factory OVA"
  type        = string
}

variable "talos_version" {
  description = "Version of Talos to use"
  type        = string
  default     = "v1.11.2"
}

variable "talos_arch" {
  description = "Architecture of Talos to use"
  type        = string
  default     = "amd64"
}

# Theses two variables are maps that control how many control and worker nodes are created
# and what their names are. The keys are the talos node names and the values are ip addresses
# to create the VMs on.
# Example:
# control_nodes = {
#   "talos-control-0" = { name = "talos-control-0", ip_addr = "172.16.0.10" }
# }
# worker_nodes = {
#   "talos-worker-0" = { name = "talos-worker-1", ip_addr = "172.16.0.11" }
#   "talos-worker-1" = { name = "talos-worker-2", ip_addr = "172.16.0.12" }
# }
variable "control_nodes" {
  description = "Map of talos control node names to vsphere node names"
  type = map(object({
    name : string
    mac : string
  }))
}

variable "worker_nodes" {
  description = "Map of talos worker node names to vsphere node names"
  type = map(object({
    name : string
    mac : string
  }))
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

variable "worker_extra_disks" {
  # This allows for extra disks to be added to the worker VMs
  # TODO - Should we allow other things like host PCI devices as well E.g., GPUs?
  description = "Map of talos worker node name to a list of extra disk blocks for the VMs"
  type = map(list(object({
    datastore_id = string
    size         = number
    file_format  = optional(string)
    file_id      = optional(string)
  })))
  default = {}
}
