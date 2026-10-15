terraform {
  required_version = ">= 1.10.0"
}

variable "cluster" {
  description = "Cluster name, Kubernetes network, topology flags and control-plane endpoint settings."
  type = object({
    name              = string
    pod_cidr          = string
    service_cidr      = string
    workloads_allowed = bool
    vip               = optional(string)
    vip_link          = optional(string)
  })
}

variable "nodes" {
  description = "Talos nodes: role, pool labels and taints per node key."
  type = map(object({
    role   = string
    labels = map(string)
    taints = list(string)
  }))
}

variable "installer_image" {
  description = "Talos installer image."
  type        = string
}

variable "install_disk" {
  description = "Device path of the system disk."
  type        = string
}

variable "disk_encryption" {
  description = "Key for STATE and EPHEMERAL: tpm, nodeid or none."
  type        = string
}

variable "inline_manifests" {
  description = "Manifests applied by Talos at bootstrap, keyed by name."
  type        = map(string)
}

variable "external_cloud_provider" {
  description = "Run the kubelet with an external cloud provider (a cloud controller manager is installed separately)."
  type        = bool
  default     = false
}

locals {
  key = {
    tpm    = { slot = 0, tpm = {} }
    nodeid = { slot = 0, nodeID = {} }
  }

  encrypted_volumes = var.disk_encryption == "none" ? [] : ["STATE", "EPHEMERAL"]

  encryption = [for volume in local.encrypted_volumes : {
    apiVersion = "v1alpha1"
    kind       = "VolumeConfig"
    name       = volume
    encryption = {
      provider = "luks2"
      keys     = [merge(local.key[var.disk_encryption], volume == "EPHEMERAL" ? { lockToState = true } : {})]
    }
  }]

  common = concat([
    {
      apiVersion = "v1alpha1"
      kind       = "UnattendedInstallConfig"
      installer  = { image = var.installer_image }
      provisioning = {
        diskSelector = { match = "disk.dev_path == \"${var.install_disk}\"" }
      }
    },
    { apiVersion = "v1alpha1", kind = "KubeNetworkConfig", podSubnets = [var.cluster.pod_cidr], serviceSubnets = [var.cluster.service_cidr] },
    { apiVersion = "v1alpha1", kind = "KubeSpanConfig", enabled = true },
    ], local.encryption,
    var.external_cloud_provider ? [{ version = "v1alpha1", cluster = { externalCloudProvider = { enabled = true } } }] : [],
  )

  control_plane = concat(
    [
      { apiVersion = "v1alpha1", kind = "KubeProxyConfig", enabled = false },
      { apiVersion = "v1alpha1", kind = "KubeFlannelCNIConfig", "$patch" = "delete" },
    ],
    [for name in sort(keys(var.inline_manifests)) : { apiVersion = "v1alpha1", kind = "KubeInlineManifestConfig", name = name, manifest = var.inline_manifests[name] }],
    var.cluster.vip == null ? [] : [{ apiVersion = "v1alpha1", kind = "Layer2VIPConfig", name = var.cluster.vip, link = var.cluster.vip_link }],
  )

  node = { for key, n in var.nodes : key => {
    apiVersion = "v1alpha1"
    kind       = "KubeNodeConfig"
    labels     = n.labels
    taints = merge(
      { for t in n.taints : split("=", split(":", t)[0])[0] => join(":", compact([try(split("=", split(":", t)[0])[1], ""), split(":", t)[1]])) },
      n.role == "control-plane" && var.cluster.workloads_allowed ? { "node-role.kubernetes.io/control-plane" = { "$patch" = "delete" } } : {},
    )
  } }

  patches = { for key, n in var.nodes : key => concat(
    [for d in local.common : yamlencode(d)],
    n.role == "control-plane" ? [for d in local.control_plane : yamlencode(d)] : [],
    [yamlencode(local.node[key])],
  ) }
}

output "patches" {
  description = "Config patches per node key, one YAML document per element."
  value       = local.patches
}
