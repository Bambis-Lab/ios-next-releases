#!/usr/bin/env python3
import argparse
import json
import re
from pathlib import Path


def read_metadata(path: Path) -> dict[str, str]:
    data: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        if not raw.strip() or "=" not in raw:
            continue
        key, value = raw.split("=", 1)
        data[key.strip()] = value.strip()
    return data


def require(actual: str | None, expected: str, label: str) -> None:
    if actual != expected:
        raise SystemExit(f"{label}: expected {expected!r}, got {actual!r}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--metadata", required=True)
    parser.add_argument("--release-date")
    args = parser.parse_args()

    manifest_path = Path(args.manifest)
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    metadata = read_metadata(Path(args.metadata))

    require(metadata.get("source_base_sha"), manifest["approved_source_commit"], "source base")
    require(metadata.get("codemagic_commit"), manifest["expected_build_commit"], "build commit")
    require(metadata.get("ipa_file"), manifest["expected_artifact"], "artifact name")
    require(metadata.get("bundle_id"), manifest["bundle_identifier"], "bundle id")
    require(metadata.get("version"), manifest["version"], "version")
    require(metadata.get("build_version"), manifest["build_version"], "build version")
    require(metadata.get("deployment_target"), manifest["min_os_version"], "deployment target")
    require(metadata.get("packet_tunnel_extension"), "absent", "packet tunnel")
    require(metadata.get("network_extension_entitlement"), "absent", "network extension entitlement")

    sha = metadata.get("sha256", "")
    if not re.fullmatch(r"[0-9a-f]{64}", sha):
        raise SystemExit("invalid SHA-256")
    size = int(metadata.get("size_bytes", "0"))
    if size <= 0:
        raise SystemExit("invalid IPA size")

    manifest["ipa_size_bytes"] = size
    manifest["ipa_sha256"] = sha
    manifest["verified_build_commit"] = metadata["codemagic_commit"]
    if args.release_date:
        manifest["release_date"] = args.release_date
    manifest["status"] = "artifact-verified"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"verified release candidate {manifest['version']} build {manifest['build_version']}")


if __name__ == "__main__":
    main()
