# Gen1 Dynamic Lighting Card

Integrated from `codex/vasc-gen1-local-lighting-20260919`, commit `8b4ff216` (preview 5), into the current VASC development branch. Public 3.0.32 is not changed by this integration.

Card: `vasc.gen1.dynamic-lighting`, version 1.0.0, capability `ascendant.gen1.dynamic-lighting/v1`. The independent registry activates only with generation 1. The dispatcher generation also gates the lighting service. No battle hooks, map mutation, save writes or gameplay RNG are owned by the Card. Existing option persistence remains with ModSetting.

`mod.exports.dynamicLighting.status()` exposes live ownership, profile, switches, budgets and an optional renderer error. `setActive(false)` retires lighting and releases its visibility atlas, shaders, masks and particles; reactivation restores the service. World and battle switches are independent: Buildings → Dynamic Lighting; Battle → Battle Lighting. Both default ON. Touch and controller use the existing menu selection flow.

| Budget | Desktop | iOS / Android |
|---|---:|---:|
| World sources | 8 | 4 |
| MAP battle sources | 4 | 2 |
| Window projections | 4 | 2 |
| Occluding building boxes | 8 | 4 |
| Visibility atlas | 384 × 256 RGBA | 192 × 256 RGBA |
| Decorative particles | 48 | 24 |

Includes sun/moon and canopy light, interior windows and lamps, torch/candle light, sparse cave crystals, fireflies and sparks, sprite/card lighting and water glints on supported water paths. MAP uses only retained combat furniture; ARENA lights its actors and platforms. DISCS and Terrarium remain neutral. Native FLASH restrictions persist.

The 3D world does not require HD actors or replacement cities for lighting. `NativeWindowLights` derives emitters from the original building stamps and existing glass mask, caching shared templates. It handles compact and regular geometry, neighbor translations and door-anchored elevation. Claimed/replaced native buildings are absent from those stamps and therefore cannot leave duplicate lights. These emitters share the normal source/blocker limits. Native terrain and original sprite billboards already consume the world shader. The classic 2D renderer is outside this Card's scope. Native Pallet/Viridian runs with replacement buildings, voxel items and HD walking sprites disabled verify sources, shader health and OFF/ON behavior.

Atmosphere preservation: the light switch leaves Pokémon Tower mist at density 0.018 / height 42 and Viridian Forest at 0.009 / 44, including their original mist colors. Location-specific mist takes precedence over generic interior haze. Both desktop modes integrate twelve density samples at half resolution with identical alpha blending; the illuminated mode evaluates irradiance six times and caps its color contribution without changing opacity. The phone air-layer path is unchanged. `indoor_mist_lighting_test.lua` compares actual GPU alpha for both maps with lighting OFF/ON, including strong scattering; native Gen1 map runs also verify the profiles and render settings in both modes.

Mobile core uses a derivative-free approximate surface normal. It retains the existing inexpensive internal depth path; the desktop volumetric depth pass and additional HD-card shadow map are not enabled on phones. The inherited mobile water/reflection settings remain authoritative. Mobile shader rejection retries the original core shader, while HD-card rejection retries the original sprite shader; failure disables the optional lighting service for the session, with diagnostics available through the Card status. No repeated compilation per frame. A failed visibility render restores the graphics state before falling back.

Validation: nine focused suites cover actual Card-registry activation/deactivation, Gen2 rejection, GPU lighting/occlusion, indoor apertures, battle scope, particles/crystals, mobile budget math, shader rejection and canvas restoration. Native Gen1 scenes and all world/water shader variants are checked on macOS. Native runs with mobile lighting budgets preserve the real host OS; these are not physical iPhone/Android GPU tests. Those devices still require a smoke test for driver compatibility and sustained frame times.

Gen2 now has a separate production adapter; see `GEN2_DYNAMIC_LIGHTING.md`. The Gen1 Card activation gate remains generation-specific. Native Gen1 regression also switches from original buildings/original sprites to replacement buildings/HD sprites and checks OFF in both modes.
