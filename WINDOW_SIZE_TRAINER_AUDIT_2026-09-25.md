# Window, species-size and trainer-placement follow-up

Local fixes on top of public 3.0.46 (05753b5b). Not a new published release.

## Changes

- Pallet village front panes sit beyond the facade relief. Side/attic/skylight panes exclude opaque mullions; glass and opaque geometry no longer occupy the same volume. The stippling reproduced with shadows disabled, confirming overlapping geometry rather than a shadow toggle.
- Cobblemon battle scale uses native species height and a cached 16-sample battle/idle pose envelope. The bounded square-root height curve preserves species size differences while limiting extreme camera occupancy. Broad bind poses no longer squeeze Venusaur into a Rattata-sized sprite box. Missing metadata has a bounded neutral default. Gen 2 passes the active battler metadata too.
- MAP trainer placement checks the full card width and body depth against walkability, terrain support and authored solid geometry. Unsafe cached seats are reselected. Occlusion tests remain mandatory in the final search; the only allowed relaxation is limited screen overlap with the trainer's own Pokemon in the foreground. A visible side position is preferred before this relaxation. Unsafe introduction support also reaches the camera safety guard. World entity coordinates and map collision data are not moved.
- The user's battle-button settings remain unchanged.

## Validation

89/89 headless suites passed, including new regressions for glass/opaque intersections (8,223 pairs), species ordering/calibration/caching and full trainer support/occlusion/cached seats. Three existing GPU-only suites are outside this headless runner.

Native Love 11.5 isolated Gen-1 battles on Route 1: Venusaur, Rattata and Gorochu against Rattata. Actual active models verified as Cobblemon; screenshots inspected. Approximate visible world heights were 19.82, 7.71 and 16.57 respectively. Venusaur's former trainer seat behind the trees reproduced; the corrected seat is on open ground beside Venusaur. Native assertions confirm safe trainer support. This is a targeted visual check, not a manual check of every species/map/camera combination.

Native Crystal Venusaur-vs-Rattata battle: species metadata 2.0066 m and posed world height 19.69 verified; screenshot inspected. Small height differences between captures are idle motion under a constant calibrated scale.

Native Pallet captures include Red's house, Blue's house and the lab with shadow variants. Before/after Red-house and lab captures inspected; no renderer shadow setting disabled by the fix.

Reproducible native drivers are under `tests/native/`: `battle_species_size_and_trainer_audit.lua`, `gen2_species_size_audit.lua`, `pallet_window_layers_audit.lua`. They require the explicitly guarded QA save identities and host driver utilities, never the user's save. Gen-1 species driver takes `QA_SPECIES` and `SHOT_DIR`; Gen-2 takes `MENU_QA`.
