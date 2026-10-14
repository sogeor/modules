# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[SemVer](https://semver.org/). Releases are tagged `modules-vX.Y.Z`.

## [Unreleased]

### Added

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
