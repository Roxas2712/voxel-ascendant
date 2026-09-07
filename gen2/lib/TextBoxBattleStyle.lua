-- Gold/Silver KASC/VASC presentation for Gold's shared dialogue and YES/NO boxes.
--
-- Presentation only: src.render.TextBox still owns substitution, pagination,
-- typewriter timing, CONT/page waits, auto text, choice spawning and input.
-- src.ui.ChoiceBox still owns selection and answer timing.  This module only
-- replaces draw() while CUSTOM UI / MENUS is enabled, so scripts and battle/
-- overworld state machines keep the engine's current behaviour exactly.
local V = ...
local mod = V and V.mod

local M = {
  installed = false,
  textDraws = 0,
  choiceDraws = 0,
  lastError = nil,
}

local fonts = {}

-- Dialogue owns this opaque paper/silver surface. None of these roles are
-- imported from the battle controller or its edition-theme module: HUD
-- furniture must never leak back into ordinary NPC/script text.
local C = {
  ink = { 0.075, 0.090, 0.105, 1 },
  paper = { 0.965, 0.945, 0.820, 1 },
  paper2 = { 0.900, 0.885, 0.775, 1 },
  gold = { 0.930, 0.680, 0.105, 1 },
  goldDark = { 0.530, 0.350, 0.055, 1 },
  silver = { 0.800, 0.835, 0.855, 1 },
  silverDark = { 0.285, 0.330, 0.365, 1 },
}

local function color(value, alpha)
  love.graphics.setColor(value[1], value[2], value[3], alpha or value[4] or 1)
end

local function customUIEnabled()
  local options = mod and mod.options
  if not (options and type(options.get) == "function") then return true end
  local ok, value = pcall(options.get, options, "customUI")
  if not ok or value == nil then return true end
  return value ~= false
end

local function font(size)
  size = math.max(8, math.floor((tonumber(size) or 18) + 0.5))
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

local function targetDimensions()
  local G = love and love.graphics
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

local function uiScaleFor(ww, wh)
  return math.max(0.55, math.min(1.75, math.min(ww / 800, wh / 600)))
end

local function dialogueFrame(x, y, w, h, s)
  local G = love.graphics
  local edge = math.max(2, math.floor(4 * s + 0.5))
  local rail = math.max(3, math.floor(6 * s + 0.5))

  G.setColor(0, 0, 0, 0.30)
  G.rectangle("fill", x + edge, y + edge, w, h)
  color(C.silver)
  G.rectangle("fill", x, y, w, h)
  color(C.silverDark)
  G.setLineWidth(math.max(1, 2 * s))
  G.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
  color(C.paper)
  G.rectangle("fill", x + edge, y + edge, w - edge * 2, h - edge * 2)
  color(C.gold)
  G.rectangle("fill", x + edge, y + edge, w - edge * 2, rail)
  color(C.goldDark)
  G.rectangle("fill", x + edge, y + edge + rail, w - edge * 2, math.max(1, s))
end

local function geometry(ww, wh)
  local s = uiScaleFor(ww, wh)
  local margin = math.max(12 * s, wh * 0.022)
  local w = math.min(ww - margin * 2, math.max(ww * 0.72, 650 * s))
  local h = math.max(104 * s, math.min(190 * s, wh * 0.205))
  if h > wh - margin * 2 then h = wh - margin * 2 end
  local x = math.floor((ww - w) * 0.5 + 0.5)
  local y = math.floor(wh - h - margin + 0.5)
  local padX = math.max(22 * s, w * 0.035)
  local padY = math.max(18 * s, h * 0.18)
  return {
    s = s, margin = margin, x = x, y = y, w = w, h = h,
    padX = padX, padY = padY,
  }
end

-- TextBox.shown stores glyph codes because the native renderer is tile based.
-- The original page strings are still on self.pages, so rebuild exactly the
-- typed prefix from Font.split() rather than trying to reverse-map glyph codes.
local function shownLineText(box, slot, Font)
  local page = box.pages and box.pages[box.pageIndex]
  local shown = box.shown and box.shown[slot]
  if type(page) ~= "table" or type(shown) ~= "table" then return "" end
  local shownCount = #box.shown
  local lineIndex = (tonumber(box.lineIndex) or 1) - (shownCount - slot)
  local source = tostring(page[lineIndex] or "")
  local count = #shown
  if count <= 0 or source == "" then return "" end
  local spans = Font.split(source)
  local last = spans[math.min(count, #spans)]
  return last and source:sub(1, last.to) or ""
end

local function textBoxDraw(self, UIVisibility, Font)
  if not UIVisibility.bottomVisible(self, true) then return end
  local ww, wh = targetDimensions()
  if not ww or not wh then return end
  local geo = geometry(ww, wh)
  local G = love.graphics

  G.push("all")
  G.origin()
  dialogueFrame(geo.x, geo.y, geo.w, geo.h, geo.s)

  local textSize = math.max(17 * geo.s, math.min(30 * geo.s, geo.h * 0.205))
  local f = font(textSize)
  if f then G.setFont(f) end
  color(C.ink)

  local lineStep = math.max(textSize * 1.42, geo.h * 0.265)
  local baseY = geo.y + geo.padY
  local off = tonumber(self.scrollPx) or 0
  if off > 0 then
    -- Match TextBox.draw exactly: decrement first, then draw the retained line
    -- at that remaining offset. Only the pixels are scaled into window space.
    off = off - 2
    self.scrollPx = off > 0 and off or nil
  end
  local scrollOffset = (math.max(0, off) / 8) * lineStep

  for i = 1, #(self.shown or {}) do
    local text = shownLineText(self, i, Font)
    local y = baseY + (i - 1) * lineStep + (i == 1 and scrollOffset or 0)
    G.print(text, geo.x + geo.padX, y)
  end

  local manualWait = self.waiting
    or (self.done and not self.choice and not self.auto and not self.stay)
  if manualWait then
    local meta = font(math.max(10 * geo.s, math.min(15 * geo.s, geo.h * 0.10)))
    if meta then G.setFont(meta) end
    color(C.silverDark, 0.88)
    local hint = "A / B  CONTINUE"
    local hintW = G.getFont():getWidth(hint)
    G.print(hint, geo.x + geo.w - geo.padX - hintW,
            geo.y + geo.h - geo.padY * 0.72)

    if (tonumber(self.blink) or 0) < 30 then
      local cx = geo.x + geo.w - geo.padX * 0.52
      local cy = geo.y + geo.h * 0.48
      local size = math.max(5 * geo.s, geo.h * 0.043)
      color(C.goldDark)
      G.polygon("fill", cx - size, cy - size * 0.45,
                        cx + size, cy - size * 0.45,
                        cx, cy + size * 0.72)
    end
  end

  G.setColor(1, 1, 1, 1)
  G.pop()
  M.textDraws = M.textDraws + 1
end

local function choiceBoxDraw(self, UIVisibility)
  if not UIVisibility.bottomVisible(self, false) then return end
  local ww, wh = targetDimensions()
  if not ww or not wh then return end
  local base = geometry(ww, wh)
  local G = love.graphics
  local s = base.s

  local w = math.max(170 * s, math.min(260 * s, ww * 0.24))
  local rowH = math.max(38 * s, math.min(58 * s, wh * 0.070))
  local gap = math.max(7 * s, wh * 0.008)
  local headerH = math.max(30 * s, rowH * 0.72)
  local h = headerH + rowH * 2 + gap * 3
  local margin = base.margin
  local x = ww - w - margin
  local y
  if self.anchor == "bottom" then
    y = base.y - h - gap
    if y < margin then y = margin end
  else
    y = math.max(margin, math.floor((wh - h) * 0.48))
  end
  G.push("all")
  G.origin()
  dialogueFrame(x, y, w, h, s)

  local meta = font(math.max(10 * s, rowH * 0.26))
  if meta then G.setFont(meta) end
  color(C.silverDark)
  G.print("CHOOSE", x + gap * 1.7, y + headerH * 0.28)

  local name = font(math.max(15 * s, rowH * 0.42))
  local labels = { "YES", "NO" }
  for i = 1, 2 do
    local ry = y + headerH + gap + (i - 1) * (rowH + gap)
    local on = tonumber(self.index) == i
    color(on and C.gold or C.paper2)
    G.rectangle("fill", x + gap, ry, w - gap * 2, rowH)
    if on then
      color(C.goldDark)
      G.setLineWidth(math.max(1, 2 * s))
      G.rectangle("line", x + gap + 0.5, ry + 0.5,
                  w - gap * 2 - 1, rowH - 1)
    end
    if name then G.setFont(name) end
    color(C.ink)
    G.print(labels[i], x + gap * 2.2, ry + rowH * 0.26)
  end

  G.setColor(1, 1, 1, 1)
  G.pop()
  M.choiceDraws = M.choiceDraws + 1
end

function M.install()
  if M.installed then return true end
  local okText, TextBox = pcall(require, "src.render.TextBox")
  local okChoice, ChoiceBox = pcall(require, "src.ui.ChoiceBox")
  local okFont, Font = pcall(require, "src.render.Font")
  local okVisibility, UIVisibility = pcall(require, "src.battle.UIVisibility")
  if not (okText and type(TextBox) == "table" and type(TextBox.draw) == "function") then
    return false, "src.render.TextBox.draw unavailable"
  end
  if not (okChoice and type(ChoiceBox) == "table" and type(ChoiceBox.draw) == "function") then
    return false, "src.ui.ChoiceBox.draw unavailable"
  end
  if not (okFont and type(Font) == "table" and type(Font.split) == "function") then
    return false, "src.render.Font.split unavailable"
  end
  if not (okVisibility and type(UIVisibility) == "table"
      and type(UIVisibility.bottomVisible) == "function") then
    return false, "src.battle.UIVisibility.bottomVisible unavailable"
  end

  if not TextBox._vasc4jJohtoDialoguePatched then
    local native = TextBox._stadium2GlassNativeDraw or TextBox.draw
    TextBox.draw = function(self, ...)
      if not customUIEnabled() then return native(self, ...) end
      return textBoxDraw(self, UIVisibility, Font)
    end
    TextBox._vasc4jJohtoDialoguePatched = true
    TextBox._vasc4jJohtoDialogueNativeDraw = native
  end

  if not ChoiceBox._vasc4jJohtoDialoguePatched then
    local native = ChoiceBox._stadium2GlassNativeDraw or ChoiceBox.draw
    ChoiceBox.draw = function(self, ...)
      if not customUIEnabled() then return native(self, ...) end
      return choiceBoxDraw(self, UIVisibility)
    end
    ChoiceBox._vasc4jJohtoDialoguePatched = true
    ChoiceBox._vasc4jJohtoDialogueNativeDraw = native
  end

  M.installed = true
  M.lastError = nil
  return true
end

function M.status()
  return {
    installed = M.installed,
    textDraws = M.textDraws,
    choiceDraws = M.choiceDraws,
    style = "johto-paper-silver",
    lastError = M.lastError,
  }
end

return M
