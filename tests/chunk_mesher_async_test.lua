-- Behavioural regression for the cold-map transition path.  The fake driver
-- charges four milliseconds per vertex upload, making a route-sized upload
-- visibly exceed ChunkMesher's 12ms urgent budget unless finish() pages it and
-- yields between calls.

local runnerLove = love
local now = 0
local pumpNo = 0
local uploads, capacities, mapUploads = {}, {}, {}
local releases = 0
local failUpload = false
local failVertexMap = false
local newMeshCalls, failNewMeshAt = 0, nil
local dataCreates, dataReleases = 0, 0
local uploadedPageRefs = setmetatable({}, { __mode = "k" })

love = {
  timer = { getTime = function() return now end },
  graphics = {},
  data = {},
}

function love.data.pack(container, format, ...)
  if container ~= "string" or format:sub(1, 1) ~= "=" then
    error("async indices must use a native-endian packed string")
  end
  local values = { ... }
  local floatFields = 0
  for _ in format:gmatch("f") do floatFields = floatFields + 1 end
  if floatFields > 0 then
    if floatFields ~= #values then error("packed vertex format/value mismatch") end
    return string.rep("\0", #values * 4)
  end
  local fields = 0
  for _ in format:gmatch("I4") do fields = fields + 1 end
  if fields ~= #values then error("packed index format/value mismatch") end
  local bytes = {}
  for _, value in ipairs(values) do
    bytes[#bytes + 1] = string.char(
      value % 256,
      math.floor(value / 256) % 256,
      math.floor(value / 65536) % 256,
      math.floor(value / 16777216) % 256)
  end
  return table.concat(bytes)
end

function love.data.newByteData(bytes)
  if type(bytes) ~= "string" then error("packed indices were not bytes") end
  dataCreates = dataCreates + 1
  local data = { bytes = bytes, released = false }
  function data:getSize() return #self.bytes end
  function data:release()
    if self.released then error("index data released twice") end
    self.released = true
    dataReleases = dataReleases + 1
  end
  return data
end

local function uint32At(bytes, offset)
  local a, b, c, d = bytes:byte(offset + 1, offset + 4)
  return a + b * 256 + c * 65536 + d * 16777216
end

function love.graphics.newMesh(_, vertices)
  if type(vertices) ~= "number" then
    error("async terrain unexpectedly used a route-sized vertex table")
  end
  newMeshCalls = newMeshCalls + 1
  if failNewMeshAt == newMeshCalls then return nil end
  capacities[#capacities + 1] = vertices
  local mesh = {}
  function mesh:setVertices(page, first, count)
    -- The preceding uploaded page must become unreachable before the next
    -- driver call. This catches retaining all consumed pages until finish().
    collectgarbage("collect")
    for _ in pairs(uploadedPageRefs) do
      error("an uploaded vertex page stayed strongly referenced")
    end
    if failUpload then
      failUpload = false
      error("simulated upload failure")
    end
    local source = page.bytes and (#page.bytes / 24) or #page
    if page.released then error("released vertex data reached driver") end
    uploads[#uploads + 1] = {
      pump = pumpNo, count = count, source = source, first = first,
    }
    uploadedPageRefs[page] = true
    now = now + 0.004
  end
  function mesh:setVertexMap(data, indexType, count)
    if data.released then error("released index data reached the driver") end
    if indexType ~= "uint32" then error("voxel indices are not uint32") end
    if #data.bytes ~= count * 4 then error("packed index byte count mismatch") end
    for i = 0, count - 1 do
      local quad, corner = math.floor(i / 6), (i % 6) + 1
      local expected = quad * 4 + ({ 0, 1, 2, 0, 2, 3 })[corner]
      if uint32At(data.bytes, i * 4) ~= expected then
        error("packed quad index order mismatch at " .. tostring(i))
      end
    end
    mapUploads[#mapUploads + 1] = {
      pump = pumpNo, count = count, bytes = #data.bytes,
      first = uint32At(data.bytes, 0),
      last = uint32At(data.bytes, #data.bytes - 4),
    }
    now = now + 0.004
    if failVertexMap then
      failVertexMap = false
      error("simulated vertex-map failure")
    end
  end
  function mesh:release()
    releases = releases + 1
  end
  return mesh
end

package.preload["src.render.Assets"] = function()
  return { register = function() end }
end

local S = {
  skip = {}, runs = {}, shapeAt = {}, tileAt = {}, ground = {},
  objectQuads = {}, roundStamps = {}, grassQuads = {}, flowerQuads = {},
  figures = {},
}

local function keyOf(tx, ty)
  return (ty + 64) * 4096 + (tx + 64)
end

-- 80x80 tiles (a 20x20-block route): enough geometry for many upload pages
-- while keeping this headless regression quick.
for ty = 0, 79 do
  for tx = 0, 79 do
    local key = keyOf(tx, ty)
    S.shapeAt[key] = { h = 0, art = "flat", class = "ground" }
    S.tileAt[key] = 0
  end
end

-- Same route with one surface quad split into the water sink. It lets the
-- test fail the SECOND allocation after terrain already succeeded, which is
-- the dangerous mobile-memory case: neither half may land on its own.
local SWater = {}
for field, value in pairs(S) do SWater[field] = value end
SWater.shapeAt = {}
for key, value in pairs(S.shapeAt) do SWater.shapeAt[key] = value end
SWater.shapeAt[keyOf(0, 0)] = { h = 0, art = "flat", class = "water" }

local Structures = {
  forMap = function(map)
    return map and map.id == "ASYNC_WATER_FAILURE" and SWater or S
  end,
  invalidate = function() end,
}

local cache = {}
local V = {}
function V.require(name)
  if cache[name] then return cache[name] end
  if name == "Structures" then
    cache[name] = Structures
  elseif name == "TileShape" then
    cache[name] = {}
  elseif name == "LedgeElevation" then
    cache[name] = {
      map = function()
        return { at = function() return 0 end }
      end,
      invalidate = function() return true end,
    }
  elseif name == "Voxel3D" then
    cache[name] = {
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
      newMesh = function() error("synchronous mesh path used by async job") end,
    }
  elseif name == "BuildBudget" then
    cache[name] = assert(loadfile("lib/BuildBudget.lua"))()
  elseif name == "ModSetting" then
    cache[name] = {
      new = function()
        return { get = function() return true end }
      end,
    }
  else
    error("unexpected dependency: " .. tostring(name))
  end
  return cache[name]
end

local Mesher = assert(loadfile("lib/ChunkMesher.lua"))(V)
local map = {
  id = "ASYNC_ROUTE",
  def = { width = 20, height = 20 },
  tileset = { tilesPerRow = 16, imageWidth = 128, imageHeight = 48 },
}

local function expect(ok, message)
  if not ok then error(message, 2) end
end

local function pump()
  pumpNo = pumpNo + 1
  Mesher.pump(false, false, false)
end

Mesher.request(map, true, nil, true)
pump()
expect(Mesher.pending() == 1,
       "one urgent pump consumed the entire cold route despite its budget")
expect(#uploads > 1, "test route did not exercise paged uploads")
expect(Mesher.ready(map, true) == false,
       "partially uploaded terrain became drawable")

-- Cancelling a map between pages must release its in-flight GPU allocation.
Mesher.invalidate(map.id)
expect(Mesher.pending() == 0, "cancelled upload stayed in the build queue")
expect(releases == 1, "cancelled partial mesh leaked its GPU allocation")

uploads, capacities, mapUploads = {}, {}, {}
Mesher.request(map, true, nil, true)
local guard = 0
while Mesher.pending() > 0 and guard < 100 do
  pump()
  guard = guard + 1
end
expect(guard < 100, "paged cold-map build never completed")
expect(Mesher.ready(map, true) ~= false, "completed route has no terrain")

local perPump, maxPage = {}, 0
for _, upload in ipairs(uploads) do
  expect(upload.count == upload.source, "upload count/source mismatch")
  expect(upload.count <= Mesher._UPLOAD_VERTICES,
         "a route-sized vertex page reached the driver")
  perPump[upload.pump] = (perPump[upload.pump] or 0) + 1
  maxPage = math.max(maxPage, upload.count)
end
for _, count in pairs(perPump) do
  expect(count <= 5, "one pump exceeded the simulated 12ms upload budget")
end
expect(#capacities == 1, "terrain should use one final mesh allocation")
expect(capacities[1] > maxPage,
       "test did not prove a large mesh was split into smaller driver calls")
expect(capacities[1] == 80 * 80 * 4,
       "async mesh did not retain four unique vertices per quad")
expect(#mapUploads == 1, "terrain did not receive exactly one packed index map")
expect(mapUploads[1].count == 80 * 80 * 6,
       "packed index map did not contain six indices per quad")
expect(mapUploads[1].bytes == mapUploads[1].count * 4,
       "packed uint32 index byte size is wrong")
expect(mapUploads[1].first == 0 and mapUploads[1].last == capacities[1] - 1,
       "packed index map is not zero-based or lost its final corner")
local completedCapacity, completedUploads, completedMaxPage =
  capacities[1], #uploads, maxPage

-- setLive cancellation follows the same ownership rule as invalidate: a
-- half-filled GPU buffer is never retained when its map leaves both live sets.
local map2 = {
  id = "ASYNC_ROUTE_2", def = map.def, tileset = map.tileset,
}
Mesher.request(map2, true, nil, true)
pump()
local beforeSetLive = releases
Mesher.setLive({ [map.id] = true })
expect(Mesher.pending() == 0, "setLive left an evicted upload queued")
expect(releases == beforeSetLive + 1,
       "setLive leaked an evicted partial GPU allocation")

-- A driver failure also releases the allocation and never exposes the
-- half-answer as drawable terrain.
local map3 = {
  id = "ASYNC_ROUTE_3", def = map.def, tileset = map.tileset,
}
failUpload = true
local beforeFailure = releases
Mesher.request(map3, true, nil, true)
pump()
expect(Mesher.pending() == 0, "failed upload stayed queued")
expect(releases == beforeFailure + 1,
       "failed upload leaked its partial GPU allocation")
expect(Mesher.ready(map3, true) == false,
       "failed upload became drawable terrain")

-- The compact binary index-map call is part of the same atomic answer. A
-- driver failure there must release both its temporary Data and final mesh.
local map4 = {
  id = "ASYNC_ROUTE_4", def = map.def, tileset = map.tileset,
}
failVertexMap = true
local beforeMapFailure = releases
local beforeMapDataRelease = dataReleases
local beforeMapDataCreate = dataCreates
Mesher.request(map4, true, nil, true)
guard = 0
while Mesher.pending() > 0 and guard < 100 do
  pump()
  guard = guard + 1
end
expect(guard < 100, "failed vertex-map upload never left the queue")
expect(releases == beforeMapFailure + 1,
       "failed vertex-map upload leaked its mesh allocation")
expect(dataCreates > beforeMapDataCreate
       and dataReleases - beforeMapDataRelease
           == dataCreates - beforeMapDataCreate,
       "failed vertex-map upload leaked temporary vertex/index Data")
expect(Mesher.ready(map4, true) == false,
       "failed vertex-map upload became drawable terrain")

-- If terrain allocation succeeds but the separate non-empty water sink cannot
-- allocate, the whole pair must fail atomically. Landing only the terrain
-- would expose holes where its water quads were deliberately removed.
local waterMap = {
  id = "ASYNC_WATER_FAILURE", def = map.def, tileset = map.tileset,
}
failNewMeshAt = newMeshCalls + 2
local beforeWaterFailure = releases
Mesher.request(waterMap, true, nil, true)
guard = 0
while Mesher.pending() > 0 and guard < 100 do
  pump()
  guard = guard + 1
end
expect(guard < 100, "failed water allocation never left the queue")
expect(releases == beforeWaterFailure + 1,
       "water allocation failure leaked its completed terrain half")
expect(Mesher.ready(waterMap, true) == false,
       "terrain landed without its required water half")
failNewMeshAt = nil

-- A failed in-place refresh keeps the previously drawable cache entry. It
-- must release only the failed replacement and clear the immediate retry
-- marker, not overwrite/leak the old GPU mesh with a false sentinel.
local oldMesh = Mesher.ready(map, true)
local beforeRefreshFailure = releases
Mesher.refresh(map.id)
failUpload = true
Mesher.request(map, true, nil, true)
pump()
expect(Mesher.pending() == 0, "failed refresh stayed queued")
expect(releases == beforeRefreshFailure + 1,
       "failed refresh did not release exactly its replacement allocation")
expect(Mesher.ready(map, true) == oldMesh,
       "failed refresh discarded the previously drawable mesh")
expect(Mesher.request(map, true, nil, true) == oldMesh,
       "failed refresh immediately requeued instead of keeping its fallback")
expect(Mesher.pending() == 0,
       "failed refresh entered an unbounded per-frame retry cycle")
expect(dataCreates == dataReleases,
       "completed/failed packed index Data objects were not all released")

-- A map kept solely as the one-step return cache must not keep its old
-- urgent bit. The newly entered destination has to land before that retained
-- partial job, otherwise a door fade spends frames finishing the room the
-- player just left.
local oldMap = {
  id = "ASYNC_RETAINED_OLD", def = map.def, tileset = map.tileset,
}
local targetMap = {
  id = "ASYNC_NEW_TARGET", def = map.def, tileset = map.tileset,
}
Mesher.setLive({ [oldMap.id] = true })
Mesher.request(oldMap, true, nil, true)
pump()
expect(Mesher.pending() == 1 and Mesher.ready(oldMap, true) == false,
       "retained-priority fixture did not leave an old partial job")
Mesher.setLive({ [targetMap.id] = true })
Mesher.request(targetMap, true, nil, true)
guard = 0
while Mesher.ready(targetMap, true) == false and guard < 100 do
  pump()
  guard = guard + 1
end
expect(guard < 100 and Mesher.ready(targetMap, true) ~= false,
       "new destination did not finish")
expect(Mesher.ready(oldMap, true) == false,
       "retained old-map job ran ahead of the destination")
Mesher.invalidate(oldMap.id)
Mesher.invalidate(targetMap.id)

-- The same ordering must hold for ordinary neighbour work, not only an urgent
-- destination. A partial job kept solely for the previous live set used to sit
-- at the FIFO head and consume the post-ready frames before a new live route's
-- grass/body work. Retain it for a quick return, but schedule all current-live
-- jobs first without enlarging their ordinary 5ms slice.
local oldBackground = {
  id = "ASYNC_RETAINED_BACKGROUND", def = map.def, tileset = map.tileset,
}
local liveBackground = {
  id = "ASYNC_NEW_LIVE_BACKGROUND", def = map.def, tileset = map.tileset,
}
Mesher.setLive({ [oldBackground.id] = true })
Mesher.request(oldBackground, true, nil, false)
pump()
expect(Mesher.pending() == 1 and Mesher.ready(oldBackground, true) == false,
       "background fixture did not leave a retained partial job")
Mesher.setLive({ [liveBackground.id] = true })
Mesher.request(liveBackground, true, nil, false)
guard = 0
while Mesher.ready(liveBackground, true) == false and guard < 100 do
  pump()
  guard = guard + 1
end
expect(guard < 100 and Mesher.ready(liveBackground, true) ~= false,
       "current-live background job was blocked by return-cache work")
expect(Mesher.ready(oldBackground, true) == false,
       "return-cache background job ran before current-live work")
Mesher.invalidate(oldBackground.id)
Mesher.invalidate(liveBackground.id)

-- Current-map readiness is still urgent, but ordinary neighbours now have
-- two ranks inside the bounded 4ms visible slice: an approached seam
-- must beat another direct connection, and every direct connection must beat
-- a two-hop survey map even when the latter entered the FIFO first.
local farSurvey = {
  id = "ASYNC_FAR_SURVEY", def = map.def, tileset = map.tileset,
}
local directConnection = {
  id = "ASYNC_DIRECT_CONNECTION", def = map.def, tileset = map.tileset,
}
local approachedConnection = {
  id = "ASYNC_APPROACHED_CONNECTION", def = map.def, tileset = map.tileset,
}
Mesher.setLive({
  [farSurvey.id] = true,
  [directConnection.id] = true,
  [approachedConnection.id] = true,
})
Mesher.request(farSurvey, true, nil, false, 0)
Mesher.request(directConnection, true, nil, false, 1)
Mesher.request(approachedConnection, true, nil, false, 2)
expect(Mesher.hasPriorityWork(), "ranked visible work was not advertised")
guard = 0
while Mesher.ready(approachedConnection, true) == false and guard < 100 do
  pump()
  guard = guard + 1
end
expect(guard < 100 and Mesher.ready(approachedConnection, true) ~= false,
       "approached seam did not finish first")
expect(Mesher.ready(directConnection, true) == false
       and Mesher.ready(farSurvey, true) == false,
       "lower-ranked neighbour ran before the approached seam")
guard = 0
while Mesher.ready(directConnection, true) == false and guard < 100 do
  pump()
  guard = guard + 1
end
expect(guard < 100 and Mesher.ready(directConnection, true) ~= false,
       "direct connection did not finish after approached seam")
expect(Mesher.ready(farSurvey, true) == false,
       "two-hop survey work ran before a direct connection")
guard = 0
while Mesher.hasPriorityWork() and guard < 100 do
  pump()
  guard = guard + 1
end
expect(guard < 100, "ranked seam finishing work did not drain")
expect(not Mesher.hasPriorityWork(),
       "rank-zero survey work kept the visible-frame gate open")
Mesher.invalidate(farSurvey.id)
Mesher.invalidate(directConnection.id)
Mesher.invalidate(approachedConnection.id)

-- Two-hop survey work still drains eventually, but its dedicated 1ms hint
-- may cross at most one indivisible fake 4ms driver upload in a frame. It is
-- never allowed to consume the normal direct-seam slice while unpromoted.
local trickleMap = {
  id = "ASYNC_SURVEY_TRICKLE", def = map.def, tileset = map.tileset,
}
Mesher.setLive({ [trickleMap.id] = true })
Mesher.request(trickleMap, true, nil, false, 0)
local beforeTrickleUploads = #uploads
pumpNo = pumpNo + 1
Mesher.pump(false, false, false, false, true)
local trickleUploads = #uploads - beforeTrickleUploads
expect(Mesher.pending() > 0, "survey trickle consumed the whole cold route")
expect(trickleUploads <= 1,
       "survey trickle crossed more than one indivisible upload")
Mesher.invalidate(trickleMap.id)

-- Even with the world hidden by a fade, VASC shares the main thread with the
-- engine transition. The covered slice is deliberately 6ms: under this fake
-- driver's 4ms/page charge it may upload two pages, never the old 30ms burst.
local coveredMap = {
  id = "ASYNC_COVERED_BUDGET", def = map.def, tileset = map.tileset,
}
Mesher.request(coveredMap, true, nil, true)
local beforeCoveredUploads = #uploads
pumpNo = pumpNo + 1
Mesher.pump(true, false, false)
local coveredUploads = #uploads - beforeCoveredUploads
expect(Mesher.pending() > 0, "covered pump consumed the whole cold route")
expect(coveredUploads <= 2,
       "covered transition exceeded its 6ms upload allowance")
Mesher.invalidate(coveredMap.id)

love = runnerLove
print(("chunk mesher async upload: %d indexed vertices, %d bounded calls, max %d")
  :format(completedCapacity, completedUploads, completedMaxPage))
