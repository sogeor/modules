output "endpoint" {
  description = "Kubernetes API endpoint: the VIP for ha, the control-plane node for single."
  value       = local.cluster_endpoint
}

output "installer_image" {
  description = "Talos installer image the nodes run."
  value       = local.installer_image
}

output "config_patches" {
  description = "Machine configuration patches per node key, one YAML document per element."
  value       = module.config.patches
}

output "talosconfig" {
  description = "talosctl client configuration (admin)."
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "kubeconfig" {
  description = "Admin kubeconfig; break-glass only, store in OpenBao."
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "machine_secrets" {
  description = "Talos machine secrets; needed to add nodes or rebuild the cluster, store in OpenBao."
  value       = talos_machine_secrets.this.machine_secrets
  sensitive   = true
}

output "client_configuration" {
  description = "Talos client certificates for other Talos resources."
  value       = talos_machine_secrets.this.client_configuration
  sensitive   = true
}
