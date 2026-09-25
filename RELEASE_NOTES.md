# VASC 3.0.47 — Public Test Update

Complete installable update based on 3.0.46, published as a regular GitHub Latest release for launcher updates.

## Changes since 3.0.46

- Correct Cobblemon battle proportions using species height and a cached measurement of the animated model. Venusaur now remains visibly larger than Rattata; compact models such as Gorochu no longer gain disproportionate size from their bind pose. Apply species metadata in Gen 2 battles too.
- Keep MAP battle trainers on supported, walkable ground with clearance across their full body width. The final placement search still checks scenery visibility, so a large Pokemon cannot force Red into a fallback seat hidden behind a hedge. Allow limited foreground overlap with the trainer's own Pokemon when necessary.
- Fix dark stippling on Pallet village windows by separating glass from overlapping facade relief and opaque window bars, including side windows, attic panes and the laboratory skylight.
- Preserve existing battle-button position, scale and shape settings.

Includes the Terrariums, Cobblemon pose coverage, menu and download fixes from 3.0.46.

## Validation and limits

89/89 headless suites passed. Native desktop comparison battles cover Venusaur, Rattata and Gorochu in Gen 1, plus Venusaur in Crystal. The hedge placement was reproduced and the corrected trainer position visually inspected. Pallet window checks include native before/after captures and 8,223 glass-versus-opaque geometry pairs. All packaged Lua, ZIP integrity, file receipts, prepared-model hashes and original Terrarium source hashes are checked during packaging.

These are targeted regression checks, not exhaustive visual approval of every species, map or camera. Physical phone/console GPU testing is outside this desktop validation. See QA-REPORT.md and WINDOW_SIZE_TRAINER_AUDIT_2026-09-25.md for details.

## Install

Close the game, update VASC through the launcher or import the complete Voxel-Ascendant-3.0.47.zip, then restart. Keep existing saves and optional artwork. No ROM, engine or player save is included.
