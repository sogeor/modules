# ansible-inventory

Turns nodes in the normalized node contract (from any provider modules) into an Ansible inventory stored in the
OpenTofu state, read by the `cloud.terraform.terraform_provider` inventory plugin.

- Talos nodes are skipped (no SSH).
- Groups: `cluster_<name>`, `distribution_<d>`, `role_<role>`, `site_<site>`, `os_<os>`, `mesh`, `internet`
  (characters other than letters, digits and `_` become `_`).
- `ansible_host`: the private address at `home`; elsewhere the mesh address once known, otherwise the public
  address (first run only, listed in `bootstrap_hosts`).
- The `cluster_<name>` group carries `cluster_vars`.

```hcl
module "inventory" {
  source = "git::https://github.com/sogeor/modules.git//modules/ansible-inventory?ref=modules-v0.1.0"

  nodes          = merge(module.home.nodes, module.vds.nodes)
  mesh_addresses = {}
}
```

Options and the inventory plugin file: [Configuration](../../docs/configuration.md#ansible-inventory).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10.0 |
| ansible | = 1.5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| ansible | = 1.5.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [ansible_group.cluster](https://registry.terraform.io/providers/ansible/ansible/1.5.0/docs/resources/group) | resource |
| [ansible_host.node](https://registry.terraform.io/providers/ansible/ansible/1.5.0/docs/resources/host) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| nodes | Nodes in the normalized node contract from any provider modules, merged into one map. Talos nodes are skipped. | ```map(object({ name = string fqdn = string cluster = string distribution = string role = string pool = string provider = string site = string os = string private_ip = string public_ip = optional(string) ssh_user = optional(string) labels = map(string) taints = list(string) mesh_required = bool }))``` | n/a | yes |
| cluster_vars | Variables of the cluster_NAME group per cluster name, for example Kubernetes version and CIDR for the k8s roles. | `map(any)` | `{}` | no |
| mesh_addresses | Mesh (Tailscale) IPv4 address per node name, once the node has joined the mesh. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| bootstrap_hosts | Hosts outside home still reached by their public address; they must join the mesh before the internet hardening closes SSH. |
| groups | All group names with their hosts. |
| hosts | Inventory hosts: connection address, how it is reached (private, mesh or public) and groups. |
<!-- END_TF_DOCS -->
