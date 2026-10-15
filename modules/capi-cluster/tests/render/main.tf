terraform {
  required_version = ">= 1.10.0"
}

locals {
  talos = {
    version      = "v1.14.2"
    schematic_id = "7d4c31cbd96db9f90c874990697c523482b2bae27fb4631d5583dcd9c281b1ff"
  }

  proxmox = {
    source_node            = "pve"
    storage                = "local-lvm"
    bridge                 = "vmbr0"
    addresses              = ["203.0.113.40-203.0.113.49"]
    prefix                 = 24
    gateway                = "203.0.113.1"
    dns_servers            = ["203.0.113.1"]
    control_plane_endpoint = "203.0.113.39"
    vip_interface          = "ens18"
  }

  openstack = {
    identity_secret  = "openstack-credentials"
    external_network = "external-network"
    dns_nameservers  = ["198.51.100.53"]
    flavors          = { m = "SL1.2-4096", l = "SL1.4-8192" }
    volume_type      = "fast.ru-9a"
  }

  pools = {
    single = {
      cp = { role = "control-plane", site = "home", size = "m", count = 1 }
    }
    ha = {
      cp      = { role = "control-plane", site = "home", size = "m", count = 3 }
      workers = { role = "worker", site = "home", size = "l", autoscale = { min = 0, max = 3 }, labels = { "sogeor.com/tier" = "app" }, taints = ["dedicated=app:NoSchedule"] }
      db      = { role = "worker", site = "home", size = "l", count = 2 }
    }
  }

  scenarios = {
    talos-proxmox-single    = { distribution = "talos", os = "talos", provider = "proxmox", site = "home", topology = "single" }
    kubeadm-proxmox-ha      = { distribution = "kubeadm", os = "ubuntu-2404", provider = "proxmox", site = "home", topology = "ha" }
    talos-selectel-ha       = { distribution = "talos", os = "talos", provider = "selectel", site = "selectel-ru-9", topology = "ha" }
    kubeadm-selectel-single = { distribution = "kubeadm", os = "ubuntu-2404", provider = "selectel", site = "selectel-ru-9", topology = "single" }
  }
}

module "spec" {
  source   = "../../../cluster-spec"
  for_each = local.scenarios

  cluster = {
    cluster            = "lab-${each.value.topology}"
    cluster_id         = 9
    distribution       = each.value.distribution
    kubernetes_version = "1.37.1"
    topology           = each.value.topology
    mechanism          = "capi"
    pools = { for name, p in local.pools[each.value.topology] : name => merge(p, {
      os       = each.value.os
      provider = each.value.provider
      site     = each.value.site
    }) }
  }
  allow_planned_images = true
}

module "capi" {
  source   = "../.."
  for_each = local.scenarios

  spec = module.spec[each.key].spec
  images = {
    talos  = local.talos
    builds = { ubuntu-2404 = "v20-1", talos = "v20-1" }
  }
  proxmox   = each.value.provider == "proxmox" ? local.proxmox : null
  openstack = each.value.provider == "proxmox" ? null : local.openstack
}

locals {
  manifests = { for k, m in module.capi : k => m.manifest }
}

output "manifests" {
  description = "Rendered manifest per scenario."
  value       = local.manifests
}
