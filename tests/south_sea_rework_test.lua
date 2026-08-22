-- Canonical South-Sea material, quay and wave audit.  This stays entirely
-- headless but consumes the generated Gen1Recomp maps instead of visual
-- fixtures, so every allow-listed pixel and connection fails closed.

local engineRoot = os.getenv("GEN1RECOMP_0190_ROOT") or "../gen1recomp"
local realMaps = assert(loadfile(engineRoot .. "/data/generated/maps.lua"))()
local realTilesets =
  assert(loadfile(engineRoot .. "/data/generated/tilesets.lua"))()
local realField = assert(loadfile(engineRoot .. "/data/generated/field.lua"))()
local RealMap = assert(loadfile(engineRoot .. "/src/world/Map.lua"))()

local function expect(ok, message)
  if not ok then error(message, 2) end
end

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected " .. tostring(expected)
          .. ", got " .. tostring(actual), 2)
  end
end

local function near(actual, expected, message)
  if math.abs(actual - expected) > 1e-10 then
    error((message or "values differ") .. ": expected " .. tostring(expected)
          .. ", got " .. tostring(actual), 2)
  end
end

local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for key, item in pairs(value) do out[copy(key, seen)] = copy(item, seen) end
  return out
end

local function realMap(id, mutate)
  local source = assert(realMaps[id], "missing real map " .. id)
  local def = copy(source)
  if mutate then mutate(def) end
  return RealMap.new(def, assert(realTilesets[def.tileset]))
end

local function gameplaySnapshot(map)
  local out = { table.concat(map.def.blocks, ",") }
  for cy = 0, map.heightCells - 1 do
    for cx = 0, map.widthCells - 1 do
      out[#out + 1] = table.concat({
        map:cellTile(cx, cy), map:isWalkableCell(cx, cy) and 1 or 0,
        map:isWaterCell(cx, cy) and 1 or 0,
      }, ":")
    end
  end
  return table.concat(out, "|")
end

package.preload["src.render.Assets"] = function()
  return {
    register = function() end,
    imageData = function() return nil end,
  }
end
package.preload["src.world.Map"] = function() return RealMap end
package.preload["src.render.TileRenderer"] = function()
  return {
    voidFill = "trees",
    borderBlockFor = function(map)
      if map.def.tileset == "OVERWORLD" then return 0x0f end
      return map.def.borderBlock
    end,
  }
end
package.preload["src.core.Game"] = function()
  return { data = { field = realField } }
end

local loaded = {}
local V = { path = "." }
function V.data(name) return assert(loadfile("data/" .. name .. ".lua"))() end
function V.require(name)
  if loaded[name] then return loaded[name] end
  if name == "Voxel3D" then
    loaded[name] = {
      FORMAT = {}, FACE_SHADE = { 0.84, 0.72, 1, 0.55, 0.90, 0.68 },
      pushQuad = function(indices, quad)
        local base = quad * 4
        for _, index in ipairs({ 1, 2, 3, 1, 3, 4 }) do
          indices[#indices + 1] = base + index
        end
      end,
      canInstance = function() return false end,
    }
  elseif name == "ModSetting" then
    loaded[name] = { new = function()
      return { get = function() return true end }
    end }
  else
    loaded[name] = assert(loadfile("lib/" .. name .. ".lua"))(V)
  end
  return loaded[name]
end

local Structures = V.require("Structures")
local Mesher = V.require("ChunkMesher")
local function keyOf(tx, ty) return (ty + 64) * 4096 + (tx + 64) end

-- Independent transcription of the audited 104 source quads.
local expected = { ROUTE_19 = {}, ROUTE_20 = {}, ROUTE_21 = {} }
local function add(id, side, tx, ty, source, material, transform,
                   waterDx, waterDy, between)
  expected[id][#expected[id] + 1] = {
    side=side, tx=tx, ty=ty, source=source, material=material,
    transform=transform, waterDx=waterDx, waterDy=waterDy, between=between,
  }
end
for tx = 8, 21 do add("ROUTE_19", "south", tx, 19, 0x39, 0x33,
                       "identity", 0, 1) end
for tx = 24, 27 do add("ROUTE_19", "south", tx, 19, 0x39, 0x33,
                        "identity", 0, 1) end
for tx = 64, 71 do
  add("ROUTE_20", "north", tx, 16, 0x3c, 0x31, "vflip", 0, -1)
  add("ROUTE_20", "south", tx, 19, 0x3c, 0x31, "identity", 0, 2, 0x31)
end
for ty = 17, 18 do
  add("ROUTE_20", "east", 71, ty, 0x3c, 0x31, "ccw", 1, 0)
  add("ROUTE_20", "west", 64, ty, 0x3c, 0x31, "cw", -1, 0)
end
for _, ty in ipairs({ 4, 6, 8, 10 }) do
  add("ROUTE_20", "east", 123, ty, 0x30, 0x32, "identity", 2, 0, 0x32)
end
for _, ty in ipairs({ 13, 15, 17 }) do
  add("ROUTE_20", "west", 92, ty, 0x30, 0x54, "identity", -2, 0, 0x54)
end
for _, row in ipairs({
  {92,0x30}, {94,0x30}, {96,0x3c}, {97,0x3c}, {98,0x3c},
  {99,0x3c}, {100,0x30}, {102,0x30}, {104,0x30}, {106,0x30},
  {108,0x30},
}) do
  local platform = row[2] == 0x3c
  add("ROUTE_20", "south", row[1], 19, row[2],
      platform and 0x31 or 0x33, "identity", 0, platform and 1 or 2,
      (not platform) and 0x33 or nil)
end
for _, row in ipairs({
  {112,0x39}, {113,0x39}, {116,0x3c}, {117,0x3c}, {118,0x3c},
  {119,0x3c}, {120,0x30}, {122,0x30},
}) do
  local platform = row[2] == 0x3c
  add("ROUTE_20", "south", row[1], 23, row[2],
      platform and 0x31 or 0x33, "identity", 0, platform and 1 or 2,
      (not platform) and 0x33 or nil)
end
for _, rect in ipairs({ {8,15,48,51}, {28,35,112,115} }) do
  for tx = rect[1], rect[2] do
    add("ROUTE_21", "north", tx, rect[3], 0x3c, 0x31,
        "vflip", 0, -1)
    add("ROUTE_21", "south", tx, rect[4], 0x3c, 0x31,
        "identity", 0, 2, 0x31)
  end
  for ty = rect[3] + 1, rect[4] - 1 do
    add("ROUTE_21", "east", rect[2], ty, 0x3c, 0x31, "ccw", 1, 0)
    add("ROUTE_21", "west", rect[1], ty, 0x3c, 0x31, "cw", -1, 0)
  end
end

local maps, structures = {}, {}
local totals = { count=0, source={}, material={}, side={}, depth={} }
for _, id in ipairs({ "ROUTE_19", "ROUTE_20", "ROUTE_21" }) do
  local map = realMap(id)
  maps[id] = map
  local before = gameplaySnapshot(map)
  Structures.invalidate(id)
  local S = Structures.forMap(map)
  structures[id] = S
  local actualCount = 0
  for _ in pairs(S.topUVAt) do actualCount = actualCount + 1 end
  eq(actualCount, #expected[id], id .. " exact transformed top count")
  eq(#S.coastalEdges, #expected[id], id .. " exact coastal lip count")
  local coastByKey = {}
  for _, coast in ipairs(S.coastalEdges) do
    local key = keyOf(coast.tx, coast.ty)
    expect(not coastByKey[key], id .. " duplicate coastal lip")
    coastByKey[key] = coast
  end
  local seen = {}
  for _, edge in ipairs(expected[id]) do
    local key = keyOf(edge.tx, edge.ty)
    expect(not seen[key], id .. " duplicate audited top")
    seen[key] = true
    eq(map:tileAt(edge.tx, edge.ty), edge.source,
       id .. " real source pixel drifted")
    if edge.between then
      local sx = edge.waterDx == 0 and 0 or (edge.waterDx > 0 and 1 or -1)
      local sy = edge.waterDy == 0 and 0 or (edge.waterDy > 0 and 1 or -1)
      eq(map:tileAt(edge.tx + sx, edge.ty + sy), edge.between,
         id .. " intermediate shore pixel drifted at "
         .. edge.tx .. "," .. edge.ty)
    end
    eq(map:tileAt(edge.tx + edge.waterDx, edge.ty + edge.waterDy), 0x14,
       id .. " canonical water witness drifted")
    local material, transform, side = Structures.southSeaTopMaterial(
      map, map:tileAt(edge.tx, edge.ty), edge.tx, edge.ty)
    eq(material, edge.material, id .. " top material")
    eq(transform, edge.transform, id .. " top transform")
    eq(side, edge.side, id .. " top side")
    eq(S.tileAt[key], edge.source, id .. " raw structure tile changed")
    eq(S.topTileAt[key], edge.material, id .. " final top material")
    eq(S.topUVAt[key], edge.transform, id .. " final top transform")
    local coast = assert(coastByKey[key], id .. " transformed top lost lip")
    eq(coast.side, edge.side, id .. " coastal lip side")
    eq(coast.tile, edge.material, id .. " coastal lip material")
    eq(coast.depth, Structures.coastalLipDepth(edge.tx, edge.ty, edge.side),
       id .. " coastal lip phase")
    expect(coast.depth == 2 or coast.depth == 4 or coast.depth == 6,
           id .. " coastal lip escaped 2/4/6px profile")
    totals.count = totals.count + 1
    totals.source[edge.source] = (totals.source[edge.source] or 0) + 1
    totals.material[edge.material] = (totals.material[edge.material] or 0) + 1
    totals.side[edge.side] = (totals.side[edge.side] or 0) + 1
    totals.depth[coast.depth] = (totals.depth[coast.depth] or 0) + 1
  end
  for key in pairs(S.topUVAt) do
    expect(seen[key], id .. " rewrote an unaudited top quad")
  end
  eq(gameplaySnapshot(map), before, id .. " visual pass mutated gameplay")
end
eq(totals.count, 104, "global South-Sea transformed top budget")
eq(totals.source[0x30], 16, "$30 source population")
eq(totals.source[0x39], 20, "$39 source population")
eq(totals.source[0x3c], 68, "$3c source population")
eq(totals.material[0x31], 68, "$31 platform population")
eq(totals.material[0x33], 29, "$33 south-shore population")
eq(totals.material[0x32], 4, "$32 east-shore population")
eq(totals.material[0x54], 3, "$54 west-shore population")
eq(totals.side.north, 24, "north population")
eq(totals.side.south, 61, "south population")
eq(totals.side.east, 10, "east population")
eq(totals.side.west, 9, "west population")
eq(totals.depth[2], 60, "2px coastal lip population")
eq(totals.depth[4], 14, "4px coastal lip population")
eq(totals.depth[6], 30, "6px coastal lip population")

-- All 104 plan-view UVs reach the final terrain quads without adding a quad.
local function expectedUV(tile, transform)
  local u0 = ((tile % 16) * 8 + 0.02) / 128
  local u1 = ((tile % 16) * 8 + 7.98) / 128
  local v0 = (math.floor(tile / 16) * 8 + 0.02) / 48
  local v1 = (math.floor(tile / 16) * 8 + 7.98) / 48
  if transform == "vflip" then
    return { {u0,v1}, {u1,v1}, {u1,v0}, {u0,v0} }
  elseif transform == "ccw" then
    return { {u1,v0}, {u1,v1}, {u0,v1}, {u0,v0} }
  elseif transform == "cw" then
    return { {u0,v1}, {u0,v0}, {u1,v0}, {u1,v1} }
  end
  return { {u0,v0}, {u1,v0}, {u1,v1}, {u0,v1} }
end

local function findTop(vertices, edge, S, map)
  local x0, z0 = edge.tx * 8, edge.ty * 8
  local shape = assert(S.shapeAt[keyOf(edge.tx, edge.ty)])
  local h = Mesher.elevation(map):atTile(edge.tx, edge.ty) + (shape.h or 0)
  local found
  for at = 1, #vertices, 4 do
    local a,b,c,d = vertices[at],vertices[at+1],vertices[at+2],vertices[at+3]
    if a[1]==x0 and a[2]==h and a[3]==z0
       and b[1]==x0+8 and b[2]==h and b[3]==z0
       and c[1]==x0+8 and c[2]==h and c[3]==z0+8
       and d[1]==x0 and d[2]==h and d[3]==z0+8 then
      expect(found == nil, "audited top quad duplicated")
      found = {a,b,c,d}
    end
  end
  return assert(found, "audited top quad missing")
end

local function findExactQuad(vertices, points, label)
  local found
  for at = 1, #vertices, 4 do
    local ok = true
    for i = 1, 4 do
      for axis = 1, 3 do
        ok = ok and vertices[at+i-1][axis] == points[i][axis]
      end
    end
    if ok then
      expect(found == nil, (label or "exact quad") .. " duplicated")
      found = { vertices[at], vertices[at+1],
                vertices[at+2], vertices[at+3] }
    end
  end
  return assert(found, (label or "exact quad") .. " missing")
end

local function findCoastalLip(vertices, edge, coast)
  local x0, z0, depth = edge.tx * 8, edge.ty * 8, coast.depth
  local points
  if edge.side == "north" then
    points = {{x0,0,z0},{x0+8,0,z0},
              {x0+8,-2,z0-depth},{x0,-2,z0-depth}}
  elseif edge.side == "south" then
    points = {{x0,0,z0+8},{x0+8,0,z0+8},
              {x0+8,-2,z0+8+depth},{x0,-2,z0+8+depth}}
  elseif edge.side == "west" then
    points = {{x0,0,z0},{x0,0,z0+8},
              {x0-depth,-2,z0+8},{x0-depth,-2,z0}}
  else
    points = {{x0+8,0,z0+8},{x0+8,0,z0},
              {x0+8+depth,-2,z0},{x0+8+depth,-2,z0+8}}
  end
  return findExactQuad(vertices, points, "coastal lip")
end

local meshes = {}
for _, id in ipairs({ "ROUTE_19", "ROUTE_20", "ROUTE_21" }) do
  local vertices, indices, quads = Mesher.geometry(maps[id], true, nil, true)
  eq(#vertices, quads * 4, id .. " terrain vertex accounting")
  eq(#indices, quads * 6, id .. " terrain index accounting")
  meshes[id] = { vertices=vertices, indices=indices, quads=quads }
  for _, edge in ipairs(expected[id]) do
    local coast
    for _, candidate in ipairs(structures[id].coastalEdges) do
      if candidate.tx == edge.tx and candidate.ty == edge.ty then
        coast = candidate
        break
      end
    end
    coast = assert(coast, id .. " lip descriptor missing")
    local quad, uv = findTop(vertices, edge, structures[id], maps[id]),
                     expectedUV(edge.material, edge.transform)
    for i = 1, 4 do
      near(quad[i][4], uv[i][1], id .. " transformed U")
      near(quad[i][5], uv[i][2], id .. " transformed V")
    end
    local lip = findCoastalLip(vertices, edge, coast)
    local tile = edge.material
    local u0 = ((tile % 16) * 8 + 0.02) / 128
    local u1 = ((tile % 16) * 8 + 7.98) / 128
    local v0 = (math.floor(tile / 16) * 8 + 8 - coast.depth + 0.02) / 48
    local v1 = (math.floor(tile / 16) * 8 + 7.98) / 48
    local lipUV = {{u0,v0},{u1,v0},{u1,v1},{u0,v1}}
    for i = 1, 4 do
      near(lip[i][4], lipUV[i][1], id .. " lip U")
      near(lip[i][5], lipUV[i][2], id .. " lip V")
    end
    eq(math.abs((lip[3][1] - lip[2][1])
                + (lip[3][3] - lip[2][3])), coast.depth,
       id .. " lip world depth is not source depth")
  end
end

-- One connection or one pixel edit independently drops only the eligible
-- visual override. Geometry remains the raw authored map budget.
local wrongConnection = realMap("ROUTE_19", function(def)
  def.connections.north.offset = -4
end)
Structures.invalidate("ROUTE_19")
local wrongS = Structures.forMap(wrongConnection)
eq(next(wrongS.topUVAt), nil, "wrong connection inherited coastal UVs")
eq(#wrongS.coastalEdges, 0, "wrong connection inherited coastal lips")
local wrongV, wrongI, wrongQ = Mesher.geometry(wrongConnection, true, nil, true)
eq(#meshes.ROUTE_19.vertices - #wrongV, 18 * 4,
   "Route 19 coastal lip vertex budget")
eq(#meshes.ROUTE_19.indices - #wrongI, 18 * 6,
   "Route 19 coastal lip index budget")
eq(meshes.ROUTE_19.quads - wrongQ, 18,
   "Route 19 coastal lip quad budget")

local wrongWater = realMap("ROUTE_19")
local rawTileAt = wrongWater.tileAt
function wrongWater:tileAt(tx, ty)
  if tx == 8 and ty == 20 then return 0x30 end
  return rawTileAt(self, tx, ty)
end
Structures.invalidate("ROUTE_19")
local wrongWaterS = Structures.forMap(wrongWater)
local wrongWaterCount = 0
for _ in pairs(wrongWaterS.topUVAt) do wrongWaterCount = wrongWaterCount + 1 end
eq(wrongWaterCount, 17, "one edited water pixel did not fail independently")
eq(wrongWaterS.topUVAt[keyOf(8,19)], nil,
   "edited water witness retained a coastal UV")
eq(#wrongWaterS.coastalEdges, 17,
   "edited water witness did not remove exactly one coastal lip")

-- The Pallet/Cinnabar south connection is never part of the 104-top pass.
local r21 = structures.ROUTE_21
for ty = 176, 179 do
  for tx = 20, 23 do
    eq(r21.topUVAt[keyOf(tx,ty)], nil, "Route 21 connection was repainted")
  end
end
eq(maps.ROUTE_21.def.connections.south.map, "CINNABAR_ISLAND",
   "Route 21 south connection moved")
eq(maps.ROUTE_21.def.connections.south.offset, 0,
   "Route 21 south connection offset moved")

-- The exact 44-cell northern stop component becomes a two-pixel visual
-- barrier. Raw blocks/collision stay byte-identical; the six isolated
-- Cinnabar-end cylinders retain their established full shape.
local barrierCells = {}
local function barrierCell(cx, cy) barrierCells[cy * 128 + cx] = true end
for _, cx in ipairs({2,3,8,9,10,11,12,13,14,15,16,17}) do
  barrierCell(cx, 0)
end
for cy = 1, 12 do barrierCell(3, cy); barrierCell(14, cy) end
for _, cx in ipairs({2,3,14}) do barrierCell(cx, 13) end
barrierCell(14, 14)
for _, cx in ipairs({14,15,16,17}) do barrierCell(cx, 15) end
local barrierCount = 0
for cy = 0, 15 do
  for cx = 0, 19 do
    local expectedLow = barrierCells[cy * 128 + cx] == true
    local low = true
    for dy = 0, 1 do
      for dx = 0, 1 do
        local shape = r21.shapeAt[keyOf(cx * 2 + dx, cy * 2 + dy)]
        low = low and shape and shape.class == "coastal_barrier"
                       and shape.art == "top" and shape.h == 2
      end
    end
    eq(low and true or false, expectedLow,
       "Route 21 low barrier cell " .. cx .. "," .. cy)
    if low then barrierCount = barrierCount + 1 end
  end
end
eq(barrierCount, 44, "Route 21 low barrier cell budget")
for _, cell in ipairs({{16,85},{17,85},{15,86},{15,87},{15,88},{15,89}}) do
  local shape = assert(r21.shapeAt[keyOf(cell[1] * 2, cell[2] * 2)])
  eq(shape.art, "cylinder", "Route 21 south stop was lowered")
end
local wrongRoute21 = realMap("ROUTE_21", function(def)
  def.connections.north.offset = 1
end)
Structures.invalidate("ROUTE_21")
local wrongRoute21S = Structures.forMap(wrongRoute21)
local leakedBarriers = 0
for _, shape in pairs(wrongRoute21S.shapeAt) do
  if shape.class == "coastal_barrier" then leakedBarriers = leakedBarriers + 1 end
end
eq(leakedBarriers, 0, "edited Route 21 inherited low barriers")
local wr21v, wr21i, wr21q = Mesher.geometry(wrongRoute21, true, nil, true)
eq(#meshes.ROUTE_21.vertices - #wr21v, 224 * 4,
   "Route 21 V4 vertex delta")
eq(#meshes.ROUTE_21.indices - #wr21i, 224 * 6,
   "Route 21 V4 index delta")
eq(meshes.ROUTE_21.quads - wr21q, 224,
   "Route 21 V4 quad delta")

-- Cinnabar keeps the old open-sea normalization and exactly 22 proven edge
-- descriptors / 44 collision-free terrain quads. The west special
-- corner is the sole mixed-material edge: upper $33, lower $54.
local cinnabar = realMap("CINNABAR_ISLAND")
local cinnabarBefore = gameplaySnapshot(cinnabar)
Structures.invalidate("CINNABAR_ISLAND")
local quay = Structures.forMap(cinnabar)
eq(next(quay.topUVAt), nil, "Cinnabar entered the 104-top pass")
eq(#quay.quayEdges, 22, "Cinnabar quay edge budget")
local edgeCount, tileCount, byKey = {south=0,west=0}, {}, {}
for _, edge in ipairs(quay.quayEdges) do
  edgeCount[edge.side] = edgeCount[edge.side] + 1
  byKey[edge.side .. ":" .. edge.cx .. ":" .. edge.cy] = edge
  for _, tile in ipairs(edge.tiles) do tileCount[tile]=(tileCount[tile] or 0)+1 end
end
eq(edgeCount.south, 16, "Cinnabar south quay edges")
eq(edgeCount.west, 6, "Cinnabar west quay edges")
eq(tileCount[0x33], 33, "Cinnabar $33 quay segments")
eq(tileCount[0x54], 11, "Cinnabar $54 quay segments")
local special = assert(byKey["west:6:12"], "special west corner missing")
eq(special.tiles[1], 0x33, "special west upper segment material")
eq(special.tiles[2], 0x54, "special west lower segment material")
eq(gameplaySnapshot(cinnabar), cinnabarBefore,
   "Cinnabar quay analysis mutated gameplay")

local noQuay = realMap("CINNABAR_ISLAND", function(def)
  def.connections.east.offset = 1
end)
Structures.invalidate("CINNABAR_ISLAND")
eq(#Structures.forMap(noQuay).quayEdges, 0,
   "wrong Cinnabar connection inherited a quay")

Structures.invalidate("CINNABAR_ISLAND")
local cv, ci, cq, cwv, cwi, cwq = Mesher.geometry(cinnabar, true, nil, true)
Structures.invalidate("CINNABAR_ISLAND")
local nv, ni, nq, nwv, nwi, nwq = Mesher.geometry(noQuay, true, nil, true)
eq(#cv - #nv, 44 * 4, "Cinnabar quay vertex budget")
eq(#ci - #ni, 44 * 6, "Cinnabar quay index budget")
eq(cq - nq, 44, "Cinnabar quay quad budget")
eq(#cwv, #nwv, "Cinnabar quay leaked into water vertices")
eq(#cwi, #nwi, "Cinnabar quay leaked into water indices")
eq(cwq, nwq, "Cinnabar quay changed water quad budget")

local slopeCount = 0
for _, edge in ipairs(quay.quayEdges) do
  for segment = 0, 1 do
    local points, depth = nil, assert(edge.depths[segment + 1])
    expect(depth == 2 or depth == 4 or depth == 6,
           "Cinnabar quay escaped 2/4/6px profile")
    if edge.side == "south" then
      local x0, z = edge.cx*16 + segment*8, (edge.cy+1)*16
      points = {{x0,0,z},{x0+8,0,z},
                {x0+8,-2,z+depth},{x0,-2,z+depth}}
    else
      local x, z0 = edge.cx*16, edge.cy*16 + segment*8
      points = {{x,0,z0},{x,0,z0+8},
                {x-depth,-2,z0+8},{x-depth,-2,z0}}
    end
    local quad = findExactQuad(cv, points, "quay slope")
    local tile = edge.tiles[segment+1]
    local u0 = ((tile % 16)*8 + 0.02)/128
    local u1 = ((tile % 16)*8 + 7.98)/128
    local v0 = (math.floor(tile/16)*8 + 8-depth + 0.02)/48
    local v1 = (math.floor(tile/16)*8 + 7.98)/48
    local uv = {{u0,v0},{u1,v0},{u1,v1},{u0,v1}}
    for i=1,4 do near(quad[i][4],uv[i][1],"quay U")
                      near(quad[i][5],uv[i][2],"quay V") end
    slopeCount = slopeCount + 1
  end
end
eq(slopeCount, 44, "Cinnabar located quay slopes")

-- Six exact maritime identities share the calmer 3/2.5 uniforms.  A wrong
-- id, dimension or tileset fails to the default 5/3.5 without a camera input.
local WaterV = {}
function WaterV.require(name)
  if name == "ModSetting" then
    return { new=function() return { get=function() return "full" end } end }
  elseif name == "Mat4" then return { identity=function() return {} end }
  elseif name == "ShadowMap" then return { res=1, bias=0 }
  else return {} end
end
local Water = assert(loadfile("lib/Water.lua"))(WaterV)
for _, id in ipairs({ "ROUTE_19", "ROUTE_20", "ROUTE_21",
                      "CINNABAR_ISLAND", "VERMILION_DOCK", "SS_ANNE_BOW" }) do
  local map = realMap(id)
  expect(Water.maritime(map), id .. " lost maritime semantics")
end
local wh, ws = Water.waveUniforms(true)
eq(wh, 3, "maritime wave height")
eq(ws, 2.5, "maritime wave slope")
wh, ws = Water.waveUniforms(false)
eq(wh, 5, "default wave height")
eq(ws, 3.5, "default wave slope")
for _, field in ipairs({ "width", "height", "tileset", "id" }) do
  local map = realMap("VERMILION_DOCK")
  if field == "id" then map.id = "EDITED_DOCK"
  elseif field == "tileset" then map.def.tileset = "OVERWORLD"
  else map.def[field] = map.def[field] + 1 end
  expect(not Water.maritime(map), "edited maritime " .. field .. " passed")
end

print("south sea rework: ok")
