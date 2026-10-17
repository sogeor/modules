locals {
  pools = { for k, p in var.spec.pools : k => p if p.provider == "selectel" }
  sizes = { for p in values(local.pools) : p.size => { cpu = p.cpu, memory_mb = p.memory_mb }... }

  created = { for size, s in local.sizes : size => s[0] if !contains(keys(var.existing_flavors), size) }

  flavors = merge(
    { for size, f in openstack_compute_flavor_v2.size : size => f.name },
    { for size, name in var.existing_flavors : size => name if contains(keys(local.sizes), size) },
  )

  ssh_key_name = try(openstack_compute_keypair_v2.admin[0].name, null)
}

data "openstack_networking_network_v2" "external" {
  name     = var.external_network
  external = true
}

resource "openstack_compute_flavor_v2" "size" {
  for_each = local.created

  name        = "${var.flavor_prefix}-${var.spec.cluster}-${each.key}"
  description = "Size ${each.key} of cluster ${var.spec.cluster}; root disk is a volume."
  vcpus       = each.value.cpu
  ram         = each.value.memory_mb
  disk        = 0
  is_public   = false
}

resource "openstack_compute_keypair_v2" "admin" {
  count = var.ssh_public_key == null ? 0 : 1

  name       = "${var.spec.cluster}-admin"
  public_key = var.ssh_public_key

  lifecycle {
    precondition {
      condition     = var.spec.distribution != "talos"
      error_message = "Talos nodes have no SSH; do not set ssh_public_key for a Talos cluster."
    }
  }
}
