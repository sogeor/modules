module "talos_config" {
  source = "../talos-cluster/config"
  count  = local.talos ? 1 : 0

  cluster = {
    name              = local.name
    pod_cidr          = local.c.network.pod_cidr
    service_cidr      = local.c.network.service_cidr
    workloads_allowed = local.c.control_plane.workloads_allowed
    vip               = local.infra == "proxmox" ? try(var.proxmox.control_plane_endpoint, null) : null
    vip_link          = local.infra == "proxmox" ? try(var.proxmox.vip_interface, null) : null
  }

  nodes = { for name, p in local.c.pools : name => { role = p.role, labels = p.labels, taints = p.taints } }

  installer_image         = "factory.talos.dev/${local.infra == "proxmox" ? "nocloud" : "openstack"}-installer/${try(var.images.talos.schematic_id, "")}:${local.talos_version}"
  install_disk            = local.infra == "proxmox" ? "/dev/sda" : "/dev/vda"
  disk_encryption         = var.talos_disk_encryption
  inline_manifests        = {}
  external_cloud_provider = local.infra == "openstack"
}

locals {
  kube_vip_image = "ghcr.io/kube-vip/kube-vip:v1.2.4@sha256:dde4c0669d9058c74c69c0bc2f0122e26900e1e4b913c03577cb6e4e28083079"

  kubelet_provider_args = {
    proxmox   = [{ name = "provider-id", value = "proxmox://'{{ ds.meta_data.instance_id }}'" }]
    openstack = [{ name = "cloud-provider", value = "external" }]
  }

  node_registration = { for name, p in local.c.pools : name => {
    kubeletExtraArgs = concat(
      local.kubelet_provider_args[local.infra],
      [{ name = "node-labels", value = join(",", [for k in sort(keys(p.labels)) : "${k}=${p.labels[k]}"]) }],
    )
    taints = concat(
      local.taints[name],
      p.role == "control-plane" && !local.c.control_plane.workloads_allowed ? [{ key = "node-role.kubernetes.io/control-plane", effect = "NoSchedule" }] : [],
    )
  } }

  kube_vip_files = [
    { path = "/etc/kubernetes/manifests/kube-vip.yaml", owner = "root:root", permissions = "0600", content = templatefile("${path.module}/files/kube-vip.yaml.tftpl", {
      image     = local.kube_vip_image
      interface = try(coalesce(var.proxmox.vip_interface, ""), "")
      address   = try(var.proxmox.control_plane_endpoint, "")
    }) },
    { path = "/etc/kube-vip-prepare.sh", owner = "root:root", permissions = "0700", content = file("${path.module}/files/kube-vip-prepare.sh") },
  ]

  kube_vip = local.infra == "proxmox" && !local.talos

  bootstrap_spec = { for name, p in local.c.pools : name => {
    talos = try({
      generateType     = p.role == "control-plane" ? "controlplane" : "worker"
      talosVersion     = local.talos_contract
      strategicPatches = module.talos_config[0].patches[name]
    }, null)
    kubeadm = { joinConfiguration = { nodeRegistration = local.node_registration[name] } }
  }[local.c.distribution] }

  bootstrap_template = { for name, p in local.workers : name => {
    apiVersion = local.talos ? "bootstrap.cluster.x-k8s.io/v1alpha3" : "bootstrap.cluster.x-k8s.io/v1beta2"
    kind       = local.talos ? "TalosConfigTemplate" : "KubeadmConfigTemplate"
    metadata   = { name = local.template_name[name], namespace = local.namespace, labels = local.cluster_label }
    spec       = { template = { spec = local.bootstrap_spec[name] } }
  } }

  talos_control_plane = {
    apiVersion = "controlplane.cluster.x-k8s.io/v1alpha3"
    kind       = "TalosControlPlane"
    metadata   = { name = "${local.name}-control-plane", namespace = local.namespace, labels = local.cluster_label }
    spec = {
      version  = local.version
      replicas = local.c.control_plane.count
      infrastructureTemplate = {
        apiVersion = local.infra_api[local.infra]
        kind       = local.infra_ref[local.cp_pool].kind
        name       = local.template_name[local.cp_pool]
        namespace  = local.namespace
      }
      controlPlaneConfig = { controlplane = local.bootstrap_spec[local.cp_pool] }
    }
  }

  kubeadm_control_plane = {
    apiVersion = "controlplane.cluster.x-k8s.io/v1beta2"
    kind       = "KubeadmControlPlane"
    metadata   = { name = "${local.name}-control-plane", namespace = local.namespace, labels = local.cluster_label }
    spec = {
      version         = local.version
      replicas        = local.c.control_plane.count
      machineTemplate = { spec = { infrastructureRef = local.infra_ref[local.cp_pool] } }
      kubeadmConfigSpec = merge(
        {
          initConfiguration = {
            nodeRegistration = local.node_registration[local.cp_pool]
            skipPhases       = ["addon/kube-proxy"]
          }
          joinConfiguration = { nodeRegistration = local.node_registration[local.cp_pool] }
        },
        local.kube_vip ? { files = local.kube_vip_files } : {},
        local.kube_vip ? { preKubeadmCommands = ["/etc/kube-vip-prepare.sh"] } : {},
      )
    }
  }

  control_plane = { talos = local.talos_control_plane, kubeadm = local.kubeadm_control_plane }[local.c.distribution]
}
