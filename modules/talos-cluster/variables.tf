variable "spec" {
  description = "Normalized cluster from the cluster-spec module (module.NAME.spec)."
  type = object({
    cluster            = string
    cluster_id         = number
    distribution       = string
    kubernetes_version = string
    topology           = string
    network = object({
      pod_cidr     = string
      service_cidr = string
    })
    control_plane = object({
      workloads_allowed = bool
    })
  })

  validation {
    condition     = var.spec.distribution == "talos"
    error_message = "The talos-cluster module needs a cluster with distribution talos."
  }
}

variable "nodes" {
  description = "Nodes in the normalized node contract, for example module.NAME.nodes of a provider module."
  type = map(object({
    name         = string
    distribution = string
    role         = string
    pool         = string
    private_ip   = string
    labels       = map(string)
    taints       = list(string)
  }))

  validation {
    condition     = alltrue([for n in values(var.nodes) : n.distribution == "talos"])
    error_message = "Every node must have distribution talos."
  }

  validation {
    condition     = length([for n in values(var.nodes) : n if n.role == "control-plane"]) > 0
    error_message = "At least one control-plane node is required."
  }

  validation {
    condition     = alltrue([for n in values(var.nodes) : can(cidrhost("${n.private_ip}/32", 0))])
    error_message = "Every node needs an IPv4 private_ip."
  }
}

variable "talos" {
  description = "Talos version to install, Image Factory schematic and the config contract fixed at cluster creation (for example v1.14)."
  type = object({
    version         = string
    schematic_id    = string
    config_contract = string
  })

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", var.talos.version))
    error_message = "The talos version must look like v1.14.2."
  }

  validation {
    condition     = can(regex("^[0-9a-f]{64}$", var.talos.schematic_id))
    error_message = "The schematic_id must be 64 lowercase hex characters."
  }

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+$", var.talos.config_contract))
    error_message = "The config_contract must look like v1.14."
  }
}

variable "vip" {
  description = "Shared IPv4 address of the Kubernetes API and the link it is announced on; required for topology ha."
  type = object({
    address = string
    link    = string
  })
  default = null

  validation {
    condition     = var.vip == null || try(can(cidrhost("${var.vip.address}/32", 0)) && trimspace(var.vip.link) != "", false)
    error_message = "The vip needs an IPv4 address and a link name."
  }
}

variable "install_disk" {
  description = "Device path of the system disk."
  type        = string
  default     = "/dev/sda"

  validation {
    condition     = can(regex("^/dev/[a-z0-9]+$", var.install_disk))
    error_message = "The install_disk must be a device path such as /dev/sda."
  }
}

variable "disk_encryption" {
  description = "Key for the STATE and EPHEMERAL volumes: tpm (needs a TPM 2.0), nodeid or none."
  type        = string
  default     = "tpm"

  validation {
    condition     = contains(["tpm", "nodeid", "none"], var.disk_encryption)
    error_message = "The disk_encryption must be tpm, nodeid or none."
  }
}

variable "cilium" {
  description = "Cilium Helm chart installed at bootstrap: version, repository and extra values merged over the defaults."
  type = object({
    version    = optional(string, "1.20.2")
    repository = optional(string, "https://helm.cilium.io")
    values     = optional(any, {})
  })
  default = {}

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.cilium.version))
    error_message = "The cilium version must be an exact chart version such as 1.20.2."
  }
}

variable "image_factory_host" {
  description = "Image Factory host that serves the installer image."
  type        = string
  default     = "factory.talos.dev"

  validation {
    condition     = can(regex("^[a-z0-9.-]+(:[0-9]+)?$", var.image_factory_host))
    error_message = "The image_factory_host must be a host name without scheme."
  }
}
