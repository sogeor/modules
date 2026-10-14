run "mgmt" {
  command = plan

  variables {
    cluster = yamldecode(file("../../clusters/mgmt.yaml"))
  }

  assert {
    condition     = length(output.violations) == 0 && length(output.warnings) == 0
    error_message = "mgmt must be valid without planned images."
  }

  assert {
    condition     = output.spec.mechanism == "opentofu" && output.spec.control_plane.workloads_allowed
    error_message = "mgmt must use opentofu and allow workloads on the single control plane."
  }

  assert {
    condition     = output.spec.network.pod_cidr == "10.10.0.0/16" && output.spec.network.service_cidr == "10.11.0.0/16"
    error_message = "mgmt CIDR must follow cluster_id 1."
  }
}

run "main" {
  command = plan

  variables {
    cluster              = yamldecode(file("../../clusters/main.yaml"))
    allow_planned_images = true
  }

  assert {
    condition     = length(output.violations) == 0
    error_message = "main must be valid when planned images are allowed."
  }

  assert {
    condition     = toset([for w in output.warnings : w.rule]) == toset(["image-planned"]) && length(output.warnings) == 3
    error_message = "main must report the three pools with planned images as warnings."
  }

  assert {
    condition     = output.spec.network.pod_cidr == "10.20.0.0/16" && output.spec.network.service_cidr == "10.21.0.0/16"
    error_message = "main CIDR must follow cluster_id 2."
  }

  assert {
    condition     = output.spec.pools.workers.cpu == 4 && output.spec.pools.workers.memory_mb == 8192 && output.spec.pools.workers.disk_gb == 80
    error_message = "Size l must resolve to 4 vCPU, 8192 MB, 80 GB."
  }

  assert {
    condition     = output.spec.pools.astra.mesh_required == false && output.spec.pools.workers.mesh_required == true
    error_message = "mesh_required must be true outside home."
  }
}

run "main_strict" {
  command = plan

  variables {
    cluster = yamldecode(file("../../clusters/main.yaml"))
    enforce = false
  }

  assert {
    condition     = length([for v in output.violations : v if v.rule == "image-planned"]) == 3
    error_message = "Without allow_planned_images the planned images of main must be violations."
  }
}

run "talos" {
  command = plan

  variables {
    cluster = yamldecode(file("../../clusters/talos.yaml"))
  }

  assert {
    condition     = length(output.violations) == 0
    error_message = "talos must be valid."
  }

  assert {
    condition     = output.spec.labels["sogeor.com/profile-data"] == "true" && output.spec.labels["sogeor.com/cluster"] == "talos"
    error_message = "Cluster labels must include the name and profiles."
  }
}
