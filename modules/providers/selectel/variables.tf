variable "spec" {
  description = "Normalized cluster from the cluster-spec module (module.NAME.spec). Only pools with provider selectel are used."
  type = object({
    cluster      = string
    distribution = string
    pools = map(object({
      provider  = string
      size      = string
      cpu       = number
      memory_mb = number
    }))
  })

  validation {
    condition     = anytrue([for p in values(var.spec.pools) : p.provider == "selectel"])
    error_message = "The cluster has no pools with provider selectel."
  }
}

variable "external_network" {
  description = "Name of the external (internet) network of the region; checked at plan time."
  type        = string

  validation {
    condition     = length(trimspace(var.external_network)) > 0
    error_message = "The external_network must not be empty."
  }
}

variable "dns_nameservers" {
  description = "IPv4 DNS resolvers for the node subnet created by CAPO."
  type        = list(string)

  validation {
    condition     = length(var.dns_nameservers) > 0 && alltrue([for s in var.dns_nameservers : can(cidrhost("${s}/32", 0))])
    error_message = "At least one DNS server is required, and every one must be an IPv4 address."
  }
}

variable "volume_type" {
  description = "Volume type of the root volumes, for example a fast SSD type of the pool zone. null keeps the project default."
  type        = string
  default     = null
}

variable "existing_flavors" {
  description = "Existing flavor name per size, used instead of creating a private flavor (for example a fixed Selectel configuration)."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for k in keys(var.existing_flavors) : contains(["xs", "s", "m", "l", "xl", "2xl"], k)])
    error_message = "Keys of existing_flavors must be sizes: xs, s, m, l, xl, 2xl."
  }
}

variable "flavor_prefix" {
  description = "Prefix of created flavor names: PREFIX-CLUSTER-SIZE."
  type        = string
  default     = "sogeor"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,30}$", var.flavor_prefix))
    error_message = "The flavor_prefix must be a short lowercase name."
  }
}

variable "ssh_public_key" {
  description = "OpenSSH public key for the break-glass key pair of kubeadm nodes. Not allowed for Talos clusters."
  type        = string
  default     = null

  validation {
    condition     = var.ssh_public_key == null || can(regex("^(ssh-ed25519|ecdsa-sha2-nistp(256|384|521)|ssh-rsa) [A-Za-z0-9+/=]+( .*)?$", coalesce(var.ssh_public_key, "x")))
    error_message = "The ssh_public_key must be an OpenSSH public key."
  }
}
