terraform {
  required_version = ">= 1.11.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "= 0.116.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "= 0.12.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "= 3.3.0"
    }
  }
}

# PROXMOX_VE_ENDPOINT, PROXMOX_VE_API_TOKEN
provider "proxmox" {}

provider "talos" {}

provider "helm" {}

module "spec" {
  source = "../../../cluster-spec"

  cluster = yamldecode(file("${path.module}/cluster.yaml"))
}

module "nodes" {
  source = "../../../providers/proxmox"

  spec      = module.spec.spec
  proxmox   = var.proxmox
  network   = var.network
  addresses = var.addresses

  talos = {
    version      = var.talos.version
    schematic_id = var.talos.schematic_id
    iso_sha256   = var.talos.iso_sha256
  }
}

module "cluster" {
  source = "../.."

  spec  = module.spec.spec
  nodes = module.nodes.nodes

  talos = {
    version         = var.talos.version
    schematic_id    = var.talos.schematic_id
    config_contract = var.talos.config_contract
  }
}

variable "proxmox" {
  description = "Proxmox placement; see terraform.tfvars.example."
  type = object({
    node_name    = string
    datastore_id = string
    bridge       = string
  })
}

variable "network" {
  description = "Node network; see terraform.tfvars.example."
  type = object({
    prefix_length = number
    gateway       = string
    dns_servers   = list(string)
    domain        = string
  })
}

variable "addresses" {
  description = "Addresses per pool; see terraform.tfvars.example."
  type        = map(list(string))
}

variable "talos" {
  description = "Talos version, schematic, ISO checksum and config contract; see terraform.tfvars.example."
  type = object({
    version         = string
    schematic_id    = string
    iso_sha256      = string
    config_contract = string
  })
}

output "endpoint" {
  description = "Kubernetes API endpoint."
  value       = module.cluster.endpoint
}

output "talosconfig" {
  description = "talosctl configuration."
  value       = module.cluster.talosconfig
  sensitive   = true
}

output "kubeconfig" {
  description = "Admin kubeconfig."
  value       = module.cluster.kubeconfig
  sensitive   = true
}
