# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[SemVer](https://semver.org/). Releases are tagged `modules-vX.Y.Z`.

## [Unreleased]

### Added

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
