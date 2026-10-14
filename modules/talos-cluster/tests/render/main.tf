terraform {
  required_version = ">= 1.10.0"
}

locals {
  manifest  = "apiVersion: v1\nkind: Namespace\nmetadata:\n  name: render-check\n"
  installer = "factory.talos.dev/nocloud-installer/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:v1.14.2"
}

module "single" {
  source = "../../config"

  cluster = {
    name              = "mgmt"
    pod_cidr          = "10.10.0.0/16"
    service_cidr      = "10.11.0.0/16"
    workloads_allowed = true
  }

  nodes = {
    cp-1 = { role = "control-plane", labels = { "sogeor.com/pool" = "cp" }, taints = [] }
  }

  installer_image  = local.installer
  install_disk     = "/dev/sda"
  disk_encryption  = "tpm"
  inline_manifests = { cilium = local.manifest }
}

module "ha" {
  source = "../../config"

  cluster = {
    name              = "lab"
    pod_cidr          = "10.90.0.0/16"
    service_cidr      = "10.91.0.0/16"
    workloads_allowed = false
    vip               = "203.0.113.30"
    vip_link          = "eth0"
  }

  nodes = {
    cp-1      = { role = "control-plane", labels = { "sogeor.com/pool" = "cp" }, taints = [] }
    workers-1 = { role = "worker", labels = { "sogeor.com/pool" = "workers" }, taints = ["dedicated=db:NoSchedule", "spot:PreferNoSchedule"] }
  }

  installer_image  = local.installer
  install_disk     = "/dev/sda"
  disk_encryption  = "nodeid"
  inline_manifests = { cilium = local.manifest }
}

locals {
  checks = {
    single-cp-1  = { role = "controlplane", patches = module.single.patches["cp-1"] }
    ha-cp-1      = { role = "controlplane", patches = module.ha.patches["cp-1"] }
    ha-workers-1 = { role = "worker", patches = module.ha.patches["workers-1"] }
  }
}

output "checks" {
  description = "Patches per scenario and node, with the machine type to validate against."
  value       = local.checks
}
