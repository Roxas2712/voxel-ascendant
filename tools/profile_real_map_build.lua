-- Headless, deterministic profiler for the real generated map-analysis path.
--
-- Usage (the caller supplies decoded 128x48 RGBA bytes on stdin):
--   python3 -c '...' | luajit tools/profile_real_map_build.lua \
--     ../gen1recomp SAFFRON_CITY 0.005
--
-- This intentionally does not invoke LOVE.  It runs the same Map,
-- TileShape, Buildings and Structures Lua code used by ChunkMesher, while a
-- tiny ImageData-compatible wrapper exposes the already-decoded tileset.

local engineRoot = assert(arg[1], "engine root required")
local mapId = arg[2] or "SAFFRON_CITY"
local slice = tonumber(arg[3]) or 0.005
local mode = arg[4] or "structures"
local denseReference = mode:match("^dense%-") ~= nil
local legacyBounds = mode:match("^legacy%-") ~= nil
local objectReference = mode:match("^object%-reference%-") ~= nil
local mutateBlock = mode:find("mutated%-block%-") ~= nil
local mutateApron = mode:find("mutated%-apron%-") ~= nil
local mutateOutdoor = mode:find("mutated%-outdoor%-") ~= nil
local malformedDimensions = mode:find("malformed%-dimensions%-") ~= nil
local malformedReceiptProbe = mode:find("malformed%-receipt%-") ~= nil
local benchmarkOnly = mode:find("benchmark%-", 1, false) ~= nil
local baseMode = mode:gsub("^dense%-", ""):gsub("^legacy%-", "")
                     :gsub("^object%-reference%-", "")
                     :gsub("mutated%-block%-", "")
                     :gsub("mutated%-apron%-", "")
                     :gsub("mutated%-outdoor%-", "")
                     :gsub("malformed%-dimensions%-", "")
                     :gsub("malformed%-receipt%-", "")
                     :gsub("^benchmark%-", "")
local rgba = io.stdin:read("*a")
local imageW, imageH = 128, 48
assert(#rgba == imageW * imageH * 4,
       ("expected %d RGBA bytes, got %d"):format(imageW * imageH * 4,
                                                  #rgba))

local function meshStub()
  return {
    setVertices = function() end,
    setVertexMap = function() end,
    attachAttribute = function() end,
    release = function() end,
  }
end
love = {
  timer = { getTime = os.clock },
  data = {
    pack = function() return "x" end,
    newByteData = function()
      return { release = function() end, getSize = function() return 1 end }
    end,
  },
  graphics = { newMesh = function() return meshStub() end },
}

local imageData = {}
function imageData:getDimensions()
  if malformedDimensions then return imageW - 1, imageH end
  return imageW, imageH
end
function imageData:getPixel(x, y)
  local at = (y * imageW + x) * 4 + 1
  return rgba:byte(at) / 255, rgba:byte(at + 1) / 255,
         rgba:byte(at + 2) / 255, rgba:byte(at + 3) / 255
end

package.preload["src.render.Assets"] = function()
  return { imageData = function() return imageData end,
           register = function() end }
end

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

local loaded, V = {}, {}
function V.data(name)
  return assert(loadfile("data/" .. name .. ".lua"))()
end
function V.require(name)
  if loaded[name] then return loaded[name] end
  if name == "Voxel3D" then
    loaded[name] = {
      FORMAT = {},
      FACE_SHADE = { 0.84, 0.72, 1, 0.55, 0.90, 0.68 },
      pushQuad = function(indices, quad)
        local base = quad * 4
        for _, index in ipairs({ 1, 2, 3, 1, 3, 4 }) do
          indices[#indices + 1] = base + index
        end
      end,
      canInstance = function() return false end,
    }
    return loaded[name]
  elseif name == "ModSetting" then
    loaded[name] = { new = function()
      return { get = function() return true end }
    end }
    return loaded[name]
  end
  local path = "lib/" .. name .. ".lua"
  if name == "Buildings" and denseReference then
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    local replaced
    source, replaced = source:gsub(
      'local rangeCache = type%(m%.ranges%) == "function" and {} or nil',
      "local rangeCache = false", 1)
    assert(replaced == 1, "dense reference transform no longer matches")
    loaded[name] = assert(loadstring(source, "@" .. path .. "#dense"))(V)
  elseif name == "Structures" and (legacyBounds or objectReference) then
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    if legacyBounds then
      local replaced
      source, replaced = source:gsub(
        "  if hullRingOnly then\n    x0, x1 = %-ROUND_RING, tw %+ ROUND_RING %- 1",
        "  if false and hullRingOnly then\n"
          .. "    x0, x1 = -ROUND_RING, tw + ROUND_RING - 1", 1)
      assert(replaced == 1, "legacy bounds transform no longer matches")
    end
    if objectReference then
      local needle = [[  if route8VolumeRegionReceipt(S, map, region, data, perRow, force) then
    return region.tiles
  end]]
      local first, last = source:find(needle, 1, true)
      assert(first and not source:find(needle, last + 1, true),
             "object reference transform no longer matches")
      source = source:sub(1, first - 1)
        .. "  if false and route8VolumeRegionReceipt(S, map, region, data, perRow, force) then\n"
        .. "    return region.tiles\n  end"
        .. source:sub(last + 1)
    end
    local suffix = legacyBounds and "#legacy" or "#object-reference"
    loaded[name] = assert(loadstring(source, "@" .. path .. suffix))(V)
  else
    loaded[name] = assert(loadfile(path))(V)
  end
  return loaded[name]
end

local maps = assert(loadfile(engineRoot .. "/data/generated/maps.lua"))()
local tilesets = assert(loadfile(engineRoot .. "/data/generated/tilesets.lua"))()
local def = assert(maps[mapId], "unknown map " .. tostring(mapId))
if mutateBlock then
  assert(mapId == "ROUTE_8", "block mutation is Route8-only")
  local copy = {}
  for key, value in pairs(def) do copy[key] = value end
  copy.blocks = {}
  for i, value in ipairs(def.blocks) do copy.blocks[i] = value end
  copy.blocks[1] = copy.blocks[1] + 1
  def = copy
end
local map = RealMap.new(def, assert(tilesets[def.tileset]))
assert(map.tileset.id == "OVERWORLD",
       "this profiler currently accepts the 128x48 OVERWORLD atlas")

-- A deterministic, graph-aware digest.  Sorted primitive keys make hash-table
-- insertion order irrelevant; reference ids also prove that shared templates
-- and stamp streams retain the same topology instead of merely the same
-- aggregate counts.
local function canonicalDigest(root)
  local prime1, prime2 = 4294967291, 4294967279
  local h1, h2, atoms = 2166136261, 2246822519, 0
  local seen, nextId = {}, 0
  local rank = { boolean = 1, number = 2, string = 3 }
  local function add(text)
    atoms = atoms + 1
    for i = 1, #text do
      local byte = text:byte(i)
      h1 = (h1 * 257 + byte) % prime1
      h2 = (h2 * 263 + byte) % prime2
    end
    h1 = (h1 * 257 + 255) % prime1
    h2 = (h2 * 263 + 255) % prime2
  end
  local walk
  walk = function(value)
    local kind = type(value)
    if kind == "nil" then
      add("z")
    elseif kind == "boolean" then
      add(value and "b1" or "b0")
    elseif kind == "number" then
      add("n" .. string.format("%.17g", value))
    elseif kind == "string" then
      add("s" .. #value .. ":" .. value)
    elseif kind == "table" then
      if seen[value] then
        add("r" .. seen[value])
        return
      end
      nextId = nextId + 1
      seen[value] = nextId
      local keys = {}
      for key in pairs(value) do
        assert(rank[type(key)], "non-primitive digest key: " .. type(key))
        keys[#keys + 1] = key
      end
      table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta ~= tb then return rank[ta] < rank[tb] end
        if ta == "boolean" then return (a and 1 or 0) < (b and 1 or 0) end
        return a < b
      end)
      add("t" .. nextId .. ":" .. #keys)
      for _, key in ipairs(keys) do
        walk(key)
        walk(value[key])
      end
    else
      error("unsupported digest value: " .. kind)
    end
  end
  walk(root)
  return string.format("%.0f:%.0f", h1, h2), nextId, atoms
end

local function collisionSnapshot(m)
  local rows = {}
  for cy = -1, m.heightCells do
    for cx = -1, m.widthCells do
      rows[#rows + 1] = {
        cx, cy, m:cellTile(cx, cy),
        m:isWalkableCell(cx, cy), m:isWaterCell(cx, cy),
        m:isDoorTileCell(cx, cy), m:isWarpTileCell(cx, cy),
      }
    end
  end
  return rows
end

local function warpSnapshot(m)
  local rows = { definitions = m.def.warps or {}, placed = {} }
  for cy = -1, m.heightCells do
    for cx = -1, m.widthCells do
      local placed = m:warpAtCell(cx, cy)
      if placed then
        rows.placed[#rows.placed + 1] = {
          cx = cx, cy = cy, index = placed.index, def = placed.def,
        }
      end
    end
  end
  return rows
end

local collisionBefore = benchmarkOnly and nil
                        or canonicalDigest(collisionSnapshot(map))
local warpsBefore = benchmarkOnly and nil or canonicalDigest(warpSnapshot(map))

local Budget = V.require("BuildBudget")
local Buildings = V.require("Buildings")
local Structures = V.require("Structures")
if mutateApron or mutateOutdoor then
  assert(mapId == "ROUTE_8", "receipt mutation is Route8-only")
  local rawExtractObjects = Structures.extractObjects
  local mutated = false
  Structures.extractObjects = function(S, currentMap, region, ...)
    if not mutated and currentMap and currentMap.id == "ROUTE_8"
       and region.minX == 10 and region.minY == 0
       and region.maxX == 109 and region.maxY == 5 then
      if mutateOutdoor then
        S.outdoor = false
      else
        local ty, key, shape = region.maxY + 1
        for tx = region.minX - 1, region.maxX + 1 do
          local candidate = (ty + 64) * 4096 + (tx + 64)
          local value = S.shapeAt[candidate]
          if value and value.flat and value.class ~= "void" then
            key, shape = candidate, value
            break
          end
        end
        assert(key, "Route8 south apron fixture has no air cell")
        local replacement = {}
        for name, value in pairs(shape) do replacement[name] = value end
        replacement.class = "void"
        S.shapeAt[key] = replacement
      end
      mutated = true
    end
    return rawExtractObjects(S, currentMap, region, ...)
  end
end
local ChunkMesher = (baseMode == "geometry" or baseMode:match("^async"))
                    and V.require("ChunkMesher") or nil
Buildings.diagnostics(false)
Buildings.invalidate()
Structures.invalidate(mapId)

local started = os.clock()
local result = {}
local co = coroutine.create(function()
  if baseMode == "geometry" then
    result.vertices, result.indices, result.quads =
      ChunkMesher.geometry(map, true)
  else
    result.analysis = Structures.forMap(map)
  end
end)
local resumes, maxResume, totalResume = 0, 0, 0
local bodyFrame, auxFrame
if baseMode:match("^async") then
  ChunkMesher.setLive({ [mapId] = true })
  local urgent = baseMode == "async-urgent"
  ChunkMesher.request(map, true, nil, urgent, urgent and 0 or 2)
  while not (ChunkMesher.pair(map, true)
             and ChunkMesher.auxReady(map)) do
    local at = os.clock()
    ChunkMesher.pump(false, false, false)
    local elapsed = os.clock() - at
    resumes = resumes + 1
    totalResume = totalResume + elapsed
    if elapsed > maxResume then maxResume = elapsed end
    if not bodyFrame and ChunkMesher.pair(map, true) then bodyFrame = resumes end
    if not auxFrame and ChunkMesher.auxReady(map) then auxFrame = resumes end
    assert(resumes < 10000, "async build did not converge")
  end
else
  while coroutine.status(co) ~= "dead" do
    Budget.begin(co, slice)
    local at = os.clock()
    local ok, reason = coroutine.resume(co)
    local elapsed = os.clock() - at
    Budget.finish()
    assert(ok, reason)
    resumes = resumes + 1
    totalResume = totalResume + elapsed
    if elapsed > maxResume then maxResume = elapsed end
  end
end
local buildCpu = os.clock() - started

if malformedReceiptProbe then
  local receipt
  for index = 1, 100 do
    local name, value = debug.getupvalue(Structures.extractObjects, index)
    if not name then break end
    if name == "route8VolumeRegionReceipt" then receipt = value break end
  end
  assert(type(receipt) == "function", "Route8 receipt helper not reachable")
  local analysis = result.analysis or Structures.forMap(map)
  local function reject(label, region)
    local ok, value = pcall(receipt, analysis, map, region,
                            imageData, 16, nil)
    assert(ok and value == false,
           "malformed receipt did not fail closed: " .. label)
  end
  for _, missing in ipairs({ "minX", "minY", "maxX", "maxY" }) do
    local region = { tiles = {}, minX = 9, minY = 20,
                     maxX = 119, maxY = 35 }
    region[missing] = nil
    reject("nil-" .. missing, region)
  end
  reject("string-bound", {
    tiles = {}, minX = "malformed", minY = 20, maxX = 119, maxY = 35,
  })
  reject("nan-bound", {
    tiles = {}, minX = 0 / 0, minY = 20, maxX = 119, maxY = 35,
  })
  local function malformedCells(x, y)
    local tiles = {}
    for i = 1, 490 do tiles[i] = { 9, 20 } end
    tiles[1] = { x, y }
    return { tiles = tiles, minX = 9, minY = 20,
             maxX = 119, maxY = 35 }
  end
  reject("nan-cell-x", malformedCells(0 / 0, 20))
  reject("fractional-cell-x", malformedCells(9.5, 20))
  reject("nan-cell-y", malformedCells(9, 0 / 0))
  reject("fractional-cell-y", malformedCells(9, 20.5))
end

local models, voxels, quads = Buildings.stats(), 0, 0
local ordered = {}
for key, row in pairs(models) do
  voxels, quads = voxels + (row.voxels or 0), quads + (row.quads or 0)
  ordered[#ordered + 1] = { key = key, row = row }
end
table.sort(ordered, function(a, b)
  if (a.row.voxels or 0) ~= (b.row.voxels or 0) then
    return (a.row.voxels or 0) > (b.row.voxels or 0)
  end
  return a.key < b.key
end)

local geometryDigest = 0
if result.vertices then
  local prime = 4294967291
  geometryDigest = 2166136261
  local function add(value)
    geometryDigest = (geometryDigest * 257 + value) % prime
  end
  for _, vertex in ipairs(result.vertices) do
    for i = 1, #vertex do
      add(math.floor(vertex[i] * 100000000 + 0.5) + 1073741824)
    end
  end
  for _, index in ipairs(result.indices) do add(index) end
end

local structuresDigest, structureNodes, structureAtoms = "skipped", 0, 0
local collisionAfter, warpsAfter = "skipped", "skipped"
if not benchmarkOnly then
  local analysis = result.analysis or Structures.forMap(map)
  structuresDigest, structureNodes, structureAtoms = canonicalDigest(analysis)
  collisionAfter = canonicalDigest(collisionSnapshot(map))
  warpsAfter = canonicalDigest(warpSnapshot(map))
  assert(collisionAfter == collisionBefore,
         "Structures/geometry build mutated collision behavior")
  assert(warpsAfter == warpsBefore,
         "Structures/geometry build mutated warp behavior")
end

print(("PROFILE map=%s mode=%s slice_ms=%.3f resumes=%d cpu_ms=%.3f "
       .. "resume_cpu_ms=%.3f max_resume_ms=%.3f models=%d "
       .. "voxels=%d quads=%d terrain_quads=%d body_frame=%d "
       .. "aux_frame=%d geometry_digest=%.0f structures_digest=%s "
       .. "structure_nodes=%d structure_atoms=%d collision_digest=%s "
       .. "warps_digest=%s budget_ticks=%d heap_kib=%.1f")
  :format(mapId, mode, slice * 1000, resumes, buildCpu * 1000,
          totalResume * 1000, maxResume * 1000, #ordered, voxels, quads,
          result.quads or 0, bodyFrame or 0, auxFrame or 0, geometryDigest,
          structuresDigest, structureNodes, structureAtoms, collisionAfter,
          warpsAfter, Budget.n, collectgarbage("count")))
for i = 1, math.min(20, #ordered) do
  local entry = ordered[i]
  print(("MODEL rank=%d key=%s voxels=%d quads=%d")
    :format(i, entry.key, entry.row.voxels or 0, entry.row.quads or 0))
end
