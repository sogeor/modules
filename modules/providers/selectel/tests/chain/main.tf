terraform {
  required_version = ">= 1.10.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "= 3.4.0"
    }
  }
}

variable "cluster" {
  description = "Cluster description passed to cluster-spec."
  type        = any
}

module "spec" {
  source = "../../../../cluster-spec"

  cluster              = var.cluster
  allow_planned_images = true
}

module "selectel" {
  source = "../.."

  spec             = module.spec.spec
  external_network = "external-network"
  dns_nameservers  = ["198.51.100.53"]
  volume_type      = "fast.zone-a"
  existing_flavors = { l = "SL1.4-8192" }
  ssh_public_key   = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKeyOnlyForTests ops@example.com"
}

module "capi" {
  source = "../../../../capi-cluster"

  spec      = module.spec.spec
  images    = { builds = { ubuntu-2404 = "v20-1" } }
  openstack = merge(module.selectel.capi_openstack, { identity_secret = "capo" })
}

output "flavors" {
  description = "Flavors from providers/selectel."
  value       = module.selectel.flavors
}

output "objects" {
  description = "Rendered Cluster API objects."
  value       = module.capi.objects
}
