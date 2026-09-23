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
