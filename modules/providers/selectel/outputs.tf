output "flavors" {
  description = "Flavor name per size used by the Selectel pools."
  value       = local.flavors
}

output "external_network" {
  description = "External network: id and name."
  value       = { id = data.openstack_networking_network_v2.external.id, name = data.openstack_networking_network_v2.external.name }
}

output "ssh_key_name" {
  description = "Name of the break-glass key pair, or null."
  value       = local.ssh_key_name
}

output "capi_openstack" {
  description = "Values for the openstack input of capi-cluster; merge identity_secret and other settings into it."
  value = {
    external_network = var.external_network
    dns_nameservers  = var.dns_nameservers
    flavors          = local.flavors
    volume_type      = var.volume_type
    ssh_key_name     = local.ssh_key_name
  }
}
