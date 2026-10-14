# cluster-spec

Reads a cluster description, checks it against the compatibility matrix and returns a normalized
specification for provider modules, `talos-cluster` and `capi-cluster`. The module creates no resources.

```hcl
module "spec" {
  source = "git::https://github.com/sogeor/modules.git//modules/cluster-spec?ref=modules-v0.1.0"

  cluster = yamldecode(file("${path.root}/clusters/main.yaml"))
}
```

- Structure errors (types, names, `cluster_id`, versions) fail at the `cluster` variable.
- Compatibility errors are listed in `violations` (`{ rule, message }`); with `enforce = true` the plan fails
  on the `spec` output and prints every violation.
- Rules, the matrix and the normalized fields: [Configuration](../../docs/configuration.md#cluster-spec).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10.0 |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| cluster | Cluster description, usually yamldecode(file("clusters/NAME.yaml")). Fields: docs/configuration.md. | ```object({ cluster = string cluster_id = number distribution = string kubernetes_version = string topology = string profiles = optional(list(string), ["core"]) mechanism = optional(string) allow_experimental = optional(bool, false) control_plane_multisite = optional(object({ enabled = bool reason = optional(string, "") })) pools = map(object({ role = string os = string provider = string site = string size = string count = optional(number) autoscale = optional(object({ min = number max = number })) labels = optional(map(string), {}) taints = optional(list(string), []) custom_image_supported = optional(bool, false) })) })``` | n/a | yes |
| allow_planned_images | Accept (OS, provider) pairs whose image is only planned; they are reported in the warnings output instead of violations. | `bool` | `false` | no |
| enforce | Fail the plan when the description has violations. Set to false only to inspect the violations output. | `bool` | `true` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| matrix | Compatibility matrix used for validation: distributions, providers, image status per (OS, provider), sizes, profiles. |
| spec | Normalized cluster: derived mechanism, network CIDR, control plane summary, cluster labels and pools with resolved sizes. |
| violations | List of { rule, message } for every broken rule; empty for a valid description. |
| warnings | List of { rule, message } that do not block, such as planned images accepted with allow_planned_images. |
<!-- END_TF_DOCS -->
