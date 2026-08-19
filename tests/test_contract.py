#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
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
    "Voxel3D",
    "VoxelScene",
    "VoxelState",
    "WallDecals",
}
REMOVED_NAMES = (
    "FirstPerson",
    "ThirdPerson",
    "FreeMove",
    "CamControl",
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
    re.compile(
        r"\blove\.(?:mousemoved|mousepressed|mousereleased|keypressed|"
        r"keyreleased|wheelmoved)\s*="
    ),
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
        self.assertEqual(manifest["version"], "0.1.6")
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
        denied_suffixes = {".dll", ".so", ".dylib", ".png", ".jpg", ".bin",
                           ".gb", ".gbc", ".z64", ".n64", ".v64"}
        self.assertFalse(any(Path(path).suffix.lower() in denied_suffixes
                             for path in release_paths))

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

    def test_cold_map_build_exposes_terrain_progressively(self) -> None:
        scene = (ROOT / "lib" / "VoxelScene.lua").read_text(encoding="utf-8")
        mesher = (ROOT / "lib" / "ChunkMesher.lua").read_text(
            encoding="utf-8"
        )
        body_request = "ChunkMesher.request(state.map, true, nil, true)"
        full_request = "ChunkMesher.request(state.map, false, masks, true)"
        self.assertLess(scene.index(body_request), scene.index(full_request))

        run_job_start = mesher.index("local function runJob(job)")
        run_job = mesher[
            run_job_start:
            mesher.index("function ChunkMesher.request", run_job_start)
        ]
        self.assertLess(run_job.index("runGeometry("),
                        run_job.index("buildGrassMesh"))
        self.assertLess(run_job.index('swapSlot(c, job.slot'),
                        run_job.index("buildGrassMesh"))

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
                for info in archive.infolist():
                    self.assertEqual(info.date_time, (1980, 1, 1, 0, 0, 0))


if __name__ == "__main__":
    unittest.main(verbosity=2)
