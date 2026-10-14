locals {
  ha = var.spec.topology == "ha"

  cp_keys = sort([for key, n in var.nodes : key if n.role == "control-plane"])
  cp_ips  = [for key in local.cp_keys : var.nodes[key].private_ip]

  endpoint_ip      = local.ha ? try(var.vip.address, null) : local.cp_ips[0]
  cluster_endpoint = "https://${coalesce(local.endpoint_ip, local.cp_ips[0])}:6443"

  installer_image = "${var.image_factory_host}/nocloud-installer/${var.talos.schematic_id}:${var.talos.version}"

  cilium_values = merge({
    cluster = {
      name = var.spec.cluster
      id   = var.spec.cluster_id
    }
    ipam                 = { mode = "kubernetes" }
    kubeProxyReplacement = true
    k8sServiceHost       = "localhost"
    k8sServicePort       = 7445
    cgroup = {
      autoMount = { enabled = false }
      hostRoot  = "/sys/fs/cgroup"
    }
    securityContext = {
      capabilities = {
        ciliumAgent      = ["CHOWN", "KILL", "NET_ADMIN", "NET_RAW", "IPC_LOCK", "SYS_ADMIN", "SYS_RESOURCE", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID"]
        cleanCiliumState = ["NET_ADMIN", "SYS_ADMIN", "SYS_RESOURCE"]
      }
    }
    operator = { replicas = local.ha ? 2 : 1 }
  }, var.cilium.values)
}

data "helm_template" "cilium" {
  name         = "cilium"
  namespace    = "kube-system"
  repository   = var.cilium.repository
  chart        = "cilium"
  version      = var.cilium.version
  kube_version = var.spec.kubernetes_version
  values       = [yamlencode(local.cilium_values)]
}

module "config" {
  source = "./config"

  cluster = {
    name              = var.spec.cluster
    pod_cidr          = var.spec.network.pod_cidr
    service_cidr      = var.spec.network.service_cidr
    workloads_allowed = var.spec.control_plane.workloads_allowed
    vip               = local.ha ? try(var.vip.address, null) : null
    vip_link          = local.ha ? try(var.vip.link, null) : null
  }

  nodes = { for key, n in var.nodes : key => {
    role   = n.role
    labels = n.labels
    taints = n.taints
  } }

  installer_image  = local.installer_image
  install_disk     = var.install_disk
  disk_encryption  = var.disk_encryption
  inline_manifests = { cilium = data.helm_template.cilium.manifest }
}

resource "talos_machine_secrets" "this" {
  talos_version = var.talos.config_contract
}

data "talos_machine_configuration" "node" {
  for_each = var.nodes

  cluster_name       = var.spec.cluster
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = each.value.role == "control-plane" ? "controlplane" : "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos.config_contract
  kubernetes_version = var.spec.kubernetes_version
  config_patches     = module.config.patches[each.key]
}

ephemeral "talos_cluster_kubeconfig" "drain" {
  cluster_name    = var.spec.cluster
  endpoint        = local.cluster_endpoint
  machine_secrets = talos_machine_secrets.this.machine_secrets
}

resource "talos_machine" "node" {
  for_each = var.nodes

  node                            = each.value.private_ip
  client_configuration            = talos_machine_secrets.this.client_configuration
  machine_configuration           = data.talos_machine_configuration.node[each.key].machine_configuration
  image                           = local.installer_image
  ignore_kubernetes_upgrade_drift = true
  drain_on_upgrade                = local.ha
  kubeconfig_wo                   = ephemeral.talos_cluster_kubeconfig.drain.kubeconfig_raw

  lifecycle {
    precondition {
      condition     = !local.ha || var.vip != null
      error_message = "Topology ha needs the vip input (address and link)."
    }
  }
}

resource "talos_cluster" "this" {
  node                 = local.cp_ips[0]
  control_plane_nodes  = local.cp_ips
  client_configuration = talos_machine_secrets.this.client_configuration
  kubernetes_version   = "v${var.spec.kubernetes_version}"

  depends_on = [talos_machine.node]
}

resource "talos_cluster_kubeconfig" "this" {
  node                 = local.cp_ips[0]
  client_configuration = talos_machine_secrets.this.client_configuration

  depends_on = [talos_cluster.this]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.spec.cluster
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = local.cp_ips
  nodes                = [for n in values(var.nodes) : n.private_ip]
}
