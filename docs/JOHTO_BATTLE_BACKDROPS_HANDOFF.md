# Johto battle-backdrop handoff

This is the implementation contract for the Gold/Silver/Crystal location-art
battle backgrounds. `data/arena_scenery.lua` is the executable source of truth;
this document explains the authored assets and the rules that must survive a
merge into the current VASC line.

## Non-negotiable visual rules

- Johto uses unique location art. Kanto (Routes 1-28, its cities, Gyms and
  facilities) may reuse the established Kanto Arena Scenery library.
- The shared Indigo Plateau / Elite Four may reuse its existing backgrounds.
- Every visible sky opening is genuine PNG alpha. The voxel sky must be drawn
  behind that alpha, including on indoor engine maps such as the lighthouse,
  ship, Burned Tower, Slowpoke Well and the windowed Gyms.
- Only real Gyms and the Battle Tower have designed combat floors. Caves,
  towers, ruins, the Radio Tower, underground, Rocket Base, lighthouse, ship
  and shrines use their ordinary local floor without an arena ring/platform.
- Outdoor routes contain recognizable tall grass or reeds around a clear,
  readable combat area.

## Authoritative files

- `data/arena_scenery.lua`: complete map-ID to asset mapping and safe fallbacks.
- `lib/BattleBackdrop.lua`: loading, validation, caching and alpha composition.
- `lib/BattleScene.lua`: voxel-sky support for transparent openings, including
  maps whose engine environment is `INDOOR`.
- `lib/OverworldBattle.lua`: selects location art for Gold/Silver/Crystal fights.
- `assets/battle/arena_johto-*.compact.png`: 69 Johto PNG files, all 1280x800.

## Johto assignments

Routes 29 through 46 map one-to-one to
`arena_johto-route29.compact.png` through
`arena_johto-route46.compact.png`.

Cities and outdoor landmarks:

| Map IDs | Asset suffix |
| --- | --- |
| `NEW_BARK_TOWN` | `new-bark-town` |
| `CHERRYGROVE_CITY` | `cherrygrove-city` |
| `VIOLET_CITY` | `violet-city` |
| `AZALEA_TOWN` | `azalea-town` |
| `GOLDENROD_CITY` | `goldenrod-city` |
| `ECRUTEAK_CITY` | `ecruteak-city` |
| `OLIVINE_CITY`, `OLIVINE_PORT` | `olivine-city` |
| `CIANWOOD_CITY` | `cianwood-city` |
| `MAHOGANY_TOWN` | `mahogany-town` |
| `LAKE_OF_RAGE` | `lake-of-rage` |
| `BLACKTHORN_CITY` | `blackthorn-city` |
| `NATIONAL_PARK*` | `national-park` |
| `ILEX_FOREST` | `ilex-forest` |
| `RUINS_OF_ALPH_OUTSIDE` | `ruins-alph-outside` |
| `SILVER_CAVE_OUTSIDE` | `silver-cave-outside` |
| `BATTLE_TOWER_OUTSIDE` | `battle-tower-outside` |

Gyms and Battle Tower:

| Map IDs | Asset suffix |
| --- | --- |
| `VIOLET_GYM` | `gym-violet-flying` |
| `AZALEA_GYM` | `gym-azalea-bug` |
| `GOLDENROD_GYM` | `gym-goldenrod-normal` |
| `ECRUTEAK_GYM` | `gym-ecruteak-ghost` |
| `CIANWOOD_GYM` | `gym-cianwood-fighting` |
| `OLIVINE_GYM` | `gym-olivine-steel` |
| `MAHOGANY_GYM` | `gym-mahogany-ice` |
| `BLACKTHORN_GYM_*` | `gym-blackthorn-dragon` |
| `BATTLE_TOWER_*` | `battle-tower` |

Battle-capable complexes:

| Map-ID family | Asset suffix |
| --- | --- |
| `SPROUT_TOWER_*` | `sprout-tower` |
| `BURNED_TOWER_*` | `burned-tower` |
| `TIN_TOWER_1F` through `9F`, `WISE_TRIOS_ROOM` | `tin-tower` |
| `TIN_TOWER_ROOF` | `tin-tower-roof` |
| `RUINS_OF_ALPH_*` interiors | `ruins-alph-interior` |
| `UNION_CAVE_*` | `union-cave` |
| `SLOWPOKE_WELL_*` | `slowpoke-well` |
| `GOLDENROD_UNDERGROUND*` | `goldenrod-underground` |
| `RADIO_TOWER_*` | `radio-tower` |
| `DANCE_THEATER` | `dance-theater` |
| `OLIVINE_LIGHTHOUSE_*` | `olivine-lighthouse` |
| `MOUNT_MORTAR_*` | `mount-mortar` |
| `TEAM_ROCKET_BASE_*`, `UNDERGROUND_PATH` | `team-rocket-base` |
| `ICE_PATH_*` | `ice-path` |
| `DRAGONS_DEN_*` | `dragons-den` |
| `DRAGON_SHRINE` | `dragon-shrine` |
| `DARK_CAVE_*` | `dark-cave` |
| `WHIRL_ISLAND_*` except Lugia chamber | `whirl-islands` |
| `WHIRL_ISLAND_LUGIA_CHAMBER` | `lugia-chamber` |
| `TOHJO_FALLS` | `tohjo-falls` |
| `VICTORY_ROAD` | `victory-road` |
| `SILVER_CAVE_ROOM_*`, item rooms | `silver-cave-interior` |
| `FAST_SHIP_*` including cabins | `fast-ship` |

The Elite Four assignments remain compatible with the existing Indigo Plateau
assets. Unique Will/Koga/Karen paintings are also packaged and may remain in
use; Bruno, Lance and Hall of Fame already reuse the established assets.

## Kanto and Indigo Plateau reuse assignments

These are already represented by named asset keys in `data/arena_scenery.lua`:

| Maps | Existing asset key |
| --- | --- |
| Route 1 | `route1` |
| Route 2 | `routeGate` |
| Routes 3-4 | `moonApproach`, `moonExit` |
| Routes 5-9, 12-18 | `grass` |
| Route 10 | `rockWater` |
| Route 11 | `vermilionGate` |
| Routes 19-21 | `coast` |
| Route 22 | `indigoGate` |
| Route 23 | `indigoRoad` |
| Route 24 | `bridge` |
| Route 25 | `cape` |
| Routes 26-28 | `indigoRoad` / `rockWater` |
| Pallet / Viridian | `route1` |
| Pewter | `moonApproach` |
| Cerulean | `bridge` |
| Vermilion | `vermilionGate` |
| Lavender | `rockWater` |
| Celadon / Saffron | `grass` |
| Fuchsia / Safari Zone | `safari` |
| Cinnabar | `coastTown` |
| Eight Kanto Gyms | their existing `*Gym` assets |
| Fighting Dojo | `dojo` |
| Mt. Moon / Diglett's Cave / Rock Tunnel | established cave assets |
| Power Plant / Rocket Hideout / Game Corner / Silph | established facility assets |
| Will / Koga / Karen | packaged Johto-specific rooms may remain |
| Bruno / Lance / Hall of Fame | existing `bruno`, `lance`, `champion` assets |

Do not replace Johto natural interiors with these Kanto families. Their use is
limited to Kanto, Indigo Plateau and safe fallbacks for unknown custom maps.

## Verification gates

- All 69 Johto files must be 1280x800 PNGs.
- Every asset marked `voxelSky` must be RGBA and contain transparent pixels.
- Routes 29-46 must resolve to eighteen different Johto asset keys.
- Natural interiors must never fall back to a Gym asset.
- Gold and Crystal map-ID coverage must keep the complex-prefix rules above.
- `python3 -m unittest tests/test_vasc4j_contract.py` must pass before release.
