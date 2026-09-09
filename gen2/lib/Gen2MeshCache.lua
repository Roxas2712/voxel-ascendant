-- VASC Gen-2 persistent mesh cache. This keeps VASC's own Johto mesher and
-- persists only its final GPU-ready vertex streams through engine-owned,
-- playthrough-scoped storage. Payloads are split so writes stay bounded.
local V = ...
local MeshParts = V.require("MeshParts")
local Budget = V.require("BuildBudget")
-- A9 resolves shore stairs, land terraces and cascading water on one datum.
-- A17 adds solid Ice Path rock hulls and atlas-local perimeter materials.
-- A20 includes the exact Facility and TraditionalHouse furniture templates.
-- A22 adds Kurt's full L-workbench with a sealed wooden arm silhouette.
-- A23 separates Elm's workstation; A24 builds the healing machine's recessed bed.
-- A25 separates the shared Elm/Oak terminal desk into standing and flat parts.
-- A26 separates the Center's low counter return from its isometric terminal.
-- A27 adds its upstairs apron variant and Indigo's terminal-free return.
-- A28 keeps each Center lounge seat's top emblem single across both tile ranks.
-- A29 separates nurse-counter top details from its vertical apron.
-- A30 gives the Center healing bay one upright head and a recessed bed.
-- A31 folds the blue cabinet once and separates PC screen/keyboard/stand.
-- A32 places upstairs symbol plaques against a normal-height wall backing.
-- A33 gives complete upstairs dividers one light cap and one front panel.
-- A34 limits that control face to the front, keeping its casing sides blue.
-- A35 separates the pink link unit's display from its plain horizontal lid.
-- Previous Ice Path/weather/furniture corrections are retained.
-- A44 removes exterior facade copies and retains only warp-backed rear doors.
-- A51 keeps Blackthorn's blocked lava AND painted rims flat, not extruded walls.
-- A52 models its verified inter-floor stairs and three open fall shafts.
-- A53 adds exact native Kanto city buildings and the Celadon Mansion rear door.
-- Blackthorn material pass tiles brick at native scale on stair/shaft faces.
-- Johto props replace the exact sixteen entrance boxes with shared rounded markers.
local Cache = { REVISION = "vasc-g2-mesh-a64-blackthorn-tex1-tower3-roof1-burned1-fuchsia1-johto-props1-cianwood-rocks1-olivine-rocks1-johto-planters1-viridian-hedges1-saffron-partitions1-tower-pillar1-tin-rail-base1", hits = 0, misses = 0,
  writes = 0, errors = 0, enqueues = 0, rejects = 0,
  bytesRead = 0, bytesWritten = 0, lastError = nil }
local PART_BYTES, MOD = 1024 * 1024, 2147483647
local queue = {}
-- A body can be requested more than once while the renderer swaps its
-- provisional and final map scene.  Remember completed signatures for this
-- process so the same 40+ MB stream is not serialized and written twice.
local completed = {}

local function hashAdd(h, value)
  value = tostring(value == nil and "" or value)
  for i = 1, #value do h = (h * 65599 + value:byte(i) + 1) % MOD end
  return h
end

local function signature(map, slot, masks)
  local def, h = map and map.def or {}, hashAdd(146959, Cache.REVISION)
  local values = { map and map.id or "", slot or "", def.width or "",
    def.height or "", def.tileset or "", def.borderBlock or def.border or "",
    def.environment or "", map and map.tileset and map.tileset.id or "" }
  for i = 1, #values do h = hashAdd(h, values[i]) end
  for i, value in ipairs((map and map.blocks) or def.blocks or {}) do
    h = hashAdd(hashAdd(h, i), value)
  end
  local rows = {}
  for _, m in ipairs(type(masks) == "table" and masks or {}) do
    rows[#rows + 1] = table.concat({ m[1] or 0, m[2] or 0,
      m[3] or 0, m[4] or 0 }, ",")
  end
  table.sort(rows)
  for _, row in ipairs(rows) do h = hashAdd(h, row) end
  return tostring(h)
end

local function storage()
  return V and V.mod and V.mod.storage or nil
end

local function game()
  local mod = V and V.mod
  if V and type(V.game) == "table" then return V.game end
  if mod and type(mod.game) == "table" then return mod.game end
  if mod and mod.world and type(mod.world.game) == "table" then
    return mod.world.game
  end
  return nil
end

local function call(method, key, value)
  local s = storage()
  local fn = s and s[method]
  if type(fn) ~= "function" then return nil end
  -- Current engines expose a playthrough-bound read(key) facade; the public
  -- RC QA engine still exposes read(game,key).  Prefer the legacy call when a
  -- live owner is available, then fall through to the bound facade.  Invalid
  -- argument shapes fail closed in both APIs, so this remains safe across the
  -- engine transition and makes the cache actually persistent on both.
  local activeGame = game()
  local ok, result
  if type(activeGame) == "table" then
    ok, result = pcall(fn, s, activeGame, key, value)
    if ok and result ~= nil and result ~= false then return result end
  end
  ok, result = pcall(fn, s, key, value)
  if ok and result ~= nil and result ~= false then return result end
  return nil
end

local function readBytes(key)
  local bytes = call("readBytes", key)
  if type(bytes) == "string" then return bytes end
  local value = call("read", key)
  if type(value) == "table" then return value.bytes end
  return type(value) == "string" and value or nil
end

local function writeBytes(key, bytes)
  if call("writeBytes", key, bytes) then return true end
  return call("write", key, { bytes = bytes }) and true or false
end

local function baseKey(map, slot, masks)
  return "gen2_mesh_cache/" .. Cache.REVISION .. "/"
    .. tostring(map and map.id or "map"):gsub("[^%w_.-]", "_") .. "/"
    .. tostring(slot) .. "/" .. signature(map, slot, masks)
end

local function upload(bytes, count)
  count = math.floor(tonumber(count) or 0)
  if count == 0 then return nil, true end
  if type(bytes) ~= "string" or #bytes ~= count * 24 then
    return nil, false, "invalid cached vertex payload"
  end
  local G, D = love and love.graphics, love and love.data
  if not (G and D and G.newMesh and D.newByteData) then
    return nil, false, "GPU byte upload unavailable"
  end
  local parts, sourceFirst = {}, 1
  local FORMAT = V.require("Voxel3D").FORMAT
  while sourceFirst <= count do
    local partCount = math.min(MeshParts.MAX_VERTICES,
                               count - sourceFirst + 1)
    local ok, mesh = pcall(G.newMesh, FORMAT, partCount,
                           "triangles", "static")
    if not ok or not mesh then
      MeshParts.release(parts)
      return nil, false, tostring(mesh)
    end
    local localFirst = 1
    while localFirst <= partCount do
      -- Match the cold builder's bounded upload size.  A cache hit must not
      -- reintroduce the large one-frame setVertices hitch it is meant to avoid.
      local n = math.min(4096, partCount - localFirst + 1)
      local globalFirst = sourceFirst + localFirst - 1
      local a = (globalFirst - 1) * 24 + 1
      local data = D.newByteData(bytes:sub(a, a + n * 24 - 1))
      local setOk, setErr = pcall(mesh.setVertices, mesh, data, localFirst)
      if data.release then pcall(data.release, data) end
      if not setOk then
        if mesh.release then pcall(mesh.release, mesh) end
        MeshParts.release(parts)
        return nil, false, tostring(setErr)
      end
      localFirst = localFirst + n
      if Budget and Budget.check then Budget.check() end
    end
    parts[#parts + 1] = mesh
    sourceFirst = sourceFirst + partCount
    if Budget and Budget.check then Budget.check() end
  end
  return MeshParts.wrap(parts), true
end

local function readStream(base, kind, count, parts)
  if tonumber(count) == 0 then return "" end
  local chunks = {}
  for i = 1, tonumber(parts) or 0 do
    Budget.phase("cache-read:" .. kind .. ":" .. tostring(i))
    Budget.check()
    local bytes = readBytes(base .. "/" .. kind .. "/" .. i)
    if type(bytes) ~= "string" then return nil end
    chunks[i] = bytes
    Budget.check()
  end
  Budget.phase("cache-join:" .. kind)
  Budget.check()
  return table.concat(chunks)
end

function Cache.available()
  local options = V and V.mod and V.mod.options
  if options and type(options.get) == "function" then
    local ok, enabled = pcall(options.get, options, "voxelDiskCache")
    if ok and (enabled == false or enabled == 0 or enabled == "off") then return false end
  end
  local s = storage()
  return s ~= nil and (type(s.read) == "function" or type(s.readBytes) == "function")
end

function Cache.load(map, slot, masks)
  if not Cache.available() then return nil end
  local base = baseKey(map, slot, masks)
  Budget.phase("cache-meta")
  local meta = call("read", base .. "/meta")
  if type(meta) ~= "table" or meta.revision ~= Cache.REVISION
      or meta.signature ~= signature(map, slot, masks) then
    Cache.misses = Cache.misses + 1; return nil
  end
  local terrain = readStream(base, "terrain", meta.terrainCount, meta.terrainParts)
  local water = readStream(base, "water", meta.waterCount, meta.waterParts)
  if terrain == nil or water == nil then Cache.misses = Cache.misses + 1; return nil end
  Budget.phase("cache-upload:terrain")
  local mesh, ok, err = upload(terrain, meta.terrainCount)
  if not ok then Cache.errors = Cache.errors + 1; Cache.lastError = err; return nil end
  Budget.phase("cache-upload:water")
  local waterMesh, wok, werr = upload(water, meta.waterCount)
  if not wok then
    if mesh and mesh.release then pcall(mesh.release, mesh) end
    Cache.errors = Cache.errors + 1; Cache.lastError = werr; return nil
  end
  Cache.hits, Cache.bytesRead, Cache.lastError = Cache.hits + 1,
    Cache.bytesRead + #terrain + #water, nil
  completed[base] = true
  return mesh, waterMesh
end

local function partsFor(bytes) return #bytes == 0 and 0 or math.ceil(#bytes / PART_BYTES) end

function Cache.enqueue(map, slot, masks, terrainBytes, terrainCount, waterBytes, waterCount)
  Cache.enqueues = Cache.enqueues + 1
  if not Cache.available() or type(terrainBytes) ~= "string" then
    Cache.rejects = Cache.rejects + 1
    Cache.lastError = not Cache.available() and "storage unavailable"
      or "packed vertex stream unavailable"
    return false
  end
  local base = baseKey(map, slot, masks)
  if completed[base] then return true end
  for _, job in ipairs(queue) do if job.base == base then return true end end
  waterBytes = type(waterBytes) == "string" and waterBytes or ""
  queue[#queue + 1] = { base = base, signature = signature(map, slot, masks),
    stage = "terrain", part = 1, terrain = terrainBytes,
    terrainCount = terrainCount or 0, water = waterBytes,
    waterCount = waterCount or 0, terrainParts = partsFor(terrainBytes),
    waterParts = partsFor(waterBytes) }
  while #queue > 3 do table.remove(queue, 1) end
  return true
end

local function tableSource(verts, indices)
  return {
    verts = type(verts) == "table" and verts or {},
    indices = type(indices) == "table" and indices or {},
    at = 1, buffered = 0, buffer = {}, chunks = {},
  }
end

function Cache.enqueueTable(map, slot, masks, terrainVerts, terrainIndices,
    waterVerts, waterIndices)
  Cache.enqueues = Cache.enqueues + 1
  if not Cache.available() then
    Cache.rejects = Cache.rejects + 1
    Cache.lastError = "storage unavailable"
    return false
  end
  if not (love and love.data and type(love.data.pack) == "function") then
    Cache.rejects = Cache.rejects + 1
    Cache.lastError = "portable float packer unavailable"
    return false
  end
  local base = baseKey(map, slot, masks)
  if completed[base] then return true end
  for _, queued in ipairs(queue) do
    if queued.base == base then return true end
  end
  queue[#queue + 1] = {
    base = base, signature = signature(map, slot, masks),
    stage = "encode_terrain", part = 1,
    terrainSource = tableSource(terrainVerts, terrainIndices),
    waterSource = tableSource(waterVerts, waterIndices),
    terrainCount = #(terrainIndices or {}),
    waterCount = #(waterIndices or {}),
  }
  -- Only the urgent current-map BODY enters this portable path. Keeping two
  -- slots allows a warp to supersede an unfinished previous map without
  -- retaining an entire journey's Lua vertex tables.
  while #queue > 2 do table.remove(queue, 1) end
  return true
end

function Cache.noteFailure(reason)
  Cache.errors = Cache.errors + 1
  Cache.lastError = tostring(reason or "unknown cache failure")
end

local function writePart(job, kind)
  local chunks = job[kind .. "Chunks"]
  local bytes, total = job[kind], job[kind .. "Parts"]
  if job.part > total then return true end
  local chunk
  if type(chunks) == "table" then
    chunk = chunks[job.part]
  else
    local a = (job.part - 1) * PART_BYTES + 1
    chunk = bytes:sub(a, math.min(#bytes, a + PART_BYTES - 1))
  end
  if not writeBytes(job.base .. "/" .. kind .. "/" .. job.part, chunk) then
    Cache.errors, Cache.lastError = Cache.errors + 1, "scoped cache write failed"
    return nil
  end
  Cache.bytesWritten, job.part = Cache.bytesWritten + #chunk, job.part + 1
  return job.part > total
end

local function flushPortable(source)
  if #source.buffer == 0 then return end
  source.chunks[#source.chunks + 1] = table.concat(source.buffer)
  source.buffer, source.buffered = {}, 0
end

local function encodePortable(job, kind, limit)
  local source = job[kind .. "Source"]
  if type(source) ~= "table" then return true end
  local stop = math.min(#source.indices, source.at + math.max(1, limit) - 1)
  while source.at <= stop do
    local vertex = source.verts[source.indices[source.at]]
    if type(vertex) ~= "table" then
      Cache.errors, Cache.lastError = Cache.errors + 1,
        "portable cache vertex missing"
      return nil
    end
    local ok, bytes = pcall(love.data.pack, "string", "<ffffff",
      tonumber(vertex[1]) or 0, tonumber(vertex[2]) or 0,
      tonumber(vertex[3]) or 0, tonumber(vertex[4]) or 0,
      tonumber(vertex[5]) or 0, tonumber(vertex[6]) or 0)
    if not ok or type(bytes) ~= "string" then
      Cache.errors, Cache.lastError = Cache.errors + 1,
        "portable float pack failed: " .. tostring(bytes)
      return nil
    end
    source.buffer[#source.buffer + 1] = bytes
    source.buffered = source.buffered + #bytes
    source.at = source.at + 1
    if source.buffered >= PART_BYTES then flushPortable(source) end
  end
  if source.at > #source.indices then
    flushPortable(source)
    job[kind .. "Chunks"] = source.chunks
    job[kind .. "Parts"] = #source.chunks
    job[kind .. "Source"] = nil
    return true
  end
  return false
end

function Cache.pump(covered)
  local budget = covered and 4 or 1
  while budget > 0 and queue[1] do
    local job, done = queue[1]
    if job.stage == "encode_terrain" then
      done = encodePortable(job, "terrain", covered and 4096 or 512)
    elseif job.stage == "encode_water" then
      done = encodePortable(job, "water", covered and 4096 or 512)
    else
      done = writePart(job, job.stage)
    end
    if done == nil then table.remove(queue, 1)
    elseif done and job.stage == "encode_terrain" then
      job.stage = "encode_water"
    elseif done and job.stage == "encode_water" then
      job.stage, job.part = "terrain", 1
    elseif done and job.stage == "terrain" then job.stage, job.part = "water", 1
    elseif done then
      local meta = { revision = Cache.REVISION, signature = job.signature,
        terrainCount = job.terrainCount, waterCount = job.waterCount,
        terrainParts = job.terrainParts, waterParts = job.waterParts }
      if call("write", job.base .. "/meta", meta) then
        Cache.writes = Cache.writes + 1
        completed[job.base] = true
      else Cache.errors, Cache.lastError = Cache.errors + 1, "cache metadata write failed" end
      table.remove(queue, 1)
    end
    budget = budget - 1
  end
end

function Cache.status()
  return { enabled = Cache.available(), revision = Cache.REVISION,
    hits = Cache.hits, misses = Cache.misses, writes = Cache.writes,
    errors = Cache.errors, enqueues = Cache.enqueues, rejects = Cache.rejects,
    queued = #queue, bytesRead = Cache.bytesRead,
    bytesWritten = Cache.bytesWritten, lastError = Cache.lastError }
end
return Cache
