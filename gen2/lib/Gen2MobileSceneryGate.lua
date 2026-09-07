-- Atomic Gen-2 phone promotion from the proven direct-union canvas to the
-- first semantic scenery frame. Resource preparation never changes what is
-- presented. Only a completed horizon + panorama candidate may replace the
-- retained safe canvas, and a failed probe stays latched until a real map
-- object change.

local V = ...
local Gate = {}

-- Match the proven Gen-1 phone lane: a cold graphics context may reject an
-- upload for several frames even though the decoded asset is valid.  The
-- retries remain finite, map-owned and are consumed only for failures the
-- resource explicitly marks retryable.
Gate.MAX_PANORAMA_REARMS = 12

local current = nil

local function diagnostic(name, ...)
  local d = V and V.mod and V.mod._vascMobileDiagnostic
  local fn = d and d[name]
  if type(fn) == "function" then pcall(fn, ...) end
end

local function sameMap(map)
  return current ~= nil and current.map == map
end

local function positiveDimensions(w, h)
  w, h = tonumber(w), tonumber(h)
  if not (w and h and w > 0 and h > 0) then return nil, nil end
  return math.floor(w + 0.5), math.floor(h + 0.5)
end

local function canvasDimensions(canvas)
  if canvas == nil then return nil, nil end
  local ok, w, h = pcall(function()
    if type(canvas.getDimensions) ~= "function" then return nil, nil end
    return canvas:getDimensions()
  end)
  if not ok then return nil, nil end
  return positiveDimensions(w, h)
end

local function drawableDimensions()
  local graphics = love and love.graphics
  if not (graphics and type(graphics.getDimensions) == "function") then
    return nil, nil
  end
  local ok, w, h = pcall(graphics.getDimensions)
  if not ok then return nil, nil end
  return positiveDimensions(w, h)
end

-- A phone rotation may keep the same Map object while replacing the drawable.
-- Never hand the old portrait Canvas to the new landscape frame.  Dimension-
-- less test/legacy canvases remain eligible because there is no trustworthy
-- receipt to compare; every real LÖVE Canvas reports its logical dimensions.
local function discardStaleSafeCanvas(state, expectedW, expectedH)
  if not (state and state.safeCanvas) then return false end
  expectedW, expectedH = positiveDimensions(expectedW, expectedH)
  if not expectedW then expectedW, expectedH = drawableDimensions() end
  local safeW, safeH = positiveDimensions(state.safeWidth, state.safeHeight)
  if not safeW then safeW, safeH = canvasDimensions(state.safeCanvas) end
  if not (expectedW and safeW)
      or (expectedW == safeW and expectedH == safeH) then
    return false
  end
  state.safeCanvas = nil
  state.safeWidth, state.safeHeight = nil, nil
  diagnostic("checkpoint", "mobile-scenery-safe-canvas-invalidated", {
    caller = "MobileSceneryGate.discardStaleSafeCanvas",
    context = "world", map = state.map and state.map.id or "unknown",
    reason = "drawable-dimensions-changed",
    fromWidth = safeW, fromHeight = safeH,
    toWidth = expectedW, toHeight = expectedH,
  })
  return true
end

local function reset(map)
  current = {
    map = map,
    directUnion = false,
    resources = { horizon = nil, panorama = nil },
    safeCanvas = nil,
    safeWidth = nil,
    safeHeight = nil,
    probing = false,
    active = false,
    failed = false,
    failure = nil,
    retries = { panorama = 0 },
  }
  diagnostic("checkpoint", "mobile-scenery-map-enter", {
    caller = "MobileSceneryGate.enterMap",
    context = "world",
    map = map and map.id or "unknown",
  })
end

function Gate.enterMap(map)
  if map == nil then return false end
  if not sameMap(map) then reset(map) end
  return true
end

local function stateFor(map)
  if not Gate.enterMap(map) then return nil end
  return current
end

function Gate.noteSafeCanvas(map, canvas, width, height)
  local state = stateFor(map)
  if not state or canvas == nil then return false end
  state.safeCanvas = canvas
  state.safeWidth, state.safeHeight = positiveDimensions(width, height)
  if not state.safeWidth then
    state.safeWidth, state.safeHeight = canvasDimensions(canvas)
  end
  return true
end

function Gate.lastSafeCanvas(map, width, height)
  if not sameMap(map) then return nil end
  discardStaleSafeCanvas(current, width, height)
  return current.safeCanvas
end

function Gate.noteDirectUnion(map, width, height)
  local state = stateFor(map)
  discardStaleSafeCanvas(state, width, height)
  if not state or state.safeCanvas == nil then return false end
  if state.directUnion then return true end
  state.directUnion = true
  diagnostic("checkpoint", "mobile-scenery-direct-union", {
    caller = "MobileSceneryGate.noteDirectUnion",
    context = "world",
    map = map and map.id or "unknown",
  })
  return true
end

function Gate.nextResource(map)
  local state = stateFor(map)
  if not state or not state.directUnion or state.failed then return nil end
  if state.resources.horizon ~= true then return "horizon" end
  if state.resources.panorama ~= true then return "panorama" end
  return nil
end

function Gate.noteResource(map, name, ready, reason)
  local state = stateFor(map)
  if not state or state.failed then return false end
  if name ~= "horizon" and name ~= "panorama" then return false end
  if not state.directUnion then return false end
  if name == "panorama" and state.resources.horizon ~= true then return false end
  if ready ~= true then
    diagnostic("fallback", "mobile-scenery-resource", reason or name,
      "pending", { caller = "MobileSceneryGate.noteResource",
        context = "world", resource = name,
        map = map and map.id or "unknown" })
    return false
  end
  state.resources[name] = true
  diagnostic("checkpoint", "mobile-scenery-" .. name .. "-ready", {
    caller = "MobileSceneryGate.noteResource",
    context = "world", resource = name,
    map = map and map.id or "unknown",
  })
  return true
end

function Gate.resourcesReady(map)
  return sameMap(map) and current.directUnion
         and current.resources.horizon == true
         and current.resources.panorama == true
end

function Gate.assetWarmAllowed(map)
  return Gate.resourcesReady(map) and not current.failed
end

function Gate.shouldDrive(map)
  if map == nil or current == nil then return false end
  if not sameMap(map) then return true end
  if current.failed or current.active or current.probing then return false end
  return not Gate.resourcesReady(map)
end

function Gate.retryResource(map, name, reason, retryable)
  local state = stateFor(map)
  if not state or state.failed or name ~= "panorama"
      or retryable ~= true or not state.directUnion
      or state.resources.horizon ~= true then
    return false
  end
  local used = tonumber(state.retries.panorama) or 0
  if used >= Gate.MAX_PANORAMA_REARMS then return false end
  state.retries.panorama = used + 1
  diagnostic("checkpoint", "mobile-scenery-resource-rearm", {
    caller = "MobileSceneryGate.retryResource",
    context = "world", resource = name,
    map = map and map.id or "unknown",
    reason = reason or "cold-prepare",
    attempt = state.retries.panorama,
  })
  return true
end

function Gate.beginProbe(map)
  local state = stateFor(map)
  if not state or state.failed or state.probing or state.active
      or not Gate.resourcesReady(map) then return false end
  state.probing = true
  diagnostic("checkpoint", "mobile-scenery-probe-start", {
    caller = "MobileSceneryGate.beginProbe",
    context = "world", map = map and map.id or "unknown",
  })
  return true
end

function Gate.allow(map)
  return sameMap(map) and (current.probing or current.active) == true
end

function Gate.finishProbe(map, canvas, reason, width, height)
  if not sameMap(map) or not current.probing then return false end
  current.probing = false
  if canvas == nil then
    return Gate.fail(map, reason or "candidate-canvas-missing")
  end
  current.safeCanvas = canvas
  current.safeWidth, current.safeHeight = positiveDimensions(width, height)
  if not current.safeWidth then
    current.safeWidth, current.safeHeight = canvasDimensions(canvas)
  end
  current.active = true
  diagnostic("checkpoint", "mobile-scenery-probe-promoted", {
    caller = "MobileSceneryGate.finishProbe",
    context = "world", map = map and map.id or "unknown",
  })
  return true
end

function Gate.fail(map, reason)
  if not sameMap(map) then return false end
  current.probing = false
  current.active = false
  current.failed = true
  current.failure = reason or "scenery-frame-failed"
  diagnostic("fallback", "mobile-scenery-frame", current.failure,
    "latched", { caller = "MobileSceneryGate.fail",
      context = "world", map = map and map.id or "unknown" })
  return false
end

function Gate.restage(map, reason)
  if not sameMap(map) or current.failed then return false end
  current.resources.horizon = nil
  current.resources.panorama = nil
  current.retries.panorama = 0
  current.probing = false
  current.active = false
  diagnostic("checkpoint", "mobile-scenery-restage", {
    caller = "MobileSceneryGate.restage", context = "world",
    map = map and map.id or "unknown",
    reason = reason or "resource-invalidated",
  })
  return true
end

function Gate.invalidate(reason)
  if current then
    diagnostic("checkpoint", "mobile-scenery-invalidated", {
      caller = "MobileSceneryGate.invalidate", context = "world",
      map = current.map and current.map.id or "unknown",
      reason = reason or "graphics-context",
    })
  end
  current = nil
  return true
end

function Gate.status(map)
  local state = stateFor(map)
  discardStaleSafeCanvas(state)
  return {
    directUnion = state.directUnion,
    resources = {
      horizon = state.resources.horizon,
      panorama = state.resources.panorama,
    },
    hasSafeCanvas = state.safeCanvas ~= nil,
    safeWidth = state.safeWidth,
    safeHeight = state.safeHeight,
    probing = state.probing,
    active = state.active,
    failed = state.failed,
    failure = state.failure,
    panoramaRetries = state.retries.panorama,
  }
end

return Gate
