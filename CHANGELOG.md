# Changelog

## 0.1.0 — 2026-08-15

- Keep battle HUDs in the centered engine battle frame so status panels and
  command menus share one scale on large and HiDPI displays.
- Prevent the left-edge crop of long enemy names caused by window-edge HUD
  snapping.
- Add an independent Gen-I Crystal battle-art pack, animation controller and
  VASC-owned BATTLE ART / CRYSTAL MOTION menu rows. KASC remains untouched and
  wins sprite selection when both mods are active.

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
