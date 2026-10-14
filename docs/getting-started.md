# Getting started

Goal: run all repository checks locally, validate a cluster description and consume a module.

## Requirements

| Tool | Version | Used for |
|---|---|---|
| Linux or WSL (x86_64) | Ubuntu 24.04 recommended | `tools/*.sh` |
| Git | any recent | clone, pre-commit |
| Python | 3.12 | pre-commit, check-jsonschema, yamllint, zizmor, MkDocs |
| pre-commit | 4.x | hooks in `.pre-commit-config.yaml` |
| Node.js | 20+ | markdownlint-cli2 hook |
| OpenTofu, tflint, Conftest, terraform-docs | pinned in `tools/install-tools.sh` | modules, tests, policies |

## 1. Clone and install tools

```bash
git clone https://github.com/sogeor/modules.git
cd modules
python3 -m pip install --user pre-commit
python3 -m pip install --user --require-hashes -r .github/requirements-lint.txt
tools/install-tools.sh "$HOME/.local/bin"
pre-commit install
```

`tools/install-tools.sh` downloads OpenTofu, tflint, Conftest and terraform-docs and verifies their SHA-256
checksums; it stops on a mismatch.

Check: `tofu version` prints the version from `tools/install-tools.sh`.

## 2. Run the checks

```bash
pre-commit run --all-files
tools/check-modules.sh
tools/check-schema.sh
conftest verify --policy policies/conftest/cluster --data modules/cluster-spec/matrix.yaml
```

Expected: every hook `Passed`; `Success! N passed, 0 failed.` for each module; `ok: … rejected` for each invalid
schema fixture; `0 failures` from Conftest.

## 3. Validate a cluster description

```bash
cp clusters/talos.yaml clusters/lab.yaml
# edit cluster, cluster_id and pools
check-jsonschema --schemafile schemas/cluster.schema.json clusters/lab.yaml
conftest test --policy policies/conftest/cluster --data modules/cluster-spec/matrix.yaml clusters/lab.yaml
```

Expected: `ok -- validation done` and `0 failures`. Each failure starts with the rule id, for example
`[os-distribution]`; the rules are listed in [Configuration](configuration.md#rules).

## 4. Build the documentation

```bash
python3 -m pip install --user --require-hashes -r .github/requirements-docs.txt
mkdocs build --strict
```

Expected: `Documentation built in … seconds` without warnings.

## 5. Consume a module

```hcl
module "spec" {
  source = "git::https://github.com/sogeor/modules.git//modules/cluster-spec?ref=modules-v0.1.0"

  cluster = yamldecode(file("${path.root}/clusters/main.yaml"))
}
```

The double slash separates the repository from the module path. Pin the tag; Renovate in the
consuming repository updates it.

## If something fails

See [Troubleshooting](troubleshooting.md).
