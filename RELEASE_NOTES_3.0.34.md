# Voxel Ascendant 3.0.34

Omega Dias terrariums, volcanic scenery and animated world encounters. Includes all fixes and optional Gen1/Gen2 lighting from 3.0.33.

- **15 terrariums by Omega Dias / ΩDIAS:** all eight Kanto gyms, the Elite Four, Champion, Pokémon Tower and Rocket Hideout. Creator signatures retained. The Tower ghost symbol is removed from the arena decoration.
- **Terrarium atmosphere:** drifting mist in Fuchsia Gym and Pokémon Tower, smoke in Cinnabar Gym, plus optional stage lighting. Mobile uses two lights; desktop uses three. Stage lightmaps are cached, and ball rocking remains available.
- **Battle orientation:** choose Side-on or Behind Trainer through V / F3 → Terrarium. The choice is saved; trainer facing and attack effects follow the selected battle axis. Gen1, Crystal and Gold support the setting. The withdrawn experimental Johto designs are not included.
- **Moltres volcano:** irregular basalt crater rim and floor, voxel boulders, glowing rock, ash, sparks and procedural smoke/red haze. Native passages, encounter gates and collision remain authoritative.
- **KASC locations:** themed rock formations, cave atmosphere and lighting along supported legendary paths; Rayquaza's open sky platform; Deoxys' ocean island with shoreline, pier and moving puzzle triangle; Driftglass research structure and voxel prism; voxel vegetation/rocks in the supported starter habitats.
- **World encounters:** enlarged Groudon, Kyogre and Rayquaza; appropriately sized legendary pixel-art idle cards, including an upright Mewtwo at its original encounter position. With KASC 6.7.17, bundled authored animations cover 22 species. Existing directional sprites and selected available HD/Stadium sources retain priority. HD content still uses the existing optional download/import system.
- **Rooftop fix:** the department-store rooftop seats are restored so the seated NPC is supported.
- **Compatibility:** native 2D sprites, story interactions and original encounter positions remain intact. Animation updates are bounded and shared across render passes; animation OFF freezes the authored fallback pose.

## Update

Install **Voxel-Ascendant-3.0.34.zip**. For the new KASC world encounter assets and Hoenn puzzle fixes, also update to **Kanto Ascendant 6.7.17**. The optional preserving installer creates a backup and retains omitted downloaded sprites/settings. Do not delete saves or optional HD downloads.

## Validation

Focused geometry, visibility, lighting, animation ownership and battle tests passed. Native LÖVE checks cover the terrariums, Gen1/Gold/Crystal orientation, legendary encounters, selected passages/return warps and the Deoxys puzzle. Portrait/mobile rendering budgets were exercised on macOS; physical phone FPS were not measured. Further decorative work on individual rooms and paths remains planned.
