# Gen2 dynamic lighting

Production source integration, local development only; public 3.0.32 is unchanged.

`gen2/lib/LocalLights.lua` owns generation-specific source discovery and uses the explicitly allowlisted Gen1 GPU core and visibility cache. The Gen1 Card still rejects a Gen2 host unless that adapter explicitly opts into generation 2. The Gen2 voxel-world Card owns the added files; the frozen 217-file A21 baseline is unchanged.

`localLights` is a persisted boolean, default ON. It appears in the normal menu and Camera & World quick menu, and in the quick menu during live MAP battles. OFF uses the original world shader, clears light state and reads the same saved value regardless of which menu wrote it. Shader compilation or visibility failures retain the existing 3D renderer; explicit OFF/ON or renderer reset can recover. Grid capability failure is isolated from lighting.

Native Buildings stamps store only compact pane positions and bounds in `lightBuildingStamps`, not a reference to the expensive construction quads. These receipts survive `Structures.releaseAux`. Lighting reads completed cache records only; it never calls the synchronous geometry builder from rendering. The regular grass/figure build also produces these records after a persistent terrain-cache hit. Map mutations/evictions clear the owner records. Atlas overlap is necessary for native Johto facades whose UV midpoint lies on a window mullion; horizontal roof faces remain excluded.

World surfaces and original/HD actors receive sun/moon and local window light. Maximum sources/blockers: desktop 8/8; mobile 4/4. Phones use derivative-free world normals and omit additional card shadow sampling. The shared visibility volume is cached between unchanged scenes. No new render-resolution reduction, fog-density change, or weather change is introduced. Gen1-specific interior lamps, cave torches and arena lighting are not blindly applied to native Johto maps. Portable arenas and Terrarium lack the explicit world-light context and cannot inherit stale map lights.

Tests: `gen2_local_lights_test.lua`, `gen2_lighting_fallback_test.lua`, `native_window_lights_test.lua`, `gen2_bootstrap_ownership_regression_test.lua`; nine existing Gen1 lighting suites also pass. `gen2_dynamic_light_native_driver.lua` tests actual Gold/Crystal rendering in Goldenrod, New Bark and Ecruteak, day/night, saved OFF/ON, interior transition, HD shader use, reduced mobile budgets, reset and fallback. It records 240-frame timings after 90 warmup frames. The mobile budget run preserves the actual host OS and is not a physical phone test.

Native results on macOS at 1100x700, night, stationary camera, VSync disabled for measurement: Goldenrod Gold desktop 111.3 OFF / 107.1 ON FPS; reduced phone budget 120.0 / 117.0. Crystal desktop 111.1 / 108.2; reduced phone budget 119.0 / 117.6. Worst observed 95th-percentile frame was 17.82 ms (Gold desktop ON). Short samples fluctuate; no claim of locked 60 FPS on all devices. Actual iOS/Android driver, movement and thermal testing remains necessary.

Evidence and complete table: `deliverables/VASC-Dynamisches-Licht-Gen1-Gen2-20260919/` in the parent workspace. Private native logs live in `.codex-private/vasc-gen2-lighting-production-20260919/`.
