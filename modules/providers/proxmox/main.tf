resource "proxmox_virtual_environment_vm" "node" {
  for_each = local.nodes

  name        = each.value.name
  description = "sogeor cluster ${var.spec.cluster}, pool ${each.value.pool}, ${each.value.pool_spec.os}; managed by OpenTofu"
  tags        = local.vm_tags[each.key]
  node_name   = var.proxmox.node_name

  machine         = "q35"
  bios            = "ovmf"
  scsi_hardware   = "virtio-scsi-single"
  on_boot         = true
  started         = true
  stop_on_destroy = true
  boot_order      = each.value.talos ? ["scsi0", "ide0"] : ["scsi0"]

  # Clone and ISO only matter at creation; newer templates must not recreate nodes.
  dynamic "clone" {
    for_each = [for t in [try(local.templates[each.value.pool_spec.os], null)] : t if !each.value.talos && t != null]
    content {
      vm_id        = clone.value.vm_id
      node_name    = clone.value.node_name
      datastore_id = var.proxmox.datastore_id
      full         = true
      retries      = 3
    }
  }

  agent {
    enabled = true
    wait_for_ip {
      disabled = true
    }
  }

  cpu {
    cores = each.value.pool_spec.cpu
    type  = var.proxmox.cpu_type
  }

  memory {
    dedicated = each.value.pool_spec.memory_mb
    floating  = 0
  }

  efi_disk {
    datastore_id = var.proxmox.datastore_id
    type         = "4m"
  }

  disk {
    datastore_id = var.proxmox.datastore_id
    interface    = "scsi0"
    size         = each.value.pool_spec.disk_gb
    file_format  = "raw"
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  dynamic "cdrom" {
    for_each = each.value.talos ? [proxmox_download_file.talos_iso[0].id] : []
    content {
      file_id   = cdrom.value
      interface = "ide0"
    }
  }

  network_device {
    bridge  = var.proxmox.bridge
    vlan_id = var.proxmox.vlan_id
    model   = "virtio"
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = coalesce(var.proxmox.cloud_init_datastore_id, var.proxmox.datastore_id)
    interface    = each.value.talos ? "ide2" : null

    dns {
      domain  = var.network.domain
      servers = var.network.dns_servers
    }

    ip_config {
      ipv4 {
        address = "${each.value.private_ip}/${var.network.prefix_length}"
        gateway = var.network.gateway
      }
    }

    dynamic "user_account" {
      for_each = [for s in [var.ssh] : s if !each.value.talos && s != null]
      content {
        username = user_account.value.user
        keys     = user_account.value.public_keys
      }
    }
  }

  lifecycle {
    ignore_changes = [clone, cdrom]

    precondition {
      condition     = each.value.private_ip != null
      error_message = "No address for ${each.value.name}: add one to addresses[\"${each.value.pool}\"]."
    }

    precondition {
      condition     = each.value.talos || var.ssh != null
      error_message = "Pool ${each.value.pool} is not Talos, so the ssh input (user, public_keys) is required."
    }

    precondition {
      condition     = each.value.talos || try(local.templates[each.value.pool_spec.os] != null, false)
      error_message = "No template on node ${var.proxmox.node_name} has the tags ${join(";", try(local.template_tags[each.value.pool_spec.os], []))} and a name ending in -v<run>-<attempt>."
    }
  }
}
