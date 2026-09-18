# Voxel Ascendant 3.0.29-rc.1 — readable battle sizes

Based on public 3.0.28, paired with KASC 6.7.14-rc.4.

The visible animation envelope is normalized to 50 presentation units at 1m, with the smooth bounded curve 0.72 + 0.84*h/(h+2), h in metres. Pikachu's reference extent is 43, Manectric's 54 and Wailord's 72.91: approximately 80% / 135% of Manectric. Transparent borders and frame changes do not rescale the Pokemon. Unknown artwork freezes a full-source reference per model; incomplete send-out canvases never calibrate a model.

Trainer sizing, existing camera fit/zoom, user layout corrections and classic 2D rendering are retained. Room composition still has its existing upper scale limit. No save migration or network requests. Local test candidate; no physical mobile-device test.
