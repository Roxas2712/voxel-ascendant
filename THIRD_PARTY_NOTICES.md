# Third-party notices

## DramaticShapeVoxelMod v1.6.1

- Source tag: `v1.6.1`
- Source commit: `790c34efff4975c91883f7f918a875530706ee12`
- Source project: `DramaticShapeVoxelMod`
- License: MIT
- Original copyright: `Copyright (c) 2026 DramaticShape`

The complete, unchanged MIT text is included in `LICENSE`. Voxel Ascendant
modifies that source under the permission granted by the MIT license.

## Floating Battle HUD

The responsive battle-HUD integration is derived from
[g1rFloatingBattleHUD v0.7.18](https://github.com/bass-dv/g1rFloatingBattleHUD/releases/tag/v0.7.18)
by bass-dv and modified under the MIT License. The complete upstream notice is
included in `LICENSE-FLOATING-BATTLE-HUD`.

## ORAS interface and Pokémon Crystal menu art

The private RC package contains interface elements prepared from the
Pokémon Omega Ruby / Alpha Sapphire battle-interface reference sheet at
https://www.spriters-resource.com/3ds/pokemonomegarubyalphasapphire/asset/67574/
and Pokémon Crystal-derived 16×16 party-menu fallback sheets for Pokédex
#001–251. These game-art assets are not covered by either MIT license. VASC's
package includes the localized Mega button, transformation image and sound only
for private compatibility acceptance. They remain inert unless optional KASC
authorizes the exact active Pokémon through its public service. Exact scope is
recorded in `ASSET_SOURCES.md`; redistribution clearance is still outstanding.

## Pokémon Diamond/Pearl and FireRed/LeafGreen Bag sprites

The private UI candidate includes a transparent 576×128 atlas made from the
sixteen Bag crops in The Spriters Resource asset 6961, **Bag** from Pokémon
Diamond/Pearl, uploaded by Cheese:
https://www.spriters-resource.com/ds_dsi/pokemondiamondpearl/asset/6961/.
The source sheet, trainer figures, header, text and unrelated UI are not
packaged. The retained pixels are copied 1:1 without resampling. At draw time
VASC may recolour only the original red/pink moving pocket accents to red,
blue or green; gold material and outlines remain authored. Exact source and
runtime hashes, crops and slot mapping are recorded in `ASSET_SOURCES.md`.

The separate `FRLG ORAS` candidate contains ten unscaled 64×64 Bag, Berry
Pouch and TM Case crops from The Spriters Resource asset 3865, **Interface &
Bag Screens** for Pokémon FireRed/LeafGreen, uploaded by 2b2n:
https://www.spriters-resource.com/game_boy_advance/pokemonfireredleafgreen/asset/3865/.
The full source sheet is not packaged; exact hashes and crops are recorded in
`ASSET_SOURCES.md` and `FRLG_ORAS_BAG_ASSET.md`.

Both are opt-in VASC drawing styles. `GAME/KASC` is the safe default and keeps
the exact native, Useful Bag or KASC presentation owner. These Pokémon game-art
pixels are not covered by VASC's MIT licenses. They remain private test
candidates; redistribution clearance is outstanding and this package must not
be published as a public release.

## Project-supplied VASC battle animations

The 92 packaged battle-effect sheets and their 230 animation programs were
supplied by the project owner and expressly designated as Voxel Ascendant
assets. `ANIMATION_ASSET_SOURCES.md` records every runtime filename and hash;
the reproducible converter records the complete source-data hash.

## Integrated Gen-1 Fly and Surf species sprites

RC5 integrates the normal/Shiny directional and six-pose world sprites from
VASC Species Fly Cinematic 0.4.3 and VASC Species Surf Cinematic 0.3.1. The
art line credits Followers EX / PokéPC Followers / ShockSlayer, the Pokémon
Crystal Clear team and the individual authors named by those projects; the
locally curated 32px selection also credits Wilds of Kanto. These fan-art
assets are not covered by VASC's MIT software license.

The two directional source trees are byte-identical and are packaged once.
Exact source-package hashes, deduplication scope and runtime paths are recorded
in `docs/SPECIES_CINEMATICS.md`. The complete input notices, credits and
per-file provenance are preserved verbatim below `docs/species_cinematics/`.

## Non-shipped FireRed/LeafGreen visual reference

The Spriters Resource asset 3859, "Area Previews", uploaded by FrenchOrange,
was used only as a visual location/palette reference for newly generated VASC
ARENA paintings. The original 738x1176 sheet and its extracted game pixels are
not packaged. Runtime PNGs, ImageGen source IDs, prompts and hashes are recorded
in `ASSET_SOURCES.md`.

The Spriters Resource asset 3866, "Battle Backgrounds", uploaded by
desgardes, was separately used as a high-level palette and composition
reference for ten newly generated VASC DISCS textures. The original 737x466
sheet and its extracted game pixels are not packaged or copied into any
runtime texture. ImageGen source IDs, prompts, hashes and deterministic builds
are recorded in `ASSET_SOURCES.md`.

## Excluded materials

No Pokemon Stadium ROM or extracted data, OpenXR loader binary, Battle Art
code/assets, Dramaless code/assets, or unrecorded Gen 2 Pokémon sprite pack is
included.
There is no `ForkPermission.jpg` or informal permission artifact; the code
publication basis is the MIT license above and the animation collection is the
project-owned material identified in the preceding section.
