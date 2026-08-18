# Changelog

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
