output "talos_config" {
  description = "The Talos configuration for the cluster."
  value       = data.talos_client_configuration.main
  sensitive   = true
}

output "kubeconfig" {
  description = "The kubeconfig file to access the Talos cluster."
  value       = talos_cluster_kubeconfig.main.kubeconfig_raw
  sensitive   = true
}

output "primary_control_node_ip" {
  description = "The IP address of the primary control node."
  value       = local.primary_control_node_ip
}

output "node_ips" {
  description = "The IP addresses of all nodes."
  value       = local.node_ips
}

output "control_node_ips" {
  description = "The IP addresses of the control nodes."
  value       = local.control_node_ips
}

output "worker_node_ips" {
  description = "The IP addresses of the worker nodes."
  value       = local.worker_node_ips
}

output "talosconfig" {
  value     = data.talos_client_configuration.main.talos_config
  sensitive = true
}

output "controllers" {
  value = join(",", [for node in var.control_nodes : node.ip_addr])
}

output "workers" {
  value = join(",", [for node in var.worker_nodes : node.ip_addr])
}
