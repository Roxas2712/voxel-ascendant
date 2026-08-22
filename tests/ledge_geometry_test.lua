-- End-to-end visual ledge contract: the pure collision-derived datum reaches
-- terrain, scenery, auxiliary meshes, authored figures and dynamic ground.

package.preload["src.render.Assets"] = function()
  return { register = function() end }
end

local fieldData = {
  field = { ledges = {
    { facing = "down", input = "down", standingTile = 57, ledgeTile = 54 },
  } },
}
package.preload["src.core.Game"] = function() return { data = fieldData } end

local function keyOf(tx, ty)
  return (ty + 64) * 4096 + (tx + 64)
end

local function quad(x0, y0, z0, x1, y1, z1, shade)
  return {
    { x0, y0, z0 }, { x1, y0, z0 },
    { x1, y1, z1 }, { x0, y1, z1 },
    uv = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 } },
    shade = shade or 1,
  }
end

-- Two stacked Route-4-style DOWN lips at atlas resolution.  The collision
-- cell is 16px: its north 8px row is ordinary plateau ($2c), while only the
-- south 8px row carries the intrinsic six-pixel lip ($36/$37).  Modelling
-- both rows as ledge art hid the real half-cell trench regression.
local function fixtureTile(tx, ty)
  if ty == 3 or ty == 7 then return tx % 2 == 0 and 54 or 55 end
  return 44
end

local function analysis(decorated)
  local S = {
    skip = {}, runs = {}, shapeAt = {}, tileAt = {}, ground = {},
    objectQuads = {}, buildingStamps = {}, roundStamps = {},
    grassGroups = {}, flowerQuads = {}, figures = {},
  }
  for ty = 0, 11 do
    for tx = 0, 3 do
      local k = keyOf(tx, ty)
      local ledge = ty == 3 or ty == 7
      S.shapeAt[k] = {
        h = ledge and 6 or 0,
        art = ledge and "top" or "flat",
        class = ledge and "ledge" or "ground",
      }
      S.tileAt[k] = fixtureTile(tx, ty)
    end
  end
  if not decorated then return S end

  -- Claimed-object floor plus one rigid raw prop on the 12px upper terrace.
  S.skip[keyOf(0, 0)] = true
  S.ground[keyOf(0, 0)] = 0
  S.objectQuads[1] = quad(2, 0, 2, 3, 2, 2, 0.8)

  -- A profiled building and a round tree use shared local templates. Their
  -- synchronous expansion must match the 3D instance offsets tested by the
  -- dedicated instancing regression.
  S.buildingStamps[1] = {
    quads = { quad(0, 0, 0, 2, 3, 0, 0.9) }, mx = 16, mz = 4,
  }
  S.roundStamps[1] = {
    quads = { quad(0, 0, 0, 1, 4, 0, 0.85) }, mx = 8, mz = 8, r = 1,
  }

  S.grassGroups[1] = {
    quads = { quad(0, 0, 1, 2, 1, 1, 0.9) },
    placements = { 0, 0 },
  }
  S.flowerQuads[1] = quad(8, 0, 4, 9, 2, 4, 1)
  S.figures[1] = {
    quads = { quad(0, 0, 0, 2, 3, 0, 1) },
    wx = 0, wz = 8, y = 2,
  }
  return S
end

local plainS, decoratedS = analysis(false), analysis(true)
local waterS = analysis(false)
waterS.shapeAt[keyOf(0, 0)] = { h = -2, art = "flat", class = "water" }
local Structures = {
  forMap = function(map)
    if map.id == "LEDGE_DECORATED" then return decoratedS end
    if map.id == "LEDGE_WATER" then return waterS end
    return plainS
  end,
  invalidate = function() end,
}

local meshes = {}
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
    if #verts == 0 then return nil end
    local mesh = { verts = verts, indices = indices }
    function mesh:release() self.released = true end
    meshes[#meshes + 1] = mesh
    return mesh
  end,
  canInstance = function() return false end,
}

local cache, V = {}, {}
function V.data(name)
  if name == "voxel_heights" then
    return {
      heights = { ledge = 6 },
      tilesets = { OVERWORLD = { ledge = { 54, 55 } } },
    }
  end
end
function V.require(name)
  if cache[name] then return cache[name] end
  if name == "Structures" then
    cache[name] = Structures
  elseif name == "TileShape" then
    cache[name] = {}
  elseif name == "Voxel3D" then
    cache[name] = Voxel3D
  elseif name == "LedgeElevation" then
    cache[name] = assert(loadfile("lib/LedgeElevation.lua"))(V)
  elseif name == "BuildBudget" then
    cache[name] = assert(loadfile("lib/BuildBudget.lua"))()
  elseif name == "ModSetting" then
    cache[name] = { new = function() return { get = function() return true end } end }
  else
    error("unexpected dependency " .. tostring(name))
  end
  return cache[name]
end

local Mesher = assert(loadfile("lib/ChunkMesher.lua"))(V)

local function makeMap(id)
  local rows = {
    { 57, 57 }, -- S: upper terrace
    { 54, 54 }, -- L: intrinsic 6px lip, lower basis
    { 57, 57 }, -- S: middle terrace
    { 54, 54 }, -- L: intrinsic 6px lip, foot basis
    { 1, 1 },
    { 1, 1 },
  }
  local map = {
    id = id,
    rows = rows,
    widthCells = 2,
    heightCells = 6,
    def = { id = id, width = 1, height = 3,
            tileset = "OVERWORLD", connections = {} },
    tileset = { id = "OVERWORLD", tilesPerRow = 16,
                imageWidth = 128, imageHeight = 48 },
  }
  function map:inBounds(x, y)
    return x >= 0 and y >= 0 and x < self.widthCells
           and y < self.heightCells
  end
  function map:cellTile(x, y)
    return self.rows[y + 1] and self.rows[y + 1][x + 1]
  end
  function map:tileAt(tx, ty) return fixtureTile(tx, ty) end
  function map:isGrassCell() return true end
  return map
end

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected " .. tostring(expected)
          .. ", got " .. tostring(actual), 2)
  end
end

local function truth(value, message)
  if not value then error(message or "expected truthy value", 2) end
end

local plain = makeMap("LEDGE_PLAIN")
local beforeRows = {}
for y, row in ipairs(plain.rows) do beforeRows[y] = { row[1], row[2] } end
local verts = Mesher.geometry(plain, true)

local maxY = -math.huge
for _, v in ipairs(verts) do maxY = math.max(maxY, v[2]) end
eq(maxY, 12, "intrinsic lips are not added twice to stacked bases")

local tops = {}
for at = 1, #verts, 4 do
  local q = { verts[at], verts[at + 1], verts[at + 2], verts[at + 3] }
  local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
  local y = q[1][2]
  local flat = true
  for _, v in ipairs(q) do
    x0, x1 = math.min(x0, v[1]), math.max(x1, v[1])
    z0, z1 = math.min(z0, v[3]), math.max(z1, v[3])
    flat = flat and v[2] == y
  end
  if flat and x1 - x0 == 8 and z1 - z0 == 8 then
    tops[(x0 / 8) .. ":" .. (z0 / 8)] = y
  end
end
for tx = 0, 3 do
  eq(tops[tx .. ":2"], 12,
     "first lip's ordinary north half reaches the upper plateau")
  eq(tops[tx .. ":3"], 12,
     "first intrinsic lip reaches the same top without a double course")
  eq(tops[tx .. ":6"], 6,
     "second lip's ordinary north half reaches the middle plateau")
  eq(tops[tx .. ":7"], 6,
     "second intrinsic lip closes the middle plateau")
end

local firstFaces, secondFaces = 0, 0
for at = 1, #verts, 4 do
  local q = { verts[at], verts[at + 1], verts[at + 2], verts[at + 3] }
  local sameZ = q[1][3] == q[2][3] and q[2][3] == q[3][3]
                and q[3][3] == q[4][3]
  if sameZ then
    local lo = math.min(q[1][2], q[2][2], q[3][2], q[4][2])
    local hi = math.max(q[1][2], q[2][2], q[3][2], q[4][2])
    if q[1][3] == 32 and lo == 6 and hi == 12 then
      firstFaces = firstFaces + 1
    elseif q[1][3] == 64 and lo == 0 and hi == 6 then
      secondFaces = secondFaces + 1
    end
  end
end
eq(firstFaces, 4, "first authored run exposes one 6px face per tile")
eq(secondFaces, 4, "second authored run exposes one 6px face per tile")
for y, row in ipairs(plain.rows) do
  eq(row[1], beforeRows[y][1], "meshing never mutates gameplay collision")
  eq(row[2], beforeRows[y][2], "meshing never mutates gameplay collision")
end

local waterMap = makeMap("LEDGE_WATER")
local shoreVerts, _, _, waterVerts = Mesher.geometry(waterMap, true, nil, true)
truth(#waterVerts == 4, "split water keeps exactly its recessed surface quad")
for _, v in ipairs(waterVerts) do
  eq(v[2], 10, "water recess is measured from the 12px terrace datum")
end
local shoreBand = false
for at = 1, #shoreVerts, 4 do
  local lo, hi = math.huge, -math.huge
  for i = at, at + 3 do
    lo, hi = math.min(lo, shoreVerts[i][2]), math.max(hi, shoreVerts[i][2])
  end
  if lo == 10 and hi == 12 then shoreBand = true break end
end
truth(shoreBand, "ordinary shore compares absolute ledge-adjusted surfaces")

local decorated = makeMap("LEDGE_DECORATED")
local terrain = Mesher.get(decorated, true)
truth(terrain and terrain.verts, "decorated terrain built synchronously")

local synthesizedGround = false
for at = 1, #terrain.verts, 4 do
  local q = { terrain.verts[at], terrain.verts[at + 1],
              terrain.verts[at + 2], terrain.verts[at + 3] }
  local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
  local flat = true
  for _, v in ipairs(q) do
    x0, x1 = math.min(x0, v[1]), math.max(x1, v[1])
    z0, z1 = math.min(z0, v[3]), math.max(z1, v[3])
    flat = flat and v[2] == 12
  end
  if flat and x0 == 0 and x1 == 8 and z0 == 0 and z1 == 8 then
    synthesizedGround = true
    break
  end
end
truth(synthesizedGround, "claimed-object synthesized ground uses the terrace base")

local function hasY(mesh, y)
  for _, v in ipairs(mesh and mesh.verts or {}) do
    if v[2] == y then return true end
  end
  return false
end

-- Raw object (top 14), building (top 15) and round stamp (top 16) all start
-- from the same 12px floor; their distinct tops make each path observable.
truth(hasY(terrain, 14), "raw objectQuads received the terrace base")
truth(hasY(terrain, 15), "expanded building stamp received the terrace base")
truth(hasY(terrain, 16), "expanded round stamp received the terrace base")

local grass, flowers = Mesher.grass(decorated), Mesher.flowers(decorated)
truth(grass and hasY(grass, 12) and hasY(grass, 13),
      "expanded grass placement received the terrace base")
truth(flowers and hasY(flowers, 12) and hasY(flowers, 14),
      "flower quads received the terrace base")
local figures = Mesher.figures(decorated)
eq(#figures, 1, "authored figure survived auxiliary build")
eq(figures[1].y, 14, "authored figure support includes the terrace base")
eq(figures[1].mesh.verts[1][2], 0,
   "authored figure local mesh remains unshifted for its model matrix")

-- Load only VoxelScene's pure ground query. Empty siblings are sufficient
-- because module initialization does not draw; this proves entities, camera
-- eye and battle consumers receive the exact same surface as the mesher.
package.preload["src.render.PaletteFX"] = function()
  return { effectiveColors = function(c) return c end }
end
package.preload["src.world.Map"] = function() return {} end
local sceneV = {}
function sceneV.require(name)
  if name == "ChunkMesher" then return Mesher end
  if name == "TileShape" then
    return { forMap = function()
      return {
        [57] = { h = 0, art = "flat" },
        [54] = { h = 6, art = "top" },
        [1] = { h = 0, art = "flat" },
      }
    end }
  end
  return {}
end
local Scene = assert(loadfile("lib/VoxelScene.lua"))(sceneV)
eq(Scene.groundAt(decorated, 0, 0), 12, "entity/camera upper ground")
eq(Scene.groundAt(decorated, 0, 1), 12, "entity/camera lip surface")
eq(Scene.groundAt(decorated, 0, 2), 6, "entity/camera middle ground")
eq(Scene.groundAt(decorated, 0, 3), 6, "entity/camera second lip")
eq(Scene.groundAt(decorated, 0, 4), 0, "entity/camera terrace foot")
eq(Scene.groundAt(decorated, 0, -1), 0, "off-map seam ground remains zero")

-- Same-object block edit: ChunkMesher invalidation must evict the helper's
-- weak snapshot too, otherwise a rebuilt mesh and groundAt disagree forever.
decorated.rows[4][1], decorated.rows[4][2] = 1, 1
eq(Scene.groundAt(decorated, 0, 0), 12,
   "cached elevation remains stable until the edit is committed")
Mesher.invalidate(decorated.id)
eq(Scene.groundAt(decorated, 0, 0), 6,
   "mesher invalidation commits the edited ledge snapshot")

print("ledge geometry: ok")
