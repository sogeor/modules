# 0008. Selectel: Cluster API prerequisites, no static nodes

- Status: accepted
- Date: 2026-10-17

## Context and problem statement

Workload clusters in Selectel are created by Cluster API through CAPO; the compatibility matrix allows only the
`capi` mechanism for `selectel`. CAPO already creates the node network, subnet, router and security groups
(`managedSubnets`, `managedSecurityGroups`), `bootstrap` creates projects and service users, and `images` uploads
images. What remains are project objects CAPO only references: flavors for the size catalog, the external
network and an SSH key pair.

## Considered options

1. `providers/selectel` with OpenTofu servers in the normalized node contract, like `providers/proxmox`.
2. `providers/selectel` with the Cluster API prerequisites only, returning the `openstack` input of
   `capi-cluster`.

## Decision outcome

Option 2.

- Provider `terraform-provider-openstack/openstack` only; `selectel/selectel` belongs to `bootstrap`.
- Private flavors `PREFIX-CLUSTER-SIZE` per size of the Selectel pools with disk 0 (root disk is a volume of
  `volume_type`); existing flavors can be used instead.
- The external network is looked up by name at plan time.
- An optional key pair for kubeadm nodes; rejected for Talos.
- Output `capi_openstack`, merged with `identity_secret` into the `openstack` input of `capi-cluster`.

### Consequences

- No servers are managed by OpenTofu in Selectel; static nodes would need the `opentofu` mechanism in the matrix
  and a separate decision.
- Flavor names include the cluster, so several clusters share a project without name conflicts.
- Changing the size catalog replaces the flavors; existing machines keep running until Cluster API rolls them.
