-- Responsive ORAS-glass renderer for Gold's actual Gen-2 START menu.
--
-- v0.2.39 keeps Gold's native menu logic and makes the panel tall enough to
-- show every ordinary START-menu entry at once.  If another mod injects more
-- rows than can physically fit, it falls back to a readable scrolling window.
--
-- Gold's native menu logic remains untouched.  This module owns only the
-- physical draw surface while OVERWORLD MENUS is ORAS GLASS; GAME DEFAULT
-- delegates to the exact engine methods live.
local V = ...
local mod = V and V.mod
local OrasUiSkin = V and V.OrasUiSkin
local SharedMenus = V and V.SharedMenuPresentation
local Diagnostics = V and V.Diagnostics
local CanvasPresentation = V and V.CanvasPresentation

local function german()
  if not (mod and type(mod.find) == "function") then return false end
  local ok, handle = pcall(mod.find, "translation-german-universal")
  if not ok or not handle then
    ok, handle = pcall(mod.find, mod, "translation-german-universal")
  end
  return ok and type(handle) == "table" and type(handle.exports) == "table"
    and handle.exports.bootLanguage == "de"
end
local function tr(en, de) return german() and de or en end

local M = {
  installed = false,
  draws = 0,
  resolved = 0,
  registryHook = false,
  target = "src.ui.gen2.StartMenu",
  lastError = nil,
}

local fonts = {}
local activeEdition = "crystal"
local START_MODE_KEY = "startMenuFullscreen"

local EDITION_ACCENTS = {
  gold = { 0.92, 0.67, 0.13 },
  silver = { 0.68, 0.75, 0.84 },
  crystal = { 0.12, 0.78, 0.95 },
}

local function customUIEnabled()
  -- `customUI` is a retired migration tombstone.  The START skin is governed
  -- exclusively by the visible `qol_ui_skin` option.
  return true
end

local function orasUIEnabled()
  if not customUIEnabled() then return false end
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return true end
  local ok, value = pcall(options.get, options, "qol_ui_skin")
  if not ok or value == nil then return true end
  value = tostring(value):lower()
  return value == "oras" or value == "oras_glass"
end

local function font(size)
  size = math.max(5, math.floor((tonumber(size) or 10) + 0.5))
  if fonts[size] ~= nil then return fonts[size] or nil end
  local G = love and love.graphics
  if not (G and type(G.newFont) == "function") then
    fonts[size] = false
    return nil
  end
  local ok, f = pcall(G.newFont, size)
  fonts[size] = ok and f or false
  return fonts[size] or nil
end

local function roundRect(mode, x, y, w, h, r)
  love.graphics.rectangle(mode, x, y, w, h, r, r)
end

local function panel(x, y, w, h, r, alpha, uiScale)
  local G = love.graphics
  local accent = EDITION_ACCENTS[activeEdition] or EDITION_ACCENTS.crystal
  G.setColor(0.018, 0.022, 0.030, alpha or 0.92)
  roundRect("fill", x, y, w, h, r)
  G.setColor(accent[1], accent[2], accent[3], 0.94)
  G.setLineWidth(math.max(1, 2 * (uiScale or 1)))
  roundRect("line", x, y, w, h, r)
end

local function targetDimensions(fallbackW, fallbackH)
  local mobile = CanvasPresentation
    and (CanvasPresentation.OS == "iOS"
      or CanvasPresentation.OS == "Android")
  local G = love and love.graphics
  -- draw() resets the transform with graphics.origin().  On mobile its
  -- coordinate space is therefore the physical window, even when the engine
  -- passes the narrower emulated/HUD viewport as fallback dimensions.
  if mobile and G and type(G.getDimensions) == "function" then
    local ok, w, h = pcall(G.getDimensions)
    if ok and w and h and w > 0 and h > 0 then return w, h end
  end
  if fallbackW and fallbackH and fallbackW > 0 and fallbackH > 0 then
    return fallbackW, fallbackH
  end
  if not G then return nil, nil end
  if type(G.getCanvas) == "function" then
    local ok, c = pcall(G.getCanvas)
    if ok and c and type(c.getDimensions) == "function" then
      local cw, ch = c:getDimensions()
      if cw and ch and cw > 0 and ch > 0 then return cw, ch end
    end
  end
  if type(G.getDimensions) == "function" then return G.getDimensions() end
  return nil, nil
end

-- Read-only acceptance seam; production drawing continues to call the local
-- resolver above and no menu/input ownership is exposed.
M.mobileWindowForQA = targetDimensions

local function drawBackdrop(ww, wh)
  local G = love.graphics
  G.setColor(0.010, 0.016, 0.028, 1)
  G.rectangle("fill", 0, 0, ww, wh)
  G.setColor(0.045, 0.090, 0.150, 1)
  G.rectangle("fill", 0, 0, ww, math.max(1, wh * 0.32))
  local inset = math.max(8, math.floor(math.min(ww, wh) * 0.018))
  G.setColor(1, 1, 1, 0.94)
  G.setLineWidth(math.max(2, math.floor(math.min(ww, wh) * 0.004)))
  G.rectangle("line", inset, inset, ww - inset * 2, wh - inset * 2,
    math.max(8, inset * 0.7), math.max(8, inset * 0.7))
end

local function uiScaleFor(ww, wh)
  return math.max(0.18, math.min(1, math.min(ww / 800, wh / 600)))
end

local function cleanText(text)
  text = tostring(text or "")
  text = text:gsub("<PO><KE>", "POKé")
  text = text:gsub("<PK><MN>", "POKéMON")
  text = text:gsub("<POKE>", "POKé")
  text = text:gsub("<NEXT>", " ")
  text = text:gsub("[\v\f\r]", " ")
  text = text:gsub("\n", "  ")
  text = text:gsub("%s+", " ")
  return text
end

local function recordMode(menu, trigger)
  if type(Diagnostics) ~= "table" or type(Diagnostics.write) ~= "function" then
    return
  end
  pcall(Diagnostics.write, "gen2-start-menu-mode", {
    mode=menu and menu._vascGen2StartFullscreen and "fullscreen" or "edge",
    trigger=trigger or "select",
  })
end

local function optionValue(game)
  local options = game and game.save and game.save.options
  local buckets = type(options) == "table" and options.modOptions or nil
  local bucket = type(buckets) == "table" and buckets.VOXEL_ASCENDANT or nil
  if type(bucket) == "table" and bucket[START_MODE_KEY] ~= nil then
    return bucket[START_MODE_KEY]
  end
  local api = mod and mod.options
  if api and type(api.get) == "function" then
    local ok, value = pcall(api.get, api, START_MODE_KEY)
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
  local ok, value = pcall(save.get, save, START_MODE_KEY)
  if not ok then return false end
  return value == true or value == 1 or value == "1"
    or value == "fullscreen"
end

local function persistFullscreenMode(game, value)
  local save = mod and mod.save
  local memoryOk = false
  if save and type(save.set) == "function" then
    local ok, result = pcall(save.set, save, START_MODE_KEY, value == true)
    memoryOk = ok and result ~= false
  end
  local options = game and game.save and game.save.options
  if type(options) ~= "table" then return memoryOk end
  options.modOptions = options.modOptions or {}
  options.modOptions.VOXEL_ASCENDANT =
    options.modOptions.VOXEL_ASCENDANT or {}
  options.modOptions.VOXEL_ASCENDANT[START_MODE_KEY] = value == true
  if type(game.writeOptions) == "function" then
    local ok = pcall(game.writeOptions, game)
    return ok or memoryOk
  end
  return memoryOk
end

local function toggleMode(menu, trigger)
  menu._vascGen2StartFullscreen = not menu._vascGen2StartFullscreen
  menu._vascGen2StartInputGuard = 1
  persistFullscreenMode(menu.game, menu._vascGen2StartFullscreen)
  recordMode(menu, trigger)
end

-- START is deliberately a compact right-edge overlay on a fresh save. SELECT
-- switches to the large shared Kanto/VASC view and persists that presentation
-- preference. Reopening START or restarting the game therefore restores the
-- player's last choice without altering any native menu item or callback.
local function updateWithModeToggle(menu, nativeUpdate, ...)
  local input = menu and menu.game and menu.game.input
  if (tonumber(menu and menu._vascGen2StartInputGuard) or 0) > 0 then
    menu._vascGen2StartInputGuard = menu._vascGen2StartInputGuard - 1
    return
  end
  if not menu.phase and input and type(input.wasPressed) == "function"
      and input:wasPressed("select") then
    toggleMode(menu, "select")
    return
  end
  return nativeUpdate(menu, ...)
end

local function mappedSelect(menu, mapName, value, fallback)
  local input = menu and menu.game and menu.game.input
  local mappings = input and input[mapName]
  if type(mappings) == "table" and mappings[value] ~= nil then
    return mappings[value] == "select"
  end
  return fallback == true
end

local function installRawSelectHandlers(menu)
  if menu._vascGen2RawSelectHandlers then return end
  local nativeKey = menu.onKeyPressed
  menu.onKeyPressed = function(self, key)
    if mappedSelect(self, "keyBindings", key,
        key == "tab" or key == "rshift" or key == "lshift") then
      toggleMode(self, "key:" .. tostring(key))
      return true
    end
    if type(nativeKey) == "function" then return nativeKey(self, key) end
    local input = self.game and self.game.input
    if input and type(input.keypressed) == "function" then input:keypressed(key) end
  end
  local nativePad = menu.onGamepadPressed
  menu.onGamepadPressed = function(self, button)
    if mappedSelect(self, "padBindings", button, button == "back") then
      toggleMode(self, "pad:" .. tostring(button))
      return true
    end
    if type(nativePad) == "function" then return nativePad(self, button) end
    local input = self.game and self.game.input
    if input and type(input.gamepadpressed) == "function" then
      input:gamepadpressed(nil, button)
    end
  end
  local nativeJoy = menu.onJoystickPressed
  menu.onJoystickPressed = function(self, button)
    local fallback = button == 7 or button == 9
    if mappedSelect(self, "joyBindings", button, fallback) then
      toggleMode(self, "joy:" .. tostring(button))
      return true
    end
    if type(nativeJoy) == "function" then return nativeJoy(self, button) end
    local input = self.game and self.game.input
    if input and type(input.joystickpressed) == "function" then
      input:joystickpressed(nil, button)
    end
  end
  menu._vascGen2RawSelectHandlers = true
end

local function clipped(text, f, maxW)
  text = cleanText(text)
  if not f or type(f.getWidth) ~= "function" or f:getWidth(text) <= maxW then
    return text
  end
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
  while #text > 0 and f:getWidth(text .. suffix) > maxW do
    text = dropLastCodepoint(text)
  end
  return text .. suffix
end

-- Same battle-selector geometry, but dynamically compress the row height just
-- enough to keep all normal pause rows visible.  At 600p+ eight rows fit with
-- no scroll.  A pathological hook list still receives a readable minimum row
-- height and uses a cursor-following window.
local function selectorGeometry(ww, wh, requestedRows)
  local s = uiScaleFor(ww, wh)
  local margin = math.max(18 * s, wh * 0.025)
  local w = math.min(ww * 0.42, 560 * s)
  local gap = math.max(7 * s, wh * 0.008)
  local headerH = math.max(48 * s, wh * 0.060)
  local footerH = math.max(42 * s, wh * 0.052)
  local baseRowH = math.max(54 * s, math.min(76 * s, wh * 0.076))
  local minRowH = math.max(31 * s, wh * 0.041)
  local available = math.max(1, wh - margin * 2)
  local rows = math.max(1, math.floor(tonumber(requestedRows) or 1))

  local function heightFor(n, rh)
    return headerH + rh * n + gap * (n + 1) + footerH
  end

  local rowH = baseRowH
  local h = heightFor(rows, rowH)
  if h > available then
    rowH = (available - headerH - footerH - gap * (rows + 1)) / rows
    if rowH < minRowH then
      rowH = minRowH
      rows = math.max(1, math.floor(
        (available - headerH - footerH - gap) / (rowH + gap)))
    end
    h = heightFor(rows, rowH)
  end

  local x = ww - w - margin
  local y = wh - h - margin
  local r = math.max(14 * s, wh * 0.022)
  return x, y, w, h, rowH, gap, headerH, footerH, r, s, rows
end

local function selectorHeader(G, title, subtitle, x, y, w, headerH, wh, s)
  local titleFont = font(math.max(18 * s, wh * 0.023))
  local metaFont = font(math.max(11 * s, wh * 0.013))
  if titleFont then G.setFont(titleFont) end
  G.setColor(1, 1, 1, 0.98)
  G.print(clipped(title, G.getFont(), w * 0.89), x + w * 0.055, y + headerH * 0.22)
  if subtitle and subtitle ~= "" then
    if metaFont then G.setFont(metaFont) end
    G.setColor(1, 1, 1, 0.58)
    G.print(clipped(subtitle, G.getFont(), w * 0.89),
            x + w * 0.055, y + headerH * 0.68)
  end
end

local function selectorFooter(G, text, x, y, w, h, gap, wh, s)
  local metaFont = font(math.max(11 * s, wh * 0.013))
  if metaFont then G.setFont(metaFont) end
  G.setColor(1, 1, 1, 0.58)
  G.printf(text, x + gap * 1.5, y + h - math.max(30 * s, wh * 0.037),
           w - gap * 3, "left")
end

local function rowLabel(item)
  return cleanText(item and item.label or "")
end

local function rowDescription(item)
  local desc = item and item.desc
  if type(desc) == "table" then
    local a, b = cleanText(desc[1]), cleanText(desc[2])
    if a ~= "" and b ~= "" then return a .. " " .. b end
    return a ~= "" and a or b
  end
  return cleanText(desc)
end

local START_LABEL_DE = {
  pokedex="POKéDEX", pokemon="POKéMON", pack="TASCHE",
  pokegear="POKéGEAR", status="TRAINERKARTE", save="SPEICHERN",
  option="OPTIONEN", mods="MODS", quit="BEENDEN",
}

local START_HELP_DE = {
  pokedex="Öffnet den modernen Johto-Pokédex mit gesehenen und gefangenen Pokémon.",
  pokemon="Öffnet die vollständige ORAS-Teamansicht; Wechsel, Feldattacken und Items bleiben Gen-2-Logik.",
  pack="Öffnet die ORAS-Tasche mit allen vier Gold/Silber/Kristall-Fächern.",
  pokegear="Öffnet Pokégear mit Uhr, Johto-Karte, Telefon, Radio und freigeschalteten Flugzielen.",
  status="Zeigt die moderne Trainerkarte mit deinem aktuellen Spielfortschritt.",
  save="Speichert über die unveränderte native Gold/Silber/Kristall-Speicherroutine.",
  option="Öffnet die Spieleinstellungen.",
  mods="Öffnet installierte Mods und die Voxel-Ascendant-Zentrale.",
  quit="Kehrt nach Bestätigung zum Titelbild zurück.",
}

local START_META_DE = {
  pokedex="Moderner Johto-Pokédex",
  pokemon="Team ansehen und verwalten",
  pack="Items und Schlüsseltasche",
  pokegear="Uhr, Karte, Telefon und Radio",
  status="Trainerkarte und Fortschritt",
  save="Spielstand sicher speichern",
  option="Spieleinstellungen öffnen",
  mods="Installierte Erweiterungen",
  quit="Zum Titelbild zurückkehren",
}

local START_LABEL_EN = {
  pokedex="POKéDEX", pokemon="POKéMON", pack="BAG",
  pokegear="POKéGEAR", status="TRAINER CARD", save="SAVE",
  option="OPTIONS", mods="MODS", quit="EXIT",
}
local START_HELP_EN = {
  pokedex="Open the modern Johto Pokédex with seen and caught Pokémon.",
  pokemon="Open the full ORAS team view. Switching, field moves and items keep Gen 2 rules.",
  pack="Open the ORAS bag with all four Gold/Silver/Crystal pockets.",
  pokegear="Open the clock, Johto map, phone, radio and unlocked flight destinations.",
  status="Show the modern trainer card and your current progress.",
  save="Save using the unchanged native Gold/Silver/Crystal save routine.",
  option="Open game settings.", mods="Open installed mods and the Voxel Ascendant hub.",
  quit="Return to the title screen after confirmation.",
}
local START_META_EN = {
  pokedex="Modern Johto Pokédex", pokemon="View and manage your team",
  pack="Items and key items", pokegear="Clock, map, phone and radio",
  status="Trainer card and progress", save="Save your progress",
  option="Open game settings", mods="Installed extensions",
  quit="Return to the title screen",
}
local function localized(en, de, id, fallback)
  return (german() and de or en)[id] or fallback
end

local function drawSharedPause(menu, ww, wh)
  if not (SharedMenus and type(SharedMenus.draw) == "function") then
    return false
  end
  local list = menu and menu.list
  if not (menu and list and type(menu.items) == "table") then return false end
  if menu.phase == "confirm" then
    return SharedMenus.draw(menu, {
    title=tr("EXIT GAME?", "SPIEL BEENDEN?"),
      items={
        { label=tr("YES", "JA"), help=tr("Unsaved progress will be lost.", "Ungespeicherter Fortschritt geht verloren.") },
        { label=tr("NO", "NEIN"), help=tr("Return to the game.", "Zum Spiel zurückkehren.") },
      },
      index=tonumber(menu.confirmChoice) or 2,
    footer=tr("A: CONFIRM   B: BACK", "A: BESTÄTIGEN   B: ZURÜCK"),
    }, ww, wh)
  end
  local items = {}
  for _, item in ipairs(menu.items) do
    local id = tostring(item.value or "")
    items[#items + 1] = {
    label=localized(START_LABEL_EN, START_LABEL_DE, id, rowLabel(item)),
    help=localized(START_HELP_EN, START_HELP_DE, id, rowDescription(item)),
    }
  end
  local save = menu.save or (menu.game and menu.game.save) or {}
  local player = save.player or {}
  return SharedMenus.draw(menu, {
    title=tr("START MENU", "START-MENÜ"),
    header="VOXEL ASCENDANT / " .. cleanText(player.name or "TRAINER"),
    items=items,
    index=tonumber(list.index) or 1,
    scroll=tonumber(list.scroll) or 0,
    footer=tr("A: OPEN  B: BACK  SELECT: EDGE", "A: ÖFFNEN  B: ZURÜCK  SELECT: RAND"),
  }, ww, wh)
end

local function drawRows(menu, x, y, w, rowH, gap, headerH, r, wh, s, rows)
  local G = love.graphics
  local list = menu.list
  local items = menu.items or (list and list.items) or {}
  local n = #items
  if n <= 0 then return end

  local cursor = math.max(1, math.min(math.floor(tonumber(list and list.index) or 1), n))
  local first = 1
  if n > rows then
    local engineFirst = math.max(1, math.floor(tonumber(list and list.scroll) or 0) + 1)
    first = engineFirst
    if cursor < first then first = cursor end
    if cursor > first + rows - 1 then first = cursor - rows + 1 end
    if first + rows - 1 > n then first = math.max(1, n - rows + 1) end
  end

  local nameFont = font(math.max(14 * s, math.min(18 * s, rowH * 0.31)))
  local metaFont = font(math.max(9 * s, math.min(12 * s, rowH * 0.22)))

  for slot = 1, rows do
    local i = first + slot - 1
    local item = items[i]
    if not item then break end
    local ry = y + headerH + gap + (slot - 1) * (rowH + gap)
    local on = i == cursor

    G.setColor(on and 0.16 or 0.10, on and 0.35 or 0.19,
               on and 0.56 or 0.30, on and 0.94 or 0.82)
    roundRect("fill", x + gap, ry, w - gap * 2, rowH, r * 0.55)
    if on then
      G.setColor(1.00, 0.72, 0.24, 0.98)
      G.setLineWidth(math.max(1, 2 * s))
      roundRect("line", x + gap, ry, w - gap * 2, rowH, r * 0.55)
    end

    if nameFont then G.setFont(nameFont) end
    G.setColor(1, 1, 1, 0.98)
    local lx = x + gap * (on and 4.3 or 2.2)
    local maxW = w - gap * (on and 6.5 or 4.4)
    if on and type(G.circle) == "function" and type(G.line) == "function" then
      local accent = EDITION_ACCENTS[activeEdition] or EDITION_ACCENTS.crystal
      local cx, cy = x + gap * 2.25, ry + rowH * 0.5
      local radius = math.max(4 * s, math.min(8 * s, rowH * 0.18))
      G.setColor(1, 1, 1, 0.98)
      G.circle("fill", cx, cy, radius)
      G.setColor(accent[1], accent[2], accent[3], 1)
      G.setLineWidth(math.max(1, 1.5 * s))
      G.circle("line", cx, cy, radius)
      G.line(cx - radius, cy, cx + radius, cy)
      G.circle("fill", cx, cy, math.max(1.5 * s, radius * 0.32))
      G.setColor(1, 1, 1, 1)
      G.circle("fill", cx, cy, math.max(0.8 * s, radius * 0.15))
    end
    local itemId = tostring(item.value or ""):lower()
    local meta = localized(START_META_EN, START_META_DE, itemId, rowDescription(item))
    local nameY = meta ~= "" and (ry + rowH * 0.14) or (ry + rowH * 0.31)
    local displayLabel = localized(START_LABEL_EN, START_LABEL_DE, itemId, rowLabel(item))
    G.print(clipped(displayLabel, G.getFont(), maxW), lx, nameY)

    if meta ~= "" and rowH >= 34 * s then
      if metaFont then G.setFont(metaFont) end
      G.setColor(1, 1, 1, 0.58)
      G.print(clipped(meta, G.getFont(), maxW), lx, ry + rowH * 0.60)
    end
  end
end

local function drawDescription(menu, ww, wh, menuX, s)
  if menu.showDescription == false then return end
  local list = menu.list
  local item = list and type(list.current) == "function" and list:current() or nil
  local text = rowDescription(item)
  if text == "" then return end

  local G = love.graphics
  local margin = math.max(18 * s, wh * 0.025)
  local available = math.max(0, menuX - margin * 2)
  if available < 70 * s then return end
  local w = math.min(ww * 0.54, 720 * s, available)
  local h = math.max(66 * s, math.min(105 * s, wh * 0.105))
  local x = margin
  local y = wh - h - margin
  local r = math.max(14 * s, wh * 0.022)
  panel(x, y, w, h, r, 0.78, s)

  local titleFont = font(math.max(15 * s, wh * 0.020))
  local metaFont = font(math.max(11 * s, wh * 0.013))
  if titleFont then G.setFont(titleFont) end
  G.setColor(1, 1, 1, 0.96)
  G.print(clipped(rowLabel(item), G.getFont(), w - h * 0.44),
          x + h * 0.22, y + h * 0.17)
  if metaFont then G.setFont(metaFont) end
  G.setColor(1, 1, 1, 0.62)
  G.printf(text, x + h * 0.22, y + h * 0.55,
           w - h * 0.44, "left")
end

local function drawConfirm(menu, ww, wh)
  local G = love.graphics
  local x, y, w, h, rowH, gap, headerH, _, r, s = selectorGeometry(ww, wh, 2)
  panel(x, y, w, h, r, 0.82, s)
  selectorHeader(G, tr("RETURN TO TITLE?", "ZUM TITELBILD?"), tr("UNSAVED PROGRESS WILL BE LOST", "UNGESPEICHERTER FORTSCHRITT GEHT VERLOREN"),
                 x, y, w, headerH, wh, s)

  local nameFont = font(math.max(15 * s, wh * 0.019))
  local choices = { tr("YES", "JA"), tr("NO", "NEIN") }
  local selected = math.max(1, math.min(2, tonumber(menu.confirmChoice) or 2))
  for i = 1, 2 do
    local ry = y + headerH + gap + (i - 1) * (rowH + gap)
    local on = i == selected
    G.setColor(1, 1, 1, on and 0.17 or 0.07)
    roundRect("fill", x + gap, ry, w - gap * 2, rowH, r * 0.55)
    if on then
      G.setColor(1, 1, 1, 0.72)
      G.setLineWidth(math.max(1, 2 * s))
      roundRect("line", x + gap, ry, w - gap * 2, rowH, r * 0.55)
    end
    if nameFont then G.setFont(nameFont) end
    G.setColor(1, 1, 1, 0.98)
    G.print(choices[i], x + gap * 2.2, ry + rowH * 0.32)
  end

  selectorFooter(G,
    tr("D-PAD: SELECT    A: CONFIRM    B: BACK", "STEUERKREUZ: AUSWAHL    A: BESTÄTIGEN    B: ZURÜCK"),
    x, y, w, h, gap, wh, s)

  local margin = math.max(18 * s, wh * 0.025)
  local available = math.max(0, x - margin * 2)
  if available >= 70 * s then
    local mw = math.min(ww * 0.54, 720 * s, available)
    local mh = math.max(66 * s, math.min(105 * s, wh * 0.105))
    local mx, my = margin, wh - mh - margin
    local mr = math.max(14 * s, wh * 0.022)
    panel(mx, my, mw, mh, mr, 0.78, s)
    local f = font(math.max(15 * s, wh * 0.020))
    if f then G.setFont(f) end
    G.setColor(1, 1, 1, 0.96)
    G.printf(tr("Return to the title screen?", "Zum Titelbild zurückkehren?"), mx + mh * 0.22, my + mh * 0.29,
             mw - mh * 0.44, "left")
  end
end

local function drawPause(menu, fallbackW, fallbackH)
  local G = love and love.graphics
  local list = menu and menu.list
  if not (G and menu and list and type(menu.items) == "table") then return false end

  -- When a pause-launched submenu is on top, keep the START menu itself out of
  -- the picture.  Gold's world is still visible beneath the transparent modern
  -- submenu, instead of showing two glass lists on top of each other.
  local stack = menu.game and menu.game.stack
  if stack and type(stack.top) == "function" then
    local ok, top = pcall(stack.top, stack)
    if ok and top and top ~= menu then return true end
  end

  local ww, wh = targetDimensions(fallbackW, fallbackH)
  if not (ww and wh and ww > 0 and wh > 0) then return false end

  -- The ordinary Gen-2 START menu stays a compact overlay at the screen edge,
  -- like the cartridge window and Kanto's field menu. The large shared view is
  -- available after SELECT and restored from the player's saved preference.
  if menu._vascGen2StartFullscreen == true then
    local okShared, sharedHandled = pcall(drawSharedPause, menu, ww, wh)
    if okShared and sharedHandled then
      M.draws = M.draws + 1
      return true
    end
    if not okShared then M.lastError = tostring(sharedHandled) end
  end

  G.push("all")
  G.origin()
  if type(G.setBlendMode) == "function" then G.setBlendMode("alpha") end
  local save = menu.save or (menu.game and menu.game.save) or {}
  local edition = tostring(save.version or "crystal"):lower()
  activeEdition = EDITION_ACCENTS[edition] and edition or "crystal"

  if menu.phase == "confirm" then
    drawConfirm(menu, ww, wh)
  else
    local requested = math.max(1, #menu.items)
    local x, y, w, h, rowH, gap, headerH, _, r, s, rows =
      selectorGeometry(ww, wh, requested)
    panel(x, y, w, h, r, 0.82, s)

    local save = menu.save or (menu.game and menu.game.save) or {}
    local player = save.player or {}
    local playerName = cleanText(player.name or "GOLD")
    local index = math.max(1, math.min(#menu.items, tonumber(list.index) or 1))
    local subtitle = playerName
    if #menu.items > rows then
      subtitle = subtitle .. "    " .. index .. "/" .. #menu.items
    end
  selectorHeader(G, tr("START MENU", "START-MENÜ"), subtitle, x, y, w, headerH, wh, s)
    drawRows(menu, x, y, w, rowH, gap, headerH, r, wh, s, rows)
    selectorFooter(G,
    tr("A: OPEN   B: BACK   SELECT: FULLSCREEN", "A: ÖFFNEN   B: ZURÜCK   SELECT: VOLLBILD"),
      x, y, w, h, gap, wh, s)
    -- Match Kanto's ordinary START behavior: a compact selector over the live
    -- world.  Detailed help belongs to the Ascendant/options hub, not to a
    -- fullscreen pause replacement.
  end

  G.pop()
  M.draws = M.draws + 1
  return true
end

-- Screen registry entries deliberately win over built-in classes in the
-- engine.  Patching only src.ui.gen2.StartMenu therefore left a legitimate
-- Registry-provided Gen2StartMenu on the cartridge renderer.  Decorate the
-- resolved instance at StateStack's public screen.pushed boundary as well.
-- This changes draw ownership only: update/input/callbacks and the native
-- transparent-overworld behavior remain on the resolved screen itself.
local function decorateResolvedStart(state)
  if type(state) ~= "table" or state.screenId ~= "Gen2StartMenu" then
    return false
  end
  if state._vascGen2ResolvedStartPresentation then return true end

  local nativeDraw = state.draw
  local nativeUpdate = state.update
  local nativeDrawsWide = type(state.drawsWidescreen) == "function"
    and state.drawsWidescreen or nil
  local nativeWide = type(state.drawWidescreen) == "function"
    and state.drawWidescreen or nil
  if type(nativeDraw) ~= "function" then
    state._vascGen2ResolvedStartPresentation = "native-no-draw"
    return false
  end

  state._vascGen2StartFullscreen = savedFullscreenMode(state.game)
  installRawSelectHandlers(state)
  if type(nativeUpdate) == "function" then
    state.update = function(self, ...)
      return updateWithModeToggle(self, nativeUpdate, ...)
    end
  end
  state.drawsWidescreen = function(self, ...)
    if orasUIEnabled() and self._vascGen2StartFullscreen == true then
      return true
    end
    if nativeDrawsWide then return nativeDrawsWide(self, ...) end
    return false
  end

  state.draw = function(self, ...)
    if orasUIEnabled() then
      local okDraw, handled = pcall(drawPause, self)
      if okDraw and handled then M.lastError = nil return end
      if not okDraw then M.lastError = tostring(handled) end
    end
    return nativeDraw(self, ...)
  end
  -- Do not opt a transparent START menu into widescreen ownership.  Some
  -- registry screens already provide that method, though; preserve and skin
  -- it when present without changing drawsWidescreen.
  if nativeWide then
    state.drawWidescreen = function(self, ww, wh, ...)
      if orasUIEnabled() then
        local okDraw, handled = pcall(drawPause, self, ww, wh)
        if okDraw and handled then M.lastError = nil return end
        if not okDraw then M.lastError = tostring(handled) end
      end
      return nativeWide(self, ww, wh, ...)
    end
  end
  state._vascGen2ResolvedStartPresentation = "oras-start"
  state._vascGen2ResolvedStartNativeDraw = nativeDraw
  state._vascGen2ResolvedStartNativeWide = nativeWide
  state._vascGen2ResolvedStartNativeUpdate = nativeUpdate
  M.resolved = M.resolved + 1
  return true
end

local function installResolvedStartWatcher()
  if mod and mod._vascGen2ResolvedStartWatcher then
    M.registryHook = true
    return true
  end
  local events = mod and mod.events
  if not (events and type(events.on) == "function") then
    return false, "mod.events:on unavailable"
  end
  local ok, err = pcall(events.on, events, "screen.pushed", function(event)
    decorateResolvedStart(event and event.state)
  end)
  if not ok then return false, tostring(err) end
  mod._vascGen2ResolvedStartWatcher = true
  M.registryHook = true
  return true
end

function M.install()
  if M.installed then return true end

  local ok, StartMenu = pcall(require, "src.ui.gen2.StartMenu")
  if not (ok and type(StartMenu) == "table" and type(StartMenu.draw) == "function") then
    return false, "src.ui.gen2.StartMenu.draw unavailable"
  end
  if not StartMenu._stadium2CustomBattlePausePatched then
    -- Own presentation only. Navigation, row count, callbacks and
    -- confirmation remain StartMenu's native Gen-II implementation.
    local nativeDraw = StartMenu.draw
    local nativeWide = StartMenu.drawWidescreen
    local nativeDrawsWide = StartMenu.drawsWidescreen
    local nativeUpdate = StartMenu.update
    if type(nativeUpdate) == "function" then
      StartMenu.update = function(self, ...)
        return updateWithModeToggle(self, nativeUpdate, ...)
      end
    end
    StartMenu.draw = function(self, ...)
      if orasUIEnabled() then
        local okDraw, handled = pcall(drawPause, self)
        if okDraw and handled then M.lastError = nil return end
        if not okDraw then M.lastError = tostring(handled) end
      end
      return nativeDraw(self, ...)
    end
    StartMenu.drawsWidescreen = function(self, ...)
      if orasUIEnabled() and self._vascGen2StartFullscreen == true then
        return true
      end
      if type(nativeDrawsWide) == "function" then
        return nativeDrawsWide(self, ...)
      end
      return false
    end
    if type(nativeWide) == "function" then
      StartMenu.drawWidescreen = function(self, ww, wh, ...)
        if orasUIEnabled() then
          local okDraw, handled = pcall(drawPause, self, ww, wh)
          if okDraw and handled then M.lastError = nil return end
          if not okDraw then M.lastError = tostring(handled) end
        end
        return nativeWide(self, ww, wh, ...)
      end
    end
    StartMenu._stadium2CustomBattlePausePatched = true
  end

  local watcherOk, watcherErr = installResolvedStartWatcher()
  if not watcherOk then return false, watcherErr end
  M.installed = true
  return true
end

function M.status()
  return {
    installed = M.installed,
    draws = M.draws,
    resolved = M.resolved,
    registryHook = M.registryHook,
    target = M.target,
    lastError = M.lastError,
  }
end

-- Narrow test seam: verifies registry decoration/fallback without changing
-- how production screens are constructed or pushed.
M.decorateResolvedStart = decorateResolvedStart
M.editionAccents = EDITION_ACCENTS

return M
