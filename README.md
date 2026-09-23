## VASC 3.0.37 — Models, sprites and characters (1/4)

Public test release, published as a regular GitHub release. Recommended pairing: KASC 6.7.19. These notes cover changes since VASC 3.0.36.

- Added selectable Cobblemon models and animations for Gen-1 battles, followers and visible wild Pokemon. Coverage includes Hoenn, Gorochu and the regular KASC roster: 463 model slots plus 18 Alolan forms.
- Official assets are bundled with their licenses in BASE, avoiding thousands of separate downloads. Setup distinguishes local verification, real network speed and model preparation; repair, resume and cancellation preserve verified files and the selected model source.
- Fifteen missing models receive simpler, clearly identified Ascendant-made models. Unsupported/missing models and missing shiny artwork retain sprite fallbacks. This is not unrestricted compatibility with every Cobblemon add-on or animation expression.
- Model sizes use Crystal battle-sprite silhouettes and later-species references while preserving proportions.
- Animated HD Pokemon can be selected in battles and the Modern Dex. Original, Crystal and HD choices are exposed when available; F3 changes work during move selection. HD artwork faces the opposing Pokemon as the camera rotates.
- Added a separate Voxel Characters Card for Red, Blue and Green, associated NPC artwork and character-specific wardrobe presentations. F6/F3 switches Original, HD and Voxel styles without changing character identity. VASC alone uses Red.
- Corrected Pokemon/arena actor scale, oversized followers, scripted HD movement and Nurse Joy's white cutout remnants. Joy retains her original poses. Champion clothing and fishing poses better match across render styles.

---

## VASC 3.0.37 — Battles and interface (2/4)

- Regional MAP battle courts cover wild and trainer encounters, including separate Surf placements. Closer side-oriented starting views, stable trainer seats and safe room-specific placement replace excessive overhead views and frequent repositioning. Camera zoom/orbit remain available.
- Battle recovery follows MAP > Terrarium > Arena > Discs > Vanilla, beginning at the chosen presentation. The fallback is reported on screen and applies only to that encounter; the next battle restores the saved selection. Vanilla is the final safety path if every supported 3D stage fails.
- Bounded loading covers avoid briefly exposing the native map during known world rebuilds.
- Fixed attack-animation source/target transforms and optional hero-art failures, including the Omega Dias hash(nil) crash. Ball-throw animation receives its one-time enabled default.
- Level-up summaries show stat gains and filling the EXP bar has audible feedback.
- VASC now presents the complete evolution sequence, with readable introduction, result and cancellation text. Available HD/Crystal art is reused; missing art falls back without exposing the old white scene or stale battle HUD.
- Post-evolution move learning remains readable for free slots, replacement and declining a move, including after wide battles. Engine evolution, cancellation and learning rules remain authoritative.
- Refined location plaques, trainer alert bubbles, save-summary presentation, world curvature and less rigid flower placement.
- Native touch-button offsets are shared with the layout editor and remain editable. Touch OFF hides the independent VASC launcher and removes stale hit areas. Walking no longer makes the launcher flash; keyboard/controller shortcuts remain usable.
- Johto quizzes now use the full ORAS question layout with a visible, live countdown. The question stays alongside the answers rather than generic help text.

---

## VASC 3.0.37 — Seasons, weather and scenery (3/4)

- AUTO weather cycles through spring, summer, autumn and winter, using game time: 16 minutes per season. Spring/autumn have more rain, summer brings heat and winter brings snow. Manual weather remains authoritative; the clock is saved.
- Deciduous trees transition to fresh spring greens and autumn red/orange/brown. Conifers and trunks keep appropriate colors. Sparse windblown autumn leaves use a bounded particle budget.
- Accumulated snow coats trees, roofs and upper landscape surfaces. Added frost flowers, roof icicles, thunder and stronger snow/rain movement sounds. Thawing is gradual rather than instantly clearing existing snow.
- Deep snow can form walkable ramps over suitable small outdoor ledges. They work in both directions and with free movement, then disappear safely during thawing. Floor-to-floor stairs, progression barriers, disconnected areas and map exits are excluded.
- Actual distant voxel trees, terrain and roofs now react to seasons and accumulated snow, including Celadon rooftop views. Windows, water and building colors are excluded from foliage tinting; the painted 2D panorama is unchanged.
- Rooftop mountain silhouettes now come from the actual surrounding map geometry and world positions rather than invented mountain cones.
- Improved Driftglass's island/coast/pier presentation, Safari decorative posts, mart terrace detail and Pokemon Tower lighting.

---

## VASC 3.0.37 — Interiors, lighting and performance (4/4)

- Restored complete gym floors, including disconnected puzzle/teleport rooms, wall-edge joins and perimeter floors that survive roof cutaways. Silph Co's eleven floors use complete vanilla layouts; large-room floor/wall masks remain cached until relevant geometry changes.
- All eight Kanto gyms feature flush badge-mosaic skylights with transmitted daylight and moving floor projections. Glass meets the ceiling directly, without an added black frame. Night and weather affect the light.
- Misty's pool receives a shimmering/distorted projection while dry paths stay stable. Fixed indoor water brightness and outdoor-sky reflections leaking into the pool.
- Added the Fighting Dojo's amber martial-arts mosaic and building-specific ceiling/fixture families, including Oak's lab, the mart, casino, SS Anne and supported KASC interiors. Roof cutaways and existing light budgets remain intact.
- Reduced repeated CPU allocation and retained data through bounded horizon/MAP caches, shared prop buffers, reusable terrain signatures, retired HD resolver layers and released old sprite-bound identities.
- Background HD decoding, bounded uploads and staged battle/send-out preparation reduce synchronous work. Human atlas geometry is cached against actual file hashes; shader programs and unchanged geometry are reused. New Voxel character frame bounds are precomputed.
- These are targeted improvements, not a universal FPS or zero-stall promise. Cold loading can still spike. Physical Windows/mobile and longer sessions with the final paired build need further feedback.

Install: close the game, update the existing mod and restart. Keep saves and optional artwork. The Preserve-Installed-Sprites installer backs up an existing installation and retains omitted optional files. Check the supplied SHA-256 files when downloading.

---

## Previous documentation

# VASC 3.0.36 — Readability and battle hotfix

• Larger, readable HD Pokémon in the overworld: followers, city, indoor and wild Pokémon share size floors. Battle scaling is unchanged.
• Fixed Gust targeting its own caster when used by the opponent.
• Fixed classic 2D HUD briefly flashing after confirming a move in MAP battles.
• Corrected Delia's seat position and dining-chair proportions; her chair back now faces the table.
• Existing translucent battle panels remain in use, including the empty transition frame before attack text appears.

Validation: 772 HD variants; Gust targeting both sides in both generations; native MAP battle confirmation frame captures; native seated-NPC checks. The reported second Mac on engine 0.2.66 has not yet been retested.

---

## Previous release documentation

# VASC 3.0.35 — Steam Deck hotfix

- Recognize Steam Deck Vangogh and AMD Custom GPU 0405/0932 renderer names on Linux/Windows; generic AMD GPUs and screen resolution alone are not classified as Deck.
- AUTO uses BALANCED on recognized Deck hardware, including the shared host AUTO detector. Explicit graphics tiers and CUSTOM settings remain available.
- Gen1 Deck AUTO keeps native 1280×800 rendering on the built-in panel with a 1080p cap for larger displays and no automatic supersampling.
- Gen1/Gen2 world lighting uses a four-light budget; battles use two lights and terrariums two local lamps. HD sprite selections and desktop graphics APIs remain intact.
- Bounded menu glyph cache reduces repeated text allocations, with font reload and live-value handling preserved.

Works with KASC 6.7.17; no KASC data update is required. Select AUTO to use hardware defaults if you previously chose HIGH or CUSTOM manually.

Validation: device/profile and negative-control tests, Gen1/Gen2 lighting/fallback checks, support menus and cache regression tests. Physical Steam Deck FPS and complete elimination of reported stalls are not yet verified.

---

## Previous release documentation

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
