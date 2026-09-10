-- Bounded RC flight recorder.  One plain-text log is created for every VASC
-- process session, regardless of whether the maintainer panel is unlocked.
-- At most five sessions survive and every file is capped at 8 MiB, so useful
-- evidence exists after a rare crash without allowing diagnostics to grow
-- without bound or recording save contents.

local V = ...
local Diagnostics = {}

Diagnostics.CODE = "2712"
Diagnostics.DIRECTORY = "VASC-Logs"
Diagnostics.FILE = Diagnostics.DIRECTORY
Diagnostics.MAX_SESSIONS = 5
-- Event-driven rather than per-frame: 8 MiB still holds tens of thousands of
-- lifecycle records, while the five-file ring can never exceed 40 MiB.
Diagnostics.MAX_BYTES = 8 * 1024 * 1024
local active
-- Deliberately not persisted.  Maintainers may temporarily lift only the
-- one-Mega-per-battle presentation gate after unlocking diagnostics with the
-- code.  Restarting the game or disabling diagnostics always restores the
-- normal KASC rule.
local megaLimitBypass = false
local booted = false
local bootLogged = false
local sessionFile
local sessionBytes = 0
local sessionCapped = false

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
  -- A mod may be loaded before the engine has attached the selected save.
  -- Whenever a concrete game object is supplied, let its persisted bucket
  -- settle the cached value instead of preserving an early false forever.
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

local function clean(value)
  value = tostring(value == nil and "nil" or value)
  value = value:gsub("[\r\n\t]", " ")
  return value
end

local function timestamp()
  return os and os.date and os.date("!%Y-%m-%dT%H:%M:%SZ") or "time-unavailable"
end

local function line(event, fields)
  local parts = { timestamp(), clean(event) }
  local entries = {}
  for key, value in pairs(type(fields) == "table" and fields or {}) do
    entries[#entries + 1] = { key=tostring(key), value=value }
  end
  table.sort(entries, function(a, b) return a.key < b.key end)
  for _, entry in ipairs(entries) do
    parts[#parts + 1] = entry.key .. "=" .. clean(entry.value)
  end
  return table.concat(parts, "\t") .. "\n"
end

local function fs()
  return love and love.filesystem or nil
end

local function logNames(filesystem)
  local ok, items = pcall(filesystem.getDirectoryItems, Diagnostics.DIRECTORY)
  if not ok or type(items) ~= "table" then return {} end
  local names = {}
  for _, name in ipairs(items) do
    if type(name) == "string"
        and name:match("^VASC%-SESSION%-.+%.log$") then
      names[#names + 1] = name
    end
  end
  table.sort(names)
  return names
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
  local names = logNames(filesystem)
  -- Rotate before creating the new session: the sixth start removes exactly
  -- the oldest of the five existing logs, leaving five again afterwards.
  while #names >= Diagnostics.MAX_SESSIONS do
    local oldest = table.remove(names, 1)
    if type(filesystem.remove) == "function" then
      pcall(filesystem.remove, Diagnostics.DIRECTORY .. "/" .. oldest)
    else
      break
    end
  end
  local stamp = os and os.date and os.date("!%Y%m%dT%H%M%SZ")
    or tostring(math.floor((love.timer and love.timer.getTime
      and love.timer.getTime() or 0) * 1000))
  local generation = tostring(V and V.mod and V.mod._vascHostGeneration or "x")
  local base = "VASC-SESSION-" .. stamp .. "-G" .. generation
  local name = base .. ".log"
  local used = {}
  for _, existing in ipairs(names) do used[existing] = true end
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
  return sessionFile
end

local supportTail, supportTailBytes = {}, 0
local function append(payload)
  supportTail[#supportTail + 1] = payload
  supportTailBytes = supportTailBytes + #payload
  while supportTailBytes > 1024 * 1024 and #supportTail > 1 do
    supportTailBytes = supportTailBytes - #table.remove(supportTail, 1)
  end
  local filesystem = fs()
  local path = ensureSession()
  if not (filesystem and path and type(filesystem.append) == "function")
      or sessionCapped then return false end
  payload = tostring(payload or "")
  local room = Diagnostics.MAX_BYTES - sessionBytes
  if room <= 0 then sessionCapped = true; return false end
  if #payload > room then
    local marker = line("log-size-limit", {
      maxBytes=Diagnostics.MAX_BYTES,
      action="further-events-dropped",
    })
    if #marker <= room then payload = marker else payload = payload:sub(1, room) end
    sessionCapped = true
  end
  local ok, result = pcall(filesystem.append, path, payload)
  if ok and result ~= false then
    sessionBytes = sessionBytes + #payload
    return true
  end
  return false
end

function Diagnostics.write(event, fields)
  -- Always-on bounded lifecycle evidence. Diagnostics.enabled() continues to
  -- control the maintainer UI and dangerous QA bypasses, never file creation.
  return append(line(event, fields))
end

function Diagnostics.supportPayload()
  local filesystem, path = fs(), ensureSession()
  local ok, bytes = false, nil
  if filesystem and path and type(filesystem.read) == "function" then
    ok, bytes = pcall(filesystem.read, path)
  end
  if not ok or type(bytes) ~= "string" or #bytes == 0 then bytes = "VASC Gen2 current-session tail\n" .. table.concat(supportTail) end
  if type(bytes) ~= "string" or #bytes == 0 then return nil, "no-log" end
  return bytes
end
local supportSender
function Diagnostics.openSupportSend(explicit, de)
  if not supportSender then
    local source = assert(V.mod:read("lib/SupportSend.lua"))
    supportSender = assert((loadstring or load)(source, "@SupportSend"))().new(V.mod, Diagnostics.supportPayload)
  end
  return supportSender.open(explicit, de)
end

function Diagnostics.setEnabled(explicit, value)
  active = value == true
  if not active then megaLimitBypass = false end
  local owner = bucket(explicit, true)
  if owner then owner.rcDiagnostics = active end
  local g = game(explicit)
  if g and type(g.writeOptions) == "function" then pcall(g.writeOptions, g) end
  append(line(active and "diagnostics-enabled" or "diagnostics-disabled", {
    version=V and V.mod and V.mod._vascPackageVersion or "unknown",
    canonical=ensureSession() or "unavailable",
    automaticSessionLogs=true,
  }))
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
  })
  return megaLimitBypass
end

function Diagnostics.boot(explicit)
  local enabled = Diagnostics.enabled(explicit)
  if booted then return enabled end
  booted = true
  ensureSession()
  Diagnostics.write("game-start", {
    version=V and V.mod and V.mod._vascPackageVersion or "unknown",
    generation=V and V.mod and V.mod._vascHostGeneration or "unknown",
    maintainerPanel=enabled and "enabled" or "disabled",
    retention=Diagnostics.MAX_SESSIONS,
    maxBytes=Diagnostics.MAX_BYTES,
  })
  bootLogged = true
  return enabled
end

function Diagnostics.sessionFile()
  return ensureSession()
end

return Diagnostics
