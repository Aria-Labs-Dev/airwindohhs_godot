#!/usr/bin/env python3
"""Assemble the distributable addon zip from prebuilt platform binaries.

Collects artifacts from one or more bin directories (TeamCity artifact
dependencies drop them there), stages a self-contained addon folder, verifies
that every required library and dependency referenced by the .gdextension
descriptor is present, and zips it so the archive extracts as
addons/airwindohhs_godot/ in a project root.
"""

import argparse
import re
import shutil
import sys
import zipfile
from pathlib import Path
from typing import Optional

ADDON = "airwindohhs_godot"
DESCRIPTOR_ARTIFACT = re.compile(r'"res://addons/%s/bin/([^"]+)"' % ADDON)
ARTIFACT_PLATFORM = re.compile(r"\.(windows|macos|ios|android|linux)\.")


def descriptor_artifacts(source: str) -> list[str]:
    """Return unique bin artifacts referenced by libraries or dependencies."""
    return list(dict.fromkeys(DESCRIPTOR_ARTIFACT.findall(source)))


def artifact_platform(name: str) -> Optional[str]:
    match = ARTIFACT_PLATFORM.search(name)
    return match.group(1) if match else None


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bin-dir", action="append", type=Path, required=True,
                        help="Directory containing built libraries (repeatable)")
    parser.add_argument("--output", type=Path, required=True,
                        help="Path of the zip to write")
    parser.add_argument("--platforms", default="windows,macos,ios,android",
                        help="Comma-separated platforms whose binaries are required "
                             "(descriptor entries for other platforms are optional)")
    parser.add_argument("--allow-missing", action="store_true",
                        help="Package even if some required binaries are absent")
    args = parser.parse_args()

    descriptor_source = (repo_root / "demo" / "addons" / ADDON
                         / f"{ADDON}.gdextension.in")
    catalog = repo_root / "generated" / "catalog.json"

    staging = args.output.parent / "addon-staging"
    addon_dir = staging / "addons" / ADDON
    shutil.rmtree(staging, ignore_errors=True)
    (addon_dir / "bin").mkdir(parents=True)

    shutil.copyfile(descriptor_source, addon_dir / f"{ADDON}.gdextension")
    shutil.copyfile(catalog, addon_dir / "catalog.json")
    for extra in ("LICENSE", "THIRD_PARTY.md"):
        shutil.copyfile(repo_root / extra, addon_dir / extra)

    artifacts = descriptor_artifacts(descriptor_source.read_text())
    collected = []
    for bin_dir in args.bin_dir:
        if not bin_dir.is_dir():
            print(f"error: --bin-dir {bin_dir} does not exist", file=sys.stderr)
            return 1
        for name in artifacts:
            for artifact in sorted(bin_dir.rglob(name)):
                destination = addon_dir / "bin" / name
                if artifact.is_dir():
                    shutil.rmtree(destination, ignore_errors=True)
                    shutil.copytree(artifact, destination)
                elif artifact.is_file():
                    shutil.copyfile(artifact, destination)
                else:
                    continue
                collected.append(name)

    required_platforms = {p.strip() for p in args.platforms.split(",") if p.strip()}
    expected = [name for name in artifacts
                if artifact_platform(name) in required_platforms]
    missing = [name for name in expected
               if not (addon_dir / "bin" / name).exists()]
    print(f"Collected {len(collected)} libraries: {', '.join(collected)}")
    if missing:
        level = "warning" if args.allow_missing else "error"
        print(f"{level}: descriptor entries without a binary:", file=sys.stderr)
        for name in missing:
            print(f"  {name}", file=sys.stderr)
        if not args.allow_missing:
            return 1

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.output, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(staging.rglob("*")):
            if path.is_file():
                archive.write(path, path.relative_to(staging).as_posix())
    print(f"Wrote {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
