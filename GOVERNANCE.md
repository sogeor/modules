# Governance

## Model

`modules` is part of the sogeor platform and follows a single-maintainer model.
The maintainer makes final decisions on scope, design and releases. Significant design
decisions are recorded as ADRs in [`docs/adr/`](docs/adr/index.md); platform-wide decisions live in the
[docs](https://github.com/sogeor/docs) repository.

Anyone may propose changes through issues and pull requests. Proposals are accepted when they
fit the [roadmap](ROADMAP.md), pass all required checks and follow [CONTRIBUTING.md](CONTRIBUTING.md).

## Roles

| Role | Who | Responsibilities |
|---|---|---|
| Maintainer | [@bloogefest](https://github.com/bloogefest) | Reviews and merges pull requests; triages issues; handles vulnerability reports ([SECURITY.md](SECURITY.md)); creates `modules-vX.Y.Z` tags and releases; manages branch rules and repository settings; keeps the roadmap and documentation current. |
| Contributor | Anyone | Opens issues and pull requests that follow [CONTRIBUTING.md](CONTRIBUTING.md). |
| Renovate (bot) | Mend Renovate | Opens dependency update pull requests; never merges. |

## Decisions

- Routine changes: merged by the maintainer once required checks pass.
- Architectural changes and contract changes: an ADR in `docs/adr/` is added in the same pull request.
- Breaking changes to module inputs or outputs: a major version bump and a migration note in `CHANGELOG.md`.
- Security fixes: handled privately per [SECURITY.md](SECURITY.md).

## Continuity

The organization `sogeor` owns the repository. If the maintainer becomes unavailable, an
organization owner can take over the maintainer role.
