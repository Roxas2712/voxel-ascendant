-- Real-map contract for Saffron's Route 8 T junction.  This test stays
-- headless: the only product change is a top-material selection, so the final
-- ChunkMesher UVs are the renderer-visible authority.

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
  local out = {
    tostring(map.id), tostring(map.def.id), tostring(map.def.tileset),
    tostring(map.def.width), tostring(map.def.height),
    table.concat(map.def.blocks, ","),
  }
  for _, side in ipairs({ "north", "south", "west", "east" }) do
    local c = map.def.connections and map.def.connections[side]
    out[#out + 1] = table.concat({ side, c and c.map or "-",
                                   c and c.offset or "-" }, ":")
  end
  for index, warp in ipairs(map.def.warps or {}) do
    out[#out + 1] = table.concat({ index, warp.x, warp.y,
                                   warp.destMap, warp.destWarp }, ":")
  end
  for ty = 0, map.def.height * 4 - 1 do
    for tx = 0, map.def.width * 4 - 1 do
      out[#out + 1] = tostring(map:tileAt(tx, ty))
    end
  end
  for cy = 0, map.heightCells - 1 do
    for cx = 0, map.widthCells - 1 do
      local warp = map:warpAtCell(cx, cy)
      out[#out + 1] = table.concat({
        map:cellTile(cx, cy), map:isWalkableCell(cx, cy) and 1 or 0,
        map:isWaterCell(cx, cy) and 1 or 0,
        map:isDoorTileCell(cx, cy) and 1 or 0,
        warp and warp.index or 0,
      }, ":")
    end
  end
  return table.concat(out, "|")
end

package.preload["src.render.Assets"] = function()
  return { register = function() end, imageData = function() return nil end }
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
local TileShape = V.require("TileShape")
local LedgeElevation = V.require("LedgeElevation")
local Mesher = V.require("ChunkMesher")
local function keyOf(tx, ty) return (ty + 64) * 4096 + (tx + 64) end

-- Independent exact UV allow-list for the true northbound leg: two complete
-- 8px columns plus the authored southeast corner pixel.  Alternating by row
-- is the only phase whose repeated $39 edges match and whose two terminal
-- edges both remain white.
local expectedTurnUV = {}
for ty = 30, 37 do
  local transform = ty % 2 == 0 and "cw" or "ccw"
  expectedTurnUV[keyOf(73, ty)] = transform
  expectedTurnUV[keyOf(74, ty)] = transform
end
expectedTurnUV[keyOf(75, 37)] = "ccw"

-- Independent transcription of the real approach.  The three solid cells at
-- x=35 are the gate-side scenery body; the walkable route turns north through
-- y=15 instead of passing through that body.
local cells = {
  { 35, 15, 0x5b, 0x5b, 0x5b, 0x5b },
  { 36, 15, 0x10, 0x23, 0x10, 0x23 },
  { 37, 15, 0x23, 0x10, 0x23, 0x10 },
  { 38, 15, 0x2c, 0x2c, 0x2c, 0x2c },
  { 36, 16, 0x10, 0x23, 0x10, 0x23 },
  { 37, 16, 0x23, 0x10, 0x23, 0x10 },
  { 38, 16, 0x23, 0x23, 0x39, 0x23 },
  { 39, 16, 0x23, 0x23, 0x23, 0x23 },
  { 36, 17, 0x10, 0x23, 0x10, 0x23 },
  { 37, 17, 0x23, 0x10, 0x23, 0x10 },
  { 38, 17, 0x23, 0x23, 0x23, 0x23 },
  { 39, 17, 0x23, 0x23, 0x39, 0x23 },
  { 36, 18, 0x10, 0x23, 0x10, 0x23 },
  { 37, 18, 0x23, 0x21, 0x23, 0x23 },
  { 38, 18, 0x39, 0x39, 0x39, 0x39 },
  { 39, 18, 0x39, 0x39, 0x39, 0x39 },
}
local blockers = {
  { 35, 16, 0x12, 0x53, 0x4d, 0x12, 0x5a },
  { 35, 17, 0x17, 0x12, 0x5a, 0x17, 0x5d },
  { 35, 18, 0x4b, 0x0a, 0x1f, 0x4b, 0x1f },
}

local saffron = realMap("SAFFRON_CITY")
local before = gameplaySnapshot(saffron)
local elevation = LedgeElevation.map(saffron)
local expectedPlan, changed = {}, 0
for _, cell in ipairs(cells) do
  local cx, cy, at = cell[1], cell[2], 3
  expect(saffron:isWalkableCell(cx, cy), "guide cell is not walkable")
  expect(not saffron:isWaterCell(cx, cy), "guide cell became water")
  expect(not saffron:isDoorTileCell(cx, cy), "guide cell became a door")
  eq(saffron:warpAtCell(cx, cy), nil, "guide cell acquired a warp")
  for dy = 0, 1 do
    for dx = 0, 1 do
      local tx, ty = cx * 2 + dx, cy * 2 + dy
      local tile = saffron:tileAt(tx, ty)
      eq(tile, cell[at], "real Saffron guide pixel drifted")
      eq(elevation:atTile(tx, ty), 0, "guide pixel left the common datum")
      if tile == 0x23 then
        expectedPlan[keyOf(tx, ty)] = 0x39
        changed = changed + 1
      end
      at = at + 1
    end
  end
end
eq(changed, 31, "exact $23 guide-pixel population")

for _, cell in ipairs(blockers) do
  local cx, cy, at = cell[1], cell[2], 4
  expect(not saffron:isWalkableCell(cx, cy), "wall cell became walkable")
  eq(saffron:cellTile(cx, cy), cell[3], "wall collision tile drifted")
  for dy = 0, 1 do
    for dx = 0, 1 do
      eq(saffron:tileAt(cx * 2 + dx, cy * 2 + dy), cell[at],
         "real Saffron wall pixel drifted")
      at = at + 1
    end
  end
end

local shapes = TileShape.forMap(saffron)
local plan, planUV = Structures.saffronRoute8TurnTiles(saffron, shapes)
plan = assert(plan, "canonical Saffron turn failed closed")
planUV = assert(planUV, "canonical Saffron turn lost its UV phase")
local planCount = 0
for key, tile in pairs(plan) do
  planCount = planCount + 1
  eq(expectedPlan[key], tile, "turn plan admitted an unaudited pixel")
end
eq(planCount, 31, "turn plan pixel budget")
local planUVCount = 0
for key, transform in pairs(planUV) do
  planUVCount = planUVCount + 1
  eq(expectedTurnUV[key], transform,
     "turn UV plan admitted an unaudited pixel/phase")
  eq(plan[key], 0x39, "turn UV escaped the $39 material plan")
end
eq(planUVCount, 17, "north-turn UV budget")
for key, transform in pairs(expectedTurnUV) do
  eq(planUV[key], transform, "north-turn UV allow-list missing")
end

Structures.invalidate("SAFFRON_CITY")
local structure = Structures.forMap(saffron)
local topCount = 0
for key, tile in pairs(structure.topTileAt) do
  topCount = topCount + 1
  eq(expectedPlan[key], tile, "Saffron acquired an unaudited top material")
  eq(tile, 0x39, "Saffron guide did not use existing $39 material")
  eq(structure.tileAt[key], 0x23, "Saffron guide lost its raw source tile")
end
eq(topCount, 31, "final Saffron top-material budget")
local topUVCount = 0
for key, transform in pairs(structure.topUVAt) do
  topUVCount = topUVCount + 1
  eq(expectedTurnUV[key], transform,
     "Saffron guide rotated an unaudited top")
  eq(structure.topTileAt[key], 0x39,
     "Saffron UV transform escaped its material top")
end
eq(topUVCount, 17, "final Saffron north-turn UV budget")
for key in pairs(expectedPlan) do
  eq(structure.topUVAt[key], expectedTurnUV[key],
     "Saffron material/UV partition drifted")
end
for _, cell in ipairs(blockers) do
  for dy = 0, 1 do
    for dx = 0, 1 do
      eq(structure.topTileAt[keyOf(cell[1] * 2 + dx, cell[2] * 2 + dy)],
         nil, "solid scenery was painted as a path")
      eq(structure.topUVAt[keyOf(cell[1] * 2 + dx, cell[2] * 2 + dy)],
         nil, "solid scenery acquired a path rotation")
    end
  end
end
-- A matching $23 sidewalk immediately north is outside the exact turn.
eq(saffron:tileAt(73, 28), 0x23, "outside control pixel drifted")
eq(structure.topTileAt[keyOf(73, 28)], nil,
   "turn material escaped into Saffron's northern sidewalk")
eq(structure.topUVAt[keyOf(73, 28)], nil,
   "turn UV escaped into Saffron's northern sidewalk")
eq(gameplaySnapshot(saffron), before,
   "visual turn analysis mutated map bytes, collision or warps")

local function tileUV(tile, transform)
  local u0 = ((tile % 16) * 8 + 0.02) / 128
  local u1 = ((tile % 16) * 8 + 7.98) / 128
  local v0 = (math.floor(tile / 16) * 8 + 0.02) / 48
  local v1 = (math.floor(tile / 16) * 8 + 7.98) / 48
  if transform == "cw" then
    return { {u0,v1}, {u0,v0}, {u1,v0}, {u1,v1} }
  elseif transform == "ccw" then
    return { {u1,v0}, {u1,v1}, {u0,v1}, {u0,v0} }
  end
  return { {u0,v0}, {u1,v0}, {u1,v1}, {u0,v1} }
end

local function findFlatTop(vertices, tx, ty)
  local x0, z0, found = tx * 8, ty * 8
  for at = 1, #vertices, 4 do
    local a,b,c,d = vertices[at],vertices[at+1],vertices[at+2],vertices[at+3]
    if a[1]==x0 and a[2]==0 and a[3]==z0
       and b[1]==x0+8 and b[2]==0 and b[3]==z0
       and c[1]==x0+8 and c[2]==0 and c[3]==z0+8
       and d[1]==x0 and d[2]==0 and d[3]==z0+8 then
      expect(found == nil, "guide top quad was duplicated")
      found = {a,b,c,d}
    end
  end
  return assert(found, "guide top quad is missing")
end

local guidedV, guidedI, guidedQ = Mesher.geometry(saffron, true)
for key in pairs(expectedPlan) do
  local ty = math.floor(key / 4096) - 64
  local tx = key - (ty + 64) * 4096 - 64
  local quad = findFlatTop(guidedV, tx, ty)
  local whiteUV = tileUV(0x39, expectedTurnUV[key])
  for i = 1, 4 do
    near(quad[i][4], whiteUV[i][1], "final guide U")
    near(quad[i][5], whiteUV[i][2], "final guide V")
  end
end

-- A noncanonical connection disables the complete visual plan.  Geometry,
-- topology and draw/VRAM-sized mesh budgets stay byte-equivalent; exactly the
-- 31 top quads return from $39 to their raw $23 UVs.
saffron.def.connections.east.offset = 5
Structures.invalidate("SAFFRON_CITY")
local rawV, rawI, rawQ = Mesher.geometry(saffron, true)
eq(#rawV, #guidedV, "guide changed the vertex/VRAM budget")
eq(#rawI, #guidedI, "guide changed the index/VRAM budget")
eq(rawQ, guidedQ, "guide changed the quad/draw budget")
for index = 1, #guidedI do
  eq(rawI[index], guidedI[index], "guide changed mesh topology")
end
local uvChanged = 0
for index = 1, #guidedV do
  local a, b = guidedV[index], rawV[index]
  eq(#a, #b, "vertex format changed")
  for field = 1, #a do
    if field == 4 or field == 5 then
      if a[field] ~= b[field] then uvChanged = uvChanged + 1 end
    else
      eq(a[field], b[field], "guide changed non-UV vertex data")
    end
  end
end
eq(uvChanged, 31 * 4 * 2, "guide changed unexpected UV components")
local rawUV = tileUV(0x23)
for key in pairs(expectedPlan) do
  local ty = math.floor(key / 4096) - 64
  local tx = key - (ty + 64) * 4096 - 64
  local quad = findFlatTop(rawV, tx, ty)
  for i = 1, 4 do
    near(quad[i][4], rawUV[i][1], "fail-closed raw U")
    near(quad[i][5], rawUV[i][2], "fail-closed raw V")
  end
end
saffron.def.connections.east.offset = 4
Structures.invalidate("SAFFRON_CITY")

local function rejects(label, mutate, alteredShapes)
  local map = realMap("SAFFRON_CITY")
  if mutate then mutate(map) end
  LedgeElevation.invalidate(map)
  local shapeSet = alteredShapes and alteredShapes(TileShape.forMap(map))
                   or TileShape.forMap(map)
  local rejectedTiles, rejectedUV =
    Structures.saffronRoute8TurnTiles(map, shapeSet)
  eq(rejectedTiles, nil, label .. " did not fail closed")
  eq(rejectedUV, nil, label .. " retained a partial UV plan")
end

rejects("edited connection", function(map)
  map.def.connections.east.offset = 5
end)
rejects("extra connection", function(map)
  map.def.connections.northeast = { map = "EDITED", offset = 0 }
end)
rejects("edited source pixel", function(map)
  local raw = map.tileAt
  function map:tileAt(tx, ty)
    if tx == 79 and ty == 32 then return 0x30 end
    return raw(self, tx, ty)
  end
end)
rejects("blocked guide cell", function(map)
  local raw = map.isWalkableCell
  function map:isWalkableCell(cx, cy)
    if cx == 39 and cy == 16 then return false end
    return raw(self, cx, cy)
  end
end)
rejects("water guide cell", function(map)
  local raw = map.isWaterCell
  function map:isWaterCell(cx, cy)
    if cx == 39 and cy == 16 then return true end
    return raw(self, cx, cy)
  end
end)
rejects("door guide cell", function(map)
  local raw = map.isDoorTileCell
  function map:isDoorTileCell(cx, cy)
    if cx == 39 and cy == 16 then return true end
    return raw(self, cx, cy)
  end
end)
rejects("warp guide cell", function(map)
  local raw = map.warpAtCell
  function map:warpAtCell(cx, cy)
    if cx == 39 and cy == 16 then return { index = 99 } end
    return raw(self, cx, cy)
  end
end)
rejects("opened scenery body", function(map)
  local raw = map.isWalkableCell
  function map:isWalkableCell(cx, cy)
    if cx == 35 and cy == 16 then return true end
    return raw(self, cx, cy)
  end
end)
rejects("edited scenery pixel", function(map)
  local raw = map.tileAt
  function map:tileAt(tx, ty)
    if tx == 70 and ty == 32 then return 0x23 end
    return raw(self, tx, ty)
  end
end)
rejects("missing warp authority", function(map)
  map.warpAtCell = false
end)
rejects("non-flat source shape", nil, function(shapeSet)
  local altered = {}
  for key, value in pairs(shapeSet) do altered[key] = value end
  altered[0x23] = { class="wall", art="upright", h=8, authored=true }
  return altered
end)

do
  local map, rawMap = realMap("SAFFRON_CITY"), LedgeElevation.map
  LedgeElevation.map = function()
    return { atTile = function(_, tx, ty)
      if tx == 79 and ty == 32 then return 6 end
      return 0
    end }
  end
  local rejectedTiles, rejectedUV =
    Structures.saffronRoute8TurnTiles(map, TileShape.forMap(map))
  eq(rejectedTiles, nil, "mixed-datum guide did not fail closed")
  eq(rejectedUV, nil, "mixed-datum guide retained a partial UV plan")
  LedgeElevation.map = rawMap
end

local lavender = realMap("LAVENDER_TOWN")
local lavenderTiles, lavenderUV =
  Structures.saffronRoute8TurnTiles(lavender, TileShape.forMap(lavender))
eq(lavenderTiles, nil, "Saffron turn material leaked to another map")
eq(lavenderUV, nil, "Saffron turn UV leaked to another map")

print("Saffron Route 8 turn top material: ok")
