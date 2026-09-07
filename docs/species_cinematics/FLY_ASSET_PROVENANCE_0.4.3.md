# Asset provenance

The cinematic sprite catalog contains 774 PNG files representing 387 species
identities: National-Dex #001-#386 plus Kanto Ascendant's Gorochu, each in a
normal and shiny variant.

## National-Dex #001-#386

- Source catalog: Kanto Ascendant 6.7.1 Fire Red Bag Hotfix vendor snapshot,
  `vendor/wilds_1_12_2/assets/enhanced_overworld/followsprites/`
- Authoritative selection map:
  `vendor/wilds_1_12_2/assets/enhanced_overworld/followsprites_mapping/followsprites_mapping.json`
- Mapping SHA-256:
  `226cba57ebfee3e8b769a7afb5a7b29396bf7868afb71df0c851e1511cc5a142`
- Import rule: use each species entry's mapped `normal.path` and `shiny.path`,
  including the preferred `m` sheets where selected by the mapping.
- Verification: all 772 packaged files are byte-identical to their mapped
  sources.

Most mapped sheets are 128x128 directional 4x4 atlases. The original authored
sizes are preserved for Steelix (144x144), Wailord (164x164), and Lugia, Ho-Oh,
Kyogre, Groudon and Rayquaza (256x256).

## Gorochu

- Normal source: Kanto Ascendant 6.7.1 Fire Red Bag Hotfix,
  `assets/followers_runtime/normal/follower_GOROCHU.png`
- Normal SHA-256:
  `13bbbf9392ba8defd0225ad88dc84cf52ac9c7d648c5d72f54b3bf0337a95cc3`
- Shiny source:
  `assets/followers_runtime/shiny/follower_GOROCHU.png`
- Shiny SHA-256:
  `a6ef9daac168cc19a588af59631968a495b50861f38c7413daa1ecae57629e49`
- Verification: both packaged 16x96 six-pose sheets are byte-identical to
  those runtime sources.

See `CREDITS.md` and `THIRD_PARTY_NOTICES.md` for attribution, fan-work status
and licensing limitations. No sprite in this package was generated from the
conversation reference images.
