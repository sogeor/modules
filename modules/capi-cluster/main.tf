locals {
  c         = var.spec
  name      = local.c.cluster
  namespace = coalesce(var.namespace, local.c.cluster)
  version   = "v${local.c.kubernetes_version}"
  talos     = local.c.distribution == "talos"

  provider = values(local.c.pools)[0].provider
  infra    = local.provider == "proxmox" ? "proxmox" : "openstack"

  cp_pool = one([for name, p in local.c.pools : name if p.role == "control-plane"])
  workers = { for name, p in local.c.pools : name => p if p.role == "worker" }

  cluster_label = { "cluster.x-k8s.io/cluster-name" = local.name }
  k8s_minor     = join("-", slice(split(".", local.c.kubernetes_version), 0, 2))

  infra_api = {
    proxmox   = "infrastructure.cluster.x-k8s.io/v1alpha2"
    openstack = "infrastructure.cluster.x-k8s.io/v1beta2"
  }
  infra_kind = {
    proxmox   = "Proxmox"
    openstack = "OpenStack"
  }

  talos_version  = try(var.images.talos.version, "")
  talos_contract = try(regex("^v[0-9]+\\.[0-9]+", local.talos_version), "")
  schematic12    = substr(try(var.images.talos.schematic_id, ""), 0, 12)

  proxmox_tags = { for name, p in local.c.pools : name => (
    p.os == "talos"
    ? ["packer", "talos", "base", "talos-${replace(trimprefix(local.talos_version, "v"), ".", "-")}", "schematic-${local.schematic12}", lookup(var.images.builds, p.os, "")]
    : ["packer", p.os, "k8s", "k8s-${local.k8s_minor}", lookup(var.images.builds, p.os, "")]
  ) }

  openstack_image = { for name, p in local.c.pools : name => (
    p.os == "talos" ? "talos-${local.talos_version}-${local.schematic12}" : "${p.os}-k8s-${lookup(var.images.builds, p.os, "")}"
  ) }

  taints = { for name, p in local.c.pools : name => [for t in p.taints : merge(
    { key = split("=", split(":", t)[0])[0], effect = split(":", t)[1] },
    length(split("=", split(":", t)[0])) > 1 ? { value = split("=", split(":", t)[0])[1] } : {},
  )] }

  machine_spec = { for name, p in local.c.pools : name => {
    proxmox = try(merge(
      {
        sourceNode       = var.proxmox.source_node
        templateSelector = { matchTags = local.proxmox_tags[name], matchPolicy = "exact" }
        full             = true
        numSockets       = 1
        numCores         = p.cpu
        memoryMiB        = p.memory_mb
        disks            = { bootVolume = { disk = "scsi0", sizeGb = p.disk_gb } }
        network = { networkDevices = [merge(
          { name = "net0", bridge = var.proxmox.bridge, model = "virtio" },
          var.proxmox.vlan == null ? {} : { vlan = var.proxmox.vlan },
        )] }
      },
      var.proxmox.storage == null ? {} : { storage = var.proxmox.storage },
      local.talos ? { checks = { skipCloudInitStatus = true } } : {},
      local.talos ? { metadataSettings = { providerIDInjection = true } } : {},
    ), null)
    openstack = try(merge(
      {
        flavor     = { filter = { name = lookup(var.openstack.flavors, p.size, "") } }
        image      = { filter = { name = local.openstack_image[name] } }
        rootVolume = merge({ sizeGiB = p.disk_gb }, var.openstack.volume_type == null ? {} : { type = var.openstack.volume_type })
      },
      var.openstack.ssh_key_name == null || local.talos ? {} : { sshKeyName = var.openstack.ssh_key_name },
    ), null)
  }[local.infra] }

  template_name = { for name, p in local.c.pools : name => (
    "${local.name}-${name}-${substr(sha256(jsonencode([local.machine_spec[name], local.bootstrap_spec[name]])), 0, 8)}"
  ) }

  machine_template = { for name, p in local.c.pools : name => {
    apiVersion = local.infra_api[local.infra]
    kind       = "${local.infra_kind[local.infra]}MachineTemplate"
    metadata   = { name = local.template_name[name], namespace = local.namespace, labels = local.cluster_label }
    spec       = { template = { spec = local.machine_spec[name] } }
  } }

  infra_ref = { for name, p in local.c.pools : name => {
    apiGroup = "infrastructure.cluster.x-k8s.io"
    kind     = local.machine_template[name].kind
    name     = local.template_name[name]
  } }

  cluster = {
    apiVersion = "cluster.x-k8s.io/v1beta2"
    kind       = "Cluster"
    metadata   = { name = local.name, namespace = local.namespace, labels = merge(local.c.labels, local.cluster_label) }
    spec = {
      clusterNetwork = {
        pods     = { cidrBlocks = [local.c.network.pod_cidr] }
        services = { cidrBlocks = [local.c.network.service_cidr] }
      }
      controlPlaneRef = {
        apiGroup = "controlplane.cluster.x-k8s.io"
        kind     = local.talos ? "TalosControlPlane" : "KubeadmControlPlane"
        name     = "${local.name}-control-plane"
      }
      infrastructureRef = {
        apiGroup = "infrastructure.cluster.x-k8s.io"
        kind     = "${local.infra_kind[local.infra]}Cluster"
        name     = local.name
      }
    }
  }

  infra_cluster = {
    proxmox = try({
      apiVersion = local.infra_api.proxmox
      kind       = "ProxmoxCluster"
      metadata   = { name = local.name, namespace = local.namespace, labels = local.cluster_label }
      spec = merge(
        {
          controlPlaneEndpoint = { host = var.proxmox.control_plane_endpoint, port = 6443 }
          ipv4Config           = { addresses = var.proxmox.addresses, prefix = var.proxmox.prefix, gateway = var.proxmox.gateway }
          dnsServers           = var.proxmox.dns_servers
        },
        length(var.proxmox.allowed_nodes) == 0 ? {} : { allowedNodes = var.proxmox.allowed_nodes },
        var.proxmox.credentials_secret == null ? {} : { credentialsRef = { name = var.proxmox.credentials_secret } },
      )
    }, null)
    openstack = try({
      apiVersion = local.infra_api.openstack
      kind       = "OpenStackCluster"
      metadata   = { name = local.name, namespace = local.namespace, labels = local.cluster_label }
      spec = {
        identityRef           = { type = "Secret", name = var.openstack.identity_secret, cloudName = var.openstack.cloud_name }
        externalNetwork       = { filter = { name = var.openstack.external_network } }
        managedSubnets        = [{ cidr = var.openstack.node_cidr, dnsNameservers = var.openstack.dns_nameservers }]
        managedSecurityGroups = { allowAllInClusterTraffic = true }
        apiServer = {
          enableFloatingIP = var.openstack.api_floating_ip
          managedLoadBalancer = merge(
            { enabled = coalesce(var.openstack.load_balancer, local.c.topology == "ha") },
            length(var.openstack.api_allowed_cidrs) == 0 ? {} : { allowedCIDRs = var.openstack.api_allowed_cidrs },
          )
        }
      }
    }, null)
  }[local.infra]

  autoscale_annotations = { for name, p in local.workers : name => p.autoscale == null ? {} : merge(
    {
      "cluster.x-k8s.io/cluster-api-autoscaler-node-group-min-size" = tostring(p.autoscale.min)
      "cluster.x-k8s.io/cluster-api-autoscaler-node-group-max-size" = tostring(p.autoscale.max)
      "capacity.cluster-autoscaler.kubernetes.io/cpu"               = tostring(p.cpu)
      "capacity.cluster-autoscaler.kubernetes.io/memory"            = "${p.memory_mb}Mi"
      "capacity.cluster-autoscaler.kubernetes.io/ephemeral-disk"    = "${p.disk_gb}Gi"
      "capacity.cluster-autoscaler.kubernetes.io/labels"            = join(",", [for k in sort(keys(p.labels)) : "${k}=${p.labels[k]}"])
    },
    length(p.taints) == 0 ? {} : { "capacity.cluster-autoscaler.kubernetes.io/taints" = join(",", p.taints) },
  ) }

  machine_deployments = [for name, p in local.workers : {
    apiVersion = "cluster.x-k8s.io/v1beta2"
    kind       = "MachineDeployment"
    metadata = merge(
      { name = "${local.name}-${name}", namespace = local.namespace, labels = local.cluster_label },
      p.autoscale == null ? {} : { annotations = local.autoscale_annotations[name] },
    )
    spec = merge(
      {
        clusterName = local.name
        selector    = { matchLabels = merge(local.cluster_label, { "sogeor.com/pool" = name }) }
        template = {
          metadata = { labels = merge(local.cluster_label, { "sogeor.com/pool" = name }) }
          spec = {
            clusterName = local.name
            version     = local.version
            bootstrap = { configRef = {
              apiGroup = "bootstrap.cluster.x-k8s.io"
              kind     = local.talos ? "TalosConfigTemplate" : "KubeadmConfigTemplate"
              name     = local.template_name[name]
            } }
            infrastructureRef = local.infra_ref[name]
          }
        }
      },
      p.autoscale == null ? { replicas = p.count } : {},
    )
  }]

  health_checks = {
    unhealthyNodeConditions = [
      { type = "Ready", status = "Unknown", timeoutSeconds = 900 },
      { type = "Ready", status = "False", timeoutSeconds = 900 },
    ]
    nodeStartupTimeoutSeconds = 1200
  }

  machine_health_checks = concat(
    length(local.workers) == 0 ? [] : [{
      apiVersion = "cluster.x-k8s.io/v1beta2"
      kind       = "MachineHealthCheck"
      metadata   = { name = "${local.name}-workers", namespace = local.namespace, labels = local.cluster_label }
      spec = {
        clusterName = local.name
        selector = {
          matchLabels      = local.cluster_label
          matchExpressions = [{ key = "cluster.x-k8s.io/deployment-name", operator = "Exists" }]
        }
        checks = local.health_checks
      }
    }],
    local.c.topology == "ha" ? [{
      apiVersion = "cluster.x-k8s.io/v1beta2"
      kind       = "MachineHealthCheck"
      metadata   = { name = "${local.name}-control-plane", namespace = local.namespace, labels = local.cluster_label }
      spec = {
        clusterName = local.name
        selector    = { matchLabels = merge(local.cluster_label, { "cluster.x-k8s.io/control-plane" = "" }) }
        checks      = local.health_checks
      }
    }] : [],
  )

  objects = concat(
    [local.cluster, local.infra_cluster, local.control_plane],
    [for name in sort(keys(local.c.pools)) : local.machine_template[name]],
    [for name in sort(keys(local.workers)) : local.bootstrap_template[name]],
    local.machine_deployments,
    local.machine_health_checks,
  )
}
