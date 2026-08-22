-- CAVERN's pure-black $3C body art is a flat visual void, not the tileset's
-- real $22 fall-through hole. Low cameras still need to see that the existing
-- top quad is a dark surface. This regression uses the canonical Yellow
-- MT_MOON_B1F block layout and its exact anchor coordinates, then gates the
-- three scopes that must stay black: the border ring, other tilesets and $22.

package.preload["src.render.Assets"] = function()
  return { register = function() end }
end

local function keyOf(tx, ty)
  return (ty + 64) * 4096 + (tx + 64)
end

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected " .. tostring(expected)
          .. ", got " .. tostring(actual), 2)
  end
end

local function near(actual, expected, message)
  if math.abs(actual - expected) > 1e-9 then
    error((message or "values differ") .. ": expected " .. tostring(expected)
          .. ", got " .. tostring(actual), 2)
  end
end

local function truth(value, message)
  if not value then error(message or "expected truthy value", 2) end
end

-- Exact 14x14 canonical Yellow MT_MOON_B1F block map. Only five CAVERN
-- blocks occur here; their exact 4x4 tile definitions follow below.
local B1F_BLOCKS = {
  { 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x3f, 0x3f, 0x3f, 0x3f },
  { 0x03, 0x03, 0x3f, 0x3f, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x19, 0x3c, 0x19, 0x3d },
  { 0x03, 0x03, 0x3d, 0x19, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03 },
  { 0x03, 0x03, 0x19, 0x19, 0x03, 0x03, 0x03, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x03 },
  { 0x03, 0x03, 0x19, 0x19, 0x03, 0x03, 0x03, 0x19, 0x19, 0x19, 0x19, 0x19, 0x3d, 0x03 },
  { 0x03, 0x03, 0x19, 0x19, 0x03, 0x03, 0x03, 0x19, 0x3c, 0x19, 0x19, 0x19, 0x19, 0x03 },
  { 0x03, 0x03, 0x19, 0x19, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x3f, 0x3f },
  { 0x03, 0x03, 0x19, 0x19, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x03, 0x3d, 0x19 },
  { 0x03, 0x03, 0x19, 0x19, 0x19, 0x19, 0x19, 0x19, 0x19, 0x19, 0x3c, 0x03, 0x19, 0x19 },
  { 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x19, 0x19 },
  { 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x19, 0x19 },
  { 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x19, 0x19 },
  { 0x03, 0x03, 0x03, 0x03, 0x03, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x19, 0x19 },
  { 0x03, 0x03, 0x03, 0x03, 0x03, 0x19, 0x3c, 0x19, 0x19, 0x19, 0x19, 0x19, 0x19, 0x19 },
}

local function repeated(tile)
  local out = {}
  for i = 1, 16 do out[i] = tile end
  return out
end

local CAVERN_BLOCKS = {
  [0x03] = repeated(0x3c),
  [0x19] = repeated(0x05),
  [0x3c] = {
    0x05, 0x05, 0x05, 0x05,
    0x05, 0x05, 0x05, 0x05,
    0x05, 0x05, 0x08, 0x09,
    0x05, 0x05, 0x18, 0x19,
  },
  [0x3d] = {
    0x05, 0x05, 0x05, 0x05,
    0x05, 0x05, 0x05, 0x05,
    0x05, 0x05, 0x0a, 0x0b,
    0x05, 0x05, 0x1a, 0x1b,
  },
  [0x3f] = {
    0x3c, 0x3c, 0x3c, 0x3c,
    0x3c, 0x3c, 0x3c, 0x3c,
    0x10, 0x10, 0x10, 0x10,
    0x10, 0x10, 0x10, 0x10,
  },
}

local WALKABLE = {
  [0x05] = true, [0x15] = true, [0x18] = true, [0x1a] = true,
  [0x20] = true, [0x21] = true, [0x22] = true, [0x2a] = true,
  [0x2d] = true, [0x30] = true,
}

local function canonicalB1F()
  local map = {
    id = "MT_MOON_B1F",
    widthCells = 28,
    heightCells = 28,
    def = { id = "MT_MOON_B1F", width = 14, height = 14,
            borderBlock = 0x03, tileset = "CAVERN", connections = {} },
    tileset = { id = "CAVERN", tilesPerRow = 16,
                imageWidth = 128, imageHeight = 40 },
  }
  function map:tileAt(tx, ty)
    local bx, by = math.floor(tx / 4), math.floor(ty / 4)
    local blockId
    if bx < 0 or by < 0 or bx >= 14 or by >= 14 then
      blockId = self.def.borderBlock
    else
      blockId = B1F_BLOCKS[by + 1][bx + 1]
    end
    local block = assert(CAVERN_BLOCKS[blockId])
    return block[(ty % 4) * 4 + (tx % 4) + 1]
  end
  function map:cellTile(cx, cy)
    return self:tileAt(cx * 2, cy * 2 + 1)
  end
  function map:inBounds(cx, cy)
    return cx >= 0 and cy >= 0 and cx < 28 and cy < 28
  end
  function map:isWalkableCell(cx, cy)
    return self:inBounds(cx, cy) and WALKABLE[self:cellTile(cx, cy)] or false
  end
  function map:warpPadOrHoleAt(cx, cy)
    return self:cellTile(cx, cy) == 0x22 and "hole" or nil
  end
  return map
end

local function emptyAnalysis()
  return {
    skip = {}, runs = {}, shapeAt = {}, tileAt = {}, ground = {},
    objectQuads = {}, buildingStamps = {}, roundStamps = {},
    grassGroups = {}, flowerQuads = {}, figures = {},
  }
end

local VOID = { h = 0, art = "flat", flat = true, class = "void" }
local LEDGE = { h = 6, art = "top", class = "ledge" }
local GROUND = { h = 0, art = "flat", flat = true, class = "ground" }

local function addCell(S, map, cx, cy, shape)
  for dy = 0, 1 do
    for dx = 0, 1 do
      local tx, ty = cx * 2 + dx, cy * 2 + dy
      local k = keyOf(tx, ty)
      S.shapeAt[k], S.tileAt[k] = shape, map:tileAt(tx, ty)
    end
  end
end

local b1f = canonicalB1F()

-- The screenshot anchor and its exact west void boundary.
eq(b1f:cellTile(13, 10), 0x3c, "B1F west boundary is canonical $3C")
truth(not b1f:isWalkableCell(13, 10), "$3C remains collision-blocked")
eq(b1f:warpPadOrHoleAt(13, 10), nil, "$3C is not a fall-through hole")
eq(b1f:cellTile(15, 10), 0x05, "B1F anchor is canonical $05 shelf")
truth(b1f:isWalkableCell(15, 10), "B1F anchor remains walkable")

local blackTiles, realHoleTiles, pureVoidCells = 0, 0, 0
for ty = 0, 55 do
  for tx = 0, 55 do
    local tile = b1f:tileAt(tx, ty)
    if tile == 0x3c then blackTiles = blackTiles + 1 end
    if tile == 0x22 or tile == 0x2f then realHoleTiles = realHoleTiles + 1 end
  end
end
for cy = 0, 27 do
  for cx = 0, 27 do
    local pure = true
    for dy = 0, 1 do
      for dx = 0, 1 do
        pure = pure and b1f:tileAt(cx * 2 + dx, cy * 2 + dy) == 0x3c
      end
    end
    if pure then pureVoidCells = pureVoidCells + 1 end
  end
end
eq(blackTiles, 1984, "canonical B1F $3C tile count")
eq(pureVoidCells, 496, "canonical B1F pure-void cell count")
eq(realHoleTiles, 0, "canonical B1F contains no $22/$2F hole art")

local S = emptyAnalysis()
addCell(S, b1f, 13, 10, VOID)
addCell(S, b1f, 14, 10, LEDGE)
addCell(S, b1f, 15, 10, LEDGE)
-- One real border-ring tile, deliberately outside the authored body.
S.shapeAt[keyOf(-1, 20)] = VOID
S.tileAt[keyOf(-1, 20)] = 0x3c
b1f.analysis = S

local Structures = {
  forMap = function(map) return assert(map.analysis) end,
  invalidate = function() end,
}

local Voxel3D = {
  FORMAT = {
    { "VertexPosition", "float", 3 },
    { "VertexTexCoord", "float", 2 },
    { "VertexShade", "float", 1 },
  },
  FACE_SHADE = { 0.84, 0.72, 1, 0.55, 0.90, 0.68 },
  pushQuad = function(indices, n)
    local base = n * 4
    for _, i in ipairs({ 1, 2, 3, 1, 3, 4 }) do
      indices[#indices + 1] = base + i
    end
  end,
  newMesh = function(verts, indices)
    return { verts = verts, indices = indices, release = function() end }
  end,
  canInstance = function() return false end,
}

local cache, V = {}, {}
function V.require(name)
  if cache[name] then return cache[name] end
  if name == "Structures" then
    cache[name] = Structures
  elseif name == "TileShape" then
    cache[name] = {}
  elseif name == "Voxel3D" then
    cache[name] = Voxel3D
  elseif name == "LedgeElevation" then
    cache[name] = {
      map = function()
        return {
          at = function() return 0 end,
          atTile = function() return 0 end,
        }
      end,
      invalidate = function() end,
    }
  elseif name == "BuildBudget" then
    cache[name] = assert(loadfile("lib/BuildBudget.lua"))()
  elseif name == "ModSetting" then
    cache[name] = { new = function()
      return { get = function() return true end }
    end }
  else
    error("unexpected dependency " .. tostring(name))
  end
  return cache[name]
end

local Mesher = assert(loadfile("lib/ChunkMesher.lua"))(V)

local function findTop(verts, tx, ty)
  local x0, x1, z0, z1 = tx * 8, tx * 8 + 8, ty * 8, ty * 8 + 8
  for at = 1, #verts, 4 do
    local q = { verts[at], verts[at + 1], verts[at + 2], verts[at + 3] }
    local minX, maxX = math.huge, -math.huge
    local minZ, maxZ = math.huge, -math.huge
    local y, flat = q[1][2], true
    for _, vertex in ipairs(q) do
      minX, maxX = math.min(minX, vertex[1]), math.max(maxX, vertex[1])
      minZ, maxZ = math.min(minZ, vertex[3]), math.max(maxZ, vertex[3])
      flat = flat and vertex[2] == y
    end
    if flat and minX == x0 and maxX == x1 and minZ == z0 and maxZ == z1 then
      return q, y
    end
  end
  return nil
end

local function expectTile(q, tile, shade, message)
  truth(q, message .. " top quad exists")
  local ax = (tile % 16) * 8
  local ay = math.floor(tile / 16) * 8
  local u0, u1 = (ax + 0.02) / 128, (ax + 7.98) / 128
  local v0, v1 = (ay + 0.02) / 40, (ay + 7.98) / 40
  near(q[1][4], u0, message .. " u0")
  near(q[2][4], u1, message .. " u1")
  near(q[1][5], v0, message .. " v0")
  near(q[3][5], v1, message .. " v1")
  for i = 1, 4 do near(q[i][6], shade, message .. " shade " .. i) end
end

local beforeBlocks = {}
for y, row in ipairs(B1F_BLOCKS) do beforeBlocks[y] = table.concat(row, ",") end

local b1fVerts, b1fIndices, b1fQuads = Mesher.geometry(b1f, false)
local shadow, shadowY = findTop(b1fVerts, 26, 20)
expectTile(shadow, 0x20, 0.22, "in-body B1F $3C shadow floor")
eq(shadowY, 0, "$3C shadow floor keeps the cave datum")

local platform, platformY = findTop(b1fVerts, 30, 20)
truth(platform, "real B1F anchor shelf top remains present")
eq(platformY, 6, "real B1F anchor shelf keeps its six-pixel height")
near(platform[1][4], (0x05 * 8 + 0.02) / 128,
     "real B1F anchor keeps $05 art")

local ring, ringY = findTop(b1fVerts, -1, 20)
expectTile(ring, 0x3c, 1, "CAVERN border ring")
eq(ringY, 0, "CAVERN border ring keeps its datum")

-- Same exact geometry under a non-CAVERN definition: no visual substitution.
local other = {}
for k, value in pairs(b1f) do other[k] = value end
other.id = "NON_CAVERN_CONTROL"
other.def = { id = other.id, width = 14, height = 14,
              borderBlock = 0x03, tileset = "INTERIOR", connections = {} }
other.tileset = { id = "INTERIOR", tilesPerRow = 16,
                  imageWidth = 128, imageHeight = 40 }
local otherVerts, otherIndices, otherQuads = Mesher.geometry(other, false)
local otherVoid, otherY = findTop(otherVerts, 26, 20)
expectTile(otherVoid, 0x3c, 1, "non-CAVERN $3C")
eq(otherY, shadowY, "visual substitution never moves the surface")
eq(#otherVerts, #b1fVerts, "visual substitution adds no vertices")
eq(#otherIndices, #b1fIndices, "visual substitution adds no indices")
eq(otherQuads, b1fQuads, "visual substitution adds no quads")

-- The actual CAVERN fall-through tile remains its original top art/class.
local hole = {
  id = "CAVERN_REAL_HOLE",
  def = { id = "CAVERN_REAL_HOLE", width = 1, height = 1,
          borderBlock = 0x03, tileset = "CAVERN", connections = {} },
  tileset = b1f.tileset,
  analysis = emptyAnalysis(),
}
function hole:tileAt() return 0x22 end
hole.analysis.shapeAt[keyOf(0, 0)] = GROUND
hole.analysis.tileAt[keyOf(0, 0)] = 0x22
local holeVerts = Mesher.geometry(hole, true)
local holeTop, holeY = findTop(holeVerts, 0, 0)
expectTile(holeTop, 0x22, 1, "real CAVERN $22 hole")
eq(holeY, 0, "real CAVERN $22 keeps its authored datum")

for y, row in ipairs(B1F_BLOCKS) do
  eq(table.concat(row, ","), beforeBlocks[y], "meshing never mutates B1F blocks")
end
eq(b1f:cellTile(13, 10), 0x3c, "meshing never changes $3C collision")
truth(not b1f:isWalkableCell(13, 10), "meshing never opens $3C gameplay")
eq(b1f:cellTile(15, 10), 0x05, "meshing never changes anchor collision")
truth(b1f:isWalkableCell(15, 10), "meshing never closes anchor gameplay")
