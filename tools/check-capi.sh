#!/usr/bin/env bash
# Renders capi-cluster scenarios offline (tofu console) and validates them with kubeconform against provider CRDs.
set -euo pipefail

readonly RENDER="modules/capi-cluster/tests/render"

readonly KUBECONFORM_VERSION="0.8.0"
readonly KUBECONFORM_SHA256="9bc2bffbf71f261128533edaf912153948b7ff238f9a531ae6d34466ec287883"

# name|url|sha256
readonly CRDS=(
  "capi-core|https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.14.3/core-components.yaml|f70be959af4aba061b91cb264b3b1961ae38ca49e2eb542ccf2640146f5221a7"
  "capi-kubeadm-bootstrap|https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.14.3/bootstrap-components.yaml|537d6db3b70aad723710825f76073659865dc1a115715ef5d5c470da3b9bcc39"
  "capi-kubeadm-control-plane|https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.14.3/control-plane-components.yaml|a211e2e54b6b6fb93e59191f5db8ee76ad6ff92a698f1c62f9d6ce4d5218cf87"
  "capmox|https://github.com/ionos-cloud/cluster-api-provider-proxmox/releases/download/v0.9.1/infrastructure-components.yaml|424fb38189659147df452490bb2b11f9f4ae3a75c7179b92a85041658bfd74d5"
  "capo|https://github.com/kubernetes-sigs/cluster-api-provider-openstack/releases/download/v0.15.0/infrastructure-components.yaml|3935869a07aefd038a0c77ca23819759e6fa0afd273e6091e8a3c6bdb96d7d40"
  "cabpt|https://github.com/siderolabs/cluster-api-bootstrap-provider-talos/releases/download/v0.6.13/bootstrap-components.yaml|1e721ad294bdd5c8994aa957017cb94ad6e0cfd4ba52a52b45ed456d93efd4f8"
  "cacppt|https://github.com/siderolabs/cluster-api-control-plane-provider-talos/releases/download/v0.5.14/control-plane-components.yaml|5b4e7830c9ce38a6a9b55cd7b7aa20e302cc25db714b81d512436ac94bc49ea4"
)

fetch() {
  local url="$1" sha="$2" out="$3"
  curl -fsSL --retry 5 -o "${out}" "${url}"
  echo "${sha}  ${out}" | sha256sum -c --quiet -
}

main() {
  local entry name url sha scenario failed=0
  local -a crd_files=()
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' EXIT

  fetch "https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz" \
    "${KUBECONFORM_SHA256}" "${tmp}/kubeconform.tgz"
  tar -xzf "${tmp}/kubeconform.tgz" -C "${tmp}" kubeconform

  for entry in "${CRDS[@]}"; do
    IFS='|' read -r name url sha <<<"${entry}"
    fetch "${url}" "${sha}" "${tmp}/${name}.yaml"
    crd_files+=("${tmp}/${name}.yaml")
  done
  python3 tools/crd-schemas.py "${tmp}/schemas" "${crd_files[@]}" >/dev/null

  TF_DATA_DIR="${tmp}/tf" tofu -chdir="${RENDER}" init -backend=false -input=false -no-color >/dev/null
  TF_DATA_DIR="${tmp}/tf" tofu -chdir="${RENDER}" console -no-color <<<'jsonencode(local.manifests)' >"${tmp}/manifests.raw"

  python3 - "${tmp}" <<'PY'
import json, pathlib, sys
out = pathlib.Path(sys.argv[1])
for name, manifest in json.loads(json.loads((out / "manifests.raw").read_text())).items():
    (out / f"{name}.k8s.yaml").write_text(manifest)
PY

  for scenario in "${tmp}"/*.k8s.yaml; do
    if "${tmp}/kubeconform" -strict -summary \
      -schema-location default \
      -schema-location "${tmp}/schemas/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json" \
      "${scenario}"; then
      echo "ok: $(basename "${scenario}" .k8s.yaml)"
    else
      echo "::error::$(basename "${scenario}" .k8s.yaml) has invalid CAPI manifests"
      failed=1
    fi
  done
  return "${failed}"
}

main "$@"
