output "nodes" {
  description = "Nodes in the normalized node contract, keyed by POOL-INDEX, for example vds-1."
  value       = local.nodes

  precondition {
    condition     = length(local.count_mismatch) == 0
    error_message = "The number of hosts must equal the pool count: ${join(", ", local.count_mismatch)}."
  }

  precondition {
    condition     = length(local.unknown_pools) == 0
    error_message = "hosts lists pools that are not BYO pools of the cluster: ${join(", ", local.unknown_pools)}."
  }

  precondition {
    condition     = length(local.missing_ssh_user) == 0
    error_message = "No SSH user for ${join(", ", local.missing_ssh_user)}: set ssh_user on the host or the module."
  }
}
