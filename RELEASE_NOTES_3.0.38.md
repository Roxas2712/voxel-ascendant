# VASC 3.0.38 — Voxel activation hotfix

Public test release. Recommended pairing: KASC 6.7.20. Changes since 3.0.37:

- Fixed voxel rendering remaining in 2D even when FULL or 3RD was selected on strict shader compilers. The shared seasonal-foliage shader used `patch`, a reserved GLSL identifier. It is now named `foliageVariation`; rendering math, autumn colors and saved feature settings are unchanged.
- The defective shader block affected full, mobile-safe and mobile-core variants, including lighting-disabled fallbacks. Changing graphics settings could not work around it.
- Added a production-shader dump driver and strict compiler regression checks to catch this portability failure before future releases.

## Validation

The supplied iPhone/Metal session log identifies the reserved-word compiler error as the actual device failure. The compiler failure was reproduced locally with Khronos glslang: before the fix, 20 of 60 shader stages failed across GLES 3.0 and desktop GLSL 4.50; after the fix, all 60 pass across GLSL 3.30, GLSL 4.50 and GLES 3.0. Coverage includes the supported full/mobile-safe/mobile-core variants, grid settings and lighting on/off, for vertex and fragment stages.

Native macOS checks on engine 0.3.2 also passed OFF-to-3RD switching and indoor/outdoor rendering. These compiler and macOS checks are not a physical Windows, Android or iPhone retest; confirmation on affected devices is still needed. This hotfix targets the shader activation failure, not a general FPS increase.

## Install

Close the game, update the existing mod and restart. Select your preferred voxel view as usual. Preserve saves and optional artwork. The ZIP contains the complete mod; the optional Preserve-Installed-Sprites desktop installer backs up the existing installation and retains omitted optional files. Both downloads include SHA-256 checksums.
