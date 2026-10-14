data "proxmox_virtual_environment_vms" "templates" {
  for_each = local.template_tags

  node_name = var.proxmox.node_name
  tags      = each.value

  filter {
    name   = "template"
    values = [true]
  }
}

locals {
  template_candidates = { for os, d in data.proxmox_virtual_environment_vms.templates : os => {
    for vm in d.vms : format("%010d-%05d",
      tonumber(regex("-v([0-9]+)-([0-9]+)$", vm.name)[0]),
      tonumber(regex("-v([0-9]+)-([0-9]+)$", vm.name)[1]),
    ) => vm if can(regex("-v([0-9]+)-([0-9]+)$", vm.name))
  } }

  templates = { for os, c in local.template_candidates : os => try(c[reverse(sort(keys(c)))[0]], null) }

  talos = coalesce(var.talos, { version = "v0.0.0", schematic_id = "0000000000000000", iso_sha256 = "" })
}

resource "proxmox_download_file" "talos_iso" {
  count = length(local.talos_pools) > 0 ? 1 : 0

  node_name          = var.proxmox.node_name
  datastore_id       = coalesce(var.proxmox.iso_datastore_id, "local")
  content_type       = "iso"
  url                = "${var.image_factory_url}/image/${local.talos.schematic_id}/${local.talos.version}/nocloud-amd64.iso"
  file_name          = "talos-${local.talos.version}-${substr(local.talos.schematic_id, 0, 12)}-nocloud-amd64.iso"
  checksum           = local.talos.iso_sha256
  checksum_algorithm = "sha256"
  overwrite          = false

  lifecycle {
    precondition {
      condition     = var.talos != null
      error_message = "Talos pools exist, so the talos input (version, schematic_id, iso_sha256) is required."
    }
  }
}
