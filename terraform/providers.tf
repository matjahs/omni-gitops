terraform {
  required_version = ">=1.13.3"
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">=5.3.0"
    }
    # see https://registry.terraform.io/providers/vmware/vsphere
    # see https://github.com/vmware/terraform-provider-vsphere
    vsphere = {
      source  = "vmware/vsphere"
      version = ">=2.15.0"
    }
    github = {
      source  = "integrations/github"
      version = ">= 6.1"
    }
    # see https://registry.terraform.io/providers/siderolabs/talos
    # see https://github.com/siderolabs/terraform-provider-talos
    talos = {
      source  = "siderolabs/talos"
      version = ">=0.9.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.3"
    }
    # see https://registry.terraform.io/providers/hashicorp/helm
    # see https://github.com/hashicorp/terraform-provider-helm
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0.2"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.1.3"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.1.0"
    }
    # see https://registry.terraform.io/providers/hashicorp/random
    # see https://github.com/hashicorp/terraform-provider-random
    random = {
      source  = "hashicorp/random"
      version = "3.6.2"
    }
    technitium = {
      source  = "kenske/technitium"
      version = ">=0.0.6"
    }
  }
}

provider "local" {
  # Configuration options
}

provider "github" {
  owner = var.github_owner
  token = var.github_token
}

provider "technitium" {
  host  = var.technitium_host
  token = var.technitium_token
}
