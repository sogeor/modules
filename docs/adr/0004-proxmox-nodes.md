# 0004. Proxmox VE nodes: template clones and the Talos ISO

- Status: accepted
- Date: 2026-10-14

## Context and problem statement

The management cluster and home pools run on Proxmox VE and are created by OpenTofu. Ubuntu images come from
tagged templates of [images](https://github.com/sogeor/images); Talos images come from the Image Factory.
New templates appear monthly, and nodes must not be recreated just because a newer image exists.

## Considered options

- Talos: import the raw disk image as the system disk, or boot the nocloud ISO on an empty disk.
- Template selection: lexical sort of names, or a numeric sort by run and attempt.
- Updates: follow the newest template automatically, or only at creation.

## Decision outcome

- **Resources:** the stable `proxmox_virtual_environment_vm` and `proxmox_virtual_environment_vms`, and
  `proxmox_download_file`; the experimental `proxmox_vm` and `proxmox_cloned_vm` are not used.
- **Ubuntu:** full clone of the newest template whose name ends in `-v<run>-<attempt>`, sorted numerically
  (`v20-1` is newer than `v3-1`); kubeadm pools also require the `k8s-<major>-<minor>` tag.
- **Talos:** the VM boots the nocloud ISO (SHA-256 required) with the disk first in the boot order; Talos installs
  itself when the machine configuration is applied, which is the method documented for Proxmox by Sidero Labs.
- **Lifecycle:** `clone` and `cdrom` are ignored after creation; nodes move to newer images by an explicit
  replacement or `talosctl upgrade`.
- **Addresses:** static IPv4 through cloud-init, because the home network has no DHCP.

### Consequences

- Monthly template rebuilds never replace running nodes; replacement is a reviewed, per-node operation.
- `tofu test` mocks cannot show the `clone` block of a planned VM when `ignore_changes` covers it; tests check the
  selected template through the `clone_sources` output instead.
