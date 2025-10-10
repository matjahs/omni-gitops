terraform {
  required_version = ">=1.13.3"
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">=5.3.0"
    }
    vsphere = {
      source  = "vmware/vsphere"
      version = ">=2.15.0"
    }
    github = {
      source  = "integrations/github"
      version = ">= 6.1"
    }
    talos = {
      source  = "siderolabs/talos"
      version = ">=0.9.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.3"
    }
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
  }
}

provider "local" {
  # Configuration options
}

provider "github" {
  owner = var.github_owner
  token = var.github_token
}
