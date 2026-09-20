# Voxel Ascendant 3.0.34

Omega Dias terrariums, volcanic scenery and animated world encounters. Includes all fixes and optional Gen1/Gen2 lighting from 3.0.33.

- **15 terrariums by Omega Dias / ΩDIAS:** all eight Kanto gyms, the Elite Four, Champion, Pokémon Tower and Rocket Hideout. Creator signatures retained. The Tower ghost symbol is removed from the arena decoration.
- **Terrarium atmosphere:** drifting mist in Fuchsia Gym and Pokémon Tower, smoke in Cinnabar Gym, plus optional stage lighting. Mobile uses two lights; desktop uses three. Stage lightmaps are cached, and ball rocking remains available.
- **Battle orientation:** choose Side-on or Behind Trainer through V / F3 → Terrarium. The choice is saved; trainer facing and attack effects follow the selected battle axis. Gen1, Crystal and Gold support the setting. The withdrawn experimental Johto designs are not included.
- **Moltres volcano:** irregular basalt crater rim and floor, voxel boulders, glowing rock, ash, sparks and procedural smoke/red haze. Native passages, encounter gates and collision remain authoritative.
- **KASC locations:** themed rock formations, cave atmosphere and lighting along supported legendary paths; Rayquaza's open sky platform; Deoxys' ocean island with shoreline, pier and moving puzzle triangle; Driftglass research structure and voxel prism; voxel vegetation/rocks in the supported starter habitats.
- **World encounters:** enlarged Groudon, Kyogre and Rayquaza; appropriately sized legendary pixel-art idle cards, including an upright Mewtwo at its original encounter position. With KASC 6.7.17, bundled authored animations cover 22 species. Existing directional sprites and selected available HD/Stadium sources retain priority. HD content still uses the existing optional download/import system.
- **Rooftop fix:** the department-store rooftop seats are restored so the seated NPC is supported.
- **Compatibility:** native 2D sprites, story interactions and original encounter positions remain intact. Animation updates are bounded and shared across render passes; animation OFF freezes the authored fallback pose.

## Update

Install **Voxel-Ascendant-3.0.34.zip**. For the new KASC world encounter assets and Hoenn puzzle fixes, also update to **Kanto Ascendant 6.7.17**. The optional preserving installer creates a backup and retains omitted downloaded sprites/settings. Do not delete saves or optional HD downloads.

## Validation

Focused geometry, visibility, lighting, animation ownership and battle tests passed. Native LÖVE checks cover the terrariums, Gen1/Gold/Crystal orientation, legendary encounters, selected passages/return warps and the Deoxys puzzle. Portrait/mobile rendering budgets were exercised on macOS; physical phone FPS were not measured. Further decorative work on individual rooms and paths remains planned.

---

## Previous release documentation

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

---

## Previous release documentation

# Voxel Ascendant 3.0.32

An update for Generation 1 and Generation 2, with visual repairs, clearer camera behaviour and improved mobile rendering options.

## New and improved

- **Gen2 rendering options:** choose 1080P, native resolution or 720P directly from the quick menu. The previous hidden mobile resolution cap is removed. Mobile tree rendering now uses the compatible geometry path, and world/camera shader calculations use higher precision.
- **Animated Gen2 battle Pokémon:** the battle renderer can use animated fronts supplied by the companion sprite provider. Animation and provider settings still apply; missing assets keep their normal fallback.
- **MAP battles:** opening the attack-selection menu can keep the last valid camera and reframe it for the larger menu instead of unnecessarily dropping back to 2D.
- **Safari Zone:** more rocky terrain and less moss, cleaner ground, and recognizable exit frames. Native paths and exits are preserved.
- **Fuchsia and surrounding areas:** replaced additional original checkerboard ground motifs with continuous paving. The fossil exhibit displays Amonitas/Omanyte or Kabuto according to the original fossil choice, and the neighbouring enclosure uses the intended Pokémon presentation.
- **Window rendering:** removed overlapping solid surfaces behind glass that could produce broken or flickering panes.
- **Celadon rooftops:** modern voxel floors, glazing, stair entrances and vending machines. Distant scenery is drawn from the actual connected Kanto world, with voxel forests and landmarks, live sky and lighting. Outdoor rain now applies to the roofs.
- **Bikers:** native Biker trainers in both generations use the seated bicycle artwork wherever the registered assets are available.
- **Johto buildings:** Crystal's Olivine lighthouse is recognized as one complete tower. Goldenrod's north gate now has a complete building and roof instead of a flattened facade with a raised window fragment.

## Still being worked on

- The new source-world distant scenery for **Johto** is not included yet. Existing Johto backgrounds remain.
- Further Johto house and wall styling is still planned.
- The reported Gen2 flicker on physical phones and the reporter's installed animated-sprite package still need device verification. The changes above are not a claim that every mobile rendering issue is resolved.

## Installation

Download **Voxel-Ascendant-3.0.32.zip** for the normal mod update. Do not delete your optional sprite downloads or saves just to update. An optional **Preserve-Installed-Sprites** desktop installer is also attached; it makes a backup and preserves omitted optional sprite files and settings.

Higher scene resolution and expanded tree geometry can use more GPU time or memory. Choose 720P if needed.

## Validation

Native macOS runs cover Gold, Crystal and Yellow, with focused automated regressions and visual comparisons from the development candidates. The Goldenrod gate was entered through normal movement in both Gold and Crystal. Archive contents, Lua syntax, checksums and the preserving installer are checked for this release. These checks do not substitute for physical iPhone/Android testing.

---

## Previous release documentation

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

---

## Previous release documentation

# Voxel Ascendant 3.0.29 — Readable, bounded battle Pokémon sizes

Changes since 3.0.28:

- **Small Pokémon stay visible:** a smooth size curve uses Pokédex/form height without mapping metres directly to screen pixels. Pikachu's reference extent is about 80% of Manectric's; Wailord stays below twice Pikachu's. Camera perspective and animation poses still affect apparent screen size.
- **Large Pokémon are gently capped:** giants remain visibly larger without dominating the battlefield.
- **Stable animations:** full-animation visible bounds supplied by KASC 6.7.14 keep scale constant between frames and ignore transparent card borders. Unknown/custom artwork uses a fixed measured fallback per model.
- Trainer sizing, existing camera fit and 1X/3X zoom, manual layout adjustments and classic 2D geometry are retained. No save migration is required.
- Includes all 3.0.28 sprite-maintenance, compact artwork, quick-menu and MAP-camera improvements.

## Updating

Use **KASC 6.7.14 together with VASC 3.0.29** for the complete battle-size update. Update both mods and fully restart the game. Existing saves remain compatible. Keep downloaded/imported sprite content; do not delete the existing mod folders first. The ZIP is the normal mod package. For manual desktop updates, the optional **Preserve-Installed-Sprites** installer creates a backup and preserves optional downloads; follow its included instructions.

## Validation

The reviewed release-candidate runtime is unchanged. Tests covered 1,351 canonical height/form entries, 78,779 PNG records in 6,153 animation/palette groups, 382 animated variants / 3,921 frames and 424 static variants. Native macOS tests included Pikachu versus Manectric and Wailord, Crystal mode, Mega Manectric and Gorochu, plus 1X/3X MAP camera checks. All packaged Lua files, archive integrity and installer preservation checks passed. Fifteen additional gameplay regression tests passed.

Not every form has been manually played. Physical mobile-device and live cloud-sync verification remain pending.
