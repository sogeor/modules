# Troubleshooting

Symptom → cause → fix. Entries are added from real failures.

## Required status check is missing in the ruleset

- **Cause:** checks appear in **Add checks** only after they have run once.
- **Fix:** open a pull request, wait for `validate` and `docs`, then add the checks.

## Scorecard: `workflow verification failed` when publishing

- **Cause:** the Scorecard API checks the caller workflow: no top-level `env:` or `defaults:`, no write
  permissions at workflow level, `id-token: write` only on the Scorecard job.
- **Fix:** keep `scorecard.yml` as shipped (`permissions: {}` at the top, permissions on the job).

## lychee reports 503 or 504 for `github.com/.../blob/...` links

- **Cause:** github.com throttles GitHub-hosted runners.
- **Fix:** nothing; the reusable `docs` workflow checks such links through raw.githubusercontent.com and
  accepts temporary statuses.

## `tools/check-modules.sh`: `README.md is out of date`

- **Cause:** module inputs or outputs changed without regenerating the module README.
- **Fix:** from the module directory run `terraform-docs --config ../../.terraform-docs.yml .`, commit the README.

## `tools/check-schema.sh`: `enum … differs from modules/cluster-spec/matrix.yaml`

- **Cause:** a value was added to the matrix or to the schema, not to both.
- **Fix:** add the same value to both files, see [Usage](usage.md#add-an-os-provider-or-size).

## A Conftest rule stops matching after `conftest fmt`

- **Cause:** `conftest fmt` removes parentheses around `x in y`, so `("a" in s) == ("b" in s)` becomes a
  different expression.
- **Fix:** express such conditions as separate rules with helper functions (see `has_field` in
  `policies/conftest/cluster/cluster.rego`) and keep a test for each rule.

## Plan fails with `The cluster description is invalid`

- **Cause:** the description breaks a compatibility rule; the message lists each rule id.
- **Fix:** look the rule up in [Configuration](configuration.md#rules). For `image-planned`, wait for the image
  or set `allow_planned_images = true` only for a test environment.

## providers/proxmox: `No template on node … has the tags …`

- **Cause:** no template with all the tags exists on that node, or its name does not end in `-v<run>-<attempt>`
  (local builds such as `-vtest` are ignored); for kubeadm the `k8s-<major>-<minor>` tag must match
  `kubernetes_version`.
- **Fix:** build the image in [images](https://github.com/sogeor/images) for that Kubernetes version, or align
  `kubernetes_version` with the newest template.

## providers/proxmox: `401`, `403` or `501` from the Proxmox API

- **Cause:** the token lacks a privilege, or a token with privilege separation has no ACL entry of its own.
- **Fix:** grant the role from [Configuration](configuration.md#proxmox-api-token) to the token itself
  (`pveum aclmod / -token '<user>!<token>' -role <role>`).

## providers/proxmox: checksum mismatch when downloading the Talos ISO

- **Cause:** `talos.iso_sha256` belongs to another schematic or version.
- **Fix:** recompute it with the command in [Configuration](configuration.md#providersproxmox) for the exact schematic and version.

## talos-cluster: `… is incompatible with v1alpha1 config` or `already set in v1alpha1 config`

- **Cause:** a patch uses the old v1alpha1 fields (`machine.install`, `cluster.network`, `cluster.proxy`) while the
  config contract `v1.14` generates the new documents.
- **Fix:** patch the document that replaced the field (`UnattendedInstallConfig`, `KubeNetworkConfig`,
  `KubeProxyConfig`, …); `tools/check-talos.sh` reproduces the error offline.

## talos-cluster: `the following document kinds are only allowed on control plane machines`

- **Cause:** a control-plane-only document (`KubeProxyConfig`, inline manifests, VIP) reached a worker patch.
- **Fix:** keep such documents in the control-plane list of `modules/talos-cluster/config`.

## talos-cluster: apply waits on `talos_machine` and times out

- **Cause:** the node is not reachable on port 50000, or it booted from the disk before Talos was installed.
- **Fix:** check that the VM shows the Talos maintenance screen with the expected address in the Proxmox
  console, and that the machine running OpenTofu reaches `<address>:50000`.

## talos-cluster: nodes stay `NotReady`

- **Cause:** Cilium did not start (chart values, image pull) — without a CNI nodes are never ready.
- **Fix:** `kubectl -n kube-system get pods -l k8s-app=cilium` and the pod logs; `talosctl get manifests` lists
  the inline manifests Talos applied.

## Ansible inventory is empty

- **Cause:** the `cloud.terraform.terraform_provider` plugin reads only the root module unless
  `search_child_modules: true` is set; or the root module is not initialized.
- **Fix:** use the plugin file from [Configuration](configuration.md#inventory-plugin-file) and run `tofu init` in
  `project_path`.

## providers/byo: `The number of hosts must equal the pool count`

- **Cause:** the `hosts` list of a pool and its `count` in the cluster description differ.
- **Fix:** add or remove hosts, or change `count`, so both match.

## cluster-spec: `[capi-single-provider]`

- **Cause:** a cluster with mechanism `capi` has pools on several providers; a CAPI `Cluster` has one
  infrastructure provider.
- **Fix:** move the pools of the other provider into a separate cluster description (as `clusters/astra.yaml`).

## capi-cluster: `images.builds needs a build for every pool OS`

- **Cause:** Proxmox templates and OpenStack Ubuntu images are selected by their exact build.
- **Fix:** set `images.builds` to the build published by [images](https://github.com/sogeor/images), for example
  `{ ubuntu-2404 = "v20-1" }`.

## Cluster API: machines are `Provisioning` forever on Proxmox VE

- **Cause:** no template carries exactly the tag set of the images contract (`matchPolicy: exact`), or the
  address range is exhausted.
- **Fix:** compare the tags of the template in the Proxmox web UI with `templateSelector.matchTags` in the
  manifest; check `kubectl -n <cluster> get proxmoxmachines` and the CAPMOX logs.

## Cluster API: nodes stay `NotReady` and are replaced by the health check

- **Cause:** the manifests contain no CNI; Argo CD has not installed Cilium yet (and on OpenStack the cloud
  controller manager that removes the `uninitialized` taint).
- **Fix:** make sure the cluster is registered in Argo CD and the Cilium and CCM applications sync; the health
  check replaces a node that is not `Ready` for 15 minutes.

## Renovate does not update a Python lock file

- **Cause:** the pip-compile header is missing or contains `--no-index`.
- **Fix:** regenerate the file as described in [Operations](operations.md#update-locked-python-dependencies).

## Tunnel hostname returns an error

- **Error 1033** — **cause:** no `cloudflared` is connected; **fix:** check that the pod runs with the current
  `tunnel_token` (it changes when the tunnel is recreated) and can reach Cloudflare on outbound port 7844.
- **502 Bad Gateway** — **cause:** `cloudflared` cannot reach `service`; **fix:** check the in-cluster address,
  port and NetworkPolicy egress from `cloudflared`; for an HTTPS origin set `origin_server_name` to a name in
  its certificate.
- **404** — **cause:** no rule matches the hostname and path; **fix:** check `tofu output ingress`.
