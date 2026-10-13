# Configuration

Every option of the repository. Each module adds its inputs and outputs to this page in the same
change that adds the module.

## Cluster description

The input of the constructor. The schema and validations arrive with `cluster-spec`; the fields below
are the agreed contract.

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
| `pools.<name>.role` | `control-plane` \| `worker` | — | yes | Pool role | `worker` |
| `pools.<name>.os` | `ubuntu-2404` \| `ubuntu-2604` \| `astra-18` \| `alpine` \| `talos` | — | yes | OS of the pool | `ubuntu-2404` |
| `pools.<name>.provider` | `proxmox` \| `selectel` \| `byo` (others later) | — | yes | Where nodes run | `selectel` |
| `pools.<name>.site` | string | — | yes | Site (`home`, `<cloud>-<region>`) | `selectel-ru-9` |
| `pools.<name>.size` | `xs` \| `s` \| `m` \| `l` \| `xl` \| `2xl` | — | yes | Node size | `m` |
| `pools.<name>.count` | integer | — | one of `count`, `autoscale` | Fixed number of nodes | `1` |
| `pools.<name>.autoscale` | `{min, max}` | — | one of `count`, `autoscale` | Cluster Autoscaler bounds; `max` always required | `{ min: 0, max: 3 }` |
| `pools.<name>.labels` | map of strings | `{}` | no | Node labels | `{}` |
| `pools.<name>.taints` | list of strings | `[]` | no | Node taints | `[]` |

Sizes:

| Size | vCPU | RAM | Disk |
|---|---|---|---|
| `xs` | 1 | 1 GB | 20 GB |
| `s` | 2 | 2 GB | 30 GB |
| `m` | 2 | 4 GB | 40 GB |
| `l` | 4 | 8 GB | 80 GB |
| `xl` | 8 | 16 GB | 160 GB |
| `2xl` | 8 | 32 GB | 200 GB |

## Module inputs and outputs

No modules are released yet. Each module documents every input here as a table
«name | type | default | required | description | example», plus the generated reference.

## CI

| Workflow | Trigger | Inputs | Secrets |
|---|---|---|---|
| `validate` | pull request, push to `master`, manual | — | — |
| `docs` | pull request, push to `master`, manual | — | — |
| `scorecard` | weekly, push to `master`, ruleset change | — | `SCORECARD_TOKEN` (repository secret, fine-grained PAT, Administration: read-only) |

Tool versions pinned in `validate.yml`:

| Variable | Description |
|---|---|
| `ACTIONLINT_VERSION` | actionlint release |
| `ACTIONLINT_SHA256` | SHA-256 of the actionlint archive; update together with the version |

The repository uses no Environments and no infrastructure credentials.
