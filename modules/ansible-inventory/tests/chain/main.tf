terraform {
  required_version = ">= 1.10.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "= 0.116.0"
    }
    ansible = {
      source  = "ansible/ansible"
      version = "= 1.5.0"
    }
  }
}

module "spec" {
  source = "../../../cluster-spec"

  cluster = yamldecode(file("${path.module}/../../examples/mixed/cluster.yaml"))
}

module "home" {
  source = "../../../providers/proxmox"

  spec      = module.spec.spec
  proxmox   = { node_name = "pve-test", datastore_id = "local-lvm", bridge = "vmbr0" }
  network   = { prefix_length = 24, gateway = "203.0.113.1", dns_servers = ["203.0.113.1"], domain = "lab.example.com" }
  addresses = { cp = ["203.0.113.40"] }
  ssh       = { user = "ops", public_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleExampleExampleExampleExampleExample test"] }
}

module "vds" {
  source = "../../../providers/byo"

  spec     = module.spec.spec
  hosts    = { vds = [{ public_ip = "198.51.100.10" }] }
  ssh_user = "ops"
  domain   = "lab.example.com"
}

output "nodes" {
  description = "Nodes of both providers merged."
  value       = merge(module.home.nodes, module.vds.nodes)
}

module "inventory" {
  source = "../.."

  nodes = merge(module.home.nodes, module.vds.nodes)
}

output "hosts" {
  description = "Inventory hosts built from both providers."
  value       = module.inventory.hosts
}
