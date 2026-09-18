# Voxel Ascendant 3.0.29 — Readable, bounded battle Pokémon sizes

Changes since 3.0.28:

- **Small Pokémon stay visible:** a smooth size curve uses Pokédex/form height without mapping metres directly to screen pixels. Pikachu's reference extent is about 80% of Manectric's; Wailord stays below twice Pikachu's. Camera perspective and animation poses still affect apparent screen size.
- **Large Pokémon are gently capped:** giants remain visibly larger without dominating the battlefield.
- **Stable animations:** full-animation visible bounds supplied by KASC 6.7.14 keep scale constant between frames and ignore transparent card borders. Unknown/custom artwork uses a fixed measured fallback per model.
- Trainer sizing, existing camera fit and 1X/3X zoom, manual layout adjustments and classic 2D geometry are retained. No save migration is required.
- Includes all 3.0.28 sprite-maintenance, compact artwork, quick-menu and MAP-camera improvements.

## Updating

Use **KASC 6.7.14 together with VASC 3.0.29** for the complete battle-size update. Update both mods and fully restart the game. Existing saves remain compatible. Keep downloaded/imported sprite content; do not delete the existing mod folders first. The ZIP is the normal mod package. For manual desktop updates, the optional **Preserve-Installed-Sprites** installer creates a backup and preserves optional downloads; follow its included instructions.

## Validation

The reviewed release-candidate runtime is unchanged. Tests covered 1,351 canonical height/form entries, 78,779 PNG records in 6,153 animation/palette groups, 382 animated variants / 3,921 frames and 424 static variants. Native macOS tests included Pikachu versus Manectric and Wailord, Crystal mode, Mega Manectric and Gorochu, plus 1X/3X MAP camera checks. All packaged Lua files, archive integrity and installer preservation checks passed. Fifteen additional gameplay regression tests passed.

Not every form has been manually played. Physical mobile-device and live cloud-sync verification remain pending.
