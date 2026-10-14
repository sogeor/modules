variable "nodes" {
  description = "Nodes in the normalized node contract from any provider modules, merged into one map. Talos nodes are skipped."
  type = map(object({
    name          = string
    fqdn          = string
    cluster       = string
    distribution  = string
    role          = string
    pool          = string
    provider      = string
    site          = string
    os            = string
    private_ip    = string
    public_ip     = optional(string)
    ssh_user      = optional(string)
    labels        = map(string)
    taints        = list(string)
    mesh_required = bool
  }))

  validation {
    condition     = length(distinct([for n in values(var.nodes) : n.name])) == length(var.nodes)
    error_message = "Node names must be unique."
  }
}

variable "mesh_addresses" {
  description = "Mesh (Tailscale) IPv4 address per node name, once the node has joined the mesh."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for ip in values(var.mesh_addresses) : can(cidrhost("${ip}/32", 0))])
    error_message = "Mesh addresses must be IPv4 addresses."
  }
}

variable "cluster_vars" {
  description = "Variables of the cluster_NAME group per cluster name, for example Kubernetes version and CIDR for the k8s roles."
  type        = map(any)
  default     = {}
}
