# Operations

Runbooks for maintaining the repository.

## Release a version

Goal: publish a tag that consumers can pin.

1. Move the `[Unreleased]` entries in `CHANGELOG.md` under `## [X.Y.Z] - YYYY-MM-DD` in a pull request
   `chore: release X.Y.Z`; merge it.
2. Tag the merge commit (signed) and push the tag:

    ```bash
    git switch master && git pull
    git tag -s modules-vX.Y.Z -m "modules-vX.Y.Z"
    git push origin modules-vX.Y.Z
    ```

3. **Releases → Draft a new release:** tag `modules-vX.Y.Z`, notes from the CHANGELOG section.

Check: the release page shows the tag; `git ls-remote --tags origin` lists it.

Versioning: a removed or renamed input or output, or a changed contract, is a major version.

## Update dependencies

Renovate opens pull requests. After merging one, update the **Versions** table in `README.md`.
For `actionlint`, update `ACTIONLINT_VERSION` and `ACTIONLINT_SHA256` in `validate.yml` together
(the SHA-256 is listed in the release `checksums.txt`).

## Update locked Python dependencies

Lock files are generated from the repository root with Python 3.12 and pip-tools:

```bash
python3 -m pip install --user pip==25.2 pip-tools==7.5.1
python3 -m piptools compile --quiet --generate-hashes --allow-unsafe --strip-extras \
  -o .github/requirements-lint.txt .github/requirements-lint.in
python3 -m piptools compile --quiet --generate-hashes --allow-unsafe --strip-extras \
  -o .github/requirements-docs.txt .github/requirements-docs.in
```

- Keep the generated header: Renovate reruns the command from it.
- If the header contains `--no-index` (local pip configuration), remove it.
- Add `--upgrade` only to refresh transitive dependencies on purpose; review `git diff` afterwards.

## Roll back a release

Consumers pin tags, so a faulty release is fixed by a new patch release. Do not move or delete
published tags.
