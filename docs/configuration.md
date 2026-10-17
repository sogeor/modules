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
| `control_plane_multisite.enabled` | bool | `false` | no | Allows control-plane pools on different sites | `true` |
| `control_plane_multisite.reason` | string | — | when `enabled: true` | Why the sites qualify (measured latency below 10 ms) | `"Latency below 10 ms"` |
| `pools.<name>.role` | `control-plane` \| `worker` | — | yes | Pool role | `worker` |
| `pools.<name>.os` | `ubuntu-2404` \| `ubuntu-2604` \| `astra-18` \| `talos` | — | yes | OS of the pool | `ubuntu-2404` |
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
| `talos-byo-custom-image` | `talos` on `byo` without `custom_image_supported: true` |
| `count-or-autoscale` | A pool has both or neither of `count` and `autoscale` |
| `autoscale-bounds` | Not `0 <= min <= max`, or `max < 1` |
| `autoscale-mechanism` | `autoscale` without mechanism `capi` |
| `control-plane-autoscale` | A control-plane pool uses `autoscale` |
| `mechanism-provider` | A pool provider does not support the mechanism |
| `capi-single-provider` | Mechanism `capi` with pools on more than one provider (a CAPI `Cluster` has one infrastructure provider) |
| `capi-distribution` | Mechanism `capi` with distribution `k3s` (use `opentofu`) |
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

## capi-cluster

Source: `modules/capi-cluster`. Generated reference: `modules/capi-cluster/README.md`. No providers: the module
only renders YAML; it never connects to a cluster or a cloud.

Supported: `talos` and `kubeadm`, on `proxmox` (CAPMOX) or `selectel`/`vkcloud` (CAPO), exactly one
control-plane pool, all pools on one provider.

### Inputs

| Name | Type | Default | Required | Description | Example |
|---|---|---|---|---|---|
| `spec` | object | — | yes | `module.<name>.spec` of `cluster-spec`; mechanism must be `capi` | `module.spec.spec` |
| `namespace` | string | cluster name | no | Namespace of the CAPI objects in `mgmt` | `clusters` |
| `images.talos.version` | string | — | for Talos | Talos version of the image | `v1.14.2` |
| `images.talos.schematic_id` | 64 hex | — | for Talos | Image Factory schematic of the image and installer | `CHANGE_ME` |
| `images.builds` | map(OS → build) | `{}` | Proxmox: every OS; OpenStack: every OS except `talos` | Image build per OS ([images contract](architecture.md#images)) | `{ ubuntu-2404 = "v20-1", talos = "v20-1" }` |
| `proxmox.source_node` | string | — | for Proxmox | Node that holds the templates | `pve` |
| `proxmox.allowed_nodes` | list(string) | `[]` | no | Nodes that may run the VMs; empty — all | `["pve"]` |
| `proxmox.storage` | string | template storage | no | Storage of the full clones | `local-lvm` |
| `proxmox.bridge` | string | — | yes | Bridge of the VMs | `vmbr0` |
| `proxmox.vlan` | number | none | no | VLAN tag | `40` |
| `proxmox.addresses` | list(string) | — | yes | Node address ranges or CIDRs (CAPMOX in-cluster IPAM) | `["203.0.113.40-203.0.113.49"]` |
| `proxmox.prefix` | number | — | yes | Prefix length of the node network | `24` |
| `proxmox.gateway` | IPv4 | — | yes | Default gateway | `203.0.113.1` |
| `proxmox.dns_servers` | list(IPv4) | — | yes | DNS servers | `["203.0.113.1"]` |
| `proxmox.control_plane_endpoint` | IPv4 | — | yes | API VIP, outside `addresses` | `203.0.113.39` |
| `proxmox.vip_interface` | string | none (kube-vip detects it) | for Talos | Interface that announces the VIP (Talos: `talosctl get links`) | `ens18` |
| `proxmox.credentials_secret` | string | CAPMOX default | no | Secret with the Proxmox API token for this cluster | `proxmox-credentials` |
| `openstack.identity_secret` | string | — | for OpenStack | Secret with `clouds.yaml` (created by ESO from OpenBao) | `openstack-credentials` |
| `openstack.cloud_name` | string | `openstack` | no | Cloud entry in `clouds.yaml` | `openstack` |
| `openstack.external_network` | string | — | yes | External network name (floating IPs, router) | `external-network` |
| `openstack.node_cidr` | CIDR | `10.100.0.0/24` | no | Managed node subnet | `10.100.0.0/24` |
| `openstack.dns_nameservers` | list(IPv4) | — | yes | DNS of the node subnet | `["198.51.100.53"]` |
| `openstack.flavors` | map(size → flavor) | — | yes | Flavor for every pool size | `{ m = "CHANGE_ME" }` |
| `openstack.volume_type` | string | cloud default | no | Root volume type | `CHANGE_ME` |
| `openstack.api_floating_ip` | bool | `true` | no | Floating IP for the API (reachable from `mgmt`) | `true` |
| `openstack.load_balancer` | bool | `true` for `ha` | no | Managed load balancer (Octavia) in front of the API | `false` |
| `openstack.api_allowed_cidrs` | list(CIDR) | `[]` | no | Load balancer allow-list; empty — any | `["203.0.113.0/24"]` |
| `openstack.ssh_key_name` | string | none | no | Key pair for kubeadm nodes (bootstrap only) | `bootstrap` |
| `talos_disk_encryption` | `nodeid` \| `none` | `nodeid` | no | Key of the Talos STATE and EPHEMERAL volumes (the CAPI images have no TPM) | `nodeid` |

### Outputs

| Name | Description |
|---|---|
| `objects` | CAPI objects in apply order; preconditions check the inputs above |
| `manifest` | All objects as one multi-document YAML |
| `infrastructure` | `proxmox` or `openstack` |

### What is rendered

| Object | API | When |
|---|---|---|
| `Cluster` | `cluster.x-k8s.io/v1beta2` | Always; Pod/Service CIDR and the `sogeor.com/*` labels |
| `ProxmoxCluster` / `OpenStackCluster` | `v1alpha2` / `v1beta2` | By provider |
| `TalosControlPlane` / `KubeadmControlPlane` | `v1alpha3` / `v1beta2` | By distribution |
| `ProxmoxMachineTemplate` / `OpenStackMachineTemplate` | `v1alpha2` / `v1beta2` | Per pool, named `<cluster>-<pool>-<hash>` |
| `TalosConfigTemplate` / `KubeadmConfigTemplate` | `v1alpha3` / `v1beta2` | Per worker pool |
| `MachineDeployment` | `v1beta2` | Per worker pool; `replicas` from `count`, or autoscaler annotations |
| `MachineHealthCheck` | `v1beta2` | Workers; control plane in `ha`. Remediates a node not `Ready` for 15 minutes, or without a node 20 minutes after creation |

Images: Proxmox templates by the exact tag set (`packer;talos;base;talos-<x-y-z>;schematic-<12 hex>;v<build>` or
`packer;<os>;k8s;k8s-<maj>-<min>;v<build>`); OpenStack images by name (`talos-v<version>-<12 hex>` or
`<os>-k8s-v<build>`).

Nodes: Talos gets the documents of [talos-cluster](#talos-cluster) without Cilium (installed by Argo CD), with
`nodeid` encryption, disk `/dev/sda` (Proxmox) or `/dev/vda` (OpenStack), the VIP on Proxmox and
`externalCloudProvider` on OpenStack. kubeadm gets pool labels (`node-labels`) and taints, no kube-proxy, kube-vip
on Proxmox and `cloud-provider=external` on OpenStack.

Autoscaled pools: `cluster.x-k8s.io/cluster-api-autoscaler-node-group-{min,max}-size` and
`capacity.cluster-autoscaler.kubernetes.io/{cpu,memory,ephemeral-disk,labels,taints}`; `replicas` is left to the
autoscaler (exclude it from Argo CD diffs).

## providers/selectel

Source: `modules/providers/selectel`. Generated reference: `modules/providers/selectel/README.md`.
Provider: `terraform-provider-openstack/openstack` 3.4.0, configured by the caller with the credentials of the
Selectel service user (`OS_*` variables). Creates no nodes; acts on pools with `provider: selectel`
([ADR 0008](adr/0008-selectel-capi-prerequisites.md)).

### Inputs

| Name | Type | Default | Required | Description | Example |
|---|---|---|---|---|---|
| `spec` | object | — | yes | `module.<spec>.spec`; needs at least one Selectel pool | `module.spec.spec` |
| `external_network` | string | — | yes | Name of the external network of the region; looked up at plan time | `external-network` |
| `dns_nameservers` | list(IPv4) | — | yes | Resolvers for the node subnet created by CAPO | `["198.51.100.53"]` |
| `volume_type` | string | `null` | no | Root volume type; `null` keeps the project default | `fast.ru-9a` |
| `existing_flavors` | map(size → name) | `{}` | no | Use existing flavors for these sizes instead of creating them | `{ l = "SL1.4-8192" }` |
| `flavor_prefix` | string | `sogeor` | no | Prefix of created flavors `<prefix>-<cluster>-<size>` | `sogeor` |
| `ssh_public_key` | OpenSSH public key | `null` | no | Break-glass key pair `<cluster>-admin` for kubeadm nodes; rejected for Talos | `ssh-ed25519 AAAA… ops@example.com` |

### Outputs

| Name | Description |
|---|---|
| `flavors` | Flavor name per size of the Selectel pools |
| `external_network` | `id` and `name` of the external network |
| `ssh_key_name` | Key pair name or `null` |
| `capi_openstack` | `external_network`, `dns_nameservers`, `flavors`, `volume_type`, `ssh_key_name` for the `openstack` input of `capi-cluster` |

### Created objects

| Object | Name | Settings |
|---|---|---|
| Flavor per used size not in `existing_flavors` | `<prefix>-<cluster>-<size>` | vCPU and RAM from the size catalog, disk 0, private |
| Key pair (optional) | `<cluster>-admin` | The given public key |

### Selectel service user

The OpenStack credentials belong to a service user of the project; the service user, its project role and the
OpenStack RC file are created by the `bootstrap` repository (planned). Pass them as `OS_AUTH_URL`,
`OS_REGION_NAME`, `OS_PROJECT_ID`, `OS_USER_DOMAIN_NAME`, `OS_USERNAME`, `OS_PASSWORD` from a GitHub
Environment of the consuming repository. If the project does not allow private flavors, list fixed
configurations in `existing_flavors`.

## providers/byo

Source: `modules/providers/byo`. Generated reference: `modules/providers/byo/README.md`. No provider; creates no
resources. Acts on pools with `provider: byo`.

### Inputs

| Name | Type | Default | Required | Description | Example |
|---|---|---|---|---|---|
| `spec` | object | — | yes | `module.<name>.spec` of `cluster-spec` | `module.spec.spec` |
| `hosts.<pool>[].public_ip` | IPv4 | `null` | one of the two | Public address | `198.51.100.10` |
| `hosts.<pool>[].private_ip` | IPv4 | `public_ip` | one of the two | Private address, if the provider has a private network | `10.0.0.10` |
| `hosts.<pool>[].ssh_user` | string | `ssh_user` | no | SSH user of the first connection for this host | `ubuntu` |
| `hosts.<pool>[].zone` | string | the site | no | Value of `topology.kubernetes.io/zone` | `ams-1` |
| `ssh_user` | string | `null` | for non-Talos pools without per-host users | Default SSH user | `ops` |
| `domain` | DNS name | — | yes | Domain for FQDNs | `lab.example.com` |

The number of hosts of a pool must equal its `count`; hosts of pools that are not BYO pools are rejected.

### Outputs

| Name | Description |
|---|---|
| `nodes` | Map `<pool>-<index>` → normalized node ([Architecture](architecture.md#normalized-node)) |

## ansible-inventory

Source: `modules/ansible-inventory`. Generated reference: `modules/ansible-inventory/README.md`.
Provider: `ansible/ansible` 1.5.0, configured by the caller with an empty block.

### Inputs

| Name | Type | Default | Required | Description | Example |
|---|---|---|---|---|---|
| `nodes` | map(node) | — | yes | Nodes of any providers, merged: `merge(module.a.nodes, module.b.nodes)`; names unique | `merge(module.home.nodes, module.vds.nodes)` |
| `mesh_addresses` | map(IPv4) | `{}` | no | Mesh address per node name, once the node joined the mesh | `{ lab-vds-1 = "100.64.0.12" }` |
| `cluster_vars` | map(object) | `{}` | no | Variables of the `cluster_<name>` group per cluster | `{ lab = { kubernetes_version = "1.37.1" } }` |

### Outputs

| Name | Description |
|---|---|
| `hosts` | Per host: `ansible_host`, `connection` (`private`, `mesh` or `public`), groups |
| `groups` | Per group: host names |
| `bootstrap_hosts` | Hosts outside `home` still reached by their public address |

### Inventory contents

| Item | Value |
|---|---|
| Hosts | Every node except Talos, named by the node name |
| Groups | `cluster_<name>`, `distribution_<d>`, `role_<role>`, `site_<site>`, `os_<os>`; `mesh` when `mesh_required`; `internet` when the node has a public address; other characters become `_` |
| `ansible_host` | `home`: private address; elsewhere: mesh address if known, otherwise public address, otherwise private address |
| `ansible_user` | The node `ssh_user` |
| Host variables | `sogeor_connection`, `sogeor_fqdn`, `sogeor_cluster`, `sogeor_pool`, `sogeor_role`, `sogeor_provider`, `sogeor_site`, `sogeor_os`, `sogeor_private_ip`, `sogeor_public_ip`, `sogeor_node_labels`, `sogeor_node_taints` |
| Group `cluster_<name>` | `sogeor_cluster` plus `cluster_vars[<name>]` |

### Inventory plugin file

Ansible reads the inventory from the state of the consuming root module with the
[`cloud.terraform`](https://github.com/ansible-collections/cloud.terraform) collection. The resources live in a
child module, so `search_child_modules` must be `true`:

```yaml
plugin: cloud.terraform.terraform_provider
project_path: path/to/root-module
binary_path: /usr/local/bin/tofu
search_child_modules: true
```

Save it as `inventory.terraform.yml` (the file name must end in `.yml`); the root module must be initialized
with access to its state backend.

## dns-records

Source: `modules/dns-records`. Generated reference: `modules/dns-records/README.md`.
Provider: `cloudflare/cloudflare` 5.27.0, configured by the caller; the token comes from `CLOUDFLARE_API_TOKEN`.

### Inputs

| Name | Type | Default | Required | Description | Example |
|---|---|---|---|---|---|
| `zone_id` | string (32 hex) | — | yes | Cloudflare zone ID | `0123456789abcdef0123456789abcdef` |
| `records` | map(object) | `{}` | no | Records by key, fields below | see below |

Fields of `records.<key>`:

| Field | Type | Default | Required | Description | Example |
|---|---|---|---|---|---|
| `name` | string | — | yes | Fully qualified lowercase name; `*.` allowed | `docs.example.com` |
| `type` | `A` \| `AAAA` \| `CNAME` \| `TXT` \| `MX` \| `CAA` | — | yes | Record type | `CNAME` |
| `content` | string | — | all but CAA | Value: IPv4 for A, IPv6 for AAAA, name for CNAME and MX, text for TXT | `example.github.io` |
| `ttl` | number | `1` | no | `1` (automatic) or 60–86400; proxied records need `1` | `300` |
| `proxied` | bool | `false` | no | Through the Cloudflare proxy; A, AAAA and CNAME only | `true` |
| `priority` | number | — | MX only | MX priority | `10` |
| `comment` | string | — | no | Comment shown in the dashboard | `GitHub Pages` |
| `caa` | object(`flags` = `0`, `tag`, `value`) | — | CAA only | CAA data | `{ tag = "issue", value = "letsencrypt.org" }` |

### Outputs

| Name | Description |
|---|---|
| `records` | Per key: `id`, `name`, `type` |

!!! warning "GitHub Pages"
    A CNAME for a GitHub Pages custom domain must stay `proxied = false` (DNS only), otherwise GitHub cannot issue
    the certificate and **Enforce HTTPS** is unavailable.

## cloudflare-apps

Source: `modules/cloudflare-apps`. Generated reference: `modules/cloudflare-apps/README.md`.
Provider: `cloudflare/cloudflare` 5.27.0, configured by the caller; the token comes from `CLOUDFLARE_API_TOKEN`.

### Inputs

| Name | Type | Default | Required | Description | Example |
|---|---|---|---|---|---|
| `account_id` | string (32 hex) | — | yes | Cloudflare account ID that owns the tunnel | `0123456789abcdef0123456789abcdef` |
| `zone_id` | string (32 hex) | — | yes | Zone of the public hostnames | `fedcba9876543210fedcba9876543210` |
| `tunnel_name` | DNS label | — | yes | Tunnel name, usually the cluster name | `main` |
| `apps` | map(object) | — | yes (≥ 1) | Public hostnames by key, fields below | see below |
| `comment` | string | `Managed by OpenTofu: Cloudflare Tunnel` | no | Comment on the hostname DNS records | — |

Fields of `apps.<key>`:

| Field | Type | Default | Required | Description | Example |
|---|---|---|---|---|---|
| `hostname` | string | — | yes | Public fully qualified name in the zone | `store.example.com` |
| `service` | string | — | yes | Origin: `http(s)://`, `tcp://`, `ssh://`, `rdp://`, `smb://`, `unix://`, `unix+tls://` URL or `http_status:CODE` | `http://ingress-nginx-controller.ingress-nginx.svc:80` |
| `path` | string (regex) | — | no | Only requests whose path matches | `^/api/` |
| `origin_request.http_host_header` | string | — | no | Host header sent to the origin | `store.example.com` |
| `origin_request.origin_server_name` | string | — | no | Expected name in the origin certificate | `oauth2-proxy.auth.svc` |
| `origin_request.http2_origin` | bool | — | no | HTTP/2 to an HTTPS origin | `true` |
| `origin_request.connect_timeout` | number (s) | — | no | TCP connect timeout | `10` |
| `origin_request.tls_timeout` | number (s) | — | no | TLS handshake timeout | `10` |
| `origin_request.no_tls_verify` | bool | `false` | no | Skip origin certificate verification | `false` |
| `origin_request.no_tls_verify_reason` | string | — | with `no_tls_verify` | Why verification is off; track removal in an issue | `Self-signed bootstrap certificate` |

Hostname and path pairs must be unique. Routing order: rules with `path` first, then the rest, each group sorted
by key, then `http_status:404` for everything else.

### Outputs

| Name | Description |
|---|---|
| `tunnel_id` | Tunnel UUID |
| `tunnel_cname` | `<tunnel_id>.cfargotunnel.com`, the target of the hostname records |
| `tunnel_token` | Sensitive; `TUNNEL_TOKEN` for `cloudflared` |
| `hostnames` | Published hostnames |
| `ingress` | Ingress rules in routing order |

### Cloudflare API token

Create it in **My Profile → API Tokens → Create Token → Create Custom Token** with the permissions:

| Scope | Permission | Used by |
|---|---|---|
| Account | Cloudflare Tunnel: Edit | `cloudflare-apps` |
| Zone | DNS: Edit (only the platform zone) | `dns-records`, `cloudflare-apps` |

The token is passed as `CLOUDFLARE_API_TOKEN` from a GitHub Environment of the consuming repository.

## CI

| Workflow | Trigger | Inputs | Secrets |
|---|---|---|---|
| `validate` | pull request, push to `master`, manual | — | — |
| `docs` | pull request, push to `master`, manual | — | — |
| `scorecard` | weekly, push to `master`, ruleset change | — | `SCORECARD_TOKEN` (repository secret, fine-grained PAT, Administration: read-only) |

Jobs of `validate`: `linters`, `opentofu` (`tools/check-modules.sh`, `tools/check-talos.sh`, `tools/check-capi.sh`), `policies` (schema and Conftest),
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

| `tools/check-capi.sh` | `KUBECONFORM_VERSION`, `KUBECONFORM_SHA256` | kubeconform, `linux-amd64.tar.gz` |
| `tools/check-capi.sh` | `CRDS` | Release URL and SHA-256 of the CRD bundle of every CAPI provider |

Update a version and its checksum together; the checksum comes from the release checksum file.

The repository uses no Environments and no infrastructure credentials.
