# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[SemVer](https://semver.org/). Releases are tagged `modules-vX.Y.Z`.

## [Unreleased]

### Added

- `modules/dns-records` (`cloudflare/cloudflare` 5.27.0): A, AAAA, CNAME, TXT, MX and CAA records of a Cloudflare
  zone with checks of names, TTL, proxying and record data.
- `modules/cloudflare-apps`: remotely managed Cloudflare Tunnel with ingress rules (path rules first, `404`
  catch-all), proxied CNAME per hostname and a sensitive token for `cloudflared`; origin TLS verification can be
  turned off only with a reason.
- `modules/capi-cluster`: Cluster API manifests from the cluster description — CAPI 1.14 (`v1beta2`), Proxmox VE
  through CAPMOX 0.9.1 and OpenStack (Selectel, VK Cloud) through CAPO 0.15.0, Talos through CABPT 0.6.13 and
  CACPPT 0.5.14 and kubeadm (kube-vip on Proxmox); images by the tag set or name of the images contract,
  `MachineDeployment` per pool with Cluster Autoscaler bounds and capacity, `MachineHealthCheck`, content-hashed
  template names; ADR 0006.
- `tools/check-capi.sh` and CI step: renders the scenarios offline and validates them with kubeconform 0.8.0
  against the CRDs of the pinned provider releases (`tools/crd-schemas.py`).
- Rules `capi-single-provider` and `capi-distribution` in `cluster-spec` and Conftest.
- `talos-cluster/config`: `external_cloud_provider` for clouds with a cloud controller manager.
- Reference description `clusters/astra.yaml` (kubeadm on Astra Linux at home, Cluster API).
- `modules/providers/byo`: existing servers as nodes of BYO pools in the normalized node contract, with checks of
  the host count, addresses and SSH users.
- `modules/ansible-inventory` (`ansible/ansible` 1.5.0): inventory from nodes of any providers with the platform
  groups; `ansible_host` by private, mesh or public address; `bootstrap_hosts` lists servers not yet in the mesh;
  end-to-end test with Proxmox and BYO nodes.
- `modules/talos-cluster` (`siderolabs/talos` 0.12.0, `hashicorp/helm` 3.3.0): Talos 1.14 cluster from normalized
  nodes with `talos_machine` and `talos_cluster` (Talos and Kubernetes upgrades from code), configuration
  documents built by a provider-free submodule, Cilium 1.20.2 as a bootstrap inline manifest (no kube-proxy,
  no Flannel), KubeSpan, VIP for `ha`, LUKS2 disk encryption with a TPM key; ADR 0005.
- `tools/check-talos.sh` and CI step: renders the Talos patches offline and validates them with `talosctl`.
- `providers/proxmox`: TPM 2.0 for Talos VMs (`proxmox.tpm`, default on).
- `modules/providers/proxmox` (`bpg/proxmox` 0.116.0): VMs for Proxmox pools of OpenTofu clusters; Ubuntu as
  full clones of the newest tagged template, Talos from the Image Factory ISO with SHA-256 check; static
  addresses through cloud-init; output `nodes` in the normalized node contract; ADR 0004.
- Cluster description: JSON Schema `schemas/cluster.schema.json` with invalid fixtures; new optional fields
  `control_plane_multisite` (with a required reason) and `custom_image_supported` for Talos on BYO.
- `modules/cluster-spec`: validation against the compatibility matrix `matrix.yaml` (rule ids, `violations`,
  `warnings`, `enforce`, `allow_planned_images`) and the normalized `spec` (mechanism, CIDR, sizes, labels).
- Reference descriptions `clusters/mgmt.yaml`, `clusters/main.yaml`, `clusters/talos.yaml`.
- Conftest policies `policies/conftest/cluster` with the same rule ids; planned images are warnings.
- CI jobs `opentofu` (`tools/check-modules.sh`: fmt, validate, tflint, `tofu test`, terraform-docs) and
  `policies` (`tools/check-schema.sh`, `conftest fmt/verify/test`); `tools/install-tools.sh` with SHA-256
  verification.
- Repository scaffold: community files, pre-commit, Renovate, issue and pull request templates.
- CI: `validate` (linters, reusable `security-lite`), `docs` and `scorecard` from
  [sogeor/workflows](https://github.com/sogeor/workflows) v0.1.1, pinned by commit SHA.
- Renovate waits 7 days after a release before proposing it (`minimumReleaseAge`); security updates are not delayed.
- Documentation skeleton to the platform standard and MkDocs site; ADR 0001 (record decisions) and
  ADR 0002 (repository layout).

### Changed

- ADR 0007: no `mesh-registration` module; Headscale users and pre-auth keys come from the `headscale` Ansible
  role.
- `clusters/main.yaml`: the Astra Linux pool moved to `clusters/astra.yaml` — a Cluster API cluster uses one
  provider.

### Removed

- Alpine Linux from the base platform: the `alpine` OS, the `allow_experimental` field and the
  `experimental-os` rule are gone from the cluster description, the schema, `cluster-spec` and the policies.
