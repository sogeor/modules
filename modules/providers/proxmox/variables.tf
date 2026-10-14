variable "spec" {
  description = "Normalized cluster from the cluster-spec module (module.NAME.spec)."
  type = object({
    cluster            = string
    distribution       = string
    kubernetes_version = string
    mechanism          = string
    pools = map(object({
      role          = string
      os            = string
      provider      = string
      site          = string
      size          = string
      cpu           = number
      memory_mb     = number
      disk_gb       = number
      count         = optional(number)
      labels        = map(string)
      taints        = list(string)
      mesh_required = bool
    }))
  })
}

variable "proxmox" {
  description = "Proxmox VE placement: node, datastores and bridge."
  type = object({
    node_name               = string
    datastore_id            = string
    iso_datastore_id        = optional(string)
    cloud_init_datastore_id = optional(string)
    bridge                  = string
    vlan_id                 = optional(number)
    cpu_type                = optional(string, "host")
  })

  validation {
    condition     = alltrue([for v in [var.proxmox.node_name, var.proxmox.datastore_id, var.proxmox.bridge] : trimspace(v) != ""])
    error_message = "The node_name, datastore_id and bridge must not be empty."
  }

  validation {
    condition     = var.proxmox.vlan_id == null || try(var.proxmox.vlan_id >= 1 && var.proxmox.vlan_id <= 4094, false)
    error_message = "The vlan_id must be from 1 to 4094."
  }
}

variable "network" {
  description = "IPv4 settings shared by all nodes: prefix length, gateway, DNS servers and the domain for FQDNs and DNS search."
  type = object({
    prefix_length = number
    gateway       = string
    dns_servers   = list(string)
    domain        = string
  })

  validation {
    condition     = var.network.prefix_length >= 8 && var.network.prefix_length <= 30
    error_message = "The prefix_length must be from 8 to 30."
  }

  validation {
    condition     = can(cidrhost("${var.network.gateway}/32", 0))
    error_message = "The gateway must be an IPv4 address."
  }

  validation {
    condition     = length(var.network.dns_servers) > 0 && alltrue([for s in var.network.dns_servers : can(cidrhost("${s}/32", 0))])
    error_message = "The dns_servers must be a non-empty list of IPv4 addresses."
  }

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.network.domain))
    error_message = "The domain must be a lowercase DNS name such as lab.example.com."
  }
}

variable "addresses" {
  description = "IPv4 addresses per pool, without prefix; node N of a pool gets element N-1."
  type        = map(list(string))

  validation {
    condition     = alltrue(flatten([for ips in values(var.addresses) : [for ip in ips : can(cidrhost("${ip}/32", 0))]]))
    error_message = "Every address must be an IPv4 address without prefix."
  }

  validation {
    condition     = length(flatten(values(var.addresses))) == length(distinct(flatten(values(var.addresses))))
    error_message = "Addresses must be unique across pools."
  }
}

variable "ssh" {
  description = "Cloud-init user and public keys for pools other than Talos. Required when such pools exist."
  type = object({
    user        = string
    public_keys = list(string)
  })
  default = null

  validation {
    condition     = var.ssh == null || try(can(regex("^[a-z_][a-z0-9_-]{0,31}$", var.ssh.user)) && length(var.ssh.public_keys) > 0, false)
    error_message = "The ssh user must be a valid Linux user name and public_keys must not be empty."
  }
}

variable "talos" {
  description = "Talos Image Factory schematic, version and SHA-256 of the nocloud ISO. Required when Talos pools exist."
  type = object({
    version      = string
    schematic_id = string
    iso_sha256   = string
  })
  default = null

  validation {
    condition     = var.talos == null || try(can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", var.talos.version)), false)
    error_message = "The talos version must look like v1.14.2."
  }

  validation {
    condition     = var.talos == null || try(can(regex("^[0-9a-f]{64}$", var.talos.schematic_id)) && can(regex("^[0-9a-f]{64}$", var.talos.iso_sha256)), false)
    error_message = "The schematic_id and iso_sha256 must be 64 lowercase hex characters."
  }
}

variable "image_factory_url" {
  description = "Base URL of the Talos Image Factory."
  type        = string
  default     = "https://factory.talos.dev"

  validation {
    condition     = can(regex("^https://[^/]+$", var.image_factory_url))
    error_message = "The image_factory_url must be an https:// URL without a trailing slash."
  }
}

variable "tags" {
  description = "Extra Proxmox tags added to every VM."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for t in var.tags : can(regex("^[a-z0-9][a-z0-9_.-]*$", t))])
    error_message = "Tags must be lowercase letters, digits, dots, hyphens or underscores."
  }
}
