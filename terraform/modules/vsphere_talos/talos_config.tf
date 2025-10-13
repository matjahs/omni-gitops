# data "talos_machine_configuration" "worker" {
#   count = var.worker_count

#   cluster_name = var.cluster_name
#   cluster_endpoint = var.cluster_endpoint
#   machine_secrets = talos_machine_secrets.main.machine_secrets
#   machine_type = "worker"
#   talos_version = var.talos_version
#   kubernetes_version = var.kubernetes_version
#   examples = false
#   docs = false
# }
