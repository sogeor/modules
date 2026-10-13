# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[SemVer](https://semver.org/). Releases are tagged `modules-vX.Y.Z`.

## [Unreleased]

### Added

- Repository scaffold: community files, pre-commit, Renovate, issue and pull request templates.
- CI: `validate` (linters, reusable `security-lite`), `docs` and `scorecard` from
  [sogeor/workflows](https://github.com/sogeor/workflows) v0.1.1, pinned by commit SHA.
- Renovate waits 7 days after a release before proposing it (`minimumReleaseAge`); security updates are not delayed.
- Documentation skeleton to the platform standard and MkDocs site; ADR 0001 (record decisions) and
  ADR 0002 (repository layout).
