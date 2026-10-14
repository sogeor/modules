variables {
  enforce = false
}

run "enforce_fails_plan" {
  command = plan

  variables {
    enforce = true
    cluster = {
      cluster = "bad", cluster_id = 5, distribution = "talos", kubernetes_version = "1.37.1", topology = "single"
      pools = {
        cp = { role = "control-plane", os = "ubuntu-2404", provider = "proxmox", site = "home", size = "m", count = 1 }
      }
    }
  }

  expect_failures = [output.spec]
}

run "default_mechanism" {
  command = plan

  variables {
    cluster = {
      cluster = "lab", cluster_id = 5, distribution = "kubeadm", kubernetes_version = "1.37.1", topology = "single"
      pools = {
        cp = { role = "control-plane", os = "ubuntu-2404", provider = "proxmox", site = "home", size = "m", count = 1 }
      }
    }
  }

  assert {
    condition     = length(output.violations) == 0 && output.spec.mechanism == "capi" && output.spec.profiles == tolist(["core"])
    error_message = "A minimal valid description must default to capi on proxmox and the core profile."
  }
}

run "os_distribution" {
  command = plan

  variables {
    cluster = {
      cluster = "bad", cluster_id = 5, distribution = "talos", kubernetes_version = "1.37.1", topology = "single"
      pools = {
        cp = { role = "control-plane", os = "ubuntu-2404", provider = "proxmox", site = "home", size = "m", count = 1 }
      }
    }
  }

  assert {
    condition     = contains([for v in output.violations : v.rule], "os-distribution")
    error_message = "ubuntu-2404 must be rejected for talos."
  }
}

run "unknown_values" {
  command = plan

  variables {
    cluster = {
      cluster = "bad", cluster_id = 5, distribution = "kubeadm", kubernetes_version = "1.37.1", topology = "single", profiles = ["core", "nope"]
      pools = {
        cp = { role = "control-plane", os = "debian-13", provider = "hetzner", site = "home", size = "huge", count = 1 }
      }
    }
  }

  assert {
    condition     = length(setsubtract(["unknown-profile", "unknown-os", "unknown-provider", "unknown-size"], [for v in output.violations : v.rule])) == 0
    error_message = "Unknown profile, os, provider and size must all be reported."
  }
}

run "image_unsupported" {
  command = plan

  variables {
    cluster = {
      cluster = "bad", cluster_id = 5, distribution = "kubeadm", kubernetes_version = "1.37.1", topology = "single"
      pools = {
        cp = { role = "control-plane", os = "astra-18", provider = "selectel", site = "selectel-ru-9", size = "m", count = 1 }
      }
    }
  }

  assert {
    condition     = contains([for v in output.violations : v.rule], "image-unsupported")
    error_message = "astra-18 on selectel must be rejected."
  }
}

run "image_planned_allowed" {
  command = plan

  variables {
    allow_planned_images = true
    cluster = {
      cluster = "lab", cluster_id = 5, distribution = "kubeadm", kubernetes_version = "1.37.1", topology = "single"
      pools = {
        cp = { role = "control-plane", os = "ubuntu-2604", provider = "proxmox", site = "home", size = "m", count = 1 }
      }
    }
  }

  assert {
    condition     = length(output.violations) == 0 && output.warnings[0].rule == "image-planned"
    error_message = "A planned image must become a warning when allowed."
  }
}

run "talos_byo_custom_image" {
  command = plan

  variables {
    cluster = {
      cluster = "bad", cluster_id = 5, distribution = "talos", kubernetes_version = "1.37.1", topology = "single"
      pools = {
        cp = { role = "control-plane", os = "talos", provider = "byo", site = "vds", size = "s", count = 1 }
      }
    }
  }

  assert {
    condition     = contains([for v in output.violations : v.rule], "talos-byo-custom-image")
    error_message = "talos on byo without custom_image_supported must be rejected."
  }
}

run "talos_byo_custom_image_allowed" {
  command = plan

  variables {
    cluster = {
      cluster = "lab", cluster_id = 5, distribution = "talos", kubernetes_version = "1.37.1", topology = "single"
      pools = {
        cp = { role = "control-plane", os = "talos", provider = "byo", site = "vds", size = "s", count = 1, custom_image_supported = true }
      }
    }
  }

  assert {
    condition     = length(output.violations) == 0
    error_message = "talos on byo with custom_image_supported must be valid."
  }
}

run "count_or_autoscale" {
  command = plan

  variables {
    cluster = {
      cluster = "bad", cluster_id = 5, distribution = "kubeadm", kubernetes_version = "1.37.1", topology = "single"
      pools = {
        cp      = { role = "control-plane", os = "ubuntu-2404", provider = "proxmox", site = "home", size = "m", count = 1 }
        workers = { role = "worker", os = "ubuntu-2404", provider = "proxmox", site = "home", size = "m" }
      }
    }
  }

  assert {
    condition     = contains([for v in output.violations : v.rule], "count-or-autoscale")
    error_message = "A pool without count and autoscale must be rejected."
  }
}

run "autoscale_bounds" {
  command = plan

  variables {
    cluster = {
      cluster = "bad", cluster_id = 5, distribution = "kubeadm", kubernetes_version = "1.37.1", topology = "single"
      pools = {
        cp      = { role = "control-plane", os = "ubuntu-2404", provider = "proxmox", site = "home", size = "m", count = 1 }
        workers = { role = "worker", os = "ubuntu-2404", provider = "proxmox", site = "home", size = "m", autoscale = { min = 3, max = 1 } }
      }
    }
  }

  assert {
    condition     = contains([for v in output.violations : v.rule], "autoscale-bounds")
    error_message = "min greater than max must be rejected."
  }
}

run "autoscale_mechanism" {
  command = plan

  variables {
    cluster = {
      cluster = "bad", cluster_id = 5, distribution = "kubeadm", kubernetes_version = "1.37.1", topology = "single", mechanism = "opentofu"
      pools = {
        cp      = { role = "control-plane", os = "ubuntu-2404", provider = "proxmox", site = "home", size = "m", count = 1 }
        workers = { role = "worker", os = "ubuntu-2404", provider = "proxmox", site = "home", size = "m", autoscale = { min = 0, max = 2 } }
      }
    }
  }

  assert {
    condition     = contains([for v in output.violations : v.rule], "autoscale-mechanism")
    error_message = "autoscale with opentofu must be rejected."
  }
}

run "control_plane_autoscale" {
  command = plan

  variables {
    cluster = {
      cluster = "bad", cluster_id = 5, distribution = "kubeadm", kubernetes_version = "1.37.1", topology = "single"
      pools = {
        cp = { role = "control-plane", os = "ubuntu-2404", provider = "proxmox", site = "home", size = "m", autoscale = { min = 1, max = 1 } }
      }
    }
  }

  assert {
    condition     = contains([for v in output.violations : v.rule], "control-plane-autoscale")
    error_message = "autoscale on a control-plane pool must be rejected."
  }
}

run "mechanism_provider" {
  command = plan

  variables {
    cluster = {
      cluster = "bad", cluster_id = 5, distribution = "kubeadm", kubernetes_version = "1.37.1", topology = "single", mechanism = "capi"
      pools = {
        cp = { role = "control-plane", os = "ubuntu-2404", provider = "byo", site = "vds", size = "m", count = 1 }
      }
    }
  }

  assert {
    condition     = contains([for v in output.violations : v.rule], "mechanism-provider")
    error_message = "capi on byo must be rejected."
  }
}

run "control_plane_missing" {
  command = plan

  variables {
    cluster = {
      cluster = "bad", cluster_id = 5, distribution = "kubeadm", kubernetes_version = "1.37.1", topology = "single"
      pools = {
        workers = { role = "worker", os = "ubuntu-2404", provider = "proxmox", site = "home", size = "m", count = 1 }
      }
    }
  }

  assert {
    condition     = contains([for v in output.violations : v.rule], "control-plane-missing")
    error_message = "A cluster without control plane must be rejected."
  }
}

run "single_control_plane_count" {
  command = plan

  variables {
    cluster = {
      cluster = "bad", cluster_id = 5, distribution = "kubeadm", kubernetes_version = "1.37.1", topology = "single"
      pools = {
        cp = { role = "control-plane", os = "ubuntu-2404", provider = "proxmox", site = "home", size = "m", count = 2 }
      }
    }
  }

  assert {
    condition     = contains([for v in output.violations : v.rule], "topology-control-plane")
    error_message = "single with 2 control-plane nodes must be rejected."
  }
}

run "ha_control_plane_even" {
  command = plan

  variables {
    cluster = {
      cluster = "bad", cluster_id = 5, distribution = "kubeadm", kubernetes_version = "1.37.1", topology = "ha"
      pools = {
        cp = { role = "control-plane", os = "ubuntu-2404", provider = "proxmox", site = "home", size = "m", count = 4 }
      }
    }
  }

  assert {
    condition     = contains([for v in output.violations : v.rule], "topology-control-plane")
    error_message = "ha with 4 control-plane nodes must be rejected."
  }
}

run "ha_control_plane_valid" {
  command = plan

  variables {
    cluster = {
      cluster = "lab", cluster_id = 5, distribution = "kubeadm", kubernetes_version = "1.37.1", topology = "ha"
      pools = {
        cp = { role = "control-plane", os = "ubuntu-2404", provider = "proxmox", site = "home", size = "m", count = 3 }
      }
    }
  }

  assert {
    condition     = length(output.violations) == 0 && output.spec.control_plane.workloads_allowed == false
    error_message = "ha with 3 control-plane nodes must be valid and keep workloads off the control plane."
  }
}

run "control_plane_multisite" {
  command = plan

  variables {
    cluster = {
      cluster = "bad", cluster_id = 5, distribution = "talos", kubernetes_version = "1.37.1", topology = "ha"
      pools = {
        home  = { role = "control-plane", os = "talos", provider = "proxmox", site = "home", size = "m", count = 1 }
        cloud = { role = "control-plane", os = "talos", provider = "selectel", site = "selectel-ru-9", size = "m", count = 2 }
      }
    }
  }

  assert {
    condition     = contains([for v in output.violations : v.rule], "control-plane-multisite")
    error_message = "Control plane on two sites without the flag must be rejected."
  }
}

run "control_plane_multisite_without_reason" {
  command = plan

  variables {
    cluster = {
      cluster                 = "bad", cluster_id = 5, distribution = "talos", kubernetes_version = "1.37.1", topology = "ha"
      control_plane_multisite = { enabled = true }
      pools = {
        home  = { role = "control-plane", os = "talos", provider = "proxmox", site = "home", size = "m", count = 1 }
        cloud = { role = "control-plane", os = "talos", provider = "selectel", site = "selectel-ru-9", size = "m", count = 2 }
      }
    }
  }

  assert {
    condition     = contains([for v in output.violations : v.rule], "control-plane-multisite")
    error_message = "The multisite flag without a reason must be rejected."
  }
}

run "control_plane_multisite_allowed" {
  command = plan

  variables {
    cluster = {
      cluster                 = "lab", cluster_id = 5, distribution = "talos", kubernetes_version = "1.37.1", topology = "ha"
      control_plane_multisite = { enabled = true, reason = "Measured latency below 10 ms." }
      pools = {
        home  = { role = "control-plane", os = "talos", provider = "proxmox", site = "home", size = "m", count = 1 }
        cloud = { role = "control-plane", os = "talos", provider = "selectel", site = "selectel-ru-9", size = "m", count = 2 }
      }
    }
  }

  assert {
    condition     = length(output.violations) == 0 && output.spec.control_plane.count == 3
    error_message = "Multisite with a reason must be valid."
  }
}

run "invalid_cluster_id" {
  command = plan

  variables {
    cluster = {
      cluster = "bad", cluster_id = 25, distribution = "kubeadm", kubernetes_version = "1.37.1", topology = "single"
      pools = {
        cp = { role = "control-plane", os = "ubuntu-2404", provider = "proxmox", site = "home", size = "m", count = 1 }
      }
    }
  }

  expect_failures = [var.cluster]
}

run "invalid_kubernetes_version" {
  command = plan

  variables {
    cluster = {
      cluster = "bad", cluster_id = 5, distribution = "kubeadm", kubernetes_version = "1.37", topology = "single"
      pools = {
        cp = { role = "control-plane", os = "ubuntu-2404", provider = "proxmox", site = "home", size = "m", count = 1 }
      }
    }
  }

  expect_failures = [var.cluster]
}
