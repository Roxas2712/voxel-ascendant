-- Low-cost, map-aware skyline panels beyond the streamed map union.
--
-- The first implementation extended the border block as thousands of small
-- wall quads. It closed the void, but close cameras exposed it as wallpaper
-- and building it added work to the first voxel frame. This version bakes a
-- directional transparent pixel-art skyline atlases once and wraps them around
-- a bounded set of batched large quads. It deliberately does NOT enlarge
-- an arbitrary border block: many Kanto maps use houses, gates or statues as
-- their most frequent edge block, which made the old curtain look like giant
-- wallpaper. Location-specific compact Fuji/town/forest images are baked into
-- the same retained targets as procedural fallbacks; the scene shader still
-- applies the map's time-of-day colour grade. The horizontal cap keeps orbit
-- cameras from seeing a paper edge.

local V = ...

local Voxel3D = V.require("Voxel3D")
local ModSetting = V.require("ModSetting")
local WorldPlacement = V.require("WorldPlacement")
local TileRenderer = require("src.render.TileRenderer")

local HorizonWall = {}

HorizonWall.setting = ModSetting.new("scenery", "SCENERY",
  { "full", "off" }, { "FULL", "OFF" })

-- Map and connection bounds are block-aligned (32px), so one panel per block
-- clips cleanly at seams while cutting draw geometry by 4x versus tile-sized
-- strips. Most open-sky classes pack four 128px bearings into one Canvas.
-- Mountain maps reserve 1024 texels for the important north/Fuji bearing and
-- about 341 for each other bearing in one circular world panorama. The extra
-- north texels matter because a complete Route 4 edge can fill most of a
-- Retina viewport. Every forest edge uses three connectable world-scale
-- variants instead of stretching one bearing across the complete map.
HorizonWall.CELL = 32
-- One map block is the connection/corner sampling unit. SCENERY uses a cheap
-- textured apron instead of the expensive carved border ring; the outdoor
-- silhouette itself may sit farther away for believable scale.
HorizonWall.BELT = 32
-- Outdoor silhouettes need breathing room. Keeping a city only one block
-- beyond the body made even a native 1:1 asset read as a giant vertical
-- wallpaper. The low apron still reaches the playable edge, while the distant
-- wall sits three blocks out. Closed rooms retain the compact one-block belt.
HorizonWall.OUTDOOR_WALL_DISTANCE = 96
-- Pallet and Route 1 deliberately terminate at the authored body boundary.
-- Even one synthetic 32px apron resolved into a bright green strip in the
-- default 3X MAP battle.  The continuous forest skyline therefore meets the
-- last real map cell directly; its ordinary depth test lets authored border
-- rocks/trees remain in front without another ground board between them.
HorizonWall.PALLET_WALL_DISTANCE = 0
-- Vegetated aprons use a broad, non-periodic-looking native-pixel ground
-- source.  Repeating the old 32px/8px patchwork along a long 3X battle edge
-- exposed a green checker strip between the real map and its forest.  One
-- shared 128px period per semantic vegetation class keeps the safe block-wide
-- transition while reading as continuous grass/undergrowth.  It changes no
-- geometry, draw family or streaming ownership.
HorizonWall.VEGETATION_GROUND_PERIOD = 128
HorizonWall.HEIGHT = 96
-- Closed spaces need a real enclosure rather than an outdoor-height curtain.
-- At 160 world pixels the wall remains well above both supported camera rigs.
-- A downward-facing ceiling closes the last black void in the same ground
-- batch. It is tessellated on the world-cell grid: WorldCurve then bends each
-- 32px span instead of interpolating one map-sized plane between four corners.
-- The texture is authored at the same height, so this does not trade the void
-- for a vertically stretched brick pattern.
HorizonWall.ENCLOSURE_HEIGHT = 160
HorizonWall.ENCLOSURE_TEXTURE_H = 160
-- Mt Moon keeps the same enclosure geometry and cooperative build budget as
-- every other cavern, but its authored shell has a longer world-space repeat.
-- Both dimensions are native asset dimensions: no resampling or extra layer
-- is introduced when the sources are baked into the existing wall/ground
-- textures.
HorizonWall.MT_MOON_WALL_W = 512
HorizonWall.MT_MOON_GROUND_PERIOD = 256
-- Pokemon Tower shares the same closed-room geometry as every other tower,
-- but uses a long two-bay authored wall and a broad coffered ceiling instead
-- of the old 32/128px procedural stamps.  Both periods stay block-aligned, so
-- the existing 32px WorldCurve tessellation and two-draw enclosure are
-- unchanged while the obvious wallpaper repeat moves outside a normal view.
HorizonWall.TOWER_WALL_W = 512
HorizonWall.TOWER_SURFACE_PERIOD = 256
HorizonWall.TOWER_VRAM =
  HorizonWall.TOWER_WALL_W * HorizonWall.ENCLOSURE_TEXTURE_H * 4
  + HorizonWall.TOWER_SURFACE_PERIOD
    * HorizonWall.TOWER_SURFACE_PERIOD * 4
-- The two location-named Pokecenters below use the same closed-room geometry
-- as caves/towers, but never their material.  A calm 128px repeat is wide
-- enough to avoid the old 32px wallpaper read in this 7x4-block room while
-- staying tiny and shared by both maps.
HorizonWall.POKECENTER_ROOM_WALL_W = 128
HorizonWall.POKECENTER_ROOM_SURFACE_PERIOD = 128
HorizonWall.POKECENTER_ROOM_VRAM =
  HorizonWall.POKECENTER_ROOM_WALL_W
    * HorizonWall.ENCLOSURE_TEXTURE_H * 4
  + HorizonWall.POKECENTER_ROOM_SURFACE_PERIOD
    * HorizonWall.POKECENTER_ROOM_SURFACE_PERIOD * 4
-- Eight tiny ceiling quads are roughly the same table-build work as one of the
-- existing semantic wall panels. Account for them as one cooperative unit so a
-- large tunnel yields during construction without stretching a 20x18 map over
-- dozens of otherwise idle frames.
HorizonWall.CEILING_QUADS_PER_BUILD_UNIT = 8
-- Outdoor aprons/caps now follow the same 32px vertex lattice as terrain and
-- cave ceilings.  Charging eight tiny cells as one cooperative unit keeps the
-- stricter WorldCurve geometry from turning one resume into an unbounded Lua
-- table build while avoiding a yield after every four vertices.
HorizonWall.GROUND_QUADS_PER_BUILD_UNIT = 8
HorizonWall.DIRECTION_W = 128
HorizonWall.STRIP_W = HorizonWall.DIRECTION_W * 4
HorizonWall.MOUNTAIN_STRIP_W = 2048
HorizonWall.MOUNTAIN_TEXTURE_H = 128
-- All non-alpine outdoor silhouettes share one retained atlas.  Keeping the
-- five semantic families in one Canvas means a route can change from city to
-- countryside (or town to harbour) without creating another wall draw.  The
-- compact sources are copied at native resolution and are never stretched to
-- the current map/union length.
HorizonWall.REGIONAL_STRIP_W = 2432
HorizonWall.REGIONAL_TEXTURE_H = 128
-- Viridian Forest's free camera must see a layered canopy rather than open
-- sky, but duplicating the complete 96px panel 64px higher exposed its fully
-- opaque lower third as a pair of grey-green horizontal bands in steep orbit.
-- Keep only the native upper 64px crown: its bottom starts at y=48, directly
-- behind source row 48 where all three front variants are already 126--128px
-- opaque. The cropped crown remains at one texel per world pixel and shifts
-- the foliage silhouette upward by only 16px. It is still a perimeter vault:
-- it never roofs or hides the playable map, and it shares the existing
-- regional texture and wall draw.
HorizonWall.CANOPY_VAULT_RISE = 48
HorizonWall.CANOPY_VAULT_HEIGHT = 64
HorizonWall.CANOPY_VAULT_OUTSET = 0.25
-- Viridian Forest has warp exits rather than streamed map connections, so its
-- normal horizon pass cannot infer a destination body beyond either opening.
-- Continue only the six canonical $30 approach cells across a shallow 48px
-- apron.  The live FOREST terrain atlas supplies every 8px quad; the two ends
-- aggregate into one texture-less mesh/draw and retain no bitmap of their own.
--
-- The gatehouse is the exact lower facade of Route 2's City-side Forest warp
-- (building #2 / warp #6), deterministically composited and recoloured from
-- the canonical OVERWORLD tileset, then cropped to source y=24..63. This keeps
-- the real eave, windows, brickwork and door without mounting the top-down roof
-- as a vertical billboard. Its binary-alpha outline occupies x=3..60,
-- y=0..39: unlike the old procedural frame it has no opaque background card.
-- The native-width 64x40 compact is copied once into one 10 KiB retained
-- Canvas, released immediately, and both exits aggregate into one two-quad
-- draw. South reverses winding while U stays tied to world X, so the same
-- facade is seen horizontally mirrored from inside the opposite entrance.
-- Every coordinate and source-cell expectation lives in this exported spec so
-- geometry and headless verification cannot drift.
HorizonWall.FOREST_GATE_PATH_TILE_SIZE = 8
HorizonWall.FOREST_GATE_PATH_TILE = 0x30
HorizonWall.FOREST_GATE_PATH_RISE = 0.02
HorizonWall.FOREST_GATE_PATH_UV_INSET = 0.02
HorizonWall.FOREST_GATE_FACADE_SOURCE = {
  asset = "forestGateFacade", x = 0, y = 0, w = 64, h = 40,
  alphaBBox = { x0 = 3, y0 = 0, x1 = 61, y1 = 40 },
  opaquePixels = 2140, doorCenterX = 24,
}
HorizonWall.VIRIDIAN_FOREST_GATES = {
  north = {
    edgeIndex = 0, boundaryY = 0,
    target = "VIRIDIAN_FOREST_NORTH_GATE",
    warps = {
      { x = 1, y = 0, destWarp = 3 },
      { x = 2, y = 0, destWarp = 4 },
    },
    flanks = { { x = 0, y = 0 }, { x = 3, y = 0 } },
    path = { x0 = 16, x1 = 48, z0 = -48, z1 = 0 },
    suppressPanels = { [0] = true, [32] = true },
    facade = { x0 = 8, x1 = 72, z = -48, mirror = false },
  },
  south = {
    edgeIndex = 1, boundaryY = 47,
    target = "VIRIDIAN_FOREST_SOUTH_GATE",
    warps = {
      { x = 15, y = 47, destWarp = 2 },
      { x = 16, y = 47, destWarp = 2 },
      { x = 17, y = 47, destWarp = 2 },
      { x = 18, y = 47, destWarp = 2 },
    },
    flanks = { { x = 14, y = 47 }, { x = 19, y = 47 } },
    path = { x0 = 240, x1 = 304, z0 = 768, z1 = 816 },
    suppressPanels = { [224] = true, [256] = true, [288] = true },
    facade = { x0 = 232, x1 = 296, z = 816, mirror = true },
  },
}
-- Route 8 owns one continuous west-to-east strip.  The first 32px draft had
-- enough horizontal resolution but not enough vertical source information:
-- its few high-rise pixels expanded into the modern billboard ring caught by
-- native QA.  Keep the same 1:1 world width, but retain a dedicated 960x96
-- Canvas with three low Kanto depth bands.  It is decoded only when Route 8
-- is visible; ordinary regional maps keep their existing atlas and VRAM.
HorizonWall.ROUTE8_STRIP_W = 960
HorizonWall.ROUTE8_TEXTURE_H = 96
HorizonWall.ROUTE8_CITY_SPAN = 288
HorizonWall.ROUTE8_LAVENDER_X = 672
-- The landmark silhouettes have one physical owner each: Saffron's tower is
-- on the west face and Lavender's memorial tower is on the east face.  The
-- long north/south views still advance west-to-east through the same authored
-- strip, but substitute two native 32px background panels where those towers
-- live.  This prevents an oblique camera from seeing the same landmark on
-- three walls at once without adding another atlas or changing either exact
-- connector view.
HorizonWall.ROUTE8_LANDMARKS = {
  saffron = {
    owner = 2, x0 = 128, x1 = 192, replacementX = 256,
  },
  lavender = {
    owner = 3, x0 = 768, x1 = 832, replacementX = 608,
  },
}
HorizonWall.ROUTE8_LANDMARK_ORDER = { "saffron", "lavender" }
-- A separate eight-module cut-out atlas supplies the missing middle depth on
-- Route 8.  It remains independent of the distant skyline so the landmark
-- strip is still drawn exactly once.  Every module is one 32x64 world plane;
-- two rings at 32px and 64px outward share one mesh/texture draw.
HorizonWall.ROUTE8_MIDGROUND_W = 256
HorizonWall.ROUTE8_MIDGROUND_H = 64
HorizonWall.ROUTE8_MIDGROUND_MODULE_W = 32
HorizonWall.ROUTE8_MIDGROUND_MODULES = 8
HorizonWall.ROUTE8_MIDGROUND_ROWS = 2
HorizonWall.ROUTE8_MIDGROUND_OPENING = 64
-- Route 8's real Gen-1 connections are not centred generic 64px gates.  The
-- west connection is offset four blocks into Saffron and exposes walkable
-- cells y=8..10; the flush Lavender connection has only cell y=8 open.  Keep
-- those authored lanes explicit so fallback scenery can frame, but never
-- cover, the route that the real streamed neighbour will occupy.
HorizonWall.ROUTE8_SEAMS = {
  [2] = {
    target = "SAFFRON_CITY", offsetBlocks = -4,
    firstCell = 8, lastCell = 10, z0 = 128, z1 = 176,
    flankModule = 3,
    sourceTiles = {
      [8] = { 0x23, 0x23, 0x39, 0x23 },
      [9] = { 0x23, 0x23, 0x23, 0x23 },
      [10] = { 0x39, 0x39, 0x39, 0x39 },
    },
  },
  [3] = {
    target = "LAVENDER_TOWN", offsetBlocks = 0,
    firstCell = 8, lastCell = 8, z0 = 128, z1 = 144,
    flankModule = 7,
    sourceTiles = { [8] = { 0x39, 0x39, 0x39, 0x39 } },
  },
}
HorizonWall.ROUTE8_SEAM_CELL = 16
HorizonWall.ROUTE8_COLD_PATH_LENGTH = 96
HorizonWall.ROUTE8_COLD_PATH_TILE_SIZE = 8
HorizonWall.ROUTE8_COLD_PATH_RISE = 0.02
HorizonWall.ROUTE8_COLD_PATH_UV_INSET = 0.02
-- The endpoint modules contain attractive trees, but even a half-module is a
-- 64px-high billboard at the player's shoulder when placed at a seam.  The
-- existing Route 8 voxel course supplies the physical frame, so it gets no
-- second near-camera billboard.  Only cold-apron midground markers farther
-- outside use module 3's intact lower 16x12 shrub region; they disappear with
-- the fallback and add no resampling, bitmap or retained texture.
HorizonWall.ROUTE8_SEAM_SHRUB = { x = 112, y = 48, w = 16, h = 12 }
HorizonWall.REGIONAL_SLICES = {
  forest =    { x = 0,    y = 32, w = 384, h = 96 },
  town =      { x = 384,  y = 32, w = 512, h = 96 },
  metropolis ={ x = 896,  y = 32, w = 512, h = 96 },
  rural =     { x = 1408, y = 0,  w = 512, h = 128 },
  harbor =    { x = 1920, y = 0,  w = 512, h = 128 },
}
-- A coastal cadence needs one genuinely low native module between the full
-- panorama and open water, not a scaled or softly faded copy.  The last 32px
-- of the already-retained harbour source is an irregular quay/bush cut-out
-- with binary alpha.  This overlapping atlas alias adds no image, Canvas,
-- retained byte or draw family; `nativeWorld` makes its complete 32px source
-- span consume exactly one 32px world panel.
HorizonWall.COASTAL_CADENCE_LOW_KIND = "coastal_quay"
HorizonWall.COASTAL_CADENCE_LOW_SOURCE = {
  asset = "harbor", x = 480, y = 0, w = 32, h = 128,
  atlasX = 2400, atlasY = 0,
  alphaBBox = { x0 = 0, y0 = 87, x1 = 32, y1 = 118 },
  alphaValues = { 0, 255 },
}
HorizonWall.REGIONAL_SLICES[HorizonWall.COASTAL_CADENCE_LOW_KIND] = {
  x = HorizonWall.COASTAL_CADENCE_LOW_SOURCE.atlasX,
  y = HorizonWall.COASTAL_CADENCE_LOW_SOURCE.atlasY,
  w = HorizonWall.COASTAL_CADENCE_LOW_SOURCE.w,
  h = HorizonWall.COASTAL_CADENCE_LOW_SOURCE.h,
  nativeWorld = true,
}
-- Physical atlas order follows a clockwise world walk: north west->east,
-- east north->south, south east->west, west south->north, then back to north.
-- The south/west UVs therefore run backwards as their local coordinates grow.
-- Every adjacent pair of endpoint columns is authored identically, removing
-- the vertical cut that used to expose the NW wall join in Route 4.
HorizonWall.MOUNTAIN_SECTORS = {
  [0] = { x = 0,    w = 1024, reverse = false }, -- north: west -> east
  [1] = { x = 1365, w = 342,  reverse = true  }, -- south: east -> west
  [2] = { x = 1707, w = 341,  reverse = true  }, -- west:  south -> north
  [3] = { x = 1024, w = 341,  reverse = false }, -- east:  north -> south
}
HorizonWall.MOUNTAIN_SHADE = 0.90
HorizonWall.FOREST_VARIANTS = 3
HorizonWall.FOREST_STRIP_W = HorizonWall.DIRECTION_W
                              * HorizonWall.FOREST_VARIANTS
-- The backdrop is ultimately viewed through perspective minification and can
-- optionally pass through the AA fold and the tilt-shift photo effect. Tiny
-- one-pixel leaf marks turn into grey/green mush in those passes, especially
-- on a Retina/iPhone canvas. Author the forest on a deliberate 2px grid so
-- its smallest marks remain a readable pixel-art block after either pass.
HorizonWall.ART_GRID = 2
HorizonWall.CAP_DEPTH = 192
-- Viridian gets a small amount of real near-field scenery in front of its
-- painted town panorama. All trees share one mesh: this is a hard cap on
-- both first-build work and GPU cost, independent of the map perimeter.
HorizonWall.FOREGROUND_TREE_CAP = 8
HorizonWall.FOREGROUND_TREE_QUADS = 13
-- Viridian Forest uses three shallow billboard rows between the real map edge
-- and its opaque forest wall. They share one 128x64 four-tree atlas and one
-- indexed mesh, so a longer perimeter grows only the vertex count, never the
-- texture or draw count.
HorizonWall.CANOPY_FILLER_ROWS = 3
-- Ordinary wooded routes use two shallow cut-out rows as well. This is a
-- fixed depth budget, not a new voxel ring: every row is appended to the one
-- shared foreground mesh and uses the existing four-tree atlas.
HorizonWall.GENERIC_TREE_FILLER_ROWS = 2
HorizonWall.MINI_TREE_W = 128
HorizonWall.MINI_TREE_H = 64
HorizonWall.FOREGROUND_ATLAS_W = 160 -- 32px voxel material + 4x32px trees
HorizonWall.FOREGROUND_ATLAS_H = 64
-- Ordinary outdoor filler begins on the first half-cell beyond the real map
-- and advances in full cells from there.  This is the useful part of the old
-- first-person/world-fill look: real terrain ends, a few native-scale props
-- pick up immediately, and the authored skyline remains a separate distant
-- layer.  Cards are deliberately narrower than their 32px ownership cell, so
-- adjacent bitmaps do not form another continuous wall.
HorizonWall.NEAR_FILL_FIRST = 16
HorizonWall.NEAR_FILL_STEP = 32
HorizonWall.NEAR_FILL_CARD_W = 26
-- A rural panorama is transparent, so a true 90-degree end in the dilated
-- union contour can expose its rectangular geometry edge even though the
-- orthogonal wall continues behind it.  One crossed cut-out at that exact
-- turn reads as an isolated tree instead of another panorama wall.  It reuses
-- the second module in the existing foreground atlas: its centre column is
-- opaque continuously from crown to trunk, while 76px clears the rural
-- source's highest 69px silhouette.  The cards retain the ordinary 26px
-- width; this is a seam cover, never another continuous filler cadence.
HorizonWall.RURAL_TERMINAL_TREE_H = 76
HorizonWall.RURAL_TERMINAL_INSET = 2
HorizonWall.RURAL_TERMINAL_TREE_VARIANT = 1
HorizonWall.RURAL_TERMINAL_QUADS = 2
-- Open sea needs to run farther than a canopy cap: at walking height there
-- must be enough surface for the world curve to carry it below the visible
-- horizon before its far edge can ever enter frame.
HorizonWall.SEA_DEPTH = 384
HorizonWall.SEA_LEVEL = -2
HorizonWall.COASTAL_LANDMARK_W = 96
HorizonWall.COASTAL_LANDMARK_H = 60
-- V3 fits each proportional cut-out into its reviewed world maximum and pins
-- the exact alpha BBox. Geometry samples only this rectangle: one atlas texel
-- is one world pixel in both axes, while transparent module padding never
-- becomes a stretched billboard. All four feet end at the exclusive edge y=89.
HorizonWall.COASTAL_LANDMARK_V_BOTTOM = 89 / 128
HorizonWall.COASTAL_MODULES = {
  [0] = { x=20, y=50, w=88, h=39 }, -- rocky island
  [1] = { x=24, y=29, w=80, h=60 }, -- lighthouse
  [2] = { x=16, y=56, w=96, h=33 }, -- archipelago
  [3] = { x=28, y=60, w=72, h=29 }, -- Cinnabar
}
HorizonWall.COASTAL_LANDMARKS_PER_MAP = 1
HorizonWall.BUILD_UNITS_PER_SLICE = 8
HorizonWall.BUILD_RESUMES_PER_CALL = 1

-- Runtime source/target contract. The large transparent masters are decoded
-- only while their compact destination is being baked and are released in the
-- same protected call. Only the target sizes contribute retained GPU memory.
HorizonWall.IMAGE_ASSETS = {
  mountain = {
    path = "assets/sky/mountain_panorama.compact.png",
    sourceW = 2048, sourceH = 128, targetW = 2048, targetH = 128,
  },
  fuji = {
    path = "assets/sky/fuji_panorama.compact.png",
    sourceW = 128, sourceH = 43, targetW = 128, targetH = 43,
  },
  town = {
    path = "assets/scenery/viridian_town.compact.png",
    sourceW = 512, sourceH = 96, targetW = 512, targetH = 96,
  },
  forestA = {
    path = "assets/scenery/forest_edge_a.compact.png",
    sourceW = 128, sourceH = 96, targetW = 128, targetH = 96,
  },
  forestB = {
    path = "assets/scenery/forest_edge_b.compact.png",
    sourceW = 128, sourceH = 96, targetW = 128, targetH = 96,
  },
  forestC = {
    path = "assets/scenery/forest_edge_c.compact.png",
    sourceW = 128, sourceH = 96, targetW = 128, targetH = 96,
  },
  miniTrees = {
    path = "assets/scenery/mini_trees.compact.png",
    sourceW = 128, sourceH = 64, targetW = 128, targetH = 64,
  },
  metropolis = {
    path = "assets/scenery/metropolis.compact.png",
    sourceW = 512, sourceH = 96, targetW = 512, targetH = 96,
  },
  route8 = {
    path = "assets/scenery/route8_horizon.compact.png",
    sourceW = 960, sourceH = 96, targetW = 960, targetH = 96,
  },
  route8Midground = {
    path = "assets/scenery/route8_midground.compact.png",
    sourceW = 256, sourceH = 64, targetW = 256, targetH = 64,
  },
  forestGateFacade = {
    path = "assets/scenery/viridian_forest_gate.compact.png",
    sourceW = 64, sourceH = 40, targetW = 64, targetH = 40,
  },
  rural = {
    path = "assets/scenery/rural_edge.compact.png",
    sourceW = 512, sourceH = 128, targetW = 512, targetH = 128,
  },
  harbor = {
    path = "assets/scenery/harbor_edge.compact.png",
    sourceW = 512, sourceH = 128, targetW = 512, targetH = 128,
  },
  coastalLandmarks = {
    path = "assets/scenery/coastal_landmarks_v3.compact.png",
    sourceW = 512, sourceH = 128, targetW = 512, targetH = 128,
  },
  mtMoonWall = {
    path = "assets/scenery/mt_moon_wall.compact.png",
    sourceW = 512, sourceH = 160, targetW = 512, targetH = 160,
  },
  mtMoonCeiling = {
    path = "assets/scenery/mt_moon_ceiling.compact.png",
    sourceW = 256, sourceH = 256, targetW = 256, targetH = 256,
  },
  pokemonTowerWall = {
    path = "assets/scenery/pokemon_tower_wall.compact.png",
    sourceW = 512, sourceH = 160, targetW = 512, targetH = 160,
  },
  pokemonTowerCeiling = {
    path = "assets/scenery/pokemon_tower_ceiling.compact.png",
    sourceW = 256, sourceH = 256, targetW = 256, targetH = 256,
  },
  pokecenterRoomWall = {
    path = "assets/scenery/pokecenter_room_wall.compact.png",
    sourceW = 128, sourceH = 160, targetW = 128, targetH = 160,
  },
  pokecenterRoomCeiling = {
    path = "assets/scenery/pokecenter_room_ceiling.compact.png",
    sourceW = 128, sourceH = 128, targetW = 128, targetH = 128,
  },
}

HorizonWall.FUJI_VRAM = 128 * 43 * 4
HorizonWall.MOUNTAIN_VRAM = HorizonWall.MOUNTAIN_STRIP_W
                              * HorizonWall.MOUNTAIN_TEXTURE_H * 4
HorizonWall.REGIONAL_VRAM = HorizonWall.REGIONAL_STRIP_W
                              * HorizonWall.REGIONAL_TEXTURE_H * 4
HorizonWall.ROUTE8_VRAM = HorizonWall.ROUTE8_STRIP_W
                            * HorizonWall.ROUTE8_TEXTURE_H * 4
HorizonWall.ROUTE8_MIDGROUND_VRAM = HorizonWall.ROUTE8_MIDGROUND_W
                                      * HorizonWall.ROUTE8_MIDGROUND_H * 4
HorizonWall.FOREST_GATE_FACADE_VRAM =
  HorizonWall.FOREST_GATE_FACADE_SOURCE.w
  * HorizonWall.FOREST_GATE_FACADE_SOURCE.h * 4
HorizonWall.COASTAL_LANDMARK_VRAM = 512 * 128 * 4
HorizonWall.MINI_TREE_VRAM = HorizonWall.FOREGROUND_ATLAS_W
                               * HorizonWall.FOREGROUND_ATLAS_H * 4
HorizonWall.MT_MOON_VRAM = HorizonWall.MT_MOON_WALL_W
                              * HorizonWall.ENCLOSURE_TEXTURE_H * 4
                            + HorizonWall.MT_MOON_GROUND_PERIOD
                              * HorizonWall.MT_MOON_GROUND_PERIOD * 4
HorizonWall.IMAGE_EXTRA_VRAM = HorizonWall.REGIONAL_VRAM
                               + HorizonWall.ROUTE8_VRAM
                               + HorizonWall.ROUTE8_MIDGROUND_VRAM
                               + HorizonWall.FOREST_GATE_FACADE_VRAM
                               + HorizonWall.COASTAL_LANDMARK_VRAM
                               + HorizonWall.MINI_TREE_VRAM

-- A terminal mesh-allocation failure is cached for the current scenery
-- epoch.  Changing FULL/OFF is an explicit retry boundary even when the
-- setting is written by the mod manager instead of the in-game Options row.
-- Observe the raw setting here, the one common entry point used by meshes(),
-- cacheStatus() and stateKey(), and clear the old epoch exactly once when it
-- changes.  The initial read merely establishes the baseline.
local sceneryEpochValue
function HorizonWall.enabled()
  local value = HorizonWall.setting:get()
  if sceneryEpochValue ~= nil and value ~= sceneryEpochValue
     and type(HorizonWall.invalidate) == "function" then
    HorizonWall.invalidate()
  end
  sceneryEpochValue = value
  return value ~= "off"
end

local MOUNTAIN_MAPS = {
  INDIGO_PLATEAU = true, ROUTE_23 = true, ROUTE_10 = true,
  ROUTE_9 = true, ROUTE_4 = true, ROUTE_3 = true,
  CINNABAR_ISLAND = true, PEWTER_CITY = true,
}

-- Explicit settlement profiles keep image layers local to the places they
-- depict. A city strip never leaks onto Pallet or an arbitrary route merely
-- because it shares the OVERWORLD tileset. `fillerRows` is the bounded number
-- of mini-tree/underbrush depth planes inside the 32px belt.
HorizonWall.PROFILES = {
  PALLET_TOWN = {
    class = "pallet", wall = "forest", fillerRows = 0,
  },
  ROUTE_1 = {
    class = "pallet", wall = "forest", fillerRows = 0,
  },
  VIRIDIAN_CITY = {
    class = "smalltown", wall = "town", filler = "miniTrees", fillerRows = 1,
  },
  CERULEAN_CITY = {
    class = "smalltown", wall = "town", filler = "miniTrees", fillerRows = 1,
  },
  LAVENDER_TOWN = {
    class = "smalltown", wall = "town", filler = "miniTrees", fillerRows = 1,
  },
  VERMILION_CITY = {
    class = "smalltown", wall = "town", filler = "miniTrees", fillerRows = 1,
  },
  FUCHSIA_CITY = {
    class = "smalltown", wall = "town", filler = "miniTrees", fillerRows = 1,
  },
  SAFFRON_CITY = {
    class = "metropolis", wall = "metropolis", foreground = "town",
    fillerRows = 0,
  },
  CELADON_CITY = {
    class = "metropolis", wall = "metropolis", foreground = "town",
    fillerRows = 0,
  },
  VIRIDIAN_FOREST = {
    class = "canopy", wall = "forest", filler = "miniTrees", fillerRows = 3,
  },
  -- The engine marks the Safari quadrants as closed special maps even though
  -- they are open-air reserves.  Reuse the existing sharp A/B/C forest strip
  -- and the same bounded three-row mini-tree belt as Viridian Forest, but keep
  -- the sky visible above it.
  SAFARI_ZONE_CENTER = {
    class = "trees", wall = "forest", filler = "miniTrees", fillerRows = 3,
    sky = true,
  },
  SAFARI_ZONE_EAST = {
    class = "trees", wall = "forest", filler = "miniTrees", fillerRows = 3,
    sky = true,
  },
  SAFARI_ZONE_NORTH = {
    class = "trees", wall = "forest", filler = "miniTrees", fillerRows = 3,
    sky = true,
  },
  SAFARI_ZONE_WEST = {
    class = "trees", wall = "forest", filler = "miniTrees", fillerRows = 3,
    sky = true,
  },
  -- Ship Port/Ship Deck are also tagged like interiors by the source game.
  -- Their free perimeter is sea, not a room wall.  `openWater` only selects
  -- the already shared water ground texture; it adds no asset or draw pass.
  VERMILION_DOCK = {
    class = "water", wall = "water", fillerRows = 0,
    sky = true,
  },
  SS_ANNE_BOW = {
    class = "water", wall = "water", fillerRows = 0,
    sky = true, openWater = true,
  },
}

-- Safari's four outdoor reserves are authored as isolated FOREST maps.  Their
-- far wall therefore owns all four turns, unlike a streamed route whose shared
-- edge is clipped by a real neighbour.  Keep the special corner addressing
-- explicit: ordinary forest routes retain canonical world UVs unchanged.
local SAFARI_FOREST_SEEDS = {
  SAFARI_ZONE_CENTER = 11,
  SAFARI_ZONE_EAST = 23,
  SAFARI_ZONE_NORTH = 37,
  SAFARI_ZONE_WEST = 53,
}

-- Three native 32px panels from the existing A/B/C strip form each arm.  Both
-- arms of one corner use the same range in opposite physical directions, so
-- the exposed 90-degree join samples one identical texel instead of presenting
-- two unrelated cut-out crowns.  SW deliberately uses an offset A window to
-- keep the fourth turn from repeating NW verbatim.
HorizonWall.SAFARI_CORNER_MOTIFS = {
  nw = { inner = 0,   shared = 96  }, -- forest A
  ne = { inner = 128, shared = 224 }, -- forest B
  se = { inner = 256, shared = 352 }, -- forest C
  sw = { inner = 32,  shared = 128 }, -- forest A, one panel later
}

function HorizonWall.isSafariForest(map)
  local def = map and map.def or {}
  local id = tostring(map and map.id or def.id or "")
  return SAFARI_FOREST_SEEDS[id] ~= nil
end

-- Pure panel contract used by geometry and headless tests. `panelIndex` follows
-- increasing map coordinates; `outerAtStart` describes whether that coordinate
-- starts at the exposed corner or at the real map edge.
function HorizonWall.safariCornerPanelPhases(corner, panelIndex,
                                              outerAtStart)
  local motif = HorizonWall.SAFARI_CORNER_MOTIFS[corner]
  if not motif then return nil end
  local i = math.max(0, math.min(2, math.floor(panelIndex or 0)))
  if outerAtStart then
    return motif.shared - i * HorizonWall.CELL,
           motif.shared - (i + 1) * HorizonWall.CELL
  end
  return motif.inner + i * HorizonWall.CELL,
         motif.inner + (i + 1) * HorizonWall.CELL
end

-- Break the old four-panel cadence without adding another cut-out or atlas.
-- The coarse and quadratic terms keep long Safari edges from falling back into
-- a short ABAB-looking loop, while every value remains stable across rebuilds.
function HorizonWall.safariFillerStyle(map, edgeIndex, ordinal, row)
  local def = map and map.def or {}
  local id = tostring(map and map.id or def.id or "")
  local seed = SAFARI_FOREST_SEEDS[id]
  if not seed then return nil end
  local n = math.floor(ordinal or 0)
  local band = math.floor(n / 3)
  local mixed = seed * 17 + (edgeIndex or 0) * 29 + n * 11
                + band * 7 + band * band * 3 + (row or 0) * 19
  return mixed % 4, ((math.floor(mixed / 4) % 3) - 1) * 4,
         34 + ((row or 0) + 1) * 5 + (math.floor(mixed / 12) % 4) * 2
end

-- Each rule is resolved at the centre of a 32px panel.  Transition rules are
-- deliberately expressed as fractions only to choose a semantic asset; UVs
-- never use those fractions.  Texture phase is always canonical-world 1:1 in
-- panelUV() below, so adding/removing a neighbour cannot slide a panorama.
local function mix2(a, b, cut)
  return { { upto = cut or 0.50, kind = a }, { kind = b } }
end

local function mix3(a, b, c, cut1, cut2)
  return { { upto = cut1 or 0.34, kind = a },
           { upto = cut2 or 0.68, kind = b }, { kind = c } }
end

local function mix4(a, b, c, d, cut1, cut2, cut3)
  return { { upto = cut1, kind = a }, { upto = cut2, kind = b },
           { upto = cut3, kind = c }, { kind = d } }
end

-- Opposite sides deliberately do not switch semantic art on one shared
-- centre line. Their staggered thresholds follow the shape of each place,
-- while one low countryside stage separates incompatible house/forest or
-- town/harbour silhouettes. The real connected bodies still clip these
-- fallback panels atomically; this affects only genuinely exposed scenery.
-- Explicit regional matrix.  Covered real-map seams are filtered before
-- these values are consulted, so seam-facing entries describe only a safe
-- staging fallback while the adjoining map is not resident yet.
HorizonWall.EDGE_PROFILES = {
  PALLET_TOWN =       { north="forest", south="forest", west="forest", east="forest" },
  ROUTE_1 =           { north="forest", south="forest", west="forest", east="forest" },
  VIRIDIAN_CITY =     { north="town", south="town", west="town", east="town" },
  ROUTE_2 =           { north="forest", south="forest", west="forest", east="forest" },
  VIRIDIAN_FOREST =   { north="forest", south="forest", west="forest", east="forest" },

  PEWTER_CITY =       { north="mountain", south="mountain", west="mountain", east="mountain" },
  ROUTE_3 =           { north="mountain", south="mountain", west="mountain", east="mountain" },
  ROUTE_4 =           { north="mountain", south="mountain", west="mountain", east="mountain" },

  CERULEAN_CITY =     { north="rural", south="town",
                        west=mix3("rural", "mountain", "town", 0.29, 0.63),
                        east=mix3("rural", "mountain", "town", 0.39, 0.72) },
  ROUTE_5 =           { north="rural", south="metropolis",
                        west=mix3("rural", "town", "metropolis", 0.29, 0.63),
                        east=mix3("rural", "town", "metropolis", 0.39, 0.72) },
  ROUTE_9 =           { north="mountain", south="mountain", west="mountain", east="mountain" },
  ROUTE_24 =          { north="rural", south="rural", west="rural", east="rural" },
  ROUTE_25 =          { north="rural", south="rural", west="rural", east="rural" },

  SAFFRON_CITY =      { north="metropolis", south="metropolis", west="metropolis", east="metropolis" },
  ROUTE_6 =           { north="metropolis", south="harbor",
                        west=mix3("metropolis", "rural", "harbor", 0.27, 0.62),
                        east=mix3("metropolis", "rural", "harbor", 0.39, 0.73) },
  ROUTE_7 =           { north="metropolis", south="metropolis", west="metropolis", east="metropolis" },
  -- Route 8 is one authored, connector-safe world strip rather than three
  -- unrelated photo backdrops meeting on visible 90-degree cuts.  The strip
  -- itself progresses from retro Saffron through low suburbs to Lavender's
  -- memorial tower and mountains; route8Phase() selects its matching end
  -- segments when the north/south wall turns onto the west/east faces.
  ROUTE_8 =           { west="route8", east="route8",
                        north="route8", south="route8" },

  CELADON_CITY =      { north="metropolis", south="metropolis", west="metropolis", east="metropolis" },
  ROUTE_16 =          {
                        north=mix3("rural", "town", "metropolis", 0.42, 0.58),
                        south=mix3("rural", "town", "metropolis", 0.76, 0.90),
                        west="rural", east="metropolis" },

  LAVENDER_TOWN =     {
    north=mix2("town", "rural", 0.82),
    south=mix2("town", "rural", 0.82), west="town",
    east=mix3("rural", "mountain", "rural", 0.18, 0.82),
  },
  ROUTE_10 =          { north="mountain", south="mountain", west="mountain", east="mountain" },
  ROUTE_12 =          { north="rural", south="rural", west="rural", east="rural" },

  VERMILION_CITY =    { north="town", south="harbor",
                        west=mix3("town", "rural", "harbor", 0.42, 0.58),
                        east=mix3("town", "rural", "harbor", 0.48, 0.66) },
  ROUTE_11 =          { north=mix2("town", "rural", 0.44),
                        south=mix2("town", "rural", 0.58),
                        west="town", east="rural" },
  VERMILION_DOCK =    { north="harbor", south="harbor",
                        west="open_water", east="open_water" },
  SS_ANNE_BOW =       { north="open_water", south="open_water",
                        west="open_water", east="open_water" },

  FUCHSIA_CITY =      { north="forest", south="harbor",
                        west=mix4("forest", "rural", "town", "harbor",
                                  0.27, 0.39, 0.69),
                        east=mix4("forest", "rural", "town", "harbor",
                                  0.31, 0.45, 0.73) },
  ROUTE_13 =          { north="rural", south="rural", west="rural", east="rural" },
  ROUTE_14 =          { north="rural", south="rural", west="rural", east="rural" },
  ROUTE_15 =          { north=mix2("town", "rural", 0.43),
                        south=mix2("town", "rural", 0.57),
                        west="town", east="rural" },
  ROUTE_17 =          { north="rural", south="rural", west="rural", east="rural" },
  ROUTE_18 =          { north=mix2("rural", "town", 0.46),
                        south=mix2("rural", "town", 0.58),
                        west="rural", east="town" },
  SAFARI_ZONE_CENTER ={ north="forest", south="forest", west="forest", east="forest" },
  SAFARI_ZONE_EAST =  { north="forest", south="forest", west="forest", east="forest" },
  SAFARI_ZONE_NORTH = { north="forest", south="forest", west="forest", east="forest" },
  SAFARI_ZONE_WEST =  { north="forest", south="forest", west="forest", east="forest" },

  ROUTE_19 =          { north="open_water", south="open_water", west="open_water", east="open_water" },
  ROUTE_20 =          { north="open_water", south="open_water", west="open_water", east="open_water" },
  ROUTE_21 =          { north="open_water", south="open_water", west="open_water", east="open_water" },
  CINNABAR_ISLAND =   { north="open_water", south="open_water", west="open_water", east="open_water" },

  -- Route 22 approaches the mountain front from open countryside.  Keep the
  -- landmark silhouette on the north face, but let both long side faces stay
  -- rural: a mid-face mountain swap projects as a conspicuous vertical card
  -- edge in the westward 1ST/3RD views.
  ROUTE_22 =          { north="mountain", south="rural",
                        west="rural", east="rural" },
  ROUTE_23 =          { north="mountain", south="mountain", west="mountain", east="mountain" },
  INDIGO_PLATEAU =    { north="mountain", south="mountain", west="mountain", east="mountain" },
}

-- Only these long, genuinely maritime horizons receive isolated landmark
-- sprites.  They remain sparse billboards over the water mesh, never walls.
HorizonWall.COASTAL_EDGES = {
  ROUTE_19 = { south=true, east=true },
  ROUTE_20 = { north=true, south=true },
  ROUTE_21 = { west=true, east=true },
  CINNABAR_ISLAND = { south=true, west=true },
  VERMILION_DOCK = { west=true, east=true },
  SS_ANNE_BOW = { north=true, west=true, east=true },
}

-- One deliberately chosen distant motif per maritime map.  A complete
-- Route-19/20/21/Cinnabar survey union therefore contains each of the four
-- atlas modules exactly once instead of three lighthouses and two identical
-- islands.  Dock and bow use their own short-edge centre placements.  These
-- assignments are map-stable: streaming can hide a covered edge, but never
-- move or re-skin a surviving landmark.
HorizonWall.COASTAL_LANDMARKS = {
  ROUTE_19 =        { edge="east",  variant=1, w=80, h=60 }, -- lighthouse
  ROUTE_20 =        { edge="south", variant=2, w=96, h=33 }, -- archipelago
  ROUTE_21 =        { edge="east",  variant=0, w=88, h=39 }, -- rocky island
  -- The town source is naturally wide. Keep it a distant settlement rather
  -- than a third-of-screen sticker while preserving the same fixed owner.
  CINNABAR_ISLAND = { edge="west",  variant=3, w=72, h=29 },
  VERMILION_DOCK =  { edge="west",  variant=1, w=80, h=60 },
  SS_ANNE_BOW =     { edge="north", variant=2, w=96, h=33 },
}

-- Viridian Forest is intentionally not marked `outdoor` by the engine: its
-- canopy hides open sky. It is still an exterior forest at the MAP EDGE,
-- though. Treating it as an interior kept the old three-block carved tree
-- ring, which was both the forest's largest cold-build cost and the least
-- convincing edge in free cameras. The semantic tree panorama closes it
-- without making hasSky() expose sun/clouds through the leaves.
local function hasDirectionalPanorama(class)
  return class == "smalltown" or class == "metropolis" or class == "mountain"
end

-- Closed forest art is authored at one texel per world pixel and selected by
-- global 128px segments. Pallet is a forest ring too: treating it as a
-- directional landmark stretched one 128px forest image across the complete
-- town edge, turning crowns and trunks into the thick horizontal bands seen
-- from its free camera. It can share the canopy's stable A/B/C addressing
-- without inheriting the canopy's closed-sky semantics.
local function hasWorldForestStrip(class)
  return class == "trees" or class == "canopy" or class == "pallet"
end

local CAVE_TILESETS = { CAVERN = true, ORANGE_GEN2_CAVE = true }
local MT_MOON_MAPS = {
  MT_MOON_1F = true,
  MT_MOON_B1F = true,
  MT_MOON_B2F = true,
}
local ROOM_SHELL_PROFILES = {
  -- Both names describe the outdoor location of one ordinary Pokecenter
  -- layout.  They need a sealed room, but must never inherit the cave material
  -- selected by their location substrings.  Keep this an exact two-map
  -- allowlist: other interiors retain their established border path until they
  -- receive their own material and native camera proof.
  MT_MOON_POKECENTER = {
    tileset = "POKECENTER", material = "pokecenter_room",
  },
  ROCK_TUNNEL_POKECENTER = {
    tileset = "POKECENTER", material = "pokecenter_room",
  },
}

local function isTower(id)
  return id:find("POKEMON_TOWER_", 1, true) == 1
end

local function isEnclosure(class)
  return class == "cave" or class == "tower" or class == "room"
end

-- Kanto's connected southern sea belt. A named map may still have another
-- semantic class inland (Cinnabar remains volcanic), but every FREE edge on
-- these four maps is ocean. `covered()` below continues to win at the real
-- Cinnabar/Route 20/Route 21/Route 19 seams, so water is only synthesized
-- where the streamed map union genuinely ends.
local OPEN_SEA_MAPS = {
  CINNABAR_ISLAND = true,
  ROUTE_19 = true, ROUTE_20 = true, ROUTE_21 = true,
}

-- Two land maps are the authored caps of the southern sea belt. Their free
-- coastal corners used to receive the generic green 288px town apron even
-- while the connected sea body was resident. V4 moves only the nearest four
-- native 32px cells of those exact, already-existing apron panels into the
-- existing sea batch. This table is deliberately a full data contract: an
-- edited identity, dimension, offset or reciprocal connection keeps the
-- established ground path rather than guessing that a coastline still exists.
local SOUTH_SEA_LAND_FOOTS = {
  FUCHSIA_CITY = {
    width = 20, height = 18, edge = "south", sea = "ROUTE_19",
    offset = 5, seaWidth = 10, seaHeight = 27,
    reciprocal = "north", reciprocalOffset = -5,
    connections = {
      east = { map = "ROUTE_15", offset = 4 },
      south = { map = "ROUTE_19", offset = 5 },
      west = { map = "ROUTE_18", offset = 4 },
    },
    seaConnections = {
      north = { map = "FUCHSIA_CITY", offset = -5 },
      west = { map = "ROUTE_20", offset = 18 },
    },
    mode = "south_free",
  },
  PALLET_TOWN = {
    width = 10, height = 9, edge = "south", sea = "ROUTE_21",
    offset = 0, seaWidth = 10, seaHeight = 45,
    reciprocal = "north", reciprocalOffset = 0,
    connections = {
      north = { map = "ROUTE_1", offset = 0 },
      south = { map = "ROUTE_21", offset = 0 },
    },
    seaConnections = {
      north = { map = "PALLET_TOWN", offset = 0 },
      south = { map = "CINNABAR_ISLAND", offset = 0 },
    },
    mode = "south_corners",
  },
}
local SOUTH_SEA_LAND_FOOT_DEPTH = 4 * HorizonWall.CELL

-- Ship Port is not tagged outdoor in the source engine, so Dock cannot share
-- the land-foot verifier above.  Its cadence is nevertheless safe only for
-- the one exact generated 14x6 map with no streamed connections.  Any map
-- override or future topology edit retains the established panorama verbatim.
local COASTAL_CADENCE_DOCK = {
  id = "VERMILION_DOCK", width = 14, height = 6,
  tileset = "SHIP_PORT", mode = "dock",
}

-- Pure, grid-exact visual cadence.  `nil` means the canonical panel remains;
-- `low` selects the native 32px quay crop; `open_water` removes only that
-- synthetic Horizon panel and lets the existing semantic sea batch show.
-- Fuchsia tapers both arms of its two sharp coastal turns, so neither an
-- inland-facing side band nor the shoreline band can close the tip with a
-- second high/low card.  Pallet's south edge is the resident Route 21 body;
-- its two side bands taper into that real open-water continuation.
function HorizonWall.coastalCadenceStage(mode, edge, along, length)
  local C = HorizonWall.CELL
  if type(mode) ~= "string" or type(edge) ~= "string"
     or type(along) ~= "number" or type(length) ~= "number"
     or length < 3 * C or along < 0 or along >= length
     or along % C ~= 0 or length % C ~= 0 then
    return nil
  end
  local fromStart, fromEnd = along, length - C - along
  local coastalArm = false
  if mode == "south_free" then
    coastalArm = edge == "south"
                  or (edge == "west" or edge == "east")
                     and fromEnd <= C
  elseif mode == "south_corners" then
    coastalArm = (edge == "west" or edge == "east")
                 and fromEnd <= 2 * C
  elseif mode == "dock" then
    coastalArm = edge == "north" or edge == "south"
  end
  if not coastalArm then return nil end

  if mode == "south_corners" then
    if fromEnd == 0 then return "open_water" end
    if fromEnd == C then return "low" end
    return nil
  end
  if edge == "west" or edge == "east" then
    if fromEnd == 0 then return "open_water" end
    if fromEnd == C then return "low" end
    return nil
  end
  if fromStart == 0 or fromEnd == 0 then return "open_water" end
  if fromStart == C or fromEnd == C then return "low" end
  return nil
end

local function isOutdoor(def)
  if def.outdoor ~= nil then return def.outdoor and true or false end
  return def.tileset == "OVERWORLD"
end

local function roomShellProfile(map)
  local def = map and map.def or {}
  local id = tostring(map and map.id or def.id or "")
  local profile = ROOM_SHELL_PROFILES[id]
  if not profile or def.tileset ~= profile.tileset or isOutdoor(def) then
    return nil
  end
  -- A room shell is a closed warp destination, never a streamed map union.
  -- An authored physical connection therefore fails safely back to the legacy
  -- interior path rather than letting a ceiling/wall cut through its opening.
  if next(def.connections or {}) ~= nil then return nil end
  return profile
end

function HorizonWall.classFor(map)
  local def = map and map.def or {}
  local id, tileset = tostring(map and map.id or def.id or ""), def.tileset
  -- Tileset semantics are authoritative for enclosed caves. This keeps future
  -- extension maps fail-safe without maintaining an ID allowlist, and prevents
  -- an outdoor/location/room profile collision from opening a real cavern.
  if CAVE_TILESETS[tileset] then return "cave" end
  local profile = HorizonWall.PROFILES[id]
  -- A closed canopy deliberately owns a separate texture class. Ordinary
  -- outdoor tree edges may show Kanto's distant ridges through their upper
  -- gaps; painting the same ridge behind Viridian Forest would put bright
  -- mountains against its intentionally black, enclosed ceiling.
  if profile then return profile.class end
  if roomShellProfile(map) then return "room" end
  if ROOM_SHELL_PROFILES[id] then
    -- Preserve the old false-positive guard when an override no longer matches
    -- its strict room contract, while allowing an outdoor conversion of the
    -- exact ID to retain its actual world semantics.
    if isOutdoor(def) then
      if (TileRenderer.voidFill or "trees") == "water" then return "water" end
      return "trees"
    end
    return "interior"
  end
  if isTower(id) then return "tower" end
  -- Named outdoor plateaus/routes win over legacy ID-name cave fallbacks:
  -- Route 23 deliberately borrows non-OVERWORLD art but still depicts open
  -- mountains. An explicit cave tileset has already won above.
  if MOUNTAIN_MAPS[id] then return "mountain" end
  if id:find("CAVE", 1, true)
     or id:find("TUNNEL", 1, true)
     or id:find("MT_MOON", 1, true)
     or id:find("VICTORY_ROAD", 1, true)
     or id:find("SEAFOAM_ISLANDS", 1, true) then
    return "cave"
  end
  if isOutdoor(def) then
    if (TileRenderer.voidFill or "trees") == "water" then return "water" end
    return "trees"
  end
  return "interior"
end

-- Geometry keeps the broad `cave` class so camera, sky, collision and build
-- policy remain shared with the existing enclosure. Only the retained wall
-- and ground material keys vary for the three actual Mt Moon floors.
function HorizonWall.materialFor(map)
  local def = map and map.def or {}
  local id = tostring(map and map.id or def.id or "")
  local class = HorizonWall.classFor(map)
  if class == "room" then
    local profile = roomShellProfile(map)
    return profile and profile.material or "room"
  end
  if class == "cave" and MT_MOON_MAPS[id] then return "mt_moon" end
  return class
end

function HorizonWall.groundPeriodFor(map)
  local material = HorizonWall.materialFor(map)
  if material == "pallet" or material == "trees"
     or material == "canopy" then
    return HorizonWall.VEGETATION_GROUND_PERIOD
  end
  if material == "mt_moon" then return HorizonWall.MT_MOON_GROUND_PERIOD end
  if material == "tower" then return HorizonWall.TOWER_SURFACE_PERIOD end
  if material == "pokecenter_room" then
    return HorizonWall.POKECENTER_ROOM_SURFACE_PERIOD
  end
  return HorizonWall.CELL
end

function HorizonWall.profileFor(map)
  local def = map and map.def or {}
  return HorizonWall.PROFILES[tostring(map and map.id or def.id or "")]
end

local function defaultEdgeKind(class)
  if class == "smalltown" then return "town" end
  if class == "metropolis" then return "metropolis" end
  if class == "mountain" then return "mountain" end
  if class == "water" then return "open_water" end
  if class == "cave" or class == "tower" then return class end
  if class == "room" then return "room" end
  return "forest"
end

local function resolveEdgeRule(rule, t)
  if type(rule) == "string" then return rule end
  if type(rule) == "table" then
    for _, part in ipairs(rule) do
      if part.upto == nil or t < part.upto then return part.kind end
    end
  end
  return nil
end

local function fillerRowsFor(map, kind)
  local profile = HorizonWall.profileFor(map)
  if kind == "forest" then
    return profile and (profile.fillerRows or 0)
           or HorizonWall.GENERIC_TREE_FILLER_ROWS
  end
  if kind == "town" or kind == "rural" then return 1 end
  return 0
end

-- Returns both the semantic panel and its bounded near-field depth budget.
-- `localAlong` is a map-local world coordinate, but only chooses a semantic
-- transition.  It never participates in texture scaling; panelUV receives the
-- canonical coordinate separately.
function HorizonWall.panelProfile(map, edge, localAlong)
  local def = map and map.def or {}
  local id = tostring(map and map.id or def.id or "")
  local profile = HorizonWall.PROFILES[id]
  if OPEN_SEA_MAPS[id] or profile and profile.openWater then
    return "open_water", 0
  end
  local horizontal = edge == "north" or edge == "south"
  local length = math.max(HorizonWall.CELL,
    (horizontal and (def.width or 1) or (def.height or 1)) * HorizonWall.CELL)
  local t = math.max(0, math.min(0.999999,
    ((localAlong or 0) + HorizonWall.CELL * 0.5) / length))
  local rules = HorizonWall.EDGE_PROFILES[id]
  local kind = rules and resolveEdgeRule(rules[edge], t)
               or defaultEdgeKind(HorizonWall.classFor(map))
  return kind, fillerRowsFor(map, kind)
end

function HorizonWall.edgeClass(map, edge, localAlong)
  return HorizonWall.panelProfile(map, edge, localAlong)
end

function HorizonWall.hasSky(map)
  if not (map and map.def) then return false end
  local profile = HorizonWall.profileFor(map)
  return isOutdoor(map.def)
         or HorizonWall.classFor(map) == "mountain"
         or profile and profile.sky == true
         or false
end

-- Semantic scenery replaces the generic three-block border extrusion for all
-- maps it can actually close. Besides preventing decorative statue/door
-- blocks from becoming walls, this removes the most expensive cold-build
-- portion and lets the panorama exist immediately with the map body.
function HorizonWall.preferBody(map)
  if not HorizonWall.enabled() then return false end
  local class = HorizonWall.classFor(map)
  return class ~= "interior"
end

local function mapsOf(state)
  local out = { { map = state.map, ox = 0, oy = 0 } }
  for _, nb in ipairs(state.neighbors or {}) do
    if nb.map then out[#out + 1] = { map = nb.map, ox = nb.ox or 0,
                                     oy = nb.oy or 0 } end
  end
  for _, e in ipairs(out) do
    e.w, e.h = e.map.def.width * 32, e.map.def.height * 32
    e.x0, e.z0, e.x1, e.z1 = e.ox, e.oy, e.ox + e.w, e.oy + e.h
  end
  return out
end

local function covered(rects, own, x, z)
  for i, r in ipairs(rects) do
    if i ~= own and x >= r.x0 and x < r.x1 and z >= r.z0 and z < r.z1 then
      return true
    end
  end
  return false
end

local function pushQuad(verts, indices, corners, uv, shade)
  local base = #verts
  for i = 1, 4 do
    local p, t = corners[i], uv[i]
    verts[#verts + 1] = { p[1], p[2], p[3], t[1], t[2], shade }
  end
  for _, i in ipairs({ 1, 2, 3, 1, 3, 4 }) do indices[#indices + 1] = base + i end
end

local function faceUV(u0, v0, u1, v1)
  return { { u0, v1 }, { u1, v1 }, { u1, v0 }, { u0, v0 } }
end

function HorizonWall.wallFamily(kind, map)
  if kind == "route8" then return "route8" end
  if HorizonWall.REGIONAL_SLICES[kind] then return "regional" end
  if kind == "mountain" then return "mountain" end
  if kind == "mt_moon"
     or kind == "cave" and map
        and HorizonWall.materialFor(map) == "mt_moon" then
    return "mt_moon"
  end
  if kind == "cave" or kind == "tower" then return kind end
  if kind == "room" and map then return HorizonWall.materialFor(map) end
  return nil
end

-- Route 8's long north/south faces consume the strip once at native scale.
-- Its short west/east faces reuse only the authored Saffron/Lavender thirds.
-- The 96px corner arms reverse away from their adjoining endpoint, so both
-- faces arrive at the same atlas column at the outer corner.  At the two
-- inner south/east joins a panel-end and panel-start deliberately select the
-- strip's identical connector columns (0/288 and 672/959 respectively).
-- Keeping this address map pure makes the corner contract headless-testable.
function HorizonWall.route8Phase(edgeIndex, localAlong, edgeLength,
                                 atPanelEnd)
  local along = localAlong or 0
  local length = math.max(HorizonWall.CELL, edgeLength or 0)
  local cityEnd = HorizonWall.ROUTE8_CITY_SPAN
  local lavender = HorizonWall.ROUTE8_LAVENDER_X
  local stripEnd = HorizonWall.ROUTE8_STRIP_W

  if edgeIndex == 0 or edgeIndex == 1 then
    if along < 0 then return math.min(cityEnd, -along) end
    if along > length then
      return math.max(lavender, stripEnd - (along - length))
    end
    -- Route 8 is 30 blocks/960px in production.  Express the invariant as a
    -- ratio so a deliberately reduced headless fixture still reaches both
    -- authored endpoints without changing the production 1:1 address.
    return math.max(0, math.min(stripEnd, along * stripEnd / length))
  end

  if edgeIndex == 2 then -- west: the complete 288px Saffron third
    if along < 0 then return math.min(cityEnd, -along) end
    if along < length then return along * cityEnd / length end
    if along == length and atPanelEnd then return cityEnd end
    return math.min(cityEnd, math.max(0, along - length))
  end

  -- east: the complete 288px Lavender/mountain third.  A top corner ending
  -- at local zero uses the final connector, while the main face begins at the
  -- equal authored connector at x=672.  This avoids one giant interpolated
  -- wrap panel and keeps the tower unique on the short face.
  if along < 0 then return math.max(lavender, stripEnd + along) end
  if along == 0 and atPanelEnd then return stripEnd end
  if along < length then return lavender + along * cityEnd / length end
  if along == length then return stripEnd end
  return math.max(lavender, stripEnd - (along - length))
end

-- Resolve both endpoints together so a 32px wall panel can never straddle a
-- landmark replacement or acquire a stretched UV.  Only the two long faces
-- substitute pixels; the short west/east faces and all four 96px connector
-- arms retain route8Phase() byte-for-byte.  Production Route 8 is native
-- 960px wide, therefore the two 64px landmark windows align exactly to two
-- wall panels each.
function HorizonWall.route8PanelPhases(edgeIndex, local0, local1, edgeLength)
  local phase0 = HorizonWall.route8Phase(edgeIndex, local0, edgeLength, false)
  local phase1 = HorizonWall.route8Phase(edgeIndex, local1, edgeLength, true)
  if edgeIndex ~= 0 and edgeIndex ~= 1 then return phase0, phase1 end
  if local0 < 0 or local1 > edgeLength then return phase0, phase1 end

  for _, name in ipairs(HorizonWall.ROUTE8_LANDMARK_ORDER) do
    local landmark = HorizonWall.ROUTE8_LANDMARKS[name]
    if phase0 >= landmark.x0 and phase1 <= landmark.x1 then
      local shift = landmark.replacementX - landmark.x0
      return phase0 + shift, phase1 + shift
    end
  end
  return phase0, phase1
end

-- Route 8's cut-outs follow the same connector/corner address as its distant
-- strip.  Connector-equivalent phases (0/288 at Saffron and 672/960 at
-- Lavender) deliberately fold onto the same four-module set.  That makes an
-- outer corner choose the same motif from either arm without copying a second
-- landmark panorama onto the near layer.  `row` rotates by two modules so the
-- 32px and 64px rings never stack identical silhouettes on top of one another.
function HorizonWall.route8MidgroundModule(edgeIndex, localAlong, edgeLength,
                                            row)
  local phase = HorizonWall.route8Phase(edgeIndex, localAlong, edgeLength,
                                        false)
  local east = phase >= (HorizonWall.ROUTE8_CITY_SPAN
                          + HorizonWall.ROUTE8_LAVENDER_X) * 0.5
  local base = east and 4 or 0
  local anchor = east and HorizonWall.ROUTE8_LAVENDER_X or 0
  local cityPhase = (phase - anchor) % HorizonWall.ROUTE8_CITY_SPAN
  local ordinal = math.floor(cityPhase / HorizonWall.CELL + 1e-6)
  return base + (ordinal + math.max(0, math.floor(row or 0)) * 2) % 4
end

-- The short connector faces keep their complete two-row framing and exact
-- 64px opening.  On the long north/south faces, isolated native cut-outs read
-- as depth; filling every cell in both rows reads as a cardboard housing
-- belt.  Two coprime cadences keep both rows deterministic, distribute every
-- module over distance and reduce geometry without adding a draw.  Corner
-- arms remain occupied so the 90-degree connector turns do not acquire gaps.
function HorizonWall.route8MidgroundOccupied(edgeIndex, localAlong,
                                               edgeLength, row)
  if edgeIndex == 2 or edgeIndex == 3 then return true end
  if localAlong < 0 or localAlong >= edgeLength then return true end
  local ordinal = math.floor(localAlong / HorizonWall.CELL + 1e-6)
  if math.max(0, math.floor(row or 0)) == 0 then
    return ordinal % 3 == 0
  end
  return ordinal % 5 == 2
end

-- Route 8 is nine 32px blocks deep, so a geometrically centred 64px opening
-- would begin half-way through a module.  Keep every plane native 32x64 and
-- choose the stable lower of the two centre pairs: production uses 96..160.
-- The same pure calculation keeps reduced headless fixtures deterministic.
function HorizonWall.route8SeamSpec(edgeIndex)
  return HorizonWall.ROUTE8_SEAMS[edgeIndex]
end

function HorizonWall.route8MidgroundOpening(edgeLength, edgeIndex)
  local seam = HorizonWall.route8SeamSpec(edgeIndex)
  if seam and edgeLength >= seam.z1 then
    local start = math.floor(seam.z0 / HorizonWall.CELL)
                  * HorizonWall.CELL
    local finish = math.ceil(seam.z1 / HorizonWall.CELL)
                   * HorizonWall.CELL
    return start, finish
  end
  local length = math.max(HorizonWall.ROUTE8_MIDGROUND_OPENING,
                          edgeLength or 0)
  local start = math.floor((length - HorizonWall.ROUTE8_MIDGROUND_OPENING)
                           / (2 * HorizonWall.CELL)) * HorizonWall.CELL
  return start, start + HorizonWall.ROUTE8_MIDGROUND_OPENING
end

-- The first depth row directly flanking a real seam is always low vegetation
-- from the existing endpoint module set.  Houses and shops remain available
-- elsewhere, but cannot crowd the continuation of the authored white road.
function HorizonWall.route8MidgroundFlankModule(edgeIndex, localAlong,
                                                 edgeLength, row)
  local seam = HorizonWall.route8SeamSpec(edgeIndex)
  if not seam or math.floor(row or 0) ~= 0 then return nil end
  local opening0, opening1 = HorizonWall.route8MidgroundOpening(
    edgeLength, edgeIndex)
  if localAlong + HorizonWall.CELL == opening0
     or localAlong == opening1 then
    return seam.flankModule
  end
  return nil
end

local ROUTE8_SEAM_EDGE = { [2] = "west", [3] = "east" }

local function connectionTarget(connection)
  if type(connection) == "table" then
    return connection.map or connection.targetMap or connection.id
  end
  return connection
end

local function exactConnections(actual, expected)
  if type(actual) ~= "table" or type(expected) ~= "table" then return false end
  local count = 0
  for edge, wanted in pairs(expected) do
    local connection = actual[edge]
    if type(connection) ~= "table"
       or connectionTarget(connection) ~= wanted.map
       or connection.offset ~= wanted.offset then return false end
    count = count + 1
  end
  local actualCount = 0
  for edge in pairs(actual) do
    if expected[edge] == nil then return false end
    actualCount = actualCount + 1
  end
  return actualCount == count
end

local function verifiedSouthSeaLandFoot(entry, rects)
  local map, def = entry and entry.map, entry and entry.map and entry.map.def
  local id = tostring(map and (map.id or def and def.id) or "")
  local spec = SOUTH_SEA_LAND_FOOTS[id]
  if not (spec and def and map.id == id and def.id == id
      and def.tileset == "OVERWORLD"
      and def.width == spec.width and def.height == spec.height
      and isOutdoor(def)
      and exactConnections(def.connections, spec.connections)) then return nil end
  local connection = def.connections[spec.edge]
  if connectionTarget(connection) ~= spec.sea
      or type(connection) ~= "table"
      or connection.offset ~= spec.offset then return nil end

  local resident
  for _, rect in ipairs(rects or {}) do
    local seaMap, seaDef = rect.map, rect.map and rect.map.def
    local seaId = tostring(seaMap and (seaMap.id or seaDef and seaDef.id)
                             or "")
    if seaId == spec.sea then
      if resident then return nil end
      resident = rect
    end
  end
  local seaMap, seaDef = resident and resident.map,
                         resident and resident.map and resident.map.def
  local reciprocal = seaDef and seaDef.connections
                     and seaDef.connections[spec.reciprocal]
  if not (seaMap and seaDef and seaMap.id == spec.sea
      and seaDef.id == spec.sea and seaDef.tileset == "OVERWORLD"
      and seaDef.width == spec.seaWidth
      and seaDef.height == spec.seaHeight
      and isOutdoor(seaDef)
      and exactConnections(seaDef.connections, spec.seaConnections)
      and type(reciprocal) == "table"
      and connectionTarget(reciprocal) == id
      and reciprocal.offset == spec.reciprocalOffset
      and resident.ox == entry.ox + spec.offset * HorizonWall.CELL
      and resident.oy == entry.oy + entry.h) then return nil end
  return spec
end

local function verifiedDockCadence(entry)
  local map, def = entry and entry.map, entry and entry.map and entry.map.def
  local spec = COASTAL_CADENCE_DOCK
  if not (map and def and map.id == spec.id and def.id == spec.id
      and def.tileset == spec.tileset
      and def.width == spec.width and def.height == spec.height
      and def.outdoor == nil
      and type(def.connections) == "table"
      and next(def.connections) == nil) then return nil end
  return spec
end

function HorizonWall.viridianForestGateSpec(edge)
  if type(edge) == "string" then
    return HorizonWall.VIRIDIAN_FOREST_GATES[edge]
  end
  for _, spec in pairs(HorizonWall.VIRIDIAN_FOREST_GATES) do
    if spec.edgeIndex == edge then return spec end
  end
  return nil
end

-- The small gate/path treatment is deliberately tied to the exact generated
-- Red/Blue Viridian Forest exits.  North and south are verified separately:
-- an override changing one warp, material cell or collision flank loses only
-- that end's visual proxy.  The helper performs no writes to map data.
function HorizonWall.viridianForestGateVerified(map, edge)
  local spec = HorizonWall.viridianForestGateSpec(edge)
  local def, tileset = map and map.def, map and map.tileset
  if not (spec and def and tileset
          and map.id == "VIRIDIAN_FOREST"
          and def.id == "VIRIDIAN_FOREST"
          and def.tileset == "FOREST"
          and def.width == 17 and def.height == 24
          and type(def.connections) == "table"
          and next(def.connections) == nil
          and type(def.warps) == "table"
          and tileset.tilesPerRow == 16
          and tileset.imageWidth == 128 and tileset.imageHeight == 48
          and type(map.isWalkableCell) == "function"
          and type(map.tileAt) == "function") then
    return false
  end

  local expectedByX = {}
  for _, expected in ipairs(spec.warps) do
    expectedByX[expected.x] = expected
  end
  local seen, boundaryCount = {}, 0
  for _, warp in pairs(def.warps) do
    if type(warp) ~= "table" or type(warp.y) ~= "number" then return false end
    if warp.y == spec.boundaryY then
      boundaryCount = boundaryCount + 1
      local expected = expectedByX[warp.x]
      if not expected or seen[warp.x]
         or warp.x ~= expected.x or warp.y ~= expected.y
         or warp.destMap ~= spec.target
         or warp.destWarp ~= expected.destWarp then
        return false
      end
      seen[warp.x] = true
    end
  end
  if boundaryCount ~= #spec.warps then return false end

  local expectedTile = HorizonWall.FOREST_GATE_PATH_TILE
  for _, cell in ipairs(spec.warps) do
    if not seen[cell.x] then return false end
    local ok, walkable = pcall(map.isWalkableCell, map, cell.x, cell.y)
    if not ok or walkable ~= true then return false end
    for dy = 0, 1 do
      for dx = 0, 1 do
        local tileOK, tile = pcall(map.tileAt, map,
          cell.x * 2 + dx, cell.y * 2 + dy)
        if not tileOK or tile ~= expectedTile then return false end
      end
    end
  end
  for _, cell in ipairs(spec.flanks) do
    local ok, walkable = pcall(map.isWalkableCell, map, cell.x, cell.y)
    if not ok or walkable ~= false then return false end
  end
  return true
end

-- Verify an exact Route 8 endpoint before its cold path proxy can exist.
-- Every authored lane cell and its raw 2x2 material must match, while both
-- adjacent source cells remain blocked.  An edited route therefore fails
-- closed instead of inheriting screenshot-shaped scenery on a changed lane.
function HorizonWall.route8SeamVerified(map, edgeIndex)
  local seam = HorizonWall.route8SeamSpec(edgeIndex)
  local def = map and map.def
  local id = tostring(map and (map.id or (def and def.id)) or "")
  local edge = ROUTE8_SEAM_EDGE[edgeIndex]
  if not (id == "ROUTE_8" and seam and edge and def
          and def.tileset == "OVERWORLD" and def.width == 30
          and def.height == 9 and type(map.isWalkableCell) == "function"
          and type(map.tileAt) == "function") then
    return false
  end
  local connections = type(def.connections) == "table" and def.connections
                      or nil
  local connection = connections and connections[edge]
  if connectionTarget(connection) ~= seam.target
      or type(connection) ~= "table"
      or tonumber(connection.offset or 0) ~= seam.offsetBlocks then
    return false
  end
  local cx = edgeIndex == 2 and 0 or def.width * 2 - 1
  local function collision(cy)
    local ok, value = pcall(map.isWalkableCell, map, cx, cy)
    if not ok or type(value) ~= "boolean" then return nil end
    return value
  end
  for cy = seam.firstCell, seam.lastCell do
    if collision(cy) ~= true then return false end
    local expected = seam.sourceTiles and seam.sourceTiles[cy]
    if type(expected) ~= "table" or #expected ~= 4 then return false end
    local ax, ay = cx * 2, cy * 2
    for dy = 0, 1 do
      for dx = 0, 1 do
        local ok, tile = pcall(map.tileAt, map, ax + dx, ay + dy)
        if not ok or tile ~= expected[dy * 2 + dx + 1] then return false end
      end
    end
  end
  return collision(seam.firstCell - 1) == false
         and collision(seam.lastCell + 1) == false
end

-- Canonical one-world-pixel addressing.  Atlas selection is cyclic, but a
-- panel ending exactly at a cycle boundary samples the old cycle's final
-- texel; the next panel starts at the new cycle's first texel.  Since every
-- map/connection origin is 32px aligned and all periods are multiples of 32,
-- a quad can never interpolate across the atlas wrap.
function HorizonWall.panelUV(kind, edgeIndex, worldAlong, atPanelEnd)
  local family = HorizonWall.wallFamily(kind)
  if family == "mt_moon" then
    return worldAlong / HorizonWall.MT_MOON_WALL_W, 0, 1
  end
  if family == "tower" then
    return worldAlong / HorizonWall.TOWER_WALL_W, 0, 1
  end
  if family == "route8" then
    local addressed = math.max(0, math.min(HorizonWall.ROUTE8_STRIP_W - 1e-6,
      worldAlong - (atPanelEnd and 1e-6 or 0)))
    local u = (0.5 + addressed / HorizonWall.ROUTE8_STRIP_W
               * (HorizonWall.ROUTE8_STRIP_W - 1))
              / HorizonWall.ROUTE8_STRIP_W
    return u, 0, 1
  end
  if family == "regional" then
    local slice = HorizonWall.REGIONAL_SLICES[kind]
    local shifted = worldAlong + edgeIndex * HorizonWall.DIRECTION_W
    local addressed = shifted - (atPanelEnd and 1e-6 or 0)
    local cycle = math.floor(addressed / slice.w)
    local phase = shifted - cycle * slice.w
    if slice.nativeWorld then
      return (slice.x + phase) / HorizonWall.REGIONAL_STRIP_W,
             slice.y / HorizonWall.REGIONAL_TEXTURE_H,
             (slice.y + slice.h) / HorizonWall.REGIONAL_TEXTURE_H
    end
    local u = (slice.x + 0.5 + phase / slice.w * (slice.w - 1))
              / HorizonWall.REGIONAL_STRIP_W
    return u, slice.y / HorizonWall.REGIONAL_TEXTURE_H,
           (slice.y + slice.h) / HorizonWall.REGIONAL_TEXTURE_H
  end
  if family == "mountain" then
    local shifted = worldAlong + edgeIndex * 512
    local addressed = shifted - (atPanelEnd and 1e-6 or 0)
    local cycle = math.floor(addressed / HorizonWall.MOUNTAIN_STRIP_W)
    local phase = shifted - cycle * HorizonWall.MOUNTAIN_STRIP_W
    return (0.5 + phase / HorizonWall.MOUNTAIN_STRIP_W
                  * (HorizonWall.MOUNTAIN_STRIP_W - 1))
           / HorizonWall.MOUNTAIN_STRIP_W, 0, 1
  end
  -- Remaining closed rooms use a small repeating material. These are not
  -- regional panoramas and therefore need no directional atlas band.
  return worldAlong / HorizonWall.DIRECTION_W, 0, 1
end

local function panelHeight(kind)
  local slice = HorizonWall.REGIONAL_SLICES[kind]
  if slice then return slice.h end
  if kind == "mountain" then return HorizonWall.MOUNTAIN_TEXTURE_H end
  if kind == "cave" or kind == "tower" or kind == "room" then
    return HorizonWall.ENCLOSURE_HEIGHT
  end
  return HorizonWall.HEIGHT
end

local function wallDistanceFor(kind, class)
  if kind == "cave" or kind == "tower" or kind == "room" then
    return HorizonWall.BELT
  end
  if class == "pallet" then return HorizonWall.PALLET_WALL_DISTANCE end
  return HorizonWall.OUTDOOR_WALL_DISTANCE
end

-- One deliberately small, faceted voxel tree. Four trunk sides, four lower
-- crown sides plus its visible top rim, then four faces meeting at the crown
-- tip: exactly 13 quads. The transparent skyline still supplies the many
-- distant trees; these few solids exist to give the first two rows parallax,
-- depth occlusion and readable side lighting in 1ST/3RD.
local function pushForegroundTree(verts, indices, x, z, height, radius)
  local trunkHalf = 2
  local trunkTop = math.floor(height * 0.36)
  local lowerBottom = trunkTop - 5
  local lowerTop = math.floor(height * 0.70)
  local upperRadius = math.max(4, radius - 2)
  -- The first 32px of the shared 160px atlas retain the old material layout;
  -- its remaining 128px are the four billboard trees used by belt rows.
  local material = 32 / HorizonWall.FOREGROUND_ATLAS_W
  local trunkUV = faceUV(0, 0, material * 0.25, 1)
  local leafUV = faceUV(material * 0.25, 0, material * 0.75, 1)
  local lightLeafUV = faceUV(material * 0.75, 0, material, 1)

  local function sides(x0, x1, y0, y1, z0, z1,
                       tx0, tx1, tz0, tz1, uv)
    pushQuad(verts, indices,
      { { x1, y0, z1 }, { x1, y0, z0 },
        { tx1, y1, tz0 }, { tx1, y1, tz1 } },
      uv, Voxel3D.FACE_SHADE[1] or 0.84)
    pushQuad(verts, indices,
      { { x0, y0, z0 }, { x0, y0, z1 },
        { tx0, y1, tz1 }, { tx0, y1, tz0 } },
      uv, Voxel3D.FACE_SHADE[2] or 0.72)
    pushQuad(verts, indices,
      { { x0, y0, z1 }, { x1, y0, z1 },
        { tx1, y1, tz1 }, { tx0, y1, tz1 } },
      uv, Voxel3D.FACE_SHADE[5] or 0.90)
    pushQuad(verts, indices,
      { { x1, y0, z0 }, { x0, y0, z0 },
        { tx0, y1, tz0 }, { tx1, y1, tz0 } },
      uv, Voxel3D.FACE_SHADE[6] or 0.68)
  end

  sides(x - trunkHalf, x + trunkHalf, 0, trunkTop,
        z - trunkHalf, z + trunkHalf,
        x - trunkHalf, x + trunkHalf, z - trunkHalf, z + trunkHalf,
        trunkUV)
  sides(x - radius, x + radius, lowerBottom, lowerTop,
        z - radius, z + radius,
        x - upperRadius, x + upperRadius,
        z - upperRadius, z + upperRadius, leafUV)
  pushQuad(verts, indices,
    { { x - upperRadius, lowerTop, z - upperRadius },
      { x + upperRadius, lowerTop, z - upperRadius },
      { x + upperRadius, lowerTop, z + upperRadius },
      { x - upperRadius, lowerTop, z + upperRadius } },
    lightLeafUV, Voxel3D.FACE_SHADE[3] or 1)

  -- A zero-width top makes four real triangles while retaining the shared
  -- quad/index format (the second triangle of each face is degenerate).
  sides(x - upperRadius, x + upperRadius, lowerTop, height,
        z - upperRadius, z + upperRadius,
        x, x, z, z, leafUV)
end

-- One 1:1 gatehouse facade sampled from its dedicated native-size crop Canvas.
-- A half-texel inset keeps nearest filtering inside the reviewed module.
-- Winding reverses at the south exit while U remains tied to world X; from the
-- inward-facing camera that is the requested horizontal mirror.
local function pushForestGateFacade(verts, indices, spec)
  local source = HorizonWall.FOREST_GATE_FACADE_SOURCE
  local u0, u1 = 0.5 / source.w, (source.w - 0.5) / source.w
  local v0, v1 = 0.5 / source.h, (source.h - 0.5) / source.h
  local x0, x1, z, h = spec.x0, spec.x1, spec.z, source.h
  local corners, uv
  if spec.mirror then
    corners = { { x1, 0, z }, { x0, 0, z },
                { x0, h, z }, { x1, h, z } }
    uv = { { u1, v1 }, { u0, v1 }, { u0, v0 }, { u1, v0 } }
  else
    corners = { { x0, 0, z }, { x1, 0, z },
                { x1, h, z }, { x0, h, z } }
    uv = { { u0, v1 }, { u1, v1 }, { u1, v0 }, { u0, v0 } }
  end
  pushQuad(verts, indices, corners, uv, 1)
end

local function geometryFor(entry, own, rects, cooperativeStep,
                           sharedGroundCells, sharedSeaCells,
                           sharedRuralTerminals)
  local class = HorizonWall.classFor(entry.map)
  if class == "interior" then return nil end
  local material = HorizonWall.materialFor(entry.map)
  local profile = HorizonWall.profileFor(entry.map)
  local safariForest = HorizonWall.isSafariForest(entry.map)
  local workUnits = 0
  local function checkpoint(cost)
    if not cooperativeStep then return end
    workUnits = workUnits + (cost or 1)
    if workUnits >= HorizonWall.BUILD_UNITS_PER_SLICE then
      workUnits = 0
      cooperativeStep()
    end
  end
  local wallVerts, wallIndices = {}, {}
  local wallGroupsByFamily = {}
  local groundVerts, groundIndices, quads = {}, {}, 0
  local seaVerts, seaIndices, seaQuads = {}, {}, 0
  local coastalVerts, coastalIndices, coastalQuads = {}, {}, 0
  local foregroundVerts, foregroundIndices = {}, {}
  local route8MidgroundVerts, route8MidgroundIndices = {}, {}
  local route8SeamPathVerts, route8SeamPathIndices = {}, {}
  local forestGatePathVerts, forestGatePathIndices = {}, {}
  local forestGateFacadeVerts, forestGateFacadeIndices = {}, {}
  local treeSpots = {}
  local canopyFillerQuads = 0
  local ruralTerminalQuads = 0
  local canopyCrownQuads = 0
  local forestGateFacadeQuads = 0
  local forestGateFillerSuppressed = 0
  local forestGatePathQuads = 0
  local forestGatePathQuadsByEdge = { north = 0, south = 0 }
  local forestGateEdges = { north = false, south = false }
  local route8MidgroundQuads = 0
  local route8SeamFlankQuads = 0
  local route8SeamPathQuads = 0
  local route8SeamPathQuadsByEdge = { [2] = 0, [3] = 0 }
  local C, B, D = HorizonWall.CELL, HorizonWall.BELT, HorizonWall.CAP_DEPTH
  local mapId = tostring(entry.map.id or entry.map.def.id or "")
  local route8Owner = mapId == "ROUTE_8"
  local southSeaLandFoot = verifiedSouthSeaLandFoot(entry, rects)
  local coastalCadence = southSeaLandFoot or verifiedDockCadence(entry)
  local coastalWaterFootQuads = 0
  local groundPeriod = HorizonWall.groundPeriodFor(entry.map)
  local function groundUV(p)
    -- UVs include the connection/world offset. The old 32px materials are
    -- unchanged modulo one; Mt Moon's 256px source now also stays fixed when
    -- ownership changes across a streamed union.
    return { (entry.ox + p[1]) / groundPeriod,
             (entry.oy + p[3]) / groundPeriod }
  end
  local enclosureH = isEnclosure(class) and HorizonWall.ENCLOSURE_HEIGHT or 0
  local capY = enclosureH
  local outdoorGround = not isEnclosure(class)
  -- These sets are shared by every owner in one streamed union.  A connection
  -- can make two map-local aprons claim the same world cell; first ownership
  -- wins deterministically and the second owner emits no coplanar quad.
  sharedGroundCells = sharedGroundCells or {}
  sharedSeaCells = sharedSeaCells or {}
  sharedRuralTerminals = sharedRuralTerminals or {}

  -- While either target body mesh is still cold, the current-only semantic
  -- horizon owns a 96px apron whose generic `trees` material would otherwise
  -- turn Route 8's white lanes green.  Continue the exact source-authored
  -- 2x2 tile phases ($23/$39 west, $39 east) over that complete depth.  Both
  -- sides aggregate into one terrain-atlas draw, add no bitmap/retained VRAM,
  -- and disappear independently when their real target or any covering body
  -- is resident, so the warm union can never z-fight a proxy.
  local function route8ColdSeamPath(edgeIndex)
    if not route8Owner
       or not HorizonWall.route8SeamVerified(entry.map, edgeIndex) then
      return
    end
    local seam = HorizonWall.route8SeamSpec(edgeIndex)
    for _, rect in ipairs(rects) do
      local id = tostring(rect.map and (rect.map.id
                         or rect.map.def and rect.map.def.id) or "")
      if id == seam.target then return end
    end

    local tileSize = HorizonWall.ROUTE8_COLD_PATH_TILE_SIZE
    local x0, x1, sourceBaseTx
    if edgeIndex == 2 then
      x0, x1, sourceBaseTx = -HorizonWall.ROUTE8_COLD_PATH_LENGTH, 0, 0
    else
      x0, x1 = entry.w, entry.w + HorizonWall.ROUTE8_COLD_PATH_LENGTH
      sourceBaseTx = (entry.map.def.width * 2 - 1) * 2
    end
    local z0, z1 = seam.z0, seam.z1
    -- Coverage is preflighted before the first push: an unusual edited union
    -- gets either one complete fallback or none, never a half-painted lane.
    for x = x0, x1 - tileSize, tileSize do
      for z = z0, z1 - tileSize, tileSize do
        if covered(rects, own, entry.ox + x + tileSize / 2,
                              entry.oy + z + tileSize / 2) then
          return
        end
      end
    end

    local tileset = entry.map.tileset or {}
    local perRow = tonumber(tileset.tilesPerRow)
    local atlasW, atlasH = tonumber(tileset.imageWidth),
                           tonumber(tileset.imageHeight)
    if perRow ~= 16 or atlasW ~= 128 or atlasH ~= 48 then return end
    local inset = HorizonWall.ROUTE8_COLD_PATH_UV_INSET
    local y = HorizonWall.ROUTE8_COLD_PATH_RISE
    for x = x0, x1 - tileSize, tileSize do
      for z = z0, z1 - tileSize, tileSize do
        local sourceDx = math.floor(x / tileSize) % 2
        local sourceTy = math.floor(z / tileSize)
        local tile = entry.map:tileAt(sourceBaseTx + sourceDx, sourceTy)
        local px = (tile % perRow) * tileSize
        local py = math.floor(tile / perRow) * tileSize
        local u0, u1 = (px + inset) / atlasW,
                       (px + tileSize - inset) / atlasW
        local v0, v1 = (py + inset) / atlasH,
                       (py + tileSize - inset) / atlasH
        pushQuad(route8SeamPathVerts, route8SeamPathIndices,
          { { x, y, z }, { x + tileSize, y, z },
            { x + tileSize, y, z + tileSize },
            { x, y, z + tileSize } },
          { { u0, v0 }, { u1, v0 }, { u1, v1 }, { u0, v1 } },
          Voxel3D.FACE_SHADE[3] or 1)
        route8SeamPathQuads = route8SeamPathQuads + 1
        route8SeamPathQuadsByEdge[edgeIndex] =
          route8SeamPathQuadsByEdge[edgeIndex] + 1
        checkpoint(1 / HorizonWall.GROUND_QUADS_PER_BUILD_UNIT)
      end
    end
  end

  route8ColdSeamPath(2)
  route8ColdSeamPath(3)

  -- Warp destinations are not streamed neighbours, so each canonical Forest
  -- exit owns a short visual continuation.  Preflight the complete rectangle
  -- before activating an end: a synthetic/overridden resident body gets all
  -- of its own ground or none of this proxy, never a partial z-fighting lane.
  for _, name in ipairs({ "north", "south" }) do
    local spec = HorizonWall.VIRIDIAN_FOREST_GATES[name]
    local active = HorizonWall.viridianForestGateVerified(entry.map, name)
    if active then
      local tileSize = HorizonWall.FOREST_GATE_PATH_TILE_SIZE
      for x = spec.path.x0, spec.path.x1 - tileSize, tileSize do
        for z = spec.path.z0, spec.path.z1 - tileSize, tileSize do
          if covered(rects, own, entry.ox + x + tileSize / 2,
                                  entry.oy + z + tileSize / 2) then
            active = false
            break
          end
        end
        if not active then break end
      end
    end
    forestGateEdges[name] = active
    if active then
      local tileSize = HorizonWall.FOREST_GATE_PATH_TILE_SIZE
      local tile = HorizonWall.FOREST_GATE_PATH_TILE
      local atlasW, atlasH = entry.map.tileset.imageWidth,
                             entry.map.tileset.imageHeight
      local px = (tile % entry.map.tileset.tilesPerRow) * tileSize
      local py = math.floor(tile / entry.map.tileset.tilesPerRow) * tileSize
      local inset = HorizonWall.FOREST_GATE_PATH_UV_INSET
      local u0, u1 = (px + inset) / atlasW,
                     (px + tileSize - inset) / atlasW
      local v0, v1 = (py + inset) / atlasH,
                     (py + tileSize - inset) / atlasH
      local y = HorizonWall.FOREST_GATE_PATH_RISE
      for x = spec.path.x0, spec.path.x1 - tileSize, tileSize do
        for z = spec.path.z0, spec.path.z1 - tileSize, tileSize do
          pushQuad(forestGatePathVerts, forestGatePathIndices,
            { { x, y, z }, { x + tileSize, y, z },
              { x + tileSize, y, z + tileSize }, { x, y, z + tileSize } },
            { { u0, v0 }, { u1, v0 }, { u1, v1 }, { u0, v1 } },
            Voxel3D.FACE_SHADE[3] or 1)
          forestGatePathQuads = forestGatePathQuads + 1
          forestGatePathQuadsByEdge[name] =
            forestGatePathQuadsByEdge[name] + 1
          checkpoint(1 / HorizonWall.GROUND_QUADS_PER_BUILD_UNIT)
        end
      end
      pushForestGateFacade(forestGateFacadeVerts,
                           forestGateFacadeIndices, spec.facade)
      forestGateFacadeQuads = forestGateFacadeQuads + 1
      checkpoint(1)
    end
  end

  local function wallGroup(family)
    local group = wallGroupsByFamily[family]
    if not group then
      group = { family = family, vertices = {}, indices = {} }
      wallGroupsByFamily[family] = group
    end
    return group
  end

  local function pushWall(kind, corners, edgeIndex, world0, world1, shade,
                          reverse, local0, local1, edgeLength,
                          forcedPhase0, forcedPhase1)
    local family = HorizonWall.wallFamily(kind, entry.map)
    if not family then return end
    local texture0, texture1 = world0, world1
    if kind == "route8" and local0 ~= nil and local1 ~= nil then
      texture0, texture1 = HorizonWall.route8PanelPhases(
        edgeIndex, local0, local1, edgeLength)
    end
    local u0, u1, v0, v1
    if forcedPhase0 ~= nil and forcedPhase1 ~= nil and kind == "forest" then
      local slice = HorizonWall.REGIONAL_SLICES.forest
      local function phaseU(phase)
        local p = phase % slice.w
        return (slice.x + 0.5 + p / slice.w * (slice.w - 1))
               / HorizonWall.REGIONAL_STRIP_W
      end
      u0, u1 = phaseU(forcedPhase0), phaseU(forcedPhase1)
      v0, v1 = slice.y / HorizonWall.REGIONAL_TEXTURE_H,
               (slice.y + slice.h) / HorizonWall.REGIONAL_TEXTURE_H
    else
      local textureKind = family == "mt_moon" and family or kind
      u0, v0, v1 = HorizonWall.panelUV(textureKind, edgeIndex,
                                       texture0, false)
      u1 = HorizonWall.panelUV(textureKind, edgeIndex, texture1, true)
    end
    local uv = reverse
      and { { u1, v1 }, { u0, v1 }, { u0, v0 }, { u1, v0 } }
      or  { { u0, v1 }, { u1, v1 }, { u1, v0 }, { u0, v0 } }
    local group = wallGroup(family)
    pushQuad(group.vertices, group.indices, corners, uv, shade)
    -- Keep the legacy aggregate for diagnostics/headless audit consumers.
    pushQuad(wallVerts, wallIndices, corners, uv, shade)

    -- Viridian Forest receives the upper 64 native texel rows of the same
    -- forest panel behind its existing wall, never a map-sized horizontal
    -- roof. Starting the crop at y=48 hides its opaque lower cut behind the
    -- front panel, while the transparent treetop gaps reveal a subtly shifted
    -- rear crown without exposing a second solid wall band. Vault vertices
    -- stay out of wallVerts: that aggregate continues to describe authored
    -- base panels.
    if class == "canopy" and kind == "forest" then
      local outset = HorizonWall.CANOPY_VAULT_OUTSET
      local dx = edgeIndex == 2 and -outset
                 or edgeIndex == 3 and outset or 0
      local dz = edgeIndex == 0 and -outset
                 or edgeIndex == 1 and outset or 0
      local rise = HorizonWall.CANOPY_VAULT_RISE
      local height = HorizonWall.CANOPY_VAULT_HEIGHT
      local crownCorners = {
        { corners[1][1] + dx, rise,
          corners[1][3] + dz },
        { corners[2][1] + dx, rise,
          corners[2][3] + dz },
        { corners[3][1] + dx, rise + height,
          corners[3][3] + dz },
        { corners[4][1] + dx, rise + height,
          corners[4][3] + dz },
      }
      local crownBottomV = v0 + height / HorizonWall.REGIONAL_TEXTURE_H
      local crownUV = {
        { uv[1][1], crownBottomV }, { uv[2][1], crownBottomV },
        { uv[3][1], v0 }, { uv[4][1], v0 },
      }
      pushQuad(group.vertices, group.indices, crownCorners, crownUV,
               math.max(0.62, math.min(0.78, shade * 0.82)))
      canopyCrownQuads = canopyCrownQuads + 1
      quads = quads + 1
      checkpoint(1 / HorizonWall.GROUND_QUADS_PER_BUILD_UNIT)
    end
  end

  local function worldCellKey(x, z)
    return tostring(entry.ox + x) .. ":" .. tostring(entry.oy + z)
  end

  -- The far wall is the boundary of the complete streamed union dilated by
  -- its scenery distance, not four independently offset map rectangles. At
  -- an offset connection two map-local walls otherwise cross, then continue
  -- as 96px spurs. Sampling one pixel to either side of the candidate plane
  -- clips those internal pieces while retaining the exact outer contour.
  local function insideDilatedUnion(worldX, worldZ, distance)
    for _, rect in ipairs(rects) do
      if worldX >= rect.x0 - distance and worldX < rect.x1 + distance
         and worldZ >= rect.z0 - distance and worldZ < rect.z1 + distance then
        return true
      end
    end
    return false
  end

  local function exteriorWallPanel(axis, along, wall, outward, distance)
    if not outdoorGround then return true end
    local worldAlong = (axis == "z" and entry.ox or entry.oy)
                       + along + C / 2
    local worldWall = (axis == "z" and entry.oy or entry.ox) + wall
    local inNormal = worldWall - outward
    local outNormal = worldWall + outward
    if axis == "z" then
      return insideDilatedUnion(worldAlong, inNormal, distance)
             and not insideDilatedUnion(worldAlong, outNormal, distance)
    end
    return insideDilatedUnion(inNormal, worldAlong, distance)
           and not insideDilatedUnion(outNormal, worldAlong, distance)
  end

  -- World-space counterpart used only to prove the orthogonal half of a
  -- terminal.  Requiring both rural faces makes the treatment fail closed at
  -- harbours, open water and mixed semantic joins: a lone rural run ending
  -- beside some other family receives no guessed tree.
  local function worldExteriorWallPanel(axis, worldAlong, worldWall,
                                        outward, distance)
    local inNormal = worldWall - outward
    local outNormal = worldWall + outward
    if axis == "z" then
      return insideDilatedUnion(worldAlong, inNormal, distance)
             and not insideDilatedUnion(worldAlong, outNormal, distance)
    end
    return insideDilatedUnion(inNormal, worldAlong, distance)
           and not insideDilatedUnion(outNormal, worldAlong, distance)
  end

  local function ruralOwnerAtWall(axis, worldAlong, worldWall,
                                  outward, distance)
    for _, rect in ipairs(rects) do
      local edge, localAlong
      if axis == "z" and outward < 0
         and worldWall == rect.z0 - distance
         and worldAlong >= rect.x0 - distance
         and worldAlong < rect.x1 + distance then
        edge, localAlong = "north", worldAlong - rect.ox
      elseif axis == "z" and outward > 0
             and worldWall == rect.z1 + distance
             and worldAlong >= rect.x0 - distance
             and worldAlong < rect.x1 + distance then
        edge, localAlong = "south", worldAlong - rect.ox
      elseif axis == "x" and outward < 0
             and worldWall == rect.x0 - distance
             and worldAlong >= rect.z0 - distance
             and worldAlong < rect.z1 + distance then
        edge, localAlong = "west", worldAlong - rect.oy
      elseif axis == "x" and outward > 0
             and worldWall == rect.x1 + distance
             and worldAlong >= rect.z0 - distance
             and worldAlong < rect.z1 + distance then
        edge, localAlong = "east", worldAlong - rect.oy
      end
      if edge and HorizonWall.panelProfile(rect.map, edge, localAlong)
                    == "rural" then
        return true
      end
    end
    return false
  end

  local function hasOrthogonalRuralWall(axis, worldX, worldZ, distance)
    local otherAxis = axis == "z" and "x" or "z"
    local worldWall = axis == "z" and worldX or worldZ
    local turnAlong = axis == "z" and worldZ or worldX
    for _, half in ipairs({ -C / 2, C / 2 }) do
      for _, outward in ipairs({ -1, 1 }) do
        local worldAlong = turnAlong + half
        if worldExteriorWallPanel(otherAxis, worldAlong, worldWall,
                                  outward, distance)
           and ruralOwnerAtWall(otherAxis, worldAlong, worldWall,
                                outward, distance) then
          return true
        end
      end
    end
    return false
  end

  local function pushRuralTerminalCover(worldX, worldZ, distance)
    local key = tostring(worldX) .. ":" .. tostring(worldZ)
    if sharedRuralTerminals[key] then return end

    -- A rectangular contour turn has either one (convex) or three (concave)
    -- inside quadrants.  Their signed sum points into the dilated union in
    -- both cases.  Anything ambiguous fails closed instead of risking a card
    -- on water or inside playable terrain.
    local inset = HorizonWall.RURAL_TERMINAL_INSET
    local insideX, insideZ = 0, 0
    for _, dx in ipairs({ -inset, inset }) do
      for _, dz in ipairs({ -inset, inset }) do
        if insideDilatedUnion(worldX + dx, worldZ + dz, distance) then
          insideX = insideX + dx / inset
          insideZ = insideZ + dz / inset
        end
      end
    end
    if insideX == 0 or insideZ == 0 then return end

    sharedRuralTerminals[key] = true
    local x = worldX - entry.ox + (insideX < 0 and -inset or inset)
    local z = worldZ - entry.oy + (insideZ < 0 and -inset or inset)
    local half = HorizonWall.NEAR_FILL_CARD_W / 2
    local h = HorizonWall.RURAL_TERMINAL_TREE_H
    local variant = HorizonWall.RURAL_TERMINAL_TREE_VARIANT
    local atlasW = HorizonWall.FOREGROUND_ATLAS_W
    local u0, u1 = (32 + variant * 32) / atlasW,
                   (32 + (variant + 1) * 32) / atlasW
    local uv = { { u0, 1 }, { u1, 1 }, { u1, 0 }, { u0, 0 } }
    pushQuad(foregroundVerts, foregroundIndices,
      { { x - half, 0, z }, { x + half, 0, z },
        { x + half, h, z }, { x - half, h, z } },
      uv, Voxel3D.FACE_SHADE[5] or 0.90)
    pushQuad(foregroundVerts, foregroundIndices,
      { { x, 0, z + half }, { x, 0, z - half },
        { x, h, z - half }, { x, h, z + half } },
      uv, Voxel3D.FACE_SHADE[1] or 0.84)
    ruralTerminalQuads = ruralTerminalQuads
                         + HorizonWall.RURAL_TERMINAL_QUADS
  end

  local function ruralWallTerminals(kind, axis, along, wall, outward,
                                    distance)
    if kind ~= "rural" or not outdoorGround then return end
    for _, atEnd in ipairs({ false, true }) do
      local neighbourAlong = along + (atEnd and C or -C)
      if not exteriorWallPanel(axis, neighbourAlong, wall, outward, distance) then
        local terminalAlong = along + (atEnd and C or 0)
        local worldX = entry.ox + (axis == "z" and terminalAlong or wall)
        local worldZ = entry.oy + (axis == "z" and wall or terminalAlong)
        if hasOrthogonalRuralWall(axis, worldX, worldZ, distance) then
          pushRuralTerminalCover(worldX, worldZ, distance)
        end
      end
    end
  end

  -- Every outdoor horizontal surface is emitted on the map's native 32px
  -- world lattice.  Besides making the quadratic WorldCurve interpolation
  -- agree at every join, the shared key removes both the old isolated-corner
  -- double draw and cross-owner overlap at streamed seams.
  local function outdoorGroundRect(x0, x1, z0, z1)
    local loX, hiX = math.min(x0, x1), math.max(x0, x1)
    local loZ, hiZ = math.min(z0, z1), math.max(z0, z1)
    local added = 0
    for x = loX, hiX - C, C do
      for z = loZ, hiZ - C, C do
        local key = worldCellKey(x, z)
        if not sharedGroundCells[key] then
          sharedGroundCells[key] = true
          local p = { { x, 0, z }, { x + C, 0, z },
                      { x + C, 0, z + C }, { x, 0, z + C } }
          local uv = {}
          for i = 1, 4 do uv[i] = groundUV(p[i]) end
          pushQuad(groundVerts, groundIndices, p, uv,
                   Voxel3D.FACE_SHADE[3] or 1)
          added = added + 1
          checkpoint(1 / HorizonWall.GROUND_QUADS_PER_BUILD_UNIT)
        end
      end
    end
    return added
  end

  local function rememberTree(kind, axis, along, wall, outward, ordinal,
                              total, edgeIndex, beltDepth)
    if kind ~= "town" or ordinal < 0 or ordinal >= total then return end
    -- Two stable targets per edge, rather than sampling whatever panels are
    -- currently free. When a connected neighbour lands, covered trees simply
    -- disappear with that edge; surviving trees never reshuffle or pop to a
    -- different panel.
    local first = math.floor((total - 1) * 0.25 + 0.5)
    local second = math.floor((total - 1) * 0.75 + 0.5)
    if ordinal ~= first and ordinal ~= second then return end
    treeSpots[#treeSpots + 1] = {
      axis = axis, along = along, wall = wall, outward = outward,
      ordinal = ordinal, edgeIndex = edgeIndex, beltDepth = beltDepth,
    }
  end

  local safariCornerOrder = { nw = 0, ne = 1, se = 2, sw = 3 }
  local function sceneryRows(axis, along, wall, outward, ordinal, edgeIndex,
                             fillerRows, beltDepth, cornerInfo)
    if fillerRows <= 0 then return end
    local gateName = edgeIndex == 0 and "north"
                     or edgeIndex == 1 and "south" or nil
    local gate = gateName and HorizonWall.VIRIDIAN_FOREST_GATES[gateName]
    if class == "canopy" and axis == "z" and forestGateEdges[gateName]
       and gate.suppressPanels[along] then
      forestGateFillerSuppressed = forestGateFillerSuppressed + fillerRows
      return
    end
    beltDepth = beltDepth or B
    -- Viridian Forest and Safari already have reviewed, corner-coupled three
    -- row compositions. Preserve those byte-for-byte. Ordinary routes and
    -- towns use the simpler exposed-edge cadence below.
    local legacyRows = class == "canopy" or safariForest
    for row = 0, fillerRows - 1 do
      local towardMap
      if legacyRows then
        towardMap = beltDepth * (row + 1) / (fillerRows + 1)
      else
        local fromMap = math.min(beltDepth - 1,
          HorizonWall.NEAR_FILL_FIRST + row * HorizonWall.NEAR_FILL_STEP)
        towardMap = beltDepth - fromMap
      end
      local normal = wall - outward * towardMap
      local stagger = ((ordinal * 5 + edgeIndex * 3 + row * 2) % 3 - 1) * 4
      local height = 34 + (row + 1) * 5
                     + ((ordinal + row + edgeIndex) % 3) * 3
      local variant = (ordinal + row * 2 + edgeIndex) % 4
      if safariForest then
        variant, stagger, height = HorizonWall.safariFillerStyle(
          entry.map, edgeIndex, ordinal, row)
      end
      local lo, hi
      if legacyRows or class == "pallet" then
        -- Existing Forest/Safari motifs overlap slightly because orthogonal
        -- paired cards are their closed canopy, not freestanding props.
        -- Pallet uses the same overlap to form one continuous tree line; its
        -- former 26px cards deliberately exposed six-pixel floor/sky slits.
        lo, hi = along - 4 + stagger, along + C + 4 + stagger
      else
        local half = HorizonWall.NEAR_FILL_CARD_W / 2
        local centre = along + C / 2 + stagger
        lo, hi = centre - half, centre + half
      end

      -- At every Safari turn, row 0/1/2 owns the outer/middle/inner arm pair.
      -- Centre the two orthogonal cut-outs on one world point and give them one
      -- motif/height: together they read as a conventional crossed tree rather
      -- than two unrelated paper fins. The three points walk diagonally from
      -- the far corner toward the real map, covering the otherwise flat cap.
      if safariForest and cornerInfo
         and cornerInfo.fromOuter == row then
        local cornerOrdinal = (safariCornerOrder[cornerInfo.name] or 0) * 17
        variant, stagger, height = HorizonWall.safariFillerStyle(
          entry.map, 0, cornerOrdinal, row)
        local centre = axis == "z"
          and cornerInfo.x + cornerInfo.towardX * towardMap
          or cornerInfo.z + cornerInfo.towardZ * towardMap
        lo, hi = centre - 20, centre + 20
      end
      local atlasW = HorizonWall.FOREGROUND_ATLAS_W
      local u0, u1 = (32 + variant * 32) / atlasW,
                     (32 + (variant + 1) * 32) / atlasW
      local corners
      if axis == "z" then
        corners = { { lo, 0, normal }, { hi, 0, normal },
                    { hi, height, normal }, { lo, height, normal } }
      else
        corners = { { normal, 0, hi }, { normal, 0, lo },
                    { normal, height, lo }, { normal, height, hi } }
      end
      pushQuad(foregroundVerts, foregroundIndices, corners,
        { { u0, 1 }, { u1, 1 }, { u1, 0 }, { u0, 0 } },
        Voxel3D.FACE_SHADE[(edgeIndex % 2 == 0) and 5 or 6] or 0.8)
      canopyFillerQuads = canopyFillerQuads + 1
    end
  end

  -- Two transparent, native-scale rings occupy the otherwise empty 32..64px
  -- interval between Route 8's body and its 96px distant panorama.  Geometry
  -- is rooted only in Route 8 (never in the target city/map ground), so a
  -- streamed Saffron or Lavender neighbour cannot duplicate the landmark
  -- strip or move these planes vertically.  Corner arms are admitted only as
  -- far as their ring distance.  They use the atlas' existing low shrub crop,
  -- never a house/shop/tree module: a full-height landmark pasted across a
  -- synthetic 90-degree turn reads as a card and can make a city building
  -- appear to dissolve into the forest panorama behind it.
  local function route8SeamTargetResident(edgeIndex)
    local seam = HorizonWall.route8SeamSpec(edgeIndex)
    if not seam then return false end
    for index, rect in ipairs(rects) do
      if index ~= own then
        local id = tostring(rect.map and (rect.map.id
                           or rect.map.def and rect.map.def.id) or "")
        if id == seam.target then return true end
      end
    end
    return false
  end

  local function route8MidgroundRows(axis, along, boundary, outward,
                                     edgeIndex, edgeLength)
    if not route8Owner then return end
    for row = 0, HorizonWall.ROUTE8_MIDGROUND_ROWS - 1 do
      local distance = (row + 1) * C
      if along >= -distance and along + C <= edgeLength + distance then
        local opening0, opening1 = HorizonWall.route8MidgroundOpening(
          edgeLength, edgeIndex)
        local shortFace = edgeIndex == 2 or edgeIndex == 3
        local inMainFace = along >= 0 and along < edgeLength
        local inOpening = shortFace and inMainFace
                          and along >= opening0 and along < opening1
        local occupied = HorizonWall.route8MidgroundOccupied(
          edgeIndex, along, edgeLength, row)
        local flankModule = HorizonWall.route8MidgroundFlankModule(
          edgeIndex, along, edgeLength, row)
        local cornerArm = along < 0 or along >= edgeLength
        -- A resident city owns collision on the far side of the seam.  Its
        -- canonical approach cells are walkable, so the cold-apron shrub must
        -- disappear with the fallback instead of becoming a ghost obstacle
        -- the player can walk through.
        local residentFlank = flankModule
                              and route8SeamTargetResident(edgeIndex)
        if not inOpening and occupied and not residentFlank then
          local module = HorizonWall.route8MidgroundModule(
            edgeIndex, along, edgeLength, row)
          module = flankModule or module
          local u0 = module / HorizonWall.ROUTE8_MIDGROUND_MODULES
          local u1 = (module + 1) / HorizonWall.ROUTE8_MIDGROUND_MODULES
          local v0, v1 = 0, 1
          local plane0, plane1 = along, along + C
          local planeH = HorizonWall.ROUTE8_MIDGROUND_H
          if flankModule or cornerArm then
            local shrub = HorizonWall.ROUTE8_SEAM_SHRUB
            u0 = shrub.x / HorizonWall.ROUTE8_MIDGROUND_W
            u1 = (shrub.x + shrub.w) / HorizonWall.ROUTE8_MIDGROUND_W
            v0 = shrub.y / HorizonWall.ROUTE8_MIDGROUND_H
            v1 = (shrub.y + shrub.h) / HorizonWall.ROUTE8_MIDGROUND_H
            plane0 = along + (C - shrub.w) / 2
            plane1 = plane0 + shrub.w
            planeH = shrub.h
          end
          local normal = boundary + outward * distance
          local corners
          if axis == "z" then
            corners = { { plane0, 0, normal }, { plane1, 0, normal },
                        { plane1, planeH, normal },
                        { plane0, planeH, normal } }
          else
            corners = { { normal, 0, plane1 }, { normal, 0, plane0 },
                        { normal, planeH, plane0 },
                        { normal, planeH, plane1 } }
          end
          pushQuad(route8MidgroundVerts, route8MidgroundIndices, corners,
            { { u0, v1 }, { u1, v1 }, { u1, v0 }, { u0, v0 } },
            Voxel3D.FACE_SHADE[(edgeIndex % 2 == 0) and 5 or 6] or 0.8)
          route8MidgroundQuads = route8MidgroundQuads + 1
          -- Each native plane is real table/mesh work. Charge it to the same
          -- eight-unit cooperative slice as walls and apron cells.
          checkpoint(1)
        end
      end
    end
  end

  local seaTile, seaRect
  local function edgePanel(edge, along)
    local kind, rows = HorizonWall.panelProfile(entry.map, edge, along)
    if not coastalCadence then return kind, rows end
    local horizontal = edge == "north" or edge == "south"
    local length = horizontal and entry.w or entry.h
    local stage = HorizonWall.coastalCadenceStage(
      coastalCadence.mode, edge, along, length)
    if stage == "low" then
      return HorizonWall.COASTAL_CADENCE_LOW_KIND, 0
    end
    if stage == "open_water" then return "open_water", 0 end
    return kind, rows
  end

  local function coastalWaterFoot(edgeName, along)
    if not southSeaLandFoot then return false end
    if southSeaLandFoot.mode == "south_free" then
      return edgeName == "south"
    end
    return (edgeName == "west" or edgeName == "east")
           and along >= entry.h - HorizonWall.OUTDOOR_WALL_DISTANCE
  end

  local function panelZ(x, z, outward, edgeIndex, edgeName, kind, fillerRows,
                        forceBoundary)
    local H = panelHeight(kind)
    local wallDistance = wallDistanceFor(kind, class)
    local wallZ = z + outward * (wallDistance - B)
    if not forceBoundary
       and not exteriorWallPanel("z", x, wallZ, outward, wallDistance) then
      return
    end
    local world0, world1 = entry.ox + x, entry.ox + x + C
    pushWall(kind,
      { { x, 0, wallZ }, { x + C, 0, wallZ },
        { x + C, H, wallZ }, { x, H, wallZ } },
      edgeIndex, world0, world1,
      kind == "mountain" and HorizonWall.MOUNTAIN_SHADE
      or Voxel3D.FACE_SHADE[outward < 0 and 5 or 6] or 0.8, false,
      x, x + C, entry.w)
    -- Low apron reaches back to the real map edge without adding carved
    -- voxels. Outdoor surfaces use the shared 32px lattice; closed rooms keep
    -- their historical single apron/cap quads unchanged.
    local inner = wallZ - outward * wallDistance
    local apron = { { x, 0, wallZ }, { x + C, 0, wallZ },
                    { x + C, 0, inner },
                    { x, 0, inner } }
    -- The high-view canopy/plateau extends AWAY from the playable map. The
    -- previous sign extended it inward, where a ground-level camera saw its
    -- underside as disconnected black strips floating in the sky.
    local far = wallZ + outward * D
    local cap = { { x, capY, wallZ }, { x + C, capY, wallZ },
                  { x + C, capY, far }, { x, capY, far } }
    local groundAdded
    if outdoorGround then
      if coastalWaterFoot(edgeName, x) then
        local waterEnd = inner + outward * SOUTH_SEA_LAND_FOOT_DEPTH
        groundAdded = outdoorGroundRect(x, x + C, waterEnd, far)
        coastalWaterFootQuads = coastalWaterFootQuads
          + seaRect(x, x + C, math.min(inner, waterEnd),
                    math.max(inner, waterEnd))
      else
        groundAdded = outdoorGroundRect(x, x + C, wallZ, inner)
                      + outdoorGroundRect(x, x + C, wallZ, far)
      end
    else
      pushQuad(groundVerts, groundIndices, apron,
        { groundUV(apron[1]), groundUV(apron[2]), groundUV(apron[3]),
          groundUV(apron[4]) }, Voxel3D.FACE_SHADE[3] or 1)
      pushQuad(groundVerts, groundIndices, cap,
        { groundUV(cap[1]), groundUV(cap[2]), groundUV(cap[3]),
          groundUV(cap[4]) }, Voxel3D.FACE_SHADE[3] or 1)
      groundAdded = 2
    end
    quads = quads + 1 + groundAdded
    rememberTree(kind, "z", x + C / 2, wallZ, outward, x / C,
                 entry.w / C, edgeIndex, wallDistance)
    sceneryRows("z", x, wallZ, outward, x / C, edgeIndex, fillerRows,
                wallDistance)
    ruralWallTerminals(kind, "z", x, wallZ, outward, wallDistance)
    route8MidgroundRows("z", x, edgeIndex == 0 and 0 or entry.h,
                        outward, edgeIndex, entry.w)
    checkpoint(1)
  end

  local function panelX(x, z, outward, edgeIndex, edgeName, kind, fillerRows,
                        forceBoundary)
    local H = panelHeight(kind)
    local wallDistance = wallDistanceFor(kind, class)
    local wallX = x + outward * (wallDistance - B)
    if not forceBoundary
       and not exteriorWallPanel("x", z, wallX, outward, wallDistance) then
      return
    end
    local world0, world1 = entry.oy + z, entry.oy + z + C
    -- X-facing geometry is listed south->north, hence the canonical endpoint
    -- UVs are reversed for every family, not only for mountains.
    pushWall(kind,
      { { wallX, 0, z + C }, { wallX, 0, z },
        { wallX, H, z }, { wallX, H, z + C } },
      edgeIndex, world0, world1,
      kind == "mountain" and HorizonWall.MOUNTAIN_SHADE
      or Voxel3D.FACE_SHADE[outward < 0 and 1 or 2] or 0.8, true,
      z, z + C, entry.h)
    local inner = wallX - outward * wallDistance
    local apron = { { wallX, 0, z }, { wallX, 0, z + C },
                    { inner, 0, z + C }, { inner, 0, z } }
    local far = wallX + outward * D
    local cap = { { wallX, capY, z }, { wallX, capY, z + C },
                  { far, capY, z + C }, { far, capY, z } }
    local groundAdded
    if outdoorGround then
      if coastalWaterFoot(edgeName, z) then
        local waterEnd = inner + outward * SOUTH_SEA_LAND_FOOT_DEPTH
        groundAdded = outdoorGroundRect(waterEnd, far, z, z + C)
        coastalWaterFootQuads = coastalWaterFootQuads
          + seaRect(math.min(inner, waterEnd), math.max(inner, waterEnd),
                    z, z + C)
      else
        groundAdded = outdoorGroundRect(wallX, inner, z, z + C)
                      + outdoorGroundRect(wallX, far, z, z + C)
      end
    else
      pushQuad(groundVerts, groundIndices, apron,
        { groundUV(apron[1]), groundUV(apron[2]), groundUV(apron[3]),
          groundUV(apron[4]) }, Voxel3D.FACE_SHADE[3] or 1)
      pushQuad(groundVerts, groundIndices, cap,
        { groundUV(cap[1]), groundUV(cap[2]), groundUV(cap[3]),
          groundUV(cap[4]) }, Voxel3D.FACE_SHADE[3] or 1)
      groundAdded = 2
    end
    quads = quads + 1 + groundAdded
    rememberTree(kind, "x", z + C / 2, wallX, outward, z / C,
                 entry.h / C, edgeIndex, wallDistance)
    sceneryRows("x", z, wallX, outward, z / C, edgeIndex, fillerRows,
                wallDistance)
    ruralWallTerminals(kind, "x", z, wallX, outward, wallDistance)
    route8MidgroundRows("x", z, edgeIndex == 2 and 0 or entry.w,
                        outward, edgeIndex, entry.h)
    checkpoint(1)
  end

  seaTile = function(x, z)
    local key = worldCellKey(x, z)
    if sharedSeaCells[key] then return 0 end
    sharedSeaCells[key] = true
    local y = HorizonWall.SEA_LEVEL
    local p = { { x, y, z }, { x + C, y, z },
                { x + C, y, z + C }, { x, y, z + C } }
    local uv = {}
    for i = 1, 4 do uv[i] = { p[i][1] / C, p[i][3] / C } end
    pushQuad(seaVerts, seaIndices, p, uv, Voxel3D.FACE_SHADE[3] or 1)
    seaQuads = seaQuads + 1
    checkpoint(1)
    return 1
  end

  seaRect = function(x0, x1, z0, z1)
    local added = 0
    for x = x0, x1 - C, C do
      for z = z0, z1 - C, C do added = added + seaTile(x, z) end
    end
    return added
  end

  local open, seaOpen = {}, {}
  local waterPanels = { north = {}, south = {}, west = {}, east = {} }
  local E = B + HorizonWall.SEA_DEPTH
  -- Far outdoor walls follow the actual union boundary. The old one-block
  -- per-map overhang was harmless while wall distance equalled one block, but
  -- at 96px it became an isolated perpendicular fin whenever the next map was
  -- resident. Closed rooms retain the compact historical overhang verbatim.
  local alongStart = outdoorGround and 0 or -B
  local alongEndX = outdoorGround and entry.w - C or entry.w + B - C
  local alongEndZ = outdoorGround and entry.h - C or entry.h + B - C
  for x = alongStart, alongEndX, C do
    local gx = entry.ox + x + C / 2
    -- Outside detects a north/south connection; inside prevents one owner
    -- from drawing through a perpendicular neighbour at a union corner.
    local north = not covered(rects, own, gx, entry.oy - 1)
                  and not covered(rects, own, gx, entry.oy + 1)
    local south = not covered(rects, own, gx, entry.oy + entry.h + 1)
                  and not covered(rects, own, gx, entry.oy + entry.h - 1)
    if north then
      local kind, rows = edgePanel("north", x)
      if kind == "open_water" then
        if x >= 0 and x < entry.w then seaRect(x, x + C, -E, 0) end
        if x >= 0 and x < entry.w then waterPanels.north[x] = true end
      else
        panelZ(x, -B, -1, 0, "north", kind, rows)
      end
    end
    if south then
      local kind, rows = edgePanel("south", x)
      if kind == "open_water" then
        if x >= 0 and x < entry.w then
          seaRect(x, x + C, entry.h, entry.h + E)
          waterPanels.south[x] = true
        end
      else
        panelZ(x, entry.h + B, 1, 1, "south", kind, rows)
      end
    end
    local northWater = edgePanel("north", x) == "open_water"
    local southWater = edgePanel("south", x) == "open_water"
    if outdoorGround then
      -- Independent tests matter for a one-cell map, where both ends are the
      -- same panel. These flags describe the union's first/last real cells,
      -- never a synthetic per-owner overhang.
      if x == 0 then
        open.nwN = north and not northWater
        open.swS = south and not southWater
        seaOpen.nwN = north and northWater
        seaOpen.swS = south and southWater
      end
      if x == entry.w - C then
        open.neN = north and not northWater
        open.seS = south and not southWater
        seaOpen.neN = north and northWater
        seaOpen.seS = south and southWater
      end
    elseif x == -B then
      -- Cave/tower corner ownership stays byte-for-byte on the old apron.
      open.nwN = north and not northWater
      open.swS = south and not southWater
    elseif x == entry.w then
      open.neN = north and not northWater
      open.seS = south and not southWater
    end
  end
  for z = alongStart, alongEndZ, C do
    local gz = entry.oy + z + C / 2
    local west = not covered(rects, own, entry.ox - 1, gz)
                 and not covered(rects, own, entry.ox + 1, gz)
    local east = not covered(rects, own, entry.ox + entry.w + 1, gz)
                 and not covered(rects, own, entry.ox + entry.w - 1, gz)
    if west then
      local kind, rows = edgePanel("west", z)
      if kind == "open_water" then
        if z >= 0 and z < entry.h then seaRect(-E, 0, z, z + C) end
        if z >= 0 and z < entry.h then waterPanels.west[z] = true end
      else
        panelX(-B, z, -1, 2, "west", kind, rows)
      end
    end
    if east then
      local kind, rows = edgePanel("east", z)
      if kind == "open_water" then
        if z >= 0 and z < entry.h then
          seaRect(entry.w, entry.w + E, z, z + C)
          waterPanels.east[z] = true
        end
      else
        panelX(entry.w + B, z, 1, 3, "east", kind, rows)
      end
    end
    local westWater = edgePanel("west", z) == "open_water"
    local eastWater = edgePanel("east", z) == "open_water"
    if outdoorGround then
      if z == 0 then
        open.nwW = west and not westWater
        open.neE = east and not eastWater
        seaOpen.nwW = west and westWater
        seaOpen.neE = east and eastWater
      end
      if z == entry.h - C then
        open.swW = west and not westWater
        open.seE = east and not eastWater
        seaOpen.swW = west and westWater
        seaOpen.seE = east and eastWater
      end
    elseif z == -B then
      open.nwW = west and not westWater
      open.neE = east and not eastWater
    elseif z == entry.h then
      open.swW = west and not westWater
      open.seE = east and not eastWater
    end
  end

  -- Main outdoor panels end on the true map/union cells. Three native-width
  -- panels per arm then cover the complete 96px turn at each exposed 90-degree
  -- corner. Each side keeps its own semantic texture up to the join, so
  -- city/mountain mixes do not smear one asset diagonally and the turn adds no
  -- draw family. Closed rooms still use their historical one-block overhang.
  local wallB = isEnclosure(class) and B
                or wallDistanceFor(nil, class)
  local function cornerPanelZ(x, z, outward, edgeIndex, edgeName,
                              forcedKind, forcedRows, forceBoundary,
                              cornerInfo)
    local kind, rows = forcedKind, forcedRows
    if not kind then kind, rows = edgePanel(edgeName, x) end
    local H = panelHeight(kind)
    if not forceBoundary
       and not exteriorWallPanel("z", x, z, outward,
                                 wallDistanceFor(kind, class)) then
      return
    end
    local world0, world1 = entry.ox + x, entry.ox + x + C
    local phase0, phase1
    if safariForest and kind == "forest" and cornerInfo then
      phase0, phase1 = HorizonWall.safariCornerPanelPhases(
        cornerInfo.name, cornerInfo.panelIndex, cornerInfo.outerAtStart)
    end
    pushWall(kind,
      { { x, 0, z }, { x + C, 0, z }, { x + C, H, z }, { x, H, z } },
      edgeIndex, world0, world1,
      kind == "mountain" and HorizonWall.MOUNTAIN_SHADE
      or Voxel3D.FACE_SHADE[outward < 0 and 5 or 6] or 0.8, false,
      x, x + C, entry.w, phase0, phase1)
    local far = z + outward * D
    local groundAdded = outdoorGroundRect(x, x + C, z, far)
    sceneryRows("z", x, z, outward, x / C, edgeIndex, rows, wallB,
                cornerInfo)
    ruralWallTerminals(kind, "z", x, z, outward,
                       wallDistanceFor(kind, class))
    route8MidgroundRows("z", x, edgeIndex == 0 and 0 or entry.h,
                        outward, edgeIndex, entry.w)
    quads = quads + 1 + groundAdded
    checkpoint(1)
  end
  local function cornerPanelX(x, z, outward, edgeIndex, edgeName,
                              forcedKind, forcedRows, forceBoundary,
                              cornerInfo)
    local kind, rows = forcedKind, forcedRows
    if not kind then kind, rows = edgePanel(edgeName, z) end
    local H = panelHeight(kind)
    if not forceBoundary
       and not exteriorWallPanel("x", z, x, outward,
                                 wallDistanceFor(kind, class)) then
      return
    end
    local world0, world1 = entry.oy + z, entry.oy + z + C
    local phase0, phase1
    if safariForest and kind == "forest" and cornerInfo then
      phase0, phase1 = HorizonWall.safariCornerPanelPhases(
        cornerInfo.name, cornerInfo.panelIndex, cornerInfo.outerAtStart)
    end
    pushWall(kind,
      { { x, 0, z + C }, { x, 0, z }, { x, H, z }, { x, H, z + C } },
      edgeIndex, world0, world1,
      kind == "mountain" and HorizonWall.MOUNTAIN_SHADE
      or Voxel3D.FACE_SHADE[outward < 0 and 1 or 2] or 0.8, true,
      z, z + C, entry.h, phase0, phase1)
    local far = x + outward * D
    local groundAdded = outdoorGroundRect(x, far, z, z + C)
    sceneryRows("x", z, x, outward, z / C, edgeIndex, rows, wallB,
                cornerInfo)
    ruralWallTerminals(kind, "x", z, x, outward,
                       wallDistanceFor(kind, class))
    route8MidgroundRows("x", z, edgeIndex == 2 and 0 or entry.w,
                        outward, edgeIndex, entry.h)
    quads = quads + 1 + groundAdded
    checkpoint(1)
  end
  local function innerCorner(x0, x1, z0, z1)
    quads = quads + outdoorGroundRect(x0, x1, z0, z1)
  end
  local function forestCornerInfo(name, panelIndex, outerAtStart, fromOuter,
                                  x, z, towardX, towardZ)
    if not safariForest then return nil end
    return { name = name, panelIndex = panelIndex,
             outerAtStart = outerAtStart, fromOuter = fromOuter,
             x = x, z = z, towardX = towardX, towardZ = towardZ }
  end
  if outdoorGround and wallB >= B then
    if open.nwN and open.nwW then
      for x = -wallB, -C, C do
        local i = (x + wallB) / C
        cornerPanelZ(x, -wallB, -1, 0, "north", nil, nil, nil,
          forestCornerInfo("nw", i, true, i, -wallB, -wallB, 1, 1))
      end
      for z = -wallB, -C, C do
        local i = (z + wallB) / C
        cornerPanelX(-wallB, z, -1, 2, "west", nil, nil, nil,
          forestCornerInfo("nw", i, true, i, -wallB, -wallB, 1, 1))
      end
      innerCorner(-wallB, 0, -wallB, 0)
    end
    if open.neN and open.neE then
      for x = entry.w, entry.w + wallB - C, C do
        local i = (x - entry.w) / C
        cornerPanelZ(x, -wallB, -1, 0, "north", nil, nil, nil,
          forestCornerInfo("ne", i, false, 2 - i,
            entry.w + wallB, -wallB, -1, 1))
      end
      for z = -wallB, -C, C do
        local i = (z + wallB) / C
        cornerPanelX(entry.w + wallB, z, 1, 3, "east", nil, nil, nil,
          forestCornerInfo("ne", i, true, i,
            entry.w + wallB, -wallB, -1, 1))
      end
      innerCorner(entry.w, entry.w + wallB, -wallB, 0)
    end
    if open.swS and open.swW then
      for x = -wallB, -C, C do
        local i = (x + wallB) / C
        cornerPanelZ(x, entry.h + wallB, 1, 1, "south", nil, nil, nil,
          forestCornerInfo("sw", i, true, i,
            -wallB, entry.h + wallB, 1, -1))
      end
      for z = entry.h, entry.h + wallB - C, C do
        local i = (z - entry.h) / C
        cornerPanelX(-wallB, z, -1, 2, "west", nil, nil, nil,
          forestCornerInfo("sw", i, false, 2 - i,
            -wallB, entry.h + wallB, 1, -1))
      end
      innerCorner(-wallB, 0, entry.h, entry.h + wallB)
    end
    if open.seS and open.seE then
      for x = entry.w, entry.w + wallB - C, C do
        local i = (x - entry.w) / C
        cornerPanelZ(x, entry.h + wallB, 1, 1, "south", nil, nil, nil,
          forestCornerInfo("se", i, false, 2 - i,
            entry.w + wallB, entry.h + wallB, -1, -1))
      end
      for z = entry.h, entry.h + wallB - C, C do
        local i = (z - entry.h) / C
        cornerPanelX(entry.w + wallB, z, 1, 3, "east", nil, nil, nil,
          forestCornerInfo("se", i, false, 2 - i,
            entry.w + wallB, entry.h + wallB, -1, -1))
      end
      innerCorner(entry.w, entry.w + wallB,
                  entry.h, entry.h + wallB)
    end
  end

  -- A harbour end meeting open sea is neither a wall/wall corner nor a
  -- water/water corner.  Leaving it to the two homogeneous cases stopped the
  -- painted harbour wall in mid-air and exposed an empty diagonal quadrant.
  -- Turn the wall back to the real shoreline over the full 96px offset, then
  -- continue the water around it.  The cap is y=0 and the sea is y=-2, so the
  -- coast has real depth without two coplanar surfaces fighting.
  local function profileAtCorner(edge, atEnd)
    local horizontal = edge == "north" or edge == "south"
    local length = horizontal and entry.w or entry.h
    return edgePanel(edge, atEnd and math.max(0, length - C) or 0)
  end

  local nwMixed = open.nwN and seaOpen.nwW
                  or seaOpen.nwN and open.nwW
  if nwMixed then
    if open.nwN then
      local kind, rows = profileAtCorner("north", false)
      for z = -wallB, -C, C do
        cornerPanelX(0, z, -1, 0, "north", kind, rows, true)
      end
    else
      local kind, rows = profileAtCorner("west", false)
      for x = -wallB, -C, C do
        cornerPanelZ(x, 0, -1, 2, "west", kind, rows, true)
      end
    end
    seaRect(-E, 0, -E, 0)
  end

  local neMixed = open.neN and seaOpen.neE
                  or seaOpen.neN and open.neE
  if neMixed then
    if open.neN then
      local kind, rows = profileAtCorner("north", true)
      for z = -wallB, -C, C do
        cornerPanelX(entry.w, z, 1, 0, "north", kind, rows, true)
      end
    else
      local kind, rows = profileAtCorner("east", false)
      for x = entry.w, entry.w + wallB - C, C do
        cornerPanelZ(x, 0, -1, 3, "east", kind, rows, true)
      end
    end
    seaRect(entry.w, entry.w + E, -E, 0)
  end

  local swMixed = open.swS and seaOpen.swW
                  or seaOpen.swS and open.swW
  if swMixed then
    if open.swS then
      local kind, rows = profileAtCorner("south", false)
      for z = entry.h, entry.h + wallB - C, C do
        cornerPanelX(0, z, -1, 1, "south", kind, rows, true)
      end
    else
      local kind, rows = profileAtCorner("west", true)
      for x = -wallB, -C, C do
        cornerPanelZ(x, entry.h, 1, 2, "west", kind, rows, true)
      end
    end
    seaRect(-E, 0, entry.h, entry.h + E)
  end

  local seMixed = open.seS and seaOpen.seE
                  or seaOpen.seS and open.seE
  if seMixed then
    if open.seS then
      local kind, rows = profileAtCorner("south", true)
      for z = entry.h, entry.h + wallB - C, C do
        cornerPanelX(entry.w, z, 1, 1, "south", kind, rows, true)
      end
    else
      local kind, rows = profileAtCorner("east", true)
      for x = entry.w, entry.w + wallB - C, C do
        cornerPanelZ(x, entry.h, 1, 3, "east", kind, rows, true)
      end
    end
    seaRect(entry.w, entry.w + E, entry.h, entry.h + E)
  end

  -- Adjacent sea strips meet in a separately tessellated outer quadrant.
  -- Keeping the strips and the corner disjoint prevents coplanar overlap and
  -- the shimmer it causes in the reflective water pass.
  if seaOpen.nwN and seaOpen.nwW then seaRect(-E, 0, -E, 0) end
  if seaOpen.neN and seaOpen.neE then seaRect(entry.w, entry.w + E, -E, 0) end
  if seaOpen.swS and seaOpen.swW then
    seaRect(-E, 0, entry.h, entry.h + E)
  end
  if seaOpen.seS and seaOpen.seE then
    seaRect(entry.w, entry.w + E, entry.h, entry.h + E)
  end

  -- Sparse canonical coastal motifs. Each maritime map owns one fixed atlas
  -- module on one fixed free edge. A bounded sprite is admitted only when the
  -- three centre water panels are genuinely free, so streaming can hide it
  -- but never move/re-skin it or expose it across a connection.
  --
  -- Keep the billboard in the one shared coastal mesh, but split its plane on
  -- the same <=32px lattice as the water below it. WorldCurve is quadratic:
  -- one 96px chord would put the middle of the painted shoreline 2.88px below
  -- the tessellated sea at the strongest 144px view, visibly drowning the
  -- centre of a small island. Three quads cost no draw and keep that midpoint
  -- error at 0.32px. UVs advance continuously through the atlas module, so a
  -- split can never introduce an image seam.
  local id = tostring(entry.map.id or entry.map.def.id or "")
  local landmark = HorizonWall.COASTAL_LANDMARKS[id]
  if landmark then
    local edgeIndexByName = { north=1, south=2, west=3, east=4 }
    local edge, variant = landmark.edge, landmark.variant
    local module = HorizonWall.COASTAL_MODULES[variant]
    local edgeIndex = edgeIndexByName[edge]
    local horizontal = edgeIndex <= 2
    local length = horizontal and entry.w or entry.h
    local panelCount = math.floor(length / C)
    -- Reserve the map-centre candidate before coverage is inspected. Three
    -- cells are enough for Dock's short original edge; longer shores remain
    -- centred and never reshuffle toward a newly exposed gap.
    local centrePanel = math.max(1, math.min(panelCount - 2,
      math.floor((panelCount - 1) / 2)))
    local localAlong = centrePanel * C
    local clear = panelCount >= 3
                  and waterPanels[edge][localAlong - C]
                  and waterPanels[edge][localAlong]
                  and waterPanels[edge][localAlong + C]
    if clear and module then
      local u0 = (variant * 128 + module.x) / 512
      local u1 = (variant * 128 + module.x + module.w) / 512
      local vTop = module.y / 128
      local vBottom = (module.y + module.h) / 128
      local centre = localAlong + C / 2
      local landmarkW = module.w
      local landmarkH = module.h
      local half = landmarkW / 2
      local lo, hi = centre - half, centre + half
      local y0 = HorizonWall.SEA_LEVEL
      local y1 = y0 + landmarkH
      local distance = B + math.floor(HorizonWall.SEA_DEPTH * 0.55)
      local alongStart = horizontal and lo or hi
      local alongDirection = horizontal and 1 or -1
      local shade = Voxel3D.FACE_SHADE[horizontal and 5 or 1] or 0.84
      local offset = 0
      while offset < landmarkW do
        local segmentW = math.min(C, landmarkW - offset)
        local along0 = alongStart + alongDirection * offset
        local along1 = alongStart + alongDirection * (offset + segmentW)
        local t0, t1 = offset / landmarkW,
                             (offset + segmentW) / landmarkW
        local su0 = u0 + (u1 - u0) * t0
        local su1 = u0 + (u1 - u0) * t1
        local corners
        if horizontal then
          local z = edge == "north" and -distance or entry.h + distance
          corners = { { along0, y0, z }, { along1, y0, z },
                      { along1, y1, z }, { along0, y1, z } }
        else
          local x = edge == "west" and -distance or entry.w + distance
          corners = { { x, y0, along0 }, { x, y0, along1 },
                      { x, y1, along1 }, { x, y1, along0 } }
        end
        pushQuad(coastalVerts, coastalIndices, corners,
          { { su0, vBottom }, { su1, vBottom },
            { su1, vTop }, { su0, vTop } }, shade)
        coastalQuads = coastalQuads + 1
        offset = offset + segmentW
      end
    end
  end

  -- The four long cap strips form a plus around an isolated map. Fill their
  -- outer quadrants when both adjoining edge arms exist; without these four
  -- quads an orbit camera looked straight through D-by-D holes at the corners.
  local function corner(x0, x1, z0, z1)
    if outdoorGround then
      quads = quads + outdoorGroundRect(x0, x1, z0, z1)
    else
      local p = { { x0, capY, z0 }, { x1, capY, z0 },
                  { x1, capY, z1 }, { x0, capY, z1 } }
      local uv = {}
      for i = 1, 4 do uv[i] = groundUV(p[i]) end
      pushQuad(groundVerts, groundIndices, p, uv,
               Voxel3D.FACE_SHADE[3] or 1)
      quads = quads + 1
    end
  end
  if open.nwN and open.nwW then
    corner(-wallB - D, -wallB, -wallB - D, -wallB)
  end
  if open.neN and open.neE then
    corner(entry.w + wallB, entry.w + wallB + D,
           -wallB - D, -wallB)
  end
  if open.swS and open.swW then
    corner(-wallB - D, -wallB,
           entry.h + wallB, entry.h + wallB + D)
  end
  if open.seS and open.seE then
    corner(entry.w + wallB, entry.w + wallB + D,
           entry.h + wallB, entry.h + wallB + D)
  end

  -- A tall perimeter alone still leaves the renderer's black clear colour
  -- visible whenever 1ST/3RD looks above it. Closed maps receive a 32px-grid
  -- downward-facing ceiling in the existing ground mesh. It spans the body and
  -- its apron exactly, meets every wall at y=H and repeats the same small
  -- material texture. The grid is important under WorldCurve: the vertex
  -- shader can follow the quadratic every cell instead of turning one huge
  -- four-corner quad into a sagging chord. This adds neither a texture nor a
  -- draw call, and its CPU work is charged to the cooperative build budget.
  local ceilingQuads = 0
  if isEnclosure(class) then
    local H = enclosureH
    local x0, x1, z0, z1 = -B, entry.w + B, -B, entry.h + B
    local ceilingSinceCheckpoint = 0
    for z = z0, z1 - C, C do
      for x = x0, x1 - C, C do
        local ceiling = {
          { x, H, z }, { x + C, H, z },
          { x + C, H, z + C }, { x, H, z + C },
        }
        local uv = {}
        for i = 1, 4 do
          uv[i] = groundUV(ceiling[i])
        end
        pushQuad(groundVerts, groundIndices, ceiling, uv,
                 Voxel3D.FACE_SHADE[4] or 0.55)
        ceilingQuads = ceilingQuads + 1
        quads = quads + 1
        ceilingSinceCheckpoint = ceilingSinceCheckpoint + 1
        if ceilingSinceCheckpoint
             >= HorizonWall.CEILING_QUADS_PER_BUILD_UNIT then
          checkpoint(1)
          ceilingSinceCheckpoint = 0
        end
      end
    end
  end

  local treeCount = math.min(#treeSpots, HorizonWall.FOREGROUND_TREE_CAP)
  for i = 1, treeCount do
    local spot = treeSpots[i]
    local row = (spot.ordinal + spot.edgeIndex) % 2
    -- Keep both solid trees inside the expanded apron: one reinforces the far
    -- silhouette, the other supplies near parallax without touching gameplay.
    local beltDepth = spot.beltDepth or B
    local towardMap = row == 0 and beltDepth * 0.35
                      or beltDepth * 0.72
    local stagger = ((spot.ordinal * 7 + spot.edgeIndex * 5) % 3 - 1) * 3
    local radius = 7 + ((spot.ordinal + spot.edgeIndex) % 2)
    local height = 50 + ((spot.ordinal * 3 + spot.edgeIndex) % 3) * 4
    local normal = spot.wall - spot.outward * towardMap
    local x, z
    if spot.axis == "z" then
      x, z = spot.along + stagger, normal
    else
      x, z = normal, spot.along + stagger
    end
    pushForegroundTree(foregroundVerts, foregroundIndices,
                       x, z, height, radius)
    checkpoint(2)
  end
  local foregroundQuads = treeCount * HorizonWall.FOREGROUND_TREE_QUADS
                          + canopyFillerQuads + ruralTerminalQuads

  local wallGroups = {}
  for _, family in ipairs({ "route8", "regional", "mountain", "mt_moon",
                            "cave", "tower", "pokecenter_room" }) do
    local group = wallGroupsByFamily[family]
    if group and #group.vertices > 0 then wallGroups[#wallGroups + 1] = group end
  end
  if #wallVerts == 0 and #seaVerts == 0 and ceilingQuads == 0
     and #coastalVerts == 0 then return nil end
  return { map = entry.map, ox = entry.ox, oy = entry.oy, class = class,
           material = material, groundPeriod = groundPeriod,
           wallVertices = wallVerts, wallIndices = wallIndices,
           wallGroups = wallGroups, wallDraws = #wallGroups,
           groundVertices = groundVerts, groundIndices = groundIndices,
           foregroundVertices = foregroundVerts,
           foregroundIndices = foregroundIndices,
           route8MidgroundVertices = route8MidgroundVerts,
           route8MidgroundIndices = route8MidgroundIndices,
           route8MidgroundQuads = route8MidgroundQuads,
           route8SeamFlankQuads = route8SeamFlankQuads,
           route8SeamPathVertices = route8SeamPathVerts,
           route8SeamPathIndices = route8SeamPathIndices,
           route8SeamPathQuads = route8SeamPathQuads,
           route8SeamPathQuadsByEdge = route8SeamPathQuadsByEdge,
           route8SeamPathMap = route8SeamPathQuads > 0 and entry.map or nil,
           forestGatePathVertices = forestGatePathVerts,
           forestGatePathIndices = forestGatePathIndices,
           forestGatePathQuads = forestGatePathQuads,
           forestGatePathQuadsByEdge = forestGatePathQuadsByEdge,
           forestGatePathMap = forestGatePathQuads > 0 and entry.map or nil,
           forestGateEdges = forestGateEdges,
           forestGateFacadeVertices = forestGateFacadeVerts,
           forestGateFacadeIndices = forestGateFacadeIndices,
           forestGateFacadeQuads = forestGateFacadeQuads,
           forestGateFillerSuppressed = forestGateFillerSuppressed,
           foregroundTrees = treeCount,
           canopyFillerQuads = canopyFillerQuads,
           ruralTerminalQuads = ruralTerminalQuads,
           canopyCrownQuads = canopyCrownQuads,
           fillerQuads = canopyFillerQuads,
           foregroundQuads = foregroundQuads,
           ceilingQuads = ceilingQuads,
           seaVertices = seaVerts, seaIndices = seaIndices,
           seaQuads = seaQuads,
           coastalWaterFootQuads = coastalWaterFootQuads,
           coastalVertices = coastalVerts, coastalIndices = coastalIndices,
           coastalQuads = coastalQuads,
           quads = quads + seaQuads + foregroundQuads + coastalQuads
                   + route8MidgroundQuads + route8SeamPathQuads
                   + forestGatePathQuads + forestGateFacadeQuads }
end

function HorizonWall.geometry(state)
  if not HorizonWall.enabled()
     or not (state and state.map and state.map.def and state.map.tileset) then
    return {}
  end
  local maps, out = mapsOf(state), {}
  local groundCells, seaCells, ruralTerminals = {}, {}, {}
  for i, e in ipairs(maps) do
    local g = geometryFor(e, i, maps, nil, groundCells, seaCells,
                          ruralTerminals)
    if g then out[#out + 1] = g end
  end
  return out
end

-- ------- the generated skyline image

local textures, textureFailures = {}, {}
local compactImage, bakeCompact, fujiTexture, releaseImage

local function pixelRect(g, color, x, y, w, h)
  g.setColor(color[1], color[2], color[3], color[4] or 1)
  g.rectangle("fill", x, y, w, h)
end

local function treeRect(g, color, x, y, w, h)
  local q = HorizonWall.ART_GRID
  local x0, y0 = math.floor(x / q) * q, math.floor(y / q) * q
  local x1 = math.ceil((x + w) / q) * q
  local y1 = math.ceil((y + h) / q) * q
  pixelRect(g, color, x0, y0, math.max(q, x1 - x0),
            math.max(q, y1 - y0))
end

-- A small, original Kanto panorama assembled entirely from rectangles on the
-- authored 2px grid. It is painted INTO the same cached skyline Canvas as the
-- trees/buildings below it, so these extra layers cost no draw call, texture
-- sample or per-frame animation on mobile. The world mesh provides the anchor:
-- unlike a camera-facing sky dome, the peak cannot turn with the player.
--
-- Large colour fields and one principal peak are deliberate. Repeating many
-- detailed summits around a 128px strip looked noisy and made every route feel
-- alpine; the lower blue/green ridges carry most of the depth instead.
local function panoramaPeak(g, center, top, base, halfWidth, snowLine)
  local q = HorizonWall.ART_GRID
  local stone = { 0.34, 0.43, 0.48 }
  local lit = { 0.45, 0.54, 0.55 }
  local shadow = { 0.23, 0.33, 0.40 }
  local snow = { 0.76, 0.79, 0.73 }
  local snowShade = { 0.59, 0.66, 0.67 }
  for y = top, base - q, q do
    local t = (y - top) / math.max(1, base - top)
    local radius = math.floor((q + (halfWidth - q) * t) / q) * q
    radius = math.max(q, radius)
    local left = math.floor((center - radius) / q) * q
    local width = math.ceil((radius * 2) / q) * q
    local snowy = y < snowLine
    pixelRect(g, snowy and snow or stone, left, y, width, q)

    -- Two broad facets survive perspective minification but do not turn the
    -- pale cap into a zebra pattern. Their stepped boundary reads as snow
    -- fingers at the transition and as rock strata lower down.
    local lightWidth = math.max(q, math.floor(width * 0.30 / q) * q)
    local shadeWidth = math.max(q, math.floor(width * 0.34 / q) * q)
    pixelRect(g, snowy and snow or lit, left, y, lightWidth, q)
    pixelRect(g, snowy and snowShade or shadow,
              left + width - shadeWidth, y, shadeWidth, q)
  end
end

local function panoramaRidge(g, W, tops, base, fill, rim)
  local q = HorizonWall.ART_GRID
  local columns = #tops
  local step = W / columns
  for i = 1, columns do
    local x = math.floor(((i - 1) * step) / q) * q
    local nextX = math.floor((i * step) / q) * q
    local top = math.floor(tops[i] / q) * q
    pixelRect(g, fill, x, top, math.max(q, nextX - x), base - top)
    if rim then pixelRect(g, rim, x, top, math.max(q, nextX - x), q) end
  end
end

local function kantoPanorama(g, W, H, mountain, mainBearing)
  -- The first and last samples agree so the baked strip wraps without a
  -- visible cliff. Transparent texels remain above every silhouette and let
  -- the real day/night sky, sun and clouds show through unchanged. Only the
  -- north-bearing atlas quarter receives the pale landmark; other bearings
  -- get a lower, un-capped crag so rotation never reveals four copies.
  if mainBearing then
    panoramaPeak(g, 34, mountain and 8 or 12, 66, mountain and 32 or 28,
                 mountain and 26 or 28)
  else
    panoramaPeak(g, 34, 32, 66, 18, 32)
  end
  panoramaPeak(g, 94, 28, 66, 20, 28) -- distant crag; no second snow cap

  panoramaRidge(g, W,
    { 48, 46, 42, 44, 48, 50, 46, 42,
      44, 48, 50, 46, 42, 44, 48, 48 },
    76, { 0.20, 0.39, 0.48 }, { 0.31, 0.49, 0.54 })
  panoramaRidge(g, W,
    { 58, 54, 50, 52, 56, 60, 58, 52,
      48, 50, 54, 58, 56, 52, 54, 58 },
    84, { 0.16, 0.36, 0.22 }, { 0.24, 0.46, 0.26 })
  panoramaRidge(g, W,
    { 68, 64, 60, 62, 66, 68, 64, 60,
      62, 66, 68, 64, 60, 62, 66, 68 },
    H, { 0.09, 0.27, 0.15 }, { 0.16, 0.38, 0.18 })
end

local function treeSkyline(g, W, H)
  -- Strong value steps are intentional. The old strip used several small,
  -- similarly coloured 5px marks; perspective and the optional post-process
  -- averaged those into a soft patch on only the distant/oblique panels.
  -- Broad dark contours plus >=4px highlights keep individual crowns legible
  -- without changing the number of meshes or texture samples.
  local deep = { 0.045, 0.14, 0.06 }
  local outline = { 0.065, 0.22, 0.08 }
  local dark = { 0.09, 0.30, 0.12 }
  local greens = {
    { 0.16, 0.46, 0.18 }, { 0.11, 0.37, 0.15 },
    { 0.22, 0.54, 0.21 }, { 0.13, 0.40, 0.15 },
  }
  -- A second, distant crown line closes gaps between the foreground trees.
  treeRect(g, deep, 0, 54, W, H - 54)
  for x = 0, W - 1, 8 do
    local rise = ({ 8, 2, 6, 0, 6, 4, 10, 2 })[(x / 8) % 8 + 1]
    treeRect(g, deep, x, 46 + rise, 8, 14)
  end
  local heights = { 76, 60, 68, 64, 80, 60, 72, 56 }
  for i = 0, 7 do
    local cx, height = i * 16 + 8, heights[i + 1]
    local top, green = H - height, greens[i % #greens + 1]
    -- Visible trunks and separated lower boughs make the strip read as trees,
    -- not as a single green battlement, even close to a first-person camera.
    treeRect(g, { 0.27, 0.15, 0.055 }, cx - 2, H - 36, 4, 36)

    -- One contiguous, dark silhouette first. The coloured tiers are inset,
    -- leaving a hard two-pixel outline rather than several soft overlaps.
    treeRect(g, outline, cx - 4, top, 8, 8)
    treeRect(g, outline, cx - 8, top + 4, 16, 14)
    treeRect(g, outline, cx - 12, top + 12, 24, 18)
    treeRect(g, outline, cx - 14, top + 24, 28, 18)
    treeRect(g, outline, cx - 10, top + 38, 20, 14)
    treeRect(g, dark, cx - 2, top + 2, 4, 6)
    treeRect(g, green, cx - 6, top + 6, 12, 10)
    treeRect(g, green, cx - 10, top + 14, 20, 14)
    treeRect(g, green, cx - 12, top + 26, 24, 14)
    treeRect(g, green, cx - 8, top + 40, 16, 10)

    -- Highlights are deliberately 4x4: smaller flecks disappeared first at
    -- oblique map edges and made only those forest panels look out of focus.
    treeRect(g, { 0.34, 0.64, 0.25 }, cx - 6, top + 10, 4, 4)
    if i % 3 == 1 then
      treeRect(g, { 0.28, 0.57, 0.22 }, cx + 4, top + 28, 4, 4)
    end
  end
  treeRect(g, dark, 0, H - 14, W, 14)
  for x = 4, W - 1, 16 do
    treeRect(g, { 0.20, 0.47, 0.17 }, x, H - 18, 8, 4)
  end
end

local function viridianSkyline(g, W, H)
  -- The city is a compact Game Boy-era town, not a modern skyline. Paint a
  -- recessed tree line first; the low shop/house facades below then occlude
  -- it, leaving distant sprite trees visible only between roofs and in the
  -- upper gaps. The nearby rows are real geometry (pushForegroundTree).
  local treeDeep = { 0.045, 0.14, 0.06 }
  local treeDark = { 0.07, 0.24, 0.09 }
  local treeMid = { 0.13, 0.36, 0.13 }
  treeRect(g, treeDeep, 0, 58, W, H - 58)
  local treeTops = { 40, 48, 34, 44, 38, 50, 32, 42 }
  for i = 0, 7 do
    local x, top = i * 16, treeTops[i + 1]
    treeRect(g, { 0.23, 0.14, 0.055 }, x + 6, top + 24, 4, H - top - 24)
    treeRect(g, treeDark, x + 4, top, 8, 8)
    treeRect(g, treeDark, x + 2, top + 6, 12, 10)
    treeRect(g, treeDark, x, top + 14, 16, 12)
    treeRect(g, treeMid, x + 4, top + 8, 8, 8)
    treeRect(g, treeMid, x + 2, top + 16, 12, 8)
  end

  local facades = {
    { -8, 30, 34, { 0.55, 0.43, 0.27 }, { 0.47, 0.17, 0.12 } },
    { 26, 22, 20, { 0.60, 0.54, 0.36 }, { 0.34, 0.20, 0.16 } },
    { 52, 32, 38, { 0.49, 0.37, 0.24 }, { 0.53, 0.20, 0.13 } },
    { 88, 20, 14, { 0.57, 0.50, 0.31 }, { 0.29, 0.18, 0.15 } },
    { 112, 26, 30, { 0.51, 0.40, 0.27 }, { 0.45, 0.16, 0.11 } },
  }
  local windowDark = { 0.10, 0.18, 0.19 }
  local windowLight = { 0.68, 0.66, 0.42 }
  local trim = { 0.27, 0.22, 0.17 }
  for i, b in ipairs(facades) do
    local x, w, top, face, roof = b[1], b[2], b[3], b[4], b[5]
    local bodyTop = top + 10
    treeRect(g, face, x + 2, bodyTop, w - 4, H - bodyTop)
    -- A stepped tile roof reads as Kanto's compact houses and marts from
    -- every repeat angle, while varied tops keep the horizon non-rectangular.
    treeRect(g, roof, x, top + 8, w, 6)
    treeRect(g, roof, x + 2, top + 4, w - 4, 6)
    treeRect(g, roof, x + 6, top, w - 12, 6)
    treeRect(g, { 0.68, 0.32, 0.20 }, x + 4, top + 8, w - 8, 2)
    treeRect(g, trim, x + 2, bodyTop, 4, H - bodyTop)
    for wy = bodyTop + 8, H - 16, 12 do
      for wx = x + 8, x + w - 8, 10 do
        local glass = ((wx / 2 + wy / 2 + i) % 3 == 0)
                      and windowLight or windowDark
        treeRect(g, glass, wx, wy, 4, 6)
      end
    end
    treeRect(g, trim, x + 2, H - 10, w - 4, 2)
    treeRect(g, { 0.23, 0.15, 0.10 }, x + w / 2 - 3, H - 12, 6, 12)
  end
end

-- Restrict a local 128px authoring pass to one quarter of the directional
-- atlas without relying on transforms or additional Canvases. All skyline
-- authors only need setColor/rectangle, so clipping their rectangles here is
-- deterministic and keeps the four bearings completely isolated.
local function bandGraphics(g, x0, width)
  return {
    setColor = function(...) return g.setColor(...) end,
    setBlendMode = function(...) return g.setBlendMode(...) end,
    rectangle = function(mode, x, y, w, h)
      local left, right = math.max(0, x), math.min(width, x + w)
      if right > left then
        return g.rectangle(mode, x0 + left, y, right - left, h)
      end
    end,
  }
end

local FOREST_ASSET_NAMES = { "forestA", "forestB", "forestC" }

local function bakeForestLayout(g, positions)
  local images = {}
  for i = 1, #FOREST_ASSET_NAMES do
    images[i] = compactImage(g, FOREST_ASSET_NAMES[i])
    if not images[i] then
      for _, image in ipairs(images) do releaseImage(image) end
      return false
    end
  end
  local ok = pcall(function()
    g.setColor(1, 1, 1, 1)
    for _, placement in ipairs(positions) do
      g.draw(images[placement[2]], placement[1], 0)
    end
  end)
  for _, image in ipairs(images) do releaseImage(image) end
  return ok
end

local REGIONAL_ASSET_LAYOUT = {
  { name = "forestA", x = 0, y = 32 },
  { name = "forestB", x = 128, y = 32 },
  { name = "forestC", x = 256, y = 32 },
  { name = "town", x = 384, y = 32 },
  { name = "metropolis", x = 896, y = 32 },
  { name = "rural", x = 1408, y = 0 },
  { name = "harbor", x = 1920, y = 0 },
}

-- Strict, all-or-nothing atlas bake.  A wrong or missing compact source must
-- not silently turn one region into the old procedural smear.  Every source
-- is dimension-checked by compactImage(), copied once, and immediately
-- released; only this native-resolution target survives.
local function bakeRegionalLayout(g)
  local images = {}
  for i, placement in ipairs(REGIONAL_ASSET_LAYOUT) do
    images[i] = compactImage(g, placement.name)
    if not images[i] then
      for _, image in ipairs(images) do releaseImage(image) end
      return false
    end
  end
  local ok = pcall(function()
    g.setColor(1, 1, 1, 1)
    for i, placement in ipairs(REGIONAL_ASSET_LAYOUT) do
      g.draw(images[i], placement.x, placement.y)
    end
  end)
  for _, image in ipairs(images) do releaseImage(image) end
  return ok
end

local function directionalSkyline(g, class, H)
  if class == "mountain" then
    -- Route 4 exposed the old procedural range as stretched blue-grey bands.
    -- This compact atlas contains four circular world bearings: a recognisable
    -- high-resolution Fuji only to the north and three grounded low ranges.
    -- It is baked once into the class Canvas and released before frame one.
    if bakeCompact(g, "mountain", function(image)
      g.setColor(1, 1, 1, 1)
      g.draw(image, 0, 0)
    end) then
      return
    end

    -- A damaged/old package fails closed to one quiet silhouette. Do not
    -- resurrect layered full-width bands when the authored source is absent.
    local tops = { 94, 88, 78, 64, 48, 58, 72, 86,
                   96, 84, 70, 54, 68, 80, 90, 96 }
    for edgeIndex = 0, 3 do
      local sector = HorizonWall.MOUNTAIN_SECTORS[edgeIndex]
      panoramaRidge(bandGraphics(g, sector.x, sector.w),
        sector.w, tops, H,
        { 0.22, 0.29, 0.30 }, nil)
    end
    return
  end

  local band = HorizonWall.DIRECTION_W
  local fuji = class ~= "metropolis" and fujiTexture and fujiTexture(g) or nil

  -- First lay the world-bearing distance. Fuji belongs to north only; lower
  -- procedural ridges keep the other three bearings from becoming copies of
  -- the same landmark if an image is unavailable or the player turns around.
  for bearing = 0, 3 do
    local bg = bandGraphics(g, bearing * band, band)
    local mainBearing = bearing == 0 -- north in geometryFor()
    if mainBearing and fuji and g.draw then
      g.setColor(1, 1, 1, 1)
      -- The source is shorter than the 96px wall. Its tree line is the base of
      -- the distant landmark, so align that base with world ground rather than
      -- leaving Fuji floating in the upper half of the panel.
      g.draw(fuji, bearing * band,
             H - HorizonWall.IMAGE_ASSETS.fuji.targetH)
    elseif class ~= "mountain" then
      kantoPanorama(bg, band, H, class == "mountain", false)
    end
  end

  if class == "smalltown" then
    if not bakeCompact(g, "town", function(image)
      g.setColor(1, 1, 1, 1)
      g.draw(image, 0, 0)
    end) then
      for bearing = 0, 3 do
        viridianSkyline(bandGraphics(g, bearing * band, band), band, H)
      end
    end
  elseif class == "metropolis" then
    local metro = bakeCompact(g, "metropolis", function(image)
      g.setColor(1, 1, 1, 1)
      g.draw(image, 0, 0)
    end)
    local lowerTown = bakeCompact(g, "town", function(image)
      g.setColor(1, 1, 1, 1)
      g.draw(image, 0, H - 53, 0, 1, 0.55)
    end)
    if not (metro and lowerTown) then
      for bearing = 0, 3 do
        viridianSkyline(bandGraphics(g, bearing * band, band), band, H)
      end
    end
  elseif class == "trees" then
    local forest = bakeForestLayout(g, {
      { 0, 1 }, { band, 2 }, { band * 2, 3 }, { band * 3, 1 },
    })
    if not forest then
      for bearing = 0, 3 do
        treeSkyline(bandGraphics(g, bearing * band, band), band, H)
      end
    end
  end
end

local function caveSkyline(g, W, H)
  local base, mid, edge = { 0.18, 0.16, 0.15 },
    { 0.30, 0.27, 0.23 }, { 0.40, 0.35, 0.28 }
  pixelRect(g, base, 0, 0, W, H)
  for y = 7, H - 1, 15 do
    local off = (math.floor(y / 15) % 2) * 8
    for x = -off, W - 1, 24 do
      pixelRect(g, mid, x, y, 19, 7)
      pixelRect(g, edge, x + 3, y, 11, 2)
    end
  end
  -- Uneven dark stalactites retain a natural upper silhouette without alpha
  -- holes. The previous transparent pockets exposed the renderer's black
  -- clear colour, which looked like missing geometry rather than depth.
  for x = 8, W - 1, 19 do
    local h = 5 + (x * 7 % 13)
    pixelRect(g, { 0.10, 0.085, 0.075 }, x, 0, 7, h)
    pixelRect(g, { 0.23, 0.20, 0.17 }, x + 1, h - 2, 5, 2)
  end
end

local function towerSkyline(g, W, H)
  local mortar = { 0.12, 0.095, 0.12 }
  local stone = { 0.28, 0.20, 0.25 }
  local rim = { 0.43, 0.30, 0.34 }
  local shadow = { 0.18, 0.13, 0.18 }
  pixelRect(g, mortar, 0, 0, W, H)
  for y = 5, H - 1, 18 do
    local off = (math.floor(y / 18) % 2) * 12
    for x = -off, W - 1, 24 do
      pixelRect(g, stone, x, y, 21, 10)
      pixelRect(g, rim, x + 2, y + 1, 17, 2)
      pixelRect(g, shadow, x + 3, y + 7, 16, 3)
    end
  end
  -- Repeating shallow pilasters keep the long tower perimeter architectural
  -- instead of turning it into one enlarged wall tile.
  for x = 0, W - 1, 32 do
    pixelRect(g, { 0.20, 0.14, 0.20 }, x, 0, 5, H)
    pixelRect(g, { 0.38, 0.25, 0.31 }, x + 1, 0, 2, H)
  end
end

-- Failure-safe only: the shipped compact art is the visual source.  If it is
-- missing or malformed, keep the room opaque and recognisably architectural
-- instead of exposing the renderer clear colour or falling back to cave rock.
local function pokecenterRoomSkyline(g, W, H)
  local upper = { 0.20, 0.23, 0.25 }
  local panel = { 0.35, 0.37, 0.36 }
  local inset = { 0.27, 0.30, 0.31 }
  local ivory = { 0.68, 0.67, 0.57 }
  local blue = { 0.16, 0.28, 0.48 }
  local olive = { 0.37, 0.33, 0.16 }
  pixelRect(g, upper, 0, 0, W, H)
  pixelRect(g, { 0.13, 0.16, 0.19 }, 0, 0, W, 8)
  pixelRect(g, blue, 0, 8, W, 3)
  for x = 8, W - 24, 32 do
    pixelRect(g, inset, x, 24, 24, 80)
    pixelRect(g, panel, x + 3, 27, 18, 74)
    pixelRect(g, ivory, x + 5, 31, 14, 2)
  end
  pixelRect(g, blue, 0, H - 38, W, 4)
  pixelRect(g, olive, 0, H - 34, W, 22)
  pixelRect(g, { 0.22, 0.22, 0.17 }, 0, H - 12, W, 12)
  for x = 12, W - 12, 24 do
    pixelRect(g, { 0.53, 0.48, 0.27 }, x, H - 30, 10, 3)
  end
end

local function waterSkyline(g, W, H)
  pixelRect(g, { 0.08, 0.25, 0.38 }, 0, H - 30, W, 30)
  for x = 0, W - 1, 16 do
    pixelRect(g, { 0.20, 0.46, 0.58 }, x, H - 26 - (x % 7), 11, 3)
  end
  for x = 5, W - 1, 23 do
    pixelRect(g, { 0.18, 0.38, 0.14 }, x, H - 45, 4, 45)
    pixelRect(g, { 0.28, 0.49, 0.18 }, x - 4, H - 39, 8, 5)
  end
end

local function vegetationGroundPattern(g, class, W, H)
  if class == "pallet" then
    -- The transition is viewed almost edge-on in the default 3X battle
    -- camera. Hundreds of isolated 1--3px marks survived minification as a
    -- bright regular raster even though their source positions were hashed.
    -- Build broader, overlapping sod/underbrush islands instead: the base is
    -- quiet forest-edge grass, each island has an irregular shadow and only a
    -- few upright blade pixels. Nothing is aligned to an 8/16/32px tile grid,
    -- so the one-block apron reads as grass rather than another map board.
    local base = { 0.25, 0.56, 0.105 }
    local shadow = { 0.16, 0.43, 0.075 }
    local mid = { 0.33, 0.67, 0.13 }
    local light = { 0.48, 0.79, 0.18 }
    pixelRect(g, base, 0, 0, W, H)
    local count = math.floor(W * H / 112)
    for i = 0, count - 1 do
      local x = (i * 83 + math.floor(i / 5) * 37 + 19) % W
      local y = (i * 53 + math.floor(i / 7) * 41 + 31) % H
      local w = 5 + (i * 7 % 9)
      local h = 2 + (i * 5 % 5)
      pixelRect(g, shadow, x, y, w, h)
      pixelRect(g, mid, x + 2, y, math.max(2, w - 4),
                math.max(1, h - 2))
      if i % 3 == 0 then
        pixelRect(g, light, x + 2 + (i % math.max(1, w - 3)),
                  y - 3, 1, 4)
      end
      if i % 7 == 0 then
        pixelRect(g, mid, x + math.floor(w / 2), y - 5, 2, 6)
      end
    end
    return
  end
  local styles = {
    trees = {
      seed = 37, base = { 0.22, 0.52, 0.12 },
      { 0.30, 0.64, 0.14 }, { 0.38, 0.72, 0.18 },
      { 0.16, 0.44, 0.09 }, { 0.46, 0.78, 0.21 },
      { 0.26, 0.58, 0.13 },
    },
    canopy = {
      seed = 71, base = { 0.14, 0.40, 0.09 },
      { 0.20, 0.50, 0.11 }, { 0.27, 0.59, 0.15 },
      { 0.09, 0.33, 0.075 }, { 0.34, 0.66, 0.18 },
      { 0.17, 0.45, 0.10 },
    },
  }
  local style = styles[class] or styles.trees
  pixelRect(g, style.base, 0, 0, W, H)

  -- Stable integer hashes scatter only 1..3px clusters.  There are no 8px
  -- cells, lanes or large alternating rectangles that can resolve into a
  -- checkerboard when the camera exposes a long transition.  The work runs
  -- once when the retained Canvas is baked; no per-frame randomness/work.
  local count = math.floor(W * H / 32)
  for i = 0, count - 1 do
    local x = (i * 73 + math.floor(i / 7) * 29 + style.seed) % W
    local y = (i * 47 + math.floor(i / 5) * 31 + style.seed * 3) % H
    local colour = style[1 + ((i * 5 + math.floor(i / 11)
                              + style.seed) % 5)]
    local w = 1 + ((i + style.seed) % 3)
    local h = 1 + ((i * 3 + style.seed) % 2)
    pixelRect(g, colour, x, y, w, h)
    if (i + style.seed) % 9 == 0 then
      pixelRect(g, style[2], x + 1, y - 2, 1, 3)
    end
  end
end

local function groundPattern(g, class, W, H)
  if class == "smalltown" or class == "metropolis" then
    -- Seen from the steepest orbit this is an outskirts patchwork, not a
    -- single raised green rectangle: tiled roofs, little yards and two pale
    -- lanes repeat beyond the authored facade at ground level.
    pixelRect(g, { 0.09, 0.27, 0.12 }, 0, 0, W, H)
    pixelRect(g, { 0.43, 0.39, 0.29 }, 14, 0, 6, H)
    pixelRect(g, { 0.47, 0.42, 0.31 }, 0, 14, W, 6)
    pixelRect(g, { 0.45, 0.17, 0.12 }, 0, 0, 12, 10)
    pixelRect(g, { 0.58, 0.25, 0.16 }, 22, 2, 10, 12)
    pixelRect(g, { 0.34, 0.20, 0.15 }, 2, 22, 12, 10)
    pixelRect(g, { 0.52, 0.38, 0.22 }, 22, 22, 10, 10)
    pixelRect(g, { 0.66, 0.32, 0.20 }, 2, 2, 8, 2)
    pixelRect(g, { 0.72, 0.38, 0.22 }, 24, 4, 8, 2)
    pixelRect(g, { 0.48, 0.30, 0.20 }, 4, 24, 8, 2)
    pixelRect(g, { 0.67, 0.51, 0.30 }, 24, 24, 6, 2)
    pixelRect(g, { 0.15, 0.39, 0.15 }, 0, 10, 12, 4)
    pixelRect(g, { 0.14, 0.36, 0.14 }, 20, 16, 12, 4)
  elseif class == "pallet" or class == "canopy" or class == "trees" then
    vegetationGroundPattern(g, class, W, H)
  elseif class == "mountain" then
    pixelRect(g, { 0.31, 0.34, 0.34 }, 0, 0, W, H)
    for y = 2, H - 1, 8 do
      pixelRect(g, { 0.48, 0.50, 0.47 }, (y * 3) % 11, y, 18, 3)
      pixelRect(g, { 0.22, 0.25, 0.26 }, (y * 5) % 17, y + 3, 13, 2)
    end
  elseif class == "cave" then
    pixelRect(g, { 0.16, 0.14, 0.13 }, 0, 0, W, H)
    for y = 1, H - 1, 8 do
      local off = (math.floor(y / 8) % 2) * 5
      for x = -off, W - 1, 12 do
        pixelRect(g, { 0.29, 0.25, 0.21 }, x, y, 10, 5)
        pixelRect(g, { 0.39, 0.33, 0.26 }, x + 2, y, 5, 1)
      end
    end
  elseif class == "tower" then
    pixelRect(g, { 0.13, 0.10, 0.13 }, 0, 0, W, H)
    for y = 1, H - 1, 8 do
      local off = (math.floor(y / 8) % 2) * 6
      for x = -off, W - 1, 12 do
        pixelRect(g, { 0.28, 0.20, 0.25 }, x, y, 10, 5)
        pixelRect(g, { 0.43, 0.29, 0.34 }, x + 2, y, 6, 1)
      end
    end
  elseif class == "pokecenter_room" then
    local base = { 0.34, 0.37, 0.39 }
    local seam = { 0.23, 0.27, 0.30 }
    local light = { 0.58, 0.60, 0.56 }
    pixelRect(g, base, 0, 0, W, H)
    for at = 32, W - 1, 32 do pixelRect(g, seam, at, 0, 2, H) end
    for at = 32, H - 1, 32 do pixelRect(g, seam, 0, at, W, 2) end
    for y = 12, H - 12, 32 do
      for x = 12, W - 12, 32 do
        pixelRect(g, light, x, y, 8, 4)
      end
    end
  else
    pixelRect(g, { 0.07, 0.24, 0.36 }, 0, 0, W, H)
    for y = 3, H - 1, 8 do
      for x = (y * 3) % 9, W - 1, 13 do
        pixelRect(g, { 0.17, 0.44, 0.57 }, x, y, 8, 2)
      end
    end
  end
end

local function crispCanvas(g, W, H)
  -- Explicit one-device-pixel backing avoids a high-DPI window silently
  -- changing the authored texel grid. No MSAA/mip chain: both would average
  -- the very hard leaf edges this texture exists to provide. Older LOVE
  -- builds that do not accept the settings table retain the safe fallback.
  local ok, canvas = pcall(g.newCanvas, W, H, {
    dpiscale = 1, msaa = 0, mipmaps = "none",
  })
  if not (ok and canvas) then ok, canvas = pcall(g.newCanvas, W, H) end
  if not (ok and canvas) then return nil end
  pcall(canvas.setFilter, canvas, "nearest", "nearest", 1)
  if canvas.setMipmapFilter then
    pcall(canvas.setMipmapFilter, canvas, nil)
  end
  return canvas
end

local assetStats = { loads = 0, releases = 0, rejected = 0 }

releaseImage = function(image)
  if image and image.release then
    pcall(image.release, image)
    assetStats.releases = assetStats.releases + 1
  end
end

local function compactPath(spec)
  if type(V.path) ~= "string" then return nil end
  return V.path .. "/" .. spec.path
end

compactImage = function(g, name)
  local spec = HorizonWall.IMAGE_ASSETS[name]
  local path = spec and compactPath(spec)
  if not (spec and path and g and type(g.newImage) == "function") then
    return nil
  end
  local ok, image = pcall(g.newImage, path,
                          { mipmaps = false, linear = false })
  if not (ok and image) then ok, image = pcall(g.newImage, path) end
  if not (ok and image) then return nil end
  assetStats.loads = assetStats.loads + 1
  if image.setFilter then
    pcall(image.setFilter, image, "nearest", "nearest", 1)
  end
  if image.setMipmapFilter then pcall(image.setMipmapFilter, image, nil) end
  local dimOK, width, height = pcall(image.getDimensions, image)
  if not dimOK or width ~= spec.sourceW or height ~= spec.sourceH then
    assetStats.rejected = assetStats.rejected + 1
    releaseImage(image)
    return nil
  end
  return image
end

-- Draw a compact input into the currently bound final Canvas, then drop the
-- input immediately. Town/forest masters therefore never become retained GPU
-- textures and can never be decoded once per frame.
bakeCompact = function(g, name, painter)
  local image = compactImage(g, name)
  if not image then return false end
  local ok = pcall(painter, image)
  releaseImage(image)
  return ok
end

-- Fuji is shared by generic, small-town and mountain skyline Canvases.
-- Retaining the already compact 128x43 image avoids decoding it for each class
-- while costing only 21.5 KiB. It is released with every other horizon GPU
-- object on invalidate/context loss.
fujiTexture = function(g)
  local key = "asset:fuji"
  if textures[key] then return textures[key] end
  local image = compactImage(g, "fuji")
  if not image then return nil end
  textures[key] = image
  return image
end

function HorizonWall.assetStats()
  return { loads = assetStats.loads, releases = assetStats.releases,
           rejected = assetStats.rejected }
end

function HorizonWall._resetAssetStats()
  assetStats.loads, assetStats.releases, assetStats.rejected = 0, 0, 0
end

local function skylineTexture(class)
  if not (love and love.graphics and love.graphics.newCanvas) then return nil end
  -- The baked panorama receives the scene's time-of-day tint in the world
  -- shader and never samples the terrain atlas. Sharing one Canvas per
  -- semantic class avoids duplicate textures for every connected map.
  local key = class
  if textures[key] then return textures[key] end
  if textureFailures[key] then return nil end
  local directional = hasDirectionalPanorama(class)
  local g = love.graphics
  local W = class == "regional" and HorizonWall.REGIONAL_STRIP_W
            or class == "route8" and HorizonWall.ROUTE8_STRIP_W
            or class == "mountain" and HorizonWall.MOUNTAIN_STRIP_W
            or class == "mt_moon" and HorizonWall.MT_MOON_WALL_W
            or class == "tower" and HorizonWall.TOWER_WALL_W
            or class == "pokecenter_room"
               and HorizonWall.POKECENTER_ROOM_WALL_W
            or hasWorldForestStrip(class) and HorizonWall.FOREST_STRIP_W
            or directional and HorizonWall.STRIP_W
            or HorizonWall.DIRECTION_W
  local H = class == "regional" and HorizonWall.REGIONAL_TEXTURE_H
            or class == "route8" and HorizonWall.ROUTE8_TEXTURE_H
            or class == "mountain" and HorizonWall.MOUNTAIN_TEXTURE_H
            or class == "mt_moon" and HorizonWall.ENCLOSURE_TEXTURE_H
            or class == "pokecenter_room"
               and HorizonWall.ENCLOSURE_TEXTURE_H
            or isEnclosure(class) and HorizonWall.ENCLOSURE_TEXTURE_H
            or HorizonWall.HEIGHT
  local canvas = crispCanvas(g, W, H)
  if not canvas then textureFailures[key] = true return nil end
  pcall(canvas.setWrap, canvas,
        (class == "regional" or class == "route8" or directional
          or hasWorldForestStrip(class))
          and "clamp" or "repeat",
        "clamp")
  local pushed = false
  local done = pcall(function()
    g.push("all")
    pushed = true
    g.origin()
    g.setCanvas(canvas)
    g.clear(0, 0, 0, 0)
    if class == "regional" then
      if not bakeRegionalLayout(g) then
        error("regional skyline compact asset rejected")
      end
    elseif class == "route8" then
      if not bakeCompact(g, "route8", function(image)
        g.setColor(1, 1, 1, 1)
        g.draw(image, 0, 0)
      end) then
        error("Route 8 skyline compact asset rejected")
      end
    elseif class == "mt_moon" then
      -- Missing, malformed or undecodable art retains the proven opaque cave
      -- material. The failed source is still released by compactImage(); the
      -- fallback Canvas is cached so a bad package never retries per frame.
      if not bakeCompact(g, "mtMoonWall", function(image)
        g.setColor(1, 1, 1, 1)
        g.draw(image, 0, 0)
      end) then
        caveSkyline(g, W, H)
      end
    elseif class == "tower" then
      -- The procedural tower remains an opaque package-failure fallback. A
      -- valid release bakes only the reviewed 512px two-bay source and drops
      -- that transient Image immediately, preserving the existing wall draw.
      if not bakeCompact(g, "pokemonTowerWall", function(image)
        g.setColor(1, 1, 1, 1)
        g.draw(image, 0, 0)
      end) then
        towerSkyline(g, W, H)
      end
    elseif class == "pokecenter_room" then
      if not bakeCompact(g, "pokecenterRoomWall", function(image)
        g.setColor(1, 1, 1, 1)
        g.draw(image, 0, 0)
      end) then
        pokecenterRoomSkyline(g, W, H)
      end
    elseif directional then
      directionalSkyline(g, class, H)
    elseif hasWorldForestStrip(class) then
      if not bakeForestLayout(g, {
        { 0, 1 }, { HorizonWall.DIRECTION_W, 2 },
        { HorizonWall.DIRECTION_W * 2, 3 },
      }) then
        treeSkyline(g, W, H)
      end
    elseif class == "cave" then caveSkyline(g, W, H)
    elseif class == "water" then waterSkyline(g, W, H)
    else treeSkyline(g, W, H) end
    g.setCanvas()
    g.pop()
    pushed = false
  end)
  if not done then
    pcall(g.setCanvas)
    if pushed then pcall(g.pop) end
    if canvas.release then pcall(canvas.release, canvas) end
    textureFailures[key] = true
    return nil
  end
  textures[key] = canvas
  return canvas
end

local function coastalLandmarkTexture()
  if not (love and love.graphics) then return nil end
  local key = "asset:coastalLandmarks"
  if textures[key] then return textures[key] end
  if textureFailures[key] then return nil end
  local image = compactImage(love.graphics, "coastalLandmarks")
  if not image then textureFailures[key] = true return nil end
  textures[key] = image
  return image
end

local function groundTexture(class)
  if not (love and love.graphics and love.graphics.newCanvas) then return nil end
  local key = "ground:" .. class
  if textures[key] then return textures[key] end
  local g = love.graphics
  local W = class == "mt_moon" and HorizonWall.MT_MOON_GROUND_PERIOD
            or class == "tower" and HorizonWall.TOWER_SURFACE_PERIOD
            or class == "pokecenter_room"
               and HorizonWall.POKECENTER_ROOM_SURFACE_PERIOD
            or (class == "pallet" or class == "trees"
                or class == "canopy")
               and HorizonWall.VEGETATION_GROUND_PERIOD
            or HorizonWall.CELL
  local H = W
  local canvas = crispCanvas(g, W, H)
  if not canvas then return nil end
  pcall(canvas.setWrap, canvas, "repeat", "repeat")
  local pushed = false
  local done = pcall(function()
    g.push("all")
    pushed = true
    g.origin()
    g.setCanvas(canvas)
    g.clear(0, 0, 0, 1)
    local baked = false
    if class == "mt_moon" then
      baked = bakeCompact(g, "mtMoonCeiling", function(image)
         g.setColor(1, 1, 1, 1)
         g.draw(image, 0, 0)
      end)
    elseif class == "tower" then
      baked = bakeCompact(g, "pokemonTowerCeiling", function(image)
        g.setColor(1, 1, 1, 1)
        g.draw(image, 0, 0)
      end)
    elseif class == "pokecenter_room" then
      baked = bakeCompact(g, "pokecenterRoomCeiling", function(image)
        g.setColor(1, 1, 1, 1)
        g.draw(image, 0, 0)
      end)
    end
    if not baked then
      groundPattern(g, class == "mt_moon" and "cave" or class, W, H)
    end
    g.setCanvas()
    g.pop()
    pushed = false
  end)
  if not done then
    pcall(g.setCanvas)
    if pushed then pcall(g.pop) end
    if canvas.release then pcall(canvas.release, canvas) end
    return nil
  end
  textures[key] = canvas
  return canvas
end

local function foregroundTreeTexture(class)
  if class ~= "smalltown" and class ~= "trees"
     and class ~= "pallet" and class ~= "canopy"
     or not (love and love.graphics and love.graphics.newCanvas) then
    return nil
  end
  local key = "foreground:layered"
  if textures[key] then return textures[key] end
  local g, W, H = love.graphics, HorizonWall.FOREGROUND_ATLAS_W,
                  HorizonWall.FOREGROUND_ATLAS_H
  local canvas = crispCanvas(g, W, H)
  if not canvas then return nil end
  pcall(canvas.setWrap, canvas, "clamp", "clamp")
  local pushed = false
  local done = pcall(function()
    g.push("all")
    pushed = true
    g.origin()
    g.setCanvas(canvas)
    g.clear(0, 0, 0, 0)
    -- First 32px: UV quarters for the faceted small-town voxel trees.
    pixelRect(g, { 0.27, 0.15, 0.055 }, 0, 0, 8, H)
    for y = 0, H - 1, 8 do
      pixelRect(g, { 0.38, 0.22, 0.08 }, (y / 8) % 2 * 4, y, 4, 6)
    end
    pixelRect(g, { 0.055, 0.23, 0.08 }, 8, 0, 8, H)
    pixelRect(g, { 0.11, 0.36, 0.12 }, 16, 0, 8, H)
    pixelRect(g, { 0.22, 0.50, 0.18 }, 24, 0, 8, H)
    for y = 2, H - 1, 8 do
      pixelRect(g, { 0.29, 0.59, 0.21 }, 26, y, 4, 4)
      pixelRect(g, { 0.16, 0.43, 0.14 }, 18, y + 2, 4, 4)
    end
    -- Remaining 128px: the four compact standalone tree cut-outs. Drawing the
    -- source once into this final atlas and releasing it avoids an extra
    -- retained texture/draw while generic forest, canopy, Pallet and
    -- small-town profiles share it.
    local baked = bakeCompact(g, "miniTrees", function(image)
      g.setColor(1, 1, 1, 1)
      g.draw(image, 32, 0)
    end)
    if not baked then
      -- Fail closed to simple green silhouettes rather than exposing belt
      -- gaps when an asset is missing from an older package.
      for variant = 0, 3 do
        local x = 32 + variant * 32
        pixelRect(g, { 0.06, 0.20, 0.07 }, x + 12, 28, 8, 36)
        pixelRect(g, { 0.10, 0.34, 0.10 }, x + 4, 12, 24, 38)
        pixelRect(g, { 0.20, 0.48, 0.16 }, x + 8, 6, 16, 30)
      end
    end
    g.setCanvas()
    g.pop()
    pushed = false
  end)
  if not done then
    pcall(g.setCanvas)
    if pushed then pcall(g.pop) end
    if canvas.release then pcall(canvas.release, canvas) end
    return nil
  end
  textures[key] = canvas
  return canvas
end

-- Route 8's eight cut-outs retain exactly one 256x64 RGBA8 Canvas (64 KiB).
-- The compact PNG is copied at native size with nearest filtering, released
-- immediately, and never mixed into the far skyline Canvas: one extra texture
-- therefore also means at most one extra foreground draw for the whole union.
local function route8MidgroundTexture()
  if not (love and love.graphics and love.graphics.newCanvas) then return nil end
  local key = "foreground:route8-midground"
  if textures[key] then return textures[key] end
  if textureFailures[key] then return nil end
  local g = love.graphics
  local canvas = crispCanvas(g, HorizonWall.ROUTE8_MIDGROUND_W,
                             HorizonWall.ROUTE8_MIDGROUND_H)
  if not canvas then textureFailures[key] = true return nil end
  pcall(canvas.setWrap, canvas, "clamp", "clamp")
  local pushed = false
  local done = pcall(function()
    g.push("all")
    pushed = true
    g.origin()
    g.setCanvas(canvas)
    g.clear(0, 0, 0, 0)
    if not bakeCompact(g, "route8Midground", function(image)
      g.setColor(1, 1, 1, 1)
      g.draw(image, 0, 0)
    end) then
      error("Route 8 midground compact asset rejected")
    end
    g.setCanvas()
    g.pop()
    pushed = false
  end)
  if not done then
    pcall(g.setCanvas)
    if pushed then pcall(g.pop) end
    if canvas.release then pcall(canvas.release, canvas) end
    textureFailures[key] = true
    return nil
  end
  textures[key] = canvas
  return canvas
end

-- Forest's two warp ends reuse the reviewed canonical Route 2 exterior.
-- Copying it during the protected Canvas bake keeps its exact native texel
-- scale and binary alpha while retaining only one shared 64x40 texture.
local function forestGateFacadeTexture()
  if not (love and love.graphics and love.graphics.newCanvas) then return nil end
  local key = "foreground:forest-gate-facade"
  if textures[key] then return textures[key] end
  if textureFailures[key] then return nil end
  local source = HorizonWall.FOREST_GATE_FACADE_SOURCE
  local g = love.graphics
  local canvas = crispCanvas(g, source.w, source.h)
  if not canvas then textureFailures[key] = true return nil end
  pcall(canvas.setWrap, canvas, "clamp", "clamp")
  local pushed = false
  local done = pcall(function()
    g.push("all")
    pushed = true
    g.origin()
    g.setCanvas(canvas)
    g.clear(0, 0, 0, 0)
    if not bakeCompact(g, source.asset, function(image)
      g.setColor(1, 1, 1, 1)
      g.draw(image, -source.x, -source.y)
    end) then
      error("Forest gatehouse compact asset rejected")
    end
    g.setCanvas()
    g.pop()
    pushed = false
  end)
  if not done then
    pcall(g.setCanvas)
    if pushed then pcall(g.pop) end
    if canvas.release then pcall(canvas.release, canvas) end
    textureFailures[key] = true
    return nil
  end
  textures[key] = canvas
  return canvas
end

function HorizonWall.prewarm(map)
  if not HorizonWall.enabled() or not map then return true end
  local class = HorizonWall.classFor(map)
  if class == "interior" then return true end
  local families, wantsForeground = {}, false
  local id = tostring(map.id or map.def and map.def.id or "")
  local rules = HorizonWall.EDGE_PROFILES[id]
  local function includeKind(kind)
    if not kind then return end
    local family = HorizonWall.wallFamily(kind, map)
    if family then families[family] = true end
    if fillerRowsFor(map, kind) > 0 then wantsForeground = true end
  end
  local function includeRule(rule)
    if type(rule) == "string" then includeKind(rule) return end
    for _, part in ipairs(rule or {}) do includeKind(part.kind) end
  end
  if rules then
    for _, edge in ipairs({ "north", "south", "west", "east" }) do
      includeRule(rules[edge])
    end
  else
    includeKind(defaultEdgeKind(class))
  end
  local wall = true
  for family in pairs(families) do
    if not skylineTexture(family) then wall = false end
  end
  local ground = groundTexture(HorizonWall.materialFor(map))
  local foreground = not wantsForeground or foregroundTreeTexture(class)
  local midground = id ~= "ROUTE_8" or route8MidgroundTexture()
  local wantsForestGateFacade = id == "VIRIDIAN_FOREST"
    and (HorizonWall.viridianForestGateVerified(map, "north")
         or HorizonWall.viridianForestGateVerified(map, "south"))
  local forestGateFacade = not wantsForestGateFacade
                           or forestGateFacadeTexture()
  local coastal = not HorizonWall.COASTAL_LANDMARKS[id]
                  or coastalLandmarkTexture() ~= nil
  return wall == true and ground ~= nil and foreground ~= nil
         and midground ~= nil and forestGateFacade ~= nil and coastal
end

local readyCaches, pendingJobs, failedKeys = {}, {}, {}
local failedCount = 0
local lastReady, useSerial = nil, 0
-- The visible union, its direct-connection handoff union and one future
-- active+neighbour build may coexist briefly. Textures are shared; these are
-- only the small perimeter meshes, and retaining all three avoids releasing a
-- known-good seam fallback in the very frame its replacement completes.
HorizonWall.READY_CACHE_CAP = 3
-- A direction change can leave an in-progress future union behind before its
-- coroutine reaches the cache. Unlike ready entries, such jobs cannot finish
-- unless that exact union key is requested again, so retaining them without a
-- bound leaks their geometry tables and any mesh parts already allocated.
-- Four slots cover the steady active/handoff/future trio plus one re-root
-- fallback. The job requested by the current call is never an eviction target.
HorizonWall.PENDING_CACHE_CAP = 4
-- A deterministic state build failure is terminal for this invalidation
-- epoch (normally a graphics-context or scenery-setting change). These exact
-- keys retain no geometry and invalidate() bounds their lifetime. They must
-- not use an LRU: evicting one would recreate its failed GPU work per frame.

local function mapIdsOf(maps)
  local ids = {}
  for _, e in ipairs(maps or {}) do
    local id = e and e.map and e.map.id
    if id ~= nil then ids[tostring(id)] = true end
  end
  return ids
end

local function containsMap(ids, mapId)
  return type(ids) == "table" and ids[tostring(mapId)] == true
end

local function failed(key)
  return failedKeys[key] ~= nil
end

local function markFailed(key, maps)
  if failedKeys[key] then return end
  failedKeys[key] = mapIdsOf(maps)
  failedCount = failedCount + 1
end

local function releaseMeshes(entries)
  for _, e in ipairs(entries or {}) do
    if e.mesh and e.mesh.release then pcall(e.mesh.release, e.mesh) end
  end
end

local function abandonPending(key)
  local job = pendingJobs[key]
  if not job then return end
  pendingJobs[key] = nil
  releaseMeshes(job.meshes)
  -- A suspended coroutine retains every geometry table in its Lua stack.
  -- Drop it, the captured map list and completed parts explicitly so the next
  -- collection can reclaim the abandoned union immediately.
  job.co, job.maps, job.meshes = nil, nil, nil
end

local function jobContainsMap(job, mapId)
  if not (job and mapId ~= nil) then return false end
  for _, e in ipairs(job.maps or {}) do
    if e and e.map and tostring(e.map.id) == tostring(mapId) then return true end
  end
  return false
end

local function trimPending(keepKey)
  local count = 0
  for _ in pairs(pendingJobs) do count = count + 1 end
  while count > HorizonWall.PENDING_CACHE_CAP do
    local oldestKey, oldestUse
    for key, job in pairs(pendingJobs) do
      if key ~= keepKey and (not oldestUse or (job.used or 0) < oldestUse) then
        oldestKey, oldestUse = key, job.used or 0
      end
    end
    if not oldestKey then break end
    abandonPending(oldestKey)
    count = count - 1
  end
end

local function canonicalAddress(state)
  local localMaps = mapsOf(state)
  local maps, baseX, baseY
  if WorldPlacement and type(WorldPlacement.canonical) == "function" then
    maps, baseX, baseY = WorldPlacement.canonical(
      localMaps, state.map.id, state.worldMaps)
  end
  if maps then return maps, baseX, baseY, true end

  -- Missing/inconsistent mod map data: preserve the old root-local behaviour
  -- and make the root part of the address so two unrelated local frames can
  -- never alias. This can rebuild, but it cannot place a wall on the wrong map.
  return localMaps, 0, 0, false
end

local function stateKey(state, maps, canonical)
  local parts = { tostring(TileRenderer.voidFill or "trees"),
                  HorizonWall.enabled() and "full" or "off",
                  canonical and "world" or ("root:" .. tostring(state.map.id)) }
  for _, e in ipairs(maps) do
    parts[#parts + 1] = table.concat({ tostring(e.map.id), e.ox, e.oy,
      e.w, e.h, HorizonWall.classFor(e.map),
      HorizonWall.materialFor(e.map) }, ":")
  end
  return table.concat(parts, "|")
end

local function rebasedView(entry, baseX, baseY)
  baseX, baseY = baseX or 0, baseY or 0
  local key = tostring(baseX) .. ":" .. tostring(baseY)
  entry.views = entry.views or {}
  local hit = entry.views[key]
  if hit then return hit end
  local out = {}
  for i, rim in ipairs(entry.meshes) do
    local copy = {}
    for name, value in pairs(rim) do copy[name] = value end
    copy.ox, copy.oy = (rim.ox or 0) + baseX, (rim.oy or 0) + baseY
    out[i] = copy
  end
  entry.views[key] = out
  return out
end

local function touch(entry, baseX, baseY)
  useSerial = useSerial + 1
  entry.used = useSerial
  if baseX ~= nil then
    entry.lastBaseX, entry.lastBaseY = baseX, baseY
  end
  return rebasedView(entry, entry.lastBaseX or 0, entry.lastBaseY or 0)
end

local function trimReady(keepKey)
  local count = 0
  for _ in pairs(readyCaches) do count = count + 1 end
  while count > HorizonWall.READY_CACHE_CAP do
    local oldestKey, oldestUse
    for key, entry in pairs(readyCaches) do
      if key ~= keepKey and (not oldestUse or entry.used < oldestUse) then
        oldestKey, oldestUse = key, entry.used
      end
    end
    if not oldestKey then break end
    releaseMeshes(readyCaches[oldestKey].meshes)
    readyCaches[oldestKey] = nil
    count = count - 1
  end
end

local function newBuildJob(key, maps)
  local job = { key = key, maps = maps, meshes = {}, complete = true,
                resumes = 0 }
  job.co = coroutine.create(function()
    local coastalVertices, coastalIndices = {}, {}
    local seaVertices, seaIndices = {}, {}
    local route8MidgroundVertices, route8MidgroundIndices = {}, {}
    local route8SeamPathVertices, route8SeamPathIndices = {}, {}
    local route8SeamPathMap
    local forestGatePathVertices, forestGatePathIndices = {}, {}
    local forestGatePathMap
    local forestGateFacadeVertices, forestGateFacadeIndices = {}, {}
    local groundCells, seaCells, ruralTerminals = {}, {}, {}
    local function failBuild()
      job.complete = false
      -- Voxel3D.newMesh deliberately reports protected LOVE allocation
      -- failures as nil. Abort this coroutine immediately: continuing would
      -- allocate unrelated later parts for a result that can never publish.
      error("horizon mesh allocation failed", 0)
    end
    local function addPart(kind, className, vertices, indices, texture, ox, oy)
      if #vertices == 0 then return end
      coroutine.yield("before-mesh")
      local mesh = texture and Voxel3D.newMesh(vertices, indices) or nil
      if not mesh then failBuild() end
      job.meshes[#job.meshes + 1] = {
        mesh = mesh, texture = texture, ox = ox or 0, oy = oy or 0,
        class = className, kind = kind,
      }
    end
    local function addAtlasPart(kind, className, vertices, indices, textureMap)
      if #vertices == 0 then return end
      coroutine.yield("before-mesh")
      local mesh = Voxel3D.newMesh(vertices, indices)
      if not mesh then failBuild() end
      job.meshes[#job.meshes + 1] = {
        mesh = mesh, textureMap = textureMap, ox = 0, oy = 0,
        class = className, kind = kind,
      }
    end
    local function appendCoastal(built)
      local base = #coastalVertices
      for _, v in ipairs(built.coastalVertices or {}) do
        coastalVertices[#coastalVertices + 1] = {
          v[1] + built.ox, v[2], v[3] + built.oy,
          v[4], v[5], v[6],
        }
      end
      for _, index in ipairs(built.coastalIndices or {}) do
        coastalIndices[#coastalIndices + 1] = base + index
      end
    end
    local function appendSea(built)
      local base = #seaVertices
      for _, v in ipairs(built.seaVertices or {}) do
        seaVertices[#seaVertices + 1] = {
          v[1] + built.ox, v[2], v[3] + built.oy,
          v[4], v[5], v[6],
        }
      end
      for _, index in ipairs(built.seaIndices or {}) do
        seaIndices[#seaIndices + 1] = base + index
      end
    end
    local function appendRoute8Midground(built)
      local base = #route8MidgroundVertices
      for _, v in ipairs(built.route8MidgroundVertices or {}) do
        route8MidgroundVertices[#route8MidgroundVertices + 1] = {
          v[1] + built.ox, v[2], v[3] + built.oy,
          v[4], v[5], v[6],
        }
      end
      for _, index in ipairs(built.route8MidgroundIndices or {}) do
        route8MidgroundIndices[#route8MidgroundIndices + 1] = base + index
      end
    end
    local function appendRoute8SeamPath(built)
      local base = #route8SeamPathVertices
      for _, v in ipairs(built.route8SeamPathVertices or {}) do
        route8SeamPathVertices[#route8SeamPathVertices + 1] = {
          v[1] + built.ox, v[2], v[3] + built.oy,
          v[4], v[5], v[6],
        }
      end
      for _, index in ipairs(built.route8SeamPathIndices or {}) do
        route8SeamPathIndices[#route8SeamPathIndices + 1] = base + index
      end
      if built.route8SeamPathMap then
        route8SeamPathMap = built.route8SeamPathMap
      end
    end
    local function appendForestGatePath(built)
      local base = #forestGatePathVertices
      for _, v in ipairs(built.forestGatePathVertices or {}) do
        forestGatePathVertices[#forestGatePathVertices + 1] = {
          v[1] + built.ox, v[2], v[3] + built.oy,
          v[4], v[5], v[6],
        }
      end
      for _, index in ipairs(built.forestGatePathIndices or {}) do
        forestGatePathIndices[#forestGatePathIndices + 1] = base + index
      end
      if built.forestGatePathMap then
        forestGatePathMap = built.forestGatePathMap
      end
    end
    local function appendForestGateFacade(built)
      local base = #forestGateFacadeVertices
      for _, v in ipairs(built.forestGateFacadeVertices or {}) do
        forestGateFacadeVertices[#forestGateFacadeVertices + 1] = {
          v[1] + built.ox, v[2], v[3] + built.oy,
          v[4], v[5], v[6],
        }
      end
      for _, index in ipairs(built.forestGateFacadeIndices or {}) do
        forestGateFacadeIndices[#forestGateFacadeIndices + 1] = base + index
      end
    end

    for i, e in ipairs(maps) do
      local built = geometryFor(e, i, maps, function()
        coroutine.yield("geometry")
      end, groundCells, seaCells, ruralTerminals)
      coroutine.yield("geometry-ready")
      if built then
        -- Canvas/image decode is one bounded prewarm step. Never yield while a
        -- Canvas is bound; the next resume starts only after state is restored.
        local wallTextures = {}
        for groupIndex, group in ipairs(built.wallGroups or {}) do
          wallTextures[groupIndex] = skylineTexture(group.family)
        end
        local floorTexture = #built.groundVertices > 0
                             and groundTexture(built.material) or nil
        local treeTexture = #built.foregroundVertices > 0
                            and foregroundTreeTexture(built.class) or nil
        coroutine.yield("textures-ready")

        for groupIndex, group in ipairs(built.wallGroups or {}) do
          addPart("wall", group.family, group.vertices, group.indices,
                  wallTextures[groupIndex], built.ox, built.oy)
        end
        addPart("ground", built.class, built.groundVertices,
                built.groundIndices, floorTexture, built.ox, built.oy)
        addPart("foreground", built.class, built.foregroundVertices,
                built.foregroundIndices, treeTexture, built.ox, built.oy)
        appendSea(built)
        appendCoastal(built)
        appendRoute8Midground(built)
        appendRoute8SeamPath(built)
        appendForestGatePath(built)
        appendForestGateFacade(built)
      end
    end

    -- All open-water cap quads already share one material and world-cell
    -- ownership table. Aggregate the translated vertices before allocation as
    -- well: a complete Route19/20/21/Cinnabar union keeps every quad and UV but
    -- publishes one reflective horizon-water mesh instead of four draws.
    if #seaVertices > 0 then
      local texture = groundTexture("water")
      coroutine.yield("sea-texture-ready")
      addPart("water", "water", seaVertices, seaIndices, texture, 0, 0)
    end

    -- Route 8 is the only owner, but aggregate before allocation so even a
    -- synthetic/re-rooted union can never grow beyond one midground draw.
    if #route8MidgroundVertices > 0 then
      local texture = route8MidgroundTexture()
      coroutine.yield("route8-midground-texture-ready")
      addPart("foreground", "route8-midground", route8MidgroundVertices,
              route8MidgroundIndices, texture, 0, 0)
    end

    -- Cold-only Route 8 path: one atlas-backed batch, with the live terrain
    -- palette resolved by VoxelScene at draw time.  It retains no texture of
    -- its own and disappears from the warm Route8+Lavender horizon key.
    addAtlasPart("route8-seam-path", "route8-seam-path",
                 route8SeamPathVertices, route8SeamPathIndices,
                 route8SeamPathMap)

    -- Both independently verified Viridian Forest warp exits share one live
    -- FOREST-atlas batch and retain no duplicate path bitmap.
    addAtlasPart("forest-gate-path", "forest-gate-path",
                 forestGatePathVertices, forestGatePathIndices,
                 forestGatePathMap)

    -- Both verified Forest exits share one native-width 64x40 gate facade, one mesh
    -- and one draw. The source PNG is released by forestGateFacadeTexture();
    -- only its 10 KiB Canvas survives.
    if #forestGateFacadeVertices > 0 then
      local texture = forestGateFacadeTexture()
      coroutine.yield("forest-gate-facade-texture-ready")
      addPart("forest-gate-facade", "forest-gate-facade",
              forestGateFacadeVertices, forestGateFacadeIndices,
              texture, 0, 0)
    end

    -- Canonical vertices from every resident map share one sparse landmark
    -- mesh and therefore exactly one additional draw for the complete scene.
    if #coastalVertices > 0 then
      local texture = coastalLandmarkTexture()
      coroutine.yield("coastal-texture-ready")
      addPart("coastal", "coastal", coastalVertices, coastalIndices,
              texture, 0, 0)
    end
  end)
  return job
end

local function finishJob(job)
  pendingJobs[job.key] = nil
  if not job.complete then
    markFailed(job.key, job.maps)
    releaseMeshes(job.meshes)
    job.co, job.maps, job.meshes = nil, nil, nil
    return nil
  end
  local meshes = job.meshes
  local entry = { key = job.key, meshes = meshes, used = 0, views = {},
                  mapIds = mapIdsOf(job.maps) }
  job.co, job.maps, job.meshes = nil, nil, nil
  readyCaches[job.key] = entry
  lastReady = entry
  useSerial = useSerial + 1
  entry.used = useSerial
  trimReady(job.key)
  return entry
end

local function advanceJob(job)
  for _ = 1, HorizonWall.BUILD_RESUMES_PER_CALL do
    if coroutine.status(job.co) == "dead" then return finishJob(job), true end
    job.resumes = job.resumes + 1
    local ok = coroutine.resume(job.co)
    if not ok then
      job.complete = false
      return finishJob(job), false
    end
    if coroutine.status(job.co) == "dead" then return finishJob(job), true end
  end
  return nil, false
end

function HorizonWall.buildStatus()
  local ready, pending = 0, 0
  for _ in pairs(readyCaches) do ready = ready + 1 end
  for _ in pairs(pendingJobs) do pending = pending + 1 end
  return { ready = ready, pending = pending, failed = failedCount }
end

-- Passive cache probe for transition QA.  It computes the same canonical key
-- as meshes(), but deliberately neither creates nor resumes a build job and
-- never touches LRU order.  A native seam timeout can therefore tell whether
-- the exact current/retained plan is ready, still progressing, or absent
-- without changing the state it is trying to diagnose.
function HorizonWall.cacheStatus(state)
  if not HorizonWall.enabled() or not (state and state.map) then
    return { enabled = false, ready = true, pending = false,
             failed = false, resumes = 0, maps = 0 }
  end
  local maps, _, _, canonical = canonicalAddress(state)
  local key = stateKey(state, maps, canonical)
  local job = pendingJobs[key]
  return {
    enabled = true,
    ready = readyCaches[key] ~= nil,
    pending = job ~= nil,
    failed = readyCaches[key] == nil and failed(key),
    resumes = job and job.resumes or 0,
    maps = #maps,
    key = key,
  }
end

function HorizonWall.meshes(state)
  if not HorizonWall.enabled() or not (state and state.map) then
    return {}, true, false
  end
  local maps, baseX, baseY, canonical = canonicalAddress(state)
  local key = stateKey(state, maps, canonical)
  local ready = readyCaches[key]
  if ready then
    lastReady = ready
    return touch(ready, baseX, baseY), true, false
  end
  -- Never hand a half-built or unrelated lastReady mesh to a state whose
  -- exact build already failed.  The third result lets VoxelScene select its
  -- complete FULL-ring fallback without scheduling this key again.
  if failed(key) then return {}, false, true end
  local job = pendingJobs[key]
  if not job then
    job = newBuildJob(key, maps)
    pendingJobs[key] = job
  end
  useSerial = useSerial + 1
  job.used = useSerial
  trimPending(key)
  local built, done = advanceJob(job)
  if built and done then return touch(built, baseX, baseY), true, false end
  if failed(key) then return {}, false, true end
  -- A pending address must never borrow the most recently completed address.
  -- That global entry may belong to a wholly different map; returning it for
  -- even one frame flashes the previous city's houses/panorama during a warp.
  -- VoxelScene already retains compatible smaller unions explicitly by their
  -- exact canonical key, so an exact cache hit above remains seamless while a
  -- genuinely cold/unrelated key stays behind the atomic 2D/transition cover.
  return {}, false, false
end

-- Pure address probe for the headless regression suite. HorizonWall is an
-- internal module (not part of PublicFacade); exposing the canonical key and
-- rebase here lets tests prove a connection re-root is cache-identical without
-- constructing LOVE GPU resources.
function HorizonWall._canonicalAddress(state)
  local maps, baseX, baseY, canonical = canonicalAddress(state)
  return stateKey(state, maps, canonical), baseX, baseY, maps, canonical
end

-- Horizon geometry never reads ordinary interior body blocks. The only
-- block-dependent overlays (Route 8's cold seam and Viridian Forest's gate
-- mouths) verify cells in the outermost block row or column. Keep malformed
-- or mod-map metadata conservative, but avoid rebuilding a complete union for
-- an unrelated Cut tree in the middle of a route.
function HorizonWall.blockAffectsGeometry(map, bx, by)
  local def = map and map.def
  local w, h = def and def.width, def and def.height
  if type(w) ~= "number" or type(h) ~= "number"
     or type(bx) ~= "number" or type(by) ~= "number" then
    return true
  end
  return bx <= 0 or by <= 0 or bx >= w - 1 or by >= h - 1
end

-- Invalidate only unions that actually contain one edited/reloaded map.
-- Terrain edits are common (Cut, door stamps, regrowth), so a global
-- invalidate here would discard every shared skyline texture and every warm
-- handoff just to rebuild one local edge.  Ready entries remember their map
-- membership; pending jobs still own the same canonical map list; terminal
-- failures retain it as well.  WorldPlacement is cheap metadata and is reset
-- globally because a reload may have changed a connection graph rather than
-- merely a block.
function HorizonWall.invalidateMap(mapId)
  if mapId == nil then return false end
  mapId = tostring(mapId)
  local changed = false

  local readyDrop = {}
  for key, entry in pairs(readyCaches) do
    if containsMap(entry.mapIds, mapId) then readyDrop[#readyDrop + 1] = key end
  end
  for _, key in ipairs(readyDrop) do
    local entry = readyCaches[key]
    if entry then
      if lastReady == entry then lastReady = nil end
      releaseMeshes(entry.meshes)
      readyCaches[key] = nil
      changed = true
    end
  end

  local pendingDrop = {}
  for key, job in pairs(pendingJobs) do
    if jobContainsMap(job, mapId) then pendingDrop[#pendingDrop + 1] = key end
  end
  for _, key in ipairs(pendingDrop) do
    abandonPending(key)
    changed = true
  end

  for key, ids in pairs(failedKeys) do
    if containsMap(ids, mapId) then
      failedKeys[key] = nil
      failedCount = math.max(0, failedCount - 1)
      changed = true
    end
  end

  if WorldPlacement and type(WorldPlacement.invalidate) == "function" then
    WorldPlacement.invalidate()
  end
  return changed
end

function HorizonWall.invalidate()
  for _, entry in pairs(readyCaches) do releaseMeshes(entry.meshes) end
  for _, job in pairs(pendingJobs) do releaseMeshes(job.meshes) end
  readyCaches, pendingJobs, failedKeys = {}, {}, {}
  failedCount = 0
  lastReady, useSerial = nil, 0
  for k, tex in pairs(textures) do
    if tex and tex.release then pcall(tex.release, tex) end
    textures[k] = nil
  end
  textureFailures = {}
  if WorldPlacement and type(WorldPlacement.invalidate) == "function" then
    WorldPlacement.invalidate()
  end
end

return HorizonWall
