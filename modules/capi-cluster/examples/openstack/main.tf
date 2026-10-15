terraform {
  required_version = ">= 1.10.0"
}

variable "talos" {
  description = "Talos version and Image Factory schematic ID."
  type = object({
    version      = string
    schematic_id = string
  })
}

variable "openstack" {
  description = "OpenStack settings for CAPO."
  type = object({
    identity_secret  = string
    external_network = string
    dns_nameservers  = list(string)
    flavors          = map(string)
    volume_type      = optional(string)
  })
}

module "spec" {
  source = "../../../cluster-spec"

  cluster = yamldecode(file("${path.module}/cluster.yaml"))
}

module "capi" {
  source = "../.."

  spec      = module.spec.spec
  images    = { talos = var.talos }
  openstack = var.openstack
}

output "manifest" {
  description = "CAPI manifests to commit to the GitOps repository."
  value       = module.capi.manifest
}
