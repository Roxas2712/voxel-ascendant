# Voxel Ascendant 3.0.30 — Gen2 recovery, battle modes & faster world loading

This update brings the reviewed Gen2 improvements and recent visual fixes together. Changes since 3.0.29:

## Gold and Crystal

- **Gen2 starts again:** fixes the file-ownership check that could stop the mod during startup.
- **V quick menu:** touch-friendly controls and controller navigation, with separate world and battle settings. Includes quick access to follower, town/wild Pokémon and presentation settings where available.
- **Battle views:** switch between MAP, ARENA, DISCS, the integrated Gen2 TERRARIUM and GAME DEFAULT. Includes orbit/zoom controls and portrait HUD clearance, with recovery if a presentation switch fails.
- **Correct Pokémon scale:** removes the extra Gen2 enlargement and reads species heights from the actual battle data. Small and large Pokémon retain their relative sizes without animation-driven resizing.
- **Faster first world build:** the optimized building construction now also runs in Gen2. In eight comparable macOS runs per version, Goldenrod's first 3D frame improved from 14.3–14.7 seconds to 2.48–2.55 seconds; New Bark Town from 1.77–1.87 to 0.55–0.62 seconds. Geometry, textures and per-frame work budgets are preserved. These are desktop measurements, including simulated touch/portrait, not phone benchmarks.
- Actor prewarming, bounded loading work and improved English fallback; German UI follows the Universal translation mod.

## Visual and interface improvements

- Stable battle status panels while Pokémon idle or flap, while still following camera movement.
- Improved Gen1 battle camera framing, portrait handling and Dex sprite rendering.
- Correct shiny overworld source selection, more readable small HD followers and targeted character-edge cleanup.
- Celadon rooftop scenery, aquarium fish, Pokémon Tower variants, a taller Silph Co. landmark and matching distant silhouette.
- Camera-aware cave walls, Safari obstacles, revised gym floor materials, Cycling Road trainer poses and the detailed Kanto flight map.
- Clearer optional model setup guidance and further menu-language fixes.

## Updating

Update VASC and fully restart the game. Keep existing saves and downloaded/imported sprite content; do not delete the mod folder first. The **ZIP is the normal mod package**. The optional **Preserve-Installed-Sprites** desktop updater includes backup/preservation instructions.

Custom Cards pinned to an older VASC version do not automatically adopt this update; update their mod binding or use the standard updated mod installation. Existing Cards are not republished in this release.

## Validation and remaining scope

The shipped runtime/assets are identical to the tested 3.0.30-rc.6 candidate. Combined validation covered Gold/Crystal world rendering, battle modes and real attacks, touch/controller paths, rollback, species sizing and Gen1 visual regressions. The loading change additionally passed exact comparisons for 64 native building models, 24 analytical/dense cases, 13 existing Gen2 regression suites and eight benchmark runs. All packaged Lua files compile; archive integrity and file hashes are verified.

Physical iPhone/Android retesting remains pending. General Gen2 forest, mountain and sea backdrops work; new location-specific Johto panorama artwork is not included. This release does not claim that every historical tester report is resolved.
