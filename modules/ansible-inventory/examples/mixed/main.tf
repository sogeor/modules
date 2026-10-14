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

# PROXMOX_VE_ENDPOINT, PROXMOX_VE_API_TOKEN
provider "proxmox" {}

provider "ansible" {}

module "spec" {
  source = "../../../cluster-spec"

  cluster = yamldecode(file("${path.module}/cluster.yaml"))
}

module "home" {
  source = "../../../providers/proxmox"

  spec      = module.spec.spec
  proxmox   = var.proxmox
  network   = var.network
  addresses = var.addresses
  ssh       = var.ssh
}

module "vds" {
  source = "../../../providers/byo"

  spec     = module.spec.spec
  hosts    = var.hosts
  ssh_user = var.ssh.user
  domain   = var.network.domain
}

module "inventory" {
  source = "../.."

  nodes          = merge(module.home.nodes, module.vds.nodes)
  mesh_addresses = var.mesh_addresses

  cluster_vars = {
    (module.spec.spec.cluster) = {
      kubernetes_version = module.spec.spec.kubernetes_version
      pod_cidr           = module.spec.spec.network.pod_cidr
      service_cidr       = module.spec.spec.network.service_cidr
    }
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
  description = "Home network; see terraform.tfvars.example."
  type = object({
    prefix_length = number
    gateway       = string
    dns_servers   = list(string)
    domain        = string
  })
}

variable "addresses" {
  description = "Home addresses per pool; see terraform.tfvars.example."
  type        = map(list(string))
}

variable "ssh" {
  description = "SSH user and keys; see terraform.tfvars.example."
  type = object({
    user        = string
    public_keys = list(string)
  })
}

variable "hosts" {
  description = "BYO servers per pool; see terraform.tfvars.example."
  type = map(list(object({
    public_ip  = optional(string)
    private_ip = optional(string)
    ssh_user   = optional(string)
    zone       = optional(string)
  })))
}

variable "mesh_addresses" {
  description = "Mesh addresses per node name once nodes joined the mesh."
  type        = map(string)
  default     = {}
}

output "hosts" {
  description = "Inventory hosts."
  value       = module.inventory.hosts
}

output "bootstrap_hosts" {
  description = "Hosts still reached by public address."
  value       = module.inventory.bootstrap_hosts
}
