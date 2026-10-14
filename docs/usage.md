# Usage

Typical tasks. Module-specific tasks are added with each module.

## Check a change locally

1. Run the hooks:

    ```bash
    pre-commit run --all-files
    ```

2. Build the documentation:

    ```bash
    mkdocs build --strict
    ```

Expected: all hooks `Passed`, the site builds without warnings.

## Pin a module in a consuming repository

```hcl
module "nodes" {
  source = "git::https://github.com/sogeor/modules.git//modules/providers/proxmox?ref=modules-v0.1.0"
}
```

- Always pin a `modules-vX.Y.Z` tag, never a branch.
- Read the module section in `CHANGELOG.md` before moving to a new major version.

## Describe a new cluster

Goal: a new description that passes every rule.

1. Copy the closest reference: `clusters/mgmt.yaml` (Talos on Proxmox VE, OpenTofu), `clusters/main.yaml`
   (kubeadm on Selectel with an Astra Linux pool at home, Cluster API) or `clusters/talos.yaml` (Talos on Selectel).
2. Change `cluster` and `cluster_id` (unique; it defines the CIDR), then the pools.
3. Validate:

    ```bash
    check-jsonschema --schemafile schemas/cluster.schema.json clusters/<name>.yaml
    conftest test --policy policies/conftest/cluster --data modules/cluster-spec/matrix.yaml clusters/<name>.yaml
    ```

Expected: no `FAIL` lines. `WARN [image-planned]` means the image for that pool is not built yet; the cluster
can be described, but `cluster-spec` refuses to deploy it until the image is available.
Fields: [Configuration](configuration.md#cluster-description); rules: [Configuration](configuration.md#rules).

## Use the normalized specification

```hcl
module "spec" {
  source  = "git::https://github.com/sogeor/modules.git//modules/cluster-spec?ref=modules-v0.1.0"
  cluster = yamldecode(file("${path.root}/clusters/mgmt.yaml"))
}

locals {
  pod_cidr = module.spec.spec.network.pod_cidr
  cp_pools = { for name, p in module.spec.spec.pools : name => p if p.role == "control-plane" }
}
```

An invalid description stops the plan at `module.spec.spec` with a list such as:

```text
The cluster description is invalid:
- [os-distribution] pool cp: os ubuntu-2404 is not allowed for distribution talos (allowed: talos)
```

## Create nodes on Proxmox VE

Goal: VMs for the Proxmox pools of a cluster created by OpenTofu (for example the management cluster).

Preconditions: a Proxmox API token with the privileges from [Configuration](configuration.md#proxmox-api-token);
for Ubuntu pools, a template from [images](https://github.com/sogeor/images) on the node; for Talos pools, the
schematic ID and ISO checksum.

```hcl
module "spec" {
  source  = "git::https://github.com/sogeor/modules.git//modules/cluster-spec?ref=modules-v0.1.0"
  cluster = yamldecode(file("${path.root}/clusters/mgmt.yaml"))
}

module "nodes" {
  source = "git::https://github.com/sogeor/modules.git//modules/providers/proxmox?ref=modules-v0.1.0"

  spec      = module.spec.spec
  proxmox   = { node_name = var.proxmox_node, datastore_id = "local-lvm", bridge = "vmbr0" }
  network   = { prefix_length = 24, gateway = var.gateway, dns_servers = [var.gateway], domain = var.domain }
  addresses = { cp = var.cp_addresses }
  talos     = var.talos
}
```

Expected after apply: one VM per node, named `<cluster>-<pool>-<index>`, running, with the given address;
`module.nodes.nodes` lists them in the node contract. Talos VMs wait in maintenance mode until `talos-cluster`
applies the configuration.

Check: in the Proxmox web UI the VMs carry the tags `sogeor`, the cluster and the pool name.

## Create a Talos cluster on Proxmox VE

Goal: a working Talos cluster (for example `mgmt`) from one description.

Preconditions: everything from [Create nodes on Proxmox VE](#create-nodes-on-proxmox-ve); OpenTofu 1.11+;
network access from the machine running OpenTofu to the node addresses (port 50000 for the Talos API, 6443 for
Kubernetes) and to `helm.cilium.io`.

1. Copy `modules/talos-cluster/examples/proxmox` into the consuming repository, set `cluster.yaml` and
   `terraform.tfvars` (from `terraform.tfvars.example`).
2. Plan and apply in the consuming repository.

Expected: VMs boot the Talos ISO, receive the configuration, install Talos on the disk and reboot; etcd is
bootstrapped; nodes become `Ready` once Cilium starts. Takes about 5–10 minutes for one node.

Check:

```bash
tofu output -raw talosconfig > talosconfig && export TALOSCONFIG=$PWD/talosconfig
talosctl health
tofu output -raw kubeconfig > kubeconfig && kubectl --kubeconfig kubeconfig get nodes -o wide
```

Expected: `talosctl health` passes every check; every node is `Ready`. Delete the local `talosconfig` and
`kubeconfig` files after copying them to OpenBao.

## Register BYO servers and build the Ansible inventory

Goal: existing servers (and VMs from other providers) listed in an Ansible inventory with the platform groups.

Preconditions: the servers accept SSH with a key for the first user; the cluster description has pools with
`provider: byo` and matching `count`.

1. List the servers per pool in `providers/byo` (`hosts`), merge the nodes of all providers into
   `ansible-inventory` (see `modules/ansible-inventory/examples/mixed`).
2. Apply in the consuming repository.
3. Create the inventory plugin file from [Configuration](configuration.md#inventory-plugin-file) and check:

    ```bash
    ansible-galaxy collection install cloud.terraform
    ansible-inventory -i inventory.terraform.yml --graph
    ```

Expected: groups `cluster_<name>`, `role_*`, `site_*`, `os_*`, `mesh`, `internet` with the hosts; Talos nodes are
absent. `tofu output` of `bootstrap_hosts` lists servers still reached by their public address.

## Move a server behind the mesh

Goal: Ansible reaches a server outside `home` through the mesh, so the `internet` hardening can close public SSH.

1. Join the server to the mesh (role `tailscale` in the `ansible` repository) and note its mesh address.
2. Add it to `mesh_addresses` (`{ <node name> = "<mesh address>" }`) and apply.

Check: the server is no longer in `bootstrap_hosts`; `ansible -i inventory.terraform.yml <node name> -m ping`
succeeds through the mesh. Only then apply the hardening that closes public SSH.

## Mark an image as available

When [images](https://github.com/sogeor/images) builds a new (OS, provider) image, change its status in
`modules/cluster-spec/matrix.yaml` from `planned` to `available`, update the matrix table in
[Configuration](configuration.md#compatibility-matrix) and add a CHANGELOG entry.

## Add an OS, provider or size

1. Add it to `modules/cluster-spec/matrix.yaml`.
2. Add the same value to the enum in `schemas/cluster.schema.json` (`tools/check-schema.sh` fails otherwise).
3. Add tests to `modules/cluster-spec/tests/` and `policies/conftest/cluster/cluster_test.rego`.
4. Update [Configuration](configuration.md) and open a pull request with an ADR if the contract changes.
