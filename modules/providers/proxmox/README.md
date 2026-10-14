# providers/proxmox

Creates Proxmox VE virtual machines for the Proxmox pools of a cluster created by OpenTofu
(`mechanism: opentofu`) and returns them in the normalized node contract.

- **Ubuntu pools:** full clone of the newest template from [images](https://github.com/sogeor/images), selected
  by tags `packer;<os>;<kind>` (`k8s` with `k8s-<major>-<minor>` for kubeadm, `base` otherwise) and the build
  number in the name.
- **Talos pools:** the VM boots the Image Factory nocloud ISO (checked by SHA-256) on an empty disk; Talos is
  installed when `talos-cluster` applies the machine configuration.
- Static IPv4 addresses, DNS and (for Ubuntu) the SSH user are set through cloud-init.
- A newer template or Talos version does not recreate existing VMs.
- Pools of other providers and clusters with `mechanism: capi` are skipped.

```hcl
module "nodes" {
  source = "git::https://github.com/sogeor/modules.git//modules/providers/proxmox?ref=modules-v0.1.0"

  spec      = module.spec.spec
  proxmox   = { node_name = "pve", datastore_id = "local-lvm", bridge = "vmbr0" }
  network   = { prefix_length = 24, gateway = "203.0.113.1", dns_servers = ["203.0.113.1"], domain = "lab.example.com" }
  addresses = { cp = ["203.0.113.31"] }
  talos     = { version = "v1.14.2", schematic_id = "CHANGE_ME", iso_sha256 = "CHANGE_ME" }
}
```

Options, the API token privileges and examples: [Configuration](../../../docs/configuration.md#providersproxmox).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10.0 |
| proxmox | = 0.116.0 |

## Providers

| Name | Version |
| ---- | ------- |
| proxmox | = 0.116.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [proxmox_download_file.talos_iso](https://registry.terraform.io/providers/bpg/proxmox/0.116.0/docs/resources/download_file) | resource |
| [proxmox_virtual_environment_vm.node](https://registry.terraform.io/providers/bpg/proxmox/0.116.0/docs/resources/virtual_environment_vm) | resource |
| [proxmox_virtual_environment_vms.templates](https://registry.terraform.io/providers/bpg/proxmox/0.116.0/docs/data-sources/virtual_environment_vms) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| addresses | IPv4 addresses per pool, without prefix; node N of a pool gets element N-1. | `map(list(string))` | n/a | yes |
| network | IPv4 settings shared by all nodes: prefix length, gateway, DNS servers and the domain for FQDNs and DNS search. | ```object({ prefix_length = number gateway = string dns_servers = list(string) domain = string })``` | n/a | yes |
| proxmox | Proxmox VE placement: node, datastores and bridge. | ```object({ node_name = string datastore_id = string iso_datastore_id = optional(string) cloud_init_datastore_id = optional(string) bridge = string vlan_id = optional(number) cpu_type = optional(string, "host") })``` | n/a | yes |
| spec | Normalized cluster from the cluster-spec module (module.NAME.spec). | ```object({ cluster = string distribution = string kubernetes_version = string mechanism = string pools = map(object({ role = string os = string provider = string site = string size = string cpu = number memory_mb = number disk_gb = number count = optional(number) labels = map(string) taints = list(string) mesh_required = bool })) })``` | n/a | yes |
| image_factory_url | Base URL of the Talos Image Factory. | `string` | `"https://factory.talos.dev"` | no |
| ssh | Cloud-init user and public keys for pools other than Talos. Required when such pools exist. | ```object({ user = string public_keys = list(string) })``` | `null` | no |
| tags | Extra Proxmox tags added to every VM. | `list(string)` | `[]` | no |
| talos | Talos Image Factory schematic, version and SHA-256 of the nocloud ISO. Required when Talos pools exist. | ```object({ version = string schematic_id = string iso_sha256 = string })``` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| clone_sources | Template VM ID each Ubuntu node is cloned from when created, keyed like nodes. |
| nodes | Nodes in the normalized node contract, keyed by POOL-INDEX, for example cp-1. |
| talos_iso | Proxmox file ID of the Talos ISO, or null when there are no Talos pools. |
| templates | Selected template per OS: name, vm_id and node. |
<!-- END_TF_DOCS -->
