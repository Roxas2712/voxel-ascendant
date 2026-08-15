# Companion compatibility API

The loader exposes this table only under the real manifest id:

```lua
local handle = mod.find("VOXEL_ASCENDANT")
local exports = handle and handle.exports
```

For `0.1.0-rc.1`, the stable fields are:

```lua
exports.version == "0.1.0-rc.1"
exports.apiVersion == 1
exports.renderer.id == "VOXEL_ASCENDANT"
exports.renderer.version == "0.1.0-rc.1"
exports.renderer.pipeline == "voxel"
exports.renderer.cameraProfile == "orbit-only"
exports.capabilities.voxelWorld == true
exports.capabilities.battleCards == { "MAP", "DISCS" }
exports.capabilities.wallDecals == 1
exports.capabilities.diskCache == false
exports.capabilities.stadium == false
exports.capabilities.vr == false
exports.Voxel3D                    -- renderer module
exports.WallDecals                 -- wall-decal module
exports.lib.require(name)          -- compatibility module resolver
```

`exports.lib` is an owner-isolated, read-only facade. It has no `mod`, `path`,
`data`, storage, content, or module-cache fields. `require(name)` returns only
an allowlisted compatibility module and returns `nil` for every other name; it
never delegates an unknown name to Voxel Ascendant's private loader.

The stable resolver names are `Voxel3D` and `WallDecals`. The RC also exposes
the following best-effort compatibility names for Kanto Ascendant and similar
feature-detecting companions: `AntiAlias`, `BattleArena`, `BattleCam`,
`OverworldBattle`, `VoxelScene`, and `VoxelState`. These extra modules may gain
new versions behind a future capability receipt; consumers must not assume
private fields or mutate them.

Consumers must feature-detect fields and versions. They must not create alias
entries in `game.mods.exports`, mutate the renderer, inspect private module
storage, or assume a removed capability.

## Wall-decals API version 1

`WallDecals.register(id, provider)` registers a provider function
`provider(map) -> array|nil`, or a table with `provider:records(map)`. Each
returned record follows Gen1Recomp's map wall-decal fields:

- `image` (required asset path)
- `cellX`, `cellY` (required map cell)
- `face` (`north`, `east`, `south`, or `west`; defaults to `south`)
- `offsetX`, `elevation`, `faceOffsetY` (optional numeric offsets)

Registration returns `true`, or `false, reason`. Re-registering an id replaces
that provider. `WallDecals.unregister(id)` removes it. `drawState(state)` is
owned by Voxel Ascendant and draws the current map plus connected neighbors
immediately before `Voxel3D.endScene()`; companions do not call it.
