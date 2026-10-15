# capi-cluster

Renders Cluster API manifests for a workload cluster from the normalized cluster description. The module creates
nothing: the GitOps repository commits `manifest` and Argo CD in the management cluster applies it.

- **Infrastructure:** Proxmox VE through CAPMOX (templates selected by the exact tag set of the images contract,
  node addresses from a range, API VIP) and OpenStack clouds (Selectel, VK Cloud) through CAPO (image by name,
  flavor per size, managed network, optional API load balancer).
- **Distributions:** Talos (`TalosControlPlane`, `TalosConfigTemplate` with the same Talos 1.14 documents as
  `talos-cluster`) and kubeadm (`KubeadmControlPlane`, `KubeadmConfigTemplate`, kube-vip on Proxmox); no kube-proxy,
  Cilium and the cloud controller manager are installed by Argo CD.
- **Pools:** one `MachineDeployment` per worker pool with labels and taints; autoscaled pools carry Cluster
  Autoscaler bounds and capacity, so they can scale from zero.
- **Health:** `MachineHealthCheck` for workers, and for the control plane with topology `ha`.
- **Rollouts:** machine and bootstrap templates are named after a hash of their content, so a change creates a new
  template and CAPI replaces the machines.

```hcl
module "capi" {
  source = "git::https://github.com/sogeor/modules.git//modules/capi-cluster?ref=modules-v0.1.0"

  spec   = module.spec.spec
  images = { talos = { version = "v1.14.2", schematic_id = "CHANGE_ME" } }
  openstack = {
    identity_secret  = "talos-openstack-credentials"
    external_network = "CHANGE_ME"
    dns_nameservers  = ["198.51.100.53"]
    flavors          = { m = "CHANGE_ME", l = "CHANGE_ME" }
  }
}
```

Options: [Configuration](../../docs/configuration.md#capi-cluster). Task: [Usage](../../docs/usage.md#render-cluster-api-manifests).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| talos_config | ../talos-cluster/config | n/a |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| images | Images: Talos version and Image Factory schematic, and the image build per OS (for example v20-1). Proxmox needs a build for every OS, OpenStack for every OS except talos. | ```object({ talos = optional(object({ version = string schematic_id = string })) builds = optional(map(string), {}) })``` | n/a | yes |
| spec | Normalized cluster from the cluster-spec module (module.NAME.spec). | ```object({ cluster = string distribution = string kubernetes_version = string topology = string mechanism = string labels = map(string) network = object({ pod_cidr = string service_cidr = string }) control_plane = object({ count = number workloads_allowed = bool }) pools = map(object({ role = string os = string provider = string size = string cpu = number memory_mb = number disk_gb = number count = optional(number) autoscale = optional(object({ min = number max = number })) labels = map(string) taints = list(string) })) })``` | n/a | yes |
| namespace | Namespace of the CAPI objects in the management cluster; null uses the cluster name. | `string` | `null` | no |
| openstack | OpenStack settings for CAPO: credentials Secret, external network, node subnet, flavor per size, API endpoint exposure. | ```object({ identity_secret = string cloud_name = optional(string, "openstack") external_network = string node_cidr = optional(string, "10.100.0.0/24") dns_nameservers = list(string) flavors = map(string) volume_type = optional(string) api_floating_ip = optional(bool, true) api_allowed_cidrs = optional(list(string), []) load_balancer = optional(bool) ssh_key_name = optional(string) })``` | `null` | no |
| proxmox | Proxmox VE settings for CAPMOX: template node, target storage, bridge, node address range, gateway, DNS and the control-plane VIP. | ```object({ source_node = string allowed_nodes = optional(list(string), []) storage = optional(string) bridge = string vlan = optional(number) addresses = list(string) prefix = number gateway = string dns_servers = list(string) control_plane_endpoint = string vip_interface = optional(string) credentials_secret = optional(string) })``` | `null` | no |
| talos_disk_encryption | Key for the Talos STATE and EPHEMERAL volumes: nodeid or none (the CAPI images have no TPM). | `string` | `"nodeid"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| infrastructure | CAPI infrastructure provider used: proxmox (CAPMOX) or openstack (CAPO). |
| manifest | All objects as one multi-document YAML, ready to commit for Argo CD. |
| objects | CAPI objects in apply order: Cluster, infrastructure cluster, control plane, machine templates, bootstrap templates, MachineDeployments, MachineHealthChecks. |
<!-- END_TF_DOCS -->
