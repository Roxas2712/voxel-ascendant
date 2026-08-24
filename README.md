# Voxel Ascendant

Voxel Ascendant renders the Gen1Recomp overworld as a depth-tested voxel
diorama and can stage battles in 3D using the game's own Gen 1 battle
pictures. It is a standalone graphics mod: Kanto Ascendant is supported as
an optional companion, but is not required.

Version 2.0 is built only from the MIT-licensed
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
- For a first install, select `VOXEL_ASCENDANT-2.0.2.zip` in the mod manager.
  `manifest.json` is at the ZIP root; do not unpack or re-wrap it.

Use the game's regular **OPTIONS** menu for the concise in-game controls. The
mod manager's per-mod options page exposes every stored setting and is mainly
useful for recovery or advanced configuration.

## Included features

| option | values | effect |
| --- | --- | --- |
| **VOXEL** / `V` / `ZR` | OFF, FULL, 15, 35, 50, 75, 1ST, 3RD | Voxel diorama, orbit angles, first person, or a collision-aware third-person boom. FULL is the curated preset; `3` and SELECT remain compatible aliases. |
| **T-SHIFT** / `6` | OFF, 1, 2, 3 | Miniature tilt-shift blur. |
| **V-GRID** / `5` | OFF, ON | One-pixel voxel seams. |
| **BTL GRID** | ON, OFF | Voxel seams in 3D battles, independent of V-GRID. |
| **SHADOWS** | ON, OFF | Cast shadows in the overworld and 3D battles; OFF is the mobile-safe path. |
| **V-CURVE** / `7` | OFF, 1, 2, 3 | Curves the distant world toward the horizon. |
| **WATER** / `9` | FULL, SKY, OFF | Voxel water and reflections, with safe fallbacks. |
| **DAYTIME** | DAY, NIGHT, DUSK, DAWN, AUTO | Automatic outdoor lighting by default; the save-local clock favours long DAY/NIGHT plateaus and keeps manual pins. |
| **SKY** | FULL, FLAT, OFF | Banded Kanto sky, inexpensive flat color, or no added sky. |
| **CLOUDS** | ON, OFF | World-anchored pixel clouds, independently removable on slower devices. |
| **SKY EVENTS** | FULL, RAINBOW, FLYERS, OFF | Rare rainbows, curated distant sky life and legendary sightings; OFF has no event draw cost. |
| **WEATHER** | CLEAR, AUTO, RAIN, SNOW, FOG, STORM | Lightweight precipitation, drifting fog and thunderstorms; staged outdoor battles retain the active effect. |
| **SCENERY** | FULL, OFF | Closes outdoor/cave map edges with world-fixed mountains, town/tree layers, open water or rock walls. |
| **PRELOAD** | ON, OFF | Safely warms current/connected voxel meshes in RAM while 3D is off. |
| **3D-BTL** / `8` | MAP, ARENA, DISCS, OFF | Native Gen 1 battle cards on nearby voxel terrain, reviewed location artwork, or a procedural disc stage. ARENA alone uses its fixed per-location card anchors. |
| **BTL CAM** | 1X, 2X, 3X | Saved MAP/DISCS battle view: close, middle, or the default wide 3X view; direct zoom remains available. ARENA uses its separately saved 3X/STADIUM director. |
| **TRAINER BACK** | OFF, ON | OFF stands the trainer's front art in the 3D intro; ON keeps the trainer back in its classic slot. |
| **PKMN BACK** | OFF, ON | Independently keeps the player's Pokemon back sprite in its classic battle slot. |
| **USER MUSIC** | GAME/KASC, SHUFFLE, FILE | Opt-in loose MP3/OGG/WAV/FLAC replacement with grouped battle, world, result and scene submenus. Exact `replace/<SONG_ID>` files cover additional Game/KASC cues; the default/back switch bypasses all VASC music replacements. English/German platform guides ship in the folder. |
| **USER SPRITES** | GAME/KASC, ON | Opt-in PNG replacement for Pokémon forms/front/back/Dex/icons/overworld, player battle art, trainer portraits and every registered Game/KASC overworld sheet. The default/back switch bypasses all VASC sprite hooks; the VASC hub can restore every custom provider globally. |
| **AA** | OFF, 2X, 4X | Supersamples the 3D pass. |

When KASC 6.7 supplies the complete reciprocal `CINNABAR_SOUTH_CHANNEL`
topology, SCENERY also shows the distant volcano left of Birth Island during
the southern approach. The visual is strictly additive and remains disabled
on older or incomplete map data.

The 1ST and 3RD rungs use camera-relative movement with the engine's own cell
collision, warp, encounter, ledge, boulder and step-completion paths. Mouse,
right-stick and open-screen touch drags steer the view; `V` or the controller's
right trigger (`ZR`/`R2`/`RT`) cycles the complete camera ladder. SELECT and
the `3` key remain compatible aliases. The release still excludes VR, Horde
mode, Pokemon Stadium
models, ROM import, external art and disk caching. PRELOAD is a bounded,
generation-checked memory cache: map edits invalidate it and no stale geometry
survives a restart.

One-way ledges now also define the visual terrain datum. The lip tile keeps its
existing 6px shape on the lower base while the plateau behind it rises by 6px;
stacked Route 4 terraces therefore become real 18/12/6/0px levels without a
double-height tooth. Terrain, buildings, vegetation, figures, entities,
camera placement and shadows share that same immutable height snapshot. This
is presentation only: the engine remains the sole authority for collision and
ledge jumps.

In 1ST/3RD, clouds, the sun and moon, stars, shooting stars and rare events
live at fixed bearings in the sky: turning the camera reveals or loses them
instead of carrying them around on the screen. The classic orbit uses the
same world-space atmosphere, so switching cameras does not teleport it.
Rainbow and flyer schedules persist with the save and remain deliberately
rare. Ordinary windows rotate Pidgey, Pidgeotto, Pidgeot, Spearow, Fearow and
Murkrow through solo flights or compact two-to-four-bird formations; much
rarer singleton sightings can reveal Articuno, Zapdos, Moltres or Ho-Oh.
**SKY EVENTS** can keep either class alone or remove all of their work.
Normal rain can still reveal a distant rainbow; snow, fog and storms suppress
obscured sky events. Weather follows the arena into staged outdoor battles,
while buildings and caves remain clear.
Viridian Forest is treated as a sheltered outdoor canopy: its backdrop follows
the same day/night colours without exposing sun, moon, stars or open clouds,
and forest weather remains active instead of falling back to a black void.

BTL CAM pulls staged MAP and DISCS fights back as far as 3X without changing
the classic 2D battle screen or its HUD. New saves start at the wide 3X view;
1X remains the close view and 2X the middle ground. The selected distance is
saved, and FULL never overwrites it. Q/E, mouse wheel and pinch remain
temporary fine controls during the fight and are not overwritten every frame.

ARENA is an explicit fourth 3D-BTL rung, not a replacement for MAP or DISCS.
It maps all 111 reviewed Gen 1 battle anchors, plus supported city trainer
fights, to one of 46 independent 1280x800 location paintings. Each painting
owns fixed lower-left player and upper-right opponent footing at the authored
3X composition; STADIUM may direct that same composition dynamically. MAP,
DISCS and classic battles retain their historical positions and card scale.
Outdoor paintings expose the live sky, while reviewed rooms with exterior
windows receive a restrained blend from the same continuous AUTO/day/night/
dawn/dusk clock as the overworld.

With SCENERY enabled, outdoor and cave maps use cached compact pixel-art
panoramas with opaque procedural failure fallbacks instead of building the old
three-block carved border ring. Open-sky routes, towns and mountain regions
layer a fixed Kanto ridge behind their local tree, town or rock foreground;
canopy forest, caves and the southern open sea remain geographically distinct.
Route 1 and Viridian replace the former raised green side slabs with low Kanto
outskirts and two sparse rows of batched voxel trees. Semantic caves and every
Pokemon Tower floor also receive a 160px wall plus a 32px-tessellated ceiling;
Tower floors share a longer two-bay wall and coffered ceiling rather than a
small repeated brick stamp.
The vertical skyline and separately tiled canopy/ground apron close straight
edges and high-camera corners without stretching a facade texture over the
floor.

A cold 3D switch remains on the complete 2D renderer until the current terrain,
grass, flowers, figures, exact atlas/mask and panorama are all drawable, then
swaps once. Repeated forest, grass and building geometry is retained as shared
templates plus offsets, while route-sized indexed GPU uploads are split into
frame-budgeted pages. Map refreshes keep drawing their previous cached mesh
while rebuilding, so neither delayed decoration pop-in nor one route-sized
driver call has to interrupt normal play.
The unconnected southern and western edges around Cinnabar and the adjoining
sea routes extend as open water rather than turning their shoreline barriers
into a distant mountain or tree wall.

Voxel Ascendant is maintained as a focused compatibility alternative while
older voxel renderers catch up with current Gen1Recomp releases. Its scope is
deliberately stable: renderer compatibility and serious regressions may be
fixed, but it will not grow a bundled Pokemon/trainer sprite or soundtrack
collection. Battles use character art already provided by the game or another
compatible content mod; the included location paintings contain no Pokemon,
trainers or copied game screenshots.

Optional music is deliberately provider-owned. A separately installed mod may
register already-installed engine song IDs through `exports.battleMusic` and
label them by generation and fight type. Voxel Ascendant never downloads a
soundtrack, never accepts a raw URL as a playable song, and includes no audio
files. Removing or breaking the provider restores the original cue without
changing the save.

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

When both mods are enabled, Voxel Ascendant also appears as
**VOXEL ASCENDANT** inside Kanto Ascendant's **ASCENDANT** menu. Selecting the
entry opens the same VASC settings from the regular **OPTIONS** screen. The
bridge is optional and runtime-detected; a VASC-only installation does not
gain an extra Start-menu row or a dependency on Kanto Ascendant.

The stable export contract is documented in [COMPATIBILITY.md](COMPATIBILITY.md).
On iOS, Voxel Ascendant does not advertise the optional legacy edge-HUD
compositor. Companion mods therefore keep Gen1Recomp's upright, centered
battle HUD without installing cross-canvas panel wrappers.

## License and provenance

The software is MIT licensed. The original copyright and license text remain
unchanged in [LICENSE](LICENSE). See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md),
[CREDITS.md](CREDITS.md), and [FORK_HISTORY.md](FORK_HISTORY.md) for the exact
source and fork record. The historical upstream changelog is retained as
[UPSTREAM_CHANGELOG.md](UPSTREAM_CHANGELOG.md) and does not describe the
current Voxel Ascendant feature set.
