#!/usr/bin/env bash
# Renders talos-cluster patches offline (tofu console) and validates the patched configs with talosctl.
set -euo pipefail

readonly RENDER="modules/talos-cluster/tests/render"
readonly CONTRACT="v1.14"
readonly KUBERNETES="1.37.1"

main() {
  local check role base failed=0
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' EXIT

  TF_DATA_DIR="${tmp}/tf" tofu -chdir="${RENDER}" init -backend=false -input=false -no-color >/dev/null
  TF_DATA_DIR="${tmp}/tf" tofu -chdir="${RENDER}" console -no-color <<<'jsonencode(local.checks)' >"${tmp}/checks.raw"

  python3 - "${tmp}" <<'PY'
import json, pathlib, sys
out = pathlib.Path(sys.argv[1])
checks = json.loads(json.loads((out / "checks.raw").read_text()))
for name, check in checks.items():
    (out / f"{name}.role").write_text(check["role"])
    (out / f"{name}.yaml").write_text("---\n".join(check["patches"]))
PY

  talosctl gen config check https://203.0.113.10:6443 \
    --talos-version "${CONTRACT}" --kubernetes-version "${KUBERNETES}" -o "${tmp}/base" >/dev/null 2>&1

  for check in "${tmp}"/*.role; do
    check="${check%.role}"
    role="$(<"${check}.role")"
    base="${tmp}/base/${role}.yaml"
    [[ "${role}" == "controlplane" ]] || base="${tmp}/base/worker.yaml"
    if talosctl machineconfig patch "${base}" --patch "@${check}.yaml" -o "${check}.out" \
      && talosctl validate --config "${check}.out" --mode metal >/dev/null; then
      echo "ok: $(basename "${check}") (${role})"
    else
      echo "::error::$(basename "${check}") is not a valid Talos ${role} configuration"
      failed=1
    fi
  done
  return "${failed}"
}

main "$@"
