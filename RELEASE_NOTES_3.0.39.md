# Voxel Ascendant 3.0.39 — public test release

Complete installable VASC update. This is a public test release, a regular GitHub release for updater compatibility. No ROM, engine or save is included.

## New since rc.2
- Integrates Your Look / Dein Look for Gen1: one-time visual setup per playthrough, resumable drafts, and reopening through F3 and the main VASC menu. When KASC is active its additional world-Pokémon context is included.
- Nine steps cover device presets, character art, independent overworld Pokémon styles, Pokédex, battle art, world scenery, optional graphics checks and final confirmation.
- Existing values remain active until Apply. Keep current settings finishes setup without changing the look. Benchmark previews temporarily change rendering, then restore the original save, world and settings.
- Optional two-minute graphics check uses repeated OFF/ON/ON/OFF comparisons. Targeted retests preserve unrelated results; uncertain evidence keeps the user's choice. Visual review remains necessary.
- English by default; German follows the Universal translation mod's active German boot language.
- Cobblemon is bundled and ready without a separate installation/download. The content menu now consistently explains this.
- Corrects the final Mac/desktop fog-canvas compositing, which previously multiplied already alpha-weighted RGB again. Translucent fog may appear brighter; density, colour, movement and lighting parameters are unchanged.

## Compatibility and validation
The setup is Gen1-only in this candidate. Gen2 keeps its existing hub and controls; its separate scene/battle owners are not used by this setup. All rc.2 mobile, terrain, banner and FLY fixes remain included. Physical Android/iPhone validation remains pending.

The KASC development source also includes an entry that opens the same VASC setup. That entry ships with KASC 6.7.21; existing KASC installations can already reach setup through VASC/F3 with this ZIP.

Detailed checks and limitations are recorded in QA-REPORT.md beside this archive. Existing player saves and the earlier rc.2 archive are unchanged.

This is a complete regular release for the updater. The test-release designation is informational only; there is no GitHub prerelease flag. Recommended pairing: VASC 3.0.39 with KASC 6.7.21.
