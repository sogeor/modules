terraform {
  required_version = ">= 1.10.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "= 0.116.0"
    }
  }
}

variable "cluster" {
  description = "Cluster description passed to cluster-spec."
  type        = any
}

module "spec" {
  source = "../../../../cluster-spec"

  cluster = var.cluster
}

output "spec" {
  description = "Normalized cluster."
  value       = module.spec.spec
}
