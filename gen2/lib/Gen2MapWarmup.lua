-- Non-blocking current-map gate for the Gen-2 compose bridge.
--
-- ChunkMesher.get is deliberately absent: the real Gold/Silver/Crystal frame
-- must never wait for an entire cold route mesh.  A bounded pump advances the
-- urgent job; until it lands the official engine simply draws its native 2D
-- frame.  A body mesh warmed behind a door fade is accepted immediately and
-- the full apron continues cooking in the background.

local V = ...
local okDiagnostics, Diagnostics = pcall(function()
  return V and type(V.require) == "function" and V.require("Diagnostics") or nil
end)
if not okDiagnostics or type(Diagnostics) ~= "table" then Diagnostics = {} end
local Warmup = {}

local function diagnostic(event, fields)
  if type(Diagnostics.write) == "function" then
    pcall(Diagnostics.write, event, fields)
  end
end

-- Map ids are stable ROM labels, not load-generation identifiers. Gold builds
-- a fresh Map object on every warp and seamless connection, and map callbacks
-- may rewrite the shared block buffer before `map.entered`.  Keep an exact,
-- deterministic geometry receipt so the bridge can preserve a genuinely warm
-- destination while rejecting an old same-id mesh whose load-time blocks or
-- connection contract changed.
function Warmup.geometrySignature(map)
  if not (type(map) == "table" and map.id ~= nil) then return nil end
  local def = type(map.def) == "table" and map.def or {}
  local blocks = type(map.blocks) == "table" and map.blocks
    or (type(def.blocks) == "table" and def.blocks or {})
  local parts = {
    tostring(map.id), tostring(def.width or map.width or ""),
    tostring(def.height or map.height or ""),
    tostring(def.borderBlock or map.borderBlock or ""),
    tostring(def.tileset or ""), tostring(def.environment or ""),
    tostring(def.outdoor), tostring(#blocks),
  }
  for index = 1, #blocks do
    parts[#parts + 1] = tostring(blocks[index])
  end
  local connections = type(def.connections) == "table" and def.connections
    or (type(map.connections) == "table" and map.connections or {})
  for _, dir in ipairs({ "north", "south", "west", "east" }) do
    local conn = connections[dir]
    parts[#parts + 1] = dir
    parts[#parts + 1] = tostring(type(conn) == "table"
      and (conn.mapId or conn.map) or "")
    parts[#parts + 1] = tostring(type(conn) == "table" and conn.offset or "")
  end
  return table.concat(parts, "\31")
end

function Warmup.reset(state, map)
  if type(state) ~= "table" then return false end
  state.syncBuildMapId = nil
  state.syncBuildMapRef = nil
  state.syncBuildAttemptMapId = nil
  state.syncBuildAttemptMapRef = nil
  state.asyncBuildFrames = 0
  state.asyncBuildStartedAt = nil
  state.asyncBuildReadyMs = nil
  state.asyncBuildFailedMapId = nil
  state.syncBuildRetryAt = nil
  state.currentMapRef = map
  state.currentMapId = map and map.id or nil
  return true
end

local function fail(state, mapId, message)
  -- A false-cached geometry error is stable until ChunkMesher invalidates the
  -- map.  Report it on every caller frame, but count it once: otherwise a
  -- single bad custom tile inflates diagnostics at 60 failures per second and
  -- hides whether several maps actually failed.
  if state.asyncBuildFailedMapId ~= mapId then
    state.syncBuildFailures = (tonumber(state.syncBuildFailures) or 0) + 1
    state.asyncBuildFailedMapId = mapId
    diagnostic("gen2-map-warmup", {
      mapId=mapId, result="failed", reason=message,
      frames=state.asyncBuildFrames,
    })
  end
  return false, message, "failed"
end

local function peek(mesher, map, bodyOnlyRequired)
  -- Terrain is independently drawable.  Do not keep the official 2D frame on
  -- screen merely because flowers, grass cards or figures are still being
  -- analysed: those auxiliary passes can join the already playable route on
  -- a later frame.  This is the decisive cold-load path for large Johto maps.
  if type(mesher.peek) == "function" then
    -- The first admitted Gen-2 frame deliberately renders BODY only until its
    -- direct neighbours have been adapted.  A disk-cached FULL mesh is not a
    -- readiness receipt for that frame: VoxelScene will request BODY and
    -- return nil, which some hosts interpret as a failed provider and retire.
    -- Require the exact variant when the caller is still on that bootstrap
    -- rung; later frames may continue to use either drawable variant.
    local terrain
    if bodyOnlyRequired then
      terrain = mesher.peek(map, true)
    else
      terrain = mesher.peek(map, false) or mesher.peek(map, true)
    end
    if terrain then return terrain end
  end
  if type(mesher.ready) == "function" then
    if bodyOnlyRequired then return mesher.ready(map, true) end
    return mesher.ready(map, false) or mesher.ready(map, true)
  end
  return nil
end

function Warmup.advance(mesher, map, masks, state, covered, now,
                        bodyOnlyRequired)
  if not (mesher and map and map.id and state) then
    return false, "invalid Gen-2 map warmup input", "failed"
  end

  -- Never trust a sticky id-only latch.  Even the exact same object must pass
  -- the atomic mesher check again after an in-place refresh/invalidation; a
  -- fresh same-id Map must establish its own readiness generation.
  if state.syncBuildMapId == map.id and state.syncBuildMapRef == map then
    if peek(mesher, map, bodyOnlyRequired) then
      return true, nil, "ready", false
    end
    state.syncBuildMapId = nil
    state.syncBuildMapRef = nil
  end

  now = tonumber(now)
  if state.syncBuildAttemptMapId ~= map.id
      or state.syncBuildAttemptMapRef ~= map then
    state.syncBuildAttemptMapId = map.id
    state.syncBuildAttemptMapRef = map
    state.syncBuilds = (tonumber(state.syncBuilds) or 0) + 1
    state.asyncBuildFrames = 0
    state.asyncBuildStartedAt = now
    state.asyncBuildFailedMapId = nil
    state.syncBuildRetryAt = nil
    diagnostic("gen2-map-warmup", {
      mapId=map.id, result="started", covered=covered == true,
    })
  end

  local mesh = peek(mesher, map, bodyOnlyRequired)
  local pumped = false
  if not mesh then
    local known = type(mesher.lastError) == "function"
      and mesher.lastError(map.id) or nil
    if known then
      return fail(state, map.id,
        "Gen-2 voxel mesh build failed: " .. tostring(known))
    end

    -- The current-map body is the smallest honest 3D result and is exactly
    -- what VoxelScene already accepts while the apron/full mesh continues in
    -- the background.  Asking for FULL here made a cold forest spend several
    -- seconds in native fallback even though its playable body could have
    -- appeared much earlier.  Masks belong only to that later full build.
    local okRequest, requestErr = pcall(
      mesher.request, map, true, nil, true, 3)
    if not okRequest then
      return fail(state, map.id,
        "Gen-2 voxel mesh request failed: " .. tostring(requestErr))
    end
    if type(mesher.pump) == "function" then
      local okPump, pumpErr = pcall(mesher.pump, covered == true)
      if not okPump then
        return fail(state, map.id,
          "Gen-2 voxel mesh pump failed: " .. tostring(pumpErr))
      end
      pumped = true
    end
    mesh = peek(mesher, map, bodyOnlyRequired)
  end

  if not mesh then
    state.asyncBuildFrames = (tonumber(state.asyncBuildFrames) or 0) + 1
    return false, "voxel mesh building", "pending", pumped
  end

  state.syncBuildMapId = map.id
  state.syncBuildMapRef = map
  state.syncBuildRetryAt = nil
  state.asyncBuildFailedMapId = nil
  if now and state.asyncBuildStartedAt then
    state.asyncBuildReadyMs = math.max(0, (now - state.asyncBuildStartedAt) * 1000)
  end
  diagnostic("gen2-map-warmup", {
    mapId=map.id, result="ready", frames=state.asyncBuildFrames,
    milliseconds=state.asyncBuildReadyMs, pumped=pumped,
  })
  return true, nil, "ready", pumped
end

return Warmup
