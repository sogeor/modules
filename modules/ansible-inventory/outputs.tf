output "hosts" {
  description = "Inventory hosts: connection address, how it is reached (private, mesh or public) and groups."
  value = { for name, n in local.hosts : name => {
    ansible_host = local.connection[name].address
    connection   = local.connection[name].via
    groups       = local.groups[name]
  } }
}

output "groups" {
  description = "All group names with their hosts."
  value       = { for g in distinct(flatten(values(local.groups))) : g => sort([for name, gs in local.groups : name if contains(gs, g)]) }
}

output "bootstrap_hosts" {
  description = "Hosts outside home still reached by their public address; they must join the mesh before the internet hardening closes SSH."
  value       = sort([for name, c in local.connection : name if c.via == "public"])
}
