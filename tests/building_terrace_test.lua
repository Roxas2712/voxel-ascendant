-- Route 4's real Pokemon Center footprint is an 8x8-tile drawing at
-- (20,4)..(27,11). Its northwest datum is 0 while its gameplay door cell
-- (11,5), bottom-left tile (22,11), is 6. A rigid building must stand on that
-- authored door terrace, and its claimed plot must meet it, without changing the
-- raw ledge field used by the uneven-footprint instancing guard.

package.preload["src.render.Assets"] = function()
  return { register = function() end }
end

local function keyOf(tx, ty)
  return (ty + 64) * 4096 + (tx + 64)
end

local function quad(corners, shade)
  corners.uv = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 } }
  corners.shade = shade or 1
  return corners
end

local S = {
  skip = {}, runs = {}, shapeAt = {}, tileAt = {}, ground = {},
  objectQuads = {}, buildingStamps = {}, roundStamps = {},
  grassGroups = {}, flowerQuads = {}, figures = {},
}
for ty = 0, 15 do
  for tx = 0, 31 do
    local k = keyOf(tx, ty)
    S.shapeAt[k] = { h = 0, art = "flat", class = "ground", flat = true }
    S.tileAt[k] = 0
  end
end

for ty = 4, 11 do
  for tx = 20, 27 do
    local k = keyOf(tx, ty)
    S.shapeAt[k] = {
      h = 0, art = "building", class = "building", flat = false,
    }
    S.skip[k] = true
    S.ground[k] = 0
  end
end

-- The broad horizontal quad makes the physical footprint observable to the
-- raw-uniformity check; the south face makes the building's translated foot
-- and top directly measurable in the emitted vertex stream.
local template = {
  quad({ { 0, 0, 0 }, { 64, 0, 0 }, { 64, 0, 64 }, { 0, 0, 64 } }),
  quad({ { 0, 0, 64 }, { 64, 0, 64 },
         { 64, 10, 64 }, { 0, 10, 64 } }, 0.9),
}
S.buildingStamps[1] = {
  quads = template, mx = 160, mz = 32,
  tx = 20, ty = 4, bw = 8, bh = 8,
  doorGroundSamples = { 22, 11 }, -- ROUTE_4 warp/collision cell (11,5)
}

local raw = {}
function raw:atTile(tx, ty)
  -- The one proven high tile inside the otherwise-low blocked footprint is
  -- the actual door cell. It must not turn into a per-vertex bend.
  if tx == 22 and ty == 11 then return 6 end
  return 0
end
function raw:at(cx, cy) return self:atTile(cx * 2, cy * 2) end

local Structures = {
  forMap = function(map) return map.analysis end,
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
  newMesh = function() error("GPU path reached headless terrace fixture") end,
  canInstance = function() return false end,
}
local loaded, V = {}, {}
function V.require(name)
  if loaded[name] then return loaded[name] end
  if name == "Structures" then loaded[name] = Structures
  elseif name == "TileShape" then loaded[name] = {}
  elseif name == "Voxel3D" then loaded[name] = Voxel3D
  elseif name == "LedgeElevation" then
    loaded[name] = { map = function(map) return map.raw end,
                     invalidate = function() end }
  elseif name == "BuildBudget" then
    loaded[name] = { tick = function() end, check = function() end }
  elseif name == "ModSetting" then
    loaded[name] = { new = function()
      return { get = function() return true end }
    end }
  else
    error("unexpected dependency " .. tostring(name))
  end
  return loaded[name]
end

local Mesher = assert(loadfile("lib/ChunkMesher.lua"))(V)
local map = {
  id = "ROUTE_4_CENTER_TERRACE",
  def = { width = 8, height = 4 },
  tileset = { tilesPerRow = 16, imageWidth = 128, imageHeight = 48 },
  tileAt = function() return 0 end,
  analysis = S, raw = raw,
}

-- A target-owned visual material override changes only this ground tile's UV.
-- It is the exact ChunkMesher path used by the resident Lavender approach;
-- raw structure art, collision-derived height and geometry count stay intact.
S.topTileAt = { [keyOf(0, 0)] = 0x39 }

local verts = Mesher.geometry(map, true)
local plotTops, facade, foundation = 0, false, false
local visualTop = false
for at = 1, #verts, 4 do
  local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
  local lo, hi = math.huge, -math.huge
  for i = at, at + 3 do
    local v = verts[i]
    x0, x1 = math.min(x0, v[1]), math.max(x1, v[1])
    z0, z1 = math.min(z0, v[3]), math.max(z1, v[3])
    lo, hi = math.min(lo, v[2]), math.max(hi, v[2])
  end
  if x0 >= 160 and x1 <= 224 and z0 >= 32 and z1 <= 96
     and x1 - x0 == 8 and z1 - z0 == 8 and lo == 6 and hi == 6 then
    plotTops = plotTops + 1
  end
  if x0 == 160 and x1 == 224 and z0 == 96 and z1 == 96
     and lo == 6 and hi == 16 then
    facade = true
  end
  if ((z0 == 32 and z1 == 32) or (x0 == 160 and x1 == 160))
     and lo == 0 and hi == 6 then
    foundation = true
  end
  if x0 == 0 and x1 == 8 and z0 == 0 and z1 == 8 and lo == 0 and hi == 0 then
    local expectedU = ((0x39 % 16) * 8 + 0.02) / 128
    if math.abs(verts[at][4] - expectedU) < 1e-9 then visualTop = true end
  end
end

if plotTops ~= 64 then
  error("claimed Center plot did not level all 64 tiles to its frontage: "
        .. tostring(plotTops))
end
if not facade then
  error("Center facade did not move from raw origin 0 to entrance datum 6")
end
if not foundation then
  error("leveled Center plot did not close its exposed retaining foundation")
end
if not visualTop or S.tileAt[keyOf(0, 0)] ~= 0 then
  error("visual top material did not remain separate from raw terrain art")
end
if raw:atTile(20, 4) ~= 0 or raw:atTile(22, 11) ~= 6 then
  error("building leveling mutated the immutable ledge snapshot")
end

local function fixture(id, blocksW, blocksH, tx, ty, bw, bh,
                       doorSamples, rawAt)
  local A = {
    skip = {}, runs = {}, shapeAt = {}, tileAt = {}, ground = {},
    objectQuads = {}, buildingStamps = {}, roundStamps = {},
    grassGroups = {}, flowerQuads = {}, figures = {},
  }
  for y = 0, blocksH * 4 - 1 do
    for x = 0, blocksW * 4 - 1 do
      local k = keyOf(x, y)
      A.shapeAt[k] = { h = 0, art = "flat", class = "ground", flat = true }
      A.tileAt[k] = 0
    end
  end
  for y = ty, ty + bh - 1 do
    for x = tx, tx + bw - 1 do
      local k = keyOf(x, y)
      A.shapeAt[k] = {
        h = 0, art = "building", class = "building", flat = false,
      }
      A.skip[k], A.ground[k] = true, 0
    end
  end
  local W, D = bw * 8, bh * 8
  local model = {
    quad({ { 0, 0, 0 }, { W, 0, 0 }, { W, 0, D }, { 0, 0, D } }),
    quad({ { 0, 0, D }, { W, 0, D },
           { W, 10, D }, { 0, 10, D } }, 0.9),
  }
  A.buildingStamps[1] = {
    quads = model, mx = tx * 8, mz = ty * 8,
    tx = tx, ty = ty, bw = bw, bh = bh,
    doorGroundSamples = doorSamples or {},
  }
  local R = {}
  function R:atTile(x, y) return rawAt(x, y) end
  function R:at(cx, cy) return self:atTile(cx * 2, cy * 2) end
  return {
    id = id, def = { width = blocksW, height = blocksH },
    tileset = { tilesPerRow = 16, imageWidth = 128, imageHeight = 48 },
    tileAt = function() return 0 end,
    analysis = A, raw = R,
  }
end

local function quadBounds(vs, at)
  local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
  local lo, hi = math.huge, -math.huge
  for i = at, at + 3 do
    local v = vs[i]
    x0, x1 = math.min(x0, v[1]), math.max(x1, v[1])
    z0, z1 = math.min(z0, v[3]), math.max(z1, v[3])
    lo, hi = math.min(lo, v[2]), math.max(hi, v[2])
  end
  return x0, x1, z0, z1, lo, hi
end

local function terrainTop(vs, tx, ty)
  local wx, wz = tx * 8, ty * 8
  for at = 1, #vs, 4 do
    local x0, x1, z0, z1, lo, hi = quadBounds(vs, at)
    if x0 == wx and x1 == wx + 8 and z0 == wz and z1 == wz + 8
       and lo == hi then
      return lo
    end
  end
end

local function facadeAt(vs, tx, ty, bw, bh, base)
  local x0Want, x1Want = tx * 8, (tx + bw) * 8
  local zWant = (ty + bh) * 8
  for at = 1, #vs, 4 do
    local x0, x1, z0, z1, lo, hi = quadBounds(vs, at)
    if x0 == x0Want and x1 == x1Want and z0 == zWant and z1 == zWant
       and lo == base and hi == base + 10 then
      return true
    end
  end
  return false
end

-- Route 2 contributes the taller real-world counterexample: its route gate
-- is a 12x8 drawing at (28,72), origin datum 0, with door cell (15,39) at
-- datum 18. The same rule must lift it three ledge courses without hardcoding
-- either map or building id.
local route2 = fixture("ROUTE_2_GATE_TERRACE", 10, 36, 28, 72, 12, 8,
  { 30, 79 }, function(x, y)
    return x == 30 and y == 79 and 18 or 0
  end)
route2.analysis.buildingStamps[1].northDoor = {
  x = 16, z = -0.02, tiles = { 11, 12, 27, 28 },
}
local route2Verts = Mesher.geometry(route2, true)
if terrainTop(route2Verts, 28, 72) ~= 18
   or terrainTop(route2Verts, 39, 79) ~= 18
   or not facadeAt(route2Verts, 28, 72, 12, 8, 18) then
  error("Route 2 high-door building did not level to datum 18")
end
local rearDoorQuads = 0
local rearDoorTiles = {}
for at = 1, #route2Verts, 4 do
  local x0, x1, z0, z1, lo, hi = quadBounds(route2Verts, at)
  if x0 >= 28 * 8 + 16 and x1 <= 28 * 8 + 32
     and z0 == 72 * 8 - 0.02 and z1 == z0
     and lo >= 18 and hi <= 34 and hi - lo == 8 then
    rearDoorQuads = rearDoorQuads + 1
    local u = route2Verts[at][4]
    local v = route2Verts[at + 2][5]
    rearDoorTiles[math.floor(u * 128 / 8)
                  + math.floor(v * 48 / 8) * 16] = true
  end
end
if rearDoorQuads ~= 4 or not (rearDoorTiles[11] and rearDoorTiles[12]
                               and rearDoorTiles[27] and rearDoorTiles[28]) then
  error("Route 2 rear entrance did not emit the four native door tiles")
end

-- A height-corrected one-storey model keeps the same four native door quads,
-- X/Z placement, UVs and terrain sink; only their Y coordinates follow the
-- profile scale so the synthesized rear matches the scaled front facade.
route2.analysis.buildingStamps[1].heightScale = 1.4
local scaledDoorVerts = Mesher.geometry(route2, true)
local scaledRearDoorQuads = 0
for at = 1, #scaledDoorVerts, 4 do
  local x0, x1, z0, z1, lo, hi = quadBounds(scaledDoorVerts, at)
  if x0 >= 28 * 8 + 16 and x1 <= 28 * 8 + 32
     and z0 == 72 * 8 - 0.02 and z1 == z0
     and lo >= 18 and hi <= 18 + 16 * 1.4 + 1e-9
     and math.abs((hi - lo) - 8 * 1.4) < 1e-9 then
    scaledRearDoorQuads = scaledRearDoorQuads + 1
  end
end
if scaledRearDoorQuads ~= 4 or #scaledDoorVerts ~= #route2Verts then
  error("height-corrected rear entrance changed topology or lost its scale")
end
route2.analysis.buildingStamps[1].heightScale = nil

-- A compact-house receipt may narrow those same four UV quads into one
-- centred 12 px doorway.  Topology and native tile ownership stay unchanged;
-- no second entrance or collision shape is introduced.
route2.analysis.buildingStamps[1].northDoor.displayWidth = 12
local singleDoorVerts = Mesher.geometry(route2, true)
local singleDoorQuads = 0
for at = 1, #singleDoorVerts, 4 do
  local x0, x1, z0, z1, lo, hi = quadBounds(singleDoorVerts, at)
  if x0 >= 28 * 8 + 18 and x1 <= 28 * 8 + 30
     and z0 == 72 * 8 - 0.02 and z1 == z0
     and lo >= 18 and hi <= 34 and hi - lo == 8 then
    singleDoorQuads = singleDoorQuads + 1
  end
end
if singleDoorQuads ~= 4 or #singleDoorVerts ~= #route2Verts then
  error("centred single rear entrance changed topology or width")
end
route2.analysis.buildingStamps[1].northDoor.displayWidth = nil

-- Doorless scenery has no gameplay-authored floor. A tempting high south
-- perimeter must not move it: the exact old northwest/origin answer wins.
local doorless = fixture("DOORLESS_FALLBACK", 4, 4, 4, 4, 4, 4, {},
  function(x, y)
    if y == 8 and x >= 4 and x <= 7 then return 30 end
    return 0
  end)
local doorlessVerts = Mesher.geometry(doorless, true)
if terrainTop(doorlessVerts, 4, 4) ~= 0
   or not facadeAt(doorlessVerts, 4, 4, 4, 4, 0) then
  error("doorless scenery inherited a guessed perimeter terrace")
end

-- Multiple doors are accepted only when unanimous. Two conflicting door
-- datums preserve both the old rigid origin translation and each raw claimed
-- terrain tile; no arbitrary max/mode can lift the structure.
local conflict = fixture("CONFLICTING_DOOR_FALLBACK", 4, 4, 4, 4, 8, 8,
  { 6, 11, 8, 11 }, function(x, y)
    if x == 6 and y == 11 then return 6 end
    if x == 8 and y == 11 then return 12 end
    return 0
  end)
local conflictVerts = Mesher.geometry(conflict, true)
if terrainTop(conflictVerts, 4, 4) ~= 0
   or terrainTop(conflictVerts, 6, 11) ~= 6
   or terrainTop(conflictVerts, 8, 11) ~= 12
   or not facadeAt(conflictVerts, 4, 4, 8, 8, 0) then
  error("conflicting door datums did not retain the exact old fallback")
end

print("door-anchored buildings: Route4 0->6, Route2 0->18, fallbacks exact")
