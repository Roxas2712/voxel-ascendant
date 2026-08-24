# Changelog

## 2.0.2 — 2026-08-24

- Restore Gen1Recomp 0.2.22 compatibility after the engine replaced
  `src.render.GBCFX` with `src.render.ShaderFX`. VASC now disables either
  final-frame effect through a fail-open compatibility layer, keeps both
  0.2.19 and 0.2.22 loadable, and preserves saved Shader FX preset choices so
  they return when VASC is disabled.

## 2.0.1 — 2026-08-23

- Replace the broken one-pixel ARENA night marker with a cratered moon and a
  varied, deterministic star field; remove black/coloured skyline matte
  remnants and keep transparent outdoor scenery tied to the live sky.
- Make reviewed interior windows follow the same smooth
  dawn/day/dusk/night cycle while opaque rooms and greenhouse glazing retain
  their authored materials.
- Correct iOS ARENA canvas presentation, Mega/form sprite facing, grounding
  and size, large-sprite separation, oversized city shadows and overly heavy
  rain/fog presentation.
- Add a standalone VASC settings layout with START help and retain the public
  Kanto Ascendant menu integration when KASC is installed.
- Add grouped local user folders for battle, world, result and scene music,
  with per-category ORIGINAL/SHUFFLE/file selection and exact replacement of
  any resolved Game/KASC song ID.
- Add opt-in local PNG replacement for Pokemon forms/front/back/Dex/icons,
  player art, enemy trainers and registered overworld sheets, including KASC
  Mega and bicycle states. GAME/KASC is the protected default; per-section and
  global reset actions bypass every VASC replacement. Ship detailed English
  and German folder guides with platform-specific install paths. No third-party
  music or sprite is bundled.
- Keep the dynamic reveal gate, destination-specific Fly recovery, reviewed
  ARENA anchors and the Route 8 build-budget optimization intact.
- Add a fail-open KASC 6.7 Cinnabar story panorama contract: once the complete
  reciprocal south-channel topology exists, a compact volcano appears left of
  Birth Island on the approach horizon. Older/partial maps remain byte-for-byte
  on the established coast; VASC never owns the quest gate, rocks or scientists.

## 2.0.0 — 2026-08-22

- Add the reviewed ARENA battle presentation: 46 independent location masters
  cover 111 anchors across 95 maps, with fixed 3X footing, original HUD
  placement and an optional authored STADIUM director.
- Add continuous AUTO dawn/day/dusk/night lighting to the overworld, live sky,
  outdoor arenas and only the reviewed exterior-window regions of interiors.
- Add location-aware battle anchor selection for trainer, rival, Gym, League,
  cave, ship and special-room fights without changing MAP, DISCS or classic
  battle placement.
- Add persistent AUTO/PC/MAX/HANDHELD/ECO/CUSTOM device profiles, dedicated
  keyboard/controller voxel shortcuts and mouse-release-safe free cameras.
- Add a versioned optional battle-music provider API with ORIGINAL, per-fight
  SHUFFLE and available GEN 2–6 choices. No audio or network downloader is
  bundled; provider failure restores the original cue.
- Retain the dynamic reveal/load gate and Route 8 structure-analysis shortcut:
  presentation waits only for the actual destination, while the verified
  no-object regions remove 240,228 build-budget ticks without geometry drift.

## 0.1.8 — 2026-08-19

- Fix Gen1Recomp 0.2.19 zero-fade warps leaving `transitioning` permanently
  set after a cold voxel destination (notably Fly to Cinnabar), even though
  the arrival animation had already released the player's input lock.
- Add dedicated `V` and mapped right-trigger (`ZR`/`R2`/`RT`) camera-ladder
  shortcuts. Existing `3` and SELECT controls remain available.
- Add switchable Kanto skies with sun, pixel clouds, a color-coordinated
  20-minute day/night cycle, moon, stars and occasional shooting stars.
- Anchor clouds, stars, shooting stars, sun/moon and rare sky events to world
  bearings across ORBIT/1ST/3RD instead of rotating them with the camera.
- Add independently switchable, save-persistent rare rainbows and distant
  sky life with FULL/RAINBOW/FLYERS/OFF performance levels. Ordinary windows
  rotate Pidgey, Pidgeotto, Pidgeot, Spearow, Fearow and Murkrow through
  deterministic one-to-four-bird formations; Articuno, Zapdos, Moltres and
  Ho-Oh remain much rarer singleton sightings.
- Add lightweight CLEAR/AUTO/RAIN/SNOW/FOG/STORM weather. Fog uses bounded
  drifting haze; storms add denser rain and rare deterministic lightning.
  Active outdoor weather now remains visible in staged 3D battles.
- Replace enlarged border-block wallpaper with cached, transparent pixel-art
  skyline panels: varied layered trees, water/reeds, stepped mountains and
  stratified cave walls. Semantic outdoor/cave maps no longer build the old
  decorative border ring; separately tiled caps close elevated-view corners.
- Close every semantic cave and Pokemon Tower floor with a 160px wall and a
  32px-tessellated downward-facing ceiling. Cave tilesets select that shell
  regardless of map id; the two location-named Pokecenters remain rooms.
  Pokemon Tower now shares an opaque 512x160 two-bay wall and 256x256 coffered
  ceiling instead of repeating the former small procedural brick stamp.
- Add a world-fixed Kanto ridge behind open-sky routes, towns and mountain
  regions while keeping canopy forest, caves and the southern sea distinct.
  Route 1/Viridian replace their raised green side slabs with compact town-edge
  silhouettes and two sparse rows of batched voxel trees.
- Keep distant forest panels crisp with coarse outlined tree art and explicit
  1x-DPI, nearest-filtered, non-MSAA/non-mipmapped panorama canvases.
- Replace Viridian Forest's black no-sky void with a muted, day/night-aware
  canopy fill. It stays closed to celestial bodies while fog and storms still
  reach both the forest overworld and staged forest battles.
- Continue Cinnabar's free southern/western edges and the adjoining sea-route
  edges as reflective open ocean rather than procedural scenery walls.
- Replace the South Sea landmark cards with four irregularly grounded V3
  cut-outs: rocky island, lighthouse post, separated skerries and Cinnabar.
  Crop transparent module padding and map visible texels 1:1 to world pixels;
  map ownership, shared draw and 256 KiB texture budget stay unchanged.
- Add safe RAM-only PRELOAD. Current and connected meshes warm in the
  background, generation checks invalidate map edits, and the cache never
  writes stale geometry to disk.
- Keep the complete 2D renderer visible until current terrain, grass, flowers,
  figures, atlas/mask and panorama are drawable as one atomic scene. Repeated
  forest, grass and building geometry now uses shared templates plus instance
  offsets; connected jobs still rotate through a bounded budget. Split
  route-sized indexed GPU conversion into 1,024-vertex pages so transitions
  cannot stop the main thread for seconds or reveal delayed decoration pop-in.
- Derive a visual height datum from the engine's real one-way ledge triples.
  The existing 6px lip stays on the lower base while the plateau behind rises,
  producing flush and stackable Route 4 terraces without changing collision,
  movement, encounter or jump logic. Terrain, buildings, vegetation, figures,
  entities, camera placement and shadows all use the same snapshot.
- Fix outdoor house backs copying arbitrary front windows or signage. Rear
  walls repeat a clean 8x8 source-wall tile, then restore only an unambiguous
  native 2x2 door course on door-bearing OVERWORLD/FOREST buildings. A rear
  door becomes functional only where a real aligned warp already exists;
  cosmetic counterparts never invent collision, destinations or gameplay.
- Fix Kanto Ascendant 6.7 trainer-front routing and advertise the exact staged
  battle camera profile its compatibility bridge expects.
- Show an optional **VOXEL ASCENDANT** settings entry inside Kanto Ascendant's
  **ASCENDANT** menu through public runtime discovery, with no hard dependency
  and a no-op fallback when KASC is absent.
- Add a persistent **BTL CAM** 1X/2X/3X starting-distance control shared by
  MAP and DISCS 3D fights. New saves default to the wide 3X view, valid saved
  1X/2X choices remain intact and FULL no longer overwrites that preference.
  The existing Q/E, wheel and pinch zoom can still fine-tune the live shot up
  to 3X without being reset every frame; 2D battle framing and HUD rendering
  remain unchanged.

## 0.1.7 — 2026-08-19

- Split the former **BACK SPRITES** control into independent **TRAINER BACK**
  and **PKMN BACK** settings. Existing `battleBack` saves retain their Pokemon
  choice; the new trainer control defaults to front art in the 3D scene.
- Route `TRAINER BACK = OFF` through the engine's live `player.sprite` seam so
  vanilla and companion-selected trainer front art both render as a correctly
  mirrored player-side card.
- Restore the MIT-origin **1ST** and **3RD** VOXEL rungs with mouse, right-stick
  and touch look, camera-relative movement, collision-aware third-person boom,
  camera zoom and controller/touch-friendly SELECT cycling.
- Keep the restored camera code independent of the removed VR, Horde, Stadium,
  ROM and external-art features.

## 0.1.6 — 2026-08-19

- Add a persistent **BTL GRID** option so 3D battles no longer force voxel
  seams on against the player's preference.
- Add a persistent **SHADOWS** option for both the overworld and staged
  battles. OFF skips the shadow-map pass and its fallback decals, including on
  iPhone, while keeping the existing ON default for upgrades.
- Anchor each battle shadow to the combatant/opponent axis instead of the
  camera-facing billboard, so a stationary Pokemon's shadow no longer rotates
  or slides when the presentation camera drifts.
- Make cold map transitions progressive: queue the drawable body before the
  full border-ring mesh and expose terrain before grass, flowers and authored
  figures finish building.
- Queue a battle arena before its transition begins, allowing the first
  covered frame to contribute to loading instead of discovering the job one
  frame late.

## 0.1.5 — 2026-08-18

- Stop advertising the legacy wide/edge-HUD capability to companion mods on
  iOS. This makes Kanto Ascendant select its renderer-native HUD profile before
  installing the panel bridge that produced a bright green HUD-sized block.
- Match Gen1Recomp's status-HUD visibility guards, including the wild-battle
  party-ball intro where no enemy status panel exists yet.
- Fail closed when the platform cannot be identified, so companion HUD bridges
  are enabled only after a non-iOS platform is positively detected.
- Keep the owner renderer and desktop companion integration unchanged.
- Supersede 0.1.4, whose early snap decline removed the vertical flip but still
  allowed Kanto Ascendant to restore a colored frost panel into the grayscale
  battle canvas.

## 0.1.4 — 2026-08-18

- Decline the optional legacy edge-HUD compositor on iOS, where Gen1Recomp's
  final world-canvas presentation would otherwise flip those already-rendered
  status panels vertically.
- Preserve the established companion fallback contract: Kanto Ascendant and
  other feature-detecting consumers receive `false` and keep the original,
  upright HUD inside the centered engine frame.
- Leave the voxel renderer, desktop compositor and all gameplay state
  unchanged.

## 0.1.3 — 2026-08-18

- Restore the exact proven 0.1.1 renderer and battle-HUD implementation after
  the 0.1.2 mobile experiment caused Voxel Ascendant to stop rendering on
  affected clients.
- Keep only the release/API version bump; no experimental DPI, shader, water
  or HUD-backing behavior remains in this recovery release.
- Name the release archive directly from the case-sensitive manifest ID as
  `VOXEL_ASCENDANT-0.1.3.zip`, matching the launcher's canonical update rule.

## 0.1.1 — 2026-08-15

- Keep both battle HUDs in the centered engine frame so status panels and
  command menus share one scale on large and HiDPI displays.
- Confirm the permanent package boundary: no bundled Pokemon/trainer art and
  no sprite-pack menu; use the game or a separate compatible content mod.
- Move the project into focused compatibility-maintenance mode.

## 0.1.0-rc.1 — 2026-08-15

- Established the standalone `VOXEL_ASCENDANT` identity for Gen1Recomp
  `>=0.1.90`.
- Preserved the voxel overworld, orbit-camera ladder, tilt-shift, water,
  day/night lighting, native-card MAP/DISCS battles, back sprites, and AA.
- Added a versioned public renderer receipt and a RAM-only wall-decal
  registration/draw API for companion mods.
- Removed VR/OpenXR binaries, Stadium/ROM import and extraction code, Horde
  mode, first-/third-person free movement, global mouse callback mutations,
  FFI acceleration, process/filesystem probes, and disk caches.
- Added fail-closed capability checks, a narrow conflict set, deterministic
  direct-install packaging, and complete MIT provenance records.

The upstream v1.6.1 history is retained separately in
`UPSTREAM_CHANGELOG.md`; it contains features intentionally absent here.
## 0.1.8 — RC panorama completion

- Add an original, reproducibly built 1024×192 Kanto distance panorama behind
  outdoor map unions and MAP battles, centred on the player or battle arena.
- Preserve real terrain, connected neighbours, coastal openings, water,
  foreground scenery, the reviewed map-aware edge curtain, authored landmarks
  and all 1X/2X/3X camera rigs; draw the panorama strictly behind them.
- Keep 3X as the default battle view, retain stored 1X/2X choices and leave
  FULL from rewriting the battle-camera setting.
- Reduce the accepted panorama prototype from 2048×384 to 1024×192 after
  native 3X/coast comparison, saving 2.25 MiB retained VRAM; load it lazily
  and release its texture and mesh when SCENERY is switched OFF.
