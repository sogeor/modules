<!-- markdownlint-disable-file MD041 -->
## Summary

<!-- what and why -->

## Checks

- [ ] `tofu fmt -check`, `tofu validate`, `tofu test` for affected modules
- [ ] tflint, Checkov, Conftest policies and fixtures
- [ ] yamllint, actionlint, zizmor
- [ ] gitleaks: no secrets, no personal values (addresses, domains, IDs)
- [ ] Versions pinned exactly (README → Versions)
- [ ] Module README (terraform-docs), `docs/configuration.md`, CHANGELOG updated
- [ ] Contracts (cluster description, node, inventory) unchanged, or the change is agreed and has an ADR
- [ ] Both topologies (`single`, `ha`) covered where applicable
