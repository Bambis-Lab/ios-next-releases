#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


def release_notes(version: str) -> str:
    path = Path("release-notes") / f"{version}.md"
    if not path.is_file():
        raise SystemExit(f"missing release notes: {path}")
    lines = path.read_text(encoding="utf-8").strip().splitlines()
    if lines and lines[0].lstrip().startswith("#"):
        lines = lines[1:]
    text = "\n".join(lines).strip()
    if not text or not any(line.lstrip().startswith("-") for line in lines):
        raise SystemExit(f"release notes must contain bullet points: {path}")
    return text


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--date", required=True)
    parser.add_argument("--download-url", required=True)
    parser.add_argument("--size", type=int, required=True)
    parser.add_argument("--build-version")
    parser.add_argument("--min-os-version", default="27.0")
    args = parser.parse_args()

    source_path = Path("source.json")
    source = json.loads(source_path.read_text(encoding="utf-8"))
    versions = source["apps"][0]["versions"]
    if any(item.get("version") == args.version for item in versions):
        raise SystemExit(f"version already exists: {args.version}")

    entry = {
        "version": args.version,
        "date": args.date,
        "localizedDescription": release_notes(args.version),
        "downloadURL": args.download_url,
        "size": args.size,
        "minOSVersion": args.min_os_version,
    }
    if args.build_version:
        entry["buildVersion"] = args.build_version

    versions.insert(0, entry)
    source_path.write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"prepared SideStore version {args.version} with canonical What's New notes")


if __name__ == "__main__":
    main()
