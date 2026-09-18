# Voxel Ascendant 3.0.25

Public release of the tested RC22 runtime, with the live FPS/performance overlay now OFF by default. F4 or R1 + Down can enable it; an explicitly saved preference is retained. Version 3.0.24 is intentionally skipped.

- Corrected Pokémon Mansion and Power Plant wall layouts against native 2D maps, including all four Mansion floors and live switch doors. Celadon Mansion uses the real side entrances and restores the interactive wall signs on floors 1–3.
- Improved interior floors and furniture, Cinnabar Lab surfaces, Blaine's Gym exit, coastal water coverage, department-store height and elevator interiors. Elevator controls use a compact floor selector at the actual interaction point.
- Updated HD overworld Pokémon sizing and fixed scripted town Pokémon resolving to available HD sprites. Verified sprite caches can be read without redundant writes; startup avoids repeatedly hashing all installed DLC.
- Raised battle HUD buttons display their complete shapes while the simplified Glass style remains available. Includes battle camera recovery improvements and the latest flight/surf transition fixes from the RC series.
- VASC help follows the active Universal translation language; English is the default.
- The Stadium 2 importer corrects missing textures for Murkrow and Skarmory. Existing Stadium imports need to be imported again from your own ROM for that specific correction. This is separate from downloaded HD sprites.

Update and fully restart the game. Keep downloaded/imported content and user files. No save reset is required. Kanto Ascendant 6.7.12 is the companion release; VASC also works independently.

Validation includes the RC21 native map comparison, 3,489 wall-course checks, all three Celadon sign interactions, targeted interior/camera/HUD/cache regressions, and fresh overlay-off/toggle tests. The final archive is checked for exact RC deltas, Lua syntax, CRC and indexed hashes. Native testing was on macOS; no physical Windows/Android/iOS test is claimed.

Some reported cases remain unconfirmed: the particular Windows battle-camera failure and other white/flashing-edge Gen 2/3 models. This release does not claim those reports are all resolved.
