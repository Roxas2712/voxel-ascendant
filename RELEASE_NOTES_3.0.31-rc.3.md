# VASC 3.0.31-rc.3 — local mobile-render and Safari stone candidate

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

Rooftop panorama/weather, seated biker art and Safari-zone flat tile remnants/exits remain separately recorded open issues.
