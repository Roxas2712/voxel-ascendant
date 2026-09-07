-- Persistent compact/fullscreen presentation toggle for the Gen-1 START menu.
-- The engine remains the sole owner of rows, navigation, callbacks and saves;
-- this module only selects between the existing edge renderer and VASC's
-- widescreen menu presentation while START is open.
local V = ...
local mod = V and V.mod

local M = {
  installed = false,
  decorated = 0,
  hudHook = false,
  hudHealthy = true,
  lastError = nil,
}

local MODE_KEY = "startMenuFullscreen"
local adapters = setmetatable({}, { __mode="k" })
local presenter
local fonts = {}
local EditionAccent
pcall(function() EditionAccent = V.require("EditionAccent") end)
local MobileMenuPresentation
pcall(function() MobileMenuPresentation = V.require("MobileMenuPresentation") end)
local GamepadMap
pcall(function() GamepadMap = require("src.core.GamepadMap") end)

local function graphicsRuntime()
  local ok, runtime = pcall(function() return love end)
  if not ok or type(runtime) ~= "table" then return nil end
  local got, graphics = pcall(function() return runtime.graphics end)
  return got and type(graphics) == "table" and graphics or nil
end

local function activeAccent(menu)
  if type(EditionAccent) == "table" and type(EditionAccent.color) == "function" then
    local explicit = menu and menu.game and menu.game.save
      and menu.game.save.version or nil
    local ok, value = pcall(EditionAccent.color, explicit)
    if ok and type(value) == "table" then return value end
  end
  return { 0.90, 0.20, 0.18, 1 }
end

local function modernUiEnabled(menu)
  local skin = V and V.OrasUiSkin
  if type(skin) == "table" and type(skin.enabled) == "function" then
    local ok, value = pcall(skin.enabled, menu and menu.game)
    if ok then return value ~= false end
  end
  return true
end

local function font(size)
  size = math.max(8, math.floor((tonumber(size) or 12) + 0.5))
  if fonts[size] ~= nil then return fonts[size] or nil end
  local G = graphicsRuntime()
  if not (G and type(G.newFont) == "function") then
    fonts[size] = false
    return nil
  end
  local ok, value = pcall(G.newFont, size)
  fonts[size] = ok and value or false
  return fonts[size] or nil
end

local function dimensions(fallbackW, fallbackH)
  if tonumber(fallbackW) and tonumber(fallbackH)
      and fallbackW > 0 and fallbackH > 0 then
    return fallbackW, fallbackH
  end
  local G = graphicsRuntime()
  if not G then return nil, nil end
  if type(G.getCanvas) == "function" then
    local ok, canvas = pcall(G.getCanvas)
    if ok and canvas and type(canvas.getDimensions) == "function" then
      local w, h = canvas:getDimensions()
      if w and h and w > 0 and h > 0 then return w, h end
    end
  end
  if type(G.getDimensions) == "function" then return G.getDimensions() end
  return nil, nil
end

local function clean(text)
  text = tostring(text or "")
  text = text:gsub("<PO><KE>", "POKé")
  text = text:gsub("<PK><MN>", "POKéMON")
  text = text:gsub("[\v\f\r\n]", " ")
  text = text:gsub("%s+", " ")
  return text
end

local function universalBootLanguage()
  if not (mod and type(mod.find) == "function") then return nil end
  local ok, handle = pcall(mod.find, "translation-german-universal")
  if not ok then
    ok, handle = pcall(mod.find, mod, "translation-german-universal")
  end
  local exports = ok and type(handle) == "table" and handle.exports or nil
  local value = type(exports) == "table" and exports.bootLanguage or nil
  if value == "de" or value == "en" then return value end
  return nil
end

local function language()
  -- The battle-HUD language is not a global menu-language preference.
  -- In particular, an old saved HUD setting must not translate START when
  -- the optional translation package is absent or boots in English.
  return universalBootLanguage() or "en"
end

-- Native labels are kept untouched because Gen I owns their callbacks and
-- ordering. Only the text copied into VASC's two presenters is localized.
local START_LABELS = {
  de = {
    ["ITEM"]="TASCHE", ["ITEMS"]="TASCHE",
    ["SAVE"]="SICHERN", ["OPTION"]="OPTIONEN", ["OPTIONS"]="OPTIONEN",
    ["LINK"]="VERBINDUNG", ["QUIT"]="BEENDEN",
  },
}

local function startLabel(item)
  local raw = clean(type(item) == "table" and item.label or item)
  local labels = START_LABELS[language()]
  return type(labels) == "table" and labels[raw] or raw
end

local function startTitle()
  return language() == "de" and "START-MENÜ" or "START MENU"
end

local function compactFooter(fullscreen)
  if language() == "de" then
    return fullscreen
      and "A: ÖFFNEN   B: ZURÜCK   SELECT: RAND"
      or "A: ÖFFNEN   B: ZURÜCK   SELECT: VOLLBILD"
  end
  return fullscreen
    and "A: OPEN   B: BACK   SELECT: EDGE"
    or "A: OPEN   B: BACK   SELECT: FULLSCREEN"
end

local function clip(text, activeFont, maxWidth)
  text = clean(text)
  if not activeFont or type(activeFont.getWidth) ~= "function"
      or activeFont:getWidth(text) <= maxWidth then return text end
  local suffix = "..."
  local function dropLastCodepoint(value)
    local index = #value
    while index > 0 do
      local byte = value:byte(index)
      if not byte or byte < 0x80 or byte >= 0xC0 then break end
      index = index - 1
    end
    return index > 0 and value:sub(1, index - 1) or ""
  end
  while #text > 0 and activeFont:getWidth(text .. suffix) > maxWidth do
    text = dropLastCodepoint(text)
  end
  return text .. suffix
end

-- The compact mode is still a VASC/ORAS surface.  It deliberately occupies
-- only the right edge and leaves the live world visible; the cartridge menu
-- is retained solely as a fail-open renderer when graphics are unavailable.
local function drawEdge(menu, fallbackW, fallbackH, keepTransform)
  local G = graphicsRuntime()
  if not (G and type(G.push) == "function" and type(G.rectangle) == "function"
      and type(G.setColor) == "function" and type(G.print) == "function") then
    return false
  end
  local ww, wh = dimensions(fallbackW, fallbackH)
  if not (ww and wh and ww > 0 and wh > 0) then return false end

  local items = menu.items or {}
  local count = math.max(1, #items)
  local scale = math.max(0.55, math.min(2.50, math.min(ww / 800, wh / 600)))
  local margin = math.max(12, math.floor(18 * scale))
  local gap = math.max(4, math.floor(7 * scale))
  local panelW = math.min(ww * 0.43, math.max(265 * scale, 350 * scale))
  local headerH = math.max(42, math.floor(54 * scale))
  local footerH = math.max(34, math.floor(43 * scale))
  local available = wh - margin * 2 - headerH - footerH - gap * (count + 1)
  local rowH = math.max(28, math.min(math.floor(52 * scale), available / count))
  local visible = math.max(1, math.floor(
    (wh - margin * 2 - headerH - footerH - gap) / (rowH + gap)))
  visible = math.min(count, visible)
  local panelH = headerH + footerH + gap * (visible + 1) + rowH * visible
  local x, y = ww - panelW - margin, wh - panelH - margin
  local radius = math.max(10, math.floor(16 * scale))
  local index = math.max(1, math.min(count, math.floor(tonumber(menu.index) or 1)))
  local accent = activeAccent(menu)
  local first = math.max(1, math.floor(tonumber(menu.scroll) or 0) + 1)
  if index < first then first = index end
  if index > first + visible - 1 then first = index - visible + 1 end
  if first + visible - 1 > count then first = math.max(1, count - visible + 1) end

  G.push("all")
  if not keepTransform and type(G.origin) == "function" then G.origin() end
  if type(G.setBlendMode) == "function" then G.setBlendMode("alpha") end
  G.setColor(0.018, 0.027, 0.043, 0.91)
  G.rectangle("fill", x, y, panelW, panelH, radius, radius)
  G.setColor(accent[1], accent[2], accent[3], accent[4] or 0.98)
  if type(G.setLineWidth) == "function" then G.setLineWidth(math.max(1, 2 * scale)) end
  G.rectangle("line", x, y, panelW, panelH, radius, radius)
  G.setColor(accent[1], accent[2], accent[3], 0.46)
  G.rectangle("line", x + 3, y + 3, panelW - 6, panelH - 6,
              math.max(6, radius - 3), math.max(6, radius - 3))

  local titleFont = font(math.max(15, 19 * scale))
  local rowFont = font(math.max(14, 18 * scale))
  local metaFont = font(math.max(10, 12 * scale))
  if titleFont and type(G.setFont) == "function" then G.setFont(titleFont) end
  G.setColor(1, 1, 1, 0.98)
  G.print(startTitle(), x + gap * 2, y + headerH * 0.22)
  if metaFont and type(G.setFont) == "function" then G.setFont(metaFont) end
  G.setColor(1, 1, 1, 0.58)
  local player = menu.game and menu.game.save and menu.game.save.player or {}
  G.print(clean(player and player.name or "TRAINER"),
          x + gap * 2, y + headerH * 0.66)

  for slot = 1, visible do
    local itemIndex = first + slot - 1
    local item = items[itemIndex]
    if not item then break end
    local rowY = y + headerH + gap + (slot - 1) * (rowH + gap)
    local selected = itemIndex == index
    G.setColor(selected and 0.16 or 0.08, selected and 0.35 or 0.17,
               selected and 0.56 or 0.29, selected and 0.96 or 0.84)
    G.rectangle("fill", x + gap, rowY, panelW - gap * 2, rowH,
                radius * 0.48, radius * 0.48)
    if selected then
      G.setColor(1.00, 0.72, 0.24, 0.98)
      G.rectangle("line", x + gap, rowY, panelW - gap * 2, rowH,
                  radius * 0.48, radius * 0.48)
    end
    if rowFont and type(G.setFont) == "function" then G.setFont(rowFont) end
    G.setColor(1, 1, 1, 0.98)
    local iconX = x + gap * 2.15
    local iconY = rowY + rowH * 0.5
    local iconR = math.max(4, math.min(8 * scale, rowH * 0.18))
    if selected and type(G.circle) == "function" then
      -- A tiny vector Pokéball avoids font-dependent cursor glyphs.  It is
      -- always available, scales cleanly and inherits the active edition.
      G.setColor(1, 1, 1, 0.98)
      G.circle("fill", iconX, iconY, iconR)
      G.setColor(accent[1], accent[2], accent[3], 1)
      G.circle("line", iconX, iconY, iconR)
      G.line(iconX - iconR, iconY, iconX + iconR, iconY)
      G.circle("fill", iconX, iconY, math.max(1.5, iconR * 0.32))
      G.setColor(1, 1, 1, 1)
      G.circle("fill", iconX, iconY, math.max(0.8, iconR * 0.15))
    end
    G.setColor(1, 1, 1, 0.98)
    G.print(clip(startLabel(item), G.getFont and G.getFont() or rowFont,
              panelW - gap * 6),
      x + gap * 3.8, rowY + math.max(4, (rowH - (rowFont and rowFont:getHeight() or 14)) * 0.5))
  end

  if metaFont and type(G.setFont) == "function" then G.setFont(metaFont) end
  G.setColor(1, 1, 1, 0.64)
  G.print(compactFooter(false),
          x + gap * 1.7, y + panelH - footerH * 0.66)
  G.pop()
  return true
end

local function optionValue(game)
  local options = game and game.save and game.save.options
  local buckets = type(options) == "table" and options.modOptions or nil
  local bucket = type(buckets) == "table" and buckets.VOXEL_ASCENDANT or nil
  if type(bucket) == "table" and bucket[MODE_KEY] ~= nil then
    return bucket[MODE_KEY]
  end
  local api = mod and mod.options
  if api and type(api.get) == "function" then
    local ok, value = pcall(api.get, api, MODE_KEY)
    if ok and value ~= nil then return value end
  end
  return nil
end

local function savedFullscreenMode(game)
  local preferred = optionValue(game)
  if preferred ~= nil then
    return preferred == true or preferred == 1 or preferred == "1"
      or preferred == "fullscreen"
  end
  local save = mod and mod.save
  if not (save and type(save.get) == "function") then return false end
  local ok, value = pcall(save.get, save, MODE_KEY)
  if not ok then return false end
  return value == true or value == 1 or value == "1"
    or value == "fullscreen"
end

local function persistFullscreenMode(game, value)
  local save = mod and mod.save
  local memoryOk = false
  if save and type(save.set) == "function" then
    local ok, result = pcall(save.set, save, MODE_KEY, value == true)
    memoryOk = ok and result ~= false
  end
  local options = game and game.save and game.save.options
  if type(options) ~= "table" then return memoryOk end
  options.modOptions = options.modOptions or {}
  options.modOptions.VOXEL_ASCENDANT =
    options.modOptions.VOXEL_ASCENDANT or {}
  options.modOptions.VOXEL_ASCENDANT[MODE_KEY] = value == true
  if type(game.writeOptions) == "function" then
    local ok = pcall(game.writeOptions, game)
    return ok or memoryOk
  end
  return memoryOk
end

local Diagnostics
pcall(function() Diagnostics = V.require("Diagnostics") end)
local function diagnostic(event, fields)
  if type(Diagnostics) == "table" and type(Diagnostics.write) == "function" then
    pcall(Diagnostics.write, event, fields)
  end
end

local function togglePresentation(menu, trigger)
  menu._vascStartFullscreen = not menu._vascStartFullscreen
  -- Keep the controller-owned cursor authoritative across both presenters.
  -- The raw SELECT callback can run between fixed updates, before
  -- StartMenu.new's normal cursor receipt is written for that frame.
  local save = menu.game and menu.game.save
  if type(save) == "table" then
    save.startMenuIndex = math.max(1, math.floor(tonumber(menu.index) or 1))
  end
  -- Some hosts expose the same physical SELECT through both a raw callback
  -- and the next fixed-step Input edge.  Quarantine exactly one update so
  -- that second edge cannot become START/B and pop the still-open menu.
  menu._vascStartInputGuard = 1
  persistFullscreenMode(menu.game, menu._vascStartFullscreen)
  diagnostic("gen1-start-menu-mode", {
    mode=menu._vascStartFullscreen and "fullscreen" or "edge",
    trigger=trigger or "select",
  })
end

local function mappedSelect(input, mapName, rawValue, fallback)
  local mappings = input and input[mapName]
  if type(mappings) == "table" and mappings[rawValue] ~= nil then
    return mappings[rawValue] == "select"
  end
  return fallback == true
end

local function isSelectKey(menu, key)
  return mappedSelect(menu and menu.game and menu.game.input,
    "keyBindings", key,
    key == "tab" or key == "rshift" or key == "lshift")
end

local function isSelectPad(menu, button)
  return mappedSelect(menu and menu.game and menu.game.input,
    "padBindings", button, button == "back")
end

local function isSelectJoystick(menu, button)
  local input = menu and menu.game and menu.game.input
  if mappedSelect(input, "joyBindings", button, false) then return true end
  if type(GamepadMap) == "table" and type(GamepadMap.mapRawButton) == "function" then
    local ok, action = pcall(GamepadMap.mapRawButton, button)
    if ok then return action == "select" end
  end
  return button == 7 or button == 9
end

local START_HELP = {
  de = {
    ["POKéDEX"]="Pokédex ansehen, Einträge und Fundorte prüfen.",
    ["POKéMON"]="Team ansehen, ordnen und Pokémon-Aktionen wählen.",
    ["ITEM"]="Widescreen-Tasche öffnen und Gegenstände verwenden.",
    ["ASCENDANT"]="Voxel-Ascendant-Einstellungen und Funktionen öffnen.",
    ["SAVE"]="Aktuellen Spielstand speichern.",
    ["OPTION"]="Spiel-, Anzeige- und Steuerungsoptionen ändern.",
    ["LINK"]="Link-Funktionen und Mehrspieler öffnen.",
    ["MODS"]="Installierte Mods verwalten.",
    ["QUIT"]="Zum Titelbildschirm zurückkehren.",
  },
  en = {
    ["POKéDEX"]="View Pokédex entries and known locations.",
    ["POKéMON"]="View and arrange the party or choose Pokémon actions.",
    ["ITEM"]="Open the widescreen Bag and use an item.",
    ["ASCENDANT"]="Open Voxel Ascendant settings and features.",
    ["SAVE"]="Save the current game.",
    ["OPTION"]="Change game, display and control options.",
    ["LINK"]="Open Link and multiplayer functions.",
    ["MODS"]="Manage installed mods.",
    ["QUIT"]="Return to the title screen.",
  },
}

local function startHelp(item)
  local supplied = item and (item.help or item.description)
  if supplied ~= nil and clean(supplied) ~= "" then return clean(supplied) end
  local label = clean(item and item.label or "")
  local tableForLanguage = START_HELP[language()] or START_HELP.en
  if tableForLanguage[label] then return tableForLanguage[label] end
  -- The trainer-name row is the only native dynamic label.
  return language() == "de"
    and "Trainerkarte, Orden und Spielzeit anzeigen."
    or "View the Trainer Card, badges and play time."
end

local function sharedPresenter()
  if presenter then return presenter end
  local okStyle, Style = pcall(V.require, "VascMenuStyle")
  if not okStyle or type(Style) ~= "table" or type(Style.new) ~= "function" then
    return nil, tostring(Style or "VascMenuStyle.new unavailable")
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

local function adapterFor(owner)
  local adapter = adapters[owner]
  if adapter then return adapter end
  local style, err = sharedPresenter()
  if not style then return nil, err end
  adapter = {
    game=owner.game,
    title=startTitle(),
    -- The 512x288 focus/help layout has room for eight 20px rows.  Advertising
    -- nine rows made VascMenuStyle clamp scroll back to zero even though row 9
    -- (normally QUIT) was outside the visible panel.  Keep the controller's
    -- native index/scroll authoritative, but tell the presenter its real
    -- viewport capacity so the final row can scroll into view.
    items={}, index=1, scroll=0, rows=8,
    footer=compactFooter(true),
    draw=function() end,
    update=function() end,
  }
  local ok, decorated = pcall(style.decorateFocusHelp, adapter, nil, 8)
  if not ok or decorated ~= adapter then
    return nil, tostring(decorated or "VASC fullscreen decoration failed")
  end
  adapters[owner] = adapter
  return adapter
end

local function playerHeader(menu)
  local save = menu and menu.game and menu.game.save or {}
  local player = type(save.player) == "table" and save.player or {}
  return "VOXEL ASCENDANT / " .. tostring(player.name or "TRAINER")
end

local function drawFullscreen(menu, winW, winH)
  local adapter, err = adapterFor(menu)
  if not adapter then M.lastError = err return false end
  local items = {}
  for _, item in ipairs(menu.items or {}) do
    items[#items + 1] = {
      label=startLabel(item),
      help=startHelp(item),
    }
  end
  adapter.game = menu.game
  adapter.items = items
  adapter.index = math.max(1, math.min(#items > 0 and #items or 1,
    math.floor(tonumber(menu.index) or 1)))
  adapter.scroll = math.max(0, math.floor(tonumber(menu.scroll) or 0))
  adapter.__vascHeaderLabel = playerHeader(menu)
  adapter.title = startTitle()
  adapter.footer = compactFooter(true)
  local drawer = adapter.drawWidescreen or adapter.draw
  if type(drawer) ~= "function" then
    M.lastError = "VASC fullscreen drawer unavailable"
    return false
  end
  local ok, result = pcall(drawer, adapter, winW, winH)
  if not ok then M.lastError = tostring(result) return false end
  M.lastError = nil
  return true
end

local function decorate(menu)
  if type(menu) ~= "table" or menu.__vascPersistentStartMode then return menu end
  if type(menu.draw) ~= "function" or type(menu.update) ~= "function" then
    return menu
  end
  local nativeDraw = menu.draw
  local nativeUpdate = menu.update

  -- START is a transparent overlay over the live world.  Mark this one state
  -- as presentation-owned before OrasUiSkin's screen.pushed listener sees it;
  -- otherwise both decorators can wrap the same draw call in opposite order.
  local skin = V and V.OrasUiSkin
  if type(skin) == "table" and type(skin.markCustom) == "function" then
    pcall(skin.markCustom, menu)
  end

  menu._vascStartFullscreen = savedFullscreenMode(menu.game)
  menu.update = function(self, ...)
    local input = self.game and self.game.input
    if (tonumber(self._vascStartInputGuard) or 0) > 0 then
      self._vascStartInputGuard = self._vascStartInputGuard - 1
      return
    end
    if input and type(input.wasPressed) == "function"
        and input:wasPressed("select") then
      togglePresentation(self, "select")
      return
    end
    return nativeUpdate(self, ...)
  end

  -- The Gen-1 host offers raw per-screen handlers before its abstract Input
  -- queue. On macOS TAB/Shift and some SDL Back buttons can otherwise reach
  -- the START-close path without ever becoming an observable `select` edge.
  -- Claim only the engine's default SELECT aliases here. Everything else is
  -- forwarded into the same Input object Game:keypressed/gamepadpressed uses,
  -- preserving navigation, rebinds and every native callback.
  local nativeKeyPressed = menu.onKeyPressed
  menu.onKeyPressed = function(self, key)
    if isSelectKey(self, key) then
      togglePresentation(self, "key:" .. key)
      return true
    end
    if type(nativeKeyPressed) == "function" then
      return nativeKeyPressed(self, key)
    end
    local input = self.game and self.game.input
    if input and type(input.keypressed) == "function" then
      input:keypressed(key)
    end
  end
  local nativeGamepadPressed = menu.onGamepadPressed
  menu.onGamepadPressed = function(self, button)
    if isSelectPad(self, button) then
      togglePresentation(self, "pad:" .. tostring(button))
      return true
    end
    if type(nativeGamepadPressed) == "function" then
      return nativeGamepadPressed(self, button)
    end
    local input = self.game and self.game.input
    if input and type(input.gamepadpressed) == "function" then
      input:gamepadpressed(nil, button)
    end
  end
  local nativeJoystickPressed = menu.onJoystickPressed
  menu.onJoystickPressed = function(self, button)
    if isSelectJoystick(self, button) then
      togglePresentation(self, "joy:" .. tostring(button))
      return true
    end
    if type(nativeJoystickPressed) == "function" then
      return nativeJoystickPressed(self, button)
    end
    local input = self.game and self.game.input
    if input and type(input.joystickpressed) == "function" then
      input:joystickpressed(nil, button)
    end
  end
  -- Never claim the game's UI canvas here.  Gen 1 centres its transparent
  -- 160x144 interface over a separately composed voxel world; changing the
  -- top state's uiSize to 800x600 clears the surrounding world to black.
  -- The modern plate is drawn later in render.hud, in physical screen space.
  menu.draw = function(self, ...)
    if modernUiEnabled(self) and M.hudHook and M.hudHealthy then
      return
    end
    return nativeDraw(self, ...)
  end
  menu.__vascPersistentStartMode = true
  menu.__vascPersistentStartNativeDraw = nativeDraw
  menu.__vascPersistentStartNativeUpdate = nativeUpdate
  M.decorated = M.decorated + 1
  diagnostic("gen1-start-menu-decorated", {
    screenId=menu.screenId or "StartMenu",
    fullscreen=menu._vascStartFullscreen == true,
    count=M.decorated,
  })
  return menu
end

local function topState(game)
  local stack = game and game.stack
  if not stack then return nil end
  if type(stack.top) == "function" then
    local ok, state = pcall(stack.top, stack)
    if ok then return state end
  end
  local states = stack.states
  return type(states) == "table" and states[#states] or nil
end

local function drawHud(game, viewport)
  local menu = topState(game)
  if type(menu) ~= "table" or not menu.__vascPersistentStartMode
      or not modernUiEnabled(menu) then
    return false
  end
  local ww = viewport and tonumber(viewport.width) or nil
  local wh = viewport and tonumber(viewport.height) or nil
  local plan
  if type(MobileMenuPresentation) == "table"
      and type(MobileMenuPresentation.isMobileRuntime) == "function"
      and type(MobileMenuPresentation.runtimePlan) == "function" then
    local okMobile, mobile = pcall(MobileMenuPresentation.isMobileRuntime)
    if okMobile and mobile then
      local okPlan, value = pcall(MobileMenuPresentation.runtimePlan,
        "start_menu", 512, 288, ww, wh)
      if okPlan and type(value) == "table" and value.active == true then
        plan = value
      end
    end
  end
  if plan then
    if not menu._vascStartFullscreen then
      -- Compact START is an overlay, not a complete screen. Draw it directly
      -- in the final notch-safe window so the live world remains visible and
      -- fonts are rasterised at device resolution instead of enlarging a
      -- 512x288 staging texture.
      local G = graphicsRuntime()
      local safe = plan.safe or plan.usable or plan.window
      if not (G and safe and type(G.push) == "function"
          and type(G.pop) == "function" and type(G.translate) == "function") then
        return false
      end
      G.push("all")
      if type(G.origin) == "function" then G.origin() end
      G.translate(tonumber(safe.x) or 0, tonumber(safe.y) or 0)
      local ok, result = pcall(drawEdge, menu, safe.w, safe.h, true)
      G.pop()
      if not ok then error(result, 0) end
      menu.__vascStartMobileReceipt = plan.receipt
      return result
    end
    if type(MobileMenuPresentation.presentLogical) ~= "function" then
      return false
    end
    local ok, result = MobileMenuPresentation.presentLogical(menu, plan, function()
      return drawFullscreen(menu, plan.logicalW, plan.logicalH)
    end, { backdrop={ .025, .045, .085, 1 } })
    if not ok then error(result, 0) end
    menu.__vascStartMobileReceipt = plan.receipt
    return result
  elseif menu._vascStartFullscreen then
    return drawFullscreen(menu, ww, wh)
  end
  return drawEdge(menu, ww, wh)
end

local function installHudHook()
  if M.hudHook then return true end
  local hooks = mod and mod.hooks
  if not (hooks and type(hooks.wrap) == "function") then
    return false, "render.hud hook unavailable"
  end
  hooks:wrap("render.hud", function(next, game, viewport)
    local out = next(game, viewport)
    local menu = topState(game)
    if type(menu) ~= "table" or not menu.__vascPersistentStartMode
        or not modernUiEnabled(menu) then
      return out
    end
    local ok, handled = pcall(drawHud, game, viewport)
    if ok and handled then
      M.hudHealthy = true
      M.lastError = nil
    else
      M.hudHealthy = false
      M.lastError = ok and "START HUD renderer unavailable" or tostring(handled)
    end
    return out
  end, 15150)
  M.hudHook = true
  return true
end

function M.install()
  if M.installed then return true end
  local ok, StartMenu = pcall(require, "src.ui.StartMenu")
  if not (ok and type(StartMenu) == "table" and type(StartMenu.new) == "function") then
    diagnostic("gen1-start-menu-install", {
      result="failed", reason="src.ui.StartMenu.new unavailable",
    })
    return false, "src.ui.StartMenu.new unavailable"
  end
  if not StartMenu.__vascPersistentModePatched then
    local nativeNew = StartMenu.new
    StartMenu.new = function(...)
      return decorate(nativeNew(...))
    end
    StartMenu.__vascPersistentModePatched = true
  end
  local hudOk, hudReason = installHudHook()
  if not hudOk then
    diagnostic("gen1-start-menu-install", { result="failed", reason=hudReason })
    return false, hudReason
  end
  local events = mod and mod.events
  local watcher = false
  if events and type(events.on) == "function" then
    local eventOk = pcall(events.on, events, "screen.pushed", function(event)
      local state = type(event) == "table" and event.state or nil
      if type(state) == "table" and state.screenId == "StartMenu" then
        decorate(state)
      end
    end)
    watcher = eventOk == true
  end
  M.installed = true
  diagnostic("gen1-start-menu-install", {
    result="active", constructor=true, hud=true, watcher=watcher,
    sharedOwner=type(V and V.OrasUiSkin) == "table",
  })
  return true
end

function M.status()
  return {
    installed=M.installed,
    decorated=M.decorated,
    hudHook=M.hudHook,
    hudHealthy=M.hudHealthy,
    fullscreen=savedFullscreenMode(),
    lastError=M.lastError,
  }
end

M.decorate = decorate
M.startLabelForQa = startLabel
return M
