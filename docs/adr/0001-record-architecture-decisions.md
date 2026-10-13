# 0001. Record architecture decisions

- Status: accepted
- Date: 2026-10-14

## Context and problem statement

Decisions about module boundaries, contracts and mechanisms need to be traceable for contributors and
for people adopting the platform.

## Decision outcome

Record decisions as [MADR](https://adr.github.io/madr/) files in `docs/adr/`, numbered
`NNNN-title.md`, with status `proposed`, `accepted`, `deprecated` or `superseded by NNNN`.
A pull request that changes architecture or a contract adds or updates an ADR.

### Consequences

- Decisions and their reasons are reviewable in the same pull request as the change.
- Platform-wide decisions live in the [docs](https://github.com/sogeor/docs) repository; this directory keeps
  module-specific ones.
