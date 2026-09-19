# Voxel Ascendant 3.0.30-rc.3 — Gen 2 parity candidate

Local candidate based on public 3.0.29; not published.

- Restores the frozen 217-file A21 baseline, retaining explicit ownership of newer adapters. Gen 2 starts with all eight Cards; no integrity checks were disabled.
- Adds the shared touch/controller V quick menu to Gold/Crystal: camera view, grouped followers, wild and town Pokémon, world effects and downloads. Battle pages expose battle settings; live changes are limited to command/move selection.
- Switches MAP, ARENA, DISCS, TERRARIUM and GAME DEFAULT without restarting battle logic. Normalizes the engine's two different battle.started payloads into one encounter owner. Failed presentation changes restore the previous setting and renderer.
- Adds an integrated Gen 2 Terrarium with environment styles, trainer view, idle animation/sound, ball designs, backgrounds and glass dome. Reuses packaged assets; no companion download required.
- Routes touch orbit/pinch, mouse wheel/motion and controller camera inputs to the actual rendered battle camera. Zoom range .45–3.0; manual steering also works with automatic camera disabled. Camera reset reaches the same owner. Quick-menu overworld camera changes override the post-warp latch.
- Applies shared species-based sprite sizing using native Gen 2 height units and stable source bounds, independent of animation pose or source resolution.
- Prewarms actor cards during map warm-up and bounds mesh-loading slices (urgent <=8 ms, covered <=6 ms). No claim of measured total cold-start speed-up.
- Fixes Gen 2 options headings/control hints to follow the active Universal language with English fallback. New quick-menu labels are bilingual; native labels and values remain engine-owned.
- Keeps portrait battle status cards away from upper touch controls and prefers a nearby clear seat over a distant screen corner.

Validation: native LÖVE 11.5 / engine 0.2.61 on macOS, Gold and Crystal; 18 world cases per game across three maps, three cameras and both orientations; two full cycles of all five battle modes per game; touch/menu/controller input, visible Terrarium camera, real attacks and normal battle completion; injected stage-load failure and rollback; 13 focused regression suites. Package Lua syntax, CRC and per-file SHA256 checked. All original assets byte-identical to 3.0.29.

Previous checks retained: original 3.0.0-rc.15 (RC66g) comparison, all five Johto HD packs downloaded and restored (100 species / 600 PNGs), local HD file import, four native panorama scenes and simulated mobile canvas path.

Limitations: no physical iPhone/Android retest; Silver and optional ROM-based 3D model import not run natively. This is not a claim that every legacy Gen 2 defect or all tester reports are resolved. The separately recorded Gen 1 Terrarium-language / invisible-moves report remains open. No save migration, sprite deletion or new import needed for this update.
