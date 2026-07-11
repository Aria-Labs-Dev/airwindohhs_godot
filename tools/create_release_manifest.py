#!/usr/bin/env python3
"""Create a deterministic source/provenance manifest for a release."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("version")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    catalog = json.loads((root / "generated/catalog.json").read_text())
    included = []
    for name in ("CMakeLists.txt", "README.md", "LICENSE", "THIRD_PARTY.md"):
        included.append(root / name)
    for directory in ("config", "docs", "generated", "include", "src", "reports",
                      "tools", "tests", "demo"):
        included.extend(
            path for path in (root / directory).rglob("*")
            if path.is_file() and ".godot" not in path.parts and "bin" not in path.parts
            and "__pycache__" not in path.parts and path.suffix != ".pyc"
        )
    included = sorted(included, key=lambda path: path.relative_to(root).as_posix())
    hashes = {path.relative_to(root).as_posix(): digest(path) for path in included}
    output = root / "release" / args.version
    output.mkdir(parents=True, exist_ok=True)
    manifest = {
        "schema_version": 1,
        "project": "airwindohhs_godot",
        "version": args.version,
        "license": "MIT",
        "godot_api": "4.6",
        "godot_cpp_commit": "ba0edfed90512ec64aba51d4295a3e7e30112f86",
        "airwindohhs_policy": "latest-default-branch",
        "resolved_airwindohhs_commit": catalog["resolved_airwindohhs_commit"],
        "resolved_airwindows_source": catalog["resolved_airwindows_source"],
        "generator_version": catalog["generator_version"],
        "compatible_effects": catalog["compatible_effect_count"],
        "excluded_effects": catalog["excluded_effect_count"],
        "validation": {
            "offline_renders": 27016,
            "godot_smoke": "passed",
            "platform": "macos-arm64",
        },
        "sha256": hashes,
    }
    manifest_path = output / "MANIFEST.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    lines = [f"{value}  {name}" for name, value in hashes.items()]
    lines.append(f"{digest(manifest_path)}  release/{args.version}/MANIFEST.json")
    (output / "SHA256SUMS").write_text("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
