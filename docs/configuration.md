# Configuration

Every option of the repository. Each module adds its inputs and outputs to this page in the same
change that adds the module.

## Cluster description

The input of the constructor: one YAML file per cluster in `clusters/`. Structure is defined by
`schemas/cluster.schema.json`;
compatibility is checked by [`cluster-spec`](#cluster-spec) and the [Conftest policies](#conftest-policies).

| Field | Type | Default | Required | Description | Example |
|---|---|---|---|---|---|
| `cluster` | string | — | yes | Unique cluster name | `main` |
| `cluster_id` | integer 1–24 | — | yes | Defines Pod `10.{10N}.0.0/16` and Service `10.{10N+1}.0.0/16` CIDR | `2` |
| `distribution` | `talos` \| `kubeadm` \| `k3s` | — | yes | Kubernetes distribution of the whole cluster | `kubeadm` |
| `kubernetes_version` | string | — | yes | Kubernetes version | `"1.37.1"` |
| `topology` | `single` \| `ha` | — | yes | One control plane node or three | `single` |
| `profiles` | list of strings | `[core]` | no | Component profiles installed by `platform` | `[core, data]` |
| `mechanism` | `capi` \| `opentofu` | by control plane provider | no | How nodes are created | `capi` |
| `allow_experimental` | bool | `false` | no | Allows experimental OS (Alpine) | `false` |
| `control_plane_multisite.enabled` | bool | `false` | no | Allows control-plane pools on different sites | `true` |
| `control_plane_multisite.reason` | string | — | when `enabled: true` | Why the sites qualify (measured latency below 10 ms) | `"Latency below 10 ms"` |
| `pools.<name>.role` | `control-plane` \| `worker` | — | yes | Pool role | `worker` |
| `pools.<name>.os` | `ubuntu-2404` \| `ubuntu-2604` \| `astra-18` \| `alpine` \| `talos` | — | yes | OS of the pool | `ubuntu-2404` |
| `pools.<name>.provider` | `proxmox` \| `selectel` \| `byo` (others later) | — | yes | Where nodes run | `selectel` |
| `pools.<name>.site` | string | — | yes | Site (`home`, `<cloud>-<region>`) | `selectel-ru-9` |
| `pools.<name>.size` | `xs` \| `s` \| `m` \| `l` \| `xl` \| `2xl` | — | yes | Node size | `m` |
| `pools.<name>.count` | integer | — | one of `count`, `autoscale` | Fixed number of nodes | `1` |
| `pools.<name>.autoscale` | `{min, max}` | — | one of `count`, `autoscale` | Cluster Autoscaler bounds; `max` always required | `{ min: 0, max: 3 }` |
| `pools.<name>.labels` | map of strings | `{}` | no | Node labels | `{}` |
| `pools.<name>.taints` | list of strings | `[]` | no | Node taints | `[]` |
| `pools.<name>.custom_image_supported` | bool | `false` | for `os: talos` on `provider: byo` | The host accepts a custom OS image | `true` |

Names (`cluster` and pool keys) are 2–32 lowercase letters, digits or hyphens, start with a letter and do not
end with a hyphen. Unknown fields are rejected by the schema.

Sizes:

| Size | vCPU | RAM | Disk |
|---|---|---|---|
| `xs` | 1 | 1 GB | 20 GB |
| `s` | 2 | 2 GB | 30 GB |
| `m` | 2 | 4 GB | 40 GB |
| `l` | 4 | 8 GB | 80 GB |
| `xl` | 8 | 16 GB | 160 GB |
| `2xl` | 8 | 32 GB | 200 GB |

## cluster-spec

Source: `modules/cluster-spec`. Generated reference: `modules/cluster-spec/README.md`.

### Inputs

| Name | Type | Default | Required | Description | Example |
|---|---|---|---|---|---|
| `cluster` | object (the [cluster description](#cluster-description)) | — | yes | Usually `yamldecode(file("clusters/<name>.yaml"))` | `yamldecode(file("${path.root}/clusters/main.yaml"))` |
| `allow_planned_images` | bool | `false` | no | Report pairs with a planned image as warnings instead of violations | `true` |
| `enforce` | bool | `true` | no | Fail the plan on violations; `false` only to inspect `violations` | `false` |

### Outputs

| Name | Description |
|---|---|
| `spec` | Normalized cluster (below); the plan fails here when `enforce = true` and there are violations |
| `violations` | List of `{ rule, message }` |
| `warnings` | List of `{ rule, message }` that do not block |
| `matrix` | The compatibility matrix |

Fields of `spec`:

| Field | Description |
|---|---|
| `cluster`, `cluster_id`, `distribution`, `kubernetes_version`, `topology`, `profiles` | From the description; `profiles` defaults to `[core]` |
| `mechanism` | From the description, otherwise the default of the control-plane provider |
| `network.pod_cidr`, `network.service_cidr` | `10.{10N}.0.0/16` and `10.{10N+1}.0.0/16` for `cluster_id = N` |
| `control_plane.count`, `.sites`, `.provider` | Control-plane totals; the provider is taken from the first control-plane pool by name |
| `control_plane.workloads_allowed` | `true` for `single` |
| `labels` | `sogeor.com/cluster`, `sogeor.com/distribution`, `sogeor.com/topology`, `sogeor.com/profile-<name>: "true"` |
| `pools.<name>` | Pool fields plus `cpu`, `memory_mb`, `disk_gb` from the size, `image_status`, `mesh_required` (`site != home`), label `sogeor.com/pool` |

### Rules

Every rule has the same id in `cluster-spec` and in Conftest.

| Rule | Fails when |
|---|---|
| `unknown-profile`, `unknown-os`, `unknown-provider`, `unknown-size` | A value is not in the matrix |
| `os-distribution` | The pool OS is not allowed for the distribution |
| `image-unsupported` | No image exists or is planned for the (OS, provider) pair, for example `astra-18` on `selectel` |
| `image-planned` | The image is only planned (a warning with `allow_planned_images`, always a warning in Conftest) |
| `experimental-os` | An experimental OS without `allow_experimental: true` |
| `talos-byo-custom-image` | `talos` on `byo` without `custom_image_supported: true` |
| `count-or-autoscale` | A pool has both or neither of `count` and `autoscale` |
| `autoscale-bounds` | Not `0 <= min <= max`, or `max < 1` |
| `autoscale-mechanism` | `autoscale` without mechanism `capi` |
| `control-plane-autoscale` | A control-plane pool uses `autoscale` |
| `mechanism-provider` | A pool provider does not support the mechanism |
| `control-plane-missing` | No control-plane pool |
| `topology-control-plane` | `single` with other than 1 control-plane node; `ha` with fewer than 3 or an even number |
| `control-plane-multisite` | Control-plane pools on several sites without `control_plane_multisite`, or without its reason |

### Compatibility matrix

Source: `modules/cluster-spec/matrix.yaml`, read by the module and by Conftest. The schema enums are checked
against it in CI (`tools/check-schema.sh`).

| OS | proxmox | selectel | vkcloud | yandex | timeweb | byo |
|---|---|---|---|---|---|---|
| `talos` | available | available | available | available | available | available |
| `ubuntu-2404` | available | planned | planned | planned | — | available |
| `ubuntu-2604` | planned | planned | planned | planned | — | available |
| `astra-18` | planned | — | — | — | — | available |
| `alpine` (experimental) | planned | planned | planned | — | — | available |

| Provider | Mechanisms | Default |
|---|---|---|
| `proxmox` | opentofu, capi | capi |
| `selectel`, `vkcloud` | capi | capi |
| `yandex` | capi, opentofu | capi |
| `timeweb`, `byo` | opentofu | opentofu |

When [images](https://github.com/sogeor/images) publishes a new image, change its status to `available` in the
same pull request that updates the image contract.

## Conftest policies

Source: `policies/conftest/cluster`. Data: `modules/cluster-spec/matrix.yaml`.

```bash
conftest test --policy policies/conftest/cluster --data modules/cluster-spec/matrix.yaml clusters/
```

`deny` results fail; `warn` results (planned images) are printed only.

## CI

| Workflow | Trigger | Inputs | Secrets |
|---|---|---|---|
| `validate` | pull request, push to `master`, manual | — | — |
| `docs` | pull request, push to `master`, manual | — | — |
| `scorecard` | weekly, push to `master`, ruleset change | — | `SCORECARD_TOKEN` (repository secret, fine-grained PAT, Administration: read-only) |

Jobs of `validate`: `linters`, `opentofu` (`tools/check-modules.sh`), `policies` (schema and Conftest),
`security / *` (reusable `security-lite`).

Tool versions and SHA-256 checksums:

| Where | Variable | Description |
|---|---|---|
| `validate.yml` | `ACTIONLINT_VERSION`, `ACTIONLINT_SHA256` | actionlint release and archive checksum |
| `tools/install-tools.sh` | `TOFU_VERSION`, `TOFU_SHA256` | OpenTofu, `linux_amd64.tar.gz` |
| `tools/install-tools.sh` | `TFLINT_VERSION`, `TFLINT_SHA256` | tflint, `linux_amd64.zip` |
| `tools/install-tools.sh` | `CONFTEST_VERSION`, `CONFTEST_SHA256` | Conftest, `Linux_x86_64.tar.gz` |
| `tools/install-tools.sh` | `TFDOCS_VERSION`, `TFDOCS_SHA256` | terraform-docs, `linux-amd64.tar.gz` |

Update a version and its checksum together; the checksum comes from the release checksum file.

The repository uses no Environments and no infrastructure credentials.
