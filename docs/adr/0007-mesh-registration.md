# 0007. Mesh registration without an OpenTofu provider

- Status: accepted
- Date: 2026-10-17

## Context and problem statement

Nodes outside `home` join the Headscale mesh with pre-auth keys. The platform plan had a `mesh-registration`
module that would create the keys with OpenTofu. The only maintained provider, `awlsring/headscale` 0.5.1
(March 2026, one maintainer), supports Headscale 0.28.x; Headscale 0.29 is current and changed the ACL
semantics and part of the API. Keys created by OpenTofu are secrets kept in state, and the CI that applies them
needs a long-lived Headscale API key.

## Considered options

1. `mesh-registration` module with `awlsring/headscale`: users and pre-auth keys.
2. No module: the `headscale` Ansible role on `edge` creates users and short-lived keys with the Headscale CLI.
3. Module with the provider for users and the ACL policy only; keys outside OpenTofu.

## Decision outcome

Option 2.

- This repository has no `mesh-registration` module and no Headscale provider.
- The `headscale` role in the `ansible` repository (planned) creates users and
  single-use, short-lived, tagged pre-auth keys on `edge` and hands them to the `tailscale` role of the node in
  the same run; the ACL policy (`acl.hujson`, `management`) is installed by the same role.
- `ansible-inventory` keeps the link to OpenTofu: `bootstrap_hosts` lists nodes still outside the mesh and
  `mesh_addresses` records their mesh addresses afterwards.

### Consequences

- Pre-auth keys never reach OpenTofu state, and no CI holds a Headscale API key.
- Headscale versions are not limited by a third-party provider.
- Users and ACL are managed by Ansible instead of OpenTofu; drift is corrected on the next role run.
- Talos nodes outside `home` have no Ansible: their key goes into the Tailscale extension configuration of the
  machine config and so into the `talos-cluster` state. Such keys must be single-use and expire within hours.
- Revisit if a maintained provider follows Headscale releases and supports ephemeral resources for keys.
