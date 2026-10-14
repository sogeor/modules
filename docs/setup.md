# Repository setup

How to set up this repository (or your fork) so that checks, dependency updates and security
features work. Steps are in order; each ends with a check. The repository needs no Environments and
no infrastructure credentials: modules are only tested with mock providers.

!!! note "Placeholders"
    `<owner>` is your GitHub organization or user. Replace it with your value.

## Repository settings

### About

**Repository → ⚙ next to About** (right column on the main page):

| Field | Value |
|---|---|
| Description | `OpenTofu modules and generators of the sogeor cluster constructor: one validated cluster description, provider modules with a common node contract, Talos and Cluster API outputs.` |
| Website | empty until the documentation site exists |
| Topics | `opentofu` `terraform-modules` `infrastructure-as-code` `kubernetes` `cluster-api` `talos` `proxmox` `openstack` `ansible` `json-schema` `policy-as-code` `devsecops` `platform-engineering` |
| Include in the home page | Releases — on after the first release; Deployments — off; Packages — off |

When typing topics, finish each with **Space**: Enter picks the highlighted suggestion instead.

### Pull requests

**Settings → General → Pull Requests:**

- Allow merge commits — off; Allow squash merging — on; Allow rebase merging — off.
- Automatically delete head branches — on.

### Branch ruleset

**Settings → Rules → Rulesets → New ruleset → New branch ruleset:**

| Setting | Value |
|---|---|
| Ruleset Name | `master` |
| Enforcement status | Active |
| Bypass list | **Add bypass → Repository admin**, mode **For pull requests only** |
| Target branches | **Add target → Include default branch** |
| Restrict deletions | on |
| Require signed commits | on |
| Require a pull request before merging | on, Required approvals `0` |
| Require status checks to pass | on, **Require branches to be up to date**; checks `linters`, `opentofu`, `policies`, `security / gitleaks`, `security / trivy`, `security / semgrep`, `security / checkov`, `docs / docs` |
| Block force pushes | on |

Status checks appear in **Add checks** only after they have run at least once.

Check: a direct `git push` to `master` is rejected with `GH013: Repository rule violations`.

### Advanced Security

**Settings → Advanced Security:**

| Feature | Setting |
|---|---|
| Private vulnerability reporting | Enable; Require a CWE — off; Daily advisory limit — 10 |
| Dependency graph | On |
| Dependabot alerts | On |
| Malware alerts | On |
| Dependabot security updates, version updates | Off — Renovate updates dependencies |
| CodeQL analysis | **Set up → Default** (analyzes GitHub Actions workflows) |
| Code quality | Off |
| Secret Protection | Enable, then **Push protection → Enable** |

Check: the **Security** tab shows **Report a vulnerability**.

## Repository secret for Scorecard

1. **Profile → Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token:**
   owner `<owner>`, only this repository, **Administration: Read-only**, expiration 1 year.
2. **Repository → Settings → Secrets and variables → Actions → New repository secret:** `SCORECARD_TOKEN`.

Check: after the next push to `master` the **scorecard** run succeeds and the Branch-Protection check reflects the ruleset.

## Renovate

1. Install the [Renovate GitHub App](https://github.com/apps/renovate) → **Configure** → `<owner>` →
   **Only select repositories** → this repository.
2. The configuration is already in `renovate.json`: no automerge, a 7-day minimum release age for every
   update (security fixes bypass it), Conventional Commit titles, grouped
   updates (GitHub Actions, Python tools, OpenTofu providers, pre-commit hooks), SHA-pinned pre-commit hooks,
   hash-locked Python requirements.

Check: an issue **Dependency Dashboard** appears within an hour.

After merging a Renovate pull request, update the **Versions** table in `README.md`.

## OpenSSF Best Practices (optional)

Register the repository at [bestpractices.dev](https://www.bestpractices.dev), answer the criteria in
English with full URLs in "Met URL" fields, and add the badge to `README.md`.

## Local tools

See [Getting started](getting-started.md#1-clone-and-install-tools).
