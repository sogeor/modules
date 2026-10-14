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

## Renovate does not update a Python lock file

- **Cause:** the pip-compile header is missing or contains `--no-index`.
- **Fix:** regenerate the file as described in [Operations](operations.md#update-locked-python-dependencies).
