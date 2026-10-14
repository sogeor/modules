locals {
  pools = { for name, p in var.spec.pools : name => p if p.provider == "byo" }

  count_mismatch = [for name, p in local.pools : "${name} (count ${coalesce(p.count, 0)}, hosts ${length(try(var.hosts[name], []))})"
  if coalesce(p.count, 0) != length(try(var.hosts[name], []))]

  unknown_pools = [for name in keys(var.hosts) : name if !contains(keys(local.pools), name)]

  nodes = merge([for pool, p in local.pools : {
    for i, h in try(var.hosts[pool], []) : "${pool}-${i + 1}" => {
      name          = "${var.spec.cluster}-${pool}-${i + 1}"
      fqdn          = "${var.spec.cluster}-${pool}-${i + 1}.${var.domain}"
      cluster       = var.spec.cluster
      distribution  = var.spec.distribution
      role          = p.role
      pool          = pool
      provider      = "byo"
      site          = p.site
      os            = p.os
      private_ip    = coalesce(h.private_ip, h.public_ip)
      public_ip     = h.public_ip
      ssh_user      = p.os == "talos" ? null : try(coalesce(h.ssh_user, var.ssh_user), null)
      labels        = merge(p.labels, { "sogeor.com/pool" = pool, "topology.kubernetes.io/region" = p.site, "topology.kubernetes.io/zone" = coalesce(h.zone, p.site) })
      taints        = p.taints
      mesh_required = p.mesh_required
    }
  }]...)

  missing_ssh_user = [for key, n in local.nodes : n.name if n.os != "talos" && n.ssh_user == null]
}
