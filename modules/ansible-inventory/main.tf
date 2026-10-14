locals {
  hosts = { for key, n in var.nodes : n.name => n if n.distribution != "talos" && n.os != "talos" }

  group_name = { for name, n in local.hosts : name => {
    cluster      = "cluster_${replace(n.cluster, "/[^A-Za-z0-9_]/", "_")}"
    distribution = "distribution_${replace(n.distribution, "/[^A-Za-z0-9_]/", "_")}"
    role         = "role_${replace(n.role, "/[^A-Za-z0-9_]/", "_")}"
    site         = "site_${replace(n.site, "/[^A-Za-z0-9_]/", "_")}"
    os           = "os_${replace(n.os, "/[^A-Za-z0-9_]/", "_")}"
  } }

  connection = { for name, n in local.hosts : name => (
    n.site == "home" ? { address = n.private_ip, via = "private" } :
    contains(keys(var.mesh_addresses), name) ? { address = var.mesh_addresses[name], via = "mesh" } :
    n.public_ip != null ? { address = n.public_ip, via = "public" } :
    { address = n.private_ip, via = "private" }
  ) }

  groups = { for name, n in local.hosts : name => sort(concat(
    values(local.group_name[name]),
    n.mesh_required ? ["mesh"] : [],
    n.public_ip != null ? ["internet"] : [],
  )) }

  clusters = distinct([for n in values(local.hosts) : n.cluster])
}

resource "ansible_host" "node" {
  for_each = local.hosts

  name   = each.key
  groups = local.groups[each.key]

  variables = {
    ansible_host       = local.connection[each.key].address
    ansible_user       = each.value.ssh_user
    sogeor_connection  = local.connection[each.key].via
    sogeor_fqdn        = each.value.fqdn
    sogeor_cluster     = each.value.cluster
    sogeor_pool        = each.value.pool
    sogeor_role        = each.value.role
    sogeor_provider    = each.value.provider
    sogeor_site        = each.value.site
    sogeor_os          = each.value.os
    sogeor_private_ip  = each.value.private_ip
    sogeor_public_ip   = each.value.public_ip == null ? "" : each.value.public_ip
    sogeor_node_labels = each.value.labels
    sogeor_node_taints = each.value.taints
  }

  lifecycle {
    precondition {
      condition     = each.value.ssh_user != null
      error_message = "Node ${each.key} has no ssh_user."
    }
  }
}

resource "ansible_group" "cluster" {
  for_each = toset(local.clusters)

  name      = "cluster_${replace(each.key, "/[^A-Za-z0-9_]/", "_")}"
  variables = merge({ sogeor_cluster = each.key }, try(var.cluster_vars[each.key], {}))
}
