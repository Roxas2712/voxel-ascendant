-- Always-on bounded support flight recorder plus the separate M10 crash-loop
-- recovery marker. Diagnostics.enabled() controls only the maintainer panel
-- and dangerous QA actions; it never controls support-log creation.
--
-- The session log is event-driven, redacted and kept inside the historical
-- exact five-file/eight-MiB ring. VASC and KASC use independent forty-MiB
-- rings, so the documented combined ceiling is eighty MiB. The recovery
-- marker remains a much smaller state latch with its own closed allowlist.

local V = ...
local Diagnostics = {}

Diagnostics.CODE = "2712"
Diagnostics.OWNER = "VASC-66-SUPPORT-SESSION-LOG/v1"
Diagnostics.SCHEMA = "ascendant-support-session-log/v1"
Diagnostics.DIRECTORY = "VASC-Logs"
Diagnostics.FILE = Diagnostics.DIRECTORY
Diagnostics.MAX_SESSIONS = 5
Diagnostics.MAX_BYTES = 8 * 1024 * 1024
Diagnostics.RETENTION_SECONDS = 7 * 24 * 60 * 60
Diagnostics.COMBINED_KASC_VASC_MAX_BYTES = 80 * 1024 * 1024
Diagnostics.SUPPORT_LOG_ALWAYS_ON = true
Diagnostics.MOBILE_DETAILED_LOG_SUPPRESSED = false
Diagnostics.MOBILE_RECOVERY_MARKER = "VASC-RC12-MOBILE-RECOVERY.state"
Diagnostics.MOBILE_RECOVERY_MAX_BYTES = 4096
Diagnostics.MOBILE_RECOVERY_KIND = "crash-loop-recovery"
-- Read-only upgrade bridge. RC12 packages before the diagnostics-polish Card
-- used this misleading trace name for the same crash-loop latch. New writes
-- never target it; REARM removes whichever compatible marker was loaded.
Diagnostics.LEGACY_MOBILE_RECOVERY_MARKER = "VASC-RC12-MOBILE-TRACE.txt"
-- Internal storage, the readable mod-private mirror and an optional platform
-- export are deliberately separate. mod.storage byte storage is the
-- crash-safe source of truth and materialises opaque `.bin` values. A current
-- host may additionally publish/append the same bounded text under its narrow
-- mod-private `VASC-Logs` contract. The compatibility filesystem below is
-- retained only for older unsandboxed hosts. DATEIEN remains an opaque legacy
-- storage key; it is never presented as a player-visible path.
Diagnostics.EXPORT_DIRECTORY = "DATEIEN"
Diagnostics.FLUSH_EVENT_COUNT = 64
Diagnostics.FLUSH_BYTES = 32 * 1024
Diagnostics.FLUSH_SECONDS = 2
Diagnostics.READABLE_FLUSH_BYTES = 256 * 1024
Diagnostics.READABLE_FLUSH_SECONDS = 30

local function runtimeOS()
  local runtime = rawget(_G, "love")
  local system = type(runtime) == "table" and runtime.system or nil
  local nativeOS
  if system and type(system.getOS) == "function" then
    local ok, value = pcall(system.getOS)
    if ok and type(value) == "string" and value ~= "" then
      nativeOS = value
      if value == "iOS" or value == "Android" then return value end
    end
  end
  local osName = type(runtime) == "table" and rawget(runtime, "_os") or nil
  if type(osName) == "string" and osName ~= "" then return osName end
  return nativeOS or "unknown"
end

local active
-- Retain A21's maintainer-only, process-local Gen-2 Mega test override while
-- using this safer shared logger. It is never persisted.
local megaLimitBypass = false
local booted = false
local bootLogged = false
local sessionFile
local sessionBytes = 0
local sessionCapped = false
local sessionFinalized = false
local sessionSequence = 0
local sessionStartedAt
local previousIncomplete
local repeatEvent, repeatSignature, repeatCount
local summary = {
  errors=0, warnings=0, fallbacks=0, firstError=nil,
  lastMap=nil, lastScene=nil, abnormal=false,
}
local segmentInventory = {}
local segmentLogged = {}
local performanceObserver

local function game(explicit)
  if type(explicit) == "table" then return explicit end
  local ok, Game = pcall(require, "src.core.Game")
  return ok and Game or nil
end

local function bucket(explicit, create)
  local g = game(explicit)
  local options = g and g.save and g.save.options or g and g.options
  if type(options) ~= "table" then return nil end
  if create then options.modOptions = options.modOptions or {} end
  local all = options.modOptions
  if type(all) ~= "table" then return nil end
  local id = tostring(V and V.mod and V.mod.id or "VOXEL_ASCENDANT")
  if create then all[id] = all[id] or {} end
  return all[id]
end

function Diagnostics.enabled(explicit)
  -- A concrete save object supersedes an early cached value established while
  -- the mod loader was still starting.
  if type(explicit) == "table" then
    local owner = bucket(explicit, false)
    if owner and owner.rcDiagnostics ~= nil then
      active = owner.rcDiagnostics == true
    end
  end
  if active ~= nil then return active end
  local owner = bucket(explicit, false)
  active = owner and owner.rcDiagnostics == true or false
  return active
end

-- Gen1Recomp 0.1.90 deliberately removes love.filesystem from a mod's
-- sandbox. Keep the historical diagnostics path contract above this adapter,
-- but back it with this mod's engine-scoped shared byte storage. The legacy
-- LÖVE fallback remains only for older hosts and the isolated unit harness.
local scopedFilesystem
local boundGame
local storageBackend = "unavailable"
local storageLastError
local storagePublishState = "unavailable"
local storagePublishPath
local storagePublishError
local storageRecorderState = "unavailable"
local storageContext
local pendingChunks = {}
local pendingBytes = 0
local pendingEvents = 0
local pendingSince
local flushCount = 0
local readableState = "unavailable"
local readablePath
local readableError
local readableBytes = 0
local readablePendingChunks = {}
local readablePendingBytes = 0
local readablePendingSince
local readableFlushCount = 0

local function bindGame(explicit)
  if type(explicit) == "table" and type(explicit.save) == "table" then
    boundGame = explicit
  end
  local current = boundGame or game(explicit)
  if type(current) == "table" and type(current.save) == "table" then
    boundGame = current
  end
  return boundGame
end

local function isTitleSession(current)
  local states = current and current.stack and current.stack.states
  if type(states) ~= "table" then return false end
  for _, state in ipairs(states) do
    if type(state) == "table" and state.screenId == "TitleState" then
      return true
    end
  end
  return false
end

local function storageKey(path)
  path = tostring(path or "")
  if path == Diagnostics.MOBILE_RECOVERY_MARKER then
    return "diagnostics/recovery/current"
  elseif path == Diagnostics.LEGACY_MOBILE_RECOVERY_MARKER then
    return "diagnostics/recovery/legacy"
  end
  local prefix = Diagnostics.DIRECTORY .. "/"
  if path:sub(1, #prefix) ~= prefix then return nil end
  local name = path:sub(#prefix + 1)
  name = name:gsub("%.log$", "")
  if name:match("^[%w_-]+$") then
    return Diagnostics.EXPORT_DIRECTORY .. "/" .. name
  end
  return nil
end

local function storageFilesystem()
  if scopedFilesystem ~= nil then return scopedFilesystem end
  local storage = V and V.mod and V.mod.storage
  if type(storage) ~= "table" then return nil end

  -- Current hosts expose playthrough-scoped methods directly.  Older release
  -- harnesses exposed a pre-bound shared facade; support both without ever
  -- reaching for love.filesystem from the production sandbox.
  local direct = type(storage.context) == "function"
    and type(storage.readBytes) == "function"
    and type(storage.writeBytes) == "function"
    and type(storage.list) == "function"
    and type(storage.delete) == "function"
  local current = bindGame()
  local selected
  if direct and current and isTitleSession(current)
      and type(storage.selected) == "function" then
    local ok, value = pcall(storage.selected, storage, current)
    if ok and type(value) == "table" then selected = value end
  end
  local shared
  if not direct and type(storage.shared) == "function" then
    local ok, value = pcall(storage.shared, storage)
    if ok and type(value) == "table" then shared = value end
  end
  local function validBound(value)
    return value
      and type(value.readBytes) == "function"
      and type(value.writeBytes) == "function"
      and type(value.list) == "function"
      and type(value.delete) == "function"
  end
  if selected and not validBound(selected) then selected = nil end
  -- Never call the active-playthrough facade against a fresh title skeleton:
  -- that path is allowed to allocate an identity. selected() is the engine's
  -- non-allocating binding to an existing launcher choice. If none exists yet,
  -- retry after game.ready instead of inventing a pre-playthrough owner.
  if direct and isTitleSession(current) and not selected then return nil end
  if not direct and not validBound(shared) then return nil end

  local target = selected or (direct and storage or shared)
  local directTarget = target == storage

  local function invoke(name, ...)
    local fn = target and target[name]
    if type(fn) ~= "function" then return nil, "storage-api-missing" end
    local ok, a, b, c
    if directTarget then
      current = bindGame()
      if not current then
        storageLastError = "not-in-playthrough"
        return nil, storageLastError
      end
      ok, a, b, c = pcall(fn, target, current, ...)
    else
      ok, a, b, c = pcall(fn, target, ...)
    end
    if not ok then
      storageLastError = tostring(a)
      return nil, storageLastError
    end
    if a == false or a == nil then storageLastError = tostring(b or c or "storage-failed")
    else storageLastError = nil end
    return a, b, c
  end

  local function publish(path, payload, appendPayload)
    local prefix = Diagnostics.DIRECTORY .. "/"
    local name = path:sub(1, #prefix) == prefix
      and path:sub(#prefix + 1) or nil
    -- Recovery markers share the storage adapter but are not support logs.
    if not name then return true end
    if type(target.publishSupportLog) ~= "function" then
      storagePublishState = "unsupported"
      storagePublishPath = nil
      storagePublishError = "publish-support-log-api-missing"
      return false
    end
    if not name or not name:match("^[%w_-]+%.log$") then
      storagePublishState = "failed"
      storagePublishPath = nil
      storagePublishError = "invalid-publish-name"
      return false
    end
    current = bindGame()
    if directTarget and not current then
      storagePublishState = "failed"
      storagePublishPath = nil
      storagePublishError = "not-in-playthrough"
      return false
    end
    local method = type(target.appendSupportLog) == "function"
      and appendPayload ~= nil and "appendSupportLog" or "publishSupportLog"
    local bytes = method == "appendSupportLog" and appendPayload or payload
    local okCall, ok, relative, message
    if directTarget then
      okCall, ok, relative, message = pcall(target[method], target,
        current, name, tostring(bytes or ""))
    else
      okCall, ok, relative, message = pcall(target[method], target,
        name, tostring(bytes or ""))
    end
    -- The host chooses and verifies the physical file inside this mod's
    -- storage scope.  Only the narrow logical path requested by Diagnostics
    -- is accepted back; an arbitrary export or host path is never trusted.
    if okCall and ok == true and relative == path then
      storagePublishState = "active"
      storagePublishPath = relative
      storagePublishError = nil
      readableState, readablePath, readableError = "active", relative, nil
      if method == "appendSupportLog" and readablePath == relative then
        readableBytes = readableBytes + #tostring(bytes or "")
      else
        readableBytes = #tostring(bytes or "")
      end
      readablePendingChunks, readablePendingBytes, readablePendingSince = {}, 0, nil
      readableFlushCount = readableFlushCount + 1
      return true
    end
    storagePublishState = "failed"
    storagePublishPath = nil
    if not okCall then
      storagePublishError = tostring(ok)
    elseif ok == true then
      storagePublishError = "publish-path-mismatch"
    else
      storagePublishError = tostring(relative or message or "publish-failed")
    end
    readableState = "failed"
    readablePath = nil
    readableError = storagePublishError
    return false
  end

  storageBackend = selected and "mod.storage/selected"
    or directTarget and "mod.storage/playthrough" or "mod.storage/shared"
  do
    local ok, value
    if type(target.context) == "function" then
      if directTarget then
        ok, value = pcall(target.context, target, current)
      else
        ok, value = pcall(target.context, target)
      end
    end
    storageContext = ok and type(value) == "table" and value or nil
  end
  scopedFilesystem = {
    createDirectory=function() return true end,
    getDirectoryItems=function(path)
      if path ~= Diagnostics.DIRECTORY then return {} end
      local keys = invoke("list", Diagnostics.EXPORT_DIRECTORY)
      if type(keys) ~= "table" then return {} end
      local out = {}
      for _, key in ipairs(keys) do
        local name = tostring(key):match("^" .. Diagnostics.EXPORT_DIRECTORY
          .. "/(.+)$")
        if name and name:match("^[%w_-]+$") then
          out[#out + 1] = name .. ".log"
        end
      end
      table.sort(out)
      return out
    end,
    read=function(path)
      local key = storageKey(path)
      if not key then return nil end
      return invoke("readBytes", key)
    end,
    write=function(path, payload)
      local key = storageKey(path)
      if not key then return false end
      payload = tostring(payload or "")
      local ok = invoke("writeBytes", key, payload)
      if ok == true then
        storageRecorderState = "active"
        publish(path, payload)
      else
        storageRecorderState = "failed"
      end
      -- Keep the bounded in-app recorder alive on a stock/older host even
      -- when that host cannot publish a readable mod-private file.
      -- supportStatus() reports those two capabilities independently.
      return ok == true
    end,
    append=function(path, payload)
      local key = storageKey(path)
      if not key then return false end
      payload = tostring(payload or "")
      local nativeAppend = type(target and target.appendBytes) == "function"
      local ok, combined
      if nativeAppend then
        ok = invoke("appendBytes", key, payload)
      else
        local previous = invoke("readBytes", key)
        if type(previous) ~= "string" then previous = "" end
        combined = previous .. payload
        ok = invoke("writeBytes", key, combined)
      end
      if ok == true then
        storageRecorderState = "active"
        if type(target.appendSupportLog) == "function" then
          publish(path, nil, payload)
        else
          if combined == nil then combined = invoke("readBytes", key) end
          publish(path, type(combined) == "string" and combined or "")
        end
      else
        storageRecorderState = "failed"
      end
      return ok == true
    end,
    remove=function(path)
      local key = storageKey(path)
      if not key then return false end
      local removed = invoke("delete", key)
      local prefix = Diagnostics.DIRECTORY .. "/"
      local name = path:sub(1, #prefix) == prefix
        and path:sub(#prefix + 1) or nil
      if name and name:match("^[%w_-]+%.log$")
          and type(target.deleteSupportLog) == "function" then
        current = bindGame()
        if current or not directTarget then
          local okCall, ok, code
          if directTarget then
            okCall, ok, code = pcall(target.deleteSupportLog, target,
              current, name)
          else
            okCall, ok, code = pcall(target.deleteSupportLog, target, name)
          end
          if not okCall or ok == false then
            storagePublishError = tostring(not okCall and ok or code
              or "delete-support-log-failed")
          end
        end
      end
      return removed
    end,
    getInfo=function(path)
      local key = storageKey(path)
      if not key then return nil end
      local payload = invoke("readBytes", key)
      if type(payload) ~= "string" then return nil end
      return { type="file", size=#payload }
    end,
    expensiveAppend=not (type(target.appendBytes) == "function"),
    publicAppend=type(target.appendSupportLog) == "function",
    bufferedAppend=true,
  }
  return scopedFilesystem
end

local function fs()
  local scoped = storageFilesystem()
  if scoped then return scoped end
  local ok, filesystem = pcall(function()
    return love and love.filesystem or nil
  end)
  if ok and filesystem then
    storageBackend = "love.filesystem"
    storageRecorderState = "active"
    storagePublishState = "not-published"
  end
  return ok and filesystem or nil
end

-- This deliberately bypasses fs(). It is a legacy-host fallback only: current
-- sandboxed hosts preserve `.log` through the narrow
-- mod.storage:publishSupportLog contract and never expose love.filesystem to
-- mod code. No absolute path is fabricated or exposed here.
local function readableFilesystem()
  local ok, filesystem = pcall(function()
    return love and love.filesystem or nil
  end)
  if not ok or type(filesystem) ~= "table"
      or type(filesystem.createDirectory) ~= "function"
      or type(filesystem.getDirectoryItems) ~= "function"
      or type(filesystem.read) ~= "function"
      or type(filesystem.write) ~= "function" then
    return nil
  end
  return filesystem
end

local function utcTimestamp(compact)
  local format = compact and "!%Y%m%dT%H%M%SZ" or "!%Y-%m-%dT%H:%M:%SZ"
  return os and os.date and os.date(format) or "time-unavailable"
end

local function monotonicSeconds()
  local timer = love and love.timer
  if timer and type(timer.getTime) == "function" then
    local ok, value = pcall(timer.getTime)
    if ok and type(value) == "number" then return value end
  end
  return 0
end

local function clean(value, limit)
  value = tostring(value == nil and "nil" or value)
  value = value:gsub("[\r\n\t]", " ")
  -- Remove the common PII/secret shapes that can occur inside sanitized
  -- errors. Structured fields are allowlisted separately below.
  value = value:gsub("[%w%._%%+%-]+@[%w%.%-]+", "<email>")
  value = value:gsub("%f[%d]%d+%.%d+%.%d+%.%d+%f[%D]", "<ip>")
  value = value:gsub("/[Uu]sers/[^/%s]+/[^%s]+", function(path)
    return "<path:" .. (path:match("([^/]+)$") or "redacted") .. ">"
  end)
  value = value:gsub("[A-Za-z]:\\[Uu]sers\\[^\\%s]+\\[^%s]+", function(path)
    return "<path:" .. (path:match("([^\\]+)$") or "redacted") .. ">"
  end)
  for _, key in ipairs({
    "token", "secret", "password", "giftcode", "gift_code", "linkcode",
    "link_code", "roomcode", "room_code", "searchtext", "search_text",
  }) do
    value = value:gsub("(" .. key .. "%s*[=:]%s*)[^%s,;]+", "%1<redacted>")
    value = value:gsub("(" .. key:upper()
      .. "%s*[=:]%s*)[^%s,;]+", "%1<redacted>")
  end
  limit = tonumber(limit) or 384
  if #value > limit then value = value:sub(1, limit) .. "..." end
  return value
end

-- Closed schema: unknown fields are discarded, and known-dangerous values
-- never reach the serializer. Cards should emit stable IDs, not display text.
local SAFE_FIELDS = {}
for _, key in ipairs({
  "action", "active", "actual", "animation", "animationTarget", "axis",
  "backend", "baseZipSha256", "battleId", "build", "buildReceiptId",
  "caller", "camera",
  "canvasHeight", "canvasWidth", "cardId", "checkpoint", "code", "count",
  "context", "clipScaleX", "clipScaleY", "determinant",
  "dependency", "dependencyStatus", "diagnosticCode", "dpi", "edition",
  "elapsed", "enabled", "engineVersion", "error", "fallback", "firstError",
  "formId", "generation", "height", "hud", "inputMode", "kind", "level",
  "fps", "frameP50Ms", "frameP95Ms", "frameP99Ms", "sampleCount",
  "luaMemoryMb", "textureMemoryMb", "drawcalls", "canvases", "images",
  "luaMemoryDeltaMb", "textureMemoryDeltaMb", "drawcallDelta",
  "canvasDelta", "imageDelta", "phaseSequence",
  "shaderSwitches", "cores", "battery", "powerState",
  "frames", "milliseconds", "covered", "pumped", "attempt",
  "renderWidth", "renderHeight", "viewportWidth", "viewportHeight",
  "fromWidth", "fromHeight", "toWidth", "toHeight",
  "playerHudX", "playerHudY", "playerHudWidth", "playerHudHeight",
  "enemyHudX", "enemyHudY", "enemyHudWidth", "enemyHudHeight",
  "revision", "safeX", "safeY", "safeWidth", "safeHeight",
  "usableX", "usableY", "usableWidth", "usableHeight",
  "pixelWidth", "pixelHeight", "dpiX", "dpiY", "touchVisible",
  "touchOverlapCount", "touchLayoutPolicy", "orientationGeometryOk",
  "contract", "presentationApplied", "orientationOk", "sideOrderOk", "mirrored",
  "maintainerPanel", "mapId", "maxBytes", "mode", "moveId", "musicFamily",
  "musicId", "musicVariant", "occurrence", "map",
  "neighbor", "admitted", "visible", "expectedDirect", "failures",
  "coreToFirstVisibleMs", "sceneToFirstVisibleMs",
  "operation", "orientation", "os", "owner", "packageHash", "packageId",
  "phase", "physicalPass", "physicalStatus", "pipeline", "platform",
  "provider", "providerStatus", "reason", "resource", "sequence",
  "renderer", "repeatCount", "repeatedEvent", "requestToken", "result", "retention",
  "rollbackReceiptId", "schema", "sceneId", "segmentId", "shader",
  "source", "speciesId", "stack", "status", "target", "targetKind",
  "timeOfDay", "total", "transition", "version", "warning", "weatherCode",
  "width", "windowHeight", "windowWidth",
}) do SAFE_FIELDS[key] = true end

local function safeFieldValue(key, value)
  if not SAFE_FIELDS[key] then return nil end
  if type(value) == "table" or type(value) == "function"
      or type(value) == "userdata" or type(value) == "thread" then
    return nil
  end
  if key == "code" then
    local code = tostring(value or "")
    if not code:match("^D%d%d$") then return nil end
  end
  return clean(value, key == "stack" and 1024 or 384)
end

local function normalizedFields(fields)
  local entries, dropped = {}, 0
  for rawKey, value in pairs(type(fields) == "table" and fields or {}) do
    local key = tostring(rawKey)
    local safe = safeFieldValue(key, value)
    if safe ~= nil then
      entries[#entries + 1] = { key=key, value=safe }
    else
      dropped = dropped + 1
    end
  end
  table.sort(entries, function(a, b) return a.key < b.key end)
  return entries, dropped
end

local function eventSegment(event)
  local lower = event:lower()
  if lower:match("^vasc%.") then return event end
  local segment = "core"
  if lower:match("^mobile") then segment = "mobile"
  elseif lower:match("^battle") or lower:match("^mega")
      or lower:match("^move") or lower:match("^attack") then segment = "battle"
  elseif lower:match("^voxel") or lower:match("^shader")
      or lower:match("^scenery") or lower:match("^terrain")
      or lower:match("^map") or lower:match("^scene") then segment = "voxel"
  elseif lower:match("^fly") or lower:match("^surf")
      or lower:match("^fishing") or lower:match("^field") then segment = "field"
  elseif lower:match("^menu") or lower:match("^ui")
      or lower:match("^diagnostics") or lower:match("^repro") then segment = "ui"
  elseif lower:match("^save") or lower:match("^migration")
      or lower:match("^legacy") or lower:match("^ng") then segment = "persistence"
  end
  return "vasc." .. segment .. "." .. event
end

local function normalizedEvent(event)
  event = tostring(event or "unknown"):gsub("[^%w%._%-]", "-")
  if #event > 96 then event = event:sub(1, 96) end
  return eventSegment(event)
end

local function sharedSessionId()
  local key = "__ASCENDANT_SUPPORT_SESSION_V1"
  local existing = rawget(_G, key)
  if type(existing) == "string" and existing:match("^ASC%-%w[%w%-]+$") then
    return existing
  end
  local stamp = utcTimestamp(true):gsub("[^%w]", "")
  local ticks = math.floor(monotonicSeconds() * 1000) % 1000000
  local value = ("ASC-%s-%06d"):format(stamp, ticks)
  rawset(_G, key, value)
  return value
end

local function elapsedMilliseconds()
  if not sessionStartedAt then sessionStartedAt = monotonicSeconds() end
  return math.max(0, math.floor((monotonicSeconds() - sessionStartedAt) * 1000))
end

local function encodedLine(event, entries)
  sessionSequence = sessionSequence + 1
  local parts = {
    utcTimestamp(false),
    "seq=" .. tostring(sessionSequence),
    "elapsedMs=" .. tostring(elapsedMilliseconds()),
    "session=" .. sharedSessionId(),
    "event=" .. normalizedEvent(event),
  }
  for _, entry in ipairs(entries or {}) do
    parts[#parts + 1] = entry.key .. "=" .. entry.value
  end
  return table.concat(parts, "\t") .. "\n"
end

local function ownLogName(name)
  if type(name) ~= "string" then return false end
  local stamp = "%d%d%d%d%d%d%d%dT%d%d%d%d%d%dZ"
  local modern = "^VASC%-SESSION%-" .. stamp
    .. "%-G[12x]%-ASC%-%w[%w%-]*%.log$"
  local modernSuffix = "^VASC%-SESSION%-" .. stamp
    .. "%-G[12x]%-ASC%-%w[%w%-]*%-%d+%.log$"
  local legacy = "^VASC%-SESSION%-" .. stamp .. "%-G[12x]%.log$"
  local legacySuffix = "^VASC%-SESSION%-" .. stamp .. "%-G[12x]%-%d+%.log$"
  return name:match(modern) ~= nil or name:match(modernSuffix) ~= nil
    or name:match(legacy) ~= nil or name:match(legacySuffix) ~= nil
end

local function logNames(filesystem)
  if not (filesystem and type(filesystem.getDirectoryItems) == "function") then
    return {}
  end
  local ok, items = pcall(filesystem.getDirectoryItems, Diagnostics.DIRECTORY)
  if not ok or type(items) ~= "table" then return {} end
  local names = {}
  for _, name in ipairs(items) do
    if ownLogName(name) then names[#names + 1] = name end
  end
  table.sort(names)
  return names
end

local function filePayload(filesystem, path)
  if not (filesystem and type(filesystem.read) == "function") then return nil end
  local ok, payload = pcall(filesystem.read, path)
  if ok and type(payload) == "string" then return payload end
  return nil
end

local function previousWasIncomplete(filesystem, names)
  local newest = names[#names]
  if not newest then return nil end
  local payload = filePayload(filesystem, Diagnostics.DIRECTORY .. "/" .. newest)
  if payload and payload:find(
      "\tevent=vasc.core.session-finalized\t", 1, true) then
    return nil
  end
  return newest
end

local function removeOwn(filesystem, name)
  if not ownLogName(name) or type(filesystem.remove) ~= "function" then
    return false
  end
  local ok, result = pcall(filesystem.remove,
    Diagnostics.DIRECTORY .. "/" .. name)
  return ok and result ~= false
end

local function pruneLogs(filesystem, names)
  local kept = {}
  local now = os and type(os.time) == "function" and os.time() or nil
  for _, name in ipairs(names) do
    local expired = false
    if now and type(filesystem.getInfo) == "function" then
      local ok, info = pcall(filesystem.getInfo,
        Diagnostics.DIRECTORY .. "/" .. name)
      local modified = ok and type(info) == "table"
        and tonumber(info.modtime or info.modification) or nil
      expired = modified ~= nil
        and now - modified > Diagnostics.RETENTION_SECONDS
    end
    if expired then removeOwn(filesystem, name)
    else kept[#kept + 1] = name end
  end
  while #kept >= Diagnostics.MAX_SESSIONS do
    local oldest = table.remove(kept, 1)
    if not removeOwn(filesystem, oldest) then break end
  end
  return kept
end

local function markReadableUnavailable(reason)
  readableState = "unavailable"
  readablePath = nil
  readableError = reason or "readable-log-bridge-missing"
  readablePendingChunks, readablePendingBytes, readablePendingSince = {}, 0, nil
end

local function initializeReadableMirror(primary, path)
  if storagePublishState == "active" and storagePublishPath == path then
    readableState, readablePath, readableError = "active", path, nil
    readablePendingChunks, readablePendingBytes, readablePendingSince = {}, 0, nil
    return true
  end
  local mirror = readableFilesystem()
  if not mirror then
    markReadableUnavailable(storagePublishError or "readable-log-bridge-missing")
    return false
  end
  readablePath = path
  readableBytes = 0
  readablePendingChunks, readablePendingBytes, readablePendingSince = {}, 0, nil
  if mirror == primary then
    readableState, readableError = "active", nil
    return true
  end
  pcall(mirror.createDirectory, Diagnostics.DIRECTORY)
  local ok, result = pcall(mirror.write, path, "")
  local verified = ok and result ~= false and filePayload(mirror, path)
  if verified ~= "" then
    readableState = "failed"
    readablePath = nil
    readableError = not ok and tostring(result)
      or result == false and "readable-log-create-failed"
      or "readable-log-create-not-verified"
    return false
  end
  readableState, readableError = "active", nil
  return true
end

local function queueReadable(primary, payload)
  if storagePublishState == "active" and storagePublishPath == sessionFile then
    readableState, readablePath, readableError = "active", sessionFile, nil
    return true
  end
  local mirror = readableFilesystem()
  if not mirror then
    if storagePublishState == "failed" then
      readableState, readablePath = "failed", nil
      readableError = storagePublishError or "support-log-publish-failed"
    else
      markReadableUnavailable(storagePublishError or "readable-log-bridge-missing")
    end
    return false
  end
  if mirror == primary then
    readableState, readableError = "active", nil
    readablePath = sessionFile
    readableBytes = sessionBytes
    return true
  end
  if readableState ~= "active" or not readablePath then return false end
  readablePendingChunks[#readablePendingChunks + 1] = payload
  readablePendingBytes = readablePendingBytes + #payload
  readablePendingSince = readablePendingSince or monotonicSeconds()
  return true
end

-- LegacyCompat implements append as read+rewrite.  Mirroring every diagnostic
-- line would therefore make a long session quadratically expensive.  We do a
-- single verified read+write only at coarse byte/time boundaries, and at
-- explicit durability boundaries such as backgrounding and finalization.
local function syncReadable(force)
  if readablePendingBytes <= 0 then return readableState == "active" end
  local primary = fs()
  local mirror = readableFilesystem()
  if not mirror then
    markReadableUnavailable("readable-log-bridge-missing")
    return false
  end
  if mirror == primary then
    readableState, readableError = "active", nil
    readablePath = sessionFile
    readableBytes = sessionBytes
    readablePendingChunks, readablePendingBytes, readablePendingSince = {}, 0, nil
    return true
  end
  local age = readablePendingSince
    and math.max(0, monotonicSeconds() - readablePendingSince) or 0
  if not force and readablePendingBytes < Diagnostics.READABLE_FLUSH_BYTES
      and age < Diagnostics.READABLE_FLUSH_SECONDS then
    return true
  end
  if readableState ~= "active" or not readablePath then return false end
  local before = filePayload(mirror, readablePath)
  if type(before) ~= "string" or #before ~= readableBytes then
    readableState = "failed"
    readableError = type(before) ~= "string" and "readable-log-read-failed"
      or "readable-log-size-mismatch"
    return false
  end
  local delta = table.concat(readablePendingChunks)
  local combined = before .. delta
  local ok, result = pcall(mirror.write, readablePath, combined)
  local verified = ok and result ~= false and filePayload(mirror, readablePath)
  if verified ~= combined then
    readableState = "failed"
    readableError = not ok and tostring(result)
      or result == false and "readable-log-write-failed"
      or "readable-log-write-not-verified"
    return false
  end
  readableBytes = #combined
  readablePendingChunks, readablePendingBytes, readablePendingSince = {}, 0, nil
  readableFlushCount = readableFlushCount + 1
  readableState, readableError = "active", nil
  return true
end

local function ensureSession()
  if sessionFile then return sessionFile end
  local filesystem = fs()
  if not (filesystem
      and type(filesystem.createDirectory) == "function"
      and type(filesystem.getDirectoryItems) == "function"
      and type(filesystem.write) == "function") then
    return nil
  end
  pcall(filesystem.createDirectory, Diagnostics.DIRECTORY)
  local existing = logNames(filesystem)
  previousIncomplete = previousWasIncomplete(filesystem, existing)
  local names = pruneLogs(filesystem, existing)
  local used = {}
  for _, name in ipairs(names) do used[name] = true end
  local mirror = readableFilesystem()
  if mirror and mirror ~= filesystem then
    local mirrorNames = pruneLogs(mirror, logNames(mirror))
    for _, name in ipairs(mirrorNames) do used[name] = true end
  end
  local generation = tostring(V and V.mod
    and V.mod._vascHostGeneration or "x")
  if generation ~= "1" and generation ~= "2" then generation = "x" end
  local id = sharedSessionId():gsub("[^%w%-]", "")
  local base = "VASC-SESSION-" .. utcTimestamp(true)
    .. "-G" .. generation .. "-" .. id
  local name = base .. ".log"
  local suffix = 2
  while used[name] do
    name = base .. "-" .. tostring(suffix) .. ".log"
    suffix = suffix + 1
  end
  sessionFile = Diagnostics.DIRECTORY .. "/" .. name
  Diagnostics.FILE = sessionFile
  local ok, result = pcall(filesystem.write, sessionFile, "")
  if not ok or result == false then
    sessionFile = nil
    Diagnostics.FILE = Diagnostics.DIRECTORY
    return nil
  end
  sessionBytes = 0
  sessionCapped = false
  sessionFinalized = false
  sessionSequence = 0
  sessionStartedAt = monotonicSeconds()
  pendingChunks, pendingBytes, pendingEvents, pendingSince = {}, 0, 0, nil
  storageRecorderState = "active"
  initializeReadableMirror(filesystem, sessionFile)
  return sessionFile
end

-- The shared storage fallback has no atomic append contract on older hosts.
-- Queue small event lines and perform one bounded read/write per batch instead
-- of rewriting the complete growing log for every event.  Newer hosts may
-- expose appendBytes/appendSupportLog; the same batch is then appended without
-- a readback.  The public export is updated only at these explicit flush
-- boundaries, never advertised merely because the internal write succeeded.
local function flushPending(forceReadable)
  if pendingBytes <= 0 then
    syncReadable(forceReadable == true)
    return true
  end
  local filesystem = fs()
  local path = sessionFile
  if not (filesystem and path and type(filesystem.append) == "function") then
    storageRecorderState = "failed"
    storageLastError = storageLastError or "recorder-append-unavailable"
    return false
  end
  local payload = table.concat(pendingChunks)
  local ok, result = pcall(filesystem.append, path, payload)
  if not ok or result == false then
    storageRecorderState = "failed"
    storageLastError = tostring(not ok and result or storageLastError
      or "recorder-append-failed")
    return false
  end
  pendingChunks, pendingBytes, pendingEvents, pendingSince = {}, 0, 0, nil
  flushCount = flushCount + 1
  storageRecorderState = "active"
  queueReadable(filesystem, payload)
  syncReadable(forceReadable == true)
  return true
end

local function appendRaw(payload)
  local filesystem = fs()
  local path = ensureSession()
  if not (filesystem and path and type(filesystem.append) == "function")
      or sessionCapped then return false end
  payload = tostring(payload or "")
  -- Reserve a fixed tail for a terminal size marker without advancing the
  -- sequence on ordinary writes.
  local markerReserve = 384
  if sessionBytes + #payload + markerReserve > Diagnostics.MAX_BYTES then
    local markerEntries = normalizedFields({
      maxBytes=Diagnostics.MAX_BYTES,
      action="further-events-dropped",
    })
    payload = encodedLine("vasc.core.log-size-limit", markerEntries)
    sessionCapped = true
  end
  if sessionBytes + #payload > Diagnostics.MAX_BYTES then
    sessionCapped = true
    return false
  end
  if filesystem.bufferedAppend == true then
    pendingChunks[#pendingChunks + 1] = payload
    pendingBytes = pendingBytes + #payload
    pendingEvents = pendingEvents + 1
    pendingSince = pendingSince or monotonicSeconds()
    sessionBytes = sessionBytes + #payload
    local elapsed = monotonicSeconds() - pendingSince
    if pendingEvents >= Diagnostics.FLUSH_EVENT_COUNT
        or pendingBytes >= Diagnostics.FLUSH_BYTES
        or elapsed >= Diagnostics.FLUSH_SECONDS then
      return flushPending(false)
    end
    return true
  end
  local ok, result = pcall(filesystem.append, path, payload)
  if not ok or result == false then
    storageRecorderState = "failed"
    storageLastError = tostring(not ok and result or storageLastError
      or "recorder-append-failed")
    return false
  end
  sessionBytes = sessionBytes + #payload
  storageRecorderState = "active"
  queueReadable(filesystem, payload)
  return true
end

local function emitRaw(event, fields)
  local entries = normalizedFields(fields)
  return appendRaw(encodedLine(event, entries))
end

local function flushRepeat()
  if not repeatEvent or repeatCount <= 0 then return true end
  local event, count = repeatEvent, repeatCount
  repeatEvent, repeatSignature, repeatCount = nil, nil, 0
  return emitRaw("vasc.core.repeat-summary", {
    repeatedEvent=event,
    repeatCount=count,
  })
end

function Diagnostics.flush(reason)
  flushRepeat()
  -- The 10-second performance sampler already flushes the crash-safe recorder;
  -- forcing a full compat-file rewrite at the same cadence would recreate the
  -- mobile load regression. Other named calls are explicit durability points.
  local forceReadable = reason ~= nil and reason ~= ""
    and reason ~= "performance-snapshot"
  local ok = flushPending(forceReadable)
  return ok, ok and nil or (storageLastError or "recorder-flush-failed")
end

local function updateSummary(event, fields)
  local lower = tostring(event):lower()
  local status = type(fields) == "table"
    and tostring(fields.status or fields.result or ""):lower() or ""
  if lower:find("error", 1, true) or status == "error"
      or status == "failure" or status == "failed" then
    summary.errors = summary.errors + 1
    summary.abnormal = true
    if not summary.firstError then
      summary.firstError = normalizedEvent(event)
    end
  end
  if lower:find("warn", 1, true) or status == "warning" then
    summary.warnings = summary.warnings + 1
  end
  if lower:find("fallback", 1, true) then
    summary.fallbacks = summary.fallbacks + 1
  end
  if type(fields) == "table" then
    if fields.mapId ~= nil then summary.lastMap = clean(fields.mapId, 96) end
    if fields.sceneId ~= nil then summary.lastScene = clean(fields.sceneId, 96) end
  end
end

function Diagnostics.write(event, fields)
  event = normalizedEvent(event)
  local entries, dropped = normalizedFields(fields)
  if dropped > 0 then
    entries[#entries + 1] = { key="warning", value="fields-redacted" }
    table.sort(entries, function(a, b) return a.key < b.key end)
  end
  local signatureParts = { event }
  for _, entry in ipairs(entries) do
    signatureParts[#signatureParts + 1] = entry.key .. "=" .. entry.value
  end
  local signature = table.concat(signatureParts, "\0")
  updateSummary(event, fields)
  if type(performanceObserver) == "function"
      and not event:match("^vasc%.performance%.") then
    pcall(performanceObserver, event, fields)
  end
  if signature == repeatSignature then
    repeatCount = repeatCount + 1
    return true
  end
  flushRepeat()
  repeatEvent, repeatSignature, repeatCount = event, signature, 0
  return appendRaw(encodedLine(event, entries))
end

-- One process-local observer lets the read-only performance card correlate
-- events already emitted by independent Gen-1/Gen-2 Cards. It never changes
-- event ownership or persists callbacks in a save.
function Diagnostics.setPerformanceObserver(observer)
  performanceObserver = type(observer) == "function" and observer or nil
  return performanceObserver ~= nil
end

function Diagnostics.sessionFile()
  return ensureSession()
end

function Diagnostics.sessionId()
  return sharedSessionId()
end

function Diagnostics.supportStatus(caller)
  local recorderPath = ensureSession()
  -- A player opening the status page is an explicit visibility boundary.
  -- The 10-second monitor sampler uses the non-forcing caller token so it
  -- cannot trigger a full compatibility-file rewrite every snapshot.
  if caller == "monitor-snapshot" then
    flushRepeat()
    flushPending(false)
  else
    Diagnostics.flush("support-status")
  end
  -- storageFilesystem already resolved either the active playthrough or the
  -- engine's non-allocating selected-title binding. Calling the direct context
  -- method again here could mint an identity on a fresh title skeleton.
  local context = storageContext
  return {
    owner=Diagnostics.OWNER,
    schema=Diagnostics.SCHEMA,
    -- `path` stays the copy/paste support contract and is therefore present
    -- only for a real, verified .log. recorderPath names the opaque internal
    -- source and must not be shown as if it were a browsable file.
    path=readableState == "active" and readablePath or nil,
    recorderPath=recorderPath,
    sessionId=sharedSessionId(),
    bytes=sessionBytes,
    maxBytes=Diagnostics.MAX_BYTES,
    maxSessions=Diagnostics.MAX_SESSIONS,
    retentionSeconds=Diagnostics.RETENTION_SECONDS,
    capped=sessionCapped,
    alwaysOn=true,
    platform=runtimeOS(),
    recording=recorderPath and storageRecorderState == "active"
      and "ACTIVE" or "FAILED",
    readableLog=readableState == "active" and "ACTIVE"
      or readableState == "failed" and "FAILED" or "UNAVAILABLE",
    readableDirectory=readableState == "active" and readablePath
      and readablePath:match("^(.*)/[^/]+$") or Diagnostics.DIRECTORY,
    readablePath=readableState == "active" and readablePath or nil,
    readableBytes=readableBytes,
    readableBufferedBytes=readablePendingBytes,
    readableFlushCount=readableFlushCount,
    readableBackend=storagePublishState == "active"
      and "mod.storage/support-log"
      or readableFilesystem() and "love.filesystem/legacy-mod-private"
      or "unavailable",
    readableError=readableError,
    -- Platform Files/Documents export is intentionally independent and is no
    -- longer required. publishSupportLog is the mod-private readable file,
    -- not an export claim.
    export="UNAVAILABLE",
    exportDirectory=nil,
    exportFile=nil,
    exportRelativePath=nil,
    backend=storageBackend,
    storageError=storageLastError,
    exportError=nil,
    bufferedBytes=pendingBytes,
    flushCount=flushCount,
    internalAppend=storageBackend == "love.filesystem"
      or type(scopedFilesystem) == "table"
        and scopedFilesystem.expensiveAppend ~= true,
    publicAppend=type(scopedFilesystem) == "table"
      and scopedFilesystem.publicAppend == true,
    gameVersion=context and context.gameVersion or nil,
    playthroughId=context and context.playthroughId or nil,
  }
end

function Diagnostics.markRepro(state)
  state = state == "end" and "end" or "begin"
  return Diagnostics.write("vasc.ui.repro-marker-" .. state, {
    action=state,
    status="user-marked",
  })
end

function Diagnostics.registerSegment(descriptor)
  if type(descriptor) ~= "table" then return false, "invalid-segment" end
  local id = clean(descriptor.segmentId or descriptor.cardId, 96)
  if id == "nil" or id == "" then return false, "missing-segment-id" end
  local row = {
    segmentId=id,
    cardId=descriptor.cardId or id,
    version=descriptor.version or descriptor.schema or "unknown",
    schema=descriptor.schema or "unknown",
    owner=descriptor.owner or "unknown",
    active=descriptor.active == false and false or true,
    dependencyStatus=descriptor.dependencyStatus or "unknown",
    providerStatus=descriptor.providerStatus or "unknown",
    buildReceiptId=descriptor.buildReceiptId or "unknown",
    rollbackReceiptId=descriptor.rollbackReceiptId or "unknown",
    status=descriptor.pureData == true and "pure-data/no-runtime-events"
      or "runtime-events-registered",
  }
  segmentInventory[id] = row
  if bootLogged and not segmentLogged[id] then
    segmentLogged[id] = true
    Diagnostics.write("vasc.core.segment-inventory", row)
  end
  return true
end

local function emitSegmentInventory()
  local ids = {}
  for id in pairs(segmentInventory) do ids[#ids + 1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do
    if not segmentLogged[id] then
      segmentLogged[id] = true
      Diagnostics.write("vasc.core.segment-inventory", segmentInventory[id])
    end
  end
end

function Diagnostics.finalize(status)
  if sessionFinalized then return true end
  flushRepeat()
  emitRaw("vasc.core.session-summary", {
    status=status or (summary.abnormal and "abnormal" or "normal"),
    firstError=summary.firstError or "none",
    count=summary.errors,
    warning=summary.warnings,
    fallback=summary.fallbacks,
    mapId=summary.lastMap or "unknown",
    sceneId=summary.lastScene or "unknown",
  })
  local ok = emitRaw("vasc.core.session-finalized", {
    status=status or (summary.abnormal and "abnormal" or "normal"),
  })
  local flushed = Diagnostics.flush("session-finalized")
  sessionFinalized = ok == true and flushed == true
  return sessionFinalized
end

function Diagnostics.deleteOwnLogs()
  Diagnostics.flush("before-delete")
  local filesystem = fs()
  if not (filesystem and type(filesystem.getDirectoryItems) == "function"
      and type(filesystem.remove) == "function") then
    return false, "filesystem-remove-unavailable"
  end
  local mirror = readableFilesystem()
  local candidates = {}
  for _, name in ipairs(logNames(filesystem)) do candidates[name] = true end
  if mirror and mirror ~= filesystem then
    for _, name in ipairs(logNames(mirror)) do candidates[name] = true end
  end
  local removed = 0
  for name in pairs(candidates) do
    local deleted = removeOwn(filesystem, name)
    if mirror and mirror ~= filesystem then
      deleted = removeOwn(mirror, name) or deleted
    end
    if deleted then removed = removed + 1 end
  end
  sessionFile, sessionBytes, sessionCapped = nil, 0, false
  sessionFinalized, sessionSequence, sessionStartedAt = false, 0, nil
  repeatEvent, repeatSignature, repeatCount = nil, nil, 0
  pendingChunks, pendingBytes, pendingEvents, pendingSince = {}, 0, 0, nil
  readableState, readablePath, readableError = "unavailable", nil, nil
  readableBytes, readableFlushCount = 0, 0
  readablePendingChunks, readablePendingBytes, readablePendingSince = {}, 0, nil
  Diagnostics.FILE = Diagnostics.DIRECTORY
  if not ensureSession() then return false, "new-session-unavailable" end
  Diagnostics.write("vasc.ui.logs-deleted", {
    action="own-support-logs-only", count=removed, status="recording",
  })
  Diagnostics.flush("logs-deleted")
  return true, removed
end

local RECOVERY_MARKER_KEYS = {
  "kind", "schema", "build", "mode", "phase", "status", "generation",
  "checkpoint",
}

local RECOVERY_MARKER_LIMITS = {
  kind=32, schema=96, build=96, mode=32, phase=64, status=32,
  generation=16, checkpoint=112,
}
local RECOVERY_MARKER_KEY_SET = {}
for _, key in ipairs(RECOVERY_MARKER_KEYS) do
  RECOVERY_MARKER_KEY_SET[key] = true
end
Diagnostics.MOBILE_RECOVERY_FIELDS = {}
for index, key in ipairs(RECOVERY_MARKER_KEYS) do
  Diagnostics.MOBILE_RECOVERY_FIELDS[index] = key
end
local loadedRecoveryMarkerPath = nil

local function recoveryClean(value, key)
  value = clean(value):gsub("=", ":")
  local limit = RECOVERY_MARKER_LIMITS[key] or 160
  if #value > limit then value = value:sub(1, limit) .. "..." end
  return value
end

local function parseRecoveryMarker(payload, strict)
  if type(payload) ~= "string" or payload == "" then
    return nil, "recovery-marker-missing"
  end
  if #payload > Diagnostics.MOBILE_RECOVERY_MAX_BYTES then
    return nil, "recovery-marker-too-large"
  end
  local out, seen = {}, {}
  for entry in payload:gmatch("[^\r\n]+") do
    local key, value = entry:match("^([%a][%w]*)=(.*)$")
    if not key then return nil, "recovery-marker-malformed" end
    if RECOVERY_MARKER_KEY_SET[key] then
      if seen[key] then return nil, "recovery-marker-duplicate-field" end
      seen[key], out[key] = true, value
    elseif strict then
      return nil, "recovery-marker-field-not-allowlisted"
    end
  end
  for _, key in ipairs(RECOVERY_MARKER_KEYS) do
    -- Legacy markers predate the explicit kind field. All other decision
    -- inputs were already present and remain required for safe migration.
    if not (key == "kind" and not strict) and out[key] == nil then
      return nil, "recovery-marker-incomplete"
    end
  end
  if strict and out.kind ~= Diagnostics.MOBILE_RECOVERY_KIND then
    return nil, "recovery-marker-kind-invalid"
  end
  return out
end

local function readRecoveryFile(filesystem, path, strict)
  local ok, payload = pcall(filesystem.read, path)
  if not ok or type(payload) ~= "string" or payload == "" then
    return nil, "recovery-marker-missing"
  end
  return parseRecoveryMarker(payload, strict)
end

function Diagnostics.readMobileRecoveryMarker()
  -- Mobile crash-loop latches must not force Windows desktop boots into 2D.
  if runtimeOS() == "Windows" then
    return nil, "recovery-marker-disabled-on-windows"
  end
  local filesystem = fs()
  if not (filesystem and type(filesystem.read) == "function") then
    return nil, "filesystem-read-unavailable"
  end
  local marker, reason = readRecoveryFile(filesystem,
    Diagnostics.MOBILE_RECOVERY_MARKER, true)
  if marker then
    loadedRecoveryMarkerPath = Diagnostics.MOBILE_RECOVERY_MARKER
    return marker
  end
  -- A malformed new-format marker is not replaced by possibly stale legacy
  -- state. Only a genuinely absent new marker activates the upgrade bridge.
  if reason ~= "recovery-marker-missing" then return nil, reason end
  marker, reason = readRecoveryFile(filesystem,
    Diagnostics.LEGACY_MOBILE_RECOVERY_MARKER, false)
  if marker then
    loadedRecoveryMarkerPath = Diagnostics.LEGACY_MOBILE_RECOVERY_MARKER
    return marker
  end
  return nil, reason
end

function Diagnostics.writeMobileRecoveryMarker(fields)
  -- Avoid synchronous mobile-marker I/O from Windows renderer callbacks.
  -- Normal bounded support/session logging remains enabled.
  if runtimeOS() == "Windows" then return true, nil end
  local filesystem = fs()
  if not (filesystem and type(filesystem.write) == "function") then
    return false, "filesystem-write-unavailable"
  end
  fields = type(fields) == "table" and fields or {}
  if fields.kind ~= Diagnostics.MOBILE_RECOVERY_KIND then
    return false, "recovery-marker-kind-invalid"
  end
  local lines = {}
  for _, key in ipairs(RECOVERY_MARKER_KEYS) do
    if fields[key] == nil then
      return false, "recovery-marker-incomplete:" .. key
    end
    lines[#lines + 1] = key .. "=" .. recoveryClean(fields[key], key)
  end
  local payload = table.concat(lines, "\n") .. "\n"
  if #payload > Diagnostics.MOBILE_RECOVERY_MAX_BYTES then
    return false, "recovery-marker-too-large"
  end
  local ok, result = pcall(filesystem.write,
    Diagnostics.MOBILE_RECOVERY_MARKER, payload)
  if not ok then return false, tostring(result) end
  if result ~= false then
    loadedRecoveryMarkerPath = Diagnostics.MOBILE_RECOVERY_MARKER
  end
  return result ~= false, nil
end

local function recoveryFilePresent(filesystem, path)
  if type(filesystem.read) ~= "function" then return nil end
  local ok, payload = pcall(filesystem.read, path)
  return ok and type(payload) == "string" and payload ~= ""
end

function Diagnostics.clearMobileRecoveryMarker()
  local filesystem = fs()
  if not (filesystem and type(filesystem.remove) == "function") then
    return false, "filesystem-remove-unavailable"
  end
  local paths = {
    Diagnostics.MOBILE_RECOVERY_MARKER,
    Diagnostics.LEGACY_MOBILE_RECOVERY_MARKER,
  }
  local removed = false
  for _, path in ipairs(paths) do
    local present = recoveryFilePresent(filesystem, path)
    local required = present == true or path == loadedRecoveryMarkerPath
    if required then
      local ok, result = pcall(filesystem.remove, path)
      if not ok or result == false then
        return false, tostring(ok and "recovery-marker-remove-failed" or result)
      end
      removed = true
    end
  end
  if not removed then return false, "recovery-marker-missing" end
  loadedRecoveryMarkerPath = nil
  return true, nil
end

function Diagnostics.setEnabled(explicit, value)
  active = value == true
  if not active then megaLimitBypass = false end
  local owner = bucket(explicit, true)
  if owner then owner.rcDiagnostics = active end
  local g = game(explicit)
  if g and type(g.writeOptions) == "function" then pcall(g.writeOptions, g) end
  Diagnostics.write(active and "diagnostics-enabled" or "diagnostics-disabled", {
    version=V and V.mod and V.mod._vascPackageVersion or "unknown",
    status=active and "enabled" or "disabled",
  })
  return active
end

function Diagnostics.megaLimitBypass(explicit)
  return Diagnostics.enabled(explicit) and megaLimitBypass == true
end

function Diagnostics.setMegaLimitBypass(explicit, value)
  if not Diagnostics.enabled(explicit) then
    megaLimitBypass = false
    return false
  end
  megaLimitBypass = value == true
  Diagnostics.write("mega-qa-limit", {
    mode=megaLimitBypass and "unlimited-session" or "normal",
    status=megaLimitBypass and "active" or "disabled",
  })
  return megaLimitBypass
end

local function runtimeMetadata()
  local width, height, dpi = 0, 0, 1
  if love and love.graphics then
    if type(love.graphics.getDimensions) == "function" then
      local ok, w, h = pcall(love.graphics.getDimensions)
      if ok then width, height = tonumber(w) or 0, tonumber(h) or 0 end
    end
    if type(love.graphics.getDPIScale) == "function" then
      local ok, value = pcall(love.graphics.getDPIScale)
      if ok then dpi = tonumber(value) or 1 end
    end
  end
  local orientation = "unknown"
  if love and love.window and type(love.window.getDisplayOrientation) == "function" then
    local ok, value = pcall(love.window.getDisplayOrientation)
    if ok and value ~= nil then orientation = tostring(value) end
  end
  local renderer = "unknown"
  if love and love.graphics and type(love.graphics.getRendererInfo) == "function" then
    local ok, name = pcall(love.graphics.getRendererInfo)
    if ok and name ~= nil then renderer = tostring(name) end
  end
  return {
    os=runtimeOS(), renderer=renderer,
    windowWidth=width, windowHeight=height,
    canvasWidth=width, canvasHeight=height,
    dpi=dpi, orientation=orientation,
    inputMode="unknown",
  }
end

function Diagnostics.boot(explicit)
  bindGame(explicit)
  local enabled = Diagnostics.enabled(explicit)
  if booted and bootLogged then return enabled end
  booted = true
  if not ensureSession() then return enabled end
  Diagnostics.registerSegment({
    cardId="VASC-66-SUPPORT-SESSION-LOG",
    version="v1", schema=Diagnostics.SCHEMA, owner=Diagnostics.OWNER,
    active=true, dependencyStatus="ready", providerStatus="active",
    buildReceiptId="support-session-log-vertical-slice",
    rollbackReceiptId="VASC_66_DIAGNOSTICS_POLISH_ROLLBACK",
  })
  Diagnostics.registerSegment({
    cardId="VASC-66-DIAGNOSTICS-POLISH",
    version="v1", schema="vasc-rc-diagnostics/v1",
    owner="vasc.rc-diagnostics-polish/v1", active=enabled,
    dependencyStatus="ready",
    providerStatus=enabled and "active" or "locked",
    buildReceiptId="diagnostics-polish-vertical-slice",
    rollbackReceiptId="VASC_66_DIAGNOSTICS_POLISH_ROLLBACK",
  })
  Diagnostics.registerSegment({
    cardId="M10-MOBILE-FINAL", version="rc12-m10-m11-converged",
    schema="vasc-mobile-recovery-marker/rc12-m10-m11-converged",
    owner="mobile-render-lifecycle-and-direct-neighbor-stream",
    active=true, dependencyStatus="ready", providerStatus="active",
    buildReceiptId="vasc-m11-completion-evidence-20260903",
    rollbackReceiptId="M10-final-source-66021f",
  })
  local metadata = runtimeMetadata()
  metadata.version = V and V.mod and V.mod._vascPackageVersion or "unknown"
  metadata.engineVersion = V and V.mod and V.mod._vascEngineVersion or "unknown"
  metadata.packageHash = V and V.mod and V.mod._vascPackageHash or "unknown"
  metadata.generation = V and V.mod and V.mod._vascHostGeneration or "unknown"
  metadata.maintainerPanel = enabled and "enabled" or "disabled"
  metadata.retention = Diagnostics.MAX_SESSIONS
  metadata.maxBytes = Diagnostics.MAX_BYTES
  metadata.owner = Diagnostics.OWNER
  metadata.schema = Diagnostics.SCHEMA
  Diagnostics.write("game-start", metadata)
  bootLogged = true
  if previousIncomplete then
    Diagnostics.write("previous-session-incomplete", {
      source=previousIncomplete,
      status="previous_session_incomplete",
    })
  end
  emitSegmentInventory()
  Diagnostics.flush("boot-complete")
  return enabled
end

return Diagnostics
