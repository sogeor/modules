#!/usr/bin/env bash
# Checks every module under modules/ and its examples; needs tools/install-tools.sh on PATH.
set -euo pipefail

readonly ROOT="${PWD}"
readonly DATA_ROOT="${RUNNER_TEMP:-/tmp}/tfdata"

init_validate() {
  local dir="$1"
  local data_dir="${DATA_ROOT}/${dir//\//_}"
  TF_DATA_DIR="${data_dir}" tofu -chdir="${dir}" init -backend=false -input=false -no-color >/dev/null
  TF_DATA_DIR="${data_dir}" tofu -chdir="${dir}" validate -no-color
}

check_module() {
  local dir="$1"
  init_validate "${dir}"
  tflint --chdir="${dir}" --config "${ROOT}/.tflint.hcl" --format compact
  if [[ -d "${dir}/tests" ]]; then
    TF_DATA_DIR="${DATA_ROOT}/${dir//\//_}" tofu -chdir="${dir}" test -no-color
  fi
  terraform-docs --config "${ROOT}/.terraform-docs.yml" --output-check "${dir}"
}

main() {
  local dir example
  local -a module_dirs

  tflint --init --config "${ROOT}/.tflint.hcl" >/dev/null
  tofu fmt -check -recursive -diff .

  mapfile -t module_dirs < <(find modules -name versions.tf -not -path '*/examples/*' -printf '%h\n' | sort)

  for dir in "${module_dirs[@]}"; do
    echo "::group::${dir}"
    check_module "${dir}"
    for example in "${dir}"/examples/*/; do
      if [[ -d "${example}" ]]; then
        init_validate "${example%/}"
      fi
    done
    echo "::endgroup::"
  done
}

main "$@"
