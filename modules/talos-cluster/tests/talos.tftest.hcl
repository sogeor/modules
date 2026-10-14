mock_provider "talos" {
  mock_data "talos_machine_configuration" {
    defaults = {
      machine_configuration = "version: v1alpha1"
    }
  }

  mock_data "talos_client_configuration" {
    defaults = {
      talos_config = "context: test"
    }
  }
}

mock_provider "helm" {
  mock_data "helm_template" {
    defaults = {
      manifest = "apiVersion: v1\nkind: ServiceAccount\nmetadata:\n  name: cilium\n"
    }
  }
}

variables {
  talos = {
    version         = "v1.14.2"
    schematic_id    = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    config_contract = "v1.14"
  }
  spec = {
    cluster            = "mgmt"
    cluster_id         = 1
    distribution       = "talos"
    kubernetes_version = "1.37.1"
    topology           = "single"
    network            = { pod_cidr = "10.10.0.0/16", service_cidr = "10.11.0.0/16" }
    control_plane      = { workloads_allowed = true }
  }
  nodes = {
    cp-1 = {
      name   = "mgmt-cp-1", distribution = "talos", role = "control-plane", pool = "cp", private_ip = "203.0.113.31"
      labels = { "sogeor.com/pool" = "cp", "topology.kubernetes.io/region" = "home" }, taints = []
    }
  }
}

run "single" {
  assert {
    condition     = output.endpoint == "https://203.0.113.31:6443"
    error_message = "single uses the control-plane node as the endpoint."
  }

  assert {
    condition     = output.installer_image == "factory.talos.dev/nocloud-installer/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:v1.14.2"
    error_message = "The installer comes from the Image Factory schematic."
  }

  assert {
    condition     = talos_cluster.this.kubernetes_version == "v1.37.1" && talos_cluster.this.control_plane_nodes == tolist(["203.0.113.31"])
    error_message = "talos_cluster drives the Kubernetes version over all control-plane nodes."
  }

  assert {
    condition     = talos_machine.node["cp-1"].ignore_kubernetes_upgrade_drift && !talos_machine.node["cp-1"].drain_on_upgrade
    error_message = "Kubernetes upgrades belong to talos_cluster; single nodes are not drained."
  }

  assert {
    condition     = talos_machine_secrets.this.talos_version == "v1.14" && data.talos_machine_configuration.node["cp-1"].talos_version == "v1.14"
    error_message = "Secrets and configuration use the fixed config contract."
  }

  assert {
    condition     = data.talos_machine_configuration.node["cp-1"].machine_type == "controlplane"
    error_message = "Control-plane nodes get controlplane configuration."
  }

  assert {
    condition     = data.helm_template.cilium.version == "1.20.2" && yamldecode(data.helm_template.cilium.values[0]).kubeProxyReplacement
    error_message = "Cilium 1.20.2 replaces kube-proxy."
  }

  assert {
    condition     = yamldecode(data.helm_template.cilium.values[0]).cluster == { name = "mgmt", id = 1 } && yamldecode(data.helm_template.cilium.values[0]).operator.replicas == 1
    error_message = "Cilium is ready for ClusterMesh and runs one operator in single."
  }

  assert {
    condition     = contains([for p in output.config_patches["cp-1"] : yamldecode(p).kind], "KubeInlineManifestConfig")
    error_message = "Cilium is installed at bootstrap as an inline manifest."
  }

  assert {
    condition     = length([for p in output.config_patches["cp-1"] : p if yamldecode(p).kind == "VolumeConfig" && can(yamldecode(p).encryption.keys[0].tpm)]) == 2
    error_message = "STATE and EPHEMERAL are encrypted with the TPM by default."
  }

  assert {
    condition     = [for p in output.config_patches["cp-1"] : yamldecode(p) if yamldecode(p).kind == "KubeNodeConfig"][0].taints["node-role.kubernetes.io/control-plane"] == { "$patch" = "delete" }
    error_message = "single removes the control-plane taint so workloads can run."
  }

  assert {
    condition     = [for p in output.config_patches["cp-1"] : yamldecode(p) if yamldecode(p).kind == "KubeNetworkConfig"][0].podSubnets == ["10.10.0.0/16"]
    error_message = "Pod CIDR comes from the cluster specification."
  }

  assert {
    condition     = !contains([for p in output.config_patches["cp-1"] : yamldecode(p).kind], "Layer2VIPConfig")
    error_message = "single has no VIP."
  }
}

run "ha" {
  variables {
    spec = { cluster = "mgmt", cluster_id = 1, distribution = "talos", kubernetes_version = "1.37.1", topology = "ha", network = { pod_cidr = "10.10.0.0/16", service_cidr = "10.11.0.0/16" }, control_plane = { workloads_allowed = false } }
    vip  = { address = "203.0.113.30", link = "eth0" }
    nodes = {
      cp-1      = { name = "mgmt-cp-1", distribution = "talos", role = "control-plane", pool = "cp", private_ip = "203.0.113.31", labels = {}, taints = [] }
      cp-2      = { name = "mgmt-cp-2", distribution = "talos", role = "control-plane", pool = "cp", private_ip = "203.0.113.32", labels = {}, taints = [] }
      cp-3      = { name = "mgmt-cp-3", distribution = "talos", role = "control-plane", pool = "cp", private_ip = "203.0.113.33", labels = {}, taints = [] }
      workers-1 = { name = "mgmt-workers-1", distribution = "talos", role = "worker", pool = "workers", private_ip = "203.0.113.41", labels = {}, taints = ["dedicated=db:NoSchedule", "spot:PreferNoSchedule"] }
    }
    disk_encryption = "nodeid"
  }

  assert {
    condition     = output.endpoint == "https://203.0.113.30:6443"
    error_message = "ha uses the VIP as the endpoint."
  }

  assert {
    condition     = length(talos_cluster.this.control_plane_nodes) == 3 && talos_machine.node["workers-1"].drain_on_upgrade
    error_message = "All control-plane nodes take part in health checks; ha drains nodes before upgrades."
  }

  assert {
    condition     = data.talos_machine_configuration.node["workers-1"].machine_type == "worker"
    error_message = "Workers get worker configuration."
  }

  assert {
    condition     = [for p in output.config_patches["workers-1"] : yamldecode(p) if yamldecode(p).kind == "KubeNodeConfig"][0].taints == { dedicated = "db:NoSchedule", spot = "PreferNoSchedule" }
    error_message = "Pool taints become Talos node taints."
  }

  assert {
    condition     = !contains([for p in output.config_patches["workers-1"] : yamldecode(p).kind], "KubeProxyConfig") && !contains([for p in output.config_patches["workers-1"] : yamldecode(p).kind], "KubeInlineManifestConfig")
    error_message = "Control-plane-only documents must not reach workers."
  }

  assert {
    condition     = contains([for p in output.config_patches["cp-2"] : yamldecode(p).kind], "Layer2VIPConfig")
    error_message = "Control-plane nodes announce the VIP."
  }

  assert {
    condition     = can([for p in output.config_patches["cp-1"] : yamldecode(p) if yamldecode(p).kind == "VolumeConfig"][0].encryption.keys[0].nodeID)
    error_message = "disk_encryption nodeid uses the node ID key."
  }

  assert {
    condition     = yamldecode(data.helm_template.cilium.values[0]).operator.replicas == 2
    error_message = "ha runs two Cilium operators."
  }
}

run "ha_without_vip" {
  command = plan

  variables {
    spec = { cluster = "mgmt", cluster_id = 1, distribution = "talos", kubernetes_version = "1.37.1", topology = "ha", network = { pod_cidr = "10.10.0.0/16", service_cidr = "10.11.0.0/16" }, control_plane = { workloads_allowed = false } }
  }

  expect_failures = [talos_machine.node]
}

run "wrong_distribution" {
  command = plan

  variables {
    spec = { cluster = "mgmt", cluster_id = 1, distribution = "kubeadm", kubernetes_version = "1.37.1", topology = "single", network = { pod_cidr = "10.10.0.0/16", service_cidr = "10.11.0.0/16" }, control_plane = { workloads_allowed = true } }
  }

  expect_failures = [var.spec]
}

run "no_encryption" {
  command = plan

  variables {
    disk_encryption = "none"
  }

  assert {
    condition     = !contains([for p in output.config_patches["cp-1"] : yamldecode(p).kind], "VolumeConfig")
    error_message = "disk_encryption none adds no volume encryption."
  }
}
