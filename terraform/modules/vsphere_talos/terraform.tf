terraform {
  required_providers {
    vsphere = {
      source  = "vmware/vsphere"
      version = ">=2.15.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.6.1"
    }
  }
}
