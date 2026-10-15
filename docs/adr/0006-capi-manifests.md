# 0006. Cluster API manifests: one provider per cluster, plain manifests

- Status: accepted
- Date: 2026-10-15

## Context and problem statement

Workload clusters are created by Cluster API from the management cluster and scale with the Cluster Autoscaler.
The constructor must turn the same cluster description into CAPI objects for Proxmox VE and OpenStack clouds,
for Talos and kubeadm. In Cluster API a `Cluster` has one infrastructure provider; the Talos providers (CABPT,
CACPPT) still implement the `v1beta1` contract, which CAPI supports until release 1.16 (April 2027).

## Considered options

- Mixed providers in one cluster (for example Selectel with an Astra pool at home): not possible in one `Cluster`;
  a hybrid with OpenTofu-joined nodes needs a per-pool mechanism.
- Generation: plain manifests per object, or a `ClusterClass` with a short `Cluster`.
- Rendering: `clusterctl generate` with templates, or OpenTofu locals with `yamlencode`.
- Talos on CAPI despite the `v1beta1` contract, or Talos workload clusters through `talos-cluster` only.

## Decision outcome

- **One provider per CAPI cluster:** rule `capi-single-provider` in `cluster-spec` and Conftest. The Astra pool of
  `main` becomes the separate cluster `astra` at home. Mixed providers are left to the future Sogeor operator.
- **k3s is not rendered through CAPI** (rule `capi-distribution`); the community provider is not part of the base
  platform.
- **Plain manifests rendered by OpenTofu** (`modules/capi-cluster`): every object is explicit and validated by
  kubeconform against the CRDs of the pinned provider releases (`tools/check-capi.sh`). `ClusterClass` can follow
  once the Talos providers reach `v1beta2`.
- **Talos through CAPI:** the Talos configuration reuses the `talos-cluster/config` submodule (one set of Talos 1.14
  documents for both mechanisms). Risk: if the Talos providers do not move to `v1beta2` before CAPI 1.16, Talos
  workload clusters stop receiving CAPI upgrades; fallback — `talos-cluster` through OpenTofu without autoscaling.
  Review: January 2027.
- **Control-plane endpoint on Proxmox:** a VIP — Talos `Layer2VIPConfig`, kube-vip for kubeadm. On OpenStack:
  floating IP, plus a managed load balancer for `ha`.
- **Add-ons outside the manifests:** Cilium and the cloud controller manager are installed by Argo CD; nodes stay
  `NotReady` until Cilium runs.

### Consequences

- The generator cannot be tested against a live cloud in CI; schemas catch structure errors, not runtime behavior.
- Template names carry a content hash: every change rolls the machines of that pool, as CAPI requires.
- The Talos image for OpenStack (`talos-v<version>-<schematic>`) must exist before a Talos cluster on OpenStack.
