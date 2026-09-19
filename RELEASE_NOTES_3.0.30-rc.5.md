# Voxel Ascendant 3.0.30-rc.5 — combined local candidate

Combines the complete Gen2 3.0.30-rc.3 candidate with the implemented changes from “Video-Kritikpunkte aufnehmen”, both based on public 3.0.29. Not published or installed into a personal game.

## Gen2 retained

- Startup ownership fix; touch/controller V quick menu with contextual world and battle settings.
- Live MAP / ARENA / DISCS / TERRARIUM / GAME DEFAULT switching with rollback on failed presentation changes.
- Integrated Gen2 Terrarium, camera orbit/zoom/touch controls, stable species sizing, portrait HUD clearance.
- Actor prewarming and bounded mesh-loading slices; English fallback and Universal-driven German UI.

## Gen2 size correction after visual review

- Removes the leftover 2x Gen2 raw-card enlargement after species normalization. The normalized sprite now uses the same 16/56 world units as Gen1, preserving species ratios and stable animation references. Covers MAP, ARENA, DISCS and TERRARIUM; trainer cards and native 2D mode retain their existing scale. Also reads Pokédex heights from the actual Gen2 battle owner (screen.game.data), so species differences reach native rendering instead of silently using the default height. Supersedes the oversized RC3/RC4 presentation.

## Video feedback integrated

- Stable battle status cards: animation reference poses remove idle/flapping HUD jitter while retaining camera following, current design and the OUTSIDE placement default.
- Safer Gen1 battle camera framing and portrait changes; palette-preserving Dex sprites and isolated GPU sprite readback.
- Correct shiny overworld source selection, minimum HD follower body size and targeted Youngster edge cleanup.
- Celadon rooftop hut and panoramas; aquarium fish; stone/wood Pokémon Tower; taller Silph Co. and matching distant silhouette.
- Camera-aware Gen1 cave wall height, Safari obstacles, quieter gym floor materials, bicycle poses for the 16 Cycling Road trainers, detailed HD flight map.
- Clearer optional HD/Stadium setup guidance and Universal-driven Terrarium/Battle Heroes language.

See VIDEO_FEEDBACK_2026-09-18.md for scope, asset provenance and individual historical reports. No full 2.5D overhaul or new Stadium shiny extraction is included. The exact historical KASC animation/battle glitches remain unconfirmed.

## Integration validation

13 Gen2 regression suites and 16 video-feedback regression suites, including GPU tests, pass on the combined source. Native Gold/Crystal tests cover 20 mode changes, real attacks and normal battle completion, injected failure rollback, touch/controller camera paths and 36 world cases. Native Gen1 flying-model HUD test verifies no animation-driven status drift and continued camera following. All package Lua files compile, ZIP CRC and both file-hash receipts are checked. Source changes were merged without conflicting files; all RC3 runtime changes are preserved except the corrected Gen2 Pokémon scaling. Screenshots and logs are in the accompanying comparison report.

Native validation uses LÖVE 11.5 / engine 0.2.61 on macOS, including simulated touch and portrait windows. Physical iPhone/Android hardware is not retested. Optional ROM extraction and exact historical tester glitches are not claimed as validated by this integration.
