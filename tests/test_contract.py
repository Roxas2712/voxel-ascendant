#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile


ROOT = Path(__file__).resolve().parents[1]
KASC_656_RENDERER_BATTLE_HUD_SHA256 = (
    "73a235adb1d8e259906b0200a5ce650ac183d8e69ccc7d045cf9c9dd50dc5479"
)
EXPECTED_PUBLIC = {
    "AntiAlias",
    "BattleArena",
    "BattleCam",
    "OverworldBattle",
    "SkyEvents",
    "Voxel3D",
    "VoxelScene",
    "VoxelState",
    "WallDecals",
}
EXPECTED_ASSETS = {
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
}
OUTDOOR_ARENA_ASSETS = {
    "assets/battle/arena_cape-route25.compact.png",
    "assets/battle/arena_cerulean-canal.compact.png",
    "assets/battle/arena_coast-cinnabar.compact.png",
    "assets/battle/arena_coast-surf.compact.png",
    "assets/battle/arena_forest-viridian.compact.png",
    "assets/battle/arena_grass-kanto-open.compact.png",
    "assets/battle/arena_grass-route1.compact.png",
    "assets/battle/arena_indigo-gate-route22.compact.png",
    "assets/battle/arena_indigo-road-route23.compact.png",
    "assets/battle/arena_moon-approach-route3.compact.png",
    "assets/battle/arena_moon-exit-route4.compact.png",
    "assets/battle/arena_rock-water-route10.compact.png",
    "assets/battle/arena_route2-forest-gate.compact.png",
    "assets/battle/arena_safari-kanto.compact.png",
    "assets/battle/arena_ship-bow.compact.png",
    "assets/battle/arena_vermilion-gate-route11.compact.png",
    "assets/battle/nugget_bridge_a.compact.png",
}
EXPECTED_REPO_ONLY_PNGS = {
    # Reviewed V1/V2 runtimes remain beside V3 for rollback/diff evidence but
    # are no longer read or shipped. High-resolution retained ImageGen masters
    # make both versioned builds reproducible and remain outside the ZIP.
    "assets/scenery/coastal_landmarks.compact.png",
    "assets/scenery/coastal_landmarks_v2.compact.png",
    "qa-screenshots/vasc/cinnabar-story-landmarks-20260823/cinnabar-volcano-birth-island-headless.png",
    "tools/sources/coastal_landmarks_v2/01-rocky-island.imagegen.png",
    "tools/sources/coastal_landmarks_v2/02-lighthouse.imagegen.png",
    "tools/sources/coastal_landmarks_v2/03-archipelago.imagegen.png",
    "tools/sources/coastal_landmarks_v2/04-cinnabar.imagegen.png",
    "tools/sources/coastal_landmarks_v3/01-rocky-island.imagegen.png",
    "tools/sources/coastal_landmarks_v3/02-lighthouse.imagegen.png",
    "tools/sources/coastal_landmarks_v3/03-archipelago.imagegen.png",
    "tools/sources/coastal_landmarks_v3/04-cinnabar.imagegen.png",
    "tools/sources/cinnabar_story_landmarks/01-cinnabar-volcano.imagegen.png",
    "tools/sources/cinnabar_story_landmarks/02-birth-island.imagegen.png",
    "tools/sources/kanto_panorama/kanto-panorama.imagegen.png",
    "tools/sources/arena_scenery/cave_cerulean_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/cave_diglett_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/cave_mt_moon_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/cave_rock_tunnel_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/cave_seafoam_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/cave_victory_road_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/coast_surf_baseline_v2.imagegen.png",
    "tools/sources/arena_scenery/forest_viridian_baseline_v2.imagegen.png",
    "tools/sources/arena_scenery/gym_celadon_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/gym_celadon_baseline_v2.imagegen.png",
    "tools/sources/arena_scenery/gym_cerulean_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/gym_cerulean_baseline_v2.imagegen.png",
    "tools/sources/arena_scenery/gym_cinnabar_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/gym_cinnabar_baseline_v2.imagegen.png",
    "tools/sources/arena_scenery/gym_fighting_dojo_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/gym_fighting_dojo_baseline_v2.imagegen.png",
    "tools/sources/arena_scenery/gym_fuchsia_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/gym_fuchsia_baseline_v2.imagegen.png",
    "tools/sources/arena_scenery/gym_fuchsia_baseline_v3.imagegen.png",
    "tools/sources/arena_scenery/gym_pewter_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/gym_pewter_baseline_v2.imagegen.png",
    "tools/sources/arena_scenery/gym_saffron_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/gym_vermilion_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/gym_viridian_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/gym_viridian_baseline_v2.imagegen.png",
    "tools/sources/arena_scenery/indigo_gate_route22_baseline_v3.imagegen.png",
    "tools/sources/arena_scenery/industrial_power_plant_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/industrial_power_plant_baseline_v2.imagegen.png",
    "tools/sources/arena_scenery/industrial_silph_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/industrial_silph_baseline_v2.imagegen.png",
    "tools/sources/arena_scenery/industrial_silph_baseline_v3.imagegen.png",
    "tools/sources/arena_scenery/interior_oaks_lab_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/interior_oaks_lab_baseline_v2.imagegen.png",
    "tools/sources/arena_scenery/interior_oaks_lab_baseline_v3.imagegen.png",
    "tools/sources/arena_scenery/league_agatha_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/league_bruno_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/league_champion_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/league_lance_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/league_lorelei_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/league_lorelei_baseline_v2.imagegen.png",
    "tools/sources/arena_scenery/league_lorelei_baseline_v3.imagegen.png",
    "tools/sources/arena_scenery/league_lorelei_baseline_v4.imagegen.png",
    "tools/sources/arena_scenery/mansion_cinnabar_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/moon_exit_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/nugget_bridge_a.imagegen.png",
    "tools/sources/arena_scenery/nugget_bridge_anchors_v2.imagegen.png",
    "tools/sources/arena_scenery/nugget_bridge_grounded.imagegen.png",
    "tools/sources/arena_scenery/rocket_game_corner_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/rocket_game_corner_baseline_v2.imagegen.png",
    "tools/sources/arena_scenery/rocket_hideout_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/rocket_hideout_baseline_v2.imagegen.png",
    "tools/sources/arena_scenery/ship_bow_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/ship_bow_baseline_v2.imagegen.png",
    "tools/sources/arena_scenery/ship_cabins_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/ship_cabins_baseline_v2.imagegen.png",
    "tools/sources/arena_scenery/ship_cabins_baseline_v3.imagegen.png",
    "tools/sources/arena_scenery/ship_corridor_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/ship_corridor_baseline_v2.imagegen.png",
    "tools/sources/arena_scenery/tower_lavender_baseline_v1.imagegen.png",
    "tools/sources/arena_scenery/tower_lavender_baseline_v2.imagegen.png",
}
REMOVED_NAMES = (
    "Horde",
    "Stadium",
    "VRGL",
    "VRXR",
    "ImageCache",
    "Perf",
)
DENIED_CODE = (
    re.compile(r"\blove\.filesystem\b"),
    re.compile(r"\blove\.system\b"),
    re.compile(r"\b(?:io|os|package)\s*\."),
    re.compile(r"\bffi\b"),
    re.compile(r"\bdebug\s*\.\s*getupvalue\b"),
)


def runtime_files() -> list[Path]:
    return [ROOT / "main.lua", *sorted((ROOT / "lib").glob("*.lua")),
            *sorted((ROOT / "data").glob("*.lua"))]


def code_without_comments(text: str) -> str:
    text = re.sub(r"--\[\[.*?\]\]", "", text, flags=re.S)
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def exact_kasc_656_renderer_battle_hud() -> bytes:
    """Load the byte-exact public KASC 6.5.6 bridge used by production.

    This deliberately does not fall back to a reduced fixture. Release QA can
    point KASC_656_RENDERER_BATTLE_HUD at an extracted public package; the
    local release workspace also keeps the exact public ZIP for offline QA.
    """
    explicit = os.environ.get("KASC_656_RENDERER_BATTLE_HUD")
    candidates = [Path(explicit)] if explicit else []
    candidates.extend([
        Path("/private/tmp/kasc656.QtZSjW/renderer_battle_hud.lua"),
        ROOT.parent / "qa" / "kanto-ascendant-6.5.6-public-release-20260817"
        / "renderer_battle_hud.lua",
    ])
    archives = [
        ROOT.parent / "qa" / "kanto-ascendant-6.5.6-public-release-20260817"
        / "kanto_ascendant-6.5.6.zip",
        ROOT.parent / "qa"
        / ".kanto-ascendant-6.5.6-public-release-20260818-replacement-8eee89a9.pending"
        / "kanto_ascendant-6.5.6.zip",
    ]

    found: list[tuple[str, bytes]] = []
    for path in candidates:
        if path.is_file():
            found.append((str(path), path.read_bytes()))
    for archive in archives:
        if archive.is_file():
            with zipfile.ZipFile(archive) as package:
                try:
                    found.append((
                        f"{archive}!renderer_battle_hud.lua",
                        package.read("renderer_battle_hud.lua"),
                    ))
                except KeyError:
                    pass

    mismatches: list[str] = []
    for source, payload in found:
        digest = hashlib.sha256(payload).hexdigest()
        if digest == KASC_656_RENDERER_BATTLE_HUD_SHA256:
            return payload
        mismatches.append(f"{source}={digest}")
    detail = "; ".join(mismatches) if mismatches else "no candidate found"
    raise AssertionError(
        "byte-exact public KASC 6.5.6 renderer_battle_hud.lua unavailable: "
        + detail
    )


def exact_gen1recomp_0190_root() -> Path:
    explicit = os.environ.get("GEN1RECOMP_0190_ROOT")
    candidates = [Path(explicit)] if explicit else []
    candidates.extend([
        ROOT.parent / "qa"
        / "gen1recomp-0.1.90-clientfix-rc-20260815-2c645aef"
        / "build-A" / "stage",
        ROOT.parent / "gen1recomp",
    ])
    required = {
        Path("src/core/Game.lua"):
            "5d69119e3f5d9c622810219469a2cea496a861efc08bab3336143ecb43c44a5a",
        Path("src/mods/Hooks.lua"):
            "1e09688f927d689f6f57fc47ff9f96952a9e6015cab2458f43bbb8c510151682",
        Path("src/mods/Runtime.lua"):
            "19cf73496f92500e973eac04c82d781b5d3125f5fb2d55ebc1d7f3a5e2485b66",
        Path("src/mods/Sandbox.lua"):
            "d797c0247429e0a91dbf3fdf5e77e8c1f8aa2254c8acc3f4aaeb5b80363e0077",
        Path("src/mods/Schemas.lua"):
            "f3d4072cde0085f3b8ce1f7cdb769c13355a87b974775a163cfd9ae461c4adad",
        Path("src/render/Pipelines.lua"):
            "1816177fc3282ab062aafc765ebe8e8918d1161ce22178e882816af8e7debcef",
        Path("src/render/Transition.lua"):
            "cbbb623132e16c5569de629f9e0e545ba5f2e4efdfafd02044939eb98958f36c",
        Path("src/battle/BattleState.lua"):
            "3a443b2c95c967722c33896775ed46f09bfb0ad8488c094d53ada2ebdd9a355a",
        Path("src/render/PaletteFX.lua"):
            "0c2433022b75f46ec354298326cc211e65a8c9a55653ca6f3b1d7e1c1a48e8b6",
        Path("data/palettes_gbc.lua"):
            "e194c72de82a0a520aced960b04d95325735b4ee63e9b071ad3e96bcf6615b0c",
        Path("data/palettes_yellow.lua"):
            "d6e74d475b919d795c51cc837b1f815a9a35fafd30f8e277212da108abc69124",
    }
    for candidate in candidates:
        if all(
            (candidate / path).is_file()
            and hashlib.sha256((candidate / path).read_bytes()).hexdigest()
            == digest
            for path, digest in required.items()
        ):
            return candidate
    raise AssertionError(
        "exact Gen1Recomp 0.1.90 source unavailable; set GEN1RECOMP_0190_ROOT"
    )


class ContractTests(unittest.TestCase):
    def test_manifest_contract(self) -> None:
        manifest = json.loads((ROOT / "manifest.json").read_text())
        self.assertEqual(manifest["id"], "VOXEL_ASCENDANT")
        self.assertEqual(manifest["name"], "Voxel Ascendant")
        self.assertEqual(manifest["version"], "2.0.1")
        self.assertEqual(manifest["github"], "Roxas2712/voxel-ascendant")
        self.assertEqual(manifest["api"], 2)
        self.assertEqual(manifest["games"], ["gen1"])
        self.assertEqual(manifest["game_version"], ">=0.1.90")
        self.assertEqual(manifest["permissions"], ["engine_internals"])
        self.assertFalse(manifest["affects_link"])
        self.assertEqual(
            set(manifest["conflicts"]),
            {"DRAMATIC_SHAPE", "DRAMALESS_SHAPE",
             "BATTLE_ART_VOXEL_FORK", "potato_voxel", "TERRARIUM"},
        )

    def test_runtime_dependency_closure(self) -> None:
        for path in runtime_files():
            text = path.read_text(encoding="utf-8")
            for name in re.findall(r'V\.require\("([A-Za-z0-9_]+)"\)', text):
                self.assertTrue((ROOT / "lib" / f"{name}.lua").is_file(),
                                f"{path.name} requires missing lib/{name}.lua")
            for name in re.findall(r'V\.data\("([A-Za-z0-9_]+)"\)', text):
                self.assertTrue((ROOT / "data" / f"{name}.lua").is_file(),
                                f"{path.name} requires missing data/{name}.lua")

    def test_runtime_has_no_denied_api(self) -> None:
        for path in runtime_files():
            code = code_without_comments(path.read_text(encoding="utf-8"))
            for pattern in DENIED_CODE:
                self.assertIsNone(pattern.search(code),
                                  f"{path.name}: denied API {pattern.pattern}")

    def test_removed_modules_are_absent(self) -> None:
        release_paths = [path.relative_to(ROOT).as_posix()
                         for path in ROOT.rglob("*") if path.is_file()
                         and ".git" not in path.parts
                         and "dist" not in path.parts]
        for name in REMOVED_NAMES:
            self.assertFalse(any(name in path for path in release_paths),
                             f"removed module still present: {name}")
        denied_suffixes = {".dll", ".so", ".dylib", ".jpg", ".bin",
                           ".gb", ".gbc", ".z64", ".n64", ".v64"}
        self.assertFalse(any(Path(path).suffix.lower() in denied_suffixes
                             for path in release_paths))
        pngs = {path for path in release_paths
                if Path(path).suffix.lower() == ".png"}
        self.assertEqual(pngs, EXPECTED_ASSETS | EXPECTED_REPO_ONLY_PNGS)

    def test_release_png_hashes_are_recorded_in_asset_sources(self) -> None:
        """Every shipped bitmap must remain tied to its reviewed source record."""
        record = (ROOT / "ASSET_SOURCES.md").read_text(encoding="utf-8")
        for relative in sorted(EXPECTED_ASSETS):
            path = ROOT / relative
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            self.assertIn(path.name, record,
                          f"missing provenance entry for {relative}")
            self.assertIn(digest, record,
                          f"stale provenance hash for {relative}")

    def test_nugget_bridge_arena_scenery_rebuild_is_deterministic(self) -> None:
        from PIL import Image

        runtime = ROOT / "assets/battle/nugget_bridge_a.compact.png"
        source = (
            ROOT / "tools/sources/arena_scenery"
            / "nugget_bridge_anchors_v2.imagegen.png"
        )
        self.assertEqual(
            hashlib.sha256(source.read_bytes()).hexdigest(),
            "101f1e7f86205a31d70d3acd98d7a994d017131272c1d9dcca54fa323ad910a5",
        )
        self.assertEqual(
            hashlib.sha256(runtime.read_bytes()).hexdigest(),
            "e86a1d07a4668139bd9afbe1668b0e0d81eeeceba2478cd8520ad029478b46a3",
        )
        with tempfile.TemporaryDirectory() as temp:
            rebuilt = Path(temp) / "nugget.png"
            subprocess.run(
                [
                    sys.executable,
                    "-B",
                    "tools/build_arena_scenery.py",
                    "--source",
                    str(source),
                    "--output",
                    str(rebuilt),
                ],
                cwd=ROOT,
                check=True,
                text=True,
                capture_output=True,
            )
            self.assertEqual(rebuilt.read_bytes(), runtime.read_bytes())
        with Image.open(runtime) as opened:
            image = opened.convert("RGBA")
        self.assertEqual(image.size, (1280, 800))
        alpha = image.getchannel("A")
        self.assertEqual(set(alpha.crop((0, 0, 1280, 1)).getdata()), {0})
        self.assertEqual(set(alpha.crop((0, 799, 1280, 800)).getdata()),
                         {255})
        self.assertGreater(alpha.getextrema()[1], alpha.getextrema()[0])

    def test_outdoor_arena_matte_repair_removes_only_detached_alpha(self) -> None:
        """Live-sky repair keeps grounded scenery and removes black islands."""
        from PIL import Image

        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "source.png"
            repaired = root / "repaired.png"
            image = Image.new("RGBA", (40, 24), (0, 0, 0, 0))
            # Grounded dark tree/terrain: legal despite its matte-like color.
            for y in range(12, 24):
                for x in range(40):
                    image.putpixel((x, y), (72, 92, 64, 255))
            for y in range(6, 12):
                for x in range(10, 31):
                    image.putpixel((x, y), (72, 92, 64, 255))
            image.putpixel((10, 6), (0, 255, 0, 255))
            image.putpixel((20, 10), (0, 0, 0, 255))
            # Detached opaque core plus antialiased rim: both must disappear.
            image.putpixel((20, 2), (0, 0, 0, 255))
            image.putpixel((21, 2), (30, 30, 30, 120))
            image.save(source)
            result = subprocess.run(
                ["python3",
                 "tools/sources/arena_scenery/repair_outdoor_sky_matte.py",
                 str(source), str(repaired)],
                cwd=ROOT, check=True, text=True, capture_output=True,
            )
            self.assertIn("floating_removed=1", result.stdout)
            with Image.open(repaired) as output:
                fixed = output.convert("RGBA")
            self.assertEqual(fixed.getpixel((20, 2))[3], 0)
            self.assertEqual(fixed.getpixel((21, 2))[3], 0)
            self.assertEqual(fixed.getpixel((10, 6))[3], 255)
            self.assertNotEqual(fixed.getpixel((10, 6))[:3], (0, 255, 0))
            self.assertNotEqual(fixed.getpixel((20, 10))[:3], (0, 0, 0))
            self.assertEqual(fixed.getpixel((20, 15)), (72, 92, 64, 255))
            self.assertTrue(all(fixed.getpixel((x, 23))[3] == 255
                                for x in range(40)))
            second = root / "second.png"
            subprocess.run(
                ["python3",
                 "tools/sources/arena_scenery/repair_outdoor_sky_matte.py",
                 str(repaired), str(second)],
                cwd=ROOT, check=True, text=True, capture_output=True,
            )
            with Image.open(second) as second_image:
                second_alpha = second_image.convert("RGBA").getchannel("A")
            self.assertEqual(fixed.getchannel("A").tobytes(),
                             second_alpha.tobytes(),
                             "matte repair must preserve its fixed silhouette")

    def test_every_outdoor_arena_has_clean_live_sky_edges(self) -> None:
        """Every shipped outdoor painting is grounded and matte-free."""
        from collections import deque
        from PIL import Image
        from statistics import median

        for relative in sorted(OUTDOOR_ARENA_ASSETS):
            with self.subTest(asset=relative):
                with Image.open(ROOT / relative) as opened:
                    image = opened.convert("RGBA")
                self.assertEqual(image.size, (1280, 800))
                width, height = image.size
                pixels = list(image.getdata())
                alpha = [pixel[3] for pixel in pixels]
                self.assertTrue(all(alpha[(height - 1) * width + x] == 255
                                    for x in range(width)))

                sky = bytearray(width * height)
                queue: deque[int] = deque()
                for x in range(width):
                    if alpha[x] == 0:
                        sky[x] = 1
                        queue.append(x)
                while queue:
                    index = queue.popleft()
                    x, y = index % width, index // width
                    for ny in range(max(0, y - 1), min(height, y + 2)):
                        for nx in range(max(0, x - 1), min(width, x + 2)):
                            neighbor = ny * width + nx
                            if not sky[neighbor] and alpha[neighbor] == 0:
                                sky[neighbor] = 1
                                queue.append(neighbor)
                sky_bottom = max((index // width for index, value
                                  in enumerate(sky) if value), default=0)

                grounded = bytearray(width * height)
                queue.clear()
                for x in range(width):
                    index = (height - 1) * width + x
                    grounded[index] = 1
                    queue.append(index)
                while queue:
                    index = queue.popleft()
                    x, y = index % width, index // width
                    for ny in range(max(0, y - 1), min(height, y + 2)):
                        for nx in range(max(0, x - 1), min(width, x + 2)):
                            neighbor = ny * width + nx
                            if (not grounded[neighbor]
                                    and alpha[neighbor] > 0):
                                grounded[neighbor] = 1
                                queue.append(neighbor)
                detached = sum(1 for index, value in enumerate(alpha)
                               if value > 0 and not grounded[index])
                self.assertEqual(detached, 0,
                                 f"{relative} has detached sky pixels")

                outliers: list[tuple[int, int]] = []
                for y in range(min(height, sky_bottom + 49)):
                    for x in range(width):
                        red, green, blue, opacity = pixels[y * width + x]
                        channels = sorted((red, green, blue))
                        suspicious = (channels[2] <= 48
                                      or (channels[0] <= 8
                                          and channels[2] >= 70
                                          and channels[2] - channels[0]
                                          >= 70))
                        if not opacity or not suspicious:
                            continue
                        local = []
                        for ny in range(max(0, y - 3),
                                        min(height, y + 4)):
                            for nx in range(max(0, x - 3),
                                            min(width, x + 4)):
                                if nx == x and ny == y:
                                    continue
                                sample = pixels[ny * width + nx]
                                if sample[3] >= 128:
                                    local.append(sample[:3])
                        if len(local) < 5:
                            continue
                        center = tuple(int(median(sample[channel]
                                                  for sample in local))
                                       for channel in range(3))
                        if max(abs(red - center[0]),
                               abs(green - center[1]),
                               abs(blue - center[2])) >= 48:
                            outliers.append((x, y))
                self.assertFalse(outliers,
                                 f"{relative} has sky-edge RGB specks "
                                 f"at {outliers[:8]}")
                if relative.endswith("arena_safari-kanto.compact.png"):
                    dark = {
                        (index % width, index // width)
                        for index, pixel in enumerate(pixels)
                        if index // width < min(height, sky_bottom + 49)
                        and pixel[3] > 0 and max(pixel[:3]) <= 48
                    }
                    largest = 0
                    while dark:
                        seed = dark.pop()
                        component = {seed}
                        queue = deque([seed])
                        while queue:
                            x, y = queue.popleft()
                            for ny in range(max(0, y - 1),
                                            min(height, y + 2)):
                                for nx in range(max(0, x - 1),
                                                min(width, x + 2)):
                                    point = (nx, ny)
                                    if point in dark:
                                        dark.remove(point)
                                        component.add(point)
                                        queue.append(point)
                        largest = max(largest, len(component))
                    self.assertLessEqual(
                        largest, 64,
                        "Safari has a reintroduced enclosed black matte mass",
                    )

    def test_mountain_panorama_sector_edges_are_continuous(self) -> None:
        """The circular cardinal atlas must have pixel-exact corner joins."""
        from PIL import Image

        path = ROOT / "assets" / "sky" / "mountain_panorama.compact.png"
        with Image.open(path) as source:
            image = source.convert("RGBA")
        self.assertEqual(image.size, (2048, 128))

        # Physical order follows a clockwise world walk:
        # N[0:1024], E[1024:1365], S-reversed[1365:1707],
        # W-reversed[1707:2048], then the wrap back to N. Endpoint columns
        # are intentionally duplicated so nearest sampling cannot expose a
        # vertical skyline, alpha or palette cut at a geometry corner.
        for boundary in (1024, 1365, 1707, 2048):
            left, right = boundary - 1, boundary % image.width
            left_column = [image.getpixel((left, y))
                           for y in range(image.height)]
            right_column = [image.getpixel((right, y))
                            for y in range(image.height)]
            self.assertEqual(left_column, right_column,
                             f"pixel seam at world corner {boundary}")

    def test_kanto_panorama_is_reproducible_and_wrap_safe(self) -> None:
        from PIL import Image

        runtime = ROOT / "assets/scenery/kanto_panorama.compact.png"
        self.assertEqual(
            hashlib.sha256(runtime.read_bytes()).hexdigest(),
            "eb4668bed79673108b73a00761e5edb54d8583369bb3e60797fdc7454c30cf9f",
        )
        with Image.open(runtime) as source:
            image = source.convert("RGBA")
        self.assertEqual(image.size, (1024, 192))
        self.assertEqual(set(image.getchannel("A").getdata()), {0, 255})
        self.assertLessEqual(len({pixel[:3] for pixel in image.getdata()
                                  if pixel[3]}), 32)
        self.assertTrue(all(image.getpixel((0, y)) == image.getpixel((1023, y))
                            for y in range(image.height)))
        self.assertTrue(all(image.getpixel((x, 191))[3] == 255
                            for x in range(image.width)))
        with tempfile.TemporaryDirectory() as temp:
            rebuilt = Path(temp) / "panorama.png"
            subprocess.run(
                ["python3", "tools/build_kanto_panorama.py",
                 "--output", str(rebuilt)], cwd=ROOT, check=True,
                text=True, capture_output=True,
            )
            self.assertEqual(rebuilt.read_bytes(), runtime.read_bytes())

    def test_panorama_backdrop_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/panorama_backdrop_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_route8_horizon_connector_columns_are_continuous(self) -> None:
        """The long strip and both short end faces share exact connectors."""
        from PIL import Image

        path = ROOT / "assets" / "scenery" / "route8_horizon.compact.png"
        with Image.open(path) as source:
            image = source.convert("RGBA")
        self.assertEqual(image.size, (960, 96))

        # West reuses the Saffron third and joins the long face at 0/288;
        # east reuses the Lavender third and joins at 672/959. A dimension-
        # only test cannot catch a regenerated asset introducing a one-pixel
        # vertical cut at either physical corner.
        for left, right in ((0, 288), (672, 959)):
            left_column = [image.getpixel((left, y))
                           for y in range(image.height)]
            right_column = [image.getpixel((right, y))
                            for y in range(image.height)]
            self.assertEqual(left_column, right_column,
                             f"Route 8 connector mismatch {left}/{right}")

    def test_route8_midground_is_native_transparent_module_atlas(self) -> None:
        """Eight cut-outs stay isolated, transparent and exactly 32x64."""
        from PIL import Image

        path = ROOT / "assets" / "scenery" / "route8_midground.compact.png"
        with Image.open(path) as source:
            image = source.convert("RGBA")
        self.assertEqual(image.size, (256, 64))
        self.assertEqual(image.getchannel("A").getextrema(), (0, 255))

        for module in range(8):
            cutout = image.crop((module * 32, 0, (module + 1) * 32, 64))
            bounds = cutout.getchannel("A").getbbox()
            self.assertIsNotNone(bounds, f"Route 8 module {module} is empty")
            self.assertGreater(bounds[0], 0,
                               f"Route 8 module {module} bleeds left")
            self.assertLess(bounds[2], 32,
                            f"Route 8 module {module} bleeds right")

        # The seam renderer samples only this native 16x12 lower crop.  Pin
        # both alpha occupancy and its predominantly green content so a later
        # atlas regeneration cannot silently turn the low shrub back into a
        # lamp/tree half or a mostly transparent billboard.
        shrub = image.crop((112, 48, 128, 60))
        pixels = list(shrub.getdata())
        self.assertEqual(sum(alpha > 0 for *_, alpha in pixels), 160)
        self.assertEqual(
            sum(alpha > 0 and green > red and green > blue
                for red, green, blue, alpha in pixels),
            97,
        )
        self.assertEqual(shrub.getchannel("A").getbbox(), (0, 0, 14, 12))

    def test_viridian_forest_gate_is_canonical_native_bitmap(self) -> None:
        """The Forest proxy stays the exact colored Route 2 gate silhouette."""
        from PIL import Image

        path = ROOT / "assets" / "scenery" / \
            "viridian_forest_gate.compact.png"
        with Image.open(path) as source:
            image = source.convert("RGBA")
        self.assertEqual(image.size, (64, 40))
        alpha = image.getchannel("A")
        self.assertEqual(set(alpha.getdata()), {0, 255})
        self.assertEqual(alpha.getbbox(), (3, 0, 61, 40))
        self.assertEqual(sum(value == 255 for value in alpha.getdata()), 2140)
        visible_colors = {
            pixel[:3] for pixel in image.getdata() if pixel[3] == 255
        }
        self.assertEqual(visible_colors, {
            (0, 197, 58), (0, 239, 58), (58, 58, 58),
            (107, 107, 107), (165, 123, 25), (173, 173, 173),
            (197, 148, 58), (222, 255, 222), (255, 132, 8),
            (255, 255, 58),
        })

    def test_mt_moon_materials_are_native_opaque_seamless_tiles(self) -> None:
        """Mt Moon's wall/ceiling inputs stay strict, opaque native assets."""
        from PIL import Image

        specs = {
            "mt_moon_wall.compact.png": (512, 160),
            "mt_moon_ceiling.compact.png": (256, 256),
        }
        for name, size in specs.items():
            path = ROOT / "assets" / "scenery" / name
            with Image.open(path) as source:
                image = source.convert("RGBA")
            self.assertEqual(image.size, size)
            self.assertEqual(image.getchannel("A").getextrema(), (255, 255))
            self.assertEqual(
                list(image.crop((0, 0, 1, image.height)).getdata()),
                list(image.crop((image.width - 1, 0,
                                 image.width, image.height)).getdata()),
                f"{name} horizontal repeat edge drifted",
            )
            if name == "mt_moon_ceiling.compact.png":
                self.assertEqual(
                    list(image.crop((0, 0, image.width, 1)).getdata()),
                    list(image.crop((0, image.height - 1,
                                     image.width, image.height)).getdata()),
                    f"{name} vertical repeat edge drifted",
                )

    def test_pokemon_tower_materials_are_varied_native_seamless_tiles(
        self,
    ) -> None:
        """Tower art stays opaque, non-wallpapered, and exact at every join."""
        from PIL import Image

        specs = {
            "pokemon_tower_wall.compact.png": (
                (512, 160),
                "15d4127df049a4000ee388c26b2476c2"
                "819ee847b9e400ec54685527c2a4714a",
                60,
            ),
            "pokemon_tower_ceiling.compact.png": (
                (256, 256),
                "aa644a270b3e29a4b729c59b6b0a96"
                "a110076942f44e2d80d8b671c3190e5530",
                48,
            ),
        }
        for name, (size, digest, minimum_unique_blocks) in specs.items():
            path = ROOT / "assets" / "scenery" / name
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)
            with Image.open(path) as source:
                image = source.convert("RGBA")
            self.assertEqual(image.size, size)
            self.assertEqual(image.getchannel("A").getextrema(), (255, 255))
            self.assertEqual(len(image.getcolors(maxcolors=1 << 20)), 24)
            self.assertEqual(
                list(image.crop((0, 0, 1, image.height)).getdata()),
                list(image.crop((image.width - 1, 0,
                                 image.width, image.height)).getdata()),
                f"{name} horizontal repeat edge drifted",
            )
            blocks = {
                image.crop((x, y, x + 32, y + 32)).tobytes()
                for y in range(0, image.height, 32)
                for x in range(0, image.width, 32)
            }
            self.assertGreaterEqual(len(blocks), minimum_unique_blocks,
                                    f"{name} regressed to a small wallpaper")
            if name == "pokemon_tower_wall.compact.png":
                self.assertEqual(
                    list(image.crop((255, 0, 256, image.height)).getdata()),
                    list(image.crop((256, 0, 257, image.height)).getdata()),
                    "Tower's two authored wall bays lost their post join",
                )
            else:
                self.assertEqual(
                    list(image.crop((0, 0, image.width, 1)).getdata()),
                    list(image.crop((0, image.height - 1,
                                     image.width, image.height)).getdata()),
                    "Tower ceiling vertical repeat edge drifted",
                )

    def test_pokecenter_room_materials_are_native_opaque_seamless_tiles(
        self,
    ) -> None:
        """The two-center room shell keeps its reviewed compact pixel inputs."""
        from PIL import Image

        specs = {
            "pokecenter_room_wall.compact.png": (
                (128, 160),
                "2cb759ed9cc1afed883a2b3435438ede"
                "2e41e97f2f72d465226d22f012bd061a",
            ),
            "pokecenter_room_ceiling.compact.png": (
                (128, 128),
                "a59a180adb7c5b819631077cd4c9e5cc"
                "bd70a8536c7ac7d70f4a246769c257ac",
            ),
        }
        for name, (size, digest) in specs.items():
            path = ROOT / "assets" / "scenery" / name
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)
            with Image.open(path) as source:
                image = source.convert("RGBA")
            self.assertEqual(image.size, size)
            self.assertEqual(image.getchannel("A").getextrema(), (255, 255))
            self.assertEqual(len(image.getcolors(maxcolors=1 << 20)), 24)
            self.assertEqual(
                list(image.crop((0, 0, 1, image.height)).getdata()),
                list(image.crop((image.width - 1, 0,
                                 image.width, image.height)).getdata()),
                f"{name} horizontal repeat edge drifted",
            )
            if name == "pokecenter_room_ceiling.compact.png":
                self.assertEqual(
                    list(image.crop((0, 0, image.width, 1)).getdata()),
                    list(image.crop((0, image.height - 1,
                                     image.width, image.height)).getdata()),
                    f"{name} vertical repeat edge drifted",
                )

    def test_coastal_landmarks_have_irregular_rock_feet(self) -> None:
        """V3 ends on row 88 without restoring a broad water/card ribbon."""
        from PIL import Image

        path = ROOT / "assets" / "scenery" / "coastal_landmarks_v3.compact.png"
        with Image.open(path) as source:
            image = source.convert("RGBA")
        self.assertEqual(image.size, (512, 128))

        expected_bounds = (
            (20, 50, 108, 89),
            (24, 29, 104, 89),
            (16, 56, 112, 89),
            (28, 60, 100, 89),
        )
        for module in range(4):
            alpha = image.crop((module * 128, 0, (module + 1) * 128, 128)) \
                         .getchannel("A")
            bounds = alpha.getbbox()
            self.assertIsNotNone(bounds, f"coastal module {module} is empty")
            self.assertEqual(bounds, expected_bounds[module],
                             f"coastal module {module} BBox drifted")
            self.assertEqual(bounds[3] - 1, 88,
                             f"coastal module {module} waterline moved")
            self.assertGreaterEqual(bounds[0], 4,
                                    f"coastal module {module} clips left")
            self.assertLessEqual(bounds[2], 124,
                                 f"coastal module {module} clips right")
            self.assertGreaterEqual(bounds[1], 2,
                                    f"coastal module {module} clips top")
            self.assertLessEqual(
                len({pixel[:3] for pixel in image.crop(
                    (module * 128, 0, (module + 1) * 128, 128)
                ).getdata() if pixel[3] == 255}),
                48,
                f"coastal module {module} palette exceeded 48 colors",
            )
            self.assertLessEqual(set(alpha.getdata()), {0, 255},
                f"coastal module {module} alpha softened")

            for y in range(81, 89):
                row = [alpha.getpixel((x, y)) == 255 for x in range(128)]
                runs, current = [], 0
                for opaque in row:
                    if opaque:
                        current += 1
                    elif current:
                        runs.append(current)
                        current = 0
                if current:
                    runs.append(current)
                subject_width = bounds[2] - bounds[0]
                self.assertLess(sum(runs), math.ceil(subject_width * 0.90),
                                f"coastal module {module} regained a base")
                self.assertLess(max(runs, default=0),
                                math.ceil(subject_width * 0.85),
                                f"coastal module {module} regained a ribbon")
            self.assertLessEqual(
                sum(alpha.getpixel((x, 88)) == 255 for x in range(128)),
                16,
                f"coastal module {module} lost its sparse rock foot",
            )
            self.assertFalse(
                any(all(alpha.getpixel((x, y)) == 255 for x in range(128))
                    for y in range(128)),
                f"coastal module {module} regained a full-width alpha row",
            )

    def test_coastal_cadence_uses_native_binary_harbor_tail(self) -> None:
        """The 32px low stage is an unchanged 1:1 crop, not a new texture."""
        from PIL import Image

        path = ROOT / "assets" / "scenery" / "harbor_edge.compact.png"
        self.assertEqual(
            hashlib.sha256(path.read_bytes()).hexdigest(),
            "31ea5d0d9fd948b9ddf185e426548bdd"
            "4b3b713b05a9ec691c2bffabbf735edb",
        )
        with Image.open(path) as source:
            image = source.convert("RGBA")
        self.assertEqual(image.size, (512, 128))
        crop = image.crop((480, 0, 512, 128))
        alpha = crop.getchannel("A")
        self.assertEqual(crop.size, (32, 128))
        self.assertEqual(alpha.getbbox(), (0, 87, 32, 118))
        self.assertLessEqual(set(alpha.getdata()), {0, 255})
        self.assertLessEqual(
            len({pixel[:3] for pixel in crop.getdata() if pixel[3] == 255}),
            48,
            "coastal cadence low crop escaped the reviewed retro palette",
        )

    def test_cinnabar_story_landmarks_are_compact_transparent_cutouts(self) -> None:
        """The optional volcano/Birth-Island lane has no baked sky or matte."""
        from PIL import Image

        path = ROOT / "assets" / "scenery" / \
            "cinnabar_story_landmarks.compact.png"
        self.assertEqual(
            hashlib.sha256(path.read_bytes()).hexdigest(),
            "ddbfeac791b1b35fa5571277f9a85da9d310e8082427cff1b751c53fb5fa84ba",
        )
        with Image.open(path) as source:
            self.assertEqual(source.mode, "RGBA")
            image = source.copy()
        self.assertEqual(image.size, (512, 128))
        self.assertEqual(image.getchannel("A").getextrema(), (0, 255))
        expected_bounds = ((18, 15, 238, 119), (30, 35, 226, 119))
        sample_limits = ((220, 110), (196, 98))
        for index, (expected, limit) in enumerate(
                zip(expected_bounds, sample_limits)):
            module = image.crop((index * 256, 0, (index + 1) * 256, 128))
            alpha = module.getchannel("A")
            self.assertEqual(alpha.getbbox(), expected)
            self.assertLessEqual(expected[2] - expected[0], limit[0])
            self.assertLessEqual(expected[3] - expected[1], limit[1])
            self.assertTrue(
                any(0 < opacity < 255 for opacity in alpha.getdata()),
                f"story module {index} lost its antialiased coast",
            )
            self.assertFalse(any(alpha.getpixel((x, 0)) for x in range(256)))
            self.assertLessEqual(
                len({pixel[:3] for pixel in module.getdata() if pixel[3] == 255}),
                96,
            )
            self.assertTrue(all(
                pixel[:3] == (0, 0, 0)
                for pixel in module.getdata() if pixel[3] == 0
            ), f"story module {index} retained a colored transparent matte")
            self.assertLessEqual(
                sum(alpha.getpixel((x, 127)) == 255 for x in range(256)),
                24,
            )

    def test_cinnabar_story_landmarks_are_reproducible(self) -> None:
        """The shipped two-island atlas rebuilds from hash-pinned masters."""
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / "cinnabar-story.png"
            subprocess.run(
                ["python3", "tools/build_cinnabar_story_landmarks.py",
                 "--output", str(output)],
                cwd=ROOT, check=True, text=True, capture_output=True,
            )
            shipped = ROOT / "assets" / "scenery" / \
                "cinnabar_story_landmarks.compact.png"
            self.assertEqual(output.read_bytes(), shipped.read_bytes())

    def test_coastal_landmarks_v2_is_reproducible(self) -> None:
        """The shipped V2 bitmap must rebuild solely from retained repo sources."""
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / "coastal.png"
            subprocess.run(
                ["python3", "tools/build_coastal_landmarks_v2.py",
                 "--output", str(output)],
                cwd=ROOT, check=True, text=True, capture_output=True,
            )
            shipped = ROOT / "assets" / "scenery" / \
                "coastal_landmarks_v2.compact.png"
            self.assertEqual(output.read_bytes(), shipped.read_bytes())

    def test_coastal_landmarks_v3_is_reproducible(self) -> None:
        """The shipped V3 bitmap rebuilds solely from retained repo sources."""
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / "coastal.png"
            subprocess.run(
                ["python3", "tools/build_coastal_landmarks_v3.py",
                 "--output", str(output)],
                cwd=ROOT, check=True, text=True, capture_output=True,
            )
            shipped = ROOT / "assets" / "scenery" / \
                "coastal_landmarks_v3.compact.png"
            self.assertEqual(output.read_bytes(), shipped.read_bytes())

    def test_viridian_forest_gate_is_reproducible(self) -> None:
        """The shipped facade rebuilds from the hash-pinned Gen I atlas."""
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / "forest-gate.png"
            subprocess.run(
                ["python3", "tools/build_viridian_forest_gate.py",
                 "--output", str(output)],
                cwd=ROOT, check=True, text=True, capture_output=True,
            )
            shipped = ROOT / "assets" / "scenery" / \
                "viridian_forest_gate.compact.png"
            self.assertEqual(output.read_bytes(), shipped.read_bytes())

    def test_export_facade_source_is_exact_allowlist(self) -> None:
        source = (ROOT / "main.lua").read_text(encoding="utf-8")
        self.assertNotIn("mod.exports.lib = V", source)
        match = re.search(r"local publicModules = \{(.*?)\n\}", source, re.S)
        self.assertIsNotNone(match)
        names = set(re.findall(r"^\s*([A-Za-z0-9_]+)\s*=", match.group(1), re.M))
        self.assertEqual(names, EXPECTED_PUBLIC)
        self.assertIn("mod.exports.lib = PublicFacade.new(publicModules)", source)

    def test_battle_huds_stay_in_centered_engine_frame(self) -> None:
        source = (ROOT / "lib" / "OverworldBattle.lua").read_text(
            encoding="utf-8"
        )
        start = source.index("function OverworldBattle.update(dt)")
        end = source.index("function OverworldBattle.shot()", start)
        update = source[start:end]
        self.assertNotIn("OverworldBattle.snapHUDs", update)
        self.assertIn("session.snapped = false", update)
        self.assertIn("return innerHUDs(self, slide, ...)", source)

    def test_battle_grid_and_shadows_are_player_controls(self) -> None:
        main = (ROOT / "main.lua").read_text(encoding="utf-8")
        grid = (ROOT / "lib" / "VoxelGrid.lua").read_text(encoding="utf-8")
        battle = (ROOT / "lib" / "BattleScene.lua").read_text(
            encoding="utf-8"
        )
        shadows = (ROOT / "lib" / "Shadows.lua").read_text(encoding="utf-8")
        scene = (ROOT / "lib" / "VoxelScene.lua").read_text(encoding="utf-8")
        voxel = (ROOT / "lib" / "Voxel3D.lua").read_text(encoding="utf-8")

        self.assertIn("VoxelGrid.battleSetting", main)
        self.assertIn("Shadows.setting", main)
        self.assertIn('VoxelGrid.BATTLE_KEY = "battleGrid"', grid)
        self.assertIn("VoxelGrid.battleEnabled()", battle)
        self.assertNotIn("VoxelGrid.override = true", battle)
        self.assertIn("shadowModel = monMatrix", battle)
        self.assertIn("ShadowMap.snug(card.shadowModel)", battle)
        self.assertNotIn("ShadowMap.snug(card.model)", battle)
        self.assertIn('Shadows.KEY = "shadows"', shadows)
        self.assertIn("if not Shadows.enabled() then return end", scene)
        self.assertIn("Shadows.enabled() and ShadowMap.active()", voxel)

    def test_render_controls_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run([str(lua), "tests/render_controls_test.lua"], cwd=ROOT,
                       check=True, text=True, capture_output=True)

    def test_voxel_view_shortcuts_runtime(self) -> None:
        main = (ROOT / "main.lua").read_text(encoding="utf-8")
        self.assertIn('local VoxelShortcut = V.require("VoxelShortcut")', main)
        self.assertIn("VoxelShortcut.install(cycleVoxel)", main)
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run([str(lua), "tests/voxel_shortcut_test.lua"], cwd=ROOT,
                       check=True, text=True, capture_output=True)

    def test_player_camera_modes_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run([str(lua), "tests/camera_modes_test.lua"], cwd=ROOT,
                       check=True, text=True, capture_output=True)

    def test_ledge_elevation_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run([str(lua), "tests/ledge_elevation_test.lua"], cwd=ROOT,
                       check=True, text=True, capture_output=True)

    def test_ledge_geometry_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run([str(lua), "tests/ledge_geometry_test.lua"], cwd=ROOT,
                       check=True, text=True, capture_output=True)

    def test_cavern_void_floor_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run([str(lua), "tests/cavern_void_floor_test.lua"],
                       cwd=ROOT, check=True, text=True, capture_output=True)

    def test_building_terrace_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run([str(lua), "tests/building_terrace_test.lua"], cwd=ROOT,
                       check=True, text=True, capture_output=True)

    def test_battle_sprite_modes_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run([str(lua), "tests/battle_sprite_modes_test.lua"],
                       cwd=ROOT, check=True, text=True, capture_output=True)

    def test_battle_camera_distance_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run([str(lua), "tests/battle_camera_distance_test.lua"],
                       cwd=ROOT, check=True, text=True, capture_output=True)

        main = (ROOT / "main.lua").read_text(encoding="utf-8")
        camera = (ROOT / "lib" / "BattleCam.lua").read_text(
            encoding="utf-8"
        )
        battle = (ROOT / "lib" / "BattleScene.lua").read_text(
            encoding="utf-8"
        )
        self.assertIn('DISTANCE_KEY = "battleCameraDistance"', camera)
        self.assertIn("{ 1, 2, 3 }, { \"1X\", \"2X\", \"3X\" }", camera)
        self.assertIn("BattleCam.distanceSetting", main)
        # BattleScene selects MAP versus DISCS before this single shared rig
        # call, so both 3D branches inherit the setting without touching the
        # engine's flat battle/HUD composition.
        mode = battle.index("local discs = arena.discs")
        rig = battle.index("local cam, pitch = BattleCam.rig", mode)
        self.assertGreater(rig, mode)
        hud_start = (ROOT / "lib" / "OverworldBattle.lua").read_text(
            encoding="utf-8"
        ).index("function BattleState:drawHUDs")
        hud = (ROOT / "lib" / "OverworldBattle.lua").read_text(
            encoding="utf-8"
        )[hud_start:hud_start + 700]
        self.assertNotIn("distanceSetting", hud)

    def test_cinnabar_battle_arena_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run([str(lua), "tests/battle_arena_cinnabar_test.lua"],
                       cwd=ROOT, check=True, text=True, capture_output=True)

    def test_battle_anchor_selection_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run([str(lua), "tests/battle_anchor_selection_test.lua"],
                       cwd=ROOT, check=True, text=True, capture_output=True)

    def test_battle_scene_uses_closed_progressive_plan(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run([str(lua), "tests/battle_scene_horizon_test.lua"],
                       cwd=ROOT, check=True, text=True, capture_output=True)

        battle = (ROOT / "lib" / "BattleScene.lua").read_text(
            encoding="utf-8"
        )
        self.assertIn("local terrain, nbMesh, water, nbWater, plan =",
                      battle)
        self.assertIn("HorizonWall.meshes(plan.state)", battle)
        self.assertIn("for _, rim in ipairs(horizon or {}) do", battle)

    def test_battle_weather_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run([str(lua), "tests/battle_weather_test.lua"],
                       cwd=ROOT, check=True, text=True, capture_output=True)
        battle = (ROOT / "lib" / "BattleScene.lua").read_text(
            encoding="utf-8"
        )
        self.assertIn('local Weather = V.require("Weather")', battle)
        self.assertIn("local weatherMode = BattleScene.weatherMode(host)",
                      battle)
        self.assertIn("weather = weatherMode", battle)
        self.assertIn("arena = discs and arena.arenaStyle and true or false",
                      battle)
        self.assertIn("BattleScene.applyWeather(rendered, rw, rh, host,",
                      battle)
        self.assertIn("local outdoor = Weather.isOutdoor(host)", battle)
        self.assertIn("Weather.applyBattle or Weather.apply", battle)

    def test_ios_battle_canvas_orientation_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/ios_canvas_presentation_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )
        voxel = (ROOT / "lib" / "Voxel3D.lua").read_text(encoding="utf-8")
        weather = (ROOT / "lib" / "Weather.lua").read_text(encoding="utf-8")
        self.assertIn("CanvasPresentation.imageDraw", voxel)
        self.assertIn("CanvasPresentation.rectY", voxel)
        self.assertIn("CanvasPresentation.pointY", voxel)
        self.assertIn("CanvasPresentation.begin2D", weather)

    def test_water_sky_dither_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run([str(lua), "tests/water_sky_dither_test.lua"],
                       cwd=ROOT, check=True, text=True, capture_output=True)
        scene = (ROOT / "lib" / "VoxelScene.lua").read_text(
            encoding="utf-8"
        )
        water = (ROOT / "lib" / "Water.lua").read_text(encoding="utf-8")
        self.assertIn("skyRay = Voxel3D.skyRayLive", scene)
        self.assertIn("Sky.ditherStart(ctx.skyRay)", water)

    def test_weather_modes_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run([str(lua), "tests/weather_modes_test.lua"], cwd=ROOT,
                       check=True, text=True, capture_output=True)

    def test_environment_controls_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run([str(lua), "tests/environment_controls_test.lua"],
                       cwd=ROOT, check=True, text=True, capture_output=True)

    def test_viridian_forest_gate_overlays_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/forest_gate_overlay_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_regional_horizon_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run([str(lua), "tests/regional_horizon_test.lua"],
                       cwd=ROOT, check=True, text=True, capture_output=True)
        generated = ROOT.parent / "gen1recomp"
        for relative in (
            "data/generated/maps.lua",
            "data/generated/tilesets.lua",
            "src/world/Map.lua",
        ):
            self.assertTrue((generated / relative).is_file(),
                            f"missing outdoor audit fixture: {relative}")
        subprocess.run(
            [str(lua), "tools/audit_outdoor_transitions.lua",
             str(generated)],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_outdoor_specials_and_south_sea_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/outdoor_specials_sea_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_open_sea_structure_normalization_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/open_sea_structure_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_south_sea_rework_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/south_sea_rework_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_saffron_route8_turn_material_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/saffron_route8_turn_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_outdoor_cave_portals_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/outdoor_cave_portal_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_panorama_audit_driver_helpers_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        for script in (
            "tests/panorama_audit_driver_test.lua",
            "tests/battle_visual_qa_driver_test.lua",
            "tests/manual_transition_qa_driver_test.lua",
            "tests/transition_reveal_gate_test.lua",
        ):
            command = [str(lua), script]
            if script.endswith("transition_reveal_gate_test.lua"):
                command.append(str(exact_gen1recomp_0190_root()))
            subprocess.run(
                command, cwd=ROOT, check=True, text=True,
                capture_output=True,
            )

    def test_pointer_input_uses_frozen_public_hook_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/pointer_input_compat_test.lua",
             str(exact_gen1recomp_0190_root())],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_device_profile_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/device_profile_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_battle_party_balls_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/battle_party_balls_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_battle_arena_style_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/battle_arena_style_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_battle_arena_backdrop_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/battle_arena_backdrop_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_sprite_pack_hooks_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/sprite_pack_hooks_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )
        subprocess.run(
            [str(lua), "tests/local_sprites_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_warp_destination_prefetch_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/warp_prefetch_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_battle_music_pack_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/battle_music_pack_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )
        subprocess.run(
            [str(lua), "tests/local_music_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_canopy_sky_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run([str(lua), "tests/canopy_sky_test.lua"], cwd=ROOT,
                       check=True, text=True, capture_output=True)

    def test_sky_anchors_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run([str(lua), "tests/sky_anchor_test.lua"], cwd=ROOT,
                       check=True, text=True, capture_output=True)

    def test_sky_events_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run([str(lua), "tests/sky_events_test.lua"], cwd=ROOT,
                       check=True, text=True, capture_output=True)

    def test_building_rear_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run([str(lua), "tests/building_rear_test.lua"], cwd=ROOT,
                       check=True, text=True, capture_output=True)

    def test_buildings_cold_model_is_frame_budgeted(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run([str(lua), "tests/buildings_budget_test.lua"], cwd=ROOT,
                       check=True, text=True, capture_output=True)

    def test_saffron_sparse_building_shell_matches_dense_reference(self) -> None:
        """The fast shell path must preserve the complete real map mesh."""
        from PIL import Image

        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")

        engine = ROOT.parent / "gen1recomp"
        atlas_path = (engine / "assets" / "generated" / "tilesets"
                      / "overworld.png")
        self.assertTrue(atlas_path.is_file(), "generated OVERWORLD atlas missing")
        with Image.open(atlas_path) as source:
            atlas = source.convert("RGBA")
            self.assertEqual(atlas.size, (128, 48))
            rgba = atlas.tobytes()

        def profile(mode: str) -> dict[str, str]:
            result = subprocess.run(
                [str(lua), "tools/profile_real_map_build.lua", str(engine),
                 "SAFFRON_CITY", "0.005", mode],
                cwd=ROOT, input=rgba, check=True, capture_output=True,
            )
            first = result.stdout.decode("utf-8").splitlines()[0]
            self.assertTrue(first.startswith("PROFILE "), first)
            return dict(field.split("=", 1) for field in first.split()[1:])

        dense = profile("dense-geometry")
        sparse = profile("geometry")
        exact = {
            "models": "10",
            "voxels": "5223047",
            "quads": "56021",
            # Eight door-bearing Saffron buildings retain their native 2x2
            # entrance on the visible north facade: +32 quads in the same
            # terrain/building sink, with no new draw or texture.
            "terrain_quads": "203648",
            # The 31 Saffron T-junction tops select existing $39 UVs; the
            # northbound 17 use the frozen alternating 90-degree phase.
            # Compact one-storey gables opt into the reviewed 1.4 Y scale;
            # positions, topology and every geometry budget above stay exact.
            "geometry_digest": "448053113",
        }
        for field, expected in exact.items():
            self.assertEqual(dense[field], expected,
                             f"dense Saffron reference {field} drifted")
            self.assertEqual(sparse[field], expected,
                             f"sparse Saffron shell changed {field}")

    def test_overworld_hull_bounds_match_legacy_real_maps(self) -> None:
        """The smaller tree-ring analysis domain is a semantic no-op."""
        from PIL import Image

        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")

        engine = ROOT.parent / "gen1recomp"
        atlas_path = (engine / "assets" / "generated" / "tilesets"
                      / "overworld.png")
        self.assertTrue(atlas_path.is_file(), "generated OVERWORLD atlas missing")
        with Image.open(atlas_path) as source:
            atlas = source.convert("RGBA")
            self.assertEqual(atlas.size, (128, 48))
            rgba = atlas.tobytes()

        def profile(map_id: str, mode: str,
                    payload: bytes | bytearray = rgba) -> dict[str, str]:
            result = subprocess.run(
                [str(lua), "tools/profile_real_map_build.lua", str(engine),
                 map_id, "0.001", mode],
                cwd=ROOT, input=payload, check=True, capture_output=True,
            )
            first = result.stdout.decode("utf-8").splitlines()[0]
            self.assertTrue(first.startswith("PROFILE "), first)
            return dict(field.split("=", 1) for field in first.split()[1:])

        # Route 8 plus the seven maps in its retained QA neighbourhood.  The
        # profiler's legacy mode loads the same Structures source with only
        # the new ROUND_RING clamp disabled; each process also asserts that
        # collision and warp behavior are unchanged by its own full build.
        map_ids = (
            "ROUTE_8", "SAFFRON_CITY", "LAVENDER_TOWN", "ROUTE_5",
            "ROUTE_6", "ROUTE_7", "ROUTE_10", "ROUTE_12",
        )
        semantic_fields = (
            "models", "voxels", "quads", "terrain_quads",
            "geometry_digest", "structures_digest", "structure_nodes",
            "structure_atoms", "collision_digest", "warps_digest",
        )
        total_saved = 0
        route8_optimized = None
        for map_id in map_ids:
            optimized = profile(map_id, "geometry")
            legacy = profile(map_id, "legacy-geometry")
            if map_id == "ROUTE_8":
                route8_optimized = optimized
            for field in semantic_fields:
                self.assertEqual(
                    optimized[field], legacy[field],
                    f"{map_id} hull-bound optimization changed {field}",
                )
            saved = int(legacy["budget_ticks"]) - int(
                optimized["budget_ticks"]
            )
            self.assertGreater(saved, 0, f"{map_id} did not reduce scan work")
            total_saved += saved
        self.assertEqual(total_saved, 49_680)

        # Route 8 has three exact wall regions whose generic object analysis
        # returns every source tile unchanged.  The guarded negative receipt
        # must preserve the entire real-map graph and mesh while removing the
        # historical pixel/flood work.  `object-reference` disables only that
        # return in-memory, leaving the checked-in source untouched.
        self.assertIsNotNone(route8_optimized)
        route8_reference = profile("ROUTE_8", "object-reference-geometry")
        for field in semantic_fields:
            self.assertEqual(
                route8_optimized[field], route8_reference[field],
                f"Route8 volume receipt changed {field}",
            )
        exact_route8 = {
            "models": "2",
            "voxels": "229655",
            "quads": "5558",
            # Route 8 has no reviewed two-sided gate: cosmetic rear doors are
            # absent in both optimized and historical object paths.
            "terrain_quads": "22953",
            "geometry_digest": "224994826",
            # Runtime building faces are retained as one flat numeric record
            # per quad instead of nine nested corner/UV tables. The rendered
            # geometry digest above remains exact while the internal graph is
            # intentionally much smaller.
            "structures_digest": "2101816750:644595139",
            "structure_nodes": "32159",
            "structure_atoms": "484573",
            "collision_digest": "3573221619:841077224",
            "warps_digest": "3059780264:1422021758",
            "budget_ticks": "92973",
        }
        for field, expected in exact_route8.items():
            self.assertEqual(route8_optimized[field], expected,
                             f"Route8 optimized {field} drifted")
        self.assertEqual(
            int(route8_reference["budget_ticks"])
            - int(route8_optimized["budget_ticks"]),
            240_228,
        )

        def same_profile(left: dict[str, str], right: dict[str, str],
                         label: str) -> None:
            for field in (*semantic_fields, "budget_ticks"):
                self.assertEqual(left[field], right[field],
                                 f"{label} did not use historical path: {field}")

        # Full block-map drift rejects all receipts.
        mutated_block = profile("ROUTE_8", "mutated-block-geometry")
        mutated_block_reference = profile(
            "ROUTE_8", "object-reference-mutated-block-geometry")
        same_profile(mutated_block, mutated_block_reference, "block mutation")

        # The outdoor detector seeds its complete southern apron. Flipping one
        # adjacent air cell must reject that one receipt while the other two
        # canonical regions may still retain their independent fast paths.
        mutated_apron = profile("ROUTE_8", "mutated-apron-geometry")
        mutated_apron_reference = profile(
            "ROUTE_8", "object-reference-mutated-apron-geometry")
        for field in semantic_fields:
            self.assertEqual(mutated_apron[field],
                             mutated_apron_reference[field],
                             f"apron mutation changed historical {field}")
        self.assertGreater(int(mutated_apron["budget_ticks"]),
                           int(route8_optimized["budget_ticks"]) + 40_000)
        self.assertLess(int(mutated_apron["budget_ticks"]),
                        int(mutated_apron_reference["budget_ticks"]))

        # Indoor semantics seed all four aprons, so the outdoor-only receipt
        # must reject before applying its south-only proof.
        mutated_outdoor = profile("ROUTE_8", "mutated-outdoor-geometry")
        mutated_outdoor_reference = profile(
            "ROUTE_8", "object-reference-mutated-outdoor-geometry")
        same_profile(mutated_outdoor, mutated_outdoor_reference,
                     "outdoor mutation")

        # A different-size ImageData returns false before the first pixel
        # lookup; the real detector still consumes the valid test buffer.
        malformed_dimensions = profile(
            "ROUTE_8", "malformed-dimensions-geometry")
        malformed_dimensions_reference = profile(
            "ROUTE_8", "object-reference-malformed-dimensions-geometry")
        same_profile(malformed_dimensions, malformed_dimensions_reference,
                     "dimension mutation")

        # Flip one exact detector-candidate bit in tile $11, but supply it as
        # a different ImageData identity. The cached canonical receipt must
        # not admit it, and optimized/reference work must become identical.
        mutated_rgba = bytearray(rgba)
        tile = 0x11
        changed = False
        for py in range(8):
            for px in range(8):
                at = (((tile // 16) * 8 + py) * 128
                      + (tile % 16) * 8 + px) * 4
                r, g, b, a = mutated_rgba[at:at + 4]
                if a == 0 or min(r, g, b) / 255 > 0.83:
                    mutated_rgba[at:at + 4] = bytes((0, 0, 0, 255))
                    changed = True
                    break
            if changed:
                break
        self.assertTrue(changed, "Route8 $11 candidate fixture disappeared")
        mutated_atlas = profile("ROUTE_8", "geometry", mutated_rgba)
        mutated_atlas_reference = profile(
            "ROUTE_8", "object-reference-geometry", mutated_rgba)
        same_profile(mutated_atlas, mutated_atlas_reference,
                     "atlas mutation")

        # Directly exercises malformed nonnumeric bounds against the private
        # receipt. The profiler asserts pcall success and a false result.
        malformed_receipt = profile("ROUTE_8", "malformed-receipt-geometry")
        for field in semantic_fields:
            self.assertEqual(malformed_receipt[field],
                             route8_optimized[field],
                             f"malformed receipt probe changed {field}")

    def test_chunk_mesher_upload_is_frame_budgeted(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run([str(lua), "tests/chunk_mesher_async_test.lua"],
                       cwd=ROOT, check=True, text=True, capture_output=True)

    def test_chunk_mesher_instancing_and_atomic_aux_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/chunk_mesher_instancing_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_shadow_map_keeps_its_fitted_canvas_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/shadow_map_canvas_retention_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_structures_cold_scans_are_frame_budgeted(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run([str(lua), "tests/structures_budget_test.lua"],
                       cwd=ROOT, check=True, text=True, capture_output=True)

    def test_safari_structure_foot_trim_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/safari_structure_trim_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_terrain_atlas_retains_previous_neighbourhood(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/terrain_atlas_retention_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_day_night_exact_mix_is_reused_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/day_night_mix_cache_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_voxel_scene_reuses_map_palette_per_render_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/voxel_scene_palette_cache_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_first_person_actor_near_cull_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/first_person_actor_near_cull_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_glass_mask_first_visit_is_prepared_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/glass_mask_first_visit_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_redpp_atlas_first_visit_uses_exact_readback_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/terrain_atlas_first_visit_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_atlas_cold_neighbour_waits_behind_horizon_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/voxel_scene_atlas_gate_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_kanto_ascendant_menu_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run([str(lua), "tests/kanto_ascendant_menu_test.lua"],
                       cwd=ROOT, check=True, text=True, capture_output=True)
        subprocess.run([str(lua), "tests/vasc_menu_test.lua"],
                       cwd=ROOT, check=True, text=True, capture_output=True)

    def test_building_rear_is_exterior_only(self) -> None:
        source = (ROOT / "lib" / "Buildings.lua").read_text(encoding="utf-8")
        self.assertIn("local plainRear = S.outdoor == true", source)
        self.assertIn('(plainRear and ":rear" or ":copy")', source)
        self.assertIn("local pr = measure(sp, t, plainRear)", source)
        self.assertIn("if pr.rear then return pr.rear[i]", source)
        self.assertIn("return i", source)

    def test_battle_back_sprites_are_independent(self) -> None:
        main = (ROOT / "main.lua").read_text(encoding="utf-8")
        battle = (ROOT / "lib" / "OverworldBattle.lua").read_text(
            encoding="utf-8"
        )
        self.assertIn('POKEMON_BACK_KEY = "battleBack"', battle)
        self.assertIn('TRAINER_BACK_KEY = "trainerBack"', battle)
        self.assertIn("OverworldBattle.trainerBackSetting", main)
        self.assertIn("OverworldBattle.pokemonBackSetting", main)
        self.assertIn("OverworldBattle.wantsTrainerFront()", main)
        self.assertIn("trainer = OverworldBattle.trainerBackPinned()", battle)

    def test_cold_map_current_lands_with_atomic_decorations(self) -> None:
        scene = (ROOT / "lib" / "VoxelScene.lua").read_text(encoding="utf-8")
        mesher = (ROOT / "lib" / "ChunkMesher.lua").read_text(
            encoding="utf-8"
        )
        self.assertIn(
            "local preferBody = HorizonWall.preferBody(state.map)", scene
        )
        self.assertIn("ChunkMesher.request(state.map, preferBody,", scene)
        self.assertEqual(scene.count("ChunkMesher.request(state.map,"), 2)
        self.assertIn(
            "ChunkMesher.request(state.map, false, masks, true)", scene
        )
        self.assertIn("plan.horizonFallback = true", scene)
        self.assertNotIn("ChunkMesher.peek(state.map", scene)
        self.assertIn("preferBody and nil or masks", scene)
        self.assertIn("ChunkMesher.pair(state.map, preferBody)", scene)
        self.assertNotIn("ChunkMesher.pair(state.map, not preferBody)", scene)
        self.assertIn(
            "ChunkMesher.request(nb.map, true, nil, not preferBody,", scene
        )
        self.assertIn("if i == approachedIndex then backgroundRank = 2", scene)
        self.assertIn("elseif directSet[nb.map.id] then backgroundRank = 1",
                      scene)
        self.assertIn("backgroundRank)", scene)

        run_job_start = mesher.index("local function runJob(job)")
        run_job = mesher[
            run_job_start:
            mesher.index("function ChunkMesher.request", run_job_start)
        ]
        self.assertLess(run_job.index("buildJobTerrain(job)"),
                        run_job.index("atomicAux"))
        self.assertLess(run_job.index("buildAux(job, map)"),
                        run_job.index('swapSlot(c, job.slot'))
        self.assertLess(run_job.index("if auxComplete(c)"),
                        run_job.index('coroutine.yield("terrain-ready")'))
        self.assertIn("needsAtomicAux", run_job)
        self.assertIn("landAux(c, aux)", run_job)

    def test_instancing_shader_and_retained_grass_contract(self) -> None:
        voxel = (ROOT / "lib" / "Voxel3D.lua").read_text(encoding="utf-8")
        shadow = (ROOT / "lib" / "ShadowMap.lua").read_text(
            encoding="utf-8"
        )
        structures = (ROOT / "lib" / "Structures.lua").read_text(
            encoding="utf-8"
        )
        mesher = (ROOT / "lib" / "ChunkMesher.lua").read_text(
            encoding="utf-8"
        )
        self.assertIn("attribute vec3 InstanceOffset", voxel)
        self.assertIn("placed.xyz += InstanceOffset", voxel)
        self.assertIn("sunModel * placed", voxel)
        self.assertIn("love.graphics.drawInstanced(group.mesh, group.count)",
                      voxel)
        self.assertIn("attribute vec3 InstanceOffset", shadow)
        self.assertIn("placed.xyz += InstanceOffset", shadow)
        self.assertIn("model * placed", shadow)
        self.assertIn("love.graphics.drawInstanced(group.mesh, group.count)",
                      shadow)
        self.assertIn("supported.instancing == true", voxel)
        self.assertIn('"InstanceOffset", source,', mesher)
        self.assertIn('"perinstance"', mesher)
        self.assertIn("voxelInstancingUnsupported", mesher)
        self.assertIn("grassGroups = {}", structures)
        self.assertIn("placements = {}", structures)
        self.assertNotIn("grassQuads = {}", structures)

    def test_cold_map_swap_releases_a_closed_progressive_union(self) -> None:
        scene = (ROOT / "lib" / "VoxelScene.lua").read_text(encoding="utf-8")
        transition_qa = (ROOT / "tests" / "manual_transition_qa.lua").read_text(
            encoding="utf-8"
        )
        self.assertIn("Voxel.ready = complete", scene)
        self.assertNotIn("ChunkMesher.ready(nb.map, true)", scene)
        self.assertIn("semanticPlan(state, nbMesh, nbWater", scene)
        self.assertIn("local activeUnion, handoffUnion", scene)
        self.assertIn("futureIds[state.neighbors[candidateIndex].map.id]", scene)
        self.assertIn("visuallyReady(state.neighbors[candidateIndex]", scene)
        self.assertIn("plan = currentOnlyPlan(state)", scene)
        self.assertIn("fullHorizonReady and allReady", scene)
        self.assertIn("local drawState, drawMesh, drawWater", scene)
        self.assertIn("if not terrain or not Voxel.ready then return nil end",
                      scene)
        self.assertIn('printHorizonCacheStatus(label, "APPROACH_END")',
                      transition_qa)
        self.assertIn('printHorizonCacheStatus(label, "PRE_CROSS")',
                      transition_qa)
        self.assertIn('printHorizonCacheStatus(label, "POST_CROSS")',
                      transition_qa)
        self.assertLess(
            transition_qa.index('printHorizonCacheStatus(label, "PRE_CROSS")'),
            transition_qa.index("ow:crossConnection(direction, connection)"),
        )
        self.assertGreater(
            transition_qa.index('printHorizonCacheStatus(label, "POST_CROSS")'),
            transition_qa.index("ow:crossConnection(direction, connection)"),
        )

    def test_voxel_scene_progressive_release_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/voxel_scene_progressive_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_horizon_connection_reroot_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/horizon_reroot_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_horizon_pending_jobs_are_bounded_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/horizon_pending_cache_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_voxel_scene_seam_handoff_runtime(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run(
            [str(lua), "tests/voxel_scene_handoff_test.lua"],
            cwd=ROOT, check=True, text=True, capture_output=True,
        )

    def test_ios_battle_hud_capability_isolation(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        source = exact_kasc_656_renderer_battle_hud()
        with tempfile.TemporaryDirectory() as temp:
            exact_module = Path(temp) / "renderer_battle_hud.lua"
            exact_module.write_bytes(source)
            subprocess.run(
                [str(lua), "tests/ios_battle_hud_test.lua", str(exact_module)],
                cwd=ROOT, check=True, text=True, capture_output=True,
            )

    def test_ios_battle_hud_zone_pixel_acceptance(self) -> None:
        engine = exact_gen1recomp_0190_root()
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / "ios-hud-bad-vs-fixed.png"
            subprocess.run(
                [
                    "python3", "tests/render_ios_hud_acceptance.py",
                    "--engine-root", str(engine),
                    "--output", str(output),
                ],
                cwd=ROOT, check=True, text=True, capture_output=True,
            )
            self.assertTrue(output.is_file())
            self.assertGreater(output.stat().st_size, 1_000)

    def test_export_facade_adversarial(self) -> None:
        candidate = os.environ.get("VOXEL_ASCENDANT_LUA")
        lua = Path(candidate) if candidate else None
        if not lua or not lua.is_file():
            found = shutil.which("luajit") or shutil.which("lua")
            lua = Path(found) if found else None
        if not lua:
            self.fail("set VOXEL_ASCENDANT_LUA to a Lua/LuaJIT executable")
        subprocess.run([str(lua), "tests/public_facade_test.lua"], cwd=ROOT,
                       check=True, text=True, capture_output=True)

    def test_deterministic_direct_install_zip(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            a = Path(temp) / "a.zip"
            b = Path(temp) / "b.zip"
            for output in (a, b):
                subprocess.run(
                    ["python3", "scripts/build_release.py", "-o", str(output)],
                    cwd=ROOT, check=True, text=True, capture_output=True,
                )
            self.assertEqual(hashlib.sha256(a.read_bytes()).digest(),
                             hashlib.sha256(b.read_bytes()).digest())
            with zipfile.ZipFile(a) as archive:
                names = archive.namelist()
                self.assertIn("manifest.json", names)
                self.assertNotIn("voxel-ascendant/manifest.json", names)
                self.assertFalse(any(name.startswith(("tests/", "scripts/", ".git/"))
                                     for name in names))
                self.assertFalse(any(name.endswith("/") for name in names))
                self.assertEqual(len(names), len(set(names)))
                manifest = json.loads(archive.read("manifest.json"))
                self.assertEqual(manifest["id"], "VOXEL_ASCENDANT")
                self.assertTrue(EXPECTED_ASSETS.issubset(names))
                self.assertTrue(EXPECTED_REPO_ONLY_PNGS.isdisjoint(names))
                for guide in (
                    "user/music/README.txt",
                    "user/music/README_EN.txt",
                    "user/music/README_DE.txt",
                    "user/sprites/README.txt",
                    "user/sprites/README_EN.txt",
                    "user/sprites/README_DE.txt",
                ):
                    self.assertIn(guide, names,
                                  f"customisation guide missing: {guide}")
                guide_markers = {
                    "user/music/README_EN.txt": (
                        b"%APPDATA%", b"On My iPhone", b"Android/data",
                        b"SHUFFLE", b"BACK TO GAME / KASC",
                    ),
                    "user/music/README_DE.txt": (
                        b"WO LIEGT DER INSTALLIERTE ORDNER", b"Android/data",
                        b"ALL TO GAME/KASC",
                    ),
                    "user/sprites/README_EN.txt": (
                        b"CHARIZARD_MEGA_Y", b"SPRITE_KA_CRYSTAL_GREEN_BIKE",
                        b"On My iPhone", b"Android/data",
                    ),
                    "user/sprites/README_DE.txt": (
                        b"SPIEL/KASC WIEDERHERSTELLEN", b"Android/data",
                        b"ALL TO GAME/KASC",
                    ),
                }
                for guide, markers in guide_markers.items():
                    payload = archive.read(guide)
                    for marker in markers:
                        self.assertIn(marker, payload,
                                      f"{guide} lacks {marker!r}")
                for name in EXPECTED_ASSETS:
                    self.assertEqual(archive.read(name), (ROOT / name).read_bytes(),
                                     f"packaged asset drifted: {name}")
                for info in archive.infolist():
                    self.assertEqual(info.date_time, (1980, 1, 1, 0, 0, 0))


if __name__ == "__main__":
    unittest.main(verbosity=2)
