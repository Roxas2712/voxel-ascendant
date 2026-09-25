# VASC 3.0.48 — Local Pokemon PNG colors

Complete installable update based on 3.0.47, published as a regular GitHub Latest release for launcher updates.

## Changes since 3.0.47

- Fix colored local Pokemon PNGs appearing white or incorrectly recolored. USER SPRITES now identifies visible color in the selected file and preserves it in game modes that support full-color art.
- Keep the game palette for grayscale PNGs, including grayscale replacements of full-color providers. Invisible RGB values in transparent padding do not affect the classification.
- Apply the correction to both generation importers, including Pokemon front/back, Dex and overworld image selection. Cache the result with image validation; changed files or RESCAN PNG FILES refresh it.
- Preserve fallback to the existing Game/KASC provider when a local file is absent, invalid or removed. PNG dimensions, alpha and the source files themselves are unchanged.

Includes all content and fixes from 3.0.47. No settings migration is required.

## Validation and known limit

90/90 headless suites passed. The new regression fails on the released importer and passes on the corrected Gen 1 and Gen 2 modules. Native Gen 1 tests with engine 0.3.2 and KASC 6.7.25 verify all 1,056 visible rear-sprite pixels against the source in classic and DISCS views; portrait HUD and FIGHT / back navigation also pass.

The reported automatic 3D-to-2D fallback is a separate investigation. Three real turns each in DISCS and MAP did not trigger it with the reference PNGs. A deliberately injected renderer error confirmed that native 2D and the native HUD take over while the battle continues. This release fixes the reproduced PNG color error; it does not claim to fix the original report's unconfirmed fallback trigger. The reporter's exact PNG and device log were unavailable. No physical phone/console retest is claimed.

All packaged Lua syntax, ZIP integrity and file receipts are checked. See QA-REPORT.md for scope.

## Install

Close the game, update VASC through the launcher or import the complete Voxel-Ascendant-3.0.48.zip, then restart. Preserve existing saves and custom/optional artwork. Use RESCAN PNG FILES after replacing an image whose size and timestamp did not change. No ROM, engine, player save or downloaded QA reference sprite is included.
