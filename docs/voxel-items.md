# Voxel Items

Default ON, configurable under VASC → Wetter + Kulisse → Voxel Items.

In Gen1, 3D renders solid replicas; 2D retains the original item sprites,
furniture and healing effects even while this setting is ON. OFF restores the
existing 3D rendering too. An authored expansion map can explicitly set
`map.def.voxelItems2D = true` to use the generated 2D projections.

## Visual identities

- Ordinary field pickups use white/yellow storage capsules with a serial label.
- Pokémon objects (Oak, Dojo prizes, static Pokémon) retain real Poké Balls.
- Oak's bases follow the Pokémon's first type; Pikachu is yellow. In NG+,
  the left Hoenn gift follows KASC's current hero, the middle archive is gray,
  and a known rival partner uses its type. Unknown choices remain gray.
- Pokédex, moss/ice evolution objects, elemental stones, Helix/Dome fossils and
  Old Amber have distinct geometry. The shared book sprite is resolved by its
  map object: Daisy has a folded paper town map, Fuji a magazine and the
  Pokémon Mansion its research diaries. Unidentified book objects retain
  native artwork; only Oak's named Pokédex objects become devices.
- Exact Gen1 tile patterns replace TVs, Switch-like consoles, home/Center PCs,
  shop shelves, displays, fridges, registers and the two Center machines.
  Indigo Plateau's matching machine/PC tiles are included. Unrecognised and
  Gen2 furniture stays with its existing renderer.
- The healing machine has six sockets. Its native `healAnim.lit` selects both
  the ball count and the current party member's follower portrait. The last
  portrait stays through the native flash, and clears on completion. The
  existing follower provider supplies the matching variant; missing artwork
  leaves the display empty. HP/status/PP, timing, sound and callbacks remain
  entirely with the engine.

No map collision, event script, object toggle, inventory identity, encounter,
party choice or save layout is changed. Models follow the live entity list;
a collected item disappears through the usual native collection path.

## Interior coverage

- Standard Marts: complete checkout booths, stocked double-sided shelving,
  cold cabinets and displays. Five product families (balls, medicine, stones,
  technology and mixed supplies), each with three stable arrangements and
  full/half-depth versions. Poké/Great/Ultra/Premier-like balls have distinct
  silhouettes and markings. Small shelf gaps vary between arrangements.
- Celadon department store: reception and payphones, all merchandise floors,
  TV displays and playable-console display counters, roof drink machines,
  tables and chairs. Aisles, stairs, lifts and clerks retain native footprints.
- Game Corner: individual machines face their adjacent chairs; prize cabinets
  show actual balls. The rendered bank has six stations per side and end caps.
- Laboratories: microscopes, computer workbenches, research consoles, fossil
  reconstruction bays and equipment storage. Oak's tables keep the native
  six-pixel item support height. The museum has skeletal exhibits, moon and
  shuttle displays, specimen cabinets and new partition/reception sections.
  Its Amber pedestal relies on the live collectible, so collection leaves it empty.
- Bookshelves use wood frames, varied spines, stacked books and lower cupboards.
  Exact artwork masks cover HOUSE, REDS_HOUSE_1, DOJO/GYM, LAB, MANSION, GATE and
  SHIP wherever those native patterns occur, including schools and offices.

## Assets and validation

`lib/VoxelItems.lua` meshes exposed voxel faces, shares one palette texture and
caches geometry. `VoxelItemExtras.lua` and `VoxelFurniture.lua` contain the
original authored models. `VoxelInteriorModels.lua` and `VoxelInteriorPatterns.lua`
add the retail, bookcase, laboratory and museum models/masks. Furniture claims only exact native patterns and
suppresses overlapping old figures. Shadows use the same mesh and position.
`VoxelHealingDisplay.lua` adds the current portrait to the physical screen.

Rebuild the optional expansion projections with LOVE:

```sh
VASC_SOURCE=/path/to/mod love scripts/voxel_items_assets
```

The Lua test runner can execute `tests/voxel_items_test.lua` with `VASC_SOURCE`
set. It checks identities, NG+ colors, default/toggle, native Gen1 2D, expansion
opt-in, OAM cropping, cache/failure fallback, exact furniture patterns, Gen2
exclusion, ball counts, native FX restoration and portrait sequencing.

Native integration was exercised with engine 0.2.59 and KASC 6.7.4 in a disposable
profile: Oak, forest/cave evolution stones, capsule collection, fossils,
Red's room, Mart and Pokémon Center; camera levels 0/4/7. Nurse healing with
1/3/6 party members passed in native 2D and voxel 3D, including HP/status/PP,
ball loading, flashing and completion. Display captures verify Bulbasaur,
Pikachu and Pidgey at their respective party positions.

The interior expansion additionally passed full-room fixtures for 25 native
maps, checking non-overlapping claims, themed stock counts, bookcase coverage,
unchanged tile arrays and native 2D fallback. Native 3D screenshots exercised
23 rooms, including all Celadon floors, the Game Corner/prize room, three
Cinnabar laboratories, both museum floors, Daisy/Fuji, school, gate, ship and
mansion bookcases. The book identities were asserted against live map objects.

The installed build also passed six-party nurse healing in 2D and 3D with
follower portraits, HP/status/PP restoration and the native completion callback.
Installed ON/OFF/2D screenshots verify Daisy's book/map and bookshelf fallbacks.
Amber support is read from the claimed replacement pedestal, shared by item
rendering and shadow rendering, without changing map/entity state.
