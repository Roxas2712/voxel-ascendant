# Changelog

## 0.1.2 — 2026-08-18

- Size the voxel framebuffer from the engine's per-axis DPI metrics when they
  are available. This keeps the world aligned on Android devices whose
  forced-rotation drawable reports different horizontal and vertical ratios.
- Keep the staged-battle HUD scratch layers, readable depth target and water
  reflection copy at `dpiscale = 1`. Retina iOS no longer mixes oversized
  DPI-inherited attachments with framebuffer-pixel scene canvases.
- Add `HUD BACKING: TRANSPARENT / FROST`. Fresh installs default to transparent
  enemy/player status blocks; text and command boxes retain their readable
  panel, and FROST restores the previous status backing.
- Guard zero-length camera rays and invalid shadow depth values in the GLES
  shaders, preventing stretched screen-spanning cards and all-black shadows
  on affected mobile GPUs.
- Fall back to flat animated water on Android, where the reflective pass can
  produce hard Mali-driver stripes, and hide the inactive WATER row.
- Keep rotation and the touch HUD under Gen1Recomp ownership; VASC does not
  apply a second orientation transform to engine UI.

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
