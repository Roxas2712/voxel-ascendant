# VASC 3.0.38-rc.1 — shader portability hotfix

Local test candidate based on public 3.0.37; not published.

- Fixed Gen 1 voxel rendering remaining in 2D despite FULL/3RD being selected on strict shader compilers. The shared seasonal-foliage shader used `patch`, which is reserved in GLES and modern GLSL. Renamed it to `foliageVariation`; rendering math, autumn colors and feature settings are unchanged.
- The faulty block was injected into full, mobile-safe and mobile-core variants, including lighting-disabled fallbacks. Changing graphics settings could not avoid it.
- Reproduced the reported iPhone compiler failure with Khronos glslang. Before: 20 of 60 shader stages failed across GLES 3.0 and desktop GLSL 4.50. After: all 60 pass (GLSL 3.30, GLSL 4.50, GLES 3.0; full/mobile-safe with grid on/off, mobile-core without grid; lighting on/off; vertex and fragment stages).
- Added a native production-shader dump driver and strict compiler regression runner. They use LOVE's stage preprocessor; the GLSL 4.50 test raises the desktop version directive explicitly.

The provided iPhone/Metal session log establishes the actual device failure. Local runtime checks use macOS and engine 0.3.2. Compiler validation is not a physical Windows/Android/iPhone retest; confirmation after installing this build remains outstanding.

For maintainers: run `tests/voxel_shader_portability_driver.lua` through POKEPORT_DRIVER in an isolated Gen 1 QA host with SHADER_OUT set to an existing empty directory, then run `python3 tests/validate_voxel_shaders.py <directory> --compiler /path/to/glslang`.
