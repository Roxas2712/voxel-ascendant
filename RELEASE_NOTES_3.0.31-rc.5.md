# VASC 3.0.31-rc.5 — local mobile-render and Safari stone candidate

Based on public 3.0.30. This candidate has not been published.

- Gen2 now shares Gen1's selectable 1080P / NATIVE / 720P scene resolution, including a live quick-menu row and profile/persistence support. Replaces the hidden 960px mobile cap. Mobile supersampling remains disabled.
- iOS/Android use the existing expanded tree geometry path instead of GPU instancing, matching Gen1's compatibility policy. Increases geometry memory use.
- Higher shader precision for world-space cutaway and battle sight-corridor calculations.
- Gen2 supports independent animated battle fronts from the public companion sprite provider, as Gen1 already does. Provider choice and animation settings remain provider-owned; unavailable providers keep native art. Native 2D rear art and battle state are preserved.
- Clarified the old RES control: it adjusts scenery detail, not framebuffer resolution.

Validation: 14 automated regressions; native Crystal with Android platform policy and Gold desktop runs; world/MAP battle, both shader variants, saved resolution switching, moves menu and portrait rotation. Additional native two-frame animation integration test verifies visible changes on both sides and provider-failure containment.

Limitations: tested on macOS/OpenGL, not physical mobile GPUs. iOS OS-spoofing on this backend reverses the unchanged release's scene and is not a valid visual iPhone test. Physical flicker reproduction and the user's installed animation package remain unverified. Expanded tree geometry and higher resolution can cost additional memory/GPU time; use 720P to reduce pixel load.

Safari terrain: replaced the old enlarged hill atlas with stone/gravel and sparse moss. Native blocked hill rims receive irregular stepped rock crowns, baked into the terrain mesh. Small Safari boulders have substantially less moss. Native collision, stairs, height datums and warps remain unchanged. All four Safari maps were rendered before/after; map/collision and structure/height hashes and warp lists match. Geometry guards verify no added rock on walking/warp/stair cells, bounds, cap coverage and deterministic geometry.

Gen1 windows: removed solid frame backing coplanar with independent glass on rear and attic windows. Disjoint panes preserve the mullions. Geometry regression covers 1,628 panes across eleven facade themes, four variants and three roof shapes; old source fails and corrected source passes. Native day/night screenshots at three camera angles show clear panes. The physical device's exact flicker was not reproduced on macOS.

Gen1 paving: both exact native checker motifs (blocks 122 and 123) become continuous paving. Native pier decks/banks use wood; Route 20 stone landings retain their treatment. Fuchsia and Routes 10/12/20 rendered before/after with unchanged native map/collision and structure/height hashes and warp lists. Negative regression tests preserve edited blocks, normal lawn, water, encounter grass, disabled scenery and Gen2.

Fuchsia fossil pool: render-only live Amonitas/Omanyte after choosing the Dome Fossil, or Kabuto after the Helix Fossil, matching the native sign. Movement stays inside an actual water rectangle with a body margin. Imported models use the existing Stadium renderer; absent models retain a species-specific native front, never the fossil prop. The aquarium remains immersed even if general swimming presentation is disabled. Native entities, interaction, flags and collision are unchanged. Tests cover 3,003 water-boundary samples, concave pools, selection, identity exclusions, stable render proxies and untouched native objects. Native Yellow runs verify visible swimming with and without an imported compatible DSM7/rev3 pack. Fuchsia Kangaskhan and the other zoo species resolve correctly with that pack; their native graphics in the empty QA identity were a missing-model fallback. No new ROM-import or physical-mobile test is claimed.

Safari paths and exits: exact paired native ground flecks now share the surrounding earth/gravel material. Direction-mark floor art is replaced only on real map warps. Thirteen open timber frames label the destinations of the original Safari boundary transitions. Frames follow the whole native opening; all posts remain on blocked shoulders and the walking space stays clear. English by default, German with the existing translation-language policy. Native maps, collision, triggers and destinations remain unchanged. Regression tests cover four orientations, widened openings, language, settings, custom/Gen2 exclusions and ground/water/grass guards.

Rooftop panorama/weather and seated biker art remain separately recorded open issues.
