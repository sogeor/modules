mock_provider "ansible" {}

variables {
  nodes = {
    home-cp = {
      name     = "lab-cp-1", fqdn = "lab-cp-1.lab.example.com", cluster = "lab", distribution = "kubeadm", role = "control-plane", pool = "cp"
      provider = "proxmox", site = "home", os = "ubuntu-2404", private_ip = "203.0.113.40", public_ip = null, ssh_user = "ops"
      labels   = { "sogeor.com/pool" = "cp" }, taints = [], mesh_required = false
    }
    vds-1 = {
      name     = "lab-vds-1", fqdn = "lab-vds-1.lab.example.com", cluster = "lab", distribution = "kubeadm", role = "worker", pool = "vds"
      provider = "byo", site = "vds-ams", os = "ubuntu-2404", private_ip = "198.51.100.10", public_ip = "198.51.100.10", ssh_user = "ops"
      labels   = {}, taints = ["dedicated=edge:NoSchedule"], mesh_required = true
    }
    vds-2 = {
      name     = "lab-vds-2", fqdn = "lab-vds-2.lab.example.com", cluster = "lab", distribution = "kubeadm", role = "worker", pool = "vds"
      provider = "byo", site = "vds-ams", os = "ubuntu-2404", private_ip = "198.51.100.11", public_ip = "198.51.100.11", ssh_user = "ops"
      labels   = {}, taints = [], mesh_required = true
    }
    talos = {
      name     = "mgmt-cp-1", fqdn = "mgmt-cp-1.lab.example.com", cluster = "mgmt", distribution = "talos", role = "control-plane", pool = "cp"
      provider = "proxmox", site = "home", os = "talos", private_ip = "203.0.113.31", public_ip = null, ssh_user = null
      labels   = {}, taints = [], mesh_required = false
    }
  }
  mesh_addresses = { lab-vds-2 = "100.64.0.12" }
  cluster_vars   = { lab = { kubernetes_version = "1.37.1", pod_cidr = "10.90.0.0/16" } }
}

run "inventory" {
  assert {
    condition     = toset(keys(ansible_host.node)) == toset(["lab-cp-1", "lab-vds-1", "lab-vds-2"])
    error_message = "Talos nodes are not in the inventory."
  }

  assert {
    condition     = output.hosts["lab-cp-1"].ansible_host == "203.0.113.40" && output.hosts["lab-cp-1"].connection == "private"
    error_message = "Home nodes are reached by their private address."
  }

  assert {
    condition     = output.hosts["lab-vds-2"].ansible_host == "100.64.0.12" && output.hosts["lab-vds-2"].connection == "mesh"
    error_message = "Nodes outside home use their mesh address once known."
  }

  assert {
    condition     = output.hosts["lab-vds-1"].connection == "public" && output.bootstrap_hosts == tolist(["lab-vds-1"])
    error_message = "Without a mesh address the public address is used and reported for bootstrap."
  }

  assert {
    condition     = ansible_host.node["lab-vds-1"].groups == tolist(["cluster_lab", "distribution_kubeadm", "internet", "mesh", "os_ubuntu_2404", "role_worker", "site_vds_ams"])
    error_message = "Groups follow the inventory contract with Ansible-safe names."
  }

  assert {
    condition     = !contains(ansible_host.node["lab-cp-1"].groups, "mesh") && !contains(ansible_host.node["lab-cp-1"].groups, "internet")
    error_message = "Home nodes without a public address are in neither mesh nor internet."
  }

  assert {
    condition     = ansible_host.node["lab-vds-1"].variables.ansible_user == "ops" && ansible_host.node["lab-vds-1"].variables.sogeor_node_taints == tolist(["dedicated=edge:NoSchedule"])
    error_message = "Host variables carry the user and node attributes."
  }

  assert {
    condition     = keys(ansible_group.cluster) == ["lab"] && ansible_group.cluster["lab"].name == "cluster_lab" && ansible_group.cluster["lab"].variables.pod_cidr == "10.90.0.0/16"
    error_message = "The cluster group carries the cluster variables."
  }

  assert {
    condition     = output.groups["role_worker"] == tolist(["lab-vds-1", "lab-vds-2"])
    error_message = "The groups output lists the hosts of each group."
  }
}

run "missing_ssh_user" {
  command = plan

  variables {
    nodes = {
      vds-1 = {
        name     = "lab-vds-1", fqdn = "lab-vds-1.lab.example.com", cluster = "lab", distribution = "kubeadm", role = "worker", pool = "vds"
        provider = "byo", site = "vds-ams", os = "ubuntu-2404", private_ip = "198.51.100.10", public_ip = "198.51.100.10", ssh_user = null
        labels   = {}, taints = [], mesh_required = true
      }
    }
  }

  expect_failures = [ansible_host.node]
}

