mock_provider "ansible" {}

mock_provider "proxmox" {
  mock_data "proxmox_virtual_environment_vms" {
    defaults = {
      vms = []
    }
  }

  mock_resource "proxmox_virtual_environment_vm" {
    defaults = {
      vm_id = 100
    }
  }
}

run "proxmox_and_byo" {
  module {
    source = "./tests/chain"
  }

  override_data {
    target = module.home.data.proxmox_virtual_environment_vms.templates["ubuntu-2404"]
    values = {
      vms = [{ name = "ubuntu-2404-k8s-v20-1", vm_id = 9020, node_name = "pve-test", tags = [], status = "stopped", template = true }]
    }
  }

  assert {
    condition     = output.hosts["lab-cp-1"].connection == "private" && output.hosts["lab-vds-1"].connection == "public"
    error_message = "Nodes from proxmox and byo merge into one inventory."
  }

  assert {
    condition     = contains(output.hosts["lab-vds-1"].groups, "internet") && contains(output.hosts["lab-cp-1"].groups, "role_control_plane")
    error_message = "Groups are computed for nodes of both providers."
  }
}
