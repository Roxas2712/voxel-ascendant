# Cobblemon pose coverage — 2026-09-25

Runtime validation of candidate 3.0.46-rc.8, promoted unchanged to public test version 3.0.46.

All 463 bundled species and 1,894 variants now contain idle, battle, walk, entrance, default attack, physical attack, special attack, status attack, flinch and faint slots. The prepared set has 1,069 unique model records and an explicit per-variant pose/source manifest in `assets/cobblemon-prepared/poses.json`.

Existing supported original Cobblemon clips take priority. Missing slots receive conservative procedural VASC motions derived from the rig: body, legs, four legs, wings or fins, with primary tail bones where present. These are not newly authored original Cobblemon animations or complete execution of Kotlin/Molang poser logic. Sleep, swimming and every possible move-specific pose are outside these ten slots. Other sprite sources retain their own animation path.

The motion baseline samples the original idle pose, preserving hidden face meshes and rest transforms. Descendant limb/tail joints are excluded from duplicate procedural transforms. One-shot actions have finite durations; faint holds its endpoint. Legacy battle-idle clips are recognized, and a missing/unusable battle clip retains an available original idle.

## Coverage

- All 1,894 variants have all ten required slots and matching source attribution: 18,940 entries.
- 85,520 sampled poses across 1,069 unique models are finite.
- Compared with rc.7 normal variants, 1,862 original action records remain identical; 57 battle-idle selections upgrade to the species' dedicated original battle idle.
- Normal variants use original/VASC clips respectively: idle 437/26, battle 440/23, walk 388/75, entrance 297/166, physical 55/408, special 50/413, status 48/415, flinch 100/363, faint 108/355. Default attacks use VASC for all 463.
- Headless suite: 86/86 passed, including baseline preservation, hidden geometry, primary-joint selection, action continuity, idempotence, import fallback and prepared-manifest coverage.
- Native desktop Dex renderer: 90 pose captures over nine species (48 original, 42 VASC). The tenth requested species, Rayquaza, is absent from the Crystal test host and was skipped explicitly.
- Native Gen1 and Gen2 battles exercised move-category routing, missing-action fallback, recoil, source switching and battle exit.
- Native Unown battle exercised all three generated attack categories, entrance, flinch and manually triggered faint, endpoint hold and suppression of sprite reappearance.

## Screenshot defect and correction

The first faint screenshot was captured after a manually triggered faint finished while the battle's Pokémon still had full HP. The invisible model yielded its slot to the native sprite. Crystal's opaque white shade-0 background then appeared as a rectangle. The user correctly flagged this; the original capture was not a successful visual acceptance.

The completed faint now retains slot ownership until the actor resets or is replaced. Native Crystal indexed images are stripped only of border-connected white before palette application; enclosed eye/body whites are retained. Animated sheets are processed independently per frame and cached by source image and frame size. True-color replacements retain their own alpha.

The corrected native run verifies no fallback after faint completion, transparent native capture background, preservation of enclosed white, per-frame sheet processing and cache reuse. Corrected Crystal, mid-faint and completed-faint screenshots were inspected. The complete 90-image Dex set was generated with renderer assertions, not individually signed off visually.

## Limits

No claim of manual visual inspection of every species/variant, all move-specific animations or physical phone/console GPU performance. The faint regression uses a manually invoked animation, not a complete engine-driven zero-HP knockout sequence. Generic generated motions are functional coverage and can later receive species-specific artistic refinement. The supplied Terrarium source files and source receipts remain unchanged.
