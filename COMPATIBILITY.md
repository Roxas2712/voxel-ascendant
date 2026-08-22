# Companion compatibility API

The loader exposes this table only under the real manifest id:

```lua
local handle = mod.find("VOXEL_ASCENDANT")
local exports = handle and handle.exports
```

For `2.0.0`, the stable fields are:

```lua
exports.version == "2.0.0"
exports.apiVersion == 1
exports.renderer.id == "VOXEL_ASCENDANT"
exports.renderer.version == "2.0.0"
exports.renderer.pipeline == "voxel"
exports.renderer.cameraProfile == "orbit-only"
exports.renderer.overworldCameraProfile == "orbit-first-third"
exports.capabilities.voxelWorld == true
exports.capabilities.battleCards == { "MAP", "DISCS", "ARENA" }
exports.capabilities.wallDecals == 1
exports.capabilities.cameraModes == { "ORBIT", "FIRST_PERSON", "THIRD_PERSON" }
exports.capabilities.freeMovement == true
exports.capabilities.backgroundMeshCache == "memory"
exports.capabilities.skyEvents == { "RAINBOW", "PIDGEOT", "HO_OH" }
exports.capabilities.diskCache == false
exports.capabilities.stadium == false
exports.capabilities.vr == false
exports.integrations.kantoAscendantMenu.schema ==
  "voxel-ascendant/kanto-menu/v1"
exports.integrations.kantoAscendantMenu.optional == true
exports.Voxel3D                    -- renderer module
exports.WallDecals                 -- wall-decal module
exports.battleMusic.apiVersion == 1
exports.battleMusic.register(pack)
exports.lib.require(name)          -- compatibility module resolver
```

`exports.lib` is an owner-isolated, read-only facade. It has no `mod`, `path`,
`data`, storage, content, or module-cache fields. `require(name)` returns only
an allowlisted compatibility module and returns `nil` for every other name; it
never delegates an unknown name to Voxel Ascendant's private loader.

The stable resolver names are `Voxel3D` and `WallDecals`. The release also exposes
the following best-effort compatibility names for Kanto Ascendant and similar
feature-detecting companions: `AntiAlias`, `BattleArena`, `BattleCam`,
`OverworldBattle`, `VoxelScene`, and `VoxelState`. These extra modules may gain
new versions behind a future capability receipt; consumers must not assume
private fields. Reviewed cooperative companions may wrap the documented
`OverworldBattle` seams (`sideTexture`, `hudTexture`, `drawHudPanels`, and
`snapHUDs` when present) while preserving their inputs, return values, and
owner-table identity. Other module mutation is unsupported.

`OverworldBattle.snapHUDs(battle, shot)` is a best-effort legacy compositor.
It is present only after an explicitly detected non-iOS platform. On iOS the
platform's final world-canvas transform inverts HUD pixels composited into that
surface; an unavailable platform receipt also fails closed. Consumers must
feature-detect the function and keep the regular engine HUD when it is absent.

Consumers must feature-detect fields and versions. They must not create alias
entries in `game.mods.exports`, mutate renderer fields outside the cooperative
seams above, inspect private module storage, or assume a removed capability.

## Battle-music packs API version 1

Voxel Ascendant distributes no music and performs no download. A separately
installed, explicitly confirmed companion first registers its own file- or
chip-backed songs in Gen1Recomp's `music` registry, then calls
`exports.battleMusic.register(pack)`. The pack receipt requires a unique id,
label, version, HTTPS provenance URL, package SHA-256, `separateInstall=true`,
`userConfirmed=true`, and one or more tracks:

```lua
local unregister, err = exports.battleMusic.register({
  id = "MY_LICENSED_MUSIC", label = "MY MUSIC", version = "1.0.0",
  sourceUrl = "https://example.org/my-pack",
  sha256 = string.rep("a", 64),
  separateInstall = true, userConfirmed = true,
  tracks = {
    { id="My_Gen2_Wild", generation=2, scopes={wild=true} },
    { id="My_Gen2_Trainer", generation=2,
      scopes={trainer=true, gym=true, league=true} },
  },
})
```

Every id must already resolve in the merged engine music registry; arbitrary
URLs and missing song definitions are rejected. Generations 2–6 are supported.
Scopes are `wild`, `trainer`, `gym`, and `league`. Registration is live and
returns an owner-specific unregister function. The public receipt explicitly
advertises `bundledAudio=false` and `networkDownloads=false`.

## Kanto Ascendant menu integration

When current Kanto Ascendant (`kanto_ascendant`) or its legacy
`trainer_rematch` identity is active and exports the reviewed
`ascendantMenu` facade, Voxel Ascendant contributes one `VOXEL ASCENDANT` row
through Gen1Recomp's public `ui.start_menu.items` hook. Kanto Ascendant's own
higher-priority collector moves that descriptor into **ASCENDANT**; selecting
it opens the regular Voxel Ascendant rows in **OPTIONS**.

Discovery happens when the Start menu is built, after all mods have loaded.
There is no hard dependency, foreign save access, export alias, or Kanto
Ascendant bundle patch. If Kanto Ascendant is absent, disabled, failed, or
does not expose the expected public menu shape, the hook returns the original
Start-menu list unchanged. The stable descriptor key is `voxel_ascendant`;
Kanto Ascendant may ship that key itself in the future without creating a
duplicate row.

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
