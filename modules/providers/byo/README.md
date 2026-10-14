# providers/byo

Registers existing servers (bought VDS, bare metal) as the nodes of BYO pools and returns them in the normalized
node contract. Creates no resources: the servers already exist; Ansible configures them through
`ansible-inventory`.

- Hosts are listed per pool in node order; their number must equal the pool `count`.
- `private_ip` defaults to `public_ip`; `zone` defaults to the site.
- The SSH user comes from the host or the module default; Talos nodes have none.

```hcl
module "vds" {
  source = "git::https://github.com/sogeor/modules.git//modules/providers/byo?ref=modules-v0.1.0"

  spec     = module.spec.spec
  hosts    = { vds = [{ public_ip = "198.51.100.10" }] }
  ssh_user = "ops"
  domain   = "lab.example.com"
}
```

Options: [Configuration](../../../docs/configuration.md#providersbyo).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10.0 |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| domain | Domain for node FQDNs. | `string` | n/a | yes |
| hosts | Existing servers per BYO pool, in node order. private_ip defaults to public_ip; zone defaults to the site. | ```map(list(object({ public_ip = optional(string) private_ip = optional(string) ssh_user = optional(string) zone = optional(string) })))``` | n/a | yes |
| spec | Normalized cluster from the cluster-spec module (module.NAME.spec). | ```object({ cluster = string distribution = string pools = map(object({ role = string os = string provider = string site = string count = optional(number) labels = map(string) taints = list(string) mesh_required = bool })) })``` | n/a | yes |
| ssh_user | Default SSH user for the first connection, used when a host sets no ssh_user. Not used for Talos pools. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| nodes | Nodes in the normalized node contract, keyed by POOL-INDEX, for example vds-1. |
<!-- END_TF_DOCS -->
