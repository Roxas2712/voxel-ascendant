# VASC 3.0.47 — QA report

Source runtime: 7cca9432db5e01a44fc5facb4e0be692a4aedf24, based on public 3.0.46 (05753b5bce6e4763fe619303561fc86f9fce0a29). Packaging updates version, documentation and generated receipts only.

- 89/89 headless regression suites passed. Three existing GPU-only suites are excluded from that runner.
- New tests cover pose-based size calibration, species ordering, metadata, cache reuse, trainer support/occlusion/cached seats and 8,223 glass/opaque intersection checks.
- Native Gen 1: actual Venusaur, Rattata and Gorochu battles against Rattata; Cobblemon model source and supported trainer feet asserted. Screenshots inspected. Measured visible heights approximately 19.82, 7.71 and 16.57 world units.
- Native Crystal: Venusaur-versus-Rattata; species metadata 2.0066 m and posed height 19.69 world units verified; screenshot inspected.
- The prior Venusaur trainer position behind trees was reproduced. The corrected position is on open ground beside Venusaur. World entity coordinates and map collisions are not changed by this presentation fix.
- Pallet native captures cover Red's house, Blue's house and the lab with shadow variants. Before/after Red-house and lab images inspected. The defect reproduced with shadows disabled; the fix changes geometry, not the user's lighting settings.
- Existing battle-button settings are preserved.
- Packaging verifies all Lua syntax, ZIP CRC, every embedded file receipt, all prepared-model content hashes and 30 original Terrarium source hashes. Prepared assets are unchanged from 3.0.46.

The 3.0.46 pose/action audits remain historical evidence for the unchanged assets. This release does not claim a new exhaustive pose review, a full zero-HP knockout-sequence retest, all-map visual signoff, or physical phone/console GPU validation. See WINDOW_SIZE_TRAINER_AUDIT_2026-09-25.md for the focused follow-up.
