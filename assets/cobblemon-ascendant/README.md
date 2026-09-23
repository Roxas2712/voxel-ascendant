# Ascendant model additions

15 original code-authored cube models fill gaps in the pinned Cobblemon catalog. These are initial stylized Ascendant assets, not official Cobblemon artwork. Each has editable Bedrock geometry, resolver, poser and animation JSON. Palette cells are generated renderer materials; no source artwork is modified.

Idle, walking, battle idle, physical attack, recoil and faint clips are supplied. Missing shiny artwork uses the existing shiny sprite rather than recoloring arbitrarily. Weather-specific Castform shapes and arbitrary addon forms are not included.

Rebuild geometry/material/animation/poser data with `python3 tools/build_cobblemon_ascendant.py --output <directory>`. Resolver mappings and the checksum catalog must be regenerated separately after editing; the installer rejects mismatched assets.

Official model data remains separate and retains its upstream credits/licences. These additions are not represented as upstream assets.
