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
    "ASSET_SOURCES.md",
)
ASSET_FILES = (
    "assets/battle/arena_cape-route25.compact.png",
    "assets/battle/arena_cave-cerulean.compact.png",
    "assets/battle/arena_cave-diglett.compact.png",
    "assets/battle/arena_cave-mt-moon.compact.png",
    "assets/battle/arena_cave-rock-tunnel.compact.png",
    "assets/battle/arena_cave-seafoam.compact.png",
    "assets/battle/arena_cave-victory-road.compact.png",
    "assets/battle/arena_cerulean-canal.compact.png",
    "assets/battle/arena_coast-cinnabar.compact.png",
    "assets/battle/arena_coast-surf.compact.png",
    "assets/battle/arena_forest-viridian.compact.png",
    "assets/battle/arena_grass-kanto-open.compact.png",
    "assets/battle/arena_grass-route1.compact.png",
    "assets/battle/arena_gym-celadon.compact.png",
    "assets/battle/arena_gym-cerulean.compact.png",
    "assets/battle/arena_gym-cinnabar.compact.png",
    "assets/battle/arena_gym-fighting-dojo.compact.png",
    "assets/battle/arena_gym-fuchsia.compact.png",
    "assets/battle/arena_gym-pewter.compact.png",
    "assets/battle/arena_gym-saffron.compact.png",
    "assets/battle/arena_gym-vermilion.compact.png",
    "assets/battle/arena_gym-viridian.compact.png",
    "assets/battle/arena_indigo-gate-route22.compact.png",
    "assets/battle/arena_indigo-road-route23.compact.png",
    "assets/battle/arena_industrial-power-plant.compact.png",
    "assets/battle/arena_industrial-silph.compact.png",
    "assets/battle/arena_interior-oaks-lab.compact.png",
    "assets/battle/arena_league-agatha.compact.png",
    "assets/battle/arena_league-bruno.compact.png",
    "assets/battle/arena_league-champion.compact.png",
    "assets/battle/arena_league-lance.compact.png",
    "assets/battle/arena_league-lorelei.compact.png",
    "assets/battle/arena_mansion-cinnabar.compact.png",
    "assets/battle/arena_moon-approach-route3.compact.png",
    "assets/battle/arena_moon-exit-route4.compact.png",
    "assets/battle/nugget_bridge_a.compact.png",
    "assets/battle/arena_rock-water-route10.compact.png",
    "assets/battle/arena_rocket-game-corner.compact.png",
    "assets/battle/arena_rocket-hideout.compact.png",
    "assets/battle/arena_route2-forest-gate.compact.png",
    "assets/battle/arena_safari-kanto.compact.png",
    "assets/battle/arena_ship-bow.compact.png",
    "assets/battle/arena_ship-cabins.compact.png",
    "assets/battle/arena_ship-corridor.compact.png",
    "assets/battle/arena_tower-lavender.compact.png",
    "assets/battle/arena_vermilion-gate-route11.compact.png",
    "assets/scenery/kanto_panorama.compact.png",
    "assets/scenery/cinnabar_story_landmarks.compact.png",
    "assets/scenery/coastal_landmarks_v3.compact.png",
    "assets/scenery/forest_edge_a.compact.png",
    "assets/scenery/forest_edge_b.compact.png",
    "assets/scenery/forest_edge_c.compact.png",
    "assets/scenery/metropolis.compact.png",
    "assets/scenery/mini_trees.compact.png",
    "assets/scenery/harbor_edge.compact.png",
    "assets/scenery/mt_moon_ceiling.compact.png",
    "assets/scenery/mt_moon_wall.compact.png",
    "assets/scenery/pokecenter_room_ceiling.compact.png",
    "assets/scenery/pokecenter_room_wall.compact.png",
    "assets/scenery/pokemon_tower_ceiling.compact.png",
    "assets/scenery/pokemon_tower_wall.compact.png",
    "assets/scenery/rural_edge.compact.png",
    "assets/scenery/route8_horizon.compact.png",
    "assets/scenery/route8_midground.compact.png",
    "assets/scenery/viridian_forest_gate.compact.png",
    "assets/scenery/viridian_town.compact.png",
    "assets/sky/articuno.png",
    "assets/sky/bird_flock.png",
    "assets/sky/clouds.png",
    "assets/sky/farfetchd.png",
    "assets/sky/fuji_panorama.compact.png",
    "assets/sky/mountain_panorama.compact.png",
    "assets/sky/hooh.png",
    "assets/sky/moltres.png",
    "assets/sky/murkrow_flock.png",
    "assets/sky/rainbow.png",
    "assets/sky/spearow_flock.png",
    "assets/sky/zapdos.png",
)
FIXED_TIME = (1980, 1, 1, 0, 0, 0)


def release_files() -> list[Path]:
    files = [ROOT / name for name in ROOT_FILES]
    files.extend(sorted((ROOT / "lib").glob("*.lua")))
    files.extend(sorted((ROOT / "data").glob("*.lua")))
    files.extend(ROOT / name for name in ASSET_FILES)
    files.extend(sorted(
        path for path in (ROOT / "user").rglob("*") if path.is_file()
    ))
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
