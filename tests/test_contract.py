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


class ContractTests(unittest.TestCase):
    def test_manifest_contract(self) -> None:
        manifest = json.loads((ROOT / "manifest.json").read_text())
        self.assertEqual(manifest["id"], "VOXEL_ASCENDANT")
        self.assertEqual(manifest["name"], "Voxel Ascendant")
        self.assertEqual(manifest["version"], "0.1.1")
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
