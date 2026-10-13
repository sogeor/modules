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

Copy a reference description from `clusters/` (added with `cluster-spec`), change `cluster`,
`cluster_id` and pools, and run the validation. Fields: [Configuration](configuration.md#cluster-description).
