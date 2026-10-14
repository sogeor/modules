output "nodes" {
  description = "Nodes in the normalized node contract, keyed by POOL-INDEX, for example cp-1."
  value = { for key, n in local.nodes : key => {
    name          = n.name
    fqdn          = "${n.name}.${var.network.domain}"
    cluster       = var.spec.cluster
    distribution  = var.spec.distribution
    role          = n.pool_spec.role
    pool          = n.pool
    provider      = "proxmox"
    site          = n.pool_spec.site
    os            = n.pool_spec.os
    private_ip    = n.private_ip
    public_ip     = null
    ssh_user      = n.talos ? null : try(var.ssh.user, null)
    labels        = merge(n.pool_spec.labels, { "topology.kubernetes.io/region" = n.pool_spec.site, "topology.kubernetes.io/zone" = var.proxmox.node_name })
    taints        = n.pool_spec.taints
    mesh_required = n.pool_spec.mesh_required
    vm_id         = proxmox_virtual_environment_vm.node[key].vm_id
  } }
}

output "templates" {
  description = "Selected template per OS: name, vm_id and node."
  value       = { for os, t in local.templates : os => t == null ? null : { name = t.name, vm_id = t.vm_id, node_name = t.node_name } }
}

output "clone_sources" {
  description = "Template VM ID each Ubuntu node is cloned from when created, keyed like nodes."
  value       = { for key, n in local.nodes : key => local.templates[n.pool_spec.os].vm_id if !n.talos && try(local.templates[n.pool_spec.os] != null, false) }
}

output "talos_iso" {
  description = "Proxmox file ID of the Talos ISO, or null when there are no Talos pools."
  value       = try(proxmox_download_file.talos_iso[0].id, null)
}
