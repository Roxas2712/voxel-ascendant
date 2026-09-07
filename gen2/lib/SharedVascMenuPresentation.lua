-- Presentation-only bridge from Gold/Silver/Crystal screens to the exact
-- VASC menu renderer already used by Gen 1.  The native Gen-2 screen remains
-- the input, navigation, callback and persistence owner; this object mirrors
-- only its currently visible labels into a disposable view model.

local C = ... or {}
local mod = C.mod
local Style = C.Style
local Diagnostics = type(C.Diagnostics) == "table" and C.Diagnostics or {}
local CanvasPresentation = C.CanvasPresentation

local M = { installed=false, lastError=nil }

local function diagnostic(event, fields)
  if type(Diagnostics.write) == "function" then
    pcall(Diagnostics.write, event, fields)
  end
end

local function qaLog(line)
  local driver = os and os.getenv and os.getenv("POKEPORT_DRIVER") or ""
  if not tostring(driver):find("gen2%-a4%-ui%-smoke") then return end
  local fs = love and love.filesystem
  if fs and type(fs.append) == "function" then
    pcall(fs.append, "gen2-a4-provider-load.txt", tostring(line) .. "\n")
  end
end

local function language()
  if not (mod and type(mod.find) == "function") then return "en" end
  local ok, handle = pcall(mod.find, "translation-german-universal")
  if not ok or not handle then
    ok, handle = pcall(mod.find, mod, "translation-german-universal")
  end
  local boot = ok and type(handle) == "table" and handle.exports
  return type(boot) == "table" and boot.bootLanguage == "de" and "de" or "en"
end

local function defaultFooter()
  return language() == "de" and "A: AUSWAHL   B: ZURÜCK" or "A: SELECT   B: BACK"
end

local function regionHeader(owner)
  local game = type(owner) == "table" and owner.game or nil
  local save = type(game) == "table" and game.save or nil
  local flags = type(save) == "table" and save.flags or nil
  return type(flags) == "table" and flags.HALL_OF_FAME == true
    and "VOXEL ASCENDANT / JOHTO / KANTO"
    or "VOXEL ASCENDANT / JOHTO"
end

local presenter
local adapters = setmetatable({}, { __mode="k" })

local function sharedPresenter()
  if presenter then return presenter end
  if not (Style and type(Style.new) == "function") then
    return nil, "VascMenuStyle.new unavailable"
  end
  local ok, value = pcall(Style.new, mod, {
    skin=function() return "oras_fullscreen" end,
    language=language,
  })
  if not ok or type(value) ~= "table"
      or type(value.decorateFocusHelp) ~= "function" then
    return nil, tostring(value or "VascMenuStyle presenter unavailable")
  end
  presenter = value
  return presenter
end

local function normalizedItem(item)
  item = type(item) == "table" and item or { label=tostring(item or "") }
  return {
    label=tostring(item.label or item.name or item.value or ""),
    right=item.right ~= nil and tostring(item.right)
      or (item.value ~= nil and tostring(item.value) or nil),
    help=tostring(item.help or item.meta or item.description or ""),
    value=item.id or item.value,
    disabled=item.disabled,
  }
end

local function adapterFor(owner)
  local adapter = adapters[owner]
  if adapter then return adapter end
  local style, err = sharedPresenter()
  if not style then return nil, err end
  adapter = {
    game=owner and owner.game,
    title="VOXEL ASCENDANT",
    items={}, index=1, scroll=0, rows=9,
    footer=defaultFooter(),
    draw=function() end,
    update=function() end,
  }
  local ok, decorated = pcall(style.decorateFocusHelp, adapter, nil, 9)
  if not ok or decorated ~= adapter then
    return nil, tostring(decorated or "VASC decoration failed")
  end
  adapters[owner] = adapter
  return adapter
end

function M.draw(owner, spec, winW, winH)
  if type(owner) ~= "table" or type(spec) ~= "table" then return false end
  local adapter, err = adapterFor(owner)
  if not adapter then M.lastError = err qaLog("draw.adapter=" .. tostring(err)) return false end
  local items = {}
  for _, item in ipairs(spec.items or {}) do
    items[#items + 1] = normalizedItem(item)
  end
  adapter.game = owner.game
  adapter.title = tostring(spec.title or "VOXEL ASCENDANT")
  adapter.items = items
  adapter.index = math.max(1, math.min(#items > 0 and #items or 1,
    math.floor(tonumber(spec.index) or 1)))
  adapter.scroll = math.max(0, math.floor(tonumber(spec.scroll) or 0))
  adapter.rows = math.max(1, math.floor(tonumber(spec.rows) or 9))
  adapter.footer = tostring(spec.footer or defaultFooter())
  adapter.__vascLanguage = language()
  adapter.__vascHeaderLabel = tostring(spec.header
    or regionHeader(owner))
  adapter.ascendantFocusTime = love and love.timer
    and type(love.timer.getTime) == "function" and love.timer.getTime() or 0
  local drawer = adapter.drawWidescreen or adapter.draw
  if type(drawer) ~= "function" then
    M.lastError = "decorated VASC draw unavailable"
    diagnostic("gen2-menu-provider", {
      provider="VascMenuStyle", result="fallback", reason=M.lastError,
      screen=spec.title,
    })
    qaLog("draw.drawer=" .. M.lastError)
    return false
  end
  if CanvasPresentation
      and (CanvasPresentation.OS == "iOS"
        or CanvasPresentation.OS == "Android") then
    local G = love and love.graphics
    if G and type(G.getDimensions) == "function" then
      local okDims, w, h = pcall(G.getDimensions)
      if okDims and w and h and w > 0 and h > 0 then
        winW, winH = w, h
      end
    end
  end
  local ok, result = pcall(drawer, adapter, winW, winH)
  if not ok then
    M.lastError = tostring(result)
    diagnostic("gen2-menu-provider", {
      provider="VascMenuStyle", result="error", reason=M.lastError,
      screen=spec.title,
    })
    qaLog("draw.error=" .. M.lastError)
    return false
  end
  if not rawget(owner, "_vascGen2SharedMenuLogged") then
    rawset(owner, "_vascGen2SharedMenuLogged", true)
    diagnostic("gen2-menu-provider", {
      provider="VascMenuStyle", result="active", screen=spec.title,
      items=#items,
    })
  end
  M.lastError = nil
  return true
end

function M.install()
  local value, err = sharedPresenter()
  M.installed = value ~= nil
  M.lastError = err
  diagnostic("gen2-menu-provider-install", {
    provider="VascMenuStyle", installed=M.installed, reason=err,
  })
  qaLog("style.type=" .. type(Style))
  qaLog("install=" .. tostring(M.installed))
  qaLog("install.error=" .. tostring(err))
  return M.installed, err
end

function M.status()
  return { installed=M.installed, lastError=M.lastError }
end

return M
