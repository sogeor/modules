# 0003. Validation of the cluster description

- Status: accepted
- Date: 2026-10-14

## Context and problem statement

The constructor promises that an incompatible cluster is rejected before any resource exists: OS per
distribution, an image for every (OS, provider) pair, control plane size for the topology, budget limits.
Two rules of the platform had no field to check (control plane on several sites, Talos on BYO hosts), and
reference descriptions must exist before all of their images are built.

## Decision outcome

- **Three layers.** JSON Schema checks structure; the same compatibility rules run in Conftest (pull requests,
  without OpenTofu) and in `cluster-spec` (plan time in the consuming repository). Rules share ids.
- **One matrix.** `modules/cluster-spec/matrix.yaml` lists distributions, providers and mechanisms, image status
  per (OS, provider), sizes and profiles. Both rule sets read it; CI checks that the schema enums match it.
- **Image status.** A pair missing from the matrix is always an error. A `planned` pair is a warning in Conftest
  and an error in `cluster-spec` unless `allow_planned_images = true`.
- **New optional fields.** `control_plane_multisite: { enabled, reason }` allows control-plane pools on several
  sites with a recorded reason; `custom_image_supported` on a pool allows `talos` on `byo`.

### Consequences

- Reference descriptions (`main` on Selectel) are kept valid in CI before their images exist, while a real
  deployment cannot start without an image.
- Each rule is implemented twice (HCL and Rego); tests with the same ids in both keep them aligned.
- Marking an image as available is a one-line change in the matrix.
