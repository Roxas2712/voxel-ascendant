# Cobblemon graphics

The Gen-1 VASC BASE setup includes the optional Cobblemon graphics download. The COBBLEMON page can resume/repair it separately. Choose COBBLEMON in battle/F3 or follower source settings after installation. Existing saved selections stay unchanged. Unsupported colour variants/forms retain their available sprites.

The regular KASC runtime roster covers 481 identities: 463 species/form slots plus 18 Alola identities, including all Hoenn species and Gorochu. Gift-code-only backend entries are excluded. Private KASC dex slots map to canonical model IDs, so Ambipom cannot become Poochyena; Zygarde 10% cannot become the gift-only 50% form.

448 base slots use official Cobblemon 1.8.1 assets pinned to commit `0bc5bb5caaca5622c9f1856cadd866ad85d21287` (https://gitlab.com/cable-mc/cobblemon). The approximately 43 MiB download includes per-asset upstream licence/credit files. Verified blobs are reused across upgrades; the full catalog hash invalidates outdated completion receipts. Installation activates atomically. Cancellation preserves verified blobs.

15 missing slots use original Ascendant cube models: Castform, Celebi, Darkrai, Deoxys, Entei, Genesect, Gorochu, Groudon, Gulpin, Jirachi, Kyogre, Raikou, Suicune, Swalot and Zygarde 10%. These are an initial, simpler visual set, with idle/walk/attack/recoil/faint animation. Editable assets and an offline Python authoring tool are included. Their shiny artwork is not supplied; shiny specimens retain existing sprites.

Geometry, resolver/poser data and Bedrock animation JSON are interpreted as data. Java/Kotlin code is never loaded. Supported: skeletal cubes, static texture layers, keyframes and bounded time/arithmetic Molang. Arbitrary procedural queries, look/quirks, animated/emissive materials and full Kotlin poser logic are not emulated. Existing valid clips are retained; missing basic actions receive bounded Ascendant-authored motion. This is not a general external add-on loader. See the [official model guide](https://wiki.cobblemon.com/index.php/Tutorials/Creating_A_Model).

Sizes use opaque Crystal front bounds for dex 1–251 and existing Gen-2-style battle front bounds for later species, normalized to a 56-pixel canvas. Height and maximum horizontal/depth extent share one scale, preserving proportions. Calibration is offline and bind-pose based; no GPU readback or sprite decoding occurs during gameplay. 15 later species without a verified size reference keep the conservative 40-pixel default. The follower keeps a legibility floor.

Validation: all 463 normal models and 1,894 requested variants compile; native Gen-1 MAP battle and representative follower adapters pass. Automated compilation does not establish visual parity for every pose. Physical mobile gameplay and Gen-2 integration remain unverified.
