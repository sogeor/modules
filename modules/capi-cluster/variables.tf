variable "spec" {
  description = "Normalized cluster from the cluster-spec module (module.NAME.spec)."
  type = object({
    cluster            = string
    distribution       = string
    kubernetes_version = string
    topology           = string
    mechanism          = string
    labels             = map(string)
    network = object({
      pod_cidr     = string
      service_cidr = string
    })
    control_plane = object({
      count             = number
      workloads_allowed = bool
    })
    pools = map(object({
      role      = string
      os        = string
      provider  = string
      size      = string
      cpu       = number
      memory_mb = number
      disk_gb   = number
      count     = optional(number)
      autoscale = optional(object({
        min = number
        max = number
      }))
      labels = map(string)
      taints = list(string)
    }))
  })

  validation {
    condition     = var.spec.mechanism == "capi"
    error_message = "The capi-cluster module needs a cluster with mechanism capi."
  }

  validation {
    condition     = contains(["talos", "kubeadm"], var.spec.distribution)
    error_message = "The distribution must be talos or kubeadm; k3s is not supported through CAPI."
  }

  validation {
    condition     = length(distinct([for p in values(var.spec.pools) : p.provider])) == 1
    error_message = "All pools of a CAPI cluster must use one provider."
  }

  validation {
    condition     = alltrue([for p in values(var.spec.pools) : contains(["proxmox", "selectel", "vkcloud"], p.provider)])
    error_message = "The provider must be proxmox (CAPMOX) or an OpenStack cloud: selectel, vkcloud (CAPO)."
  }

  validation {
    condition     = length([for p in values(var.spec.pools) : p if p.role == "control-plane"]) == 1
    error_message = "A CAPI cluster needs exactly one control-plane pool."
  }

  validation {
    condition     = alltrue([for p in values(var.spec.pools) : p.role == "worker" || p.count != null])
    error_message = "The control-plane pool needs count."
  }
}

variable "namespace" {
  description = "Namespace of the CAPI objects in the management cluster; null uses the cluster name."
  type        = string
  default     = null
}

variable "images" {
  description = "Images: Talos version and Image Factory schematic, and the image build per OS (for example v20-1). Proxmox needs a build for every OS, OpenStack for every OS except talos."
  type = object({
    talos = optional(object({
      version      = string
      schematic_id = string
    }))
    builds = optional(map(string), {})
  })

  validation {
    condition     = var.images.talos == null || can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", var.images.talos.version)) && can(regex("^[0-9a-f]{64}$", var.images.talos.schematic_id))
    error_message = "The Talos version must look like v1.14.2 and the schematic ID must be 64 hex characters."
  }

  validation {
    condition     = alltrue([for b in values(var.images.builds) : can(regex("^v[0-9]+(-[0-9]+)?$", b))])
    error_message = "Image builds must look like v20-1."
  }
}

variable "proxmox" {
  description = "Proxmox VE settings for CAPMOX: template node, target storage, bridge, node address range, gateway, DNS and the control-plane VIP."
  type = object({
    source_node            = string
    allowed_nodes          = optional(list(string), [])
    storage                = optional(string)
    bridge                 = string
    vlan                   = optional(number)
    addresses              = list(string)
    prefix                 = number
    gateway                = string
    dns_servers            = list(string)
    control_plane_endpoint = string
    vip_interface          = optional(string)
    credentials_secret     = optional(string)
  })
  default = null

  validation {
    condition     = var.proxmox == null || can(cidrhost("${var.proxmox.control_plane_endpoint}/32", 0))
    error_message = "The control_plane_endpoint must be an IPv4 address (the VIP of the API server)."
  }

  validation {
    condition     = var.proxmox == null || length(try(var.proxmox.addresses, [])) > 0 && length(try(var.proxmox.dns_servers, [])) > 0
    error_message = "Proxmox needs at least one node address range and one DNS server."
  }
}

variable "openstack" {
  description = "OpenStack settings for CAPO: credentials Secret, external network, node subnet, flavor per size, API endpoint exposure."
  type = object({
    identity_secret   = string
    cloud_name        = optional(string, "openstack")
    external_network  = string
    node_cidr         = optional(string, "10.100.0.0/24")
    dns_nameservers   = list(string)
    flavors           = map(string)
    volume_type       = optional(string)
    api_floating_ip   = optional(bool, true)
    api_allowed_cidrs = optional(list(string), [])
    load_balancer     = optional(bool)
    ssh_key_name      = optional(string)
  })
  default = null

  validation {
    condition     = var.openstack == null || can(cidrhost(var.openstack.node_cidr, 0))
    error_message = "The node_cidr must be an IPv4 CIDR."
  }
}

variable "talos_disk_encryption" {
  description = "Key for the Talos STATE and EPHEMERAL volumes: nodeid or none (the CAPI images have no TPM)."
  type        = string
  default     = "nodeid"

  validation {
    condition     = contains(["nodeid", "none"], var.talos_disk_encryption)
    error_message = "The talos_disk_encryption must be nodeid or none."
  }
}
