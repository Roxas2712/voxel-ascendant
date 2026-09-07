# Voxel Ascendant

Voxel Ascendant renders the Gen1Recomp overworld as a depth-tested voxel
diorama and can stage battles in 3D using the game's own Gen 1 battle
pictures. It is a standalone graphics mod: Kanto Ascendant is supported as
an optional companion, but is not required.

Version 3.0 RC keeps the MIT-licensed
DramaticShapeVoxelMod v1.6.1 source tag (`790c34efff4975c91883f7f918a875530706ee12`)
as its Gen1 rendering foundation and adds an isolated, attribution-preserving
Gen2 runtime. No ROM, Pokemon Stadium data, native VR binary, private KASC
code or unrecorded external art is included. The project-supplied VASC battle-
effect collection is packaged with per-file hashes and a reproducible import.

> **Private RC test boundary:** the integrated D/P and FRLG Bag atlases are
> Pokémon game-art test candidates and are not covered by VASC's MIT licenses.
> Their redistribution clearance is outstanding. Do not publish or promote
> this candidate as a public release; exact crops, hashes and builders are
> recorded in `ASSET_SOURCES.md` and `FRLG_ORAS_BAG_ASSET.md`.

> **RC11 working-tree status:** `manifest.json` and the dispatcher now carry
> the development identity `3.0.0-rc.11`. The source is pinned to Content
> Selector 0.5.0 and the reviewed Kanto Ascendant 6.7.0 pair, but it is not an
> installable RC11 candidate or release. Required Windows/Linux selector
> artifacts and the bounded visual/ROM acceptance are still outstanding.

## Requirements and installation

- Gen1Recomp `0.1.90` or newer.
- A graphics driver with shader and depth-canvas support. Unsupported features
  fail closed to the game's normal 2D renderer.
- For an installed copy, use **Check for updates** in the launcher. Manual
  import intentionally does not overwrite a mod with the same ID.
- For the frozen RC10 baseline, select
  `VOXEL_ASCENDANT-3.0.0-rc.10.zip` in the mod manager. `manifest.json` is at
  the ZIP root; do not unpack or re-wrap it. Do not install the RC11 source
  tree as if it were an accepted package.

On Red, Blue and Yellow, the regular START menu exposes this VASC subtree:

```text
VOXEL ASCENDANT
├── VIEW + WORLD
├── WEATHER + SCENERY
├── BATTLE
├── SKINS & OVERLAYS
├── POKéMON + MODELS
├── WILDS + FOLLOWERS
├── PERFORMANCE
├── USER CONTENT
│   ├── CONTENT SOURCE
│   └── PRESET & SCOPE
└── ADVANCED
```

The frozen RC10 delivery used Content Selector 0.4.0 and Kanto Ascendant
6.5.20. The RC11 working tree is instead bound to Content Selector 0.5.0 and
the exact reviewed Kanto Ascendant 6.7.0 source/package pair; no new
all-platform bundle is claimed while the native artifact contract remains
open. The selector discovers the normal VASC/VASC4J locations on macOS,
Windows and Linux and indexes file-backed content from an adjacent Kanto
Ascendant install. Named presets can target the default, Gen 1, Gen 2 or one
game and can inherit or be copied. VASC independently revalidates
the bounded `active.json`, canonical manifest, byte sizes and SHA-256 hashes;
a structurally valid CUSTOM scope whose generation later fails uses its
declared base: `retro` tries the public RETRO provider and then VASC DEFAULT,
while `vasc-default` goes directly to VASC DEFAULT. An explicit
`VASC_DEFAULT` scope stops there. If `active.json` is absent, only an already
saved legacy CUSTOM request keeps the RC8 loose-folder bridge; an ordinary
VASC DEFAULT request remains on VASC DEFAULT.
`PRESET & SCOPE` always exposes `RESTORE VASC DEFAULT`. See
[`docs/CONTENT_PRESETS.md`](docs/CONTENT_PRESETS.md). KASC remains optional and
must be installed before VASC only from the explicitly paired package.

Gold, Silver and Crystal use the same VASC-owned control centre and visual
language, but expose only settings backed by their reviewed Gen-2 adapters.
Gold/Silver/Crystal offer separate `START TEAM UI`, `BATTLE TEAM UI` and
`BATTLE HUD` choices between draw-only `ORAS GLASS` and `GAME DEFAULT`; PC and
Legacy-Bank rows remain Gen-1-only. Ordinary Gen-2 dialogue, choices and lists
use the same draw-only ORAS skin unless `OVERWORLD MENUS` is set to
`GAME DEFAULT`. With KASC enabled, KASC collects
only the public **VOXEL ASCENDANT** descriptor and places the VASC-owned Gen-1
tree in its menu. No renderer, save or feature is merged into KASC.
Every VASC page reserves a permanent cursor-sensitive help strip; START or
SELECT opens the complete contextual help for every category and selectable
row. The prose automatically follows the active English or German game-data pack.
The mod manager's per-mod options page still exposes every stored setting and
is mainly useful for recovery or advanced configuration.

Gen-2 already installs the voxel world, cameras, environment, models, Wilds,
followers and live battle stage. The exact implemented/missing/not-applicable
audit for Gold, Silver and Crystal is recorded in
[`docs/GEN2_FEATURE_PARITY.md`](docs/GEN2_FEATURE_PARITY.md). Its ORAS battle
HUD is presentation-only and intentionally limited to ordinary command/move
phases; engine-native input and the full native special-phase fallback remain
the safe owners.

## Included features

| option | values | effect |
| --- | --- | --- |
| **VOXEL** / `V` / `ZR` | OFF, FULL, 15, 35, 50, 75, 1ST, 3RD | Voxel diorama, orbit angles, first person, or a collision-aware third-person boom. FULL is the curated preset; `3` remains a compatible alias. SELECT belongs to the game/KASC Field Kit. |
| **T-SHIFT** / `6` | OFF, 1, 2, 3 | Miniature tilt-shift blur. |
| **V-GRID** / `5` | OFF, ON | One-pixel voxel seams. |
| **HEIGHTS** | WORLD, LOCAL, FLAT | WORLD continues proven ledge levels across direct outdoor map connections. LOCAL keeps the prior bounded per-map interpretation. FLAT leaves native stair/ledge art and gameplay intact without terrain lift. Retired SLICE saves read safely as LOCAL. |
| **BTL GRID** | ON, OFF | Voxel seams in 3D battles, independent of V-GRID. |
| **SHADOWS** | ON, OFF | Cast shadows in the overworld and 3D battles; OFF is the mobile-safe path. |
| **V-CURVE** / `7` | OFF, 1, 2, 3 | Curves the distant world toward the horizon. |
| **WATER** / `9` | FULL, SKY, OFF | Voxel water and reflections, with safe fallbacks. |
| **DAYTIME** | DAY, NIGHT, DUSK, DAWN, AUTO | Automatic outdoor lighting by default; the save-local clock favours long DAY/NIGHT plateaus and keeps manual pins. |
| **SKY** | FULL, FLAT, OFF | Banded Kanto sky, inexpensive flat color, or no added sky. |
| **CLOUDS** | ON, OFF | World-anchored pixel clouds, independently removable on slower devices. |
| **SKY EVENTS** | FULL, RAINBOW, FLYERS, OFF | Rare rainbows, curated distant sky life and legendary sightings; OFF has no event draw cost. |
| **WEATHER** | CLEAR, AUTO, RAIN, SNOW, FOG, STORM, HEAT, RAINBOW | AUTO deals long map-stable spells, seasonal heat/snow separated by normal weather, rare storms and a fresh hand after map/interior exits. Every value remains directly testable; staged outdoor battles retain the active effect. |
| **SCENERY** | FULL, OFF | Closes outdoor/cave map edges with world-fixed mountains, town/tree layers, open water or rock walls. |
| **PRELOAD** | ON, OFF | Safely warms current/connected voxel meshes in RAM while 3D is off. |
| **3D-BTL** / `8` | MAP, ARENA, DISCS, OFF | Native Gen 1 battle cards on nearby voxel terrain, reviewed location artwork, or a procedural disc stage. ARENA alone uses its fixed per-location card anchors. |
| **ARENA BG** | V+FRLG, VASC, FRLG | Compact in-menu labels for the existing VASC paintings, the 13 geographically reviewed FRLG-like counterparts, or a stable once-per-fight mix. Unsupported maps always retain their matching VASC master. |
| **DISK ART** | V+FRLG, VASC, FRLG | Appears only for DISCS. Select the original neutral VASC disks, ten generated FRLG-like terrain families, or a stable once-per-fight mix. Each FRLG family also tints a procedural near-white void to match—there are no large disk backdrops. Map/profile receipts keep every family in suitable locations; unsupported expansion maps retain VASC. |
| **BTL CAM** | 1X, 2X, 3X | Saved MAP/DISCS battle view: close, middle, or the default wide 3X view; direct zoom remains available. |
| **STADIUM CAM** | STATISCH 3X, SMART / STADIUM | MAP and ARENA camera style. SMART / STADIUM is the default and directs introductions, portraits, shoulder shots, attacks and a segmented slow orbit with regular still holds, comfort limits and complete travel-path checks. Manual steering becomes the new orbit basis before automatic direction resumes. In narrow or constrained Voxel rooms VASC chooses the best clear view of both Pokémon once and holds it static; STATISCH 3X always retains the fixed composition. |
| **OVERWORLD MENUS** | ORAS GLASS, GAME DEFAULT | Draw-only ORAS furniture for native dialogue, choices, title/START and ordinary lists. Authored VASC/KASC/PC/battle screens keep their owner; GAME DEFAULT restores the exact captured renderer live. |
| **BAG MENU** | GAME/KASC, D/P ORAS WIDE, FRLG ORAS WIDE | GAME/KASC is the safe default and leaves the exact native, Useful Bag or KASC draw owner untouched. The two public VASC choices author a real 512×288 Gen-1 surface with nine rows, permanent item help, real pocket images and a Pokéball row cursor instead of stretching the compact 160×144 layout. Historical compact saved values migrate to their matching WIDE choice; compact renderers remain internal fail-open only. Input, update, items, pockets, sorting, USE/TOSS, battle rules and provider callbacks remain on the original instance; missing assets or draw errors fail open atomically to its complete captured renderer. Gen 2 keeps its separate native PackMenu. |
| **TASCHEN-AKZENT** | AUTO, ROT, BLAU, GRÜN | Changes only the intended coloured insert of an explicitly selected VASC Bag; gold material and outlines remain original. AUTO follows KASC's public RED/BLUE/GREEN identity and otherwise uses red. |
| **TASCHENKÖRPER** | AUTO, ORAS, ROT, BLAU, GELB, GOLD, SILBER, CRYSTAL | Recolours only the separately masked Bag fabric of an explicitly selected VASC Bag. AUTO follows the active Red-through-Crystal edition accent; ORAS preserves the authored source material. It never overlaps the independent pocket/selection accent. |
| **TASCHENFORM** | AUTO, NORMAL, HENKEL | Selects round Red/Blue or handled Green/Leaf source form independently from the accent. It has no effect while GAME/KASC owns presentation. |
| **BATTLE HUD** | ORAS, STANDARD | VASC's responsive ORAS controls or the previous readable HUD. VASC remains the presentation owner beside KASC; an eligible Mega control appears only when KASC authorizes the exact active Pokémon through its public service. Only an explicit external HUD claim hides this row. |
| **POKéMON UI** | ASC BOX, ORAS GLASS, GAME DEFAULT, registered providers | Preferred skin for box-like Pokémon screens. VASC's ORAS GLASS provider is battle-party-only; ASC BOX also intersects PC and compatible Legacy hosts. A provider appears only where its complete public receipt intersects an active compatible host; dead rungs stay hidden while the unavailable requested default fails open without losing saved intent. This is independent of BATTLE HUD. |
| **SKINS & OVERLAYS** | Gen 1 START/BATTLE TEAM: ASC BOX / ORAS GLASS / GAME DEFAULT; Gen 2 START/BATTLE TEAM and BATTLE HUD: ORAS GLASS / GAME DEFAULT | Normal and in-battle team views are independently selectable. The regular POKéMON Start row remains the only team entrance, while storage stays at the PC/Legacy host. Gen-2 adapters replace drawing only; storage, Dex, capacity, input, switch and field-move rules remain with their authoritative host and unsupported phases use the complete native screen. The opaque Gen-1 Host-v1 transaction is documented in [`docs/POKEMON_UI_PROVIDER_CONTRACT.md`](docs/POKEMON_UI_PROVIDER_CONTRACT.md). |
| **ASC BOX GRID** | 5 X 4 DETAIL, 6 X 5 ORAS | VASC's final 0.5.3 storage layout. It opens only through the regular PC or a compatible Legacy Bank host; no Start-menu storage shortcut bypasses those owners. A lifts once and drops/swaps once; Box pages change without Bill's save prompt, while ordinary later Save/Savestate persistence remains unchanged. The 6×5 view visibly reserves seats beyond a twenty-Pokémon Gen-I host capacity. |
| **KASC PC / LEGACY STYLE** | FIRE RED / LEAF GREEN, FIRE RED / LEAF GREEN WIDE, KANTO ASCENDANT, GAME DEFAULT | KASC's append-only WIDE value authors a real 512×288 PC/Legacy surface with a 5×4 Box grid, 2×3 Team rail, persistent detail/help and remembered navigation. The existing compact choices keep their keys and order. In the Legacy Bank, SELECT marks multiple Pokémon across boxes and START transfers that selection through KASC's capacity-, lock- and rollback-safe storage core; ALL IN PC BOXES remains available. |
| **BATTLE LAYOUT** | TARGET, X, Y, SIZE, RESET | Saved VASC fine placement for player front/back/retro-back, Mega, enemy Pokémon, player/enemy trainers and every VASC fallback-HUD zone. Each role keeps independent X/Y and 50–200% size values. The reviewed automatic composition remains 0/0/100%; optional sprite providers only supply artwork and are never modified. |
| **ORAS HUD** | AUTO/DE/EN, 75–200%, STATUS GLASS 0–100% (default 75%), TEXT GLASS 0–100% (default 65%), anchors and side offsets | Localized proportional controls with independent glass strength for the compact HP/status cards and the larger battle-message box. Ink, bars, icons and edition borders retain their authored opacity. These rows appear only while VASC owns an active ORAS HUD. |
| **STANDARD HUD POS / SIZE / ALPHA** | AUTO/WIDE/EDGES/STACK, 75/100/125, 35/50/65/80 | Legacy readable-HUD details, shown only for VASC's STANDARD choice and hidden only while an explicit external provider owns the battle HUD. |
| **TRAINER BACK** | OFF, ON | OFF stands the trainer's front art in the 3D intro; ON uses the real trainer rear art on the same grounded 3D player mark, so it cannot cover the opponent on ARENA/mobile layouts. |
| **PKMN BACK** | OFF, ON | Selects the player's real rear artwork while keeping it grounded and scaled on the same 3D player mark as the front view. It never returns to the oversized classic lower slot. |
| **CONTENT PROFILE** | KASC, VASC DEFAULT, RETRO, CUSTOM | One saved owner for both sprites and music. KASC and RETRO require explicit public API-v1 receipts; missing or colliding providers fall back to VASC DEFAULT without rewriting the requested choice. CUSTOM uses the documented loose folders materialized by the cross-platform selector. VASC never discovers private KASC files or tables. |
| **CUSTOM MUSIC / CUSTOM SPRITES** | status, mapping, rescan, guides | USER CONTENT keeps configuration and diagnostics for CUSTOM without adding competing source toggles. Exact music replacements, category pools and documented Pokémon/player/trainer PNG paths remain supported; English and German guides ship in both folders. |
| **SPECIES SURF / FLY (Gen 1)** | automatic, native fallback | Red/Blue/Yellow show the exact selected normal/Shiny species through Hoenn (plus Gorochu) during VASC SURF/FLY cinematics. KASC Field Kit uses the active trainer with a jet ski/jetpack instead of inventing a Pokémon user. Missing assets or renderer/controller failures release to the native game animation. |
| **AA** | OFF, 2X, 4X | Supersamples the 3D pass. |

Fly 0.4.3 and Surf 0.3.1 are internal RC5 modules, not companion mods. Keep
only `VOXEL_ASCENDANT` enabled; modern launchers replace the retired standalone
IDs automatically and the runtime refuses to stack a surviving old companion.
Sprite/source receipts and exact notices are retained in
[`docs/SPECIES_CINEMATICS.md`](docs/SPECIES_CINEMATICS.md).

When KASC 6.7 supplies the complete reciprocal `CINNABAR_SOUTH_CHANNEL`
topology, SCENERY also shows the distant volcano left of Birth Island during
the southern approach. The visual is strictly additive and remains disabled
on older or incomplete map data.

The 1ST and 3RD rungs use camera-relative movement with the engine's own cell
collision, warp, encounter, ledge, boulder and step-completion paths. Mouse,
right-stick and open-screen touch drags steer the view; `V`, the controller's
right trigger (`ZR`/`R2`/`RT`) or `3` cycles the complete camera ladder. SELECT
is never intercepted by VASC and remains available to the game and KASC Quick
Select/Field Kit. The release still excludes VR, Horde
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

**HEIGHTS: WORLD** remains deliberately local to authored evidence. A ledge is
never extended across an entire city row: Cerulean stays flat except for its
real Nugget Bridge/house approach, and unrelated roads cannot gain invisible
steps. A connected rock or bollard frame takes the height of its nearest real
ground, so the stones enclosing an upper plateau rise with it and the land may
drop again immediately beyond that frame. Direct map seams preserve their
matching edge datum; gates, forests, caves, tunnels and other warp transitions
may reset it. **SLICE** accepts only a local ledge contour containing a real
one- or two-cell walkable stair opening. It raises the enclosed plateau and
nearest retaining stones, but never carries a datum to another map; isolated
jump ledges, flat towns and ponds therefore remain neutral. **LOCAL** restores
the earlier map-bounded object rule and
**FLAT** is the visual escape hatch requested for players who want authored
stair/ledge shapes without elevated regions.

A one- or two-cell walkable opening between two authored pieces of the same
plateau edge is rendered as a short diagonal approach instead of an invisible
vertical wall. Ordinary cliffs remain vertical. The slope reaches the lower
gameplay datum at the cell centre and has closed triangular sides against its
rock frame; collision, one-way jumps and map bytes remain entirely native.

In 1ST/3RD, clouds, the sun and moon, stars, shooting stars and rare events
live at fixed bearings in the sky: turning the camera reveals or loses them
instead of carrying them around on the screen. The classic orbit uses the
same world-space atmosphere, so switching cameras does not teleport it.
Rainbow and flyer schedules persist with the save and remain deliberately
rare. Ordinary windows rotate Pidgey, Pidgeotto, Pidgeot, Spearow, Fearow and
Murkrow through solo flights or compact two-to-four-bird formations; much
rarer singleton sightings can reveal Articuno, Zapdos, Moltres or Ho-Oh.
**SKY EVENTS** can keep either class alone or remove all of their work.
When rain or a storm clears, a map-bound distant rainbow is guaranteed. Its
large smooth circular arc stays at a fixed world bearing while both legs
continue behind the live terrain horizon. Its bearing and elevation use the
same world-sky projection as VASC's clouds, with no screen-space positioning.
Four map-seeded, slowly drifting
kaleidoscope clusters split that light into mirrored prismatic shards across
the world canvas; the HUD is composited afterwards and remains clean. Snow,
fog and storms suppress obscured scheduled sky events. Weather
follows the arena into staged outdoor battles, while buildings and caves
remain clear. Snow coats only geometrically upward ground, roof and tree-crown
surfaces; vertical building walls are excluded regardless of their palette or
lighting. Completed walking cells make a quiet procedural snow crunch or
rain/storm splash, respect SFX volume, and remain silent on the bike or Surf.
Rain now uses varied smooth depth layers and sparse ground splashes instead
of repeating pixel staircases. Rare deterministic foreground windows add a
few soft adhered drops and short downward trails; outside those windows the
screen pass performs zero drop draws, and outdoor battles use fewer drops than
the overworld. Snow has independent flake sizes and drift, while fog uses soft
moving wisps rather than rectangular bands. RAIN and STORM also add map-fixed
wet-grey cloud banks; STORM is darker and denser, while neither bank reads the
weather clock, camera or player position.
Clear daylight adds a sparse second bank of slowly wandering clouds only at
the distant horizon; they are sky directions and never nearby map objects.
Viridian Forest is treated as a sheltered outdoor canopy: its backdrop follows
the same day/night colours without exposing sun, moon, stars or open clouds,
and forest weather remains active instead of falling back to a black void.

BTL CAM pulls staged MAP and DISCS fights back as far as 3X without changing
the classic 2D battle screen or its HUD. New saves start at the wide 3X view;
1X remains the close view and 2X the middle ground. The selected distance is
saved, and FULL never overwrites it. In a roomy STADIUM shot, manual steering
becomes the new orbit basis and the dynamic director continues from there;
narrow rooms retain their one proven static safe view.

ARENA is an explicit fourth 3D-BTL rung, not a replacement for MAP or DISCS.
It maps all 111 reviewed Gen 1 battle anchors, plus supported city trainer
fights, to one of 46 independent 1280x800 location paintings. Each painting
owns reviewed lower-left player and upper-right opponent footing at the
opening 3X composition. In both MAP and ARENA, STADIUM uses the real Voxel map
and runs trainer/wild openings, alternating Pokemon portraits,
shoulder shots, attack/impact cuts and a slow full orbit. If a tree, wall or
ledge hides its subject, the director searches a closer, higher or optically
reframed lane and holds that correction instead of oscillating. The orbit moves
in four calm quarter-arcs with a still hold after each. Every travelling segment
checks a camera-sized path against terrain plus blocked tree/wall/building cells;
an unsafe path freezes at the last safe seat or becomes a cut instead of passing
through geometry. The location painting is the
safe fallback when no physical map stage fits. Q/E, mouse wheel and pinch move
the orbit basis and STADIUM resumes its dynamic direction from the new view.
3X restores the prior MAP/ARENA composition;
DISCS and classic battles retain their historical camera behaviour.
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

The retired standalone `VASC4J` package is different: Voxel Ascendant 3.0
already contains its reviewed Johto runtime. If both are still enabled after
an update, the launcher treats the shared package as the replacement and
disables `VASC4J` automatically instead of failing the game boot. Known Gen-2
settings are copied once into `VOXEL_ASCENDANT`; the old option bucket remains
untouched for rollback.

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
entry opens the same VASC-owned settings hub as the standalone Start-menu
entry. KASC collects that public descriptor into its menu tree and exclusively
owns the battle-HUD provider while it is installed; it does not take ownership
of VASC's renderer, world settings, save data or scenery assets. The bridge is
optional and runtime-detected: without KASC, the row stays in the regular
Start menu and VASC retains its responsive ORAS/standard battle choice, Gen-I
move animations and renderer without any Kanto Ascendant dependency. The VASC
standalone path contains no Mega button or Mega activation logic.

The installed `user/sprites/README_EN.txt` and `README_DE.txt` contain the
complete custom-art contract: accepted PNG dimensions, transparent padding,
foot/baseline rules, native/KASC fallbacks, Red/Blue/Green and trainer class
behavior, Mega form names, Pokémon front/back presentation, mobile checks and
a MAP/DISCS/ARENA release-acceptance checklist.

`BATTLE -> BATTLE LAYOUT` is also available directly inside VASC. Choose the
presentation role first, then adjust its saved X, Y and size values. Front,
modern rear, retro half-rear, Mega, enemy Pokémon and player/enemy trainer art
are independent. VASC fallback status cards, team rows, command and message
zones can be adjusted the same way. `RESET ONE` restores only the selected
role; `RESET ALL` returns the complete composition to the reviewed automatic
placement. This is a VASC runtime feature, not a requirement to use an
external editor, and it never writes into KASC.

The stable export contract is documented in [COMPATIBILITY.md](COMPATIBILITY.md).
VASC's ORAS/standard selection and responsive placement values remain saved
controls with or without KASC. KASC may provide gender, EXP, caught-state and
exact eligible-Mega capabilities through public receipts without becoming the
visual owner. Only a versioned external HUD claimant suppresses VASC's rows and
default compositor. VASC keeps its corrected iOS compositor private, so peer
mods cannot reinstall the historical unsafe cross-canvas wrapper.
The remaining-team markers stay on-screen after the intro and retain VASC's
original Poké Ball artwork: healthy Pokémon use its soft red tint, while
fainted Pokémon use its grey ball with the original diagonal slash. VASC also ships
its own move-effect programs: Gen 1 is available standalone and later move
generations are runtime-gated behind an active KASC installation. A liveness
guard restores KASC's animated Mega frames after stale hot-reload state but
does not replace KASC's form or sprite resolver.

## RC10 headless release gate

Before an RC10 artifact is accepted, run the canonical non-visual gate from
the repository root:

```sh
VOXEL_ASCENDANT_LUA=/absolute/path/to/luajit \
GEN1RECOMP_0190_ROOT=/absolute/path/to/pinned-0.1.90-stage \
GEN1RECOMP_0190_DATA_ROOT=/absolute/path/to/pinned-map-data \
VASC_CINEMATIC_SOURCE_ROOT=/absolute/path/to/reviewed-source-archives \
VASC_WEATHER_V41_SOURCE_ZIP=/absolute/path/to/VOXEL_ASCENDANT-3.0.0-rc.9-WX-WORLD-CYCLE-v4.1-TEST.zip \
VASC_MODERN_DEX_SOURCE_ZIP=/absolute/path/to/vasc-modern-pokedex-0.4.0.zip \
VASC_KANTO_FLY_MAP_SOURCE_ZIP=/absolute/path/to/vasc-kanto-fly-map-widescreen-1.0.0.zip \
  python3 scripts/run_rc10_headless_gate.py
```

It runs the receipt/package Python guards plus the RC10 acceptance, archive
durability, Oak's Lab, UI and Gen-1/Gen-2 Fishing Lua contracts without opening
a LÖVE window. Any missing runtime or failed child test blocks immediately;
the supplied engine/data roots are checked against the byte-exact receipts;
the only successful terminal line is `RC10 HEADLESS GATE: PASS`. Both historical
Gen-1 and Gen-2 aggregate contracts invoke this same gate, so running either
normal total contract cannot silently omit the RC10-specific checks.
`VASC_CINEMATIC_SOURCE_ROOT` must contain the three hash-pinned Fly, Surf and
Fishing source ZIPs; it may be omitted only when those archives live beside
the repository checkout. `VASC_WEATHER_V41_SOURCE_ZIP`,
`VASC_MODERN_DEX_SOURCE_ZIP` and `VASC_KANTO_FLY_MAP_SOURCE_ZIP` are mandatory
release inputs. Each must name the exact reviewed archive; missing files,
changed archive bytes, a different member inventory or any changed member
payload blocks the gate before an RC can be accepted.

The separate consolidated acceptance runner additionally requires
`--launcher-approval` for every run or merge.  That approval binds the exact
executable path, byte count and SHA-256 to the engine identity in the staged
package receipt; another executable is rejected before it can start.  A Gen-1
performance PASS also requires an explicitly approved `--oaks-budget` file.
The runner hashes the actual external file bytes, forwards that digest to the
driver and binds it into the run receipt.  No approved budget file is shipped
or inferred from the candidate itself: until maintainers supply one, Oak's Lab
is reported honestly as `MEASURED/NEEDS_REVIEW` and a final PASS merge remains
blocked.

All PNG evidence emitted beneath the Gen-1 run root and the Gold evidence root
is inventoried, fully decoded with Pillow, CRC-checked chunk by chunk and bound
by path, dimensions, byte count and SHA-256.  Unreported extra PNGs are placed
in the canonical ledger as disk outputs instead of escaping it.  Missing or
truncated images, trailing data, corrupt image streams, traversal, symlinks,
or any addition/change after capture fail the merge.

## License and provenance

The software is MIT licensed. The original copyright and license text remain
unchanged in [LICENSE](LICENSE). See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md),
[CREDITS.md](CREDITS.md), and [FORK_HISTORY.md](FORK_HISTORY.md) for the exact
source and fork record. The historical upstream changelog is retained as
[UPSTREAM_CHANGELOG.md](UPSTREAM_CHANGELOG.md) and does not describe the
current Voxel Ascendant feature set.
