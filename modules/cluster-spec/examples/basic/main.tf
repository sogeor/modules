terraform {
  required_version = ">= 1.10.0"
}

module "spec" {
  source = "../.."

  cluster = yamldecode(file("${path.module}/cluster.yaml"))
}

output "spec" {
  description = "Normalized cluster."
  value       = module.spec.spec
}

output "warnings" {
  description = "Non-blocking findings."
  value       = module.spec.warnings
}
