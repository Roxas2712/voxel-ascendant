-- Gen-1 adapter for the shared six-edition post-title menu presentation.
-- The native cartridge logo / Press Start TitleState remains entirely engine
-- owned.  Only the subsequent choice and continue-info states are decorated;
-- they retain every item, callback, update method and stack action.

local V = ... or {}
local mod = V.mod
local Hub = V.require("TitleHubPresentation")
local EditionAccent = V.require("EditionAccent")
local okRenderer, Renderer = pcall(require, "src.render.Renderer")
if not okRenderer then Renderer = nil end

local M = {
  installed=false, decorated=0, draws=0, lastError=nil,
  target="Gen1 post-title Menu/ContinueInfo",
}

local function findMod(id)
  if not (mod and type(mod.find) == "function") then return nil end
  local ok, found = pcall(mod.find, id)
  if not ok then ok, found = pcall(mod.find, mod, id) end
  return ok and found or nil
end

local function language()
  local universal = findMod("translation-german-universal")
  local boot = type(universal) == "table" and universal.exports
    and universal.exports.bootLanguage
  if boot == "de" or boot == "en" then return boot end
  if universal then return "de" end
  for _, id in ipairs({"universal_german", "deutsch", "deutsch-blau",
      "deutsch-gelb"}) do
    if findMod(id) then return "de" end
  end
  return "en"
end

local function edition()
  local ok, _, id = pcall(EditionAccent.resolve)
  if ok and id and id ~= "shared" then return id end
  return "red"
end

local function clean(value)
  return tostring(value or ""):gsub("<PO><KE>", "POKé")
    :gsub("<PK><MN>", "POKéMON"):gsub("%s+", " ")
    :gsub("^%s+", ""):gsub("%s+$", "")
end

local function canonical(value)
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

local function isTitleChoice(state)
  if type(state) ~= "table" or type(state.titleUiBox) ~= "table"
      or type(state.items) ~= "table" or #state.items < 2 then return false end
  local game, option = false, false
  for _, item in ipairs(state.items) do
    local label = canonical(type(item) == "table" and item.label or item)
    game = game or label == "WEITER" or label == "NEUES SPIEL"
    option = option or label == "OPTIONEN"
  end
  return game and option
end

local function isContinueInfo(state)
  return type(state) == "table" and type(state.titleUiBox) == "table"
    and type(state.save) == "table" and type(state.items) ~= "table"
end

local function isTitleRoot(state)
  return type(state) == "table"
    and tostring(state.screenId or state.id or "") == "TitleState"
    and type(state.draw) == "function"
    and type(state.onNewGame) == "function"
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
  local counted, value = pcall(Badges.count, state.game.data, state.save)
  return counted and tonumber(value) or 0
end

local function specFor(state)
  local common = {edition=edition(), language=language(), game=state.game,
    generation=1}
  if isTitleChoice(state) then
    common.showArtwork = true
    common.items = {}
    for _, item in ipairs(state.items) do
      common.items[#common.items + 1] = {
        label=canonical(type(item) == "table" and item.label or item),
      }
    end
    common.index = tonumber(state.index) or 1
    return common
  end
  if isContinueInfo(state) then
    common.showArtwork = false
    local save = state.save
    local player = type(save.player) == "table" and save.player or {}
    local seconds = math.max(0, math.floor(tonumber(save.playTime) or 0))
    common.items = {
      {label="TRAINER", right=clean(player.name or "RED"),
        },
      {label="BADGES", right=tostring(badgeCount(state))},
      {label="POKéDEX", right=tostring(ownedCount(save))},
      {label="PLAY TIME", right=("%d:%02d"):format(
        math.floor(seconds / 3600), math.floor(seconds / 60) % 60)},
    }
    common.index = 1
    common.footer = "A: WEITER   B: ZURÜCK"
    return common
  end
end

local function render(state, wide, ww, wh)
  local spec = specFor(state)
  if not spec then return false end
  if wide and type(Hub.drawPhysical) == "function" then
    return Hub.drawPhysical(spec, ww, wh)
  end
  return type(Hub.draw) == "function" and Hub.draw(spec) or false
end

local function decorate(state)
  -- Deliberately do not decorate isTitleRoot(state).  That state owns the
  -- edition's original logo, animation, palette and Press Start interaction.
  if not (isTitleChoice(state) or isContinueInfo(state)) then
    return false
  end
  if state.__vascGen1TitleMenuPresentation then return true end
  local nativeDraw = state.draw
  if type(nativeDraw) ~= "function" then return false end
  local nativeWide = type(state.drawWidescreen) == "function"
    and state.drawWidescreen or nil

  state.draw = function(self, ...)
    local ok, handled = pcall(render, self, false)
    if ok and handled then M.draws = M.draws + 1 M.lastError = nil return end
    if not ok then M.lastError = tostring(handled) end
    return nativeDraw(self, ...)
  end
  state.drawWidescreen = function(self, ww, wh, ...)
    local ok, handled = pcall(render, self, true, ww, wh)
    if ok and handled then M.draws = M.draws + 1 M.lastError = nil return end
    if not ok then M.lastError = tostring(handled) end
    if nativeWide then return nativeWide(self, ww, wh, ...) end
    return nativeDraw(self, ...)
  end
  state.uiSize = function() return Hub.width or 512, Hub.height or 288 end
  state.drawsWidescreen = function() return true end
  state.wantsFillScale = function() return true end
  -- Game:draw asks the topmost visible state with sgbPalettes() to own the
  -- post-draw colour pass.  Without an owner here it falls through to the
  -- underlying 160x144 Gen-I TitleState and paints its ATTR_BLK rectangles
  -- over this 512x288 true-colour hub.  A concrete full-frame opt-out keeps
  -- the hub raw in every colour mode while leaving the native TitleState
  -- untouched as soon as this screen is popped.
  state.sgbPalettes = function()
    return { {
      colors=false, x=0, y=0,
      w=Hub.width or 512, h=Hub.height or 288,
    } }
  end
  state.__vascGen1TitleMenuPresentation = isTitleChoice(state)
    and "title-choice" or "continue-info"
  state.__ascendantGlobalUiSkinSkip = true
  M.decorated = M.decorated + 1
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
  end, 13000)
  if not ok then M.lastError = tostring(err) return false, M.lastError end
  local hooks = mod and mod.hooks
  if hooks and type(hooks.wrap) == "function" and Renderer
      and type(Renderer.frameRects) == "function"
      and type(Hub.drawArtworkPhysical) == "function" then
    local installed, reason = pcall(hooks.wrap, hooks, "render.hud",
      function(next, game, viewport)
        local out = next(game, viewport)
        local state = game and game.stack and game.stack:top()
        -- Never cover a child menu/confirmation or redraw the mobile HD path.
        if state and state.__vascGen1TitleMenuPresentation == "title-choice"
            and not state.__vascGen1MobileMenuBridge then
          local drawn, handled, why = pcall(function()
            local rect = Renderer:frameRects()
            if rect.uiw ~= 512 or rect.uih ~= 288 then return false end
            return Hub.drawArtworkPhysical(specFor(state), rect)
          end)
          if not drawn or handled == false then
            M.lastError = tostring(not drawn and handled or why or "artwork declined")
          else M.lastError = nil end
        end
        return out
      end, 15150)
    if not installed then M.lastError = tostring(reason) end
  end
  M.installed = true
  return true
end

function M.status()
  return {installed=M.installed, decorated=M.decorated, draws=M.draws,
    target=M.target, lastError=M.lastError}
end

M.decorate = decorate
M.isTitleChoice = isTitleChoice
M.isContinueInfo = isContinueInfo
M.isTitleRoot = isTitleRoot
M.editionForQA = edition
M.languageForQA = language

return M
