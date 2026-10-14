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

## providers/proxmox

Source: `modules/providers/proxmox`. Generated reference: `modules/providers/proxmox/README.md`.
Provider: `bpg/proxmox` 0.116.0, configured by the caller.

The module acts only when `spec.mechanism` is `opentofu` and only on pools with `provider: proxmox`; for other
clusters it returns no nodes.

### Inputs

| Name | Type | Default | Required | Description | Example |
|---|---|---|---|---|---|
| `spec` | object | — | yes | `module.<name>.spec` of `cluster-spec` | `module.spec.spec` |
| `proxmox.node_name` | string | — | yes | Proxmox VE node that runs the VMs | `pve` |
| `proxmox.datastore_id` | string | — | yes | Datastore for system, EFI and cloud-init disks | `local-lvm` |
| `proxmox.iso_datastore_id` | string | `local` | no | Datastore with `iso` content for the Talos ISO | `local` |
| `proxmox.cloud_init_datastore_id` | string | `proxmox.datastore_id` | no | Datastore for the cloud-init drive | `local-lvm` |
| `proxmox.bridge` | string | — | yes | Network bridge | `vmbr0` |
| `proxmox.vlan_id` | number 1–4094 | none | no | VLAN tag | `30` |
| `proxmox.cpu_type` | string | `host` | no | QEMU CPU type | `x86-64-v2-AES` |
| `proxmox.tpm` | bool | `true` | no | Add a TPM 2.0 to Talos VMs (needed for `disk_encryption = "tpm"` in `talos-cluster`) | `true` |
| `network.prefix_length` | number 8–30 | — | yes | Prefix length of node addresses | `24` |
| `network.gateway` | IPv4 | — | yes | Default gateway | `203.0.113.1` |
| `network.dns_servers` | list of IPv4 | — | yes | DNS servers | `["203.0.113.1"]` |
| `network.domain` | DNS name | — | yes | Domain for FQDNs and DNS search | `lab.example.com` |
| `addresses` | map(list(IPv4)) | — | yes | Addresses per pool; node N gets element N-1; unique across pools | `{ cp = ["203.0.113.31"] }` |
| `ssh.user`, `ssh.public_keys` | string, list | `null` | for non-Talos pools | cloud-init user and keys | `{ user = "ops", public_keys = ["ssh-ed25519 AAAA…"] }` |
| `talos.version` | string | `null` | for Talos pools | Talos version | `v1.14.2` |
| `talos.schematic_id` | 64 hex | `null` | for Talos pools | Image Factory schematic ID (from `images/talos`) | `CHANGE_ME` |
| `talos.iso_sha256` | 64 hex | `null` | for Talos pools | SHA-256 of `nocloud-amd64.iso` | `CHANGE_ME` |
| `image_factory_url` | https URL | `https://factory.talos.dev` | no | Image Factory, for a mirror | `https://factory.example.com` |
| `tags` | list(string) | `[]` | no | Extra Proxmox tags | `["lab"]` |

Get the ISO checksum once per schematic and version:

```bash
curl -fsSL https://factory.talos.dev/image/<schematic_id>/<version>/nocloud-amd64.iso | sha256sum
```

### Outputs

| Name | Description |
|---|---|
| `nodes` | Map `<pool>-<index>` → normalized node ([Architecture](architecture.md#normalized-node)) plus `vm_id` |
| `templates` | Selected template per OS: `name`, `vm_id`, `node_name` |
| `clone_sources` | Template VM ID each Ubuntu node is cloned from at creation |
| `talos_iso` | Proxmox file ID of the Talos ISO, or `null` |

### What each VM gets

| Setting | Value |
|---|---|
| Name | `<cluster>-<pool>-<index>`, for example `mgmt-cp-1` |
| Tags | `sogeor`, cluster, pool, role, OS, plus `tags` |
| Firmware | `q35`, OVMF (UEFI) with a 4M EFI disk, VirtIO SCSI single |
| CPU, memory, disk | From the size: cores, dedicated memory (no ballooning), `scsi0` with discard, SSD emulation, iothread |
| Ubuntu | Full clone of the newest template with tags `packer;<os>;k8s;k8s-<major>-<minor>` (kubeadm) or `packer;<os>;base` (k3s); only names ending in `-v<run>-<attempt>` are considered |
| Talos | Image Factory ISO on `ide0`, boot order disk then ISO, cloud-init on `ide2` |
| Network | One VirtIO NIC; static IPv4, gateway, DNS through cloud-init |
| Lifecycle | Starts on boot; a newer template or ISO does not replace existing VMs |

### Proxmox API token

The caller configures the provider (for example `PROXMOX_VE_ENDPOINT` and `PROXMOX_VE_API_TOKEN`). The token
needs, on `/` or narrower paths: `VM.Allocate`, `VM.Clone`, `VM.Audit`, `VM.Config.CDROM`, `VM.Config.CPU`,
`VM.Config.Cloudinit`, `VM.Config.Disk`, `VM.Config.HWType`, `VM.Config.Memory`, `VM.Config.Network`,
`VM.Config.Options`, `VM.Monitor`, `VM.PowerMgmt`, `Datastore.Allocate`, `Datastore.AllocateSpace`,
`Datastore.AllocateTemplate`, `Datastore.Audit`, `Sys.Audit`, `Sys.AccessNetwork` (ISO download by URL),
`SDN.Use`. A token created with `--privsep 1` needs its own ACL entry.

## talos-cluster

Source: `modules/talos-cluster`. Generated reference: `modules/talos-cluster/README.md`.
Providers: `siderolabs/talos` 0.12.0 and `hashicorp/helm` 3.3.0 (only renders the Cilium chart, never connects
to a cluster), both configured by the caller with empty blocks. Requires OpenTofu 1.11 or newer (ephemeral
resources and write-only arguments).

### Inputs

| Name | Type | Default | Required | Description | Example |
|---|---|---|---|---|---|
| `spec` | object | — | yes | `module.<name>.spec` of `cluster-spec`; distribution must be `talos` | `module.spec.spec` |
| `nodes` | map(node) | — | yes | Nodes in the normalized node contract, all `distribution = talos`, at least one control plane | `module.nodes.nodes` |
| `talos.version` | string | — | yes | Talos version to install and keep on the nodes | `v1.14.2` |
| `talos.schematic_id` | 64 hex | — | yes | Image Factory schematic of the installer | `CHANGE_ME` |
| `talos.config_contract` | string | — | yes | Configuration contract fixed at creation; do not change on upgrades | `v1.14` |
| `vip.address`, `vip.link` | IPv4, string | `null` | for `ha` | Shared API address and the link it is announced on (`talosctl get links`) | `{ address = "203.0.113.30", link = "eth0" }` |
| `install_disk` | device path | `/dev/sda` | no | System disk | `/dev/vda` |
| `disk_encryption` | `tpm` \| `nodeid` \| `none` | `tpm` | no | Key of the STATE and EPHEMERAL volumes | `tpm` |
| `cilium.version` | string | `1.20.2` | no | Cilium chart version | `1.20.2` |
| `cilium.repository` | URL | `https://helm.cilium.io` | no | Chart repository or mirror | `https://helm.cilium.io` |
| `cilium.values` | object | `{}` | no | Values merged over the defaults below | `{ hubble = { enabled = false } }` |
| `image_factory_host` | host | `factory.talos.dev` | no | Image Factory serving the installer | `factory.example.com` |

### Outputs

| Name | Sensitive | Description |
|---|---|---|
| `endpoint` | no | `https://<vip or control-plane address>:6443` |
| `installer_image` | no | `<factory>/nocloud-installer/<schematic>:<version>` |
| `config_patches` | no | Patches per node key, one YAML document per element |
| `talosconfig` | yes | talosctl configuration with all control-plane endpoints |
| `kubeconfig` | yes | Admin kubeconfig (break-glass) |
| `machine_secrets` | yes | Talos machine secrets |
| `client_configuration` | yes | Talos client certificates |

Store `talosconfig`, `kubeconfig` and `machine_secrets` in OpenBao; the state that holds them must be encrypted.

### What the nodes get

| Document | All nodes | Control plane only |
|---|---|---|
| `UnattendedInstallConfig` | installer image, disk `install_disk` | |
| `KubeNetworkConfig` | Pod and Service CIDR from `cluster-spec` | |
| `KubeSpanConfig` | enabled | |
| `VolumeConfig` STATE, EPHEMERAL | LUKS2 with the `disk_encryption` key (EPHEMERAL locked to STATE) | |
| `KubeNodeConfig` | pool labels and taints (`key=value:Effect`) | in `single`, the control-plane taint is removed |
| `KubeProxyConfig` | | disabled (Cilium replaces kube-proxy) |
| `KubeFlannelCNIConfig` | | removed |
| `KubeInlineManifestConfig` `cilium` | | rendered chart |
| `Layer2VIPConfig` | | in `ha`, `vip.address` on `vip.link` |

Cilium defaults: `kubeProxyReplacement: true`, API through KubePrism (`localhost:7445`), `ipam.mode: kubernetes`,
`cluster.name` and `cluster.id` from the description (ClusterMesh-ready), cgroup and capabilities for Talos,
`operator.replicas` 1 in `single` and 2 in `ha`.

## CI

| Workflow | Trigger | Inputs | Secrets |
|---|---|---|---|
| `validate` | pull request, push to `master`, manual | — | — |
| `docs` | pull request, push to `master`, manual | — | — |
| `scorecard` | weekly, push to `master`, ruleset change | — | `SCORECARD_TOKEN` (repository secret, fine-grained PAT, Administration: read-only) |

Jobs of `validate`: `linters`, `opentofu` (`tools/check-modules.sh`, `tools/check-talos.sh`), `policies` (schema and Conftest),
`security / *` (reusable `security-lite`).

Tool versions and SHA-256 checksums:

| Where | Variable | Description |
|---|---|---|
| `validate.yml` | `ACTIONLINT_VERSION`, `ACTIONLINT_SHA256` | actionlint release and archive checksum |
| `tools/install-tools.sh` | `TOFU_VERSION`, `TOFU_SHA256` | OpenTofu, `linux_amd64.tar.gz` |
| `tools/install-tools.sh` | `TFLINT_VERSION`, `TFLINT_SHA256` | tflint, `linux_amd64.zip` |
| `tools/install-tools.sh` | `CONFTEST_VERSION`, `CONFTEST_SHA256` | Conftest, `Linux_x86_64.tar.gz` |
| `tools/install-tools.sh` | `TFDOCS_VERSION`, `TFDOCS_SHA256` | terraform-docs, `linux-amd64.tar.gz` |
| `tools/install-tools.sh` | `TALOSCTL_VERSION`, `TALOSCTL_SHA256` | talosctl, `talosctl-linux-amd64` |

Update a version and its checksum together; the checksum comes from the release checksum file.

The repository uses no Environments and no infrastructure credentials.
