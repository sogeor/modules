variables {
  spec = {
    cluster            = "lab"
    distribution       = "talos"
    kubernetes_version = "1.37.1"
    topology           = "single"
    mechanism          = "capi"
    labels             = { "sogeor.com/cluster" = "lab" }
    network            = { pod_cidr = "10.90.0.0/16", service_cidr = "10.91.0.0/16" }
    control_plane      = { count = 1, workloads_allowed = true }
    pools = {
      cp = { role = "control-plane", os = "talos", provider = "proxmox", size = "m", cpu = 2, memory_mb = 4096, disk_gb = 40, count = 1, labels = { "sogeor.com/pool" = "cp" }, taints = [] }
    }
  }
  images = {
    talos  = { version = "v1.14.2", schematic_id = "7d4c31cbd96db9f90c874990697c523482b2bae27fb4631d5583dcd9c281b1ff" }
    builds = { talos = "v20-1", ubuntu-2404 = "v20-1" }
  }
  proxmox = {
    source_node            = "pve"
    bridge                 = "vmbr0"
    addresses              = ["203.0.113.40-203.0.113.49"]
    prefix                 = 24
    gateway                = "203.0.113.1"
    dns_servers            = ["203.0.113.1"]
    control_plane_endpoint = "203.0.113.39"
    vip_interface          = "ens18"
  }
}

run "talos_proxmox_single" {
  command = plan

  assert {
    condition     = [for o in output.objects : o.kind] == ["Cluster", "ProxmoxCluster", "TalosControlPlane", "ProxmoxMachineTemplate"]
    error_message = "A single Talos cluster without workers renders Cluster, ProxmoxCluster, TalosControlPlane and one machine template."
  }

  assert {
    condition     = output.objects[3].spec.template.spec.templateSelector.matchTags == tolist(["packer", "talos", "base", "talos-1-14-2", "schematic-7d4c31cbd96d", "v20-1"])
    error_message = "The Talos template is selected by the full tag set of the images contract."
  }

  assert {
    condition     = output.objects[3].spec.template.spec.checks.skipCloudInitStatus && output.objects[3].spec.template.spec.metadataSettings.providerIDInjection
    error_message = "Talos VMs skip the cloud-init check and get the provider ID injected."
  }

  assert {
    condition     = output.objects[2].spec.replicas == 1 && output.objects[2].spec.version == "v1.37.1" && output.objects[2].spec.controlPlaneConfig.controlplane.talosVersion == "v1.14"
    error_message = "The control plane has one replica, the Kubernetes version and the Talos config contract."
  }

  assert {
    condition     = anytrue([for p in output.objects[2].spec.controlPlaneConfig.controlplane.strategicPatches : strcontains(p, "Layer2VIPConfig") && strcontains(p, "203.0.113.39")])
    error_message = "Talos on Proxmox announces the control-plane endpoint as a Layer 2 VIP."
  }

  assert {
    condition     = output.objects[3].metadata.name == "lab-cp-dfce1d9a"
    error_message = "Machine template names carry a hash of their content."
  }

  assert {
    condition     = output.objects[1].spec.controlPlaneEndpoint.host == "203.0.113.39" && output.objects[0].metadata.namespace == "lab"
    error_message = "The endpoint is the VIP and objects live in the namespace named after the cluster."
  }

  assert {
    condition     = startswith(output.manifest, "---\n") && length(split("---\n", output.manifest)) == 5
    error_message = "The manifest holds one YAML document per object."
  }
}

run "kubeadm_proxmox_ha" {
  command = plan

  variables {
    spec = {
      cluster            = "lab"
      distribution       = "kubeadm"
      kubernetes_version = "1.37.1"
      topology           = "ha"
      mechanism          = "capi"
      labels             = {}
      network            = { pod_cidr = "10.90.0.0/16", service_cidr = "10.91.0.0/16" }
      control_plane      = { count = 3, workloads_allowed = false }
      pools = {
        cp      = { role = "control-plane", os = "ubuntu-2404", provider = "proxmox", size = "m", cpu = 2, memory_mb = 4096, disk_gb = 40, count = 3, labels = { "sogeor.com/pool" = "cp" }, taints = [] }
        workers = { role = "worker", os = "ubuntu-2404", provider = "proxmox", size = "l", cpu = 4, memory_mb = 8192, disk_gb = 80, count = 2, labels = { "sogeor.com/pool" = "workers" }, taints = ["dedicated=db:NoSchedule"] }
      }
    }
  }

  assert {
    condition     = [for o in output.objects : o.kind] == ["Cluster", "ProxmoxCluster", "KubeadmControlPlane", "ProxmoxMachineTemplate", "ProxmoxMachineTemplate", "KubeadmConfigTemplate", "MachineDeployment", "MachineHealthCheck", "MachineHealthCheck"]
    error_message = "An ha kubeadm cluster renders a worker pool and health checks for workers and the control plane."
  }

  assert {
    condition     = output.objects[3].spec.template.spec.templateSelector.matchTags == tolist(["packer", "ubuntu-2404", "k8s", "k8s-1-37", "v20-1"])
    error_message = "Ubuntu templates are selected by OS, Kubernetes minor version and build."
  }

  assert {
    condition     = [for f in output.objects[2].spec.kubeadmConfigSpec.files : f.path] == ["/etc/kubernetes/manifests/kube-vip.yaml", "/etc/kube-vip-prepare.sh"] && strcontains(output.objects[2].spec.kubeadmConfigSpec.files[0].content, "203.0.113.39")
    error_message = "kubeadm on Proxmox runs kube-vip for the control-plane VIP."
  }

  assert {
    condition     = output.objects[2].spec.kubeadmConfigSpec.initConfiguration.nodeRegistration.taints == [{ key = "node-role.kubernetes.io/control-plane", effect = "NoSchedule" }]
    error_message = "ha control-plane nodes keep the control-plane taint."
  }

  assert {
    condition     = output.objects[5].spec.template.spec.joinConfiguration.nodeRegistration.taints == [{ key = "dedicated", effect = "NoSchedule", value = "db" }]
    error_message = "Pool taints are registered by kubeadm."
  }

  assert {
    condition     = output.objects[6].spec.replicas == 2 && output.objects[6].spec.template.spec.bootstrap.configRef.name == output.objects[5].metadata.name
    error_message = "A fixed-size pool sets replicas and references its bootstrap template."
  }
}

run "kubeadm_openstack_autoscale" {
  command = plan

  variables {
    spec = {
      cluster            = "lab"
      distribution       = "kubeadm"
      kubernetes_version = "1.37.1"
      topology           = "single"
      mechanism          = "capi"
      labels             = {}
      network            = { pod_cidr = "10.90.0.0/16", service_cidr = "10.91.0.0/16" }
      control_plane      = { count = 1, workloads_allowed = true }
      pools = {
        cp      = { role = "control-plane", os = "ubuntu-2404", provider = "selectel", size = "m", cpu = 2, memory_mb = 4096, disk_gb = 40, count = 1, labels = { "sogeor.com/pool" = "cp" }, taints = [] }
        workers = { role = "worker", os = "ubuntu-2404", provider = "selectel", size = "l", cpu = 4, memory_mb = 8192, disk_gb = 80, autoscale = { min = 0, max = 3 }, labels = { "sogeor.com/pool" = "workers" }, taints = [] }
      }
    }
    proxmox = null
    openstack = {
      identity_secret  = "openstack-credentials"
      external_network = "external-network"
      dns_nameservers  = ["198.51.100.53"]
      flavors          = { m = "flavor-m", l = "flavor-l" }
    }
  }

  assert {
    condition     = output.infrastructure == "openstack" && output.objects[1].kind == "OpenStackCluster" && !output.objects[1].spec.apiServer.managedLoadBalancer.enabled
    error_message = "Selectel uses CAPO; single clusters have no API load balancer by default."
  }

  assert {
    condition     = output.objects[3].spec.template.spec.image.filter.name == "ubuntu-2404-k8s-v20-1" && output.objects[4].spec.template.spec.flavor.filter.name == "flavor-l"
    error_message = "OpenStack machines use the image name of the contract and the flavor of the pool size."
  }

  assert {
    condition     = output.objects[2].spec.kubeadmConfigSpec.initConfiguration.nodeRegistration.taints == [] && !can(output.objects[2].spec.kubeadmConfigSpec.files)
    error_message = "single control planes accept workloads; OpenStack needs no kube-vip."
  }

  assert {
    condition     = contains(output.objects[2].spec.kubeadmConfigSpec.initConfiguration.nodeRegistration.kubeletExtraArgs, { name = "cloud-provider", value = "external" })
    error_message = "On OpenStack the kubelet waits for the external cloud controller manager."
  }

  assert {
    condition     = !can(output.objects[6].spec.replicas) && output.objects[6].metadata.annotations["cluster.x-k8s.io/cluster-api-autoscaler-node-group-max-size"] == "3" && output.objects[6].metadata.annotations["capacity.cluster-autoscaler.kubernetes.io/memory"] == "8192Mi"
    error_message = "Autoscaled pools leave replicas to the Cluster Autoscaler and carry bounds and capacity."
  }
}

run "talos_openstack_image" {
  command = plan

  variables {
    spec = {
      cluster            = "lab"
      distribution       = "talos"
      kubernetes_version = "1.37.1"
      topology           = "single"
      mechanism          = "capi"
      labels             = {}
      network            = { pod_cidr = "10.90.0.0/16", service_cidr = "10.91.0.0/16" }
      control_plane      = { count = 1, workloads_allowed = true }
      pools = {
        cp = { role = "control-plane", os = "talos", provider = "vkcloud", size = "m", cpu = 2, memory_mb = 4096, disk_gb = 40, count = 1, labels = { "sogeor.com/pool" = "cp" }, taints = [] }
      }
    }
    images = {
      talos = { version = "v1.14.2", schematic_id = "7d4c31cbd96db9f90c874990697c523482b2bae27fb4631d5583dcd9c281b1ff" }
    }
    proxmox = null
    openstack = {
      identity_secret  = "openstack-credentials"
      external_network = "external-network"
      dns_nameservers  = ["198.51.100.53"]
      flavors          = { m = "flavor-m" }
    }
  }

  assert {
    condition     = output.objects[3].spec.template.spec.image.filter.name == "talos-v1.14.2-7d4c31cbd96d"
    error_message = "Talos on OpenStack is selected by version and schematic, without a build."
  }

  assert {
    condition     = anytrue([for p in output.objects[2].spec.controlPlaneConfig.controlplane.strategicPatches : strcontains(p, "externalCloudProvider")]) && alltrue([for p in output.objects[2].spec.controlPlaneConfig.controlplane.strategicPatches : !strcontains(p, "Layer2VIPConfig")])
    error_message = "Talos on OpenStack uses the external cloud provider and no VIP."
  }
}

run "template_name_follows_content" {
  command = plan

  variables {
    spec = {
      cluster            = "lab"
      distribution       = "talos"
      kubernetes_version = "1.37.1"
      topology           = "single"
      mechanism          = "capi"
      labels             = {}
      network            = { pod_cidr = "10.90.0.0/16", service_cidr = "10.91.0.0/16" }
      control_plane      = { count = 1, workloads_allowed = true }
      pools = {
        cp = { role = "control-plane", os = "talos", provider = "proxmox", size = "l", cpu = 4, memory_mb = 8192, disk_gb = 80, count = 1, labels = { "sogeor.com/pool" = "cp" }, taints = [] }
      }
    }
  }

  assert {
    condition     = output.objects[3].metadata.name != "lab-cp-dfce1d9a" && can(regex("^lab-cp-[0-9a-f]{8}$", output.objects[3].metadata.name))
    error_message = "A changed machine template gets a new name, so CAPI rolls the machines."
  }
}

run "missing_provider_settings" {
  command = plan

  variables {
    proxmox = null
  }

  expect_failures = [output.objects]
}

run "missing_build" {
  command = plan

  variables {
    images = {
      talos = { version = "v1.14.2", schematic_id = "7d4c31cbd96db9f90c874990697c523482b2bae27fb4631d5583dcd9c281b1ff" }
    }
  }

  expect_failures = [output.objects]
}

run "mixed_providers" {
  command = plan

  variables {
    spec = {
      cluster            = "lab"
      distribution       = "kubeadm"
      kubernetes_version = "1.37.1"
      topology           = "single"
      mechanism          = "capi"
      labels             = {}
      network            = { pod_cidr = "10.90.0.0/16", service_cidr = "10.91.0.0/16" }
      control_plane      = { count = 1, workloads_allowed = true }
      pools = {
        cp    = { role = "control-plane", os = "ubuntu-2404", provider = "selectel", size = "m", cpu = 2, memory_mb = 4096, disk_gb = 40, count = 1, labels = {}, taints = [] }
        astra = { role = "worker", os = "astra-18", provider = "proxmox", size = "m", cpu = 2, memory_mb = 4096, disk_gb = 40, count = 1, labels = {}, taints = [] }
      }
    }
  }

  expect_failures = [var.spec]
}

run "k3s_rejected" {
  command = plan

  variables {
    spec = {
      cluster            = "lab"
      distribution       = "k3s"
      kubernetes_version = "1.37.1"
      topology           = "single"
      mechanism          = "capi"
      labels             = {}
      network            = { pod_cidr = "10.90.0.0/16", service_cidr = "10.91.0.0/16" }
      control_plane      = { count = 1, workloads_allowed = true }
      pools = {
        cp = { role = "control-plane", os = "ubuntu-2404", provider = "proxmox", size = "m", cpu = 2, memory_mb = 4096, disk_gb = 40, count = 1, labels = {}, taints = [] }
      }
    }
  }

  expect_failures = [var.spec]
}
