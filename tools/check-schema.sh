#!/usr/bin/env bash
# Valid: clusters/*.yaml. Invalid: schemas/tests/invalid/*.yaml must each fail.
set -euo pipefail

readonly SCHEMA="schemas/cluster.schema.json"
readonly MATRIX="modules/cluster-spec/matrix.yaml"

python3 - "${SCHEMA}" "${MATRIX}" <<'PY'
import json, sys, yaml

schema = json.load(open(sys.argv[1], encoding="utf-8"))
matrix = yaml.safe_load(open(sys.argv[2], encoding="utf-8"))["matrix"]
pool = schema["$defs"]["pool"]["properties"]
pairs = {
    "distribution": (schema["properties"]["distribution"]["enum"], matrix["distributions"]),
    "profiles": (schema["properties"]["profiles"]["items"]["enum"], matrix["profiles"]),
    "os": (pool["os"]["enum"], matrix["images"]),
    "provider": (pool["provider"]["enum"], matrix["providers"]),
    "size": (pool["size"]["enum"], matrix["sizes"]),
}
bad = [k for k, (a, b) in pairs.items() if set(a) != set(b)]
for k in bad:
    print(f"::error file={sys.argv[1]}::enum {k} differs from {sys.argv[2]}")
sys.exit(1 if bad else 0)
PY

check-jsonschema --check-metaschema "${SCHEMA}"
check-jsonschema --schemafile "${SCHEMA}" clusters/*.yaml

failed=0
for file in schemas/tests/invalid/*.yaml; do
  if check-jsonschema --schemafile "${SCHEMA}" "${file}" >/dev/null 2>&1; then
    echo "::error file=${file}::accepted by the schema, expected a failure"
    failed=1
  else
    echo "ok: ${file} rejected"
  fi
done
exit "${failed}"
