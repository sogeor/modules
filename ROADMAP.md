# Roadmap

Horizon: through Q4 2027. Order follows the sogeor platform plan.

## Planned

- Cluster description: JSON Schema, the `cluster-spec` module with all compatibility checks, Conftest policies,
  reference descriptions `mgmt`, `main` and `talos`.
- `providers/proxmox`: nodes from tagged templates of [images](https://github.com/sogeor/images) and Talos
  Image Factory images.
- SecureBoot for Talos VMs on Proxmox VE (Image Factory SecureBoot ISO, key enrollment), so TPM disk encryption
  reaches full strength.
- `providers/byo`: registration of existing servers; `ansible-inventory` for Ansible roles.
- `capi-cluster`: Cluster API manifests (Cluster, control plane, MachineDeployment, MachineHealthCheck,
  Cluster Autoscaler bounds) for Talos and kubeadm on Proxmox VE and OpenStack.
- `providers/selectel` and OpenStack networking for cloud clusters.
- `mesh-registration` (Headscale pre-auth keys), `dns-records`, `cloudflare-apps`.
- k3s distribution, Yandex Cloud, VK Cloud and Timeweb providers.

## Not planned

- Root modules with state: they live in `management`.
- Applying Cluster API manifests: Argo CD in the management cluster does it.
- Providers without a module implementation (no empty placeholders).
