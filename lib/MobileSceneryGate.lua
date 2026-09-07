-- Atomic Gen-1 phone promotion from the current BODY canvas to semantic
-- scenery, followed by the same fail-safe promotion for each admitted direct
-- neighbour. Resource preparation never changes what is presented. Only a
-- completed horizon + panorama candidate may replace the retained safe
-- canvas, and one failed draw probe stays latched until a real map object
-- change.

local V = ...
local Gate = {}

-- Thirteen total prepare attempts (initial + twelve rearms) span a cold
-- phone/context boundary at ordinary 30/60 Hz while remaining finite and
-- map-owned.  PanoramaBackdrop preserves completed CPU/GPU stages between
-- these attempts, so the budget does not imply thirteen PNG decodes.
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

local function reset(map)
  current = {
    map = map,
    coreReady = false,
    directUnion = false,
    resources = { horizon = nil, panorama = nil },
    safeCanvas = nil,
    probing = false,
    active = false,
    ringPromotion = false,
    ringPromotions = 0,
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

function Gate.noteSafeCanvas(map, canvas)
  local state = stateFor(map)
  if not state or canvas == nil then return false end
  state.safeCanvas = canvas
  return true
end

function Gate.lastSafeCanvas(map)
  return sameMap(map) and current.safeCanvas or nil
end

-- The first presented BODY canvas is already a stable transaction boundary.
-- On a phone, Horizon + Panorama must decorate that inexpensive current-map
-- view before current-map scenery and the progressive direct-neighbour ring
-- are allowed to consume the background mesh budget. Requiring directUnion
-- here was the field bug that left a black sky visible for ~20 seconds on an
-- iPhone 15 Pro Max even though the current map itself had rendered in 650 ms.
function Gate.noteCoreReady(map)
  local state = stateFor(map)
  if not state or state.safeCanvas == nil then return false end
  if state.coreReady then return true end
  state.coreReady = true
  diagnostic("checkpoint", "mobile-scenery-core-ready", {
    caller = "MobileSceneryGate.noteCoreReady",
    context = "world",
    map = map and map.id or "unknown",
  })
  return true
end

function Gate.noteDirectUnion(map)
  local state = stateFor(map)
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

-- A direct BODY has already completed off-screen and VoxelScene has prepared
-- the future semantic horizon while the previous canvas stayed active.  Close
-- the active flag without clearing either resource receipt: the next render
-- may immediately probe that one larger plan into the spare ping-pong slot.
-- The safe canvas remains untouched until finishProbe proves the candidate.
function Gate.beginRingPromotion(map)
  local state = stateFor(map)
  if not state or state.failed or state.probing or not state.active
      or state.safeCanvas == nil or not Gate.resourcesReady(map) then
    return false
  end
  state.active = false
  state.ringPromotion = true
  diagnostic("checkpoint", "mobile-scenery-ring-promotion", {
    caller = "MobileSceneryGate.beginRingPromotion",
    context = "world", map = map and map.id or "unknown",
    promotion = state.ringPromotions + 1,
  })
  return true
end

function Gate.nextResource(map)
  local state = stateFor(map)
  if not state or not (state.coreReady or state.directUnion)
      or state.failed then return nil end
  if state.resources.horizon ~= true then return "horizon" end
  if state.resources.panorama ~= true then return "panorama" end
  return nil
end

function Gate.noteResource(map, name, ready, reason)
  local state = stateFor(map)
  if not state or state.failed then return false end
  if name ~= "horizon" and name ~= "panorama" then return false end
  if not (state.coreReady or state.directUnion) then return false end
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
  return sameMap(map) and (current.coreReady or current.directUnion)
         and current.resources.horizon == true
         and current.resources.panorama == true
end

function Gate.assetWarmAllowed(map)
  return Gate.resourcesReady(map) and not current.failed
end

-- The pipeline update normally runs while VOXEL is active.  A map swap may
-- briefly put that general renderer gate down, however, while this map-owned
-- transaction still has bounded CPU/GPU preparation left.  Expose only that
-- unfinished structural work: once both resources are ready, render() owns
-- the single probe, and a promoted/failed transaction never spins here.
--
-- Do not initialise a cold gate from this predicate.  VoxelScene arms the
-- lifecycle only after the phone has actually entered its M10 path, so VOXEL
-- OFF cannot start background scenery work merely by polling this function.
function Gate.shouldDrive(map)
  if map == nil or current == nil then return false end
  if not sameMap(map) then return true end
  if current.failed or current.active or current.probing then return false end
  return not Gate.resourcesReady(map)
end

-- A cold panorama upload/mesh can answer false while iOS is crossing a
-- graphics or map-presentation boundary. That answer alone is not proof of a
-- broken asset. Permit a finite map-owned retry window, but only when the
-- resource module explicitly classified the failure as retryable. The budget
-- resets only with a real map object or a deliberate resource epoch.
function Gate.retryResource(map, name, reason, retryable)
  local state = stateFor(map)
  if not state or state.failed or name ~= "panorama"
      or retryable ~= true or not (state.coreReady or state.directUnion)
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

function Gate.finishProbe(map, canvas, reason)
  if not sameMap(map) or not current.probing then return false end
  current.probing = false
  if canvas == nil then
    return Gate.fail(map, reason or "candidate-canvas-missing")
  end
  current.safeCanvas = canvas
  current.active = true
  if current.ringPromotion then
    current.ringPromotions = current.ringPromotions + 1
  end
  current.ringPromotion = false
  diagnostic("checkpoint", "mobile-scenery-probe-promoted", {
    caller = "MobileSceneryGate.finishProbe",
    context = "world", map = map and map.id or "unknown",
  })
  return true
end

-- A promoted scenery frame is also transactional. A later GPU/draw failure
-- closes the rich lane and keeps the previously completed ping-pong canvas;
-- it must not retry every frame. Map replacement remains the retry boundary.
function Gate.fail(map, reason)
  if not sameMap(map) then return false end
  current.probing = false
  current.active = false
  current.ringPromotion = false
  current.failed = true
  current.failure = reason or "scenery-frame-failed"
  diagnostic("fallback", "mobile-scenery-frame", current.failure,
    "latched", { caller = "MobileSceneryGate.fail",
      context = "world", map = map and map.id or "unknown" })
  return false
end

-- Scenery cache invalidation is not a GPU failure. Keep the last completed
-- canvas and current-core/ring receipt, but require a fresh Horizon/Panorama
-- pair before opening another candidate. This is used for
-- settings/editor/context epochs and never clears a latched draw failure.
function Gate.restage(map, reason)
  if not sameMap(map) or current.failed then return false end
  current.resources.horizon = nil
  current.resources.panorama = nil
  current.retries.panorama = 0
  current.probing = false
  current.active = false
  current.ringPromotion = false
  diagnostic("checkpoint", "mobile-scenery-restage", {
    caller = "MobileSceneryGate.restage", context = "world",
    map = map and map.id or "unknown",
    reason = reason or "resource-invalidated",
  })
  return true
end

-- Canvas/context loss releases both Voxel3D slots. Drop every object receipt
-- before those releases so no later fallback can hand a dead Canvas to the
-- engine. The next ordinary M10 prefetch/render establishes a fresh map/core.
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
  return {
    coreReady = state.coreReady,
    directUnion = state.directUnion,
    resources = {
      horizon = state.resources.horizon,
      panorama = state.resources.panorama,
    },
    hasSafeCanvas = state.safeCanvas ~= nil,
    probing = state.probing,
    active = state.active,
    ringPromotion = state.ringPromotion,
    ringPromotions = state.ringPromotions,
    failed = state.failed,
    failure = state.failure,
    panoramaRetries = state.retries.panorama,
  }
end

return Gate
