# Voxel Ascendant 3.0.33

Dynamic lighting for both generations, source-world distant scenery for Johto, and cleaner buildings. Includes all fixes from 3.0.32.

## Dynamic lighting — optional in Gen1 and Gen2

- **Gen1:** sun, moon, windows, indoor lamps and torches illuminate the 3D world and characters. Works with VASC replacement buildings/HD characters and with voxelized original buildings/original sprites. Light sources follow the buildings actually shown.
- **Gen1 battles:** separate battle-lighting switch for MAP and ARENA scenes.
- **Gen2:** sun, moon and native building-window light in the 3D world and live MAP battles, including original and HD characters. Toggle **Dynamic lighting** in the normal settings or **Camera & World** quick menu. Gen1-specific indoor/torch profiles are not applied to Johto interiors.
- **OFF remains available:** restores the previous world shading and persists with your settings. A lighting shader failure keeps the existing 3D renderer running.
- **Mobile budget:** up to four local lights and four building occluders, versus eight each on desktop. Window data is cached as small records; large construction geometry is still released.
- **Fog preserved:** dynamic lighting no longer reduces Pokémon Tower fog density or height. Viridian Forest retains its existing fog density and height too.

## Johto scenery and building improvements

- **Distant scenery from the actual world:** enabled across the 31 connected Johto outdoor maps using the supported native Gold/Crystal tilesets. Forests, routes and landmarks come from the corresponding game world, with separate night-window masks.
- **One live sky:** no daytime sky baked into the backdrop; the game's sky and day/night state remain in control.
- **Bounded loading:** one view at a time, less than 6 MiB of resident backdrop textures, staged image loading and no repeated uploads while standing still. Scenery OFF, interiors and map changes release the old view. Unmatched or modified source data retains the existing horizon.
- **Cleaner Johto buildings:** regional native roof colours and calmer wall materials. Facade decoration is trimmed around door openings instead of protruding into them.

## Installation

Use **Voxel-Ascendant-3.0.33.zip** for the normal mod update. An optional **Preserve-Installed-Sprites** desktop installer is also attached; it backs up the previous installation and retains omitted downloaded sprites and settings. Save data and optional sprite downloads do not need to be deleted for this update.

## Verification and limits

Native macOS tests cover Gold/Crystal day and night, multiple cities, saved light switches, interior/exterior transitions, HD lighting and fallback recovery. Gen1 was checked with both original graphics and the VASC overhaul. Johto scenery was tested through map transitions and all four neighbor-depth settings. Archive integrity, Lua syntax, file receipts and installer preservation are checked for this release.

Goldenrod's measured average FPS decrease with lighting enabled was approximately **1–4% on the test Mac at 1100 × 700**. Reduced mobile light budgets were also exercised on that Mac; these are **not physical iPhone/Android measurements**. Sustained phone performance and device-specific rendering still need verification. Distant scenery is a baked image LOD with limited parallax, not another fully simulated world. Classic 2D rendering remains unchanged.
