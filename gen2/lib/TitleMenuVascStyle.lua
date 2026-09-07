-- Full-surface, edition-coloured presentation for the engine-owned title
-- choices and CONTINUE receipt. Navigation, phase changes and callbacks stay
-- entirely native; this adapter supplies a disposable view model only.

local V = ... or {}
local mod = V.mod
local SharedMenus = V.SharedMenuPresentation
local TitleHub = V.TitleHubPresentation
local Diagnostics = type(V.Diagnostics) == "table" and V.Diagnostics or {}
local CanvasPresentation = V.CanvasPresentation

local M = {
  installed=false, decorated=0, draws=0, lastError=nil,
  target="Gen2 MainMenu list/phase",
}

local function diagnostic(event, fields)
  if type(Diagnostics.write) == "function" then
    pcall(Diagnostics.write, event, fields)
  end
end

local function enabled() return true end

local function dimensions(ww, wh)
  local mobile = CanvasPresentation
    and (CanvasPresentation.OS == "iOS"
      or CanvasPresentation.OS == "Android")
  local G = love and love.graphics
  if mobile and G and type(G.getDimensions) == "function" then
    local ok, w, h = pcall(G.getDimensions)
    if ok and w and h and w > 0 and h > 0 then return w, h end
  end
  if tonumber(ww) and tonumber(wh) and ww > 0 and wh > 0 then
    return ww, wh
  end
  if not G then return nil, nil end
  if type(G.getCanvas) == "function" then
    local ok, canvas = pcall(G.getCanvas)
    if ok and canvas and type(canvas.getDimensions) == "function" then
      local cw, ch = canvas:getDimensions()
      if cw and ch and cw > 0 and ch > 0 then return cw, ch end
    end
  end
  if type(G.getDimensions) == "function" then return G.getDimensions() end
  return nil, nil
end

M.mobileWindowForQA = dimensions

local function clean(value)
  value = tostring(value or "")
  value = value:gsub("<PO><KE>", "POKé"):gsub("<PK><MN>", "POKéMON")
  value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return value
end

local function canonicalTitleLabel(value)
  local upper = clean(value):upper()
  if upper == "CONTINUE" or upper == "WEITER" then return "WEITER" end
  if upper == "NEW GAME" or upper == "NEUES SPIEL" then return "NEUES SPIEL" end
  if upper == "OPTION" or upper == "OPTIONS" or upper == "OPTIONEN" then
    return "OPTIONEN"
  end
  if upper == "EXIT GAME" or upper == "QUIT" or upper == "BEENDEN" then
    return "SPIEL BEENDEN"
  end
  return clean(value)
end

local function stateItems(state)
  if type(state) ~= "table" then return nil end
  if type(state.items) == "table" then return state.items end
  return type(state.list) == "table" and state.list.items or nil
end

local function stateIndex(state)
  if type(state) ~= "table" then return 1 end
  if tonumber(state.index) then return tonumber(state.index) end
  return type(state.list) == "table" and tonumber(state.list.index) or 1
end

local function interfaceLanguage(state)
  local finder = mod and mod.find
  if type(finder) == "function" then
    local ok, universal = pcall(finder, "translation-german-universal")
    if not ok then ok, universal = pcall(finder, mod,
      "translation-german-universal") end
    if ok and universal then
      local boot = type(universal) == "table" and universal.exports
        and universal.exports.bootLanguage
      if boot == "de" or boot == "en" then return boot end
      return "de"
    end
    for _, id in ipairs({"universal_german", "deutsch", "deutsch-blau",
        "deutsch-gelb"}) do
      local found, handle = pcall(finder, id)
      if not found then found, handle = pcall(finder, mod, id) end
      if found and handle then return "de" end
    end
  end
  return "en"
end

local function saveVersion(state)
  local save = state and (state.save or (state.game and state.game.save)) or nil
  local value = type(save) == "table" and save.version or nil
  local ok, GameVersion = pcall(require, "src.core.GameVersion")
  if (value == nil or value == "") and ok and type(GameVersion) == "table"
      and type(GameVersion.get) == "function" then
    local got, active = pcall(GameVersion.get)
    if got then value = active end
  end
  value = tostring(value or "crystal"):lower()
  if value:find("gold", 1, true) then return "gold" end
  if value:find("silver", 1, true) then return "silver" end
  return "crystal"
end

local function isTitleChoice(state)
  local items = stateItems(state)
  if type(state) ~= "table" or type(items) ~= "table" or #items < 2
      or state.phase == "confirm" then return false end
  local sawGame, sawOption = false, false
  for _, item in ipairs(items) do
    local label = canonicalTitleLabel(type(item) == "table" and item.label or item)
    if label == "WEITER" or label == "NEUES SPIEL" then sawGame = true end
    if label == "OPTIONEN" then sawOption = true end
  end
  return sawGame and sawOption
end

local function isContinueInfo(state)
  return type(state) == "table" and type(state.save) == "table"
    and (state.phase == "confirm"
      or (type(state.titleUiBox) == "table" and stateItems(state) == nil))
end

local function ownedCount(save)
  local n = 0
  for _ in pairs(type(save.pokedex) == "table"
      and type(save.pokedex.owned) == "table" and save.pokedex.owned or {}) do
    n = n + 1
  end
  return n
end

local function badgeCount(state)
  local ok, Badges = pcall(require, "src.inventory.Badges")
  if not ok or type(Badges) ~= "table" or type(Badges.count) ~= "function" then
    return 0
  end
  local counted, n = pcall(Badges.count, state.game.data, state.save)
  return counted and tonumber(n) or 0
end

local function drawTitleChoice(state, ww, wh)
  local sourceItems = stateItems(state) or {}
  local items = {}
  for _, item in ipairs(sourceItems) do
    local label = canonicalTitleLabel(type(item) == "table" and item.label or item)
    items[#items + 1] = { label=label }
  end
  local spec = {
    edition=saveVersion(state), language=interfaceLanguage(state),
    game=state.game, generation=2,
    showArtwork=true,
    items=items,
    index=stateIndex(state),
    footer="STEUERKREUZ: AUSWAHL   A: BESTÄTIGEN   B: ZURÜCK",
  }
  if TitleHub and type(TitleHub.drawPhysical) == "function" then
    return TitleHub.drawPhysical(spec, ww, wh)
  end
  return SharedMenus and type(SharedMenus.draw) == "function"
    and SharedMenus.draw(state, spec, ww, wh) or false
end

local function drawContinueInfo(state, ww, wh)
  local save = state.save
  local player = type(save.player) == "table" and save.player or {}
  local seconds = math.max(0, math.floor(tonumber(save.playTime) or 0))
  local spec = {
    edition=saveVersion(state), language=interfaceLanguage(state),
    game=state.game, generation=2,
    showArtwork=false,
    items={
      { label="TRAINER", right=clean(player.name or "GOLD"),
        },
      { label="BADGES", right=tostring(badgeCount(state)) },
      { label="POKéDEX", right=tostring(ownedCount(save)) },
      { label="PLAY TIME", right=("%d:%02d"):format(
          math.floor(seconds / 3600), math.floor(seconds / 60) % 60) },
    },
    index=1,
    footer="A: WEITER   B: ZURÜCK",
  }
  if TitleHub and type(TitleHub.drawPhysical) == "function" then
    return TitleHub.drawPhysical(spec, ww, wh)
  end
  return SharedMenus and type(SharedMenus.draw) == "function"
    and SharedMenus.draw(state, spec, ww, wh) or false
end

local function drawDecorated(state, ww, wh)
  local width, height = dimensions(ww, wh)
  if not width or not height then return false end
  if isTitleChoice(state) then return drawTitleChoice(state, width, height) end
  if isContinueInfo(state) then return drawContinueInfo(state, width, height) end
  return false
end

local function decorate(state)
  if not (isTitleChoice(state) or isContinueInfo(state)) then return false end
  if state.__vascGen2TitleMenuPresentation then return true end
  local nativeDraw = state.draw
  if type(nativeDraw) ~= "function" then return false end
  local nativeWide = type(state.drawWidescreen) == "function"
    and state.drawWidescreen or nil
  local nativeUiSize = state.uiSize
  local nativeDrawsWide = state.drawsWidescreen
  local nativeFill = state.wantsFillScale

  state.draw = function(self, ...)
    if enabled() then
      local ok, handled = pcall(drawDecorated, self)
      if ok and handled then M.draws = M.draws + 1 M.lastError = nil return end
      if not ok then M.lastError = tostring(handled) end
    end
    return nativeDraw(self, ...)
  end
  state.drawWidescreen = function(self, ww, wh, ...)
    if enabled() then
      local ok, handled = pcall(drawDecorated, self, ww, wh)
      if ok and handled then M.draws = M.draws + 1 M.lastError = nil return end
      if not ok then M.lastError = tostring(handled) end
    end
    if nativeWide then return nativeWide(self, ww, wh, ...) end
    return nativeDraw(self, ...)
  end
  state.uiSize = function(self)
    if enabled() then return 512, 288 end
    if type(nativeUiSize) == "function" then return nativeUiSize(self) end
    return 160, 144
  end
  state.drawsWidescreen = function(self)
    if enabled() then return true end
    if type(nativeDrawsWide) == "function" then return nativeDrawsWide(self) end
    return false
  end
  state.wantsFillScale = function(self)
    if enabled() then return true end
    if type(nativeFill) == "function" then return nativeFill(self) end
    return false
  end
  state.__vascGen2TitleMenuPresentation = isTitleChoice(state)
    and "title-choice" or "continue-info"
  state.__ascendantGlobalUiSkinSkip = true
  M.decorated = M.decorated + 1
  diagnostic("gen2-menu-provider", {
    provider="VascMenuStyle", result="active",
    screen=state.__vascGen2TitleMenuPresentation,
  })
  return true
end

function M.install()
  if M.installed then return true end
  local events = mod and mod.events
  if not (events and type(events.on) == "function") then
    return false, "mod.events:on unavailable"
  end
  local ok, err = pcall(events.on, events, "screen.pushed", function(event)
    decorate(type(event) == "table" and event.state or nil)
  end)
  if not ok then M.lastError = tostring(err) return false, M.lastError end
  M.installed = true
  return true
end

function M.status()
  return {
    installed=M.installed, decorated=M.decorated, draws=M.draws,
    target=M.target, lastError=M.lastError,
  }
end

M.decorate = decorate
M.isTitleChoice = isTitleChoice
M.isContinueInfo = isContinueInfo
M.editionForQA = saveVersion
M.languageForQA = interfaceLanguage

return M
