data "local_sensitive_file" "main" {
  filename = "secrets.yaml"
}

locals {
  content = data.local_sensitive_file.main.content
  secrets = yamldecode(data.local_sensitive_file.main.content)
}

resource "vault_mount" "main" {
  path        = "talos"
  type        = "kv"
  options     = { version = "2" }
  description = "Talos secrets"
}

resource "vault_kv_secret_v2" "cluster_secrets" {
  mount               = vault_mount.main.path
  name                = "cluster_secrets"
  delete_all_versions = true
  data_json           = jsonencode(local.secrets)

  lifecycle {
    ignore_changes = [data_json]
  }
}
