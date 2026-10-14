output "spec" {
  description = "Normalized cluster: derived mechanism, network CIDR, control plane summary, cluster labels and pools with resolved sizes."
  value       = local.spec

  precondition {
    condition     = !var.enforce || length(local.violations) == 0
    error_message = "The cluster description is invalid:\n${join("\n", [for v in local.violations : "- [${v.rule}] ${v.message}"])}"
  }
}

output "violations" {
  description = "List of { rule, message } for every broken rule; empty for a valid description."
  value       = local.violations
}

output "warnings" {
  description = "List of { rule, message } that do not block, such as planned images accepted with allow_planned_images."
  value       = local.warnings
}

output "matrix" {
  description = "Compatibility matrix used for validation: distributions, providers, image status per (OS, provider), sizes, profiles."
  value       = local.matrix
}
