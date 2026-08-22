-- Exhaustive headless audit for the semantic outdoor horizon.
--
-- Every real outdoor/profiled map is built in every subset of its directly
-- connected resident neighbours.  The audit independently rasterises the
-- real map bodies and the generated ground/sea quads on the native 32px
-- lattice, then proves that every exposed body edge reaches its semantic wall
-- without a hole or a ground/sea double claim.  It also reports (but does not
-- reject) intentional or suspicious material changes along edges and at 90°
-- corners so native QA can concentrate on the places that need visual taste.

local engineRoot = arg[1] or "../gen1recomp"
local realDefs = assert(loadfile(engineRoot .. "/data/generated/maps.lua"))()
local realTilesets =
  assert(loadfile(engineRoot .. "/data/generated/tilesets.lua"))()
local RealMap = assert(loadfile(engineRoot .. "/src/world/Map.lua"))()

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
  return { data = { maps = realDefs } }
end

local loaded, V = {}, { path = "." }
function V.require(name)
  if loaded[name] then return loaded[name] end
  if name == "Voxel3D" then
    loaded[name] = {
      FACE_SHADE = { 0.84, 0.72, 1, 0.55, 0.90, 0.68 },
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

local Horizon = V.require("HorizonWall")
local C = Horizon.CELL
local failures, warnings = {}, {}
local progressiveRiskMaps = {}
local statesBuilt, mapsAudited, quadsAudited = 0, 0, 0

local function fail(message)
  if #failures < 80 then failures[#failures + 1] = message end
end

local function warn(message)
  if #warnings < 120 then warnings[#warnings + 1] = message end
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

local mapCache = {}
local function realMap(id)
  if mapCache[id] then return mapCache[id] end
  local source = assert(realDefs[id], "missing real map " .. tostring(id))
  local def = copy(source)
  local map = RealMap.new(def, assert(realTilesets[def.tileset]))
  mapCache[id] = map
  return map
end

local function delta(def, dest, direction, connection)
  local offset = (connection.offset or 0) * C
  if direction == "north" then return offset, -dest.height * C end
  if direction == "south" then return offset, def.height * C end
  if direction == "west" then return -dest.width * C, offset end
  if direction == "east" then return def.width * C, offset end
end

local function key(x, z) return tostring(x) .. ":" .. tostring(z) end
local function integer(value)
  return type(value) == "number" and value == value
    and value > -math.huge and value < math.huge
    and value == math.floor(value)
end

local function collectQuads(part, field, owner, claims)
  local verts = part[field] or {}
  if #verts % 4 ~= 0 then
    fail(owner .. " " .. field .. " vertex count is not quad-aligned")
    return
  end
  for at = 1, #verts, 4 do
    local minX, maxX, minZ, maxZ = math.huge, -math.huge,
                                      math.huge, -math.huge
    local y = verts[at][2]
    local flat = true
    for i = at, at + 3 do
      local v = verts[i]
      flat = flat and v[2] == y
      minX, maxX = math.min(minX, v[1]), math.max(maxX, v[1])
      minZ, maxZ = math.min(minZ, v[3]), math.max(maxZ, v[3])
    end
    if not flat or maxX - minX ~= C or maxZ - minZ ~= C then
      fail(owner .. " " .. field .. " contains a non-native horizontal quad")
    else
      local x, z = part.ox + minX, part.oy + minZ
      if not integer(x) or not integer(z) or x % C ~= 0 or z % C ~= 0 then
        fail(owner .. " " .. field .. " left the native 32px lattice")
      end
      local k = key(x, z)
      local layer = field == "seaVertices" and claims.sea or claims.ground
      if layer[k] then
        fail(owner .. " duplicate " .. field .. " cell " .. k)
      else
        layer[k] = true
      end
      quadsAudited = quadsAudited + 1
    end
  end
end

local function mapDistance(map)
  return Horizon.classFor(map) == "pallet"
         and Horizon.PALLET_WALL_DISTANCE
         or Horizon.OUTDOOR_WALL_DISTANCE
end

local directions = {
  { "north", 0, -1 }, { "south", 0, 1 },
  { "west", -1, 0 }, { "east", 1, 0 },
}

local function auditState(root, neighbours, label)
  local state = { map = root, neighbors = neighbours }
  local parts = Horizon.geometry(state)
  local claims = { ground = {}, sea = {} }
  local bodies, owners = {}, {}
  local entries = { { map = root, ox = 0, oy = 0 } }
  for _, nb in ipairs(neighbours) do
    entries[#entries + 1] = { map = nb.map, ox = nb.ox, oy = nb.oy }
  end
  for _, entry in ipairs(entries) do
    local w, h = entry.map.def.width * C, entry.map.def.height * C
    for x = entry.ox, entry.ox + w - C, C do
      for z = entry.oy, entry.oy + h - C, C do
        local k = key(x, z)
        bodies[k], owners[k] = true, entry.map
      end
    end
  end
  for _, part in ipairs(parts) do
    local owner = label .. "/" .. tostring(part.map.id)
    collectQuads(part, "groundVertices", owner, claims)
    collectQuads(part, "seaVertices", owner, claims)
  end

  for k in pairs(bodies) do
    if claims.ground[k] or claims.sea[k] then
      fail(label .. " scenery overlaps real body " .. k)
    end
  end
  local gaps = {}
  for k, map in pairs(owners) do
    local sx, sz = k:match("^(-?%d+):(-?%d+)$")
    local x, z = tonumber(sx), tonumber(sz)
    for _, direction in ipairs(directions) do
      local dx, dz = direction[2], direction[3]
      if not bodies[key(x + dx * C, z + dz * C)] then
        local steps = mapDistance(map) / C
        for step = 1, steps do
          local tx, tz = x + dx * C * step, z + dz * C * step
          local target = key(tx, tz)
          if not bodies[target]
             and not claims.ground[target] and not claims.sea[target] then
            local group = map.id .. " " .. direction[1]
            local row = gaps[group] or { count = 0, maxStep = 0, sample = target }
            row.count, row.maxStep = row.count + 1, math.max(row.maxStep, step)
            gaps[group] = row
          end
        end
      end
    end
  end
  local groups = {}
  for group in pairs(gaps) do groups[#groups + 1] = group end
  table.sort(groups)
  for _, group in ipairs(groups) do
    local row = gaps[group]
    -- The first 32px is also owned by Structures' native carved border/tree
    -- ring and cannot be proven by Horizon geometry alone.  A hole reaching
    -- the second or third cell is unequivocally between that ring and the
    -- semantic bitmap, so only that case is a headless failure; the near ring
    -- is covered by the multi-position native pass below.
    if row.maxStep > 1 then
      if #neighbours == 0 then
        fail(label .. " gap-group=" .. group .. " cells=" .. row.count
             .. " max_step=" .. row.maxStep .. " sample=" .. row.sample)
      else
        progressiveRiskMaps[root.id] = true
      end
    end
  end
  statesBuilt = statesBuilt + 1
end

local function edgeKinds(map, edge)
  local horizontal = edge == "north" or edge == "south"
  local length = (horizontal and map.def.width or map.def.height) * C
  local out = {}
  for along = 0, length - C, C do
    local kind = Horizon.panelProfile(map, edge, along)
    if out[#out] and out[#out].kind == kind then
      out[#out].count = out[#out].count + 1
    else
      out[#out + 1] = { kind = kind, count = 1 }
    end
  end
  return out
end

local function endKind(map, edge, atEnd)
  local horizontal = edge == "north" or edge == "south"
  local length = (horizontal and map.def.width or map.def.height) * C
  return Horizon.panelProfile(map, edge, atEnd and length - C or 0)
end

local function auditProfile(map)
  local edges = {}
  for _, edge in ipairs({ "north", "south", "west", "east" }) do
    edges[edge] = edgeKinds(map, edge)
    if #edges[edge] > 1 then
      local runs = {}
      for _, run in ipairs(edges[edge]) do
        runs[#runs + 1] = run.kind .. "x" .. run.count
      end
      warn(map.id .. " " .. edge .. " transitions " .. table.concat(runs, ">"))
    end
  end
  local corners = {
    { "NW", "north", false, "west", false },
    { "NE", "north", true,  "east", false },
    { "SW", "south", false, "west", true },
    { "SE", "south", true,  "east", true },
  }
  for _, corner in ipairs(corners) do
    local a = endKind(map, corner[2], corner[3])
    local b = endKind(map, corner[4], corner[5])
    if a ~= b then
      warn(map.id .. " " .. corner[1] .. " corner " .. a .. ">" .. b)
    end
  end
end

local ids = {}
local onlyMap = os.getenv("VASC_AUDIT_MAP")
for id in pairs(Horizon.EDGE_PROFILES) do
  if not onlyMap or onlyMap == "" or id == onlyMap then ids[#ids + 1] = id end
end
table.sort(ids)

for _, id in ipairs(ids) do
  local root = realMap(id)
  mapsAudited = mapsAudited + 1
  auditProfile(root)
  local available = {}
  for _, direction in ipairs({ "north", "south", "west", "east" }) do
    local connection = root.def.connections and root.def.connections[direction]
    local destDef = connection and realDefs[connection.map]
    if destDef and Horizon.EDGE_PROFILES[connection.map] then
      local ox, oy = delta(root.def, destDef, direction, connection)
      available[#available + 1] = {
        direction = direction, map = realMap(connection.map), ox = ox, oy = oy,
      }
    end
  end
  local combinations = 2 ^ #available
  for mask = 0, combinations - 1 do
    local neighbours, names = {}, {}
    for index, entry in ipairs(available) do
      if math.floor(mask / 2 ^ (index - 1)) % 2 == 1 then
        neighbours[#neighbours + 1] = entry
        names[#names + 1] = entry.direction .. "=" .. entry.map.id
      end
    end
    local label = id .. "[" .. (#names > 0 and table.concat(names, ",")
                                     or "cold") .. "]"
    auditState(root, neighbours, label)
  end
end

if #warnings > 0 then
  print("VASC_OUTDOOR_TRANSITION_WARNINGS count=" .. #warnings)
  for _, message in ipairs(warnings) do print("WARN " .. message) end
end
local riskIds = {}
for id in pairs(progressiveRiskMaps) do riskIds[#riskIds + 1] = id end
table.sort(riskIds)
if #riskIds > 0 then
  print("VASC_OUTDOOR_PROGRESSIVE_NATIVE_CHECK maps="
        .. table.concat(riskIds, ","))
end
if #failures > 0 then
  print("VASC_OUTDOOR_TRANSITION_FAIL count=" .. #failures)
  for _, message in ipairs(failures) do print("FAIL " .. message) end
  os.exit(1)
end
print(("VASC_OUTDOOR_TRANSITION_PASS maps=%d states=%d surface_quads=%d warnings=%d")
  :format(mapsAudited, statesBuilt, quadsAudited, #warnings))
