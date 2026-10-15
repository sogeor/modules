output "objects" {
  description = "CAPI objects in apply order: Cluster, infrastructure cluster, control plane, machine templates, bootstrap templates, MachineDeployments, MachineHealthChecks."
  value       = local.objects

  precondition {
    condition     = local.infra != "proxmox" || var.proxmox != null
    error_message = "Pools on proxmox need the proxmox input."
  }

  precondition {
    condition     = local.infra != "openstack" || var.openstack != null
    error_message = "Pools on OpenStack clouds need the openstack input."
  }

  precondition {
    condition     = !local.talos || var.images.talos != null
    error_message = "Talos clusters need images.talos (version and schematic_id)."
  }

  precondition {
    condition     = alltrue([for p in values(local.c.pools) : contains(keys(var.images.builds), p.os) if local.infra == "proxmox" || p.os != "talos"])
    error_message = "images.builds needs a build for every pool OS (except talos on OpenStack, which is selected by version and schematic)."
  }

  precondition {
    condition     = local.infra != "openstack" || alltrue([for p in values(local.c.pools) : contains(keys(try(var.openstack.flavors, {})), p.size)])
    error_message = "openstack.flavors needs a flavor for every pool size."
  }

  precondition {
    condition     = !(local.talos && local.infra == "proxmox") || try(var.proxmox.vip_interface != null, false)
    error_message = "Talos on proxmox needs proxmox.vip_interface for the control-plane VIP."
  }
}

output "manifest" {
  description = "All objects as one multi-document YAML, ready to commit for Argo CD."
  value       = join("", [for o in local.objects : "---\n${yamlencode(o)}"])
}

output "infrastructure" {
  description = "CAPI infrastructure provider used: proxmox (CAPMOX) or openstack (CAPO)."
  value       = local.infra
}
