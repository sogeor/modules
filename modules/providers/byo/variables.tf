variable "spec" {
  description = "Normalized cluster from the cluster-spec module (module.NAME.spec)."
  type = object({
    cluster      = string
    distribution = string
    pools = map(object({
      role          = string
      os            = string
      provider      = string
      site          = string
      count         = optional(number)
      labels        = map(string)
      taints        = list(string)
      mesh_required = bool
    }))
  })
}

variable "hosts" {
  description = "Existing servers per BYO pool, in node order. private_ip defaults to public_ip; zone defaults to the site."
  type = map(list(object({
    public_ip  = optional(string)
    private_ip = optional(string)
    ssh_user   = optional(string)
    zone       = optional(string)
  })))

  validation {
    condition = alltrue(flatten([for hs in values(var.hosts) : [for h in hs :
      (h.public_ip != null || h.private_ip != null)
      && (h.public_ip == null || can(cidrhost("${coalesce(h.public_ip, "0.0.0.0")}/32", 0)))
      && (h.private_ip == null || can(cidrhost("${coalesce(h.private_ip, "0.0.0.0")}/32", 0)))
    ]]))
    error_message = "Every host needs a public_ip or a private_ip, and both must be IPv4 addresses."
  }
}

variable "ssh_user" {
  description = "Default SSH user for the first connection, used when a host sets no ssh_user. Not used for Talos pools."
  type        = string
  default     = null

  validation {
    condition     = var.ssh_user == null || can(regex("^[a-z_][a-z0-9_-]{0,31}$", coalesce(var.ssh_user, "x")))
    error_message = "The ssh_user must be a valid Linux user name."
  }
}

variable "domain" {
  description = "Domain for node FQDNs."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.domain))
    error_message = "The domain must be a lowercase DNS name such as lab.example.com."
  }
}
