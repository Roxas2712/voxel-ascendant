# Source-world Johto backdrop

Enabled for matching native Gold and Crystal GBC data on the 31 connected Johto outdoor maps using JOHTO / JOHTO_MODERN. This is distant scenery, not another live world or a gameplay map change. Other tilesets, interiors, modified map/art/palette data and missing or corrupt captures retain the previous semantic horizon.

`JohtoWorldSignature` revision 2 fingerprints map blocks, connections, environments, palettes, tilesets and roofs. `bake_johto_world_catalog_driver.lua` runs only against isolated QA identities and constructs the native source geometry offline: 127 Crystal buildings / 133 Gold buildings. It retains native ground under excluded near maps and fills unmapped inland space with simplified trees; coastal classifications remain water. No sky is baked.

The ground capture is world-aligned at y=-8 and shared between map views. Four cropped cardinal strips supply the horizon; their lower edges fade into the ground capture rather than projecting a cubemap floor over the world. Near maps are excluded from horizon geometry according to the same four neighbor depths as the renderer. Native window texels have separate night masks; frames and mullions are excluded. Near geometry is drawn after the backdrop. Only the generic Johto forest boundary is suppressed after a complete backdrop becomes available.

One view is resident at a time. Preparation decodes/uploads at most one image per call. Each view costs at most 5,028,304 bytes of RGBA textures in the shipped catalogue, under the 6 MiB cap. The shared ground texture is 1024² and cardinal captures are cropped from 640². Map/depth changes, scenery OFF, entering an interior and context invalidation release old meshes/textures. Stable frames perform no re-upload. Mobile staging completes these resources before the existing atomic scenery promotion.

Validation, 2026-09-19:

- Both catalogues: 124 views each; 121 per edition contain visible distant windows. Image dimensions, complete faces, native source signatures and per-view texture budgets checked.
- Fault injection: atomic view readiness, map/depth replacement, OFF/ON, corrupt images, incorrect dimensions, foreign source data, DMG exclusion, ground placement and resource release.
- Native Crystal and Gold: four cities by day/night, elevated cardinal views, zoom 1/2/4/8/1, route/city transitions, scenery OFF/ON, Elm's Lab round trip and cache invalidation. Both passed, 127 staged texture uploads per matrix.
- The same native Crystal matrix passed with the scene's mobile scenery scheduling branch selected, using the desktop GPU (11,503 rendered frames). This is a scheduling test, not an Android/iPhone device or driver test.
- Shared native window detector and the existing Gen1 windows/doors plus Gen2 walls/roofs/building-shell suites passed. Frozen A21 ownership remains 217; the added modules belong to the voxel-world Card outside that baseline.

Visual limits: this is an image LOD. It does not have full 3D parallax, and extreme overhead zoom reveals simplified far-map ground and canopy detail. Physical phone testing and release packaging remain separate. No public release was uploaded for this change.

Private QA scripts and source capture receipts: `.codex-private/vasc-johto-world-runtime-20260919` in the maintainer workspace. `bake.py` (Crystal or `POKEPORT_VERSION=gold`), then `install.py`, `unit.py`, `view.py`. Source captures are generated, never baked during normal gameplay.
