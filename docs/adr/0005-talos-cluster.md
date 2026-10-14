# 0005. Talos cluster: lifecycle resources, Cilium at bootstrap, TPM encryption

- Status: accepted
- Date: 2026-10-14

## Context and problem statement

The management cluster runs Talos Linux and is created by OpenTofu. Talos 1.14 replaced most v1alpha1 fields
with separate configuration documents. The cluster needs a CNI before anything else can run, and the platform
requires encrypted Talos disks and upgrades without manual steps.

## Considered options

- Lifecycle: `talos_machine_configuration_apply` + `talos_machine_bootstrap` (upgrades by `talosctl`), or the new
  `talos_machine` + `talos_cluster` of provider 0.12.0 (upgrades from code).
- CNI: Flannel by default, or Cilium installed after bootstrap by another tool, or Cilium as an inline manifest.
- Disk encryption key: `nodeID`, or TPM.

## Decision outcome

- **Lifecycle:** `talos_machine` per node (configuration, installer image, OS upgrades, drain in `ha`) and
  `talos_cluster` (etcd bootstrap, Kubernetes upgrades through `upgrade-k8s`, with
  `ignore_kubernetes_upgrade_drift`). The configuration contract (`config_contract`) is fixed at creation.
- **Configuration documents:** patches target Talos 1.14 documents (`UnattendedInstallConfig`, `KubeNetworkConfig`,
  `KubeProxyConfig`, `KubeNodeConfig`, `KubeSpanConfig`, `KubeInlineManifestConfig`, `Layer2VIPConfig`,
  `VolumeConfig`). They are built by a provider-free submodule and validated by `talosctl validate` in CI.
- **CNI:** Cilium from the pinned chart, rendered by the Helm provider and applied by Talos as an inline manifest;
  kube-proxy and Flannel are removed; `cluster.name`/`cluster.id` prepare ClusterMesh.
- **Encryption:** STATE and EPHEMERAL with a TPM-sealed key; `providers/proxmox` adds a TPM 2.0 to Talos VMs.

### Consequences

- Talos and Kubernetes upgrades are reviewed pull requests, not manual runbooks.
- The new resources are recent (provider 0.12.0); falling back to the classic resources does not require
  recreating the cluster.
- TPM encryption reaches full strength only with SecureBoot, which is a follow-up (Image Factory SecureBoot ISO,
  key enrollment on Proxmox).
- Argo CD in `platform` must adopt the Cilium release with the same values.
