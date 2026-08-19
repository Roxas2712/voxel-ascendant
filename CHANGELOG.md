# Changelog

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
