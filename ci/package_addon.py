#!/usr/bin/env python3
"""Assemble the distributable addon zip from prebuilt platform binaries.

Collects libraries from one or more bin directories (TeamCity artifact
dependencies drop them there), stages a self-contained addon folder, verifies
that every library referenced by the .gdextension descriptor is present, and
zips it so the archive extracts as addons/airwindohhs_godot/ in a project root.
"""

import argparse
import re
import shutil
import sys
import zipfile
from pathlib import Path

ADDON = "airwindohhs_godot"
LIBRARY_PATTERN = re.compile(r"^(lib)?airwindohhs_godot\..+\.(dll|so|dylib)$")
DESCRIPTOR_LIBRARY = re.compile(r'"res://addons/%s/bin/([^"]+)"' % ADDON)


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

    collected = []
    for bin_dir in args.bin_dir:
        if not bin_dir.is_dir():
            print(f"error: --bin-dir {bin_dir} does not exist", file=sys.stderr)
            return 1
        for library in sorted(bin_dir.rglob("*")):
            if library.is_file() and LIBRARY_PATTERN.match(library.name):
                shutil.copyfile(library, addon_dir / "bin" / library.name)
                collected.append(library.name)

    required_platforms = {p.strip() for p in args.platforms.split(",") if p.strip()}
    expected = [name for name in DESCRIPTOR_LIBRARY.findall(descriptor_source.read_text())
                if name.split(f"{ADDON}.", 1)[-1].split(".", 1)[0] in required_platforms]
    missing = [name for name in expected
               if not (addon_dir / "bin" / name).is_file()]
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
