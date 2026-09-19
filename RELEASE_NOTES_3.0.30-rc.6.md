# Voxel Ascendant 3.0.30-rc.6 — Gen2 building load optimization

Local candidate, not published. Includes the complete combined RC5, with one runtime change: the Gen1 analytical building-shell algorithm is ported to Gen2. Instead of repeatedly scanning every hidden interior voxel, the builder indexes exposed faces from exact occupancy intervals. Gen2 materials, nested quad format, merging order, full shell diagnostics, furniture fallback, collision and per-frame time budgets are preserved. There is no rendering-quality reduction or new persistent-cache format.

## Measured change

On Apple M2 / macOS / LÖVE 11.5 / engine 0.2.61, eight fresh-process runs each for RC5 and this candidate (Gold/Crystal, desktop/portrait, two repetitions):

- Goldenrod City first entry: 14.33–14.73 s -> 2.48–2.55 s (about 83% lower median).
- New Bark Town first entry: 1.77–1.87 s -> 0.55–0.62 s (about 67% lower median).
- Route 29 first entry: 0.40–0.68 s -> 0.35–0.42 s; this route can already benefit from neighbor prefetch.
- Repeat visits remain broadly unchanged; Goldenrod is 1.27–1.40 s.

These are timings until the first valid 3D frame after a direct map change, with already imported data and existing asset caches. No cold OS file-cache claim and no physical iPhone/Android timing claim. Dedicated location-specific Johto panorama artwork is still outstanding; existing forest/mountain/sea backdrops remain intact.

## Validation

64 real building models across Johto, Kanto and interiors compared against RC5: exact quad order, coordinates, UVs, shading, occupied voxel and shell counts. Additional regression compares 24 analytical/dense model cases with cooperative yields. All 13 existing Gen2 parity suites pass again. Eight native benchmark runs complete without renderer failures. Before/after native screenshots are included in the comparison report. All RC5 package files outside this change and release metadata are preserved byte-for-byte; Lua compilation, ZIP CRC and both hash receipts verified.

