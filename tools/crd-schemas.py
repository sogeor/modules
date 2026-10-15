"""Converts CustomResourceDefinitions to JSON schemas for kubeconform.

Usage: crd-schemas.py OUT_DIR CRD_FILE...
Writes OUT_DIR/<group>/<kind>_<version>.json for every served version.
"""

import json
import pathlib
import sys

import yaml


def strict(node):
    if isinstance(node, dict):
        if (
            node.get("type") == "object"
            and "properties" in node
            and "additionalProperties" not in node
            and not node.get("x-kubernetes-preserve-unknown-fields")
        ):
            node["additionalProperties"] = False
        for value in node.values():
            strict(value)
    elif isinstance(node, list):
        for value in node:
            strict(value)


def main():
    out = pathlib.Path(sys.argv[1])
    for path in sys.argv[2:]:
        for doc in yaml.safe_load_all(pathlib.Path(path).read_text(encoding="utf-8")):
            if not doc or doc.get("kind") != "CustomResourceDefinition":
                continue
            spec = doc["spec"]
            group, kind = spec["group"], spec["names"]["kind"].lower()
            for version in spec["versions"]:
                if not version.get("served"):
                    continue
                schema = version["schema"]["openAPIV3Schema"]
                strict(schema)
                target = out / group / f"{kind}_{version['name']}.json"
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(json.dumps(schema, indent=1), encoding="utf-8")
                print(f"{group}/{kind}_{version['name']}{' (storage)' if version.get('storage') else ''}")


if __name__ == "__main__":
    main()
