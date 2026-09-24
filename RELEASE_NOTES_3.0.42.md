# VASC 3.0.42 — Wild Pokémon sizing and menu organization

Full public test update, published as a regular release for launcher updater compatibility.

## Changes since 3.0.41
- Cobblemon wild Pokémon now follow the existing Wilds overworld walking-sprite size profiles. Removed the blanket minimum that made small species such as Rattata oversized.
- Sizing accounts for idle/walking poses and body, tail and wing extent, preserving proportions and a stable scale while moving. Measurements are cached per model.
- Small Cobblemon Pokémon gently part nearby tall grass so they remain visible at the corrected size. The existing camera-depth visibility correction is retained.
- Reorganized the Voxel Ascendant menu: world controls, Pokémon/models and Wilds/followers come first; battle options stay together. Your Look sits beside Wardrobe and Skins. Errors and Diagnostics are near the bottom; factory reset stays last. Shared Gen-2 menu ordering follows the same priorities.

## Validation
Compared ten species against genuine Wilds walking sprites in the running game: Rattata, Pidgey, Caterpie, Weedle, Pikachu, Eevee, Growlithe, Snorlax, Onix and Charizard. Checked animation/facing changes, natural Route 1 roaming, sprite/Cobblemon switching, menu navigation and error-report access. Desktop and both mobile shader paths compile under desktop LÖVE. Package integrity, receipts and preserving installation checked; see QA-REPORT.md.

Tested on macOS / LÖVE 11.5. Physical Android/iPhone verification remains pending. This is a test release and does not claim to fix all outstanding mobile rendering issues.

## Installation
Close the game, install the complete Voxel-Ascendant-3.0.42.zip through the launcher and restart. Existing saves and optional artwork are retained. No engine, ROM or player save is included. KASC 6.7.24 provides the corresponding Ascendant menu organization.
