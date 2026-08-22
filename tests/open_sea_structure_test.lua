local fixtureShapes
local Structures

package.preload["src.render.Assets"] = function()
  return { register = function() end, imageData = function() return nil end }
end
package.preload["src.world.Map"] = function()
  return { isOutdoor = function() return true end }
end
package.preload["src.render.TileRenderer"] = function()
  return { borderBlockFor = function() return false end, voidFill = "water" }
end

local V = {}
function V.require(name)
  if name == "Buildings" then
    return { build = function() end, invalidate = function() end }
  elseif name == "TileShape" then
    return {
      forMap = function() return fixtureShapes end,
      at = function(_, shapeSet, tile) return shapeSet[tile] end,
      figures = function() return {} end,
      mounted = function() return {} end,
      propBg = function() return nil end,
      bookcaseBackfill = function() return nil end,
      bookcaseRelief = function() return false end,
    }
  elseif name == "BuildBudget" then
    return { tick = function() end, check = function() end }
  elseif name == "Structures" then
    return Structures
  elseif name == "Voxel3D" then
    return {
      FACE_SHADE = { 0.84, 0.72, 1, 0.55, 0.90, 0.68 },
      canInstance = function() return false end,
      pushQuad = function(indices, quad)
        local base = quad * 4
        for _, index in ipairs({ 1, 2, 3, 1, 3, 4 }) do
          indices[#indices + 1] = base + index
        end
      end,
    }
  elseif name == "LedgeElevation" then
    return {
      map = function()
        return {
          at = function() return 0 end,
          atTile = function() return 0 end,
          atWorld = function() return 0 end,
        }
      end,
      invalidate = function() end,
    }
  elseif name == "ModSetting" then
    return { new = function()
      return { get = function() return true end }
    end }
  end
  error("unexpected dependency: " .. tostring(name))
end
function V.data() return {} end

Structures = assert(loadfile("lib/Structures.lua"))(V)

local function expect(ok, message)
  if not ok then error(message, 2) end
end

local function upvalue(fn, wanted)
  for i = 1, 100 do
    local name, value = debug.getupvalue(fn, i)
    if not name then break end
    if name == wanted then return value end
  end
end

local visualTile = upvalue(Structures.forMap, "openSeaVisualTile")
expect(type(visualTile) == "function",
       "open-sea visual normalizer is not wired into Structures.forMap")

local WATER = 20
local shapes = {
  [WATER] = { class = "water", art = "flat" },
  [42] = { class = "tree", art = "cylinder", authored = true },
  [43] = { class = "tree", art = "cylinder", authored = true },
  [58] = { class = "tree", art = "cylinder", authored = true },
  [59] = { class = "tree", art = "cylinder", authored = true },
  [99] = { class = "wall", art = "upright" },
}
shapes.classes = {
  water = shapes[WATER],
  ground = { class = "ground", art = "flat", flat = true, h = 0 },
  void = { class = "void", art = "flat", flat = true, h = 0 },
  wall = shapes[99],
}
shapes[WATER].flat, shapes[WATER].h = true, -2
shapes[0x30] = shapes.classes.ground
shapes[0x39] = shapes.classes.ground
for _, tile in ipairs({ 42, 43, 58, 59 }) do shapes[tile].h = 24 end
fixtureShapes = shapes

do
  local route8 = { id = "ROUTE_8", def = { width = 30, height = 9 } }
  local hedge = Structures.route8VisualShape(route8, shapes[42], 42, 20, 10)
  expect(hedge.class == "route8_hedge" and hedge.art == "upright"
         and hedge.h == 8 and hedge.topTile == 44 and hedge.authored,
         "Route 8 canonical canopy did not become a low rigid course")
  expect(Structures.route8VisualShape(route8, shapes[42], 42, -1, 10)
         == shapes[42], "Route 8 streamed ring was rewritten")
  expect(Structures.route8VisualShape({ id = "ROUTE_7", def = route8.def },
                                      shapes[42], 42, 20, 10) == shapes[42],
         "Route 8 hedge rule leaked to another map")
end

-- The resident Lavender body owns the approach seen through Route 8's east
-- seam.  Normalize only its four canonical checker cells to Route 8's actual
-- light path tile; raw map bytes and collision remain the sole gameplay truth.
do
  local pathTile = Structures.route8ApproachVisualTile
  expect(type(pathTile) == "function",
         "Route 8/Lavender path visual normalizer is not exported")
  local lavender = {
    id = "LAVENDER_TOWN",
    def = {
      id = "LAVENDER_TOWN", width = 10, height = 9,
      tileset = "OVERWORLD",
      connections = { west = { map = "ROUTE_8", offset = 0 } },
    },
    _tiles = {},
  }
  function lavender:tileAt(tx, ty) return self._tiles[ty * 4096 + tx] or 0 end
  function lavender:isWalkableCell(cx, cy)
    return cx >= 0 and cx <= 3 and cy == 8
  end
  for cx = 0, 3 do
    local ax, ay = cx * 2, 16
    lavender._tiles[ay * 4096 + ax] = 0x30
    lavender._tiles[ay * 4096 + ax + 1] = 0x39
    lavender._tiles[(ay + 1) * 4096 + ax] = 0x39
    lavender._tiles[(ay + 1) * 4096 + ax + 1] = 0x30
  end
  local before = {}
  for key, value in pairs(lavender._tiles) do before[key] = value end
  for tx = 0, 7 do
    for ty = 16, 17 do
      expect(pathTile(lavender, lavender:tileAt(tx, ty), tx, ty) == 0x39,
             "canonical Lavender approach did not reuse white path material")
    end
  end
  expect(pathTile(lavender, 0x30, 8, 16) == 0x30,
         "Lavender path repaint escaped x=0..3")
  for key, value in pairs(before) do
    expect(lavender._tiles[key] == value,
           "Lavender visual path mutated a raw tile")
  end
  expect(lavender:isWalkableCell(0, 8)
         and not lavender:isWalkableCell(0, 7),
         "Lavender visual path mutated collision")

  lavender._tiles[16 * 4096 + 1] = 0x30
  expect(pathTile(lavender, lavender:tileAt(2, 16), 2, 16) == 0x39,
         "canonical neighboring Lavender cell was affected by one edit")
  expect(pathTile(lavender, lavender:tileAt(0, 16), 0, 16) == 0x30,
         "edited Lavender cell did not fail closed to its raw tile")
  lavender._tiles[16 * 4096 + 1] = 0x39
  lavender.def.connections.west.offset = 1
  expect(pathTile(lavender, 0x30, 0, 16) == 0x30,
         "noncanonical Route 8 offset inherited Lavender path art")
  lavender.def.connections.west.offset = 0
  lavender.isWalkableCell = function() return false end
  expect(pathTile(lavender, 0x30, 0, 16) == 0x30,
         "blocked Lavender cell inherited walkable path art")
  expect(pathTile({ id = "SAFFRON_CITY", def = lavender.def },
                  0x30, 0, 16) == 0x30,
         "Lavender path normalizer repainted Saffron's existing road")
end

local BLOCK = {
  [20] = { 42,43,20,20, 58,59,20,20,
           42,43,42,43, 58,59,58,59 },
  [24] = { 42,43,20,20, 58,59,20,20,
           42,43,20,20, 58,59,20,20 },
  [25] = { 20,20,42,43, 20,20,58,59,
           20,20,42,43, 20,20,58,59 },
  [67] = { 20,20,20,20, 20,20,20,20,
           20,20,20,20, 20,20,20,20 },
  [107] = { 20,20,20,20, 20,20,20,20,
            42,43,42,43, 58,59,58,59 },
}

local function map(id, width, height, connections)
  local out = {
    id = id,
    def = {
      id = id, width = width, height = height,
      tileset = "OVERWORLD", connections = connections or {},
    },
    waterTiles = { [WATER] = true },
    _tiles = {},
  }
  function out:tileAt(tx, ty)
    return self._tiles[ty * 4096 + tx] or WATER
  end
  return out
end

local function normalizedBlock(m, bx, by, blockId)
  local out = {}
  for ly = 0, 3 do
    for lx = 0, 3 do
      local at = ly * 4 + lx + 1
      m._tiles[(by * 4 + ly) * 4096 + bx * 4 + lx] = BLOCK[blockId][at]
    end
  end
  for ly = 0, 3 do
    for lx = 0, 3 do
      local at = ly * 4 + lx + 1
      out[at] = visualTile(m, shapes, m:tileAt(bx * 4 + lx, by * 4 + ly),
                           bx * 4 + lx, by * 4 + ly)
    end
  end
  return out
end

local function allWater(block, message)
  for i, tile in ipairs(block) do
    expect(tile == WATER, message .. " at block tile " .. tostring(i))
  end
end

local function sameBlock(actual, blockId, message)
  local expected = BLOCK[blockId]
  for i, tile in ipairs(actual) do
    expect(tile == expected[i], message .. " at block tile " .. tostring(i))
  end
end

-- These are the native Kanto block layouts that produced the LIVE-pilot
-- rows: 107 is horizontal water-over-round-stop, 24/25 are the two vertical
-- variants.  Only the one-block strip on a genuinely free sea side flattens.
local route20 = map("ROUTE_20", 50, 9,
                    { west = { map = "CINNABAR_ISLAND" },
                      east = { map = "ROUTE_19" } })
allWater(normalizedBlock(route20, 12, 0, 107),
         "Route 20 north stop row survived")
allWater(normalizedBlock(route20, 12, 8, 107),
         "Route 20 south stop row survived")
sameBlock(normalizedBlock(route20, 12, 1, 107), 107,
          "Route 20 normalization escaped the outer block band")
sameBlock(normalizedBlock(route20, 0, 4, 24), 24,
          "Route 20 west connection geometry was modified")
sameBlock(normalizedBlock(route20, 49, 4, 25), 25,
          "Route 20 east connection geometry was modified")

-- Route 20's native south-row corner block turns inward by one cell before
-- reaching the free side. The bounded chain follows that one canonical stop
-- cell to water, removing the final isolated cylinder without escaping the
-- four-tile outer band.
allWater(normalizedBlock(route20, 31, 8, 20),
         "Route 20 south stop corner survived")

local route19 = map("ROUTE_19", 10, 27,
                    { north = { map = "FUCHSIA_CITY" },
                      west = { map = "ROUTE_20" } })
allWater(normalizedBlock(route19, 9, 12, 25),
         "Route 19 east stop column survived")
allWater(normalizedBlock(route19, 4, 26, 107),
         "Route 19 south stop row survived")
sameBlock(normalizedBlock(route19, 0, 12, 24), 24,
          "Route 19 west connection geometry was modified")

local route21 = map("ROUTE_21", 10, 45,
                    { north = { map = "PALLET_TOWN" },
                      south = { map = "CINNABAR_ISLAND" } })
allWater(normalizedBlock(route21, 0, 20, 24),
         "Route 21 west stop column survived")
allWater(normalizedBlock(route21, 9, 20, 25),
         "Route 21 east stop column survived")
sameBlock(normalizedBlock(route21, 4, 0, 107), 107,
          "Route 21 north connection geometry was modified")

local cinnabar = map("CINNABAR_ISLAND", 10, 9,
                     { north = { map = "ROUTE_21" },
                       east = { map = "ROUTE_20" } })
allWater(normalizedBlock(cinnabar, 0, 4, 24),
         "Cinnabar west stop column survived")
allWater(normalizedBlock(cinnabar, 4, 8, 107),
         "Cinnabar south stop row survived")
sameBlock(normalizedBlock(cinnabar, 9, 4, 25), 25,
          "Cinnabar east connection geometry was modified")

-- The semantic side list is only an allowlist. Runtime connection metadata is
-- an additional fail-closed gate, and non-cylinder content never changes.
local connectedSouth = map("ROUTE_20", 50, 9,
                           { south = { map = "TEST_CONNECTION" } })
sameBlock(normalizedBlock(connectedSouth, 12, 8, 107), 107,
          "runtime connection did not override the open-sea allowlist")
expect(visualTile(route20, shapes, 99, 12, 2) == 99,
       "land/building geometry inside the edge band was flattened")
expect(visualTile(map("ROUTE_18", 10, 10), shapes, 42, 39, 20) == 42,
       "non-sea map inherited southern-sea normalization")

local partial = map("ROUTE_20", 50, 9)
normalizedBlock(partial, 12, 0, 107)
partial._tiles[2 * 4096 + 12 * 4 + 1] = 99
expect(visualTile(partial, shapes, 42, 12 * 4, 2) == 42,
       "partial/edited cylinder cell was mistaken for the canonical stop")

local noCanonicalWater = map("ROUTE_20", 50, 9)
noCanonicalWater.waterTiles = { [50] = true }
expect(visualTile(noCanonicalWater, shapes, 42, 12, 2) == 42,
       "unknown water material was replaced with a hard-coded texture")

-- Real-ROM probe. This loads the canonical generated map/block data used by
-- Gen1Recomp rather than repeating a screenshot-shaped tile fixture. It proves
-- the exact outer-ring population and then runs the real Route 20 body through
-- Structures: 201 decorative edge cells become water, while the remaining 33
-- collision-significant Seafoam cells become one low, visible reef profile.
local genRoot = os.getenv("GEN1RECOMP_0190_ROOT") or "../gen1recomp"
local realMaps = assert(loadfile(genRoot .. "/data/generated/maps.lua"))()
local realTilesets = assert(loadfile(genRoot .. "/data/generated/tilesets.lua"))()
local RealMap = assert(loadfile(genRoot .. "/src/world/Map.lua"))()

local function realMap(id)
  local def = assert(realMaps[id], "missing real map " .. id)
  return RealMap.new(def, assert(realTilesets[def.tileset]))
end

local Mesher = assert(loadfile("lib/ChunkMesher.lua"))(V)

-- Canonical source evidence for Horizon's cold-only seam proxies.  West owns
-- three different white-path 2x2 phases; east is the all-$39 lane.  Pin the
-- real ROM data and collision rather than letting a hand-written visual
-- fixture become the authority for those atlas UVs.
do
  local route8 = realMap("ROUTE_8")
  local expected = {
    [8] = { 0x23, 0x23, 0x39, 0x23 },
    [9] = { 0x23, 0x23, 0x23, 0x23 },
    [10] = { 0x39, 0x39, 0x39, 0x39 },
  }
  for cy = 8, 10 do
    expect(route8:isWalkableCell(0, cy),
           "real Route 8 west seam lane ceased to be walkable")
    for dy = 0, 1 do
      for dx = 0, 1 do
        expect(route8:tileAt(dx, cy * 2 + dy)
               == expected[cy][dy * 2 + dx + 1],
               "real Route 8 west seam source material changed")
      end
    end
  end
  expect(route8:isWalkableCell(59, 8),
         "real Route 8 east seam lane ceased to be walkable")
  for dy = 0, 1 do
    for dx = 0, 1 do
      expect(route8:tileAt(118 + dx, 16 + dy) == 0x39,
             "real Route 8 east seam source material changed")
    end
  end
end

-- Real-ROM integration for the exact east-seam report.  The four target-owned
-- Lavender cells become one narrow white material strip inside Structures'
-- visual grid, while the generated block list, raw checker and collision API
-- remain byte-for-byte authoritative.
do
  local lavender = realMap("LAVENDER_TOWN")
  expect(lavender.def.connections.west.map == "ROUTE_8"
         and lavender.def.connections.west.offset == 0,
         "real Lavender/Route 8 connection fixture changed")
  local blocksBefore = table.concat(lavender.def.blocks, ",")
  local raw, walkable = {}, {}
  for cx = 0, 3 do
    walkable[cx] = lavender:isWalkableCell(cx, 8)
    expect(walkable[cx], "real Lavender approach ceased to be walkable")
    for dy = 0, 1 do
      for dx = 0, 1 do
        local tx, ty = cx * 2 + dx, 16 + dy
        local expected = (dx + dy) % 2 == 0 and 0x30 or 0x39
        raw[ty * 4096 + tx] = lavender:tileAt(tx, ty)
        expect(raw[ty * 4096 + tx] == expected,
               "real Lavender checker fixture changed")
      end
    end
  end
  Structures.invalidate("LAVENDER_TOWN")
  local visual = Structures.forMap(lavender)
  for cx = 0, 3 do
    for dy = 0, 1 do
      for dx = 0, 1 do
        local tx, ty = cx * 2 + dx, 16 + dy
        local key = (ty + 64) * 4096 + (tx + 64)
        expect((visual.topTileAt[key] or visual.tileAt[key]) == 0x39,
               "real Lavender approach kept a green top material quadrant")
        expect(visual.tileAt[key] == raw[ty * 4096 + tx],
               "real Lavender structure classification lost raw art")
        expect(lavender:tileAt(tx, ty) == raw[ty * 4096 + tx],
               "real Lavender visual material mutated map tiles")
      end
    end
    expect(lavender:isWalkableCell(cx, 8) == walkable[cx],
           "real Lavender visual material mutated collision")
  end
  expect(table.concat(lavender.def.blocks, ",") == blocksBefore,
         "real Lavender visual material mutated generated block bytes")

  -- Run that same real map through the final ChunkMesher branch.  This is the
  -- renderer-visible contract: all sixteen top quads select the exact $39 UV,
  -- whereas a fail-closed noncanonical connection retains the raw 8x$30 +
  -- 8x$39 checker with byte-identical geometry.
  local function topTileU(vertices, tx, ty)
    local wantedX, wantedZ = tx * 8, ty * 8
    local hit, count
    count = 0
    for at = 1, #vertices, 4 do
      local a, b, c, d = vertices[at], vertices[at + 1],
                         vertices[at + 2], vertices[at + 3]
      if a[1] == wantedX and a[3] == wantedZ and a[2] == 0
         and b[1] == wantedX + 8 and b[3] == wantedZ and b[2] == 0
         and c[1] == wantedX + 8 and c[3] == wantedZ + 8 and c[2] == 0
         and d[1] == wantedX and d[3] == wantedZ + 8 and d[2] == 0 then
        hit, count = a[4], count + 1
      end
    end
    expect(count == 1, "real Lavender top quad was missing or duplicated")
    return hit
  end
  local whiteU = ((0x39 % 16) * 8 + 0.02) / 128
  local darkU = ((0x30 % 16) * 8 + 0.02) / 128
  local meshed, meshedIndices, meshedQuads = Mesher.geometry(lavender, true)
  for tx = 0, 7 do
    for ty = 16, 17 do
      expect(math.abs(topTileU(meshed, tx, ty) - whiteU) < 1e-12,
             "final real Lavender top UV is not Route 8's $39 material")
    end
  end

  lavender.def.connections.west.offset = 1
  Structures.invalidate("LAVENDER_TOWN")
  local rawMesh, rawIndices, rawQuads = Mesher.geometry(lavender, true)
  expect(#rawMesh == #meshed and #rawIndices == #meshedIndices
         and rawQuads == meshedQuads,
         "Lavender visual material changed final geometry budget")
  local rawDark, rawWhite = 0, 0
  for tx = 0, 7 do
    for ty = 16, 17 do
      local u = topTileU(rawMesh, tx, ty)
      if math.abs(u - darkU) < 1e-12 then rawDark = rawDark + 1
      elseif math.abs(u - whiteU) < 1e-12 then rawWhite = rawWhite + 1
      else error("noncanonical Lavender retained an unknown final top UV") end
    end
  end
  expect(rawDark == 8 and rawWhite == 8,
         "noncanonical Lavender did not retain its raw checker UVs")
  lavender.def.connections.west.offset = 0
  Structures.invalidate("LAVENDER_TOWN")
end

local function canonicalCell(m, cx, cy)
  local tx, ty = cx * 2, cy * 2
  return m:tileAt(tx, ty) == 42 and m:tileAt(tx + 1, ty) == 43
     and m:tileAt(tx, ty + 1) == 58
     and m:tileAt(tx + 1, ty + 1) == 59
end

local function normalizedRealCells(id)
  local m = realMap(id)
  local raw, flattened = 0, 0
  for cy = 0, m.heightCells - 1 do
    for cx = 0, m.widthCells - 1 do
      if canonicalCell(m, cx, cy) then
        raw = raw + 1
        local tx, ty = cx * 2, cy * 2
        if visualTile(m, shapes, m:tileAt(tx, ty), tx, ty) == WATER then
          flattened = flattened + 1
        end
      end
    end
  end
  return m, raw, flattened
end

local realRoute20, route20Raw, route20Flat = normalizedRealCells("ROUTE_20")
local _, _, route19Flat = normalizedRealCells("ROUTE_19")
local _, _, route21Flat = normalizedRealCells("ROUTE_21")
local _, _, cinnabarFlat = normalizedRealCells("CINNABAR_ISLAND")
expect(route20Raw == 234, "unexpected canonical Route 20 quartet population")
expect(route20Flat == 201, "real Route 20 edge normalization is incomplete")
expect(route19Flat == 66, "real Route 19 edge normalization drifted")
expect(route21Flat == 155, "real Route 21 edge normalization drifted")
expect(cinnabarFlat == 37, "real Cinnabar edge normalization drifted")

local barrierTile = realRoute20:cellTile(43, 8)
local barrierWater = realRoute20:isWaterCell(43, 8)
local barrierWalkable = realRoute20:isWalkableCell(43, 8)
local platformTile = realRoute20:cellTile(34, 9)
local platformWalkable = realRoute20:isWalkableCell(34, 9)
local blocksBefore = table.concat(realRoute20.def.blocks, ",")
expect(barrierTile == 58 and not barrierWater and not barrierWalkable,
       "real Seafoam navigation barrier fixture changed")
expect(platformTile == 60 and platformWalkable,
       "real Route 20 west platform fixture changed")
expect(realRoute20.def.connections.west.map == "CINNABAR_ISLAND"
       and realRoute20.def.connections.east.map == "ROUTE_19",
       "real Route 20 connection fixture changed")

Structures.invalidate("ROUTE_20")
local realStructure = Structures.forMap(realRoute20)
local reefCells, reefTiles = 0, 0
for cy = 0, realRoute20.heightCells - 1 do
  for cx = 0, realRoute20.widthCells - 1 do
    local reef = false
    for dy = 0, 1 do
      for dx = 0, 1 do
        local tx, ty = cx * 2 + dx, cy * 2 + dy
        local key = (ty + 64) * 4096 + (tx + 64)
        local shape = realStructure.shapeAt[key]
        if shape and shape.class == "reef" then
          reef = true
          reefTiles = reefTiles + 1
          expect(shape.art == "top" and shape.h == 2,
                 "Seafoam reef is not a low top-profile")
          expect(realStructure.tileAt[key] == realRoute20:tileAt(tx, ty),
                 "Seafoam reef lost its authored quadrant texture")
          expect(not realStructure.skip[key] and not realStructure.ground[key],
                 "Seafoam reef retained a cylinder claim or mint shelf")
        end
      end
    end
    if reef then reefCells = reefCells + 1 end
  end
end
expect(reefCells == 33 and reefTiles == 132,
       "real Seafoam reef coverage is not the exact 33-cell barrier")
expect(#realStructure.roundStamps == 0,
       "real Route 20 retained a full-height round stamp")
expect(table.concat(realRoute20.def.blocks, ",") == blocksBefore
       and realRoute20:cellTile(43, 8) == barrierTile
       and realRoute20:isWaterCell(43, 8) == barrierWater
       and realRoute20:isWalkableCell(43, 8) == barrierWalkable,
       "visual reef classification mutated gameplay map/collision data")
expect(realRoute20:cellTile(34, 9) == platformTile
       and realRoute20:isWalkableCell(34, 9) == platformWalkable,
       "visual reef classification modified the west platform")
Structures.invalidate("ROUTE_20")

-- Integration through Structures.forMap: the normalized outer cells resolve
-- as recessed water before buildCylinders scans them, so they create neither
-- a round claim nor the synthesized green ground seen in the LIVE pilot. The
-- connected water-opposed inner row resolves to the low reef profile instead
-- of reintroducing full-height drums.
local integrated = map("ROUTE_20", 3, 3,
                       { west = { map = "CINNABAR_ISLAND" },
                         east = { map = "ROUTE_19" } })
integrated.tileset = {
  id = "OVERWORLD", image = "headless-overworld.png",
  imageWidth = 128, imageHeight = 48, tilesPerRow = 16,
  blocks = {},
}
integrated.doorTiles, integrated.walkable = {}, {}
function integrated:cellTile(cx, cy)
  return self:tileAt(cx * 2, cy * 2 + 1)
end
function integrated:isWaterCell(cx, cy)
  return self.waterTiles[self:cellTile(cx, cy)] or false
end
function integrated:isWalkableCell() return false end
for by = 0, 2 do
  for bx = 0, 2 do normalizedBlock(integrated, bx, by, 107) end
end

local structure = Structures.forMap(integrated)
local function structureKey(tx, ty)
  return (ty + 64) * 4096 + (tx + 64)
end
local claimed, syntheticGround, reefTiles = 0, 0, 0
for ty = 0, integrated.def.height * 4 - 1 do
  for tx = 0, integrated.def.width * 4 - 1 do
    local key = structureKey(tx, ty)
    if structure.skip[key] then claimed = claimed + 1 end
    if structure.ground[key] then syntheticGround = syntheticGround + 1 end
    local shape = structure.shapeAt[key]
    if shape and shape.class == "reef" then
      reefTiles = reefTiles + 1
      expect(shape.h == 2 and shape.art == "top",
             "integrated reef is not low, flat geometry")
    end
    if ty < 4 or ty >= 8 then
      expect(structure.tileAt[key] == WATER,
             "outer Route 20 structure grid retained a non-water tile")
      expect(not structure.skip[key],
             "outer Route 20 structure grid retained a cylinder claim")
      expect(not structure.ground[key],
             "outer Route 20 structure grid retained synthesized land")
    end
  end
end
expect(claimed == 0,
       "Route 20 water barrier retained a full-height cylinder claim")
expect(syntheticGround == 0,
       "Route 20 water barrier retained synthesized mint ground")
expect(reefTiles == 24,
       "the six inward barrier cells did not become a continuous low reef")

print("open sea structure normalization: ok")
