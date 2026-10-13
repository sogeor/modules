# 0002. Repository layout: modules only, no root modules

- Status: accepted
- Date: 2026-10-14

## Context and problem statement

The repository holds reusable OpenTofu modules together with schemas, reference cluster descriptions,
policies and documentation. Root modules with state (`edge`, `mgmt`, DNS, Cloudflare) could live here or in
the `management` repository. Modules could sit at the repository root or in a subdirectory.

## Considered options

1. Modules at the root (`//cluster-spec`), root modules in `live/`.
2. Modules in `modules/` (`//modules/cluster-spec`), no root modules.

## Decision outcome

Option 2.

- Modules live in `modules/<name>` and are referenced as
  `git::https://github.com/sogeor/modules.git//modules/<name>?ref=modules-vX.Y.Z`.
- The repository has no root modules and no state; they live in `management`.

### Consequences

- Modules are separated from schemas, policies, descriptions and repository files.
- No credentials or state are ever needed here; CI runs with mock providers only.
- The path repeats the repository name (`modules/modules/...`), which is accepted for the clearer layout.
