# Voxel Ascendant

Voxel Ascendant renders the Gen1Recomp overworld as a depth-tested voxel
diorama and can stage battles in 3D using the game's own Gen 1 battle
pictures. It is a standalone graphics mod: Kanto Ascendant is supported as
an optional companion, but is not required.

This release candidate is built only from the MIT-licensed
DramaticShapeVoxelMod v1.6.1 source tag (`790c34efff4975c91883f7f918a875530706ee12`)
plus the changes documented in this repository. No code or art from the
unlicensed Battle Art voxel fork, no Gen 2 sprite pack, Pokemon Stadium data,
ROM tooling, or VR binaries are included. Voxel Ascendant does include a
separately documented Gen-I Crystal battle-art subset; see the provenance
section below.

## Requirements and installation

- Gen1Recomp `0.1.90` or newer.
- A graphics driver with shader and depth-canvas support. Unsupported features
  fail closed to the game's normal 2D renderer.
- Install the direct-install ZIP through the mod manager. `manifest.json` is
  at the ZIP root; do not unpack or re-wrap it.

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
| **BATTLE ART** | CRYSTAL, GEN I | Uses VASC's own bundled Gen-I Crystal Pokémon/trainer pack or the game's native art. KASC keeps priority when present. |
| **CRYSTAL MOTION** | ON, OFF | Animates supplied Crystal front cards; rear cards remain static. |
| **AA** | OFF, 2X, 4X | Supersamples the 3D pass. |

The RC intentionally does not include first-/third-person free movement,
global relative-mouse hooks, VR, Horde mode, Pokemon Stadium models, ROM
import, or a disk cache. This keeps input, saves, and the filesystem entirely
inside Gen1Recomp's public/sandboxed paths.

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

Kanto Ascendant and Voxel Ascendant do not exchange or move files at runtime.
Each package retains its own art. If both are loaded, VASC deliberately yields
Pokémon and trainer selection to KASC, while it continues to provide the voxel
world, battle stage and effects.

## License and provenance

The software is MIT licensed. The original copyright and license text remain
unchanged in [LICENSE](LICENSE). See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md),
[CREDITS.md](CREDITS.md), and [FORK_HISTORY.md](FORK_HISTORY.md) for the exact
source and fork record. The historical upstream changelog is retained as
[UPSTREAM_CHANGELOG.md](UPSTREAM_CHANGELOG.md) and does not describe the
current Voxel Ascendant feature set.
