# Getting started

Goal: run all repository checks locally and know how a module is consumed.

## Requirements

| Tool | Version | Used for |
|---|---|---|
| Git | any recent | clone, pre-commit |
| Python | 3.12 | pre-commit, yamllint, zizmor, MkDocs |
| pre-commit | 4.x | all hooks in `.pre-commit-config.yaml` |
| Node.js | 20+ | markdownlint-cli2 hook |

OpenTofu, tflint, Checkov and Conftest are added to this page together with the first module.

## 1. Clone and install tools

```bash
git clone https://github.com/sogeor/modules.git
cd modules
python3 -m pip install --user pre-commit
pre-commit install
```

## 2. Run the checks

```bash
pre-commit run --all-files
```

Expected: every hook reports `Passed`.

## 3. Build the documentation

```bash
python3 -m pip install --user --require-hashes -r .github/requirements-docs.txt
mkdocs build --strict
```

Expected: `Documentation built in … seconds` without warnings. `mkdocs serve` opens a preview on
`http://127.0.0.1:8000`.

## 4. Consume a module

Modules are referenced by Git tag from a root module:

```hcl
module "spec" {
  source = "git::https://github.com/sogeor/modules.git//modules/cluster-spec?ref=modules-v0.1.0"
}
```

The double slash separates the repository from the module path. Pin the tag; Renovate in the
consuming repository updates it.

## If something fails

See [Troubleshooting](troubleshooting.md).
