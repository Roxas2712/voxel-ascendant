# Voxel Ascendant

Voxel Ascendant renders the Gen1Recomp overworld as a depth-tested voxel
diorama and can stage battles in 3D using the game's own Gen 1 battle
pictures. It is a standalone graphics mod: Kanto Ascendant is supported as
an optional companion, but is not required.

This maintenance release is built only from the MIT-licensed
DramaticShapeVoxelMod v1.6.1 source tag (`790c34efff4975c91883f7f918a875530706ee12`)
plus the changes documented in this repository. No Battle Art code or assets,
Gen 2 sprite packs, Pokemon Stadium data, ROM tooling, VR binaries, or other
third-party art are included.

## Requirements and installation

- Gen1Recomp `0.1.90` or newer.
- A graphics driver with shader and depth-canvas support. Unsupported features
  fail closed to the game's normal 2D renderer.
- For an installed copy, use **Check for updates** in the launcher. Manual
  import intentionally does not overwrite a mod with the same ID.
- For a first install, select `VOXEL_ASCENDANT-0.1.4.zip` in the mod manager.
  `manifest.json` is at the ZIP root; do not unpack or re-wrap it.

Use the game's regular **OPTIONS** menu for the concise in-game controls. The
mod manager's per-mod options page exposes every stored setting and is mainly
useful for recovery or advanced configuration.

## Included features

| option | values | effect |
| --- | --- | --- |
| **VOXEL** / `3` | OFF, FULL, 15, 35, 50, 75 | Voxel diorama and orbit-camera angle. FULL is the curated preset. |
| **T-SHIFT** / `6` | OFF, 1, 2, 3 | Miniature tilt-shift blur. |
| **V-GRID** / `5` | OFF, ON | One-pixel voxel seams. |
| **V-CURVE** / `7` | OFF, 1, 2, 3 | Curves the distant world toward the horizon. |
| **WATER** / `9` | FULL, SKY, OFF | Voxel water and reflections, with safe fallbacks. |
| **DAYTIME** | DAY, NIGHT, DUSK, DAWN, CYCLE | Deterministic outdoor lighting; CYCLE is saved per journey. |
| **3D-BTL** / `8` | MAP, DISCS, OFF | Native Gen 1 battle cards on nearby voxel terrain or a procedural disc stage. |
| **BACK SPRITES** | OFF, ON | Keeps the player's classic back sprite in its normal battle slot. |
| **AA** | OFF, 2X, 4X | Supersamples the 3D pass. |

The release intentionally does not include first-/third-person free movement,
global relative-mouse hooks, VR, Horde mode, Pokemon Stadium models, ROM
import, or a disk cache. This keeps input, saves, and the filesystem entirely
inside Gen1Recomp's public/sandboxed paths.

Voxel Ascendant is maintained as a focused compatibility alternative while
older voxel renderers catch up with current Gen1Recomp releases. Its scope is
deliberately stable: renderer compatibility and serious regressions may be
fixed, but it will not grow a bundled Pokemon/trainer art collection. Battles
always use art already provided by the game or another compatible content mod.

## Compatibility

Voxel Ascendant conflicts with other mods that own the same voxel render
pipeline: `DRAMATIC_SHAPE`, `DRAMALESS_SHAPE`, `BATTLE_ART_VOXEL_FORK`,
`potato_voxel`, and `TERRARIUM`. The loader will refuse ambiguous stacks.

Kanto Ascendant can feature-detect this mod through:

```lua
local handle = mod.find("VOXEL_ASCENDANT")
local api = handle and handle.exports
if api and api.apiVersion == 1 and api.capabilities.wallDecals == 1 then
  local Voxel3D = api.Voxel3D
  local WallDecals = api.WallDecals
end
```

The stable export contract is documented in [COMPATIBILITY.md](COMPATIBILITY.md).
On iOS, Voxel Ascendant declines the optional legacy edge-HUD compositor so
companion mods fall back to Gen1Recomp's upright, centered battle HUD.

## License and provenance

The software is MIT licensed. The original copyright and license text remain
unchanged in [LICENSE](LICENSE). See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md),
[CREDITS.md](CREDITS.md), and [FORK_HISTORY.md](FORK_HISTORY.md) for the exact
source and fork record. The historical upstream changelog is retained as
[UPSTREAM_CHANGELOG.md](UPSTREAM_CHANGELOG.md) and does not describe the
current Voxel Ascendant feature set.
