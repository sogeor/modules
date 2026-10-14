# talos-cluster

Turns Talos nodes (the normalized node contract, for example from `providers/proxmox`) into a running Talos
Linux cluster: machine secrets, per-node configuration, installation, etcd bootstrap and a kubeconfig.

- **Talos 1.14 configuration documents:** installation from the Image Factory installer, Kubernetes network from
  `cluster-spec`, KubeSpan, node labels and taints per pool.
- **Cilium at bootstrap:** rendered from the pinned Helm chart and applied by Talos as an inline manifest;
  kube-proxy and Flannel are removed. Argo CD can adopt the release later with the same values.
- **Disk encryption:** STATE and EPHEMERAL with LUKS2, key from the TPM by default.
- **Upgrades as code:** `talos.version` upgrades Talos on the nodes (`talos_machine`), `kubernetes_version` in the
  cluster description upgrades Kubernetes (`talos_cluster`, `upgrade-k8s`).
- **Topology:** `single` allows workloads on the control plane; `ha` uses a Talos VIP and drains nodes before upgrades.

```hcl
module "cluster" {
  source = "git::https://github.com/sogeor/modules.git//modules/talos-cluster?ref=modules-v0.1.0"

  spec  = module.spec.spec
  nodes = module.nodes.nodes
  talos = { version = "v1.14.2", schematic_id = "CHANGE_ME", config_contract = "v1.14" }
}
```

Options and runbooks: [Configuration](../../docs/configuration.md#talos-cluster),
[Operations](../../docs/operations.md#upgrade-talos).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.11.0 |
| helm | = 3.3.0 |
| talos | = 0.12.0 |

## Providers

| Name | Version |
| ---- | ------- |
| helm | = 3.3.0 |
| talos | = 0.12.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| config | ./config | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [talos_cluster.this](https://registry.terraform.io/providers/siderolabs/talos/0.12.0/docs/resources/cluster) | resource |
| [talos_cluster_kubeconfig.this](https://registry.terraform.io/providers/siderolabs/talos/0.12.0/docs/resources/cluster_kubeconfig) | resource |
| [talos_machine.node](https://registry.terraform.io/providers/siderolabs/talos/0.12.0/docs/resources/machine) | resource |
| [talos_machine_secrets.this](https://registry.terraform.io/providers/siderolabs/talos/0.12.0/docs/resources/machine_secrets) | resource |
| [helm_template.cilium](https://registry.terraform.io/providers/hashicorp/helm/3.3.0/docs/data-sources/template) | data source |
| [talos_client_configuration.this](https://registry.terraform.io/providers/siderolabs/talos/0.12.0/docs/data-sources/client_configuration) | data source |
| [talos_machine_configuration.node](https://registry.terraform.io/providers/siderolabs/talos/0.12.0/docs/data-sources/machine_configuration) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| nodes | Nodes in the normalized node contract, for example module.NAME.nodes of a provider module. | ```map(object({ name = string distribution = string role = string pool = string private_ip = string labels = map(string) taints = list(string) }))``` | n/a | yes |
| spec | Normalized cluster from the cluster-spec module (module.NAME.spec). | ```object({ cluster = string cluster_id = number distribution = string kubernetes_version = string topology = string network = object({ pod_cidr = string service_cidr = string }) control_plane = object({ workloads_allowed = bool }) })``` | n/a | yes |
| talos | Talos version to install, Image Factory schematic and the config contract fixed at cluster creation (for example v1.14). | ```object({ version = string schematic_id = string config_contract = string })``` | n/a | yes |
| cilium | Cilium Helm chart installed at bootstrap: version, repository and extra values merged over the defaults. | ```object({ version = optional(string, "1.20.2") repository = optional(string, "https://helm.cilium.io") values = optional(any, {}) })``` | `{}` | no |
| disk_encryption | Key for the STATE and EPHEMERAL volumes: tpm (needs a TPM 2.0), nodeid or none. | `string` | `"tpm"` | no |
| image_factory_host | Image Factory host that serves the installer image. | `string` | `"factory.talos.dev"` | no |
| install_disk | Device path of the system disk. | `string` | `"/dev/sda"` | no |
| vip | Shared IPv4 address of the Kubernetes API and the link it is announced on; required for topology ha. | ```object({ address = string link = string })``` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| client_configuration | Talos client certificates for other Talos resources. |
| config_patches | Machine configuration patches per node key, one YAML document per element. |
| endpoint | Kubernetes API endpoint: the VIP for ha, the control-plane node for single. |
| installer_image | Talos installer image the nodes run. |
| kubeconfig | Admin kubeconfig; break-glass only, store in OpenBao. |
| machine_secrets | Talos machine secrets; needed to add nodes or rebuild the cluster, store in OpenBao. |
| talosconfig | talosctl client configuration (admin). |
<!-- END_TF_DOCS -->
