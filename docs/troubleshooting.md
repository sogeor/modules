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

## Renovate does not update a Python lock file

- **Cause:** the pip-compile header is missing or contains `--no-index`.
- **Fix:** regenerate the file as described in [Operations](operations.md#update-locked-python-dependencies).
