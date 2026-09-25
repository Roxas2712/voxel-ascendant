# VASC 3.0.46 — Public Test Update

Complete installable update based on 3.0.45, published as a regular GitHub Latest release for launcher updates. This promotes the tested rc.8 runtime without gameplay code changes. Test status and coverage limits remain explicit.

## Changes since 3.0.45

- Integrate all 15 supplied Omega Dias Kanto Terrarium designs across 43 exact map IDs. Silph Company uses its design during Rocket occupation only. Original authored sources and credits are retained; encounters and story rules are unchanged.
- Add Cobblemon to the Dex source selector and correct Gen2 battle-model selection and switching back to Crystal sprites.
- Provide all ten supported pose/action slots for 463 bundled species and 1,894 variants: idle, battle, walk, entrance, default/physical/special/status attacks, flinch and faint. Supported original Cobblemon clips take priority; missing actions use rig-aware VASC motions. These are functional procedural fallbacks, not newly hand-authored original Cobblemon animations. The package includes a per-variant pose/source manifest.
- Preserve original idle posture and hidden facial geometry in generated actions. Recognize dedicated legacy battle-idle clips and keep original idle when a battle-only clip cannot be imported. Route move categories and recoil to the appropriate actions.
- Fix the opaque white background behind native Crystal battle sprites, preserving enclosed eye whites. Prevent a native sprite from reappearing after the 3D faint animation completes.
- Correct menu/help refresh, conditional rows, download selection/status navigation and setup failure handling. Preserve choices when menus rebuild, and keep download receipt failures retryable.
- Harden optional-model, Terrarium-effect and shadow-resource fallbacks. Recover invalid saved clocks and isolate optional download diagnostics.
- Reduce repeated content checks, disk lookups, listener sorting and render-time allocations with bounded caches and idle-scene scheduling.

## Validation and limits

86 headless suites pass. All 1,894 prepared variants contain the ten required slots; 85,520 sampled poses across 1,069 unique models are finite. Native desktop tests cover 90 Dex pose captures over nine species and Gen1/Gen2 battle routing, recoil, source switching and exit. The corrected Unown test checks generated actions, manually triggered faint completion, native background alpha, preserved enclosed whites and animated-frame cutout caching.

The earlier screenshot with a white rectangle was a real defect and is corrected here. Faint regression coverage uses a manually triggered animation, not a full engine-driven zero-HP knockout sequence. Not every species/variant has received individual visual approval. Physical phone/console GPU tests remain outside the desktop checks. See QA-REPORT.md and ALL_POSES_AUDIT_2026-09-25.md for details.

## Install

Close the game, import the complete Voxel-Ascendant-3.0.46.zip through the launcher updater and restart. Keep existing saves and optional artwork. Select TERRARIUM for the new location scenes and Cobblemon as the relevant Dex/battle model source. No ROM, engine or player save is included.
