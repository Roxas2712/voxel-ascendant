# VASC 3.0.45 — Public Test Update

Complete installable update. Published as a regular GitHub Latest release so the launcher can update it; test status is documented here. Recommended pairing: KASC 6.7.25.

## Changes since 3.0.44
- Fixed the Terrarium glass shader using `patch`, an identifier rejected by strict GLES compilers. Audited VASC, KASC and the local engine for further shader uses of that identifier; no additional offending shader declaration was found.
- Fixed mismatching vertex/pixel precision in the Terrarium atmosphere shader. Existing effect formulas and visual settings are preserved.
- Made optional glass-dome creation atomic. Partial GPU resources are released, a failed dome is not recompiled every frame, and its error is recorded without taking down the battle scene.
- Battle render timeouts now retain the last concrete camera/asset decline reason. Scene errors include requested/actual presentation, phase, battle ID and location.
- Expanded Errors reports with detailed error text (up to 4096 characters), frozen incident-time diagnostics, first/last occurrence, engine/game/mod versions, saved settings, named provider/checkpoint/placement details, and up to three nearby earlier incidents. Nearby incidents are explicitly not treated as proven causes. Graphics-check and gameplay incidents remain separate.
- Added a hardware/resource block near the top of reports: GPU/vendor/renderer, logical processor count, Lua architecture, Lua heap, texture allocation, frame times, resolution and graphics counters where available. Exact CPU/device identity and total/free/system-used/process RAM are explicitly marked unavailable when the engine does not expose them. Lua and texture memory are not mislabeled as total RAM or VRAM.
- Long reports paginate above touch controls and repeat their incident/session identifiers. Full text can be copied on compatible hosts; blocked clipboard access is reported honestly. Reports are session-only, bounded, redacted and never sent automatically.
- AUTO battle buttons now follow their final dock position in Gen1 and Gen2: edge-cut at the bottom of the viewport, complete when raised above it, including touch-control clearance. Raised AUTO buttons keep the compact height budget. Explicit Original, Complete and Glass choices remain intentional settings. Your Look preview/help follows the same policy.
- Added seasonal cherry blossoms to an irregular, deterministic subset of round outdoor trees. Pink/white foliage and bounded falling petals fade with spring; conifers stay evergreen. Generated voxel skylines follow the same selection. Existing painted panoramas and pre-baked rooftop captures are unchanged.

## Included from earlier updates
The complete archive retains the public 3.0.44 baseline, including the iOS grass draw-order correction, optional-light failure recovery, battle-view switching diagnostics, setup choices, Cobblemon Wilds visibility/sizing, menu ordering and Legacy Bank navigation fix. This is one full update, not a patch ZIP.

## Validation and remaining reports
All packaged Lua is syntax-checked; archive CRC and every embedded file receipt are checked. Local native game checks exercise the packaged update, not only loose source files. Strict GL/GLES shader compile/link checks, error-report pagination and privacy/failure-isolation tests, and battle-control/blossom regressions pass. See QA-REPORT.md for the exact final package results.

Local Android/iOS policies on a Mac are not physical phone GPU tests. The reported Route-2 scene-render-timeout was not reproduced and is not claimed fixed; its diagnostic reason is now more specific. Xiaomi performance, reported ARENA freezes and remaining visual-only phone defects still require device feedback. Logs remain useful for long timing sequences, crashes and visual defects that do not raise errors.

## Install and report
Close the game, import the complete Voxel-Ascendant-3.0.45.zip through the launcher updater and restart. Keep existing saves and optional artwork. For a failure, send every page of its Errors report and a gameplay screenshot where relevant. No ROM, engine or player save is included.
