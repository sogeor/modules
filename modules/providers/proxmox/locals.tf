locals {
  enabled = var.spec.mechanism == "opentofu"

  pools = local.enabled ? { for name, p in var.spec.pools : name => p if p.provider == "proxmox" } : {}

  talos_pools    = { for name, p in local.pools : name => p if p.os == "talos" }
  template_pools = { for name, p in local.pools : name => p if p.os != "talos" }

  template_kind = var.spec.distribution == "kubeadm" ? "k8s" : "base"
  k8s_tag       = "k8s-${join("-", slice(split(".", var.spec.kubernetes_version), 0, 2))}"
  template_tags = { for os in distinct([for p in values(local.template_pools) : p.os]) : os => concat(
    ["packer", os, local.template_kind],
    local.template_kind == "k8s" ? [local.k8s_tag] : [],
  ) }

  nodes = merge([for pool, p in local.pools : {
    for i in range(coalesce(p.count, 0)) : "${pool}-${i + 1}" => {
      pool       = pool
      index      = i + 1
      name       = "${var.spec.cluster}-${pool}-${i + 1}"
      pool_spec  = p
      talos      = p.os == "talos"
      private_ip = try(var.addresses[pool][i], null)
    }
  }]...)

  vm_tags = { for key, n in local.nodes : key => sort(distinct(concat(
    ["sogeor", var.spec.cluster, n.pool, n.pool_spec.role, n.pool_spec.os],
    var.tags,
  ))) }
}
