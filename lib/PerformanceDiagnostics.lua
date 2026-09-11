-- Cross-device, read-only VASC performance telemetry.
--
-- The sampler is deliberately presentation-neutral: it observes the existing
-- render.hud boundary and never changes a device profile, renderer option,
-- canvas or game state.  The hidden maintainer page can therefore use the
-- same measurements on desktop and mobile without putting the proven PC
-- presentation behind a new adaptive path.

local V = ...
local PerformanceDiagnostics = {
  SCHEMA = "vasc-performance-diagnostics/v1",
  API_VERSION = 1,
  SAMPLE_CAPACITY = 180,
  installed = false,
  samples = {},
  sampleCursor = 0,
  sampleCount = 0,
  framesObserved = 0,
  lastError = nil,
  secondsSinceLog = 0,
  LOG_INTERVAL_SECONDS = 10,
  startedAt = nil,
  pendingLoads = {},
  latestLoads = {},
  milestones = {},
  lastMilestoneResource = nil,
  phaseSequence = 0,
  findings = {},
  recentSignals = {},
  hud = {},
  battleProvider = {},
  viewport = {},
  weather = {},
  -- Gen 1 mobile presents the current BODY first and then admits its direct
  -- neighbours one by one. This is intentionally a different contract from
  -- the legacy/Gen-2 atomic direct-union receipt. Keep the live root bounded
  -- to one map so a long playthrough cannot turn diagnostics into a cache.
  sceneryRing = {},
  memoryBaseline = nil,
  lastStallAt = -math.huge,
  lastHudLogAt = -math.huge,
  lastHudSignature = nil,
  lastWeatherLogAt = -math.huge,
  lastWeatherSignature = nil,
}

local MiB = 1024 * 1024
local unpackValues = table.unpack or unpack
local hostGeneration

local function call(owner, name, ...)
  local fn = type(owner) == "table" and owner[name] or nil
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d = pcall(fn, ...)
  if not ok then ok, a, b, c, d = pcall(fn, owner, ...) end
  if ok then return a, b, c, d end
  return nil
end

local function runtime()
  local value = rawget(_G, "love")
  return type(value) == "table" and value or {}
end

local function now()
  local value = call(runtime().timer, "getTime")
  return tonumber(value) or 0
end

local function compact(value, limit)
  value = tostring(value == nil and "" or value):gsub("[\r\n\t]", " ")
  limit = tonumber(limit) or 96
  return #value > limit and value:sub(1, limit) or value
end

local function resourceSample()
  local L = runtime()
  local stats = call(L.graphics, "getStats")
  if type(stats) ~= "table" then stats = {} end
  local luaMb
  if type(collectgarbage) == "function" then
    local ok, kb = pcall(collectgarbage, "count")
    if ok and tonumber(kb) then luaMb = tonumber(kb) / 1024 end
  end
  local textureMb = tonumber(stats.texturememory)
  if textureMb then textureMb = textureMb / MiB end
  return {
    at=now(), luaMemoryMb=luaMb, textureMemoryMb=textureMb,
    canvases=tonumber(stats.canvases), images=tonumber(stats.images),
    drawcalls=tonumber(stats.drawcalls),
  }
end

local function resourceDelta(before, after)
  local function difference(key)
    local a, b = before and tonumber(before[key]), after and tonumber(after[key])
    return a and b and b - a or nil
  end
  return {
    luaMemoryMb=difference("luaMemoryMb"),
    textureMemoryMb=difference("textureMemoryMb"),
    canvases=difference("canvases"), images=difference("images"),
    drawcalls=difference("drawcalls"),
  }
end

local function statusRank(value)
  return ({ info=0, good=0, warn=1, bad=2 })[value] or 0
end

local function addFinding(code, message, tone, fields)
  local stamp = now()
  code = compact(code, 48)
  -- A persistent fault must not flood the bounded ring on every snapshot.
  -- Refresh the existing receipt instead, so the newest occurrence stays
  -- visible while unrelated correlated findings remain available.
  for index, existing in ipairs(PerformanceDiagnostics.findings) do
    if existing.code == code and stamp - existing.at < 30 then
      existing.at = stamp
      existing.message = compact(message, 128)
      existing.tone = tone or existing.tone
      existing.fields = type(fields) == "table" and fields or existing.fields
      if index > 1 then
        table.remove(PerformanceDiagnostics.findings, index)
        table.insert(PerformanceDiagnostics.findings, 1, existing)
      end
      return existing
    end
  end
  local finding = {
    code=code, message=compact(message, 128), tone=tone or "warn",
    at=stamp, fields=type(fields) == "table" and fields or {},
  }
  table.insert(PerformanceDiagnostics.findings, 1, finding)
  while #PerformanceDiagnostics.findings > 8 do
    table.remove(PerformanceDiagnostics.findings)
  end
  local diagnostics = PerformanceDiagnostics.diagnostics
  if diagnostics and type(diagnostics.write) == "function" then
    pcall(diagnostics.write, "vasc.performance.finding", {
      status=finding.tone, kind=finding.code, reason=finding.message,
      elapsed=finding.fields.elapsed, mapId=finding.fields.mapId,
      sceneId=finding.fields.sceneId, source=finding.fields.source,
    })
  end
  return finding
end

local LOAD_LIMITS = {
  startup={ warn=3000, bad=8000 }, save={ warn=2000, bad=5000 },
  map={ warn=1500, bad=4000 }, battle={ warn=1500, bad=4000 },
  weather={ warn=800, bad=2500 },
  world={ warn=5000, bad=15000 },
}

local function loadTone(kind, elapsedMs)
  local limits = LOAD_LIMITS[kind] or { warn=1500, bad=4000 }
  return elapsedMs >= limits.bad and "bad"
    or elapsedMs >= limits.warn and "warn" or "good"
end

function PerformanceDiagnostics.beginLoad(kind, context)
  kind = tostring(kind or "other"):lower()
  PerformanceDiagnostics.phaseSequence =
    PerformanceDiagnostics.phaseSequence + 1
  PerformanceDiagnostics.pendingLoads[kind] = {
    at=now(), context=type(context) == "table" and context or {},
    reportedBad=false, resourceBefore=resourceSample(),
    phaseSequence=PerformanceDiagnostics.phaseSequence,
  }
  local diagnostics = PerformanceDiagnostics.diagnostics
  if diagnostics and type(diagnostics.write) == "function" then
    local pending = PerformanceDiagnostics.pendingLoads[kind]
    local resource = pending.resourceBefore
    pcall(diagnostics.write, "vasc.performance.load-phase", {
      kind=kind, phase="begin", phaseSequence=pending.phaseSequence,
      mapId=pending.context.mapId, sceneId=pending.context.sceneId,
      source=pending.context.source, luaMemoryMb=resource.luaMemoryMb,
      textureMemoryMb=resource.textureMemoryMb, canvases=resource.canvases,
      images=resource.images, drawcalls=resource.drawcalls,
    })
  end
  return true
end

function PerformanceDiagnostics.endLoad(kind, context)
  kind = tostring(kind or "other"):lower()
  context = type(context) == "table" and context or {}
  local pending = PerformanceDiagnostics.pendingLoads[kind]
  local suppliedMs = tonumber(context.elapsedMs or context.milliseconds
    or context.elapsed)
  if not pending and suppliedMs and suppliedMs >= 0 then
    pending = { at=now() - suppliedMs / 1000, context=context }
  end
  if not pending then return nil, "load-not-started" end
  PerformanceDiagnostics.pendingLoads[kind] = nil
  local elapsedMs = math.max(0, suppliedMs or (now() - pending.at) * 1000)
  local result = tostring(context.result or context.status or "ready"):lower()
  local failed = result == "failed" or result == "failure"
    or result == "error" or result == "fallback" or result == "missing"
  local tone = result == "unobserved" and "warn" or (failed and "bad" or loadTone(kind, elapsedMs))
  local resourceAfter = resourceSample()
  local delta = resourceDelta(pending.resourceBefore, resourceAfter)
  local receipt = {
    kind=kind, elapsedMs=elapsedMs, tone=tone, at=now(),
    mapId=context.mapId or pending.context.mapId,
    sceneId=context.sceneId or pending.context.sceneId,
    source=context.source or pending.context.source,
    result=result,
    phaseSequence=pending.phaseSequence,
    resourceBefore=pending.resourceBefore, resourceAfter=resourceAfter,
    resourceDelta=delta,
  }
  PerformanceDiagnostics.latestLoads[kind] = receipt
  if tone ~= "good" and result ~= "unobserved" then
    addFinding((failed and "LOAD-FAILED-" or "SLOW-") .. kind:upper(),
      kind:upper() .. " " .. (failed and "FEHLGESCHLAGEN " or "")
        .. string.format("%.0f MS", elapsedMs), tone, {
        elapsed=elapsedMs, mapId=receipt.mapId, sceneId=receipt.sceneId,
        source=receipt.source,
      })
  end
  local resourceSpike = delta.textureMemoryMb and delta.textureMemoryMb >= 64
    or delta.luaMemoryMb and delta.luaMemoryMb >= 64
    or delta.canvases and delta.canvases >= 8
  if resourceSpike then
    addFinding("LOAD+RESOURCE-" .. kind:upper(),
      kind:upper() .. " + RESSOURCENSPRUNG", "warn", {
        elapsed=elapsedMs, mapId=receipt.mapId, sceneId=receipt.sceneId,
        source=receipt.source,
      })
  end
  local diagnostics = PerformanceDiagnostics.diagnostics
  if diagnostics and type(diagnostics.write) == "function" then
    pcall(diagnostics.write, "vasc.performance.load", {
      kind=kind, elapsed=elapsedMs, status=tone, result=receipt.result,
      mapId=receipt.mapId, sceneId=receipt.sceneId, source=receipt.source,
      phase="end", phaseSequence=receipt.phaseSequence,
      luaMemoryMb=resourceAfter.luaMemoryMb,
      textureMemoryMb=resourceAfter.textureMemoryMb,
      canvases=resourceAfter.canvases, images=resourceAfter.images,
      drawcalls=resourceAfter.drawcalls,
      luaMemoryDeltaMb=delta.luaMemoryMb,
      textureMemoryDeltaMb=delta.textureMemoryMb,
      canvasDelta=delta.canvases, imageDelta=delta.images,
      drawcallDelta=delta.drawcalls,
    })
  end
  return receipt
end

function PerformanceDiagnostics.markPhase(phase, context)
  phase = compact(tostring(phase or "checkpoint"):lower(), 48)
  context = type(context) == "table" and context or {}
  local resource = resourceSample()
  local delta = resourceDelta(PerformanceDiagnostics.lastMilestoneResource,
    resource)
  PerformanceDiagnostics.lastMilestoneResource = resource
  PerformanceDiagnostics.phaseSequence =
    PerformanceDiagnostics.phaseSequence + 1
  local receipt = {
    phase=phase, phaseSequence=PerformanceDiagnostics.phaseSequence,
    at=resource.at, elapsedMs=PerformanceDiagnostics.startedAt
      and math.max(0, (resource.at - PerformanceDiagnostics.startedAt) * 1000)
      or nil,
    mapId=context.mapId, sceneId=context.sceneId, source=context.source,
    resource=resource, resourceDelta=delta,
  }
  PerformanceDiagnostics.milestones[phase] = receipt
  local diagnostics = PerformanceDiagnostics.diagnostics
  if diagnostics and type(diagnostics.write) == "function" then
    pcall(diagnostics.write, "vasc.performance.phase", {
      phase=phase, phaseSequence=receipt.phaseSequence,
      elapsed=receipt.elapsedMs, mapId=receipt.mapId, sceneId=receipt.sceneId,
      source=receipt.source, luaMemoryMb=resource.luaMemoryMb,
      textureMemoryMb=resource.textureMemoryMb, canvases=resource.canvases,
      images=resource.images, drawcalls=resource.drawcalls,
      luaMemoryDeltaMb=delta.luaMemoryMb,
      textureMemoryDeltaMb=delta.textureMemoryMb,
      canvasDelta=delta.canvases, imageDelta=delta.images,
      drawcallDelta=delta.drawcalls,
    })
  end
  return receipt
end

local function rememberSignal(kind, event, fields, tone)
  table.insert(PerformanceDiagnostics.recentSignals, 1, {
    kind=kind, event=event, fields=fields or {}, tone=tone or "info", at=now(),
  })
  while #PerformanceDiagnostics.recentSignals > 24 do
    table.remove(PerformanceDiagnostics.recentSignals)
  end
end

local function recentLoad(seconds)
  local newest
  for _, receipt in pairs(PerformanceDiagnostics.latestLoads) do
    if now() - receipt.at <= (seconds or 20)
        and (not newest or receipt.at > newest.at) then newest = receipt end
  end
  return newest
end

local function mapField(fields, fallback)
  fields = type(fields) == "table" and fields or {}
  local value = fields.mapId or fields.map or fields.rootMapId or fallback
  if value == nil or tostring(value) == "" then return nil end
  return compact(value, 96)
end

local function tableCount(value)
  local count = 0
  for _ in pairs(type(value) == "table" and value or {}) do count = count + 1 end
  return count
end

local function writeSceneryRing(action, state, receipt)
  local diagnostics = PerformanceDiagnostics.diagnostics
  if not (diagnostics and type(diagnostics.write) == "function") then return end
  receipt = type(receipt) == "table" and receipt or {}
  local delta = receipt.resourceDelta or {}
  pcall(diagnostics.write, "vasc.performance.scenery-ring", {
    action=action, status=receipt.status or "ready",
    mapId=state and state.mapId, neighbor=receipt.neighbor,
    elapsed=receipt.elapsedMs,
    coreToFirstVisibleMs=state and state.coreToFirstVisibleMs,
    sceneToFirstVisibleMs=state and state.sceneToFirstVisibleMs,
    admitted=state and tableCount(state.admitted),
    visible=state and tableCount(state.visible),
    expectedDirect=state and state.expectedDirect,
    failures=state and tableCount(state.failures),
    luaMemoryDeltaMb=delta.luaMemoryMb,
    textureMemoryDeltaMb=delta.textureMemoryMb,
    canvasDelta=delta.canvases, imageDelta=delta.images,
    drawcallDelta=delta.drawcalls,
    source=receipt.source,
  })
end

local function sceneryState(mapId, source)
  local current = PerformanceDiagnostics.sceneryRing
  if type(current) ~= "table" or not current.mapId
      or mapId and current.mapId ~= mapId then
    current = {
      mapId=mapId or "unknown", source=source, startedAt=nil,
      admitted={}, visible={}, failures={}, admissionOrder={}, visibleOrder={},
      at=now(),
    }
    PerformanceDiagnostics.sceneryRing = current
  end
  return current
end

local function beginSceneryCore(mapId, source)
  local current = PerformanceDiagnostics.sceneryRing
  if type(current) == "table" and current.mapId == mapId
      and current.startedAt then return current end
  current = {
    mapId=mapId or "unknown", source=source, startedAt=now(),
    resourceBefore=resourceSample(), admitted={}, visible={}, failures={},
    admissionOrder={}, visibleOrder={}, at=now(),
  }
  PerformanceDiagnostics.sceneryRing = current
  if PerformanceDiagnostics.pendingLoads.world then
    -- A newer map owns the mobile world transaction. A superseded source map
    -- must not remain a fictional timeout after a warp.
    PerformanceDiagnostics.pendingLoads.world = nil
  end
  PerformanceDiagnostics.beginLoad("world", {
    mapId=current.mapId, source=source,
  })
  writeSceneryRing("core-started", current, { source=source })
  return current
end

local function noteSceneryFirstVisible(mapId, source)
  local state = sceneryState(mapId, source)
  if state.firstVisibleAt then return state end
  local stamp = now()
  state.firstVisibleAt = stamp
  state.coreToFirstVisibleMs = state.startedAt
    and math.max(0, (stamp - state.startedAt) * 1000) or nil
  state.sceneToFirstVisibleMs = state.sceneReadyAt
    and math.max(0, (stamp - state.sceneReadyAt) * 1000) or nil
  state.firstVisibleResource = resourceSample()
  state.firstVisibleResourceDelta = resourceDelta(
    state.resourceBefore, state.firstVisibleResource)
  if PerformanceDiagnostics.pendingLoads.world then
    PerformanceDiagnostics.endLoad("world", {
      status="ready", mapId=state.mapId, source=source,
      elapsedMs=state.coreToFirstVisibleMs,
    })
  end
  writeSceneryRing("first-visible", state, {
    elapsedMs=state.coreToFirstVisibleMs,
    resourceDelta=state.firstVisibleResourceDelta,
    source=source,
  })
  return state
end

local function checkpointNeighbor(rawCheckpoint, fields, marker)
  local lower = tostring(rawCheckpoint or ""):lower()
  local at = lower:find(marker, 1, true)
  if not at then return nil end
  if type(fields) == "table" and fields.neighbor ~= nil then
    return compact(fields.neighbor, 96)
  end
  local value = tostring(rawCheckpoint):sub(at + #marker)
  value = value:gsub("^%-+", "")
  return value ~= "" and compact(value, 96) or nil
end

local function noteSceneryAdmission(state, neighbor, source)
  if not neighbor or state.admitted[neighbor] then return end
  local receipt = {
    neighbor=neighbor, at=now(), source=source,
    resourceBefore=resourceSample(), frameAt=PerformanceDiagnostics.framesObserved,
  }
  state.admitted[neighbor] = receipt
  state.admissionOrder[#state.admissionOrder + 1] = neighbor
  state.lastProgressAt = receipt.at
  writeSceneryRing("direct-admitted", state, receipt)
end

local function noteSceneryVisible(state, neighbor, source)
  if not neighbor or state.visible[neighbor] then return end
  local admission = state.admitted[neighbor]
  if not admission then
    admission = { neighbor=neighbor, at=now(), source="inferred-admission",
      resourceBefore=resourceSample(), inferred=true }
    state.admitted[neighbor] = admission
    state.admissionOrder[#state.admissionOrder + 1] = neighbor
  end
  local stamp = now()
  local resource = resourceSample()
  local receipt = {
    neighbor=neighbor, at=stamp, source=source,
    elapsedMs=math.max(0, (stamp - admission.at) * 1000),
    resource=resource,
    resourceDelta=resourceDelta(admission.resourceBefore, resource),
  }
  state.visible[neighbor] = receipt
  state.visibleOrder[#state.visibleOrder + 1] = neighbor
  state.lastProgressAt = receipt.at
  writeSceneryRing("direct-visible", state, receipt)
end

local function noteSceneryFailure(fields, event, checkpoint)
  fields = type(fields) == "table" and fields or {}
  local caller = tostring(fields.caller or ""):lower()
  local reason = tostring(fields.reason or ""):lower()
  local related = caller:find("direct-ring", 1, true)
    or caller:find("mobile-scenery", 1, true)
    or checkpoint:find("direct-ring", 1, true)
    or reason:find("direct-ring", 1, true)
    or fields.neighbor ~= nil and (event:find("mobile", 1, true)
      or checkpoint:find("direct", 1, true))
  if not related then return false end
  local state = sceneryState(mapField(fields), event)
  local neighbor = fields.neighbor and compact(fields.neighbor, 96) or "core"
  local key = tostring(neighbor)
  local failure = state.failures[key]
  if not failure then
    failure = {
      neighbor=neighbor, at=now(), source=event,
      reason=compact(fields.reason or checkpoint or event, 128),
      status="failed",
    }
    state.failures[key] = failure
  end
  writeSceneryRing("ring-failed", state, failure)
  addFinding("SCENERY-RING-FAILED",
    "RING " .. string.upper(tostring(neighbor)) .. " FEHLGESCHLAGEN", "bad", {
      mapId=state.mapId, source=event,
    })
  return true
end

function PerformanceDiagnostics.reportViewport(receipt)
  receipt = type(receipt) == "table" and receipt or {}
  local previous = PerformanceDiagnostics.viewport
  local window = type(receipt.window) == "table" and receipt.window or {
    x=0, y=0, w=receipt.windowWidth or receipt.width,
    h=receipt.windowHeight or receipt.height,
  }
  local safe = type(receipt.safe) == "table" and receipt.safe or {
    x=receipt.safeX, y=receipt.safeY,
    w=receipt.safeWidth, h=receipt.safeHeight,
  }
  local revision = tonumber(receipt.revision)
  local orientation = tostring(receipt.orientation or "unknown"):lower()
  local geometry = table.concat({ tostring(window.x), tostring(window.y),
    tostring(window.w), tostring(window.h), tostring(safe.x), tostring(safe.y),
    tostring(safe.w), tostring(safe.h), orientation,
    tostring(receipt.touchLayoutPolicy), tostring(receipt.touchVisible) }, "|")
  local stale = type(previous) == "table" and previous.geometry
    and previous.geometry ~= geometry and previous.revision and revision
    and revision <= previous.revision or false
  local orientationOk = receipt.orientationGeometryOk
  if orientationOk == nil and tonumber(window.w) and tonumber(window.h) then
    if orientation:find("portrait", 1, true) then
      orientationOk = tonumber(window.h) >= tonumber(window.w)
    elseif orientation:find("landscape", 1, true) then
      orientationOk = tonumber(window.w) >= tonumber(window.h)
    end
  end
  local wx, wy = tonumber(window.x) or 0, tonumber(window.y) or 0
  local ww, wh = tonumber(window.w), tonumber(window.h)
  local sx, sy = tonumber(safe.x), tonumber(safe.y)
  local sw, sh = tonumber(safe.w), tonumber(safe.h)
  local safeValid = ww and wh and sx and sy and sw and sh
    and sw > 0 and sh > 0 and sx >= wx and sy >= wy
    and sx + sw <= wx + ww + 1e-6
    and sy + sh <= wy + wh + 1e-6
  local overlap = tonumber(receipt.touchOverlapCount) or 0
  local noControlGeometry = receipt.touchVisible == true
    and receipt.touchLayoutPolicy == "no-control-geometry"
  local tone
  if stale or orientationOk == false or not safeValid or overlap > 0 then
    tone = "bad"
  elseif not revision or noControlGeometry then
    tone = "warn"
  else
    tone = "good"
  end
  local state = {
    schema=receipt.schema, revision=revision, orientation=orientation,
    orientationOk=orientationOk, window=window, safe=safe,
    usable=receipt.usable, geometry=geometry, stale=stale,
    touchVisible=receipt.touchVisible == true,
    touchLayoutPolicy=receipt.touchLayoutPolicy,
    touchOverlapCount=overlap, safeValid=safeValid == true,
    tone=tone, at=now(), source=receipt.source or receipt.orientationSource,
  }
  PerformanceDiagnostics.viewport = state
  if tone == "bad" then
    addFinding("MOBILE-VIEWPORT", stale and "VIEWPORT-REVISION VERALTET"
      or orientationOk == false and "ORIENTIERUNG/GEOMETRIE WIDERSPRUCH"
      or safeValid == false and "SAFE CONTENT UNGUELTIG"
      or "TOUCH-CONTROL UEBERLAPPUNG", "bad", {
        source=state.source,
      })
  end
  local diagnostics = PerformanceDiagnostics.diagnostics
  if diagnostics and type(diagnostics.write) == "function" then
    pcall(diagnostics.write, "vasc.performance.viewport", {
      status=tone, revision=revision, orientation=orientation,
      source=state.source, windowWidth=window.w, windowHeight=window.h,
      safeX=safe.x, safeY=safe.y, safeWidth=safe.w, safeHeight=safe.h,
      touchVisible=state.touchVisible, touchOverlapCount=overlap,
      touchLayoutPolicy=state.touchLayoutPolicy,
      orientationGeometryOk=orientationOk,
    })
  end
  return tone ~= "bad", state
end

function PerformanceDiagnostics.noteEvent(event, fields)
  event = tostring(event or ""):lower()
  fields = type(fields) == "table" and fields or {}
  local result = tostring(fields.result or fields.status or ""):lower()
  local expectedFallback = result == "expected_fallback" or result == "expected-fallback"
  local failed = not expectedFallback and (result == "failed" or result == "failure" or result == "error"
    or event:find("error", 1, true) or event:find("fallback", 1, true))
  local function starts(kind)
    if not PerformanceDiagnostics.pendingLoads[kind] then
      PerformanceDiagnostics.beginLoad(kind, fields)
    end
  end
  local function ends(kind)
    if PerformanceDiagnostics.pendingLoads[kind] then
      PerformanceDiagnostics.endLoad(kind, fields)
    end
  end

  if event:find("viewport-revision", 1, true) then
    PerformanceDiagnostics.reportViewport(fields)
  end

  local rawCheckpoint = tostring(fields.checkpoint or event)
  local checkpoint = rawCheckpoint:lower()
  local rootMapId = mapField(fields,
    type(PerformanceDiagnostics.sceneryRing) == "table"
      and PerformanceDiagnostics.sceneryRing.mapId or nil)
  if checkpoint:find("mobile-core-prefetch-start", 1, true) then
    beginSceneryCore(rootMapId, event)
  elseif checkpoint:find("mobile-core-scene-ready", 1, true) then
    local state = sceneryState(rootMapId, event)
    state.sceneReadyAt = state.sceneReadyAt or now()
    state.sceneReadyResource = state.sceneReadyResource or resourceSample()
    state.expectedDirect = tonumber(fields.directMaps) or state.expectedDirect
    writeSceneryRing("core-scene-ready", state, { source=event })
  end
  if checkpoint:find("gen1-world-scene-canvas-ready", 1, true)
      or checkpoint:find("mobile-core-canvas-presented", 1, true) then
    noteSceneryFirstVisible(rootMapId, event)
  end
  if checkpoint:find("mobile-scenery-core-ready", 1, true) then
    local state = sceneryState(rootMapId, event)
    state.coreReadyAt = state.coreReadyAt or now()
    state.coreReadyResource = state.coreReadyResource or resourceSample()
    writeSceneryRing("core-ready", state, { source=event })
  end
  local admittedNeighbor = checkpointNeighbor(rawCheckpoint, fields,
    "direct-admitted-")
  if admittedNeighbor then
    noteSceneryAdmission(sceneryState(rootMapId, event), admittedNeighbor, event)
  end
  local visibleNeighbor = checkpointNeighbor(rawCheckpoint, fields,
    "direct-visible-")
  if visibleNeighbor then
    noteSceneryVisible(sceneryState(rootMapId, event), visibleNeighbor, event)
  end
  local phase
  if checkpoint:find("rom", 1, true) and checkpoint:find("ready", 1, true) then
    phase = "rom-ready"
  elseif checkpoint:find("atlas", 1, true) then
    phase = "atlas"
  elseif checkpoint:find("mobile%-scenery%-core%-ready") then
    phase = "current-core-ready"
  elseif checkpoint:find("direct%-union") then
    phase = "direct-union"
  elseif checkpoint:find("panorama", 1, true)
      and checkpoint:find("ready", 1, true) then
    phase = "panorama"
  elseif checkpoint:find("world%-scene%-canvas%-ready") then
    phase = "first-visible-frame"
  elseif checkpoint:find("first", 1, true)
      and (checkpoint:find("visible", 1, true)
        or checkpoint:find("frame", 1, true)
        or checkpoint:find("canvas", 1, true)) then
    phase = "first-visible-frame"
  elseif checkpoint:find("controllable", 1, true)
      or checkpoint:find("interactive", 1, true) then
    phase = "first-controllable-frame"
  elseif checkpoint:find("world", 1, true)
      and (checkpoint:find("build", 1, true)
        or checkpoint:find("scene", 1, true)) then
    phase = "world-build"
  end
  if phase then
    PerformanceDiagnostics.markPhase(phase, {
      mapId=mapField(fields, rootMapId), sceneId=fields.sceneId, source=event,
    })
  end

  if event:find("map", 1, true) and (result == "started"
      or event:find("loading", 1, true) or event:find("will", 1, true)) then
    starts("map")
  elseif event:find("map", 1, true) and (result == "ready"
      or event:find("entered", 1, true) or event:find("loaded", 1, true)) then
    ends("map")
  end
  if event:find("battle", 1, true) and (event:find("request", 1, true)
      or event:find("starting", 1, true)
      or event:find("started", 1, true)) then
    -- battle.started means that the simulation exists.  The battle is only
    -- visually ready when the first VASC HUD receipt is painted below.
    starts("battle")
  elseif result == "native_latched" and PerformanceDiagnostics.pendingLoads.battle then
    -- The native provider does not emit a VASC HUD-ready receipt. Preserve
    -- the provider's reason, but do not wait for an observation it cannot send.
    PerformanceDiagnostics.endLoad("battle", {
      status="unobserved", source=event, sceneId=fields.sceneId, mapId=fields.mapId,
    })
  elseif event:find("battle", 1, true) and (event:find("finished", 1, true)
      or event:find("ended", 1, true))
      and PerformanceDiagnostics.pendingLoads.battle then
    PerformanceDiagnostics.endLoad("battle", {
      status="unobserved", source=event,
      sceneId=fields.sceneId, mapId=fields.mapId,
    })
  end
  if event:find("battle", 1, true)
      and (fields.provider ~= nil or fields.providerStatus ~= nil
        or event:find("provider", 1, true)) then
    PerformanceDiagnostics.battleProvider = {
      provider=fields.provider or fields.source or event,
      status=failed and "failed" or fields.providerStatus or result or "active",
      tone=failed and "bad" or "good", at=now(), source=event,
    }
  end
  if event:find("save", 1, true) and event:find("loading", 1, true) then
    starts("save")
  elseif event:find("save", 1, true) and event:find("loaded", 1, true) then
    ends("save")
  end

  local sceneryFailure = failed
    and noteSceneryFailure(fields, event, checkpoint) or false
  if failed then
    rememberSignal("error", event, fields, "bad")
  end
  if failed and not sceneryFailure then
    local load = recentLoad(20)
    local message = compact(event, 72)
    if load then
      message = load.kind:upper() .. " " .. string.format("%.0f MS", load.elapsedMs)
        .. " + " .. message
    end
    addFinding(load and "LOAD+ERROR" or "RUNTIME-ERROR", message, "bad", {
      elapsed=load and load.elapsedMs, mapId=fields.mapId or (load and load.mapId),
      sceneId=fields.sceneId or (load and load.sceneId), source=event,
    })
  end

  if event:find("weather%-music") then
    PerformanceDiagnostics.weather.generation = hostGeneration()
    PerformanceDiagnostics.weather.musicExpected =
      PerformanceDiagnostics.weather.generation == 1
    PerformanceDiagnostics.weather.musicAt = now()
    PerformanceDiagnostics.weather.musicEvent = event
    PerformanceDiagnostics.weather.musicActive = not failed
      and (fields.action == "weather" or fields.musicVariant ~= nil
        or event:find("refresh%-requested") ~= nil)
    PerformanceDiagnostics.weather.code = fields.weatherCode
    PerformanceDiagnostics.weather.mapId = fields.mapId
  elseif event:find("weather", 1, true) then
    PerformanceDiagnostics.weather.generation = hostGeneration()
    PerformanceDiagnostics.weather.musicExpected =
      PerformanceDiagnostics.weather.generation == 1
    PerformanceDiagnostics.weather.visualAt = now()
    PerformanceDiagnostics.weather.visualEvent = event
    PerformanceDiagnostics.weather.visualActive = not failed
    PerformanceDiagnostics.weather.code = fields.weatherCode
    PerformanceDiagnostics.weather.mapId = fields.mapId
  end
end

function PerformanceDiagnostics.reportHud(receipt)
  receipt = type(receipt) == "table" and receipt or {}
  if PerformanceDiagnostics.pendingLoads.battle then
    PerformanceDiagnostics.endLoad("battle", {
      status="ready", source=receipt.source or receipt.hud,
      sceneId=receipt.sceneId,
    })
  end
  if receipt.sideOrderOk == nil and tonumber(receipt.playerX)
      and tonumber(receipt.enemyX) then
    local orientation = tostring(receipt.orientation or ""):lower()
    local portrait = orientation:find("portrait", 1, true) ~= nil
      or (orientation == "" and tonumber(receipt.viewportHeight)
        and tonumber(receipt.viewportWidth)
        and receipt.viewportHeight > receipt.viewportWidth)
    if portrait and tonumber(receipt.playerY) and tonumber(receipt.enemyY) then
      local playerCenter = tonumber(receipt.playerY)
        + (tonumber(receipt.playerHeight) or 0) * .5
      local enemyCenter = tonumber(receipt.enemyY)
        + (tonumber(receipt.enemyHeight) or 0) * .5
      receipt.sideOrderOk = playerCenter > enemyCenter
    else
      local playerCenter = tonumber(receipt.playerX)
        + (tonumber(receipt.playerWidth) or 0) * .5
      local enemyCenter = tonumber(receipt.enemyX)
        + (tonumber(receipt.enemyWidth) or 0) * .5
      receipt.sideOrderOk = playerCenter < enemyCenter
    end
  end
  if receipt.sideOrderOk == false then
    receipt.mirrored = true
    receipt.reason = receipt.reason == "anchors-in-bounds"
      and "player-enemy-hud-order-mirrored" or receipt.reason
  end
  PerformanceDiagnostics.hud = receipt
  PerformanceDiagnostics.battleProvider = {
    provider=receipt.provider or receipt.hud or receipt.source or "battle-hud",
    status="active", tone="good", at=now(), source=receipt.source,
  }
  local w, h = tonumber(receipt.viewportWidth or receipt.width),
    tonumber(receipt.viewportHeight or receipt.height)
  local bad = receipt.mirrored == true or receipt.inBounds == false
    or receipt.orientationOk == false
  if bad then
    addFinding("BATTLE-HUD-LAYOUT", tostring(receipt.reason or
      (receipt.mirrored and "HUD MIRRORED" or "HUD OUT OF BOUNDS")), "bad", {
        source=receipt.source, sceneId=receipt.sceneId,
      })
  end
  local signature = table.concat({ tostring(receipt.hud), tostring(w), tostring(h),
    tostring(receipt.orientation), tostring(receipt.axis), tostring(bad),
    tostring(receipt.target), tostring(receipt.contract),
    tostring(receipt.presentationApplied), tostring(receipt.reason) }, "|")
  -- Moving cameras and animations change anchor coordinates every frame.
  -- Keep the live receipt above, but log coordinates on the periodic sample
  -- or a structural/health change instead of turning motion into log traffic.
  local shouldLog = signature ~= PerformanceDiagnostics.lastHudSignature
    or now() - PerformanceDiagnostics.lastHudLogAt >= 10
  if shouldLog then
    PerformanceDiagnostics.lastHudSignature = signature
    PerformanceDiagnostics.lastHudLogAt = now()
  end
  local diagnostics = PerformanceDiagnostics.diagnostics
  if shouldLog and diagnostics and type(diagnostics.write) == "function" then
    pcall(diagnostics.write, "vasc.performance.battle-hud-layout", {
      status=bad and "bad" or "good", orientation=receipt.orientation,
      axis=receipt.axis, width=w, height=h, hud=receipt.hud,
      target=receipt.target, contract=receipt.contract,
      presentationApplied=receipt.presentationApplied,
      orientationOk=receipt.orientationOk,
      sideOrderOk=receipt.sideOrderOk, mirrored=receipt.mirrored == true,
      result=receipt.inBounds == false and "out-of-bounds" or "in-bounds",
      reason=receipt.reason, source=receipt.source,
      playerHudX=receipt.playerX, playerHudY=receipt.playerY,
      playerHudWidth=receipt.playerWidth, playerHudHeight=receipt.playerHeight,
      enemyHudX=receipt.enemyX, enemyHudY=receipt.enemyY,
      enemyHudWidth=receipt.enemyWidth, enemyHudHeight=receipt.enemyHeight,
      projectionSpace=receipt.projectionSpace,
      enemyHeadX=receipt.enemyHeadX, enemyHeadY=receipt.enemyHeadY,
    })
  end
  return not bad
end

local function activeWeatherCode(value)
  value = tostring(value or ""):lower()
  return value ~= "" and value ~= "clear" and value ~= "none"
    and value ~= "off" and value ~= "0"
end

hostGeneration = function()
  local mod = V and V.mod
  local exports = mod and mod.exports or {}
  return tonumber(mod and mod._vascHostGeneration)
    or tonumber(exports and exports.targetGeneration)
    or tonumber(exports and exports.generation)
end

function PerformanceDiagnostics.reportWeather(receipt)
  receipt = type(receipt) == "table" and receipt or {}
  local state = PerformanceDiagnostics.weather
  state.code = receipt.weatherCode or receipt.mode or state.code
  if receipt.musicActive ~= nil then state.musicActive = receipt.musicActive == true end
  if receipt.visualActive ~= nil then state.visualActive = receipt.visualActive == true end
  state.lastReportAt = now()
  state.mapId = receipt.mapId or state.mapId
  state.generation = tonumber(receipt.generation) or state.generation
    or hostGeneration()
  if receipt.musicExpected ~= nil then
    state.musicExpected = receipt.musicExpected == true
  elseif state.musicExpected == nil then
    state.musicExpected = state.generation == 1
  end
  state.musicPolicy = receipt.musicPolicy or state.musicPolicy
    or (state.musicExpected and "optional-variant" or "native")
  local activeWeather = activeWeatherCode(state.code)
  local mismatch = activeWeather and (state.visualActive == false
    or state.musicExpected and state.musicActive == true
      and state.visualActive ~= true)
  if mismatch then
    addFinding("WEATHER-MISMATCH", "MUSIK AKTIV, DARSTELLUNG FEHLT", "bad", {
      mapId=receipt.mapId, source=receipt.source,
    })
    state.mismatchReported = true
  else
    state.mismatchReported = false
  end
  local signature = table.concat({ tostring(state.code),
    tostring(state.musicActive), tostring(state.visualActive),
    tostring(mismatch), tostring(receipt.mapId) }, "|")
  local shouldLog = signature ~= PerformanceDiagnostics.lastWeatherSignature
    or now() - PerformanceDiagnostics.lastWeatherLogAt >= 10
  if shouldLog then
    PerformanceDiagnostics.lastWeatherSignature = signature
    PerformanceDiagnostics.lastWeatherLogAt = now()
  end
  local diagnostics = PerformanceDiagnostics.diagnostics
  if shouldLog and diagnostics and type(diagnostics.write) == "function" then
    pcall(diagnostics.write, "vasc.performance.weather-state", {
      status=mismatch and "bad" or "good", weatherCode=state.code,
      mapId=receipt.mapId, source=receipt.source,
      provider=state.visualActive and "visual-active" or "visual-missing",
      generation=state.generation,
      musicVariant=not state.musicExpected and "native"
        or state.musicActive == nil and "unobserved"
        or state.musicActive and "active" or "inactive",
    })
  end
  return not mismatch
end

local function inspectPendingAndWeather()
  local stamp = now()
  for kind, pending in pairs(PerformanceDiagnostics.pendingLoads) do
    local limits = LOAD_LIMITS[kind] or { bad=4000 }
    local elapsedMs = math.max(0, (stamp - pending.at) * 1000)
    if elapsedMs >= limits.bad and not pending.reportedBad then
      pending.reportedBad = true
      addFinding("LOAD-TIMEOUT-" .. kind:upper(),
        kind:upper() .. " NACH " .. string.format("%.0f MS NICHT BEREIT",
          elapsedMs), "bad", {
          elapsed=elapsedMs, mapId=pending.context.mapId,
          sceneId=pending.context.sceneId,
          source=pending.context.source,
        })
    end
  end

  -- A progressive ring is background work and therefore never has a global
  -- "all direct maps must exist" deadline. Only a neighbour that was actually
  -- admitted can become stuck. Correlate that exact per-map transaction after
  -- the old 15-second world-bad threshold without holding the current core in
  -- a permanent WAIT state.
  local ring = PerformanceDiagnostics.sceneryRing
  if type(ring) == "table" and ring.mapId and ring.firstVisibleAt then
    for neighbor, admission in pairs(ring.admitted or {}) do
      if not ring.visible[neighbor] and not ring.failures[neighbor]
          and admission.at and stamp - admission.at >= 15
          and PerformanceDiagnostics.framesObserved
            - (tonumber(admission.frameAt) or PerformanceDiagnostics.framesObserved)
              >= 120 then
        admission.reportedBad = true
        local failure = {
          neighbor=neighbor, at=stamp, status="failed",
          reason="admitted-neighbour-not-visible", source=admission.source,
          elapsedMs=math.max(0, (stamp - admission.at) * 1000),
        }
        ring.failures[neighbor] = failure
        writeSceneryRing("direct-timeout", ring, failure)
        addFinding("SCENERY-RING-TIMEOUT",
          "RING " .. string.upper(tostring(neighbor)) .. " NICHT SICHTBAR",
          "bad", { elapsed=failure.elapsedMs, mapId=ring.mapId,
            source=admission.source })
      end
    end
  end

  local weather = PerformanceDiagnostics.weather
  local waitingForVisual = activeWeatherCode(weather.code)
    and weather.musicExpected ~= false
    and weather.musicActive == true and weather.visualActive ~= true
    and weather.musicAt and stamp - weather.musicAt >= 2
  if waitingForVisual and not weather.mismatchReported then
    weather.mismatchReported = true
    addFinding("WEATHER-MISMATCH", "MUSIK AKTIV, DARSTELLUNG FEHLT", "bad", {
      mapId=weather.mapId, source=weather.musicEvent,
    })
  elseif not waitingForVisual and weather.visualActive == true then
    weather.mismatchReported = false
  end
end

local function platformInfo()
  local L = runtime()
  local nativeOS = call(L.system, "getOS")
  local nativeLower = tostring(nativeOS or ""):lower()
  local osName = (nativeLower == "ios" or nativeLower == "android")
    and nativeOS or nil
  if not osName and type(L._os) == "string" and L._os ~= "" then
    osName = L._os
  end
  if not osName then osName = nativeOS end
  osName = tostring(osName or "UNKNOWN")
  local lower = osName:lower()
  local mobile = lower == "ios" or lower == "android"
  local cores = tonumber(call(L.system, "getProcessorCount"))
  return osName, mobile, cores
end

local function finite(value)
  value = tonumber(value)
  if value and value == value and value > 0 and value < math.huge then
    return value
  end
  return nil
end

local function addSample(seconds)
  seconds = finite(seconds)
  if not seconds then return false end
  -- Ignore pauses/debugger stops. They do not describe renderer throughput
  -- and would poison the complete rolling window after returning to play.
  if seconds > 1 then return false end
  local cap = PerformanceDiagnostics.SAMPLE_CAPACITY
  local cursor = PerformanceDiagnostics.sampleCursor % cap + 1
  PerformanceDiagnostics.sampleCursor = cursor
  PerformanceDiagnostics.samples[cursor] = seconds * 1000
  PerformanceDiagnostics.sampleCount = math.min(
    PerformanceDiagnostics.sampleCount + 1, cap)
  PerformanceDiagnostics.framesObserved =
    PerformanceDiagnostics.framesObserved + 1
  return true
end

local function percentile(values, fraction)
  if #values == 0 then return nil end
  table.sort(values)
  local index = math.max(1, math.min(#values,
    math.ceil(#values * fraction)))
  return values[index]
end

local function frameWindow()
  local values = {}
  for _, value in pairs(PerformanceDiagnostics.samples) do
    if finite(value) then values[#values + 1] = value end
  end
  if #values == 0 then return nil, nil, nil end
  return percentile({ unpackValues(values) }, .50),
    percentile({ unpackValues(values) }, .95),
    percentile({ unpackValues(values) }, .99)
end

local function toneForHigherBad(value, warnAt, badAt)
  if not value then return "info" end
  if value >= badAt then return "bad" end
  if value >= warnAt then return "warn" end
  return "good"
end

local function toneForLowerBad(value, warnBelow, badBelow)
  if not value then return "info" end
  if value < badBelow then return "bad" end
  if value < warnBelow then return "warn" end
  return "good"
end

local function maxTone(a, b)
  local rank = { info=0, good=0, warn=1, bad=2 }
  return (rank[b] or 0) > (rank[a] or 0) and b or a
end

local function sceneryRingSummary(mobile)
  local state = PerformanceDiagnostics.sceneryRing
  if not mobile then
    return { tone="info", status="DESKTOP", observed=false,
      admitted=0, visible=0, failures=0 }
  end
  if type(state) == "table" and state.mapId then
    local admitted = tableCount(state.admitted)
    local visible = tableCount(state.visible)
    local failures = tableCount(state.failures)
    local summary = {
      mapId=state.mapId, admitted=admitted, visible=visible,
      failures=failures, observed=true,
      expectedDirect=state.expectedDirect,
      coreReady=state.coreReadyAt ~= nil,
      firstVisible=state.firstVisibleAt ~= nil,
      coreToFirstVisibleMs=state.coreToFirstVisibleMs,
      sceneToFirstVisibleMs=state.sceneToFirstVisibleMs,
      admissions=state.admitted, visibleMaps=state.visible,
      failureMaps=state.failures,
    }
    if not state.startedAt and PerformanceDiagnostics.milestones["direct-union"]
        and failures == 0 then
      summary.tone, summary.status, summary.legacy =
        "good", "DIRECT UNION", true
      return summary
    end
    if failures > 0 then
      summary.tone, summary.status = "bad", "RING FAILED"
      return summary
    end
    if state.firstVisibleAt then
      summary.tone = "good"
      local expected = tonumber(state.expectedDirect) or admitted
      summary.status = admitted > 0 and ("RING " .. tostring(visible) .. "/"
        .. tostring(expected) .. (admitted < expected
          and " A" .. tostring(admitted) or "")) or "CORE VISIBLE"
      return summary
    end
    if state.startedAt then
      local elapsedMs = math.max(0, (now() - state.startedAt) * 1000)
      summary.elapsedMs = elapsedMs
      summary.tone = elapsedMs >= LOAD_LIMITS.world.bad and "bad"
        or elapsedMs >= LOAD_LIMITS.world.warn and "warn" or "info"
      summary.status = "CORE LOADING"
      return summary
    end
  end
  -- Older Gen-1 builds and Gen 2 may still publish one atomic direct-union
  -- milestone. Preserve that compatibility without requiring it from the new
  -- Gen-1 ring.
  if PerformanceDiagnostics.milestones["direct-union"] then
    return { tone="good", status="DIRECT UNION", observed=true,
      legacy=true, admitted=0, visible=0, failures=0 }
  end
  return { tone="info", status="WAIT", observed=false,
    admitted=0, visible=0, failures=0 }
end

local function displayNumber(value, decimals)
  if not value then return "N/A" end
  return string.format("%." .. tostring(decimals or 0) .. "f", value)
end

local function deviceProfile()
  if not (V and type(V.require) == "function") then return nil end
  local ok, profile = pcall(V.require, "DeviceProfile")
  if not ok or type(profile) ~= "table" then return nil end
  local selected = profile.setting and type(profile.setting.get) == "function"
    and call(profile.setting, "get") or nil
  local effective = type(profile.effective) == "function"
    and call(profile, "effective") or nil
  return tostring(selected or "unknown"), tostring(effective or "unknown")
end

local function rendererHealth()
  local mod = V and V.mod
  local exports = mod and mod.exports or {}
  local generation = tonumber(mod and mod._vascHostGeneration)
    or tonumber(exports and exports.targetGeneration)
    or tonumber(exports and exports.generation)
  local installed = exports.rendererInstalled
  if installed == nil then installed = type(exports.renderer) == "table" end
  local active = exports.active
  if active == nil then active = installed end
  local status
  if type(exports.voxelStatus) == "function" then
    status = call(exports, "voxelStatus")
  end
  if type(status) == "table" then
    if status.installed ~= nil then installed = status.installed == true end
    if status.active ~= nil then active = status.active == true end
    if status.runtimeInstalled ~= nil then
      installed = status.runtimeInstalled == true
    end
    if status.runtimeActive ~= nil then active = status.runtimeActive == true end
  end
  return generation, installed == true, active == true,
    tostring(exports.rendererError or (type(status) == "table"
      and (status.lastError or status.error)) or "")
end

local function loggerHealth(diagnostics)
  if type(diagnostics) ~= "table"
      or type(diagnostics.supportStatus) ~= "function" then
    return false, "LOGGER API FEHLT", nil, false, false, "UNAVAILABLE"
  end
  local ok, status = pcall(diagnostics.supportStatus, "monitor-snapshot")
  if not ok or type(status) ~= "table" then
    return false, "LOGGER FEHLER", nil, false, false, "UNAVAILABLE"
  end
  local recording = status.recording
  if recording == nil then
    recording = type(status.path) == "string" and status.path ~= ""
      and status.storageError == nil and "ACTIVE" or "FAILED"
  end
  local readable = status.readableLog
  -- Compatibility for a pre-mirror Diagnostics provider: a concrete path was
  -- historically the only indication that the live file was readable.
  if readable == nil then
    readable = type(status.path) == "string" and status.path ~= ""
      and "ACTIVE" or "UNAVAILABLE"
  end
  local recorderHealthy = recording == "ACTIVE" and status.alwaysOn == true
    and status.capped ~= true
  local readableHealthy = readable == "ACTIVE"
  local healthy = recorderHealthy and readableHealthy
  local label = healthy and "AKTIV"
    or status.capped and "VOLL"
    or recorderHealthy and "UNLESBAR" or "FEHLT"
  return healthy, label, status, recorderHealthy, readableHealthy, readable
end

function PerformanceDiagnostics.observe(delta)
  local L = runtime()
  delta = delta or call(L.timer, "getDelta")
  local seconds = tonumber(delta)
  if seconds and seconds >= .25 and seconds <= 10
      and now() - PerformanceDiagnostics.lastStallAt >= 5 then
    PerformanceDiagnostics.lastStallAt = now()
    local load = recentLoad(20)
    addFinding(load and "LOAD+FRAME-STALL" or "FRAME-STALL",
      (load and (load.kind:upper() .. " + ") or "")
        .. string.format("FRAME %.0f MS", seconds * 1000), "bad", {
          elapsed=seconds * 1000, mapId=load and load.mapId,
          sceneId=load and load.sceneId,
        })
  end
  return addSample(delta)
end

function PerformanceDiagnostics.reset()
  PerformanceDiagnostics.samples = {}
  PerformanceDiagnostics.sampleCursor = 0
  PerformanceDiagnostics.sampleCount = 0
  PerformanceDiagnostics.framesObserved = 0
  PerformanceDiagnostics.lastError = nil
  PerformanceDiagnostics.secondsSinceLog = 0
  PerformanceDiagnostics.pendingLoads = {}
  PerformanceDiagnostics.latestLoads = {}
  PerformanceDiagnostics.milestones = {}
  PerformanceDiagnostics.lastMilestoneResource = nil
  PerformanceDiagnostics.phaseSequence = 0
  PerformanceDiagnostics.findings = {}
  PerformanceDiagnostics.recentSignals = {}
  PerformanceDiagnostics.hud = {}
  PerformanceDiagnostics.battleProvider = {}
  PerformanceDiagnostics.viewport = {}
  PerformanceDiagnostics.weather = {}
  PerformanceDiagnostics.sceneryRing = {}
  PerformanceDiagnostics.memoryBaseline = nil
  PerformanceDiagnostics.lastStallAt = -math.huge
  PerformanceDiagnostics.lastHudLogAt = -math.huge
  PerformanceDiagnostics.lastHudSignature = nil
  PerformanceDiagnostics.lastWeatherLogAt = -math.huge
  PerformanceDiagnostics.lastWeatherSignature = nil
end

function PerformanceDiagnostics.snapshot(diagnostics)
  inspectPendingAndWeather()
  local L = runtime()
  local osName, mobile, cores = platformInfo()
  local fps = finite(call(L.timer, "getFPS"))
  local p50, p95, p99 = frameWindow()
  if not fps and p50 then fps = 1000 / p50 end

  local stats = call(L.graphics, "getStats")
  if type(stats) ~= "table" then stats = {} end
  local luaMb
  if type(collectgarbage) == "function" then
    local ok, kb = pcall(collectgarbage, "count")
    if ok then luaMb = tonumber(kb) and tonumber(kb) / 1024 or nil end
  end
  local textureMb = tonumber(stats.texturememory)
  if textureMb then textureMb = textureMb / MiB end
  local drawcalls = tonumber(stats.drawcalls)
  local width, height = call(L.graphics, "getPixelDimensions")
  if not width then width, height = call(L.graphics, "getDimensions") end
  width, height = tonumber(width), tonumber(height)
  local dpi = tonumber(call(L.window, "getDPIScale")) or 1
  local powerState, powerPercent, powerSeconds =
    call(L.system, "getPowerInfo")
  local generation, rendererInstalled, rendererActive, rendererError =
    rendererHealth()
  local loggerOk, loggerLabel, logger, recorderOk, readableOk, readableState =
    loggerHealth(diagnostics)
  local selectedProfile, effectiveProfile = deviceProfile()
  local hud = PerformanceDiagnostics.hud
  local viewport = PerformanceDiagnostics.viewport
  local battleProvider = PerformanceDiagnostics.battleProvider
  local weather = PerformanceDiagnostics.weather
  local hudObserved = type(hud) == "table" and next(hud) ~= nil
  local hudTone = not hudObserved and "info"
    or (hud.mirrored == true or hud.inBounds == false
      or hud.orientationOk == false) and "bad" or "good"
  local viewportTone = mobile and (viewport.tone or "info") or "info"
  local providerTone = battleProvider.tone or "info"
  local activeWeather = activeWeatherCode(weather.code)
  local musicExpected = weather.musicExpected
  if musicExpected == nil then musicExpected = generation == 1 end
  local weatherMismatch = activeWeather and (weather.visualActive == false
    or musicExpected and weather.musicActive == true
      and weather.visualActive ~= true)
  local weatherUnobserved = activeWeather and not weatherMismatch
    and (weather.visualActive == nil
      or musicExpected and weather.musicActive == nil)
  local weatherTone = not activeWeather and "info"
    or weatherMismatch and "bad" or weatherUnobserved and "warn" or "good"
  local findingTone = PerformanceDiagnostics.findings[1]
    and PerformanceDiagnostics.findings[1].tone or "good"

  local fpsTone = toneForLowerBad(fps, mobile and 50 or 55,
    mobile and 35 or 40)
  local p95Tone = toneForHigherBad(p95, mobile and 22 or 20,
    mobile and 33.5 or 30)
  local luaTone = toneForHigherBad(luaMb, mobile and 256 or 512,
    mobile and 512 or 1024)
  local textureTone = toneForHigherBad(textureMb, mobile and 256 or 1024,
    mobile and 512 or 2048)
  local drawTone = toneForHigherBad(drawcalls, mobile and 900 or 1400,
    mobile and 1800 or 2800)
  local exportState = logger and logger.export or "UNAVAILABLE"
  local exportTone = exportState == "ACTIVE" and "good"
    or "info"
  local recorderTone = recorderOk and "good" or "bad"
  local readableTone = readableOk and "good" or "bad"
  if not PerformanceDiagnostics.memoryBaseline then
    PerformanceDiagnostics.memoryBaseline = {
      luaMemoryMb=luaMb, textureMemoryMb=textureMb, at=now(),
    }
  end
  local baseline = PerformanceDiagnostics.memoryBaseline
  local luaGrowth = luaMb and baseline.luaMemoryMb
    and luaMb - baseline.luaMemoryMb or nil
  local textureGrowth = textureMb and baseline.textureMemoryMb
    and textureMb - baseline.textureMemoryMb or nil
  local memoryTrendTone = maxTone(
    toneForHigherBad(luaGrowth, mobile and 64 or 256,
      mobile and 128 or 512),
    toneForHigherBad(textureGrowth, mobile and 96 or 512,
      mobile and 192 or 1024))
  local loadToneValue = "info"
  for kind, pending in pairs(PerformanceDiagnostics.pendingLoads) do
    local elapsedMs = math.max(0, (now() - pending.at) * 1000)
    local limits = LOAD_LIMITS[kind] or { warn=1500, bad=4000 }
    loadToneValue = maxTone(loadToneValue,
      elapsedMs >= limits.bad and "bad"
        or elapsedMs >= limits.warn and "warn" or "info")
  end
  for _, receipt in pairs(PerformanceDiagnostics.latestLoads) do
    loadToneValue = maxTone(loadToneValue, receipt.tone or "info")
  end
  local sceneryRing = sceneryRingSummary(mobile)
  local overall = "good"
  for _, tone in ipairs({ fpsTone, p95Tone, luaTone, textureTone, drawTone,
      rendererInstalled and rendererActive and "good" or "bad",
      recorderTone, readableTone, viewportTone,
      providerTone, memoryTrendTone, loadToneValue, sceneryRing.tone }) do
    overall = maxTone(overall, tone)
  end
  overall = maxTone(overall, hudTone)
  overall = maxTone(overall, weatherTone)
  overall = maxTone(overall, findingTone)

  local recommended
  if fps and fps < 35 or p95 and p95 >= 33.5 then recommended = "LIGHT"
  elseif fps and fps < 52 or p95 and p95 >= 22 then recommended = "BALANCED"
  elseif fps then recommended = "HIGH"
  else recommended = "MESSUNG LÄUFT" end

  return {
    schema=PerformanceDiagnostics.SCHEMA,
    generation=generation,
    platform=osName, mobile=mobile, cores=cores,
    fps=fps, frameP50Ms=p50, frameP95Ms=p95, frameP99Ms=p99,
    sampleCount=PerformanceDiagnostics.sampleCount,
    luaMemoryMb=luaMb, textureMemoryMb=textureMb,
    drawcalls=drawcalls, canvases=tonumber(stats.canvases),
    images=tonumber(stats.images), shaderSwitches=tonumber(stats.shaderswitches),
    width=width, height=height, dpi=dpi,
    powerState=powerState, powerPercent=powerPercent,
    powerSeconds=powerSeconds,
    rendererInstalled=rendererInstalled, rendererActive=rendererActive,
    rendererError=rendererError,
    loggerOk=loggerOk, loggerLabel=loggerLabel, logger=logger,
    selectedProfile=selectedProfile, effectiveProfile=effectiveProfile,
    recommendedProfile=recommended,
    loads=PerformanceDiagnostics.latestLoads,
    milestones=PerformanceDiagnostics.milestones,
    pendingLoads=PerformanceDiagnostics.pendingLoads,
    findings=PerformanceDiagnostics.findings,
    hud=hud, viewport=viewport, battleProvider=battleProvider,
    weather=weather, sceneryRing=sceneryRing,
    memoryTrend={ luaDeltaMb=luaGrowth, textureDeltaMb=textureGrowth,
      tone=memoryTrendTone, baselineAt=baseline.at },
    lights={
      recorder={ tone=recorderTone,
        status=recorderOk and "ACTIVE" or "FAILED" },
      readableLog={ tone=readableTone, status=readableState,
        path=logger and logger.readablePath or logger and logger.path },
      export={ tone=exportTone, status=exportState,
        path=logger and logger.exportRelativePath },
      viewport={ tone=viewportTone,
        status=viewport.revision and ("R" .. tostring(viewport.revision))
          or (mobile and "WAIT" or "DESKTOP") },
      weather={ tone=weatherTone,
        status=not activeWeather and "IDLE" or weatherMismatch and "FAILED"
          or weatherUnobserved and "WAIT" or "ACTIVE" },
      battleProvider={ tone=providerTone,
        status=battleProvider.status or "WAIT" },
      hudOrientation={ tone=hudTone,
        status=not hudObserved and "WAIT" or hudTone == "bad" and "FAILED"
          or "ACTIVE" },
      memoryTrend={ tone=memoryTrendTone,
        status=memoryTrendTone == "bad" and "SPIKE"
          or memoryTrendTone == "warn" and "RISING" or "STABLE" },
      loadPhases={ tone=loadToneValue,
        status=loadToneValue == "bad" and "SLOW/FAILED"
          or loadToneValue == "warn" and "SLOW" or "READY" },
      sceneryRing={ tone=sceneryRing.tone, status=sceneryRing.status,
        mapId=sceneryRing.mapId },
    },
    tones={ fps=fpsTone, frameP95=p95Tone, luaMemory=luaTone,
      textureMemory=textureTone, drawcalls=drawTone,
      renderer=rendererInstalled and rendererActive and "good" or "bad",
      logger=loggerOk and "good" or "bad", recorder=recorderTone,
      readableLog=readableTone, export=exportTone,
      viewport=viewportTone, battleProvider=providerTone, hud=hudTone,
      weather=weatherTone, memoryTrend=memoryTrendTone,
      loadPhases=loadToneValue, sceneryRing=sceneryRing.tone,
      finding=findingTone, overall=overall },
    overall=overall,
  }
end

function PerformanceDiagnostics.rows(language, diagnostics)
  local de = language == "de"
  local s = PerformanceDiagnostics.snapshot(diagnostics)
  local function row(label, right, tone, help)
    return { label=label, right=right, statusTone=tone, help=help }
  end
  local rows = {
    row(de and "GESAMTSTATUS" or "OVERALL STATUS",
      s.overall == "good" and "OK" or s.overall == "warn" and "WARNUNG" or "FEHLER",
      s.overall,
      de and "Rot bedeutet: diese Funktion ist ausgefallen oder der gemessene Wert liegt klar außerhalb des 60-FPS-Budgets."
        or "Red means a failed function or a measured value clearly outside the 60 FPS budget."),
    row("FPS", displayNumber(s.fps, 0), s.tones.fps,
      de and "Vom Host gemeldete aktuelle Bildrate. Rot unter 40 FPS am PC beziehungsweise 35 FPS mobil."
        or "Current host-reported frame rate. Red below 40 FPS on desktop or 35 FPS on mobile."),
    row(de and "FRAME P95" or "FRAME P95",
      displayNumber(s.frameP95Ms, 1) .. (s.frameP95Ms and " MS" or ""),
      s.tones.frameP95,
      de and "95 Prozent der letzten bis zu 180 Spielbilder waren schneller als dieser Wert. Rot ab etwa 30 ms."
        or "95 percent of the last up to 180 gameplay frames were faster than this value. Red near 30 ms."),
    row(de and "LUA RAM" or "LUA RAM", displayNumber(s.luaMemoryMb, 1) .. " MB",
      s.tones.luaMemory,
      de and "Speicher des Lua-Spielzustands. Betriebssystem-Gesamtspeicher ist in LÖVE nicht portabel verfügbar."
        or "Lua game-state memory. Total OS memory is not portably exposed by LÖVE."),
    row(de and "GRAFIK RAM" or "GRAPHICS RAM",
      displayNumber(s.textureMemoryMb, 1) .. " MB", s.tones.textureMemory,
      de and "Vom Grafiktreiber gemeldeter Textur-/Canvas-Speicher."
        or "Texture/canvas memory reported by the graphics driver."),
    row(de and "ZEICHENAUFRUFE" or "DRAW CALLS", displayNumber(s.drawcalls, 0),
      s.tones.drawcalls,
      de and "Zeichenaufrufe des aktuellen Bildes; sehr hohe Werte belasten besonders Mobilgeräte."
        or "Draw calls in the current frame; very high counts especially affect mobile devices."),
    row("VOXEL RENDERER", s.rendererInstalled and s.rendererActive and "AKTIV" or "AUSGEFALLEN",
      s.tones.renderer,
      de and "Prüft, ob der Renderer installiert und zur Laufzeit aktiv ist. Ein echter Ausfall ist rot."
        or "Checks that the renderer is installed and runtime-active. A real failure is red."),
    row(de and "FEHLERLOG" or "SUPPORT LOG", s.loggerLabel,
      s.tones.logger,
      de and "Prüft gemeinsam den begrenzten internen Recorder und seinen lesbaren .log-Spiegel. FEHLT, UNLESBAR oder VOLL wird rot markiert."
        or "Checks both the bounded internal recorder and its readable .log mirror. Missing, unreadable or full is red."),
    row(de and "LESBARES LOG" or "READABLE LOG",
      s.lights.readableLog.tone == "good"
        and tostring(s.lights.readableLog.path or "VASC-Logs")
        or s.lights.readableLog.status == "FAILED"
          and (de and "AUSGEFALLEN" or "FAILED")
        or (de and "BRIDGE FEHLT" or "BRIDGE MISSING"),
      s.lights.readableLog.tone,
      de and "Verifiziert, dass im mod-eigenen VASC-Logs-Ordner wirklich eine lesbare .log-Datei liegt und nicht nur ein opaker .bin-Recorder."
        or "Verifies that the mod-private VASC-Logs folder contains a real readable .log file, not only the opaque .bin recorder."),
    row(de and "OPTIONALER EXPORT" or "OPTIONAL EXPORT",
      s.logger and s.logger.export == "ACTIVE"
        and tostring(s.logger.exportRelativePath or s.logger.exportFile)
        or s.logger and s.logger.export == "FAILED" and "AUSGEFALLEN"
        or "NICHT ERFORDERLICH",
      s.tones.export,
      de and "Der Mod-Ordner ist der verbindliche Logspeicher. Ein zusätzlicher Dateien-/Dokumentexport ist optional und beeinflusst den Gesamtstatus nicht."
        or "The mod folder is the authoritative log location. An additional Files/Documents mirror is optional and does not affect overall health."),
    row("MOBILE VIEWPORT",
      s.lights.viewport.status, s.lights.viewport.tone,
      de and "Revisionierte gemeinsame Fenster-, Safe-Area-, DPI-, Orientierungs- und Touch-Ausschlussquittung."
        or "Revisioned shared window, safe-area, DPI, orientation and touch-exclusion receipt."),
    row(de and "KAMPF-PROVIDER" or "BATTLE PROVIDER",
      string.upper(tostring(s.lights.battleProvider.status)),
      s.lights.battleProvider.tone,
      de and "Getrennte Laufzeitquittung des aktiven Kampf-/HUD-Providers."
        or "Separate runtime receipt for the active battle/HUD provider."),
    row(de and "KAMPF-HUD" or "BATTLE HUD",
      s.hud and s.hud.hud
        and (s.tones.hud == "bad" and "FEHLER" or "OK") or "WARTE",
      s.hud and s.hud.hud and s.tones.hud or "info",
      de and "Prüft Viewport, HUD-Anker, Bildschirmgrenzen und die mobile Spiegel-/Orientierungsquittung."
        or "Checks viewport, HUD anchors, screen bounds and the mobile mirror/orientation receipt."),
    row(de and "WETTER" or "WEATHER",
      s.weather and s.weather.code
        and (s.tones.weather == "bad" and "DARSTELLUNG FEHLT"
          or string.upper(tostring(s.weather.code))
            .. (s.tones.weather == "warn"
              and (s.generation == 1 and "/MUSIK ?" or "/PAINTER ?") or ""))
        or "WARTE",
      s.weather and s.weather.code and s.tones.weather or "info",
      de and (s.generation == 1
        and "Vergleicht angefordertes Wetter, sichtbaren Wetter-Pass und die optionale Gen-1-Wettermusik."
        or "Gen 2 behält native Musik; bewertet wird ausschließlich der sichtbare Wetter-Painter.")
        or (s.generation == 1
          and "Compares requested weather, its visible pass and optional Gen-1 weather music."
          or "Gen 2 keeps native music; only the visible weather painter is evaluated.")),
    row(de and "SPEICHERTREND" or "MEMORY TREND",
      s.lights.memoryTrend.status, s.lights.memoryTrend.tone,
      de and "Wachstum seit Start der Monitor-Messung; rot erst bei einem gemessenen deutlichen Sprung."
        or "Growth since monitor sampling began; red only after a measured material spike."),
    row(de and "LADEPHASEN" or "LOAD PHASES",
      s.lights.loadPhases.status, s.lights.loadPhases.tone,
      de and "Start/Ende, Dauer sowie Lua-, Textur-, Canvas- und Bild-Deltas der beobachteten Ladephasen."
        or "Start/end, duration and Lua, texture, canvas and image deltas for observed load phases."),
    row(de and "GERÄT" or "DEVICE",
      string.upper(tostring(s.platform)) .. (s.mobile and "/MOBIL" or "/PC"),
      "info",
      de and "Erkannte Plattform; dieselbe Karte läuft auf Desktop, iOS und Android."
        or "Detected platform; this same page runs on desktop, iOS and Android."),
    row(de and "AUFLÖSUNG" or "RESOLUTION",
      s.width and (tostring(s.width) .. "X" .. tostring(s.height)) or "N/A", "info",
      de and "Physische Rendergröße und DPI-Faktor: " .. displayNumber(s.dpi, 2)
        or "Physical render size and DPI factor: " .. displayNumber(s.dpi, 2)),
    row(de and "PROFIL" or "PROFILE",
      string.upper(tostring(s.effectiveProfile or "N/A")), "info",
      de and "Aktiv erkanntes VASC-Geräteprofil. Der Monitor ändert es niemals automatisch."
        or "Effective VASC device profile. The monitor never changes it automatically."),
    row(de and "EMPFEHLUNG" or "RECOMMENDATION", s.recommendedProfile,
      s.overall == "bad" and "bad" or s.overall == "warn" and "warn" or "good",
      de and "Nur eine Empfehlung aus der Live-Messung; keine Einstellung wird verändert."
        or "A recommendation from live measurements only; no setting is changed."),
  }
  if s.mobile then
    rows[#rows + 1] = row(de and "WELT-RING" or "WORLD RING",
      s.lights.sceneryRing.status, s.lights.sceneryRing.tone,
      de and "Misst den aktuellen Gen-1-Kern bis zum ersten sichtbaren Bild sowie jede einzeln zugelassene und sichtbar gewordene Nachbarkarte. Wartet nicht auf eine alte atomare Direct Union."
        or "Measures the current Gen-1 core through first visibility and each individually admitted/visible neighbour. It does not wait for a legacy atomic direct union.")
  end
  local labels = { startup="START", save="SPIELSTAND", map="KARTE",
    world="WELT", battle="KAMPF", weather="WETTER" }
  for _, kind in ipairs({ "startup", "save", "map", "world", "battle",
      "weather" }) do
    local load = s.loads and s.loads[kind]
    if load then
      rows[#rows + 1] = row((de and "LADEZEIT " or "LOAD ")
        .. (labels[kind] or kind:upper()), string.format("%.0f MS", load.elapsedMs),
        load.tone, de and "Gemessene Zeit vom Startsignal bis zur Bereitschaft."
          or "Measured time from start signal until ready.")
    end
  end
  for index = 1, math.min(3, #(s.findings or {})) do
    local finding = s.findings[index]
    rows[#rows + 1] = row((de and "BEFUND " or "FINDING ") .. tostring(index),
      finding.message, finding.tone,
      de and "Zeitlich zusammenhängende Messwerte und Fehler aus dem Live-Log."
        or "Time-correlated metrics and errors from the live log.")
  end
  return rows, s
end

function PerformanceDiagnostics.logSnapshot(diagnostics)
  local s = PerformanceDiagnostics.snapshot(diagnostics)
  if type(diagnostics) == "table" and type(diagnostics.write) == "function" then
    pcall(diagnostics.write, "vasc.performance.snapshot", {
      status=s.overall, generation=s.generation, platform=s.platform,
      fps=s.fps, frameP95Ms=s.frameP95Ms, luaMemoryMb=s.luaMemoryMb,
      frameP50Ms=s.frameP50Ms, frameP99Ms=s.frameP99Ms,
      sampleCount=s.sampleCount, cores=s.cores,
      textureMemoryMb=s.textureMemoryMb, drawcalls=s.drawcalls,
      canvases=s.canvases, images=s.images,
      shaderSwitches=s.shaderSwitches,
      battery=s.powerPercent, powerState=s.powerState,
      windowWidth=s.width, windowHeight=s.height,
      renderer=s.rendererActive and "active" or "failed",
      provider=s.battleProvider.provider or "battle-provider-unobserved",
      providerStatus=s.lights.battleProvider.status,
      sceneryRingStatus=s.lights.sceneryRing.status,
      sceneryRingMap=s.sceneryRing.mapId,
      sceneryRingAdmitted=s.sceneryRing.admitted,
      sceneryRingVisible=s.sceneryRing.visible,
      sceneryRingExpected=s.sceneryRing.expectedDirect,
      sceneryRingFailures=s.sceneryRing.failures,
      coreToFirstVisibleMs=s.sceneryRing.coreToFirstVisibleMs,
      backend=s.logger and s.logger.backend,
      revision=s.viewport.revision,
      warning=s.findings[1] and s.findings[1].code or nil,
    })
    if type(diagnostics.flush) == "function" then
      pcall(diagnostics.flush, "performance-snapshot")
    end
  end
  return s
end

function PerformanceDiagnostics.install(opts)
  if PerformanceDiagnostics.installed then return true end
  opts = opts or {}
  PerformanceDiagnostics.diagnostics = opts.diagnostics
    or PerformanceDiagnostics.diagnostics
  PerformanceDiagnostics.startedAt = now()
  PerformanceDiagnostics.beginLoad("startup", { source="monitor-install" })
  if type(PerformanceDiagnostics.diagnostics) == "table"
      and type(PerformanceDiagnostics.diagnostics.setPerformanceObserver)
        == "function" then
    pcall(PerformanceDiagnostics.diagnostics.setPerformanceObserver,
      PerformanceDiagnostics.noteEvent)
  end
  local events = V and V.mod and V.mod.events
  if events and type(events.on) == "function" then
    pcall(events.on, events, "game.ready", function(payload)
      PerformanceDiagnostics.endLoad("startup", {
        status="ready", source="game.ready",
        mapId=type(payload) == "table" and payload.mapId or nil,
      })
    end)
    pcall(events.on, events, "map.exited", function(payload)
      PerformanceDiagnostics.beginLoad("map", payload)
    end)
    pcall(events.on, events, "map.entered", function(payload)
      PerformanceDiagnostics.endLoad("map", payload)
    end)
    pcall(events.on, events, "battle.requested", function(payload)
      PerformanceDiagnostics.beginLoad("battle", payload)
    end)
    pcall(events.on, events, "battle.started", function(payload)
      PerformanceDiagnostics.beginLoad("battle", payload)
    end)
    pcall(events.on, events, "battle.ended", function(payload)
      if PerformanceDiagnostics.pendingLoads.battle then
        PerformanceDiagnostics.endLoad("battle", {
          status="unobserved", source="battle.ended-before-first-hud",
          sceneId=type(payload) == "table" and payload.sceneId or nil,
          mapId=type(payload) == "table" and payload.mapId or nil,
        })
      end
    end)
    for _, eventName in ipairs({ "save.writing", "app.backgrounded",
        "app.suspended" }) do
      local lifecycleEvent = eventName
      pcall(events.on, events, lifecycleEvent, function()
        local diagnostics = PerformanceDiagnostics.diagnostics
        if diagnostics and type(diagnostics.flush) == "function" then
          pcall(diagnostics.flush, lifecycleEvent)
        end
      end)
    end
    for _, eventName in ipairs({ "game.quitting", "game.quit" }) do
      local lifecycleEvent = eventName
      pcall(events.on, events, lifecycleEvent, function()
        local diagnostics = PerformanceDiagnostics.diagnostics
        if diagnostics and type(diagnostics.finalize) == "function" then
          pcall(diagnostics.finalize, "normal")
        elseif diagnostics and type(diagnostics.flush) == "function" then
          pcall(diagnostics.flush, lifecycleEvent)
        end
      end)
    end
  end
  local hooks = V and V.mod and V.mod.hooks
  if not (hooks and type(hooks.wrap) == "function") then
    PerformanceDiagnostics.lastError = "render.hud hook unavailable"
    return false, PerformanceDiagnostics.lastError
  end
  local ok, err = pcall(function()
    hooks:wrap("render.hud", function(next, game, viewport)
      local delta = call(runtime().timer, "getDelta")
      PerformanceDiagnostics.observe(delta)
      if type(PerformanceDiagnostics.diagnostics) == "table" then
        if type(PerformanceDiagnostics.diagnostics.boot) == "function" then
          pcall(PerformanceDiagnostics.diagnostics.boot, game)
        end
        delta = finite(delta) or 0
        PerformanceDiagnostics.secondsSinceLog =
          PerformanceDiagnostics.secondsSinceLog + math.min(delta, 1)
        if PerformanceDiagnostics.secondsSinceLog >=
            PerformanceDiagnostics.LOG_INTERVAL_SECONDS then
          PerformanceDiagnostics.secondsSinceLog = 0
          PerformanceDiagnostics.logSnapshot(
            PerformanceDiagnostics.diagnostics)
        end
      end
      return next(game, viewport)
    end, -15180)
  end)
  if not ok then
    PerformanceDiagnostics.lastError = tostring(err)
    return false, PerformanceDiagnostics.lastError
  end
  PerformanceDiagnostics.installed = true
  return true
end

return PerformanceDiagnostics
