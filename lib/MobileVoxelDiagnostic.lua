-- Safe, event-driven diagnostics for the converged RC12 M10/M11 mobile segment.
--
-- This module never registers a callback, probes a graphics API, draws, or
-- opens a file itself. Its only persistence bridge is the already bounded
-- Diagnostics owner supplied explicitly through setLogger(). That owner keeps
-- two deliberately different channels: an always-on minimal crash-loop marker
-- and a detailed log that remains maintainer-code-gated. Calls made before the
-- bridge exists are represented by one aggregate log event after attachment.

local mod = ...
local Diagnostic = {}

Diagnostic.SCHEMA = "vasc-mobile-diagnostic/rc12-m10-m11-converged"
Diagnostic.RECOVERY_SCHEMA =
  "vasc-mobile-recovery-marker/rc12-m10-m11-converged"
Diagnostic.RECOVERY_MARKER_KIND = "crash-loop-recovery"
Diagnostic.BUILD = "VASC-RC12-M10-M11-CONVERGED-20260903"
Diagnostic.BASE_ZIP_SHA256 =
  "66021fb9a6512d3192692b14d3f8af965f8c52d8ed4b20163b1da8228be07618"
Diagnostic.PHYSICAL_STATUS = "RC12_REQUIRES_PHYSICAL_SMARTPHONE_PASS"
Diagnostic.PENDING_LIMIT = 600
Diagnostic.SNAPSHOT_BURST = 3
Diagnostic.SNAPSHOT_INTERVAL = 30

local state = {
  active = true,
  generation = nil,
  code = "D00",
  status = "WAITING",
  phase = "diagnostic-bootstrap",
  context = "bootstrap",
  checkpoint = "diagnostic-module-loaded",
  caller = "dispatcher",
  reason = "waiting-for-live-voxel-path",
  optionKnown = false,
  optionEnabled = nil,
  optionSource = nil,
  providerInstalled = nil,
  providerSelected = nil,
  callbacks = 0,
  pendingCalls = 0,
  produced = 0,
  presented = 0,
  battleFallbacks = 0,
  failure = nil,
  loggerReady = false,
  loggerFile = nil,
  flushWritten = false,
  recoveryMode = false,
  previous = nil,
  rearmRequested = false,
  persistenceFailures = 0,
  lastPersistenceError = nil,
  sequence = 0,
  occurrence = 0,
}

if type(mod) == "table" and mod._vascMobileDiagnosticDisabled == true then
  state.active = false
end

local logger
local seen = {}
local occurrences = {}
local snapshotRetry = {}
local lastSnapshotState = {}
local snapshotRiskPending = false
local buffered = {}
local BUFFER_LIMIT = 96

local function clean(value, limit)
  value = tostring(value == nil and "nil" or value)
  value = value:gsub("[\r\n\t]", " ")
  limit = tonumber(limit) or 256
  if #value > limit then value = value:sub(1, limit) .. "..." end
  return value
end

local function canonicalCode(value, fallback)
  value = tostring(value or fallback or "D00"):upper()
  if value:match("^D%d%d$") then return value end
  return tostring(fallback or "D00")
end

local function unfinishedCheckpoint(checkpoint)
  checkpoint = tostring(checkpoint or "")
  return checkpoint:match("%-start$") ~= nil
    or checkpoint:match("%-start:") ~= nil
end

local function copyFields(fields)
  local out = {}
  for key, value in pairs(type(fields) == "table" and fields or {}) do
    local kind = type(value)
    if kind == "string" then
      out[tostring(key)] = clean(value)
    elseif kind == "number" or kind == "boolean" then
      out[tostring(key)] = value
    elseif value == nil then
      out[tostring(key)] = "nil"
    end
  end
  return out
end

local function mergeFields(fields, extra)
  local out = copyFields(fields)
  for key, value in pairs(type(extra) == "table" and extra or {}) do
    out[key] = value
  end
  return out
end

local function commonFields(fields)
  return mergeFields(fields, {
    schema=Diagnostic.SCHEMA,
    build=Diagnostic.BUILD,
    baseZipSha256=Diagnostic.BASE_ZIP_SHA256,
    physicalPass=false,
    physicalStatus=Diagnostic.PHYSICAL_STATUS,
  })
end

local function write(event, fields)
  if type(logger) == "function" then
    local ok, result = pcall(logger, event, fields)
    return ok and result ~= false
  end
  if type(logger) == "table" and type(logger.write) == "function" then
    local ok, result = pcall(logger.write, event, fields)
    return ok and result ~= false
  end
  return false
end

local function fieldOr(fields, key, fallback)
  if type(fields) == "table" and fields[key] ~= nil then return fields[key] end
  return fallback
end

local function recoveryMarkerFields(phase, fields)
  return {
    kind=Diagnostic.RECOVERY_MARKER_KIND,
    schema=Diagnostic.RECOVERY_SCHEMA,
    build=Diagnostic.BUILD,
    mode=state.recoveryMode and "RECOVERY_2D" or "LIVE_TEST",
    phase=phase or "checkpoint",
    status=clean(fieldOr(fields, "status", state.status), 32),
    generation=fieldOr(fields, "generation", state.generation or "unknown"),
    checkpoint=clean(fieldOr(fields, "checkpoint", state.checkpoint), 112),
  }
end

local function persistRecoveryMarker(phase, fields)
  -- Recovery must preserve the exact last marker from the frozen live run.
  -- Its own harmless 2D boot is deliberately sent only to the gated log.
  if state.recoveryMode or type(logger) ~= "table"
      or type(logger.writeMobileRecoveryMarker) ~= "function" then
    return true, false
  end
  local ok, result, reason = pcall(logger.writeMobileRecoveryMarker,
    recoveryMarkerFields(phase, fields))
  if ok and result ~= false then
    state.lastPersistenceError = nil
    return true, true
  end
  state.persistenceFailures = state.persistenceFailures + 1
  state.lastPersistenceError = clean(ok and (reason or result)
    or result or "snapshot-write-failed", 160)
  return false, true
end

local function buffer(key, event, fields)
  if #buffered >= BUFFER_LIMIT then return false end
  buffered[#buffered + 1] = {
    key=clean(key, 96),
    event=clean(event, 64),
    code=clean(fields and fields.code or state.code, 8),
    checkpoint=clean(fields and fields.checkpoint or state.checkpoint, 80),
  }
  return true
end

local function emit(key, event, fields)
  if not state.active then return false end
  key = clean(key or event, 160)
  fields = commonFields(fields)
  state.phase = clean(event or "checkpoint", 64)
  fields.phase = state.phase
  if not state.loggerReady then
    if seen[key] then return false end
    local accepted = buffer(key, event, fields)
    if accepted then seen[key] = true end
    return accepted
  end

  state.sequence = state.sequence + 1
  occurrences[key] = (occurrences[key] or 0) + 1
  state.occurrence = occurrences[key]
  fields.sequence = state.sequence
  fields.occurrence = state.occurrence

  -- The fixed launcher receipt is a sampled last-boundary recorder, not an
  -- event log. Persist the first three occurrences of every exact key and then
  -- every thirtieth. Separate START/READY keys therefore remain aligned when
  -- their call sites are paired, while per-frame callbacks cannot generate
  -- 60--200 filesystem writes per second. Persistence decisions and attempts
  -- still happen before the session-log-only dedupe below.
  local duplicate = seen[key] == true
  local riskBoundary = event == "mobile-checkpoint"
    and tostring(fields.status or "") == "BOUNDARY"
    and unfinishedCheckpoint(fields.checkpoint)
  local snapshotState = table.concat({
    tostring(fields.code or "D00"),
    tostring(fields.status or "BOUNDARY"),
    tostring(fields.checkpoint or "unknown"),
  }, ":")
  local shouldPersist = state.occurrence <= Diagnostic.SNAPSHOT_BURST
    or state.occurrence % Diagnostic.SNAPSHOT_INTERVAL == 0
    or snapshotRetry[key] == true
    or lastSnapshotState[key] ~= snapshotState
    -- START and terminal keys have independent occurrence counters. Once a
    -- sampled START reached disk, the very next marker must therefore reach
    -- disk too even when its own counter is not sampled; otherwise a normal
    -- return could leave a stale START receipt and re-create E12 next boot.
    or snapshotRiskPending
  local persisted, attempted = true, false
  if shouldPersist then
    persisted, attempted = persistRecoveryMarker(event, fields)
  end
  if attempted and not persisted then
    -- A transient filesystem refusal must remain retryable. Also release a key
    -- that was seen on an earlier occurrence: the next occurrence must retry
    -- both the snapshot and the evidence event instead of silently disappearing.
    seen[key] = nil
    snapshotRetry[key] = true
    duplicate = false
  elseif attempted then
    snapshotRetry[key] = nil
    lastSnapshotState[key] = snapshotState
    snapshotRiskPending = riskBoundary
  end
  if duplicate then return false end

  local written = write(event, fields)
  if written and (not attempted or persisted) then
    seen[key] = true
  else
    seen[key] = nil
  end
  return written and (not attempted or persisted)
end

local function flushBuffer()
  if state.flushWritten or not state.loggerReady then return false end
  state.flushWritten = true
  local summaries = {}
  for _, entry in ipairs(buffered) do
    summaries[#summaries + 1] = table.concat({
      entry.event, entry.code, entry.checkpoint, entry.key,
    }, ":")
  end
  local fields = commonFields({
    code=state.code,
    generation=state.generation or "unknown",
    context=state.context,
    checkpoint=state.checkpoint,
    caller=state.caller,
    reason=state.reason,
    pendingEventCount=#buffered,
    pendingEvents=clean(table.concat(summaries, "|"), 2048),
  })
  buffered = {}
  return write("mobile-diagnostic-buffer-flush", fields)
end

local function updateRoute(caller, context, reason)
  if caller ~= nil then state.caller = clean(caller, 80) end
  if context ~= nil then state.context = clean(context, 48) end
  if reason ~= nil then state.reason = clean(reason, 256) end
end

-- Make one event the complete current launcher state before emit() persists it.
-- Exact method-owned fields override caller extras; failure history remains a
-- separate receipt and never leaks its code into a later successful boundary.
local function eventFields(fields, exact)
  local out = mergeFields(fields, exact)
  state.code = canonicalCode(out.code, "D00")
  state.status = clean(out.status or "BOUNDARY", 32)
  state.checkpoint = clean(out.checkpoint or state.checkpoint or "unknown", 80)
  updateRoute(out.caller, out.context, out.reason)
  out.code = state.code
  out.status = state.status
  out.checkpoint = state.checkpoint
  out.generation = state.generation or "unknown"
  out.context = state.context
  out.caller = state.caller
  out.reason = state.reason
  if state.failure then
    out.firstFailureCode = state.failure.code
    out.firstFailureCheckpoint = state.failure.checkpoint
    out.firstFailureCaller = state.failure.caller
    out.firstFailureContext = state.failure.context
    out.firstFailureReason = state.failure.reason
  end
  return out
end

local function failureFields(fields, extra)
  return mergeFields(fields, mergeFields(extra, {
    generation=state.generation or "unknown",
    context=state.context,
    option=state.optionKnown and tostring(state.optionEnabled) or "unknown",
    optionSource=state.optionSource or "unknown",
    providerInstalled=state.providerInstalled,
    providerSelected=state.providerSelected,
  }))
end

local function classifyFallback(reason)
  local value = string.lower(clean(reason or "unknown"))
  if value:find("shader", 1, true) or value:find("compiler", 1, true) then
    return "D07", "shader-compile-link"
  end
  if value:find("depth", 1, true) or value:find("canvas", 1, true)
      or value:find("framebuffer", 1, true) or value:find("attach", 1, true)
      or value:find("pixelcanvas", 1, true) then
    return "D08", "color-depth-framebuffer"
  end
  if value:find("mesh", 1, true) or value:find("vertex", 1, true)
      or value:find("index", 1, true) or value:find("uint32", 1, true) then
    return "D09", "mesh-index-upload"
  end
  if value:find("provider", 1, true) or value:find("pipeline", 1, true) then
    return "D04", "provider-selection"
  end
  if value:find("api", 1, true) or value:find("unavailable", 1, true) then
    return "D06", "renderer-api"
  end
  return "D11", "unexplained-native-fallback"
end

function Diagnostic.active()
  return state.active
end

function Diagnostic.recoveryMode()
  return state.active and state.recoveryMode == true
end

local function unfinishedRiskBoundary(value)
  if tostring(value.mode or "") ~= "LIVE_TEST"
      or tostring(value.phase or "") ~= "mobile-checkpoint"
      or tostring(value.status or "") ~= "BOUNDARY" then
    return false
  end
  -- A frozen graphics call leaves its immediately preceding START marker in
  -- the fixed receipt. Completed probes replace it with READY/SUCCESS/FAILURE.
  -- M6 treated every ordinary D00/SUCCESS receipt as a crash and therefore
  -- held VoxelState at level 0 forever; only a genuinely unfinished boundary
  -- may arm the fail-safe 2D boot.
  return unfinishedCheckpoint(value.checkpoint)
end

local function matchingRecoveryMarker(value)
  if type(value) ~= "table" or value.build ~= Diagnostic.BUILD
      or not unfinishedRiskBoundary(value) then
    return false
  end
  local current = value.kind == Diagnostic.RECOVERY_MARKER_KIND
    and value.schema == Diagnostic.RECOVERY_SCHEMA
  local legacy = value.kind == nil and value.schema == Diagnostic.SCHEMA
  if not (current or legacy) then return false end
  local previousGeneration = tostring(value.generation or "unknown")
  local currentGeneration = tostring(state.generation or "unknown")
  -- Old RC12 markers were written before the dispatcher supplied generation
  -- and therefore contain "unknown". Accept that value only on the read-only
  -- migration path; all newly written markers carry the actual generation.
  return previousGeneration == currentGeneration
    or (legacy and previousGeneration == "unknown")
end

local function maintenanceUnlocked()
  if type(logger) ~= "table" or type(logger.enabled) ~= "function" then
    return false
  end
  local ok, enabled = pcall(logger.enabled)
  return ok and enabled == true
end

function Diagnostic.setLogger(writer)
  local valid = type(writer) == "function"
    or (type(writer) == "table" and type(writer.write) == "function")
  if not valid then return false, "invalid-diagnostics-writer" end
  logger = writer
  if type(writer) == "table" and writer.MOBILE_RECOVERY_KIND ~= nil
      and writer.MOBILE_RECOVERY_KIND ~= Diagnostic.RECOVERY_MARKER_KIND then
    logger = nil
    return false, "recovery-marker-kind-mismatch"
  end
  if type(writer) == "table"
      and type(writer.readMobileRecoveryMarker) == "function" then
    local ok, previous = pcall(writer.readMobileRecoveryMarker)
    if ok and matchingRecoveryMarker(previous) then
      state.previous = copyFields(previous)
      state.recoveryMode = true
    end
  end
  state.loggerReady = true
  if type(writer) == "table" and writer.FILE ~= nil then
    state.loggerFile = clean(writer.FILE, 160)
  end
  if not state.recoveryMode then persistRecoveryMarker("logger-ready") end
  flushBuffer()
  if state.recoveryMode then
    write("mobile-recovery-2d-armed", commonFields({
      code=state.previous.code or "D00",
      generation=state.previous.generation or state.generation or "unknown",
      context=state.previous.context or "unknown",
      checkpoint=state.previous.checkpoint or "unknown",
      caller=state.previous.caller or "unknown",
      reason=state.previous.reason or "previous-live-run-preserved",
      recovery2D=true,
      previousBuild=state.previous.build or "unknown",
    }))
  end
  return true
end

function Diagnostic.rearm()
  if not maintenanceUnlocked() then return false, "diagnostics-locked" end
  if not state.active or not state.recoveryMode then
    return false, "no-recovery-marker"
  end
  if type(logger) ~= "table"
      or type(logger.clearMobileRecoveryMarker) ~= "function" then
    return false, "recovery-marker-clear-unavailable"
  end
  local ok, cleared, reason = pcall(logger.clearMobileRecoveryMarker)
  if not ok or cleared == false then
    return false, clean(reason or cleared or "recovery-marker-clear-failed", 160)
  end
  state.rearmRequested = true
  write("mobile-live-test-rearmed", commonFields({
    code=state.previous and state.previous.code or "D00",
    checkpoint=state.previous and state.previous.checkpoint or "unknown",
    action="restart-required",
  }))
  return true, "restart-required"
end

function Diagnostic.setGeneration(generation, fields)
  if not state.active then return false end
  local numeric = tonumber(generation)
  state.generation = numeric or clean(generation or "unknown", 16)
  emit("generation:" .. tostring(state.generation), "mobile-generation-selected",
    eventFields(fields, {
      code="D00",
      status="INFO",
      generation=state.generation,
      checkpoint="generation-selected",
      caller=fields and fields.caller or "dispatcher",
      context=fields and fields.context or "bootstrap",
      reason="generation-selected",
    }))
  return true
end

function Diagnostic.checkpoint(key, codeOrFields, maybeFields)
  if not state.active then return false end
  local fields = type(codeOrFields) == "table" and codeOrFields
    or type(maybeFields) == "table" and maybeFields or {}
  local code = type(codeOrFields) == "string"
    and canonicalCode(codeOrFields, "D00")
    or canonicalCode(fields.code, "D00")
  key = clean(key or "unknown", 80)
  local status = fields.status or (code == "D90" and "SUCCESS" or "BOUNDARY")
  local reason = fields.reason
    or (code == "D90" and "3d-canvas-returned" or "checkpoint-reached")
  -- Core/ring checkpoints repeat legitimately after every map transition.
  -- Keep their public checkpoint value stable for recovery and consumers, but
  -- scope the private session-log dedupe key to the root map.  Older callers
  -- without a map retain the original session-wide dedupe contract.
  local rootMap = fields.map
  local dedupeKey = "checkpoint:" .. key
  if rootMap ~= nil and tostring(rootMap) ~= "" then
    dedupeKey = dedupeKey .. ":map:" .. clean(rootMap, 80)
  end
  return emit(dedupeKey, "mobile-checkpoint", eventFields(fields, {
    code=code,
    status=status,
    checkpoint=key,
    context=fields.context or state.context,
    caller=fields.caller or "diagnostic-checkpoint",
    reason=reason,
  }))
end

function Diagnostic.fail(code, checkpoint, reason, fields)
  if not state.active then return false end
  code = canonicalCode(code, "D11")
  checkpoint = clean(checkpoint or state.checkpoint or "unknown", 80)
  reason = clean(reason or "unspecified", 256)
  updateRoute(fields and fields.caller or "diagnostic-failure",
    fields and fields.context or state.context, reason)
  local first = state.failure == nil
  if first then
    state.failure = {
      code=code,
      checkpoint=checkpoint,
      reason=reason,
      caller=state.caller,
      context=state.context,
    }
  end
  local event = first and "FIRST-FAILURE" or "mobile-failure"
  local key = first and "first-failure"
    or table.concat({ "failure", code, checkpoint }, ":")
  return emit(key, event, eventFields(failureFields(fields, {
    code=code,
    status="FAILURE",
    checkpoint=checkpoint,
    reason=reason,
    caller=state.caller,
    context=state.context,
  }), {}))
end

function Diagnostic.observeOption(enabled, source, fields)
  if not state.active then return false end
  enabled = enabled == true
  local changed = not state.optionKnown or state.optionEnabled ~= enabled
    or state.optionSource ~= tostring(source or "unknown")
  state.optionKnown = true
  state.optionEnabled = enabled
  state.optionSource = clean(source or "unknown", 80)
  local reason = enabled and "voxel-option-enabled" or "voxel-option-disabled"
  if changed then
    emit("option:" .. tostring(enabled) .. ":" .. state.optionSource,
      "mobile-voxel-option", eventFields(fields, {
        code="D00",
        status="INFO",
        checkpoint="option-read",
        enabled=enabled,
        source=state.optionSource,
        caller=state.optionSource,
        context=fields and fields.context or state.context,
        reason=reason,
      }))
  end
  return enabled
end

function Diagnostic.provider(installed, selected, caller, reason, fields)
  if not state.active then return false end
  installed = installed == true
  selected = selected == true
  state.providerInstalled = installed
  state.providerSelected = selected
  local eventStatus = installed and selected and "SUCCESS" or "OBSERVED"
  local eventFieldsValue = eventFields(fields, {
    code="D00",
    status=eventStatus,
    checkpoint="provider-selection",
    installed=installed,
    selected=selected,
    caller=caller or "provider",
    context=fields and fields.context or state.context,
    reason=reason or "provider-state-observed",
  })
  emit(table.concat({ "provider", tostring(installed), tostring(selected),
      state.caller }, ":"), "mobile-provider-state", eventFieldsValue)
  if state.optionEnabled == true and not installed
      and fields and fields.failIfMissing == true then
    return Diagnostic.fail("D03", "provider-install",
      reason or "renderer-provider-not-installed",
      mergeFields(fields, { caller=state.caller }))
  end
  if state.optionEnabled == true and installed and not selected
      and fields and fields.failIfUnselected == true then
    return Diagnostic.fail("D04", "provider-selection",
      reason or "renderer-provider-not-selected",
      mergeFields(fields, { caller=state.caller }))
  end
  return installed and selected
end

function Diagnostic.callback(caller, context, fields)
  if not state.active then return false end
  state.callbacks = state.callbacks + 1
  local eventFieldsValue = eventFields(fields, {
    code="D00",
    status="ENTERED",
    checkpoint="draw-callback-entered",
    caller=caller or "renderer",
    context=context or "world",
    reason="callback-entered",
    callbackCount=state.callbacks,
  })
  emit("callback:" .. state.caller .. ":" .. state.context,
    "mobile-render-callback", eventFieldsValue)
  return true
end

function Diagnostic.capability(code, checkpoint, ok, detail, fields)
  if not state.active then return ok == true end
  code = canonicalCode(code, "D06")
  checkpoint = clean(checkpoint or "renderer-capability", 80)
  local passed = ok == true
  local eventFieldsValue = eventFields(fields, {
    code=passed and "D00" or code,
    status=passed and "SUCCESS" or "FAILURE",
    checkpoint=checkpoint,
    caller=fields and fields.caller or "capability-probe",
    context=fields and fields.context or state.context,
    reason=detail or (passed and "available" or "unavailable"),
    ok=passed,
    detail=detail or (passed and "available" or "unavailable"),
  })
  emit("capability:" .. checkpoint .. ":" .. tostring(passed),
    "mobile-capability", eventFieldsValue)
  if not passed then Diagnostic.fail(code, checkpoint, state.reason, fields) end
  return passed
end

function Diagnostic.pending(caller, reason, fields)
  if not state.active then return false end
  state.pendingCalls = state.pendingCalls + 1
  local eventFieldsValue = eventFields(fields, {
    code="D00",
    status="PENDING",
    checkpoint="mesh-warmup",
    caller=caller or "renderer",
    context=fields and fields.context or state.context,
    reason=reason or "renderer-pending",
    pendingCalls=state.pendingCalls,
  })
  emit("pending:" .. state.caller .. ":" .. state.reason,
    "mobile-renderer-pending", eventFieldsValue)
  if state.optionEnabled == true
      and state.pendingCalls == Diagnostic.PENDING_LIMIT then
    Diagnostic.fail("D10", "mesh-warmup-timeout", state.reason,
      mergeFields(fields, { caller=state.caller,
        pendingCalls=state.pendingCalls }))
  end
  return false
end

function Diagnostic.fallback(caller, reason, status, fields)
  if not state.active then return false end
  status = clean(status or "fallback", 32)
  if status == "pending" then
    return Diagnostic.pending(caller, reason, fields)
  end
  local routeCaller = caller or "renderer"
  local routeContext = fields and fields.context or state.context
  local routeReason = reason or "native-2d-without-reason"
  -- OFF/disabled is a supported user choice and can also be observed briefly
  -- while save-backed options settle. Record the route, but never let that
  -- expected state mask a later shader/canvas/mesh failure.
  if status == "disabled" or status == "off" or status == "inactive"
      or state.optionEnabled == false then
    local eventFieldsValue = eventFields(fields, {
        code="D00",
        status="EXPECTED_FALLBACK",
        checkpoint="expected-native-fallback",
        caller=routeCaller,
        context=routeContext,
        reason=routeReason,
        fallbackStatus=status,
        expected=true,
      })
    emit("fallback-expected:" .. state.caller .. ":" .. status,
      "mobile-renderer-fallback", eventFieldsValue)
    return false
  end
  local code, checkpoint = classifyFallback(routeReason)
  local eventFieldsValue = eventFields(fields, {
    code=code,
    status="FALLBACK",
    checkpoint=checkpoint,
    caller=routeCaller,
    context=routeContext,
    reason=routeReason,
    fallbackStatus=status,
  })
  emit("fallback:" .. state.caller .. ":" .. status .. ":" .. state.reason,
    "mobile-renderer-fallback", eventFieldsValue)
  return Diagnostic.fail(code, checkpoint, state.reason,
    mergeFields(fields, { caller=state.caller, status=status }))
end

function Diagnostic.produced(caller, context, fields)
  if not state.active then return false end
  state.produced = state.produced + 1
  state.pendingCalls = 0
  local eventFieldsValue = eventFields(fields, {
    code="D90",
    status="SUCCESS",
    checkpoint="first-3d-canvas-returned",
    caller=caller or "renderer",
    context=context or state.context,
    reason="3d-canvas-returned",
    produced=state.produced,
    physicalPass=false,
  })
  emit("produced:" .. state.caller .. ":" .. state.context,
    "mobile-3d-canvas-returned", eventFieldsValue)
  return true
end

function Diagnostic.presented(caller, context, fields)
  if not state.active then return false end
  state.presented = state.presented + 1
  local eventFieldsValue = eventFields(fields, {
    code="D90",
    status="SUCCESS",
    checkpoint="late-presentation-boundary",
    caller=caller or "renderer",
    context=context or state.context,
    reason="late-presentation-boundary-reached-not-physically-proven",
    presented=state.presented,
    physicalPass=false,
    physicalMeaning="tester-photo-still-required",
  })
  emit("presented:" .. state.caller .. ":" .. state.context,
    "mobile-late-boundary-reached", eventFieldsValue)
  return true
end

function Diagnostic.battleFallback(caller, reason, fields)
  if not state.active then return false end
  state.battleFallbacks = state.battleFallbacks + 1
  local unexpected = fields and fields.failIfUnexpected == true
  local eventFieldsValue = eventFields(fields, {
    code=unexpected and "D14" or "D00",
    status=unexpected and "FALLBACK" or "EXPECTED_FALLBACK",
    checkpoint="battle-native-fallback",
    caller=caller or "battle",
    context=fields and fields.context or state.context,
    reason=reason or "battle-native-fallback",
    battleFallbacks=state.battleFallbacks,
  })
  emit("battle-fallback:" .. state.caller .. ":" .. state.reason,
    "mobile-battle-fallback", eventFieldsValue)
  if not unexpected then return false end
  return Diagnostic.fail("D14", "battle-native-fallback", state.reason,
    mergeFields(fields, { caller=state.caller }))
end

local function detailedStatus()
  local failure = state.failure and {
    code=state.failure.code,
    checkpoint=state.failure.checkpoint,
    reason=state.failure.reason,
    caller=state.failure.caller,
    context=state.failure.context,
  } or nil
  return {
    schema=Diagnostic.SCHEMA,
    build=Diagnostic.BUILD,
    baseZipSha256=Diagnostic.BASE_ZIP_SHA256,
    active=state.active,
    generation=state.generation,
    code=state.code,
    status=state.status,
    phase=state.phase,
    context=state.context,
    checkpoint=state.checkpoint,
    caller=state.caller,
    reason=state.reason,
    optionKnown=state.optionKnown,
    optionEnabled=state.optionEnabled,
    optionSource=state.optionSource,
    providerInstalled=state.providerInstalled,
    providerSelected=state.providerSelected,
    callbacks=state.callbacks,
    pendingCalls=state.pendingCalls,
    produced=state.produced,
    presented=state.presented,
    battleFallbacks=state.battleFallbacks,
    failure=failure,
    loggerReady=state.loggerReady,
    loggerFile=state.loggerFile,
    mode=state.recoveryMode and "RECOVERY_2D" or "LIVE_TEST",
    source="THIS RUN",
    recoveryMode=state.recoveryMode,
    rearmRequested=state.rearmRequested,
    persistenceFailures=state.persistenceFailures,
    lastPersistenceError=state.lastPersistenceError,
    sequence=state.sequence,
    occurrence=state.occurrence,
    previous=state.previous and copyFields(state.previous) or nil,
    physicalPass=false,
    physicalStatus=Diagnostic.PHYSICAL_STATUS,
  }
end

function Diagnostic.status()
  if not maintenanceUnlocked() then return nil, "diagnostics-locked" end
  return detailedStatus()
end

function Diagnostic.report()
  if not maintenanceUnlocked() then return nil, "diagnostics-locked" end
  if not (state.recoveryMode and state.previous) then
    return detailedStatus()
  end
  local out = copyFields(state.previous)
  out.active = state.active
  out.mode = "RECOVERY_2D"
  out.source = "LAST LIVE RUN"
  out.recoveryMode = true
  out.rearmRequested = state.rearmRequested
  out.currentCode = state.code
  out.currentStatus = state.status
  out.currentCheckpoint = state.checkpoint
  out.loggerReady = state.loggerReady
  out.loggerFile = state.loggerFile
  out.physicalPass = false
  out.physicalStatus = Diagnostic.PHYSICAL_STATUS
  return out
end

-- Queue one safe boot marker. setLogger() persists this marker in its single
-- aggregate flush instead of replaying startup events one by one.
emit("armed", "mobile-diagnostic-armed", {
  code="D00",
  status="WAITING",
  checkpoint=state.checkpoint,
  caller=state.caller,
  context=state.context,
  reason=state.reason,
})

return Diagnostic
