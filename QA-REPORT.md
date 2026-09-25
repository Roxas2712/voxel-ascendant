# VASC 3.0.48 — QA report

Source fix: aa01d2d64166e419020803a49eba588428a21006, based on public 3.0.47 (34551a3027757da252a6b2f5152db9e252c936a5). Packaging changes version, release documentation and generated receipts only.

- 90/90 headless regression suites passed. Three existing GPU-only suites are excluded from this runner (indoor_mist_composite, local_light_grid, mobile_mist_gpu).
- The new local_sprite_color_test executes both generation-owned importers: visible RGB, grayscale, transparent/partial-alpha pixels, last-pixel detection, shiny/Mega/Dex/rear selection, signature cache, modified/deleted/readded files, rescan, invalid PNG/dimensions, pixel-read failure and older no-pixel-inspection hosts. It fails on 3.0.47 at the reproduced color flag defect.
- Historical local-sprite path/form tests also pass against the corrected importer. Native-retry, timeout-reason, presentation-owner and Gen 2 provider-router regressions are included in the full suite.
- Native macOS / LÖVE 11.5 / Gen1Recomp 0.3.2 / KASC 6.7.25: original colored PNG values verified for every one of 1,056 visible rear-sprite pixels in classic and DISCS views. Captures inspected; both status cards visible; FIGHT opens the move menu and back returns in portrait (540x960).
- Earlier same-task fallback investigation: three real turns each in DISCS and MAP remain 3D with the reference PNGs. An explicit QA render exception transitions the live battle to native 2D with unchanged HP; native menu input continues. This is fault-injection evidence, not reproduction of the reporter's unknown trigger.
- Packaging checks all Lua syntax, every ZIP member/CRC, both generated file receipts, unchanged prepared Cobblemon models/content hashes and the existing original Terrarium source hashes. No runtime files are removed relative to 3.0.47.

Only the confirmed local Pokemon PNG color defect is changed. Physical phone/console GPU behavior and the reporter's exact PNG were not tested. Gen 2 importer logic is regression-tested; no new Gen 2 native screenshot run is claimed. Forced monochrome modes retain their engine behavior. Dimensions and opaque backgrounds are not automatically corrected.
