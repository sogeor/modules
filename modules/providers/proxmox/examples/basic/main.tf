terraform {
  required_version = ">= 1.10.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "= 0.116.0"
    }
  }
}

# PROXMOX_VE_ENDPOINT, PROXMOX_VE_API_TOKEN
provider "proxmox" {}

module "spec" {
  source = "../../../../cluster-spec"

  cluster = yamldecode(file("${path.module}/cluster.yaml"))
}

module "nodes" {
  source = "../.."

  spec = module.spec.spec

  proxmox = {
    node_name    = "pve"
    datastore_id = "local-lvm"
    bridge       = "vmbr0"
  }

  network = {
    prefix_length = 24
    gateway       = "203.0.113.1"
    dns_servers   = ["203.0.113.1"]
    domain        = "lab.example.com"
  }

  addresses = {
    cp = ["203.0.113.31"]
  }

  talos = var.talos
}

output "nodes" {
  description = "Nodes in the normalized node contract."
  value       = module.nodes.nodes
}

variable "talos" {
  description = "Talos Image Factory schematic, version and ISO SHA-256; see terraform.tfvars.example."
  type = object({
    version      = string
    schematic_id = string
    iso_sha256   = string
  })
}
