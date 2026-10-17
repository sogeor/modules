# providers/selectel

Prepares a Selectel project for Cluster API (CAPO) clusters and returns the values of the `openstack` input of
`capi-cluster`. Creates no nodes: Cluster API creates the servers, networks and security groups.

- Private flavors `PREFIX-CLUSTER-SIZE` for the sizes of the Selectel pools (vCPU and RAM from the size catalog,
  disk 0: the root disk is a volume); `existing_flavors` uses existing flavors instead.
- The external network is resolved at plan time.
- An optional break-glass key pair for kubeadm nodes; Talos clusters have none.

```hcl
module "selectel" {
  source = "git::https://github.com/sogeor/modules.git//modules/providers/selectel?ref=modules-v0.1.0"

  spec             = module.spec.spec
  external_network = "external-network"
  dns_nameservers  = ["198.51.100.53"]
}

module "capi" {
  source = "git::https://github.com/sogeor/modules.git//modules/capi-cluster?ref=modules-v0.1.0"

  spec      = module.spec.spec
  images    = { builds = { ubuntu-2404 = "v20-1" } }
  openstack = merge(module.selectel.capi_openstack, { identity_secret = "capo" })
}
```

Options: [Configuration](../../../docs/configuration.md#providersselectel).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10.0 |
| openstack | = 3.4.0 |

## Providers

| Name | Version |
| ---- | ------- |
| openstack | = 3.4.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [openstack_compute_flavor_v2.size](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/3.4.0/docs/resources/compute_flavor_v2) | resource |
| [openstack_compute_keypair_v2.admin](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/3.4.0/docs/resources/compute_keypair_v2) | resource |
| [openstack_networking_network_v2.external](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/3.4.0/docs/data-sources/networking_network_v2) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| dns_nameservers | IPv4 DNS resolvers for the node subnet created by CAPO. | `list(string)` | n/a | yes |
| external_network | Name of the external (internet) network of the region; checked at plan time. | `string` | n/a | yes |
| spec | Normalized cluster from the cluster-spec module (module.NAME.spec). Only pools with provider selectel are used. | ```object({ cluster = string distribution = string pools = map(object({ provider = string size = string cpu = number memory_mb = number })) })``` | n/a | yes |
| existing_flavors | Existing flavor name per size, used instead of creating a private flavor (for example a fixed Selectel configuration). | `map(string)` | `{}` | no |
| flavor_prefix | Prefix of created flavor names: PREFIX-CLUSTER-SIZE. | `string` | `"sogeor"` | no |
| ssh_public_key | OpenSSH public key for the break-glass key pair of kubeadm nodes. Not allowed for Talos clusters. | `string` | `null` | no |
| volume_type | Volume type of the root volumes, for example a fast SSD type of the pool zone. null keeps the project default. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| capi_openstack | Values for the openstack input of capi-cluster; merge identity_secret and other settings into it. |
| external_network | External network: id and name. |
| flavors | Flavor name per size used by the Selectel pools. |
| ssh_key_name | Name of the break-glass key pair, or null. |
<!-- END_TF_DOCS -->
