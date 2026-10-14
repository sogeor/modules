#!/usr/bin/env bash
# Usage: tools/install-tools.sh <dir>
set -euo pipefail

readonly TOFU_VERSION="1.13.1"
readonly TOFU_SHA256="378ada19d4bc70c43732004e8159be771b23b9a5afdf059e5f8a2b3fa2c70a69"
readonly TFLINT_VERSION="0.64.0"
readonly TFLINT_SHA256="cca9d13e2e1d7a2c627af60ff899a3c9b74212899416aeb96ec764d2ef954537"
readonly CONFTEST_VERSION="0.71.1"
readonly CONFTEST_SHA256="c3f6b2a753bd56e377a1e51a95ae3e057f926f2e9139f7d5b5dfbbaf810f7985"
readonly TFDOCS_VERSION="0.24.0"
readonly TFDOCS_SHA256="9005daf969de0b50134493a2c00078b49f5f5b39d021cda7c89bf4d4f3d776d3"

fetch() {
  local url="$1" sha="$2" out="$3"
  curl -fsSL --retry 5 -o "${out}" "${url}"
  echo "${sha}  ${out}" | sha256sum -c --quiet -
}

main() {
  local dest="${1:?destination directory required}"
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' EXIT
  mkdir -p "${dest}"

  fetch "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_linux_amd64.tar.gz" \
    "${TOFU_SHA256}" "${tmp}/tofu.tgz"
  tar -xzf "${tmp}/tofu.tgz" -C "${dest}" tofu

  fetch "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_amd64.zip" \
    "${TFLINT_SHA256}" "${tmp}/tflint.zip"
  python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extract("tflint", sys.argv[2])' "${tmp}/tflint.zip" "${dest}"

  fetch "https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz" \
    "${CONFTEST_SHA256}" "${tmp}/conftest.tgz"
  tar -xzf "${tmp}/conftest.tgz" -C "${dest}" conftest

  fetch "https://github.com/terraform-docs/terraform-docs/releases/download/v${TFDOCS_VERSION}/terraform-docs-v${TFDOCS_VERSION}-linux-amd64.tar.gz" \
    "${TFDOCS_SHA256}" "${tmp}/tfdocs.tgz"
  tar -xzf "${tmp}/tfdocs.tgz" -C "${dest}" terraform-docs

  chmod +x "${dest}"/{tofu,tflint,conftest,terraform-docs}
}

main "$@"
