mock_provider "openstack" {
  mock_data "openstack_networking_network_v2" {
    defaults = {
      id = "8e4f2c4a-0000-4000-8000-000000000001"
    }
  }
}

variables {
  external_network = "external-network"
  dns_nameservers  = ["198.51.100.53", "198.51.100.54"]

  spec = {
    cluster      = "main"
    distribution = "kubeadm"
    pools = {
      cp      = { provider = "selectel", size = "m", cpu = 2, memory_mb = 4096 }
      workers = { provider = "selectel", size = "l", cpu = 4, memory_mb = 8192 }
      extra   = { provider = "selectel", size = "l", cpu = 4, memory_mb = 8192 }
      home    = { provider = "proxmox", size = "xl", cpu = 8, memory_mb = 16384 }
    }
  }
}

run "flavors" {
  command = apply

  assert {
    condition     = toset(keys(openstack_compute_flavor_v2.size)) == toset(["m", "l"])
    error_message = "One flavor per size of the Selectel pools; other providers are ignored."
  }

  assert {
    condition     = openstack_compute_flavor_v2.size["l"].name == "sogeor-main-l" && openstack_compute_flavor_v2.size["l"].vcpus == 4 && openstack_compute_flavor_v2.size["l"].ram == 8192
    error_message = "Flavors follow the size catalog."
  }

  assert {
    condition     = alltrue([for f in values(openstack_compute_flavor_v2.size) : f.disk == 0 && !f.is_public])
    error_message = "Flavors are private and boot from a volume."
  }

  assert {
    condition     = output.external_network.id == "8e4f2c4a-0000-4000-8000-000000000001" && output.ssh_key_name == null
    error_message = "The external network is resolved; no key pair without a key."
  }

  assert {
    condition     = output.capi_openstack.flavors == output.flavors && output.capi_openstack.volume_type == null && output.capi_openstack.external_network == "external-network"
    error_message = "capi_openstack carries the values for capi-cluster."
  }
}

run "existing_flavor" {
  command = apply

  variables {
    existing_flavors = { l = "SL1.4-8192", xs = "SL1.1-1024" }
  }

  assert {
    condition     = keys(openstack_compute_flavor_v2.size) == ["m"] && output.flavors == { m = "sogeor-main-m", l = "SL1.4-8192" }
    error_message = "Existing flavors replace created ones; unused sizes are dropped."
  }
}

run "key_pair" {
  command = apply

  variables {
    ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKeyOnlyForTests ops@example.com"
  }

  assert {
    condition     = output.ssh_key_name == "main-admin" && output.capi_openstack.ssh_key_name == "main-admin"
    error_message = "The key pair is named after the cluster."
  }
}

run "talos_with_key" {
  command = plan

  variables {
    spec = {
      cluster      = "talos"
      distribution = "talos"
      pools        = { cp = { provider = "selectel", size = "m", cpu = 2, memory_mb = 4096 } }
    }
    ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKeyOnlyForTests ops@example.com"
  }

  expect_failures = [openstack_compute_keypair_v2.admin]
}

run "no_selectel_pools" {
  command = plan

  variables {
    spec = {
      cluster      = "home"
      distribution = "talos"
      pools        = { cp = { provider = "proxmox", size = "m", cpu = 2, memory_mb = 4096 } }
    }
  }

  expect_failures = [var.spec]
}

run "bad_dns" {
  command = plan

  variables {
    dns_nameservers = ["dns.example.com"]
  }

  expect_failures = [var.dns_nameservers]
}

run "bad_size_key" {
  command = plan

  variables {
    existing_flavors = { huge = "SL1.16-65536" }
  }

  expect_failures = [var.existing_flavors]
}

run "bad_key" {
  command = plan

  variables {
    ssh_public_key = "CHANGE_ME"
  }

  expect_failures = [var.ssh_public_key]
}

run "chain" {
  command = apply

  module {
    source = "./tests/chain"
  }

  variables {
    cluster = yamldecode(file("../../../clusters/main.yaml"))
  }

  assert {
    condition     = output.flavors == { m = "sogeor-main-m", l = "SL1.4-8192" }
    error_message = "Flavors for clusters/main.yaml."
  }

  assert {
    condition     = output.objects[1].kind == "OpenStackCluster" && output.objects[1].spec.externalNetwork.filter.name == "external-network"
    error_message = "capi-cluster takes the external network from providers/selectel."
  }

  assert {
    condition     = output.objects[4].spec.template.spec.flavor.filter.name == "SL1.4-8192" && output.objects[4].spec.template.spec.rootVolume.type == "fast.zone-a" && output.objects[4].spec.template.spec.sshKeyName == "main-admin"
    error_message = "Machine templates use the flavors, volume type and key pair from providers/selectel."
  }
}
