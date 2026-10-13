# Contributing

## Process

1. Open an [issue](https://github.com/sogeor/modules/issues) for bugs and feature requests
   (English or Russian). Report vulnerabilities privately per [SECURITY.md](SECURITY.md).
2. Create a branch `feat/...`, `fix/...`, `docs/...` or `chore/...` and open a pull request to `master`.
3. Requirements for a pull request to be accepted:
   - [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) title (pull requests are squash-merged);
   - signed commits;
   - all required checks green;
   - `README.md`, the module README, [`docs/configuration.md`](docs/configuration.md) and `CHANGELOG.md`
     updated when inputs, outputs or behavior change;
   - an ADR in [`docs/adr/`](docs/adr/index.md) (status `proposed`) for architectural changes and for any
     change of a contract (cluster description, node, inventory).

By contributing you agree that your contribution is licensed under [Apache-2.0](LICENSE).

## Tests

- Every module has `examples/` and `tests/` run by `tofu test` with mock providers; no test touches real infrastructure.
- Every validation rule of the cluster description has a passing and a failing case.
- Fixed defects get a test that would have caught them.

## Coding standards

| Language | Standard | Enforced by |
|---|---|---|
| OpenTofu | `versions.tf` with exact provider versions, `variables.tf` (every variable has `type`, `description`, `validation` where values are restricted), `outputs.tf` (every output has `description`), `for_each` over `count`, `moved`/`removed` blocks instead of state edits | `tofu fmt -check`, `tofu validate`, tflint, Checkov |
| Rego | One package per rule set, tests next to policies | `conftest verify` |
| YAML | 2-space indent, `.yamllint` | `yamllint --strict` |
| Shell | [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html); `#!/usr/bin/env bash`, `set -euo pipefail` | `shellcheck` |
| GitHub Actions | Actions pinned by full SHA with a version comment, minimal `permissions`, `persist-credentials: false` | `actionlint`, `zizmor` |

All documentation, comments and messages are in English. Examples use `example.com` and
`203.0.113.0/24` (RFC 5737); never commit real addresses, domains, IDs or credentials.

## Local setup

```bash
git clone https://github.com/sogeor/modules.git
cd modules
pre-commit install
pre-commit run --all-files
```

Requires Python 3.12 and `pre-commit`. Tool versions: [README → Versions](README.md#versions).
Python dependencies are hash-locked; to change one, edit the `.in` file and regenerate the lock file as
described in [Operations](docs/operations.md#update-locked-python-dependencies).
