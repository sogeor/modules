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

## Renovate does not update a Python lock file

- **Cause:** the pip-compile header is missing or contains `--no-index`.
- **Fix:** regenerate the file as described in [Operations](operations.md#update-locked-python-dependencies).
