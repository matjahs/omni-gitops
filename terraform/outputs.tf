output "talosconfig" {
  description = "The Talos configuration for the cluster."
  value       = data.talos_client_configuration.main
  sensitive   = true
}

output "kubeconfig" {
  description = "The kubeconfig file to access the Talos cluster."
  value       = talos_cluster_kubeconfig.main.kubeconfig_raw
  sensitive   = true
}
