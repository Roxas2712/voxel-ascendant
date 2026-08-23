# KASC 6.7 / VASC: `CINNABAR_VOLCANO` integration contract

Status: the additive VASC 2.0.1 panorama lane, compact art and headless
fallback tests are implemented. KASC map/story ownership remains a handoff;
no KASC file is changed by this document and no native application run is
required.

The shipped VASC verifier intentionally accepts KASC-owned positive map
dimensions/tilesets only when all four maps are outdoor and the exact
south/north plus west/east target identities and reciprocal integer offsets
are complete. Once KASC freezes its final dimensions, those values can be
pinned more narrowly without changing the atlas or runtime placement.

## 1. Current verified baseline

The KASC sources currently visible to VASC do not yet define a map named
`CINNABAR_VOLCANO`. VASC must therefore not guess its dimensions, tileset,
connection offset, collision gate, or approach-map identity.

The existing Cinnabar signature used by VASC is:

```text
id/def.id: CINNABAR_ISLAND
tileset:   OVERWORLD
width:     10 blocks
height:    9 blocks
connections:
  north -> ROUTE_21, offset 0
  east  -> ROUTE_20, offset 0
```

Every currently free Cinnabar edge is rendered as open water. The established
coastal treatment also owns one small west-edge town motif. Cinnabar's visual
quay is deliberately guarded by the exact signature above. Adding a south or
west connection without adding a second verified signature would fail safely,
but would also remove that quay treatment. The VASC implementation therefore
needs the final KASC topology before it is enabled.

## 2. Exact data KASC must hand to VASC

The agreed topology has one new southern Cinnabar exit. It enters a short
outdoor swimming channel and only then forks: west/left to the volcano and
east/right to the Deoxys coast. The recommended stable channel ID is
`CINNABAR_SOUTH_CHANNEL`; the existing Hoenn acquisition contract already
names Deoxys's destination `KA_HOENN_BIRTH_ISLAND`.

The KASC implementation must provide the final values below. Values marked
`TBD_BY_KASC` are not safe to infer from story text or screenshots.

```lua
local CINNABAR_VOLCANO_67 = {
  volcano = {
    id = "CINNABAR_VOLCANO",
    defId = "CINNABAR_VOLCANO",
    width = TBD_BY_KASC,
    height = TBD_BY_KASC,
    tileset = TBD_BY_KASC,
    outdoor = true,
    connections = {
      -- Complete exact table, including every direction, map and offset.
    },
  },
  birthIsland = {
    id = "KA_HOENN_BIRTH_ISLAND",
    defId = "KA_HOENN_BIRTH_ISLAND",
    width = TBD_BY_KASC,
    height = TBD_BY_KASC,
    tileset = TBD_BY_KASC,
    outdoor = true,
    connections = {
      -- Complete exact table, including the channel reciprocal.
    },
  },
  cinnabar = {
    id = "CINNABAR_ISLAND",
    width = 10,
    height = 9,
    tileset = "OVERWORLD",
    connections = {
      north = { map = "ROUTE_21", offset = 0 },
      east = { map = "ROUTE_20", offset = 0 },
      south = { map = "CINNABAR_SOUTH_CHANNEL", offset = TBD_BY_KASC },
    },
  },
  approach = {
    id = "CINNABAR_SOUTH_CHANNEL",
    defId = "CINNABAR_SOUTH_CHANNEL",
    width = TBD_BY_KASC,
    height = TBD_BY_KASC,
    tileset = TBD_BY_KASC,
    outdoor = true,
    connections = {
      north = { map = "CINNABAR_ISLAND", offset = TBD_BY_KASC },
      west = { map = "CINNABAR_VOLCANO", offset = TBD_BY_KASC },
      east = { map = "KA_HOENN_BIRTH_ISLAND", offset = TBD_BY_KASC },
    },
  },
  storyGate = {
    -- Informational only. VASC must not read or write this flag.
    owner = "KASC",
    collisionOpensRocksAndWater = true,
    mapConnectionsExistFromBoot = true,
    volcanoScientistLeavesAfter = {
      featherFound = true,
      victoryRoadProfessorSpokenTo = true,
    },
    birthIslandScientist = "independent Deoxys research gate",
  },
}
```

KASC must also identify the exact Cinnabar south-edge cell interval occupied by
the surf exit and the exact cells/warps occupied by both scientists. Runtime
aliases such as a display name, translated name, or randomly generated instance
ID are not an integration identity.

The reciprocal map connections remain present from boot. KASC's story logic
only owns the physical blockers and NPCs. At the fork, the volcano-side
scientist leaves after the feather has been found and the Victory Road
professor conversation has completed. The Birth Island scientist remains an
independent Deoxys-research gate. This keeps the classic 2D path, story
ownership, and VASC scenery independent.

## 3. VASC runtime behaviour

VASC will add a dedicated, topology-verified two-landmark lane. It must not
replace the existing coastal atlas entry or alter the base Cinnabar panorama.

Activation requires all of the following:

1. `CINNABAR_VOLCANO`, `CINNABAR_SOUTH_CHANNEL`, and
   `KA_HOENN_BIRTH_ISLAND` exist and each `map.id == def.id`.
2. Both targets' dimensions, tileset/outdoor status and complete connections
   match the final KASC contract exactly.
3. Cinnabar and the approach map match their complete reciprocal
   connection contracts exactly.
4. The dedicated compact asset passes its dimension/alpha contract.
5. The candidate water panels are free and not covered by a streamed map.

If any check fails, the output is the byte/geometry-equivalent current
Cinnabar/open-water panorama. Missing art, an older KASC, a future KASC map
edit, an unavailable GPU texture, or a partial runtime connection must never
hide terrain, block movement, alter collision, or make the 2D route unusable.

Placement rules:

- From Cinnabar, both destinations belong on the south horizon: the volcano
  sits left/west and Birth Island sits directly beside it on the right/east.
  This preserves the existing west-edge settlement motif and communicates the
  later two-way fork before the player reaches it.
- The along-edge coordinate is fixed by the verified map contract, never by
  the current camera or by the first free gap.
- On `CINNABAR_SOUTH_CHANNEL`, both target identities and deterministic seeds
  remain stable. Their apparent distance may reduce, but their left/right
  order may never flip or change design.
- Once either streamed destination body covers its relevant edge interval,
  only that distant card is suppressed in the same completed geometry
  transaction. The other island remains visible where the camera permits.
  There must be no one-frame duplicate or wrong transitional bitmap.
- Morning, day, dusk and night reuse one transparent geometry asset. The live
  sky, sun/moon, weather and world tint provide the phase. No sky colour is
  baked into the volcano image.
- 1x, 2x, 3x and free-camera modes share the same world anchor. The panorama
  is additive only; the classic 2D renderer never consumes it.

`CINNABAR_VOLCANO` itself receives an explicit VASC profile only after KASC's
map contract is final. Its exterior should resolve as `mountain` with sky. Its
seaward free edges can be `open_water`; crater/landward free edges must remain
`mountain`. It must not be added to the global `OPEN_SEA_MAPS` table unless
every genuinely free edge of the final map is ocean. A cave/interior floor must
use a separate map identity rather than pretending the exterior is a cave.

VASC never reads the Moltres quest flag, never opens rocks, never adds warps,
never moves either scientist, and never modifies the KASC map or save. The same
rule applies to the Deoxys research gate.

## 4. Required art and build contract

One new two-module runtime atlas is required:

```text
assets/scenery/cinnabar_story_landmarks.compact.png
```

Exact canvas: 512x128 RGBA, split into two 256x128 modules. Module 0 is the
volcano; module 1 is Birth Island. The volcano may use a maximum 220x110 sample
rectangle and Birth Island a maximum 196x98 sample rectangle. Runtime projects
those high-resolution samples at authored 144x68 and 112x48 world footprints,
respectively. Texture resolution and apparent distance/size are intentionally
independent so painterly coasts remain continuous without making either island
too large. The deterministic builder owns the final compact bytes.

Art direction:

- distant northeast face of a volcanic island, viewed from Cinnabar/approach;
- one readable crater crown, broad irregular rock foot and restrained warm
  vents suitable for a Moltres destination;
- Pokemon-route illustration character, not photorealism and not a medieval
  fantasy fortress;
- no Pokemon, trainer, text, UI, logo, copyrighted screenshot, or copied map;
- no painted sky, sun, moon, stars, clouds, ocean rectangle, horizon band, or
  full-width base ribbon;
- transparent outside the island; premultiplied downsampling may retain soft
  antialiased alpha at the silhouette and surf;
- no black/cyan matte fringe around foliage, rock or smoke;
- optional smoke must be a small transparent feature, never a black blob.

Birth Island direction:

- lower and less massive than the volcano, with a readable rocky coast;
- restrained geometric/meteorite and temporary research motifs, but no Deoxys
  Pokemon painted into the scenery;
- clearly a Pokemon-world research coast, not a second volcano, city skyline,
  or medieval ruin;
- the same transparency, matte and no-painted-sky rules as the volcano.

The build must add the source path and license/provenance note to the existing
asset-source manifest, pin both source hashes and the output hash, and add the
compact file to the release allowlist. The deterministic asset test must verify
exact 512x128 dimensions, RGBA mode, soft alpha, both bounded sample rectangles,
zero RGB in fully transparent texels, no opaque top-edge pixels, no full-width
opaque bottom strip, and no black/cyan fringe.

No separate day/night images are needed. A future battle-arena background for
fights inside `CINNABAR_VOLCANO` is a separate optional deliverable and is not
part of this panorama contract.

## 5. Headless acceptance matrix

Before any native review, the implementation must prove:

1. Any target/channel map absent: current Cinnabar geometry and coastal
   landmark unchanged.
2. Wrong target ID, dimensions, tileset, offset or reciprocal connection:
   identical fallback; no partial story-landmark lane.
3. Correct contract: exactly one volcano left and one Birth Island right at
   their fixed southern world anchors.
4. Cinnabar and the channel resolve both same target identities/seeds and keep
   their left/right order.
5. Streamed coverage suppresses only the covered card atomically; no duplicate
   landmark and no disappearance of the other island.
6. Missing, malformed or wrong-size asset: no crash and current coast remains.
7. Morning/day/dusk/night keep identical geometry and vary only live lighting.
8. 1x/2x/3x/free-camera projection bounds remain finite and correctly faced.
9. Existing Route 19/20/21/Cinnabar south-sea tests remain byte-budget stable
   in the absent/old-KASC case.
10. Release ZIP contains the pinned compact asset and remains deterministic.

Native screenshots or playthroughs are deliberately deferred until a new,
explicit EXCLUSIVE window authorises a native application start.
