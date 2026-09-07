-- Wide ORAS presentation for native modal TextBox / ChoiceBox states opened
-- Integrated from the reviewed VASC: ORAS Storage UI 0.5.3 presentation.
-- on top of the 512x288 storage, Start-party and battle-party screens.
-- Update/typewriter/callback behavior remains owned by the engine classes;
-- this module replaces only per-instance geometry and drawing.

local V = ... or {}
local WIDTH = V.width or 512
local HEIGHT = V.height or 288

local Font = require("src.render.Font")
local Strings = require("src.core.Strings")

local O = {}
local solidTextShader

local C = {
  navy = { 12 / 255, 37 / 255, 84 / 255 },
  navy2 = { 5 / 255, 24 / 255, 61 / 255 },
  blue = { 23 / 255, 75 / 255, 142 / 255 },
  orange = { 244 / 255, 91 / 255, 12 / 255 },
  gold = { 1, 194 / 255, 44 / 255 },
  cream = { 1, 247 / 255, 218 / 255 },
  paper = { 1, 252 / 255, 236 / 255 },
  shell = { 147 / 255, 151 / 255, 148 / 255 },
  white = { 1, 1, 1 },
}

local function setColor(color, alpha)
  love.graphics.setColor(color[1], color[2], color[3], alpha or 1)
end

local function rounded(color, x, y, w, h, radius, alpha)
  setColor(color, alpha)
  love.graphics.rectangle("fill", x, y, w, h, radius, radius)
end

local function outline(color, x, y, w, h, radius, lineWidth, alpha)
  setColor(color, alpha)
  love.graphics.setLineWidth(lineWidth or 1)
  love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1,
    radius, radius)
  love.graphics.setLineWidth(1)
end

local function drawCodes(codes, x, y, scale)
  local g = love.graphics
  scale = scale or 2
  setColor(C.navy2)
  g.push()
  g.translate(math.floor(x), math.floor(y))
  g.scale(scale, scale)
  for index, code in ipairs(codes or {}) do
    Font.drawCode(code, (index - 1) * 8, 0)
  end
  g.pop()
end

local function drawString(value, x, y, scale)
  local g = love.graphics
  scale = scale or 2
  local previousShader
  if type(g.getShader) == "function" then
    local ok, shader = pcall(g.getShader)
    if ok then previousShader = shader end
  end
  if solidTextShader == nil and type(g.newShader) == "function"
      and type(g.setShader) == "function" then
    local ok, shader = pcall(g.newShader, [[
      uniform vec4 ink;
      vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
        vec4 src = Texel(tex, tc);
        return vec4(ink.rgb, ink.a * src.a * color.a);
      }
    ]])
    solidTextShader = ok and shader and type(shader.send) == "function"
      and shader or false
  end
  local shader = solidTextShader or nil
  if shader then
    local sent = pcall(shader.send, shader, "ink", C.navy2)
    if not sent then solidTextShader, shader = false, nil end
  end
  if shader then g.setShader(shader); setColor(C.white)
  else setColor(C.navy2) end
  g.push()
  g.translate(math.floor(x), math.floor(y))
  g.scale(scale, scale)
  Font.draw(tostring(value or ""), 0, 0)
  g.pop()
  if shader then
    if previousShader ~= nil then g.setShader(previousShader) else g.setShader() end
  end
end

local function bagDialogPanel(title)
  local g = love.graphics
  local x, y, w, h = 184, 211, 316, 65
  rounded(C.navy2, x, y, w, h, 6)
  rounded(C.cream, x + 4, y + 4, w - 8, h - 8, 5)
  rounded(C.paper, x + 8, y + 8, w - 16, h - 16, 4)
  outline(C.navy, x + 4, y + 4, w - 8, h - 8, 5, 2)
  setColor(C.orange)
  g.rectangle("fill", x + 8, y + 8, 4, h - 16, 2, 2)
  drawString(title, x + 20, y + 11, 1)
  return x, y, w, h
end

local function bagBase(state)
  return type(state) == "table" and (
    state.__vascOrasBagSkin
    or state.__vascOrasBagPresentation
    or state.__vascOrasFrlgBagPresentation)
end

local function prepareWide(state, opts)
  local wideBattle = opts == true
    or (type(opts) == "table" and opts.wideBattle == true)
  state.__vascOrasWideBattleOverlay = wideBattle
  state.letterboxWhite = true
  state.uiSize = function() return WIDTH, HEIGHT end
  state.isWideBattleLayout = function(self)
    return self.__vascOrasWideBattleOverlay == true
  end
  state.sgbPalettes = function()
    return { { colors = false, x = 0, y = 0, w = WIDTH, h = HEIGHT } }
  end
  state.drawsWidescreen = function() return true end
  state.wantsFillScale = function() return true end
end

function O.drawTextBox(self)
  local g = love.graphics
  -- The panel deliberately covers the party strip/footer: native field-move
  -- messages own that area while the 2x3 party remains visible above it.
  rounded(C.navy2, 29, 194, 454, 80, 9, 0.72)
  rounded(C.orange, 26, 190, 454, 80, 9)
  rounded(C.cream, 30, 194, 446, 72, 7)
  rounded(C.paper, 34, 198, 438, 64, 5)
  outline(C.navy, 30, 194, 446, 72, 7, 2)
  outline(C.gold, 35, 199, 436, 62, 4, 1, 0.55)

  if self.scrollPx and self.scrollPx > 0 then
    self.scrollPx = self.scrollPx - 2
    if self.scrollPx <= 0 then self.scrollPx = nil end
  end
  local off = (self.scrollPx or 0) * 2
  local ys = { 207, 233 }
  for index, line in ipairs(self.shown or {}) do
    drawCodes(line, 52, (ys[index] or ys[2]) + (index == 1 and off or 0), 2)
  end

  if (self.waiting or (self.done and not self.choice and not self.auto))
      and (tonumber(self.blink) or 0) < 30 then
    setColor(C.gold)
    g.polygon("fill", 450, 247, 462, 247, 456, 255)
    setColor(C.orange)
    g.polygon("fill", 453, 248, 459, 248, 456, 252)
  end
  setColor(C.white)
end

function O.decorateTextBox(state, opts)
  if type(state) ~= "table" then return state end
  if state.__vascOrasWideTextBox then return state end
  state.__vascOrasWideTextBox = true
  prepareWide(state, opts)
  state.draw = O.drawTextBox
  state.drawWidescreen = state.draw
  return state
end

function O.drawChoiceBox(self)
  local x, y, w, h = 336, 106, 142, 78
  rounded(C.navy2, x + 3, y + 4, w, h, 8, 0.65)
  rounded(C.orange, x, y, w, h, 8)
  rounded(C.cream, x + 4, y + 4, w - 8, h - 8, 6)
  rounded(C.paper, x + 8, y + 8, w - 16, h - 16, 4)
  outline(C.navy, x + 4, y + 4, w - 8, h - 8, 6, 2)

  local yes, no = Strings("YES"), Strings("NO")
  local selectedY = self.index == 1 and y + 13 or y + 43
  rounded(C.orange, x + 12, selectedY, w - 24, 25, 4)
  drawString(yes, x + 35, y + 18, 2)
  drawString(no, x + 35, y + 48, 2)
  setColor(C.white)
  local cursorY = self.index == 1 and y + 24 or y + 54
  love.graphics.polygon("fill", x + 19, cursorY, x + 27, cursorY + 5,
    x + 19, cursorY + 10)
  setColor(C.white)
end

function O.decorateChoiceBox(state, opts)
  if type(state) ~= "table" then return state end
  if state.__vascOrasWideChoiceBox then return state end
  state.__vascOrasWideChoiceBox = true
  prepareWide(state, opts)
  state.draw = O.drawChoiceBox
  state.drawWidescreen = state.draw
  return state
end

-- Bag actions used to fall back to the 160x144 USE/TOSS, quantity and YES/NO
-- windows.  Keep their native state/update/callback owners, but paint each
-- transient state into the wide Bag's existing help card instead of over the
-- bag portrait or into a centred legacy island.
function O.drawBagActionMenu(self)
  local x, y, w = bagDialogPanel(Strings("ITEM"))
  local items = type(self.items) == "table" and self.items or {}
  local count = math.max(1, #items)
  local cellW = math.floor((w - 40) / count)
  for index, item in ipairs(items) do
    local bx = x + 18 + (index - 1) * cellW
    if self.index == index then
      rounded(C.orange, bx, y + 31, cellW - 7, 25, 4)
      outline(C.navy, bx, y + 31, cellW - 7, 25, 4, 1)
      setColor(C.white)
      love.graphics.polygon("fill", bx + 6, y + 39, bx + 12, y + 43,
        bx + 6, y + 47)
    end
    drawString(item.label or item.value or "—", bx + 18, y + 37, 1)
  end
  setColor(C.white)
end


function O.decorateBagActionMenu(state)
  if type(state) ~= "table" then return state end
  if state.__vascOrasWideBagAction then return state end
  state.__vascOrasWideBagAction = true
  prepareWide(state, false)
  state.draw = O.drawBagActionMenu
  state.drawWidescreen = state.draw
  return state
end


function O.drawBagQuantity(self)
  local x, y = bagDialogPanel(Strings("QUANTITY"))
  local value = ("×%02d"):format(tonumber(self.qty) or 1)
  if tonumber(self.unitPrice) then
    value = value .. ("   ¥%d"):format(
      (tonumber(self.qty) or 1) * tonumber(self.unitPrice))
  end
  rounded(C.orange, x + 18, y + 31, 278, 25, 4)
  outline(C.navy, x + 18, y + 31, 278, 25, 4, 1)
  setColor(C.white)
  love.graphics.polygon("fill", x + 31, y + 43, x + 37, y + 37,
    x + 43, y + 43)
  love.graphics.polygon("fill", x + 31, y + 46, x + 37, y + 52,
    x + 43, y + 46)
  drawString(value, x + 185, y + 37, 1)
  setColor(C.white)
end


function O.decorateBagQuantity(state)
  if type(state) ~= "table" then return state end
  if state.__vascOrasWideBagQuantity then return state end
  state.__vascOrasWideBagQuantity = true
  prepareWide(state, false)
  state.draw = O.drawBagQuantity
  state.drawWidescreen = state.draw
  return state
end


function O.drawBagChoice(self)
  local x, y = bagDialogPanel(Strings("CONFIRM"))
  local labels = type(self.labels) == "table" and self.labels
    or { "YES", "NO" }
  local cellW = 132
  for index = 1, 2 do
    local bx = x + 18 + (index - 1) * 142
    if self.index == index then
      rounded(C.orange, bx, y + 31, cellW, 25, 4)
      outline(C.navy, bx, y + 31, cellW, 25, 4, 1)
    end
    setColor(C.navy2)
    love.graphics.polygon("fill", bx + 6, y + 39, bx + 12, y + 43,
      bx + 6, y + 47)
    drawString(Strings(labels[index]), bx + 20, y + 37, 1)
  end
  setColor(C.white)
end


function O.decorateBagChoice(state)
  if type(state) ~= "table" then return state end
  if state.__vascOrasWideBagChoice then return state end
  state.__vascOrasWideBagChoice = true
  prepareWide(state, false)
  state.draw = O.drawBagChoice
  state.drawWidescreen = state.draw
  return state
end

function O.isOrasBase(state)
  return type(state) == "table" and (
    state.__vascOrasStorage
    or state.__vascOrasPartyDecorated
    or state.__vascOrasSummaryDecorated
    -- The wide ORAS/FRLG Bag is a complete authored surface as well. Its
    -- native item/TM messages are transient states and must ride this same
    -- 512x288 owner instead of reopening a centred 160x144 island.
    or state.__vascOrasBagSkin
    or state.__vascOrasBagPresentation
    or state.__vascOrasFrlgBagPresentation
    -- MoveLearnPresentation owns the full learn/forget surface while the
    -- engine's genuine TextBox and ChoiceBox remain the stack/input owners.
    or state.__vascMoveLearnPresentation
    or state.__vascOrasWideTextBox
  )
end

O.isWideBagBase = bagBase

O.WIDTH = WIDTH
O.HEIGHT = HEIGHT

return O
