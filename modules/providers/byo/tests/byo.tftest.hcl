variables {
  domain   = "lab.example.com"
  ssh_user = "ops"
}

run "spec" {
  module {
    source = "../../cluster-spec"
  }

  variables {
    cluster = {
      cluster = "edge", cluster_id = 10, distribution = "k3s", kubernetes_version = "1.37.1", topology = "single", mechanism = "opentofu"
      pools = {
        vds   = { role = "control-plane", os = "ubuntu-2404", provider = "byo", site = "vds-ams", size = "xs", count = 1 }
        extra = { role = "worker", os = "ubuntu-2404", provider = "byo", site = "vds-fra", size = "s", count = 2 }
      }
    }
  }
}

run "nodes" {
  variables {
    spec = run.spec.spec
    hosts = {
      vds   = [{ public_ip = "198.51.100.10", zone = "ams-1" }]
      extra = [{ public_ip = "198.51.100.20", private_ip = "10.0.0.20", ssh_user = "admin" }, { private_ip = "10.0.0.21" }]
    }
  }

  assert {
    condition     = toset(keys(output.nodes)) == toset(["vds-1", "extra-1", "extra-2"])
    error_message = "One node per listed host."
  }

  assert {
    condition     = output.nodes["vds-1"].name == "edge-vds-1" && output.nodes["vds-1"].fqdn == "edge-vds-1.lab.example.com" && output.nodes["vds-1"].provider == "byo"
    error_message = "Names and FQDNs follow the contract."
  }

  assert {
    condition     = output.nodes["vds-1"].private_ip == "198.51.100.10" && output.nodes["vds-1"].public_ip == "198.51.100.10"
    error_message = "private_ip defaults to public_ip."
  }

  assert {
    condition     = output.nodes["extra-2"].public_ip == null && output.nodes["extra-2"].private_ip == "10.0.0.21"
    error_message = "A host without a public address keeps public_ip null."
  }

  assert {
    condition     = output.nodes["vds-1"].ssh_user == "ops" && output.nodes["extra-1"].ssh_user == "admin"
    error_message = "The host ssh_user overrides the module default."
  }

  assert {
    condition     = output.nodes["vds-1"].labels["topology.kubernetes.io/zone"] == "ams-1" && output.nodes["extra-1"].labels["topology.kubernetes.io/zone"] == "vds-fra"
    error_message = "zone defaults to the site."
  }

  assert {
    condition     = output.nodes["vds-1"].mesh_required && output.nodes["extra-1"].role == "worker"
    error_message = "Sites other than home require the mesh."
  }
}

run "count_mismatch" {
  command = plan

  variables {
    spec  = run.spec.spec
    hosts = { vds = [{ public_ip = "198.51.100.10" }], extra = [{ public_ip = "198.51.100.20" }] }
  }

  expect_failures = [output.nodes]
}

run "unknown_pool" {
  command = plan

  variables {
    spec = run.spec.spec
    hosts = {
      vds   = [{ public_ip = "198.51.100.10" }]
      extra = [{ public_ip = "198.51.100.20" }, { public_ip = "198.51.100.21" }]
      other = [{ public_ip = "198.51.100.30" }]
    }
  }

  expect_failures = [output.nodes]
}

run "missing_ssh_user" {
  command = plan

  variables {
    spec     = run.spec.spec
    ssh_user = null
    hosts = {
      vds   = [{ public_ip = "198.51.100.10" }]
      extra = [{ public_ip = "198.51.100.20" }, { public_ip = "198.51.100.21" }]
    }
  }

  expect_failures = [output.nodes]
}

run "host_without_address" {
  command = plan

  variables {
    spec  = run.spec.spec
    hosts = { vds = [{ ssh_user = "ops" }] }
  }

  expect_failures = [var.hosts]
}

run "talos_spec" {
  module {
    source = "../../cluster-spec"
  }

  variables {
    cluster = {
      cluster = "edge", cluster_id = 10, distribution = "talos", kubernetes_version = "1.37.1", topology = "single", mechanism = "opentofu"
      pools = {
        vds = { role = "control-plane", os = "talos", provider = "byo", site = "vds-ams", size = "s", count = 1, custom_image_supported = true }
      }
    }
  }
}

run "talos_nodes" {
  variables {
    spec     = run.talos_spec.spec
    ssh_user = null
    hosts    = { vds = [{ public_ip = "198.51.100.10" }] }
  }

  assert {
    condition     = output.nodes["vds-1"].ssh_user == null && output.nodes["vds-1"].distribution == "talos"
    error_message = "Talos nodes need no SSH user."
  }
}
