output "talosconfig" {
  description = "The Talos configuration for the cluster."
  value       = module.talos.talos_config
  sensitive   = true
}
output "kubeconfig" {
  description = "kubeconfig"
  value       = module.talos.kubeconfig
  sensitive   = true
}
