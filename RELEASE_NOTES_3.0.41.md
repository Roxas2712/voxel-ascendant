# Voxel Ascendant 3.0.41 — Cobblemon Wild Pokémon Visibility

Full public test update, published as a regular GitHub release so the launcher updater can detect it. Compatible with KASC 6.7.22.

## Fixed since 3.0.40
- Fixed roaming Cobblemon Pokémon becoming almost invisible in Gen-1 tall grass. The Pokémon were still spawning and moving, but grass could incorrectly cover their models.
- Imported overworld Pokémon now use the same camera-depth correction as the surrounding grass and sprite actors.
- Small Cobblemon overworld models now use the existing 12-unit readability minimum instead of a seven-unit minimum beneath eight-unit grass.

Battle model sizing, encounter/spawn rules, fog and Card settings are unchanged. No KASC update is required for this fix.

## Validation
Reproduced on Route 1 with the previous release and checked the correction in the running game with Pidgey and Rattata. Switching from sprites to Cobblemon and back retains the roaming Pokémon and their movement. Regression checks cover grass visibility, ground anchoring, shadows, culling and sprite fallback on model/upload failure. Package integrity and preserving update installation are checked separately.

Tested on macOS with LÖVE 11.5. Physical Android/iPhone confirmation is still pending. This release does not claim to resolve every remaining mobile graphics report. See QA-REPORT.md for details.

## Installation
Close the game, import the complete Voxel-Ascendant-3.0.41.zip through the launcher and restart. Keep existing saves and optional artwork. This is a full update package; no engine, ROM or player save is included.
