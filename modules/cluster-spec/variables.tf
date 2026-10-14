variable "cluster" {
  description = "Cluster description, usually yamldecode(file(\"clusters/NAME.yaml\")). Fields: docs/configuration.md."
  type = object({
    cluster            = string
    cluster_id         = number
    distribution       = string
    kubernetes_version = string
    topology           = string
    profiles           = optional(list(string), ["core"])
    mechanism          = optional(string)
    control_plane_multisite = optional(object({
      enabled = bool
      reason  = optional(string, "")
    }))
    pools = map(object({
      role     = string
      os       = string
      provider = string
      site     = string
      size     = string
      count    = optional(number)
      autoscale = optional(object({
        min = number
        max = number
      }))
      labels                 = optional(map(string), {})
      taints                 = optional(list(string), [])
      custom_image_supported = optional(bool, false)
    }))
  })

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,30}[a-z0-9]$", var.cluster.cluster))
    error_message = "The cluster name must be 2-32 lowercase letters, digits or hyphens, start with a letter and not end with a hyphen."
  }

  validation {
    condition     = var.cluster.cluster_id >= 1 && var.cluster.cluster_id <= 24 && floor(var.cluster.cluster_id) == var.cluster.cluster_id
    error_message = "The cluster_id must be an integer from 1 to 24."
  }

  validation {
    condition     = contains(["talos", "kubeadm", "k3s"], var.cluster.distribution)
    error_message = "The distribution must be one of: talos, kubeadm, k3s."
  }

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.cluster.kubernetes_version))
    error_message = "The kubernetes_version must be a full version such as \"1.37.1\"."
  }

  validation {
    condition     = contains(["single", "ha"], var.cluster.topology)
    error_message = "The topology must be single or ha."
  }

  validation {
    condition     = var.cluster.mechanism == null || contains(["capi", "opentofu"], coalesce(var.cluster.mechanism, "capi"))
    error_message = "The mechanism must be capi or opentofu."
  }

  validation {
    condition     = length(var.cluster.pools) > 0
    error_message = "At least one pool is required."
  }

  validation {
    condition     = alltrue([for name in keys(var.cluster.pools) : can(regex("^[a-z][a-z0-9-]{0,30}[a-z0-9]$", name))])
    error_message = "Pool names must be 2-32 lowercase letters, digits or hyphens, start with a letter and not end with a hyphen."
  }

  validation {
    condition     = alltrue([for p in values(var.cluster.pools) : contains(["control-plane", "worker"], p.role)])
    error_message = "The pool role must be control-plane or worker."
  }

  validation {
    condition     = alltrue([for p in values(var.cluster.pools) : can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", p.site))])
    error_message = "The site must be lowercase letters, digits and hyphens, for example home or selectel-ru-9."
  }

  validation {
    condition     = alltrue([for p in values(var.cluster.pools) : try(p.count >= 0 && floor(p.count) == p.count, p.count == null)])
    error_message = "The pool count must be a non-negative integer."
  }
}

variable "allow_planned_images" {
  description = "Accept (OS, provider) pairs whose image is only planned; they are reported in the warnings output instead of violations."
  type        = bool
  default     = false
}

variable "enforce" {
  description = "Fail the plan when the description has violations. Set to false only to inspect the violations output."
  type        = bool
  default     = true
}
