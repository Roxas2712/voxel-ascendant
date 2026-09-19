# VASC 3.0.31-rc.1 — local mobile-render candidate

Based on public 3.0.30. This candidate has not been published.

- Gen2 now shares Gen1's selectable 1080P / NATIVE / 720P scene resolution, including a live quick-menu row and profile/persistence support. Replaces the hidden 960px mobile cap. Mobile supersampling remains disabled.
- iOS/Android use the existing expanded tree geometry path instead of GPU instancing, matching Gen1's compatibility policy. Increases geometry memory use.
- Higher shader precision for world-space cutaway and battle sight-corridor calculations.
- Gen2 supports independent animated battle fronts from the public companion sprite provider, as Gen1 already does. Provider choice and animation settings remain provider-owned; unavailable providers keep native art. Native 2D rear art and battle state are preserved.
- Clarified the old RES control: it adjusts scenery detail, not framebuffer resolution.

Validation: 14 automated regressions; native Crystal with Android platform policy and Gold desktop runs; world/MAP battle, both shader variants, saved resolution switching, moves menu and portrait rotation. Additional native two-frame animation integration test verifies visible changes on both sides and provider-failure containment.

Limitations: tested on macOS/OpenGL, not physical mobile GPUs. iOS OS-spoofing on this backend reverses the unchanged release's scene and is not a valid visual iPhone test. Physical flicker reproduction and the user's installed animation package remain unverified. Expanded tree geometry and higher resolution can cost additional memory/GPU time; use 720P to reduce pixel load.

Rooftop panorama/weather, checkerboard ground, flickering windows, seated biker art and Safari-zone terrain/exits remain separately recorded open issues.
