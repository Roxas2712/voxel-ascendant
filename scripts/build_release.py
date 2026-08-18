#!/usr/bin/env python3
"""Build the deterministic direct-install Voxel Ascendant ZIP."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import zipfile


ROOT = Path(__file__).resolve().parents[1]
ROOT_FILES = (
    "manifest.json",
    "main.lua",
    "mod.card",
    "LICENSE",
    "README.md",
    "CHANGELOG.md",
    "RELEASE_NOTES.md",
    "COMPATIBILITY.md",
    "CREDITS.md",
    "FORK_HISTORY.md",
    "THIRD_PARTY_NOTICES.md",
    "UPSTREAM_CHANGELOG.md",
)
FIXED_TIME = (1980, 1, 1, 0, 0, 0)


def release_files() -> list[Path]:
    files = [ROOT / name for name in ROOT_FILES]
    files.extend(sorted((ROOT / "lib").glob("*.lua")))
    files.extend(sorted((ROOT / "data").glob("*.lua")))
    missing = [path for path in files if not path.is_file()]
    if missing:
        raise SystemExit("missing release file(s): " + ", ".join(map(str, missing)))
    if any(path.is_symlink() for path in files):
        raise SystemExit("release inputs must not be symlinks")
    return files


def write_zip(output: Path) -> str:
    manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    if manifest.get("id") != "VOXEL_ASCENDANT":
        raise SystemExit("refusing to package an unexpected manifest id")

    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(
        output,
        "w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=9,
        strict_timestamps=True,
    ) as archive:
        for path in release_files():
            relative = path.relative_to(ROOT).as_posix()
            info = zipfile.ZipInfo(relative, FIXED_TIME)
            info.create_system = 3
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, path.read_bytes(), compresslevel=9)

    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    return digest


def main() -> int:
    manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    default = ROOT / "dist" / (
        f"{manifest['id']}-{manifest['version']}.zip"
    )
    parser = argparse.ArgumentParser()
    parser.add_argument("-o", "--output", type=Path, default=default)
    args = parser.parse_args()
    output = args.output.resolve()
    digest = write_zip(output)
    print(f"{digest}  {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
