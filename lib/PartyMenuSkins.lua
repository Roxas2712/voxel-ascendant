-- Presentation-only skins for native Gen-I Start and battle PartyMenu states.
--
-- The canonical POKéMON row remains the sole entrance and calls its captured
-- engine/KASC callback exactly once. VASC only decorates the concrete screen
-- that callback pushed. The Host-v1 battle adapter likewise resolves the
-- selected battle_party provider before offering the concrete switch picker.
-- No action, field move, item target, callback, storage model or PC backend
-- is replaced here.

local V = ...
local mod = V.mod
local ModSetting = V.require("ModSetting")
local PartyPresentation = V.require("OrasPartyPresentation")
local OverlayPresentation = V.require("OrasPartyOverlayPresentation")
local SummaryPresentation = V.require("OrasPartySummaryPresentation")
local OrasUiSkin = V.require("OrasUiSkin")
local MobileMenuPresentation
do
  local ok, value = pcall(V.require, "MobileMenuPresentation")
  if ok and type(value) == "table" then MobileMenuPresentation = value end
end

local M = {
  apiVersion = 1,
  installed = false,
  optionKey = "pokemonUiPartyMenu",
  styles = {
    ASC_BOX = "asc_box",
    ORAS_GLASS = "oras_glass",
    GAME_DEFAULT = "game_default",
  },
}

M.setting = ModSetting.new(
  M.optionKey,
  "START TEAM UI",
  { M.styles.ASC_BOX, M.styles.ORAS_GLASS, M.styles.GAME_DEFAULT },
  { "ASC BOX", "ORAS GLASS", "GAME DEFAULT" },
  M.styles.ASC_BOX
)

local unpackValues = table.unpack or unpack

local function packed(...)
  return { n = select("#", ...), ... }
end

local function warn(message, ...)
  local logger = mod and mod.log
  if logger and type(logger.warn) == "function" then
    pcall(logger.warn, logger, message, ...)
  end
end

local function language()
  if type(mod.find) ~= "function" then return "en" end

  local ok, universal = pcall(mod.find, "translation-german-universal")
  if not ok then
    ok, universal = pcall(mod.find, mod, "translation-german-universal")
  end
  local boot = ok and universal and universal.exports
    and universal.exports.bootLanguage
  if boot == "de" or boot == "en" then return boot end

  local ascendant
  ok, ascendant = pcall(mod.find, "kanto_ascendant")
  if not ok then ok, ascendant = pcall(mod.find, mod, "kanto_ascendant") end
  local activeLanguage = ok and ascendant and ascendant.exports
    and ascendant.exports.language
  if type(activeLanguage) == "function" then
    local resolved, value = pcall(activeLanguage)
    if resolved and (value == "de" or value == "en") then return value end
  end

  for _, id in ipairs({ "deutsch", "deutsch-blau", "deutsch-gelb" }) do
    local found, handle = pcall(mod.find, id)
    if not found then found, handle = pcall(mod.find, mod, id) end
    if found and handle then return "de" end
  end
  return "en"
end

local function stackTop(game)
  local stack = type(game) == "table" and game.stack or nil
  if type(stack) ~= "table" then return nil end
  if type(stack.top) == "function" then
    local ok, state = pcall(stack.top, stack)
    if ok then return state end
  end
  local states = stack.states
  return type(states) == "table" and states[#states] or nil
end

local function snapshot(state)
  local fields = {}
  for key, value in pairs(state) do fields[key] = value end
  return { fields = fields, metatable = getmetatable(state) }
end

local function restore(state, saved)
  for key in pairs(state) do
    if saved.fields[key] == nil then state[key] = nil end
  end
  for key, value in pairs(saved.fields) do state[key] = value end
  if getmetatable(state) ~= saved.metatable then
    pcall(setmetatable, state, saved.metatable)
  end
  return state
end

local function decorateAscBox(state, opts)
  opts = type(opts) == "table" and opts or {}
  local saved = snapshot(state)
  local ok, result = pcall(PartyPresentation.decoratePartyMenu, state, {
    context = opts.context == "battle" and "battle" or "start",
    battle = opts.battle,
    language = language(),
  })
  if not ok then
    restore(state, saved)
    return state, false, result
  end
  state = type(result) == "table" and result or state
  state.__vascPartyMenuStyle = M.styles.ASC_BOX
  return state, true
end

local function decorateOrasGlass(state)
  local saved = snapshot(state)
  local ok, result, decorated, reason = pcall(
    OrasUiSkin.decorateInstance, state)
  if not ok or decorated ~= true then
    restore(state, saved)
    return state, false, ok and reason or result
  end
  state = type(result) == "table" and result or state
  state.__vascPartyMenuStyle = M.styles.ORAS_GLASS
  return state, true
end

-- Keep the renderer selected above authoritative. On touch devices only,
-- relocate the completed Party surface into the full local SafeArea.
local function attachMobileParty(state)
  if type(state) ~= "table" or state.screenId ~= "PartyMenu"
      or type(MobileMenuPresentation) ~= "table"
      or type(MobileMenuPresentation.attach) ~= "function" then
    return state, false, "not_party_menu"
  end
  return MobileMenuPresentation.attach(state, {
    owner="team",
    logicalSize=function(menu)
      if type(menu.uiSize) == "function" then
        local ok, width, height = pcall(menu.uiSize, menu)
        if ok and tonumber(width) and tonumber(height)
            and width > 0 and height > 0 then return width, height end
      end
      return 160, 144
    end,
    backdrop={ 5/255, 24/255, 61/255, 1 },
  })
end

function M.style()
  local value = M.setting:get()
  if value == M.styles.ORAS_GLASS or value == M.styles.GAME_DEFAULT then
    return value
  end
  return M.styles.ASC_BOX
end

function M.decorate(state, style)
  if type(state) ~= "table" then return state, false, "missing_state" end
  style = style or M.style()
  if style == M.styles.GAME_DEFAULT then
    return state, false, "game_default"
  elseif style == M.styles.ORAS_GLASS then
    return decorateOrasGlass(state)
  end
  return decorateAscBox(state, { context="start" })
end

-- Battle PartyMenu remains the authoritative native switch picker. The
-- PokemonUi Host-v1 adapter calls this only after resolving ASC BOX for the
-- battle_party surface; this function replaces presentation on that concrete
-- instance and forwards the live battle owner to the reviewed 0.5.3 adapter.
-- Any construction error restores the complete native object and metatable.
function M.decorateBattle(state, opts)
  if type(state) ~= "table" then return state, false, "missing_state" end
  opts = type(opts) == "table" and opts or {}
  -- The same concrete PartyMenu is synchronously reported by screen.pushed
  -- after Host-v1 has already selected the battle_party surface. Claim that
  -- push now so the generic Start/Bag observer cannot redecorate this battle
  -- picker as context="start" and collapse its wide 2x3 navigation layout.
  state.__vascPartyMenuPushHandled = true
  return decorateAscBox(state, {
    context="battle",
    battle=opts.battle or state.battle,
  })
end

-- Screens.push is also used directly by BagMenu for TM/HM, stones and item
-- targets.  Those PartyMenu instances never traverse StartMenu's canonical
-- POKéMON row, so the push event is the common presentation boundary.  Keep
-- a per-instance receipt: StateStack emits synchronously and the Start row
-- retains a compatibility fallback, but one concrete native picker must be
-- offered to the selected skin at most once.
local function decoratePushedPartyMenu(state, origin)
  if type(state) ~= "table" or state.screenId ~= "PartyMenu" then
    return state, false, "not_party_menu"
  end
  if state.__vascPartyMenuPushHandled == true then
    return state, false, "already_handled"
  end
  state.__vascPartyMenuPushHandled = true
  local result, decorated, reason = M.decorate(state, M.style())
  if not decorated and reason ~= "game_default" then
    warn("%s PartyMenu skin failed open: %s",
      tostring(origin or "Pushed"), tostring(reason))
  end
  if decorated then attachMobileParty(result or state) end
  return result, decorated, reason
end

local function ascendantUnderlay(game)
  local state = stackTop(game)
  return type(state) == "table"
    and state.__vascPartyMenuStyle == M.styles.ASC_BOX
    and state.__vascOrasPartyDecorated == true
end

-- KASC Eggs can retain their future species internally. Calling the native
-- Summary constructor would resolve that portrait and play its cry before a
-- presentation decorator can hide it. If the private Egg presentation ever
-- fails during construction, return a deliberately tiny, closable neutral
-- screen instead of falling through to that leaking constructor.
local function safeEggSummary(game)
  local state = {
    game=game,
    page=1,
    isOpaque=true,
    __vascPrivateEggSummaryFallback=true,
  }
  function state:update()
    local input = self.game and self.game.input
    local pressed = false
    if input and type(input.wasPressed) == "function" then
      local okA, a = pcall(input.wasPressed, input, "a")
      local okB, b = pcall(input.wasPressed, input, "b")
      pressed = (okA and a == true) or (okB and b == true)
    end
    local stack = self.game and self.game.stack
    if pressed and stack and type(stack.pop) == "function" then
      pcall(stack.pop, stack)
    end
  end
  function state:draw()
    pcall(function()
      local graphics = love and love.graphics
      local Font = require("src.render.Font")
      if not graphics or type(graphics.rectangle) ~= "function" then return end
      graphics.setColor(1, 1, 1, 1)
      graphics.rectangle("fill", 0, 0, 160, 144)
      graphics.setColor(0, 0, 0, 1)
      if type(Font.drawBox) == "function" then Font.drawBox(1, 1, 18, 16) end
      Font.draw(language() == "de" and "EI" or "EGG", 64, 56)
      Font.draw("A/B", 64, 88)
      graphics.setColor(1, 1, 1, 1)
    end)
  end
  state.drawWidescreen = state.draw
  function state:uiSize() return 160, 144 end
  function state:sgbPalettes() return nil end
  return state
end

local function installSummaryFactory()
  local screens = mod.content and mod.content.screens
  if type(screens) ~= "table" or type(screens.override) ~= "function" then
    return false, "missing_screen_registry"
  end
  local NativeSummary = require("src.ui.SummaryMenu")
  local ok, err = pcall(screens.override, screens, "SummaryMenu", {
    new = function(game, mon)
      if not ascendantUnderlay(game) then
        return NativeSummary.new(game, mon)
      end

      local summary
      local egg = false
      if type(PartyPresentation.isEgg) == "function" then
        local checked, value = pcall(PartyPresentation.isEgg, mon)
        egg = checked and value == true
      end
      if egg then
        -- KASC Eggs may retain their future species. Avoid the native
        -- constructor's portrait/cry side effects until the egg-safe ORAS
        -- presentation owns this one state.
        summary = setmetatable({ game = game, mon = mon, page = 1 },
          NativeSummary)
      else
        summary = NativeSummary.new(game, mon)
      end

      local saved = snapshot(summary)
      local decorated, result = pcall(
        SummaryPresentation.decorateSummaryMenu, summary, {
          language = language(),
        })
      if decorated and type(result) == "table" then return result end
      restore(summary, saved)
      if egg then
        warn("ASC BOX Egg Summary presentation failed private: %s",
          tostring(result))
        return safeEggSummary(game)
      end
      warn("ASC BOX Summary presentation failed open: %s", tostring(result))
      return summary
    end,
  })
  return ok, ok and nil or err
end

local function stackPosition(states, state)
  for index = #states, 1, -1 do
    if states[index] == state then return index end
  end
  return nil
end

-- KASC and the universal language layer may proxy an engine screen through
-- one additional class/metatable.  Comparing only the immediate metatable
-- silently misses those real TextBox/Menu instances even though their native
-- update owner is unchanged.  Follow the same bounded class-chain contract as
-- OrasUiSkin so presentation routing survives those compatible wrappers.
local function classInstance(state, class)
  if type(state) ~= "table" or type(class) ~= "table" then return false end
  local mt = getmetatable(state)
  local visited = {}
  while type(mt) == "table" and not visited[mt] do
    if mt == class or rawget(mt, "__index") == class then return true end
    visited[mt] = true
    mt = getmetatable(mt)
  end
  return false
end

local function wideBattle(parent)
  if type(parent) ~= "table"
      or type(parent.isWideBattleLayout) ~= "function" then
    return false
  end
  local ok, value = pcall(parent.isWideBattleLayout, parent)
  return ok and value == true
end

local function ascendantWideBase(state)
  -- The Ascendant root/descendant lists are not Party/Summary/Bag objects,
  -- so OrasPartyOverlayPresentation.isOrasBase deliberately does not claim
  -- them.  KantoAscendantCompat stamps this marker only after the menu has
  -- actually been accepted by the ORAS fullscreen bridge.  Treating that
  -- exact marker as a modal presentation parent keeps KASC's real TextBox
  -- update, pagination and callbacks while preventing the 160x144 renderer
  -- from collapsing a 512x288 Journal/Status/Signals screen.
  return type(state) == "table"
    and state.__vascAscendantWidescreenRoute == true
end

local function installOverlayListener()
  local events = mod.events
  if type(events) ~= "table" or type(events.on) ~= "function" then
    return false, "missing_events"
  end
  local NativeTextBox = require("src.render.TextBox")
  local NativeChoiceBox = require("src.ui.ChoiceBox")
  local NativeMenu = require("src.ui.Menu")
  local NativeQuantityBox = require("src.ui.QuantityBox")
  local ok, err = pcall(events.on, events, "screen.pushed", function(event)
    local state = type(event) == "table" and event.state or nil
    decoratePushedPartyMenu(state, "Pushed")
    local game = type(state) == "table" and state.game or nil
    local stack = type(game) == "table" and game.stack or nil
    local states = type(stack) == "table" and stack.states or nil
    if type(states) ~= "table" then return end

    local position = stackPosition(states, state)
    local below = position and states[position - 1] or nil
    local base = below
    if type(stack.visibleBase) == "function" then
      local resolved, index = pcall(stack.visibleBase, stack)
      if resolved and type(index) == "number" then
        base = states[index] or base
      end
    end
    local parent = (OverlayPresentation.isOrasBase(below)
        or ascendantWideBase(below)) and below
      or ((OverlayPresentation.isOrasBase(base)
        or ascendantWideBase(base)) and base or nil)
    local bagParent = type(OverlayPresentation.isWideBagBase) == "function"
      and (OverlayPresentation.isWideBagBase(below) and below
        or (OverlayPresentation.isWideBagBase(base) and base or nil)) or nil

    if classInstance(state, NativeMenu) and bagParent then
      local saved = snapshot(state)
      state.__ascendantGlobalUiSkinSkip = true
      local decorated, result = pcall(
        OverlayPresentation.decorateBagActionMenu, state,
        { wideBattle=wideBattle(bagParent) })
      if not decorated then
        restore(state, saved)
        warn("ORAS Bag action presentation failed open: %s", tostring(result))
      end
    elseif classInstance(state, NativeQuantityBox) and bagParent then
      local saved = snapshot(state)
      state.__ascendantGlobalUiSkinSkip = true
      local decorated, result = pcall(
        OverlayPresentation.decorateBagQuantity, state,
        { wideBattle=wideBattle(bagParent) })
      if not decorated then
        restore(state, saved)
        warn("ORAS Bag quantity presentation failed open: %s", tostring(result))
      end
    elseif (classInstance(state, NativeTextBox)
        or state.isTextBox == true) and parent then
      local saved = snapshot(state)
      state.__ascendantGlobalUiSkinSkip = true
      local decorated, result = pcall(
        OverlayPresentation.decorateTextBox, state, {
          wideBattle = wideBattle(parent),
        })
      if not decorated then
        restore(state, saved)
        warn("ASC BOX TextBox presentation failed open: %s", tostring(result))
      end
    elseif classInstance(state, NativeChoiceBox) and bagParent then
      local saved = snapshot(state)
      state.__ascendantGlobalUiSkinSkip = true
      local decorated, result = pcall(
        OverlayPresentation.decorateBagChoice, state,
        { wideBattle=wideBattle(bagParent) })
      if not decorated then
        restore(state, saved)
        warn("ORAS Bag choice presentation failed open: %s", tostring(result))
      end
    elseif classInstance(state, NativeChoiceBox)
        and type(below) == "table" and below.__vascOrasWideTextBox then
      local saved = snapshot(state)
      state.__ascendantGlobalUiSkinSkip = true
      local decorated, result = pcall(
        OverlayPresentation.decorateChoiceBox, state, {
          wideBattle = below.__vascOrasWideBattleOverlay == true,
        })
      if not decorated then
        restore(state, saved)
        warn("ASC BOX ChoiceBox presentation failed open: %s", tostring(result))
      end
    end
  end, 900)
  return ok, ok and nil or err
end

local function installStartRowHook()
  local hooks = mod.hooks
  if type(hooks) ~= "table" or type(hooks.wrap) ~= "function" then
    return false, "missing_hooks"
  end
  local Strings = require("src.core.Strings")
  local ok, err = pcall(hooks.wrap, hooks, "ui.start_menu.items",
    function(nextItems, game, items)
      local out = nextItems(game, items)
      if type(out) ~= "table" then return out end

      local pokemonLabel = Strings("POKéMON")
      for index, row in ipairs(out) do
        if type(row) == "table" and row.label == pokemonLabel
            and type(row.onSelect) == "function"
            and not row.__vascPartyMenuSkinHook then
          local copy = {}
          for key, value in pairs(row) do copy[key] = value end
          local original = row.onSelect
          copy.__vascPartyMenuSkinHook = true
          copy.onSelect = function(...)
            local before = stackTop(game)
            local values = packed(original(...))
            local top = stackTop(game)
            if top and top ~= before and top.screenId == "PartyMenu" then
              decoratePushedPartyMenu(top, "Start")
            end
            return unpackValues(values, 1, values.n)
          end

          -- Replace exactly one descriptor in a shallow array clone. This is
          -- deliberately not insertBefore/append: Start keeps its native row
          -- count, order, label, help and callback contract.
          local cloned = {}
          for rowIndex, item in ipairs(out) do cloned[rowIndex] = item end
          cloned[index] = copy
          return cloned
        end
      end
      return out
    end, 850)
  return ok, ok and nil or err
end

function M.install()
  if M.installed then return true, "already_installed" end

  local summaryOk, summaryReason = installSummaryFactory()
  local overlayOk, overlayReason = installOverlayListener()
  local hookOk, hookReason = installStartRowHook()
  M.installed = hookOk
  M.receipt = {
    installed = hookOk,
    startRow = hookOk,
    summary = summaryOk,
    overlays = overlayOk,
    reasons = {
      startRow = hookReason,
      summary = summaryReason,
      overlays = overlayReason,
    },
  }
  if not hookOk then return false, hookReason end
  if not summaryOk then
    warn("ASC BOX Summary integration unavailable: %s", tostring(summaryReason))
  end
  if not overlayOk then
    warn("ASC BOX overlay integration unavailable: %s", tostring(overlayReason))
  end
  return true
end

function M.status()
  return M.receipt or { installed = false }
end

M.attachMobileParty = attachMobileParty

return M
