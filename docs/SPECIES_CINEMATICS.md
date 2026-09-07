# Integrated species cinematics

Voxel Ascendant 3.0.0 integrates the reviewed standalone sources
`VASC Species Fly Cinematic 0.4.3` and
`VASC Species Surf Cinematic 0.3.1` as Gen-1 owner modules. RC10 additionally
integrates `VASC Species Fishing Cinematic 0.1.0` for both generations. They
are not separate mod entries, loaders or save namespaces. Red, Blue and Yellow
load the Fishing controller from `lib/SpeciesFishingCinematic.lua`; the
Gold/Silver/Crystal renderer loads its isolated counterpart from
`gen2/lib/SpeciesFishingCinematic.lua`.

## Source receipt

| source package | SHA-256 | integrated source version |
| --- | --- | --- |
| `VASC-Species-Fly-Cinematic-0.4.3.zip` | `1e49115da44cb600538e0b88be7046310d5a6ab123b4bdab07375d507b5d7f80` | 0.4.3 |
| `VASC-Species-Surf-Cinematic-0.3.1.zip` | `5bd9914278efa3c9761d3cd86f21e3195bc512b4ddec2f76f0b859637ab1ca9d` | 0.3.1 |
| `VASC-Species-Fishing-Cinematic-0.1.0.zip` | `1dfc5f146148d14d4873c9585b4943e0aa1c5f9686871308a07988ac16040d1a` | 0.1.0 |

All three inputs contain byte-identical sets of 774 normal/Shiny directional
atlases for National-Dex #001-386 plus Gorochu. VASC stores that set once below
`assets/species_cinematics/directional/`. Surf's 774 six-pose world carriers
are rooted at `assets/vasc_runtime/followsprites_runtime/`: 502 files were
already byte-identical to RC4, so the import adds only the missing Hoenn and
Gorochu carriers instead of shipping a duplicate tree.

The exact input provenance, notices and credits are retained verbatim beside
this document:

- `FLY_ASSET_PROVENANCE_0.4.3.md`
- `FLY_THIRD_PARTY_NOTICES_0.4.3.md`
- `FLY_CREDITS_0.4.3.md`
- `SURF_ASSET_PROVENANCE_0.3.1.md`
- `SURF_THIRD_PARTY_NOTICES_0.3.1.md`
- `SURF_CREDITS_0.3.1.md`
- `FISHING_ASSET_PROVENANCE_0.1.0.md`
- `FISHING_THIRD_PARTY_NOTICES_0.1.0.md`
- `FISHING_CREDITS_0.1.0.md`

Those art assets remain subject to the notices in those documents and are not
relicensed by VASC's MIT software license.

## Ownership and fallback

The game remains authoritative for HM/rod permission, badges, party selection,
destinations, movement, collisions, encounter rolls, fishing timers and text,
music, battle creation, warps and save data.
The integrated modules compose only VASC's owned `voxel` update/draw callbacks
and use Kanto Ascendant's documented public `fieldTech` export when available.
They never import a KASC file or private table.

An absent or malformed sprite, failed image decode, failed canvas allocation,
lost/retired voxel pipeline, unsupported species or controller exception
releases only the cinematic's temporary state and input lock. Native SURF or
FLY then continues. A Surf-local draw failure cannot retire the shared voxel
pipeline or disable Fly, and neither module writes the saved VOXEL level.

Fishing observes only the result already selected by the engine. Gen 1 reads
the single return of the outer `encounter.fishing` chain and the real native
TextBox transition. Gen 2 reads the exact Pokémon stored by
`World:beginFishing`, including its generated Shiny state. Rod, line, bobber,
rings, bite splash and pull-out are render-only; no second random call exists.
An artwork or draw failure disables only that cast's overlay while the native
rod, text, timing and battle continue.

RC5 removes VASC's historical SELECT camera hook centrally. SELECT therefore
belongs to the game and, when installed, KASC Quick Select/Field Kit. VASC's
camera ladder remains available through `3`, `V`, the mapped right trigger
(`ZR`/`R2`/`RT`) and the VASC options.

The manifest replaces and conflicts with the retired standalone IDs
`vasc_species_fly_cinematic`, `vasc_species_surf_cinematic` and
`vasc_species_fishing_cinematic`. A runtime guard
also declines the corresponding integrated module if an older launcher still
leaves that standalone companion active, preventing stacked controller and
pipeline wrappers.
