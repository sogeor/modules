terraform {
  required_version = ">= 1.10.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "= 3.4.0"
    }
  }
}

# OS_AUTH_URL, OS_REGION_NAME, OS_PROJECT_ID, OS_USERNAME, OS_PASSWORD, OS_USER_DOMAIN_NAME
provider "openstack" {}

module "spec" {
  source = "../../../../cluster-spec"

  cluster              = yamldecode(file("${path.module}/../../../../../clusters/main.yaml"))
  allow_planned_images = true
}

module "selectel" {
  source = "../.."

  spec             = module.spec.spec
  external_network = "external-network"
  dns_nameservers  = ["198.51.100.53", "198.51.100.54"]
}

module "capi" {
  source = "../../../../capi-cluster"

  spec      = module.spec.spec
  images    = { builds = { ubuntu-2404 = "v20-1" } }
  openstack = merge(module.selectel.capi_openstack, { identity_secret = "capo" })
}

output "manifest" {
  description = "Cluster API manifests for Argo CD."
  value       = module.capi.manifest
}
