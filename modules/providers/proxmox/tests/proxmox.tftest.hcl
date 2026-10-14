mock_provider "proxmox" {
  mock_data "proxmox_virtual_environment_vms" {
    defaults = {
      vms = []
    }
  }

  mock_resource "proxmox_download_file" {
    defaults = {
      id = "local:iso/talos-v1.14.2-aaaaaaaaaaaa-nocloud-amd64.iso"
    }
  }

  mock_resource "proxmox_virtual_environment_vm" {
    defaults = {
      vm_id = 100
    }
  }
}

variables {
  proxmox = {
    node_name        = "pve-test"
    datastore_id     = "local-lvm"
    iso_datastore_id = "local"
    bridge           = "vmbr0"
  }
  network = {
    prefix_length = 24
    gateway       = "203.0.113.1"
    dns_servers   = ["203.0.113.1"]
    domain        = "lab.example.com"
  }
  talos = {
    version      = "v1.14.2"
    schematic_id = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    iso_sha256   = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  }
  ssh = {
    user        = "ops"
    public_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleExampleExampleExampleExampleExample test"]
  }
}

run "talos_spec" {
  command = apply

  module {
    source = "./tests/spec"
  }

  variables {
    cluster = {
      cluster = "mgmt", cluster_id = 1, distribution = "talos", kubernetes_version = "1.37.1", topology = "single", mechanism = "opentofu"
      pools = {
        cp = { role = "control-plane", os = "talos", provider = "proxmox", site = "home", size = "xl", count = 1 }
      }
    }
  }
}

run "talos_nodes" {
  variables {
    spec      = run.talos_spec.spec
    addresses = { cp = ["203.0.113.31"] }
  }

  assert {
    condition     = keys(output.nodes) == ["cp-1"]
    error_message = "One control-plane node is expected."
  }

  assert {
    condition     = output.nodes["cp-1"].name == "mgmt-cp-1" && output.nodes["cp-1"].fqdn == "mgmt-cp-1.lab.example.com" && output.nodes["cp-1"].private_ip == "203.0.113.31"
    error_message = "Name, FQDN and address must follow the contract."
  }

  assert {
    condition     = output.nodes["cp-1"].ssh_user == null && output.nodes["cp-1"].mesh_required == false && output.nodes["cp-1"].public_ip == null
    error_message = "Talos nodes have no SSH user; home nodes need no mesh."
  }

  assert {
    condition     = output.nodes["cp-1"].labels["topology.kubernetes.io/region"] == "home" && output.nodes["cp-1"].labels["topology.kubernetes.io/zone"] == "pve-test"
    error_message = "Topology labels must be the site and the Proxmox node."
  }

  assert {
    condition     = proxmox_virtual_environment_vm.node["cp-1"].cpu[0].cores == 8 && proxmox_virtual_environment_vm.node["cp-1"].memory[0].dedicated == 16384 && proxmox_virtual_environment_vm.node["cp-1"].disk[0].size == 160
    error_message = "Size xl must give 8 cores, 16384 MB and 160 GB."
  }

  assert {
    condition     = length(proxmox_virtual_environment_vm.node["cp-1"].clone) == 0 && proxmox_virtual_environment_vm.node["cp-1"].cdrom[0].file_id == output.talos_iso
    error_message = "Talos boots from the Image Factory ISO, not from a clone."
  }

  assert {
    condition     = proxmox_download_file.talos_iso[0].url == "https://factory.talos.dev/image/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/v1.14.2/nocloud-amd64.iso"
    error_message = "The ISO URL must use the schematic and the version."
  }

  assert {
    condition     = proxmox_download_file.talos_iso[0].checksum == "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    error_message = "The ISO must be verified with the given SHA-256."
  }

  assert {
    condition     = proxmox_virtual_environment_vm.node["cp-1"].initialization[0].ip_config[0].ipv4[0].address == "203.0.113.31/24"
    error_message = "The address must carry the prefix length."
  }

  assert {
    condition     = proxmox_virtual_environment_vm.node["cp-1"].tpm_state[0].version == "v2.0"
    error_message = "Talos VMs need a TPM 2.0 for disk encryption."
  }
}

run "missing_address" {
  command = plan

  variables {
    spec      = run.talos_spec.spec
    addresses = { cp = [] }
  }

  expect_failures = [proxmox_virtual_environment_vm.node]
}

run "missing_talos" {
  command = plan

  variables {
    spec      = run.talos_spec.spec
    addresses = { cp = ["203.0.113.31"] }
    talos     = null
  }

  expect_failures = [proxmox_download_file.talos_iso]
}

run "kubeadm_spec" {
  command = apply

  module {
    source = "./tests/spec"
  }

  variables {
    cluster = {
      cluster = "lab", cluster_id = 9, distribution = "kubeadm", kubernetes_version = "1.37.1", topology = "single", mechanism = "opentofu"
      pools = {
        cp      = { role = "control-plane", os = "ubuntu-2404", provider = "proxmox", site = "home", size = "m", count = 1 }
        workers = { role = "worker", os = "ubuntu-2404", provider = "proxmox", site = "home", size = "l", count = 2 }
        vds     = { role = "worker", os = "ubuntu-2404", provider = "byo", site = "vds", size = "s", count = 1 }
      }
    }
  }
}

run "kubeadm_nodes" {
  command = plan

  variables {
    spec      = run.kubeadm_spec.spec
    addresses = { cp = ["203.0.113.40"], workers = ["203.0.113.41", "203.0.113.42"] }
  }

  override_data {
    target = data.proxmox_virtual_environment_vms.templates["ubuntu-2404"]
    values = {
      vms = [
        { name = "ubuntu-2404-k8s-v3-1", vm_id = 9003, node_name = "pve-test", tags = [], status = "stopped", template = true },
        { name = "ubuntu-2404-k8s-v20-1", vm_id = 9020, node_name = "pve-test", tags = [], status = "stopped", template = true },
        { name = "ubuntu-2404-k8s-v20-2", vm_id = 9021, node_name = "pve-test", tags = [], status = "stopped", template = true },
        { name = "ubuntu-2404-k8s-vlocal", vm_id = 9999, node_name = "pve-test", tags = [], status = "stopped", template = true },
      ]
    }
  }

  assert {
    condition     = toset(keys(output.nodes)) == toset(["cp-1", "workers-1", "workers-2"])
    error_message = "Only Proxmox pools create nodes; the byo pool is skipped."
  }

  assert {
    condition     = output.templates["ubuntu-2404"].name == "ubuntu-2404-k8s-v20-2"
    error_message = "The newest template by run and attempt must win over v3-1 and v20-1 and ignore non-CI names."
  }

  assert {
    condition     = output.clone_sources == { "cp-1" = 9021, "workers-1" = 9021, "workers-2" = 9021 }
    error_message = "Every Ubuntu node must be cloned from the selected template."
  }

  assert {
    condition     = data.proxmox_virtual_environment_vms.templates["ubuntu-2404"].tags == tolist(["packer", "ubuntu-2404", "k8s", "k8s-1-37"])
    error_message = "kubeadm pools must select k8s templates for the Kubernetes minor version."
  }

  assert {
    condition     = output.nodes["workers-2"].ssh_user == "ops" && output.nodes["workers-2"].private_ip == "203.0.113.42"
    error_message = "Ubuntu nodes get the SSH user and their own address."
  }

  assert {
    condition     = proxmox_virtual_environment_vm.node["workers-1"].initialization[0].user_account[0].username == "ops"
    error_message = "cloud-init must create the SSH user."
  }

  assert {
    condition     = length(proxmox_download_file.talos_iso) == 0 && output.talos_iso == null
    error_message = "No ISO is downloaded without Talos pools."
  }

  assert {
    condition     = alltrue([for k, vm in proxmox_virtual_environment_vm.node : length(vm.tpm_state) == 0])
    error_message = "Ubuntu VMs get no TPM."
  }
}

run "capi_is_skipped" {
  variables {
    spec      = merge(run.kubeadm_spec.spec, { mechanism = "capi" })
    addresses = {}
  }

  assert {
    condition     = length(output.nodes) == 0
    error_message = "Clusters created by Cluster API must not create VMs here."
  }
}

run "missing_template" {
  command = plan

  variables {
    spec      = run.kubeadm_spec.spec
    addresses = { cp = ["203.0.113.40"], workers = ["203.0.113.41", "203.0.113.42"] }
  }

  expect_failures = [proxmox_virtual_environment_vm.node]
}

run "missing_ssh" {
  command = plan

  variables {
    spec      = run.kubeadm_spec.spec
    addresses = { cp = ["203.0.113.40"], workers = ["203.0.113.41", "203.0.113.42"] }
    ssh       = null
  }

  override_data {
    target = data.proxmox_virtual_environment_vms.templates["ubuntu-2404"]
    values = {
      vms = [{ name = "ubuntu-2404-k8s-v20-1", vm_id = 9020, node_name = "pve-test", tags = [], status = "stopped", template = true }]
    }
  }

  expect_failures = [proxmox_virtual_environment_vm.node]
}

run "duplicate_addresses" {
  command = plan

  variables {
    spec      = run.kubeadm_spec.spec
    addresses = { cp = ["203.0.113.40"], workers = ["203.0.113.40", "203.0.113.42"] }
  }

  expect_failures = [var.addresses]
}
