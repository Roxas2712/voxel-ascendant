local env = ...
local mod = assert(env and env.mod, "ModernDex needs mod")

local Assets = require("src.render.Assets")
local Font = require("src.render.Font")
local PaletteFX = require("src.render.PaletteFX")
local Screens = require("src.ui.Screens")
local Sound = require("src.core.Sound")
local Sprites = require("src.pokemon.Sprites")

local UI = {}
local W, H = 512, 288
local LEFT_X, LEFT_Y, LEFT_W, LEFT_H = 12, 48, 354, 228
local RAIL_X, RAIL_Y, RAIL_W, RAIL_H = 378, 48, 122, 228
local ROWS = 8

local C = {
  bg = { 0.025, 0.045, 0.085 },
  panel = { 0.035, 0.065, 0.105 },
  panel2 = { 0.075, 0.115, 0.16 },
  red = { 0.88, 0.07, 0.11 },
  redMid = { 0.67, 0.035, 0.075 },
  redDark = { 0.31, 0.018, 0.045 },
  shellEdge = { 0.19, 0.012, 0.03 },
  bezel = { 0.78, 0.82, 0.80 },
  bezelDark = { 0.25, 0.29, 0.30 },
  cyan = { 0.18, 0.89, 0.96 },
  cyanDark = { 0.045, 0.28, 0.36 },
  cream = { 0.965, 0.94, 0.82 },
  white = { 0.95, 0.98, 1.0 },
  soft = { 0.58, 0.68, 0.78 },
  gold = { 1.0, 0.72, 0.18 },
  green = { 0.24, 0.85, 0.57 },
  black = { 0.008, 0.014, 0.025 },
}

local L = {
  de = {
    title = "ASCENDANT DEX", number = "NUMMER", alpha = "A-Z",
    seen = "GESEHEN", owned = "GEFANGEN", data = "DATEN", cry = "RUF",
    area = "GEBIET", quit = "BEENDEN", unknown = "NICHT GESEHEN",
    noData = "Keine Daten vorhanden.", kind = "ART", height = "GROESSE",
    weight = "GEWICHT", page = "SEITE", next = "WEITER",
    back = "ZURUECK", listHint = "L/R ANSICHT   A DATEN",
    entryHint = "L/R POKéMON   A WEITER", caughtShort = "GEF.",
    seenShort = "GES.", areaUnknown = "GEBIET UNBEKANNT",
    kanto = "KANTO", johto = "JOHTO", hoenn = "HOENN", sinnoh = "SINNOH",
    regionHint = "START L/R REGION", noRegion = "KEINE REGIONALDATEN",
  },
  en = {
    title = "ASCENDANT DEX", number = "NUMBER", alpha = "A-Z",
    seen = "SEEN", owned = "CAUGHT", data = "DATA", cry = "CRY",
    area = "AREA", quit = "QUIT", unknown = "NOT SEEN",
    noData = "No data available.", kind = "KIND", height = "HEIGHT",
    weight = "WEIGHT", page = "PAGE", next = "NEXT",
    back = "BACK", listHint = "L/R VIEW   A DATA",
    entryHint = "L/R POKéMON   A NEXT", caughtShort = "OWN",
    seenShort = "SEEN", areaUnknown = "AREA UNKNOWN",
    kanto = "KANTO", johto = "JOHTO", hoenn = "HOENN", sinnoh = "SINNOH",
    regionHint = "START L/R REGION", noRegion = "NO REGIONAL DATA",
  },
}

local function language()
  if type(mod.find) == "function" then
    local universal = mod.find("translation-german-universal")
    local boot = universal and universal.exports and universal.exports.bootLanguage
    if boot == "de" or boot == "en" then return boot end
    local ascendant = mod.find("kanto_ascendant")
    local active = ascendant and ascendant.exports and ascendant.exports.language
    if type(active) == "function" then
      local ok, value = pcall(active)
      if ok and (value == "de" or value == "en") then return value end
    end
    for _, id in ipairs({ "deutsch", "deutsch-blau", "deutsch-gelb" }) do
      if mod.find(id) then return "de" end
    end
  end
  return "en"
end

local function tr(lang, key)
  return (L[lang] and L[lang][key]) or L.en[key] or key
end

local function color(c, alpha)
  love.graphics.setColor(c[1], c[2], c[3], alpha or c[4] or 1)
end

local function fill(c, x, y, w, h, radius, alpha)
  color(c, alpha)
  love.graphics.rectangle("fill", x, y, w, h, radius or 0, radius or 0)
end

local function line(c, x, y, w, h, radius, width)
  color(c)
  love.graphics.setLineWidth(width or 1)
  love.graphics.rectangle("line", x, y, w, h, radius or 0, radius or 0)
  love.graphics.setLineWidth(1)
end

local solidTextShader

local function textShader(c)
  if solidTextShader == nil then
    local ok, shader = pcall(love.graphics.newShader, [[
      extern vec4 tone;
      vec4 effect(vec4 vertexColor, Image tex, vec2 tc, vec2 sc) {
        vec4 px = Texel(tex, tc);
        return vec4(tone.rgb, px.a * tone.a);
      }
    ]])
    solidTextShader = ok and shader or false
  end
  if solidTextShader then
    solidTextShader:send("tone", { c[1], c[2], c[3], c[4] or 1 })
    return solidTextShader
  end
end

local function text(value, x, y, c)
  c = c or C.white
  local shader = textShader(c)
  if shader then
    love.graphics.setShader(shader)
    color(C.white)
  else
    color(c)
  end
  Font.draw(tostring(value or ""), math.floor(x), math.floor(y))
  if shader then love.graphics.setShader() end
end

local function rightText(value, x, y, w, c)
  value = tostring(value or "")
  text(value, x + w - Font.width(value), y, c)
end

local function fit(value, maxWidth)
  value = tostring(value or "")
  if Font.width(value) <= maxWidth then return value end
  local suffix = "..."
  while #value > 0 and Font.width(value .. suffix) > maxWidth do
    value = value:sub(1, -2)
  end
  return value .. suffix
end

local function header(lang, section, accent)
  fill(C.shellEdge, 0, 0, W, H)
  fill(C.red, 3, 3, W - 6, H - 6, 12)
  fill(C.redMid, 3, 34, W - 6, 8)
  fill(C.redDark, 3, 40, W - 6, 4)

  -- Classic Pokédex camera lens and status LEDs, scaled for widescreen.
  fill(C.white, 10, 6, 29, 29, 15)
  fill(C.cyanDark, 13, 9, 23, 23, 12)
  fill(C.cyan, 16, 12, 17, 17, 9)
  fill(C.white, 19, 14, 7, 5, 3, 0.82)
  fill({ 1.0, 0.28, 0.25 }, 47, 8, 7, 7, 4)
  fill(C.gold, 59, 8, 7, 7, 4)
  fill(C.green, 71, 8, 7, 7, 4)

  fill(C.redDark, 88, 7, 214, 25, 5)
  line(C.shellEdge, 88, 7, 214, 25, 5, 2)
  text(tr(lang, "title"), 100, 14, C.white)
  fill(C.redDark, 338, 7, 162, 25, 5)
  rightText(section or "", 350, 14, 138, accent or C.cream)
end

local function shell(lang, section)
  header(lang, section)
  fill(C.bezelDark, LEFT_X - 5, LEFT_Y - 5, LEFT_W + 10, LEFT_H + 10, 9)
  fill(C.bezel, LEFT_X - 3, LEFT_Y - 3, LEFT_W + 6, LEFT_H + 6, 8)
  fill(C.panel, LEFT_X, LEFT_Y, LEFT_W, LEFT_H, 7)
  line(C.black, LEFT_X, LEFT_Y, LEFT_W, LEFT_H, 7, 2)
  fill(C.bezelDark, RAIL_X - 5, RAIL_Y - 5, RAIL_W + 10, RAIL_H + 10, 9)
  fill(C.bezel, RAIL_X - 3, RAIL_Y - 3, RAIL_W + 6, RAIL_H + 6, 8)
  fill(C.panel, RAIL_X, RAIL_Y, RAIL_W, RAIL_H, 7)
  line(C.black, RAIL_X, RAIL_Y, RAIL_W, RAIL_H, 7, 2)

  -- Raised central hinge keeps the two-screen, physical-device silhouette.
  fill(C.shellEdge, 368, 47, 8, 230, 4)
  fill(C.redDark, 370, 49, 5, 226, 3)
  fill(C.red, 371, 52, 2, 220, 1)
  for y = 59, 249, 47 do
    fill(C.shellEdge, 367, y, 10, 9, 2)
    fill(C.redMid, 369, y + 2, 6, 5, 1)
  end
end

local function markTrueColor()
  if type(PaletteFX.markTrueColor) == "function" then
    PaletteFX.markTrueColor(0, 0, W, H)
  end
end

local function spriteMode()
  local options = mod and mod.options
  local value = options and options.get and options:get("sprite_source")
  if value ~= "auto" and value ~= "game" then return "kasc_crystal" end
  return value
end

local imageCache = {}

local function crystalPath(game, species)
  if not (type(mod.find) == "function" and species) then return nil end
  local okHandle, handle = pcall(mod.find, "kanto_ascendant")
  if not (okHandle and handle and type(handle.exports) == "table") then return nil end
  local exports = handle.exports
  local mon = { species = species }
  local provider = exports.crystalSpriteProvider
  if type(provider) == "table" and tonumber(provider.apiVersion) == 1
      and type(provider.resolveFront) == "function" then
    local ok, result = pcall(provider.resolveFront, game.data, mon,
      { kind = "dex", source = "vasc_modern_pokedex" })
    if ok and type(result) == "table" and type(result.path) == "string"
        and result.path ~= "" then
      return result.path, result.trueColor ~= false, "kasc_crystal"
    end
  end
  local animation = exports.crystalAnimation
  if type(animation) == "table" and type(animation.staticFrameOne) == "function" then
    local ok, path = pcall(animation.staticFrameOne,
      { data = game.data, species = species, mon = mon, kind = "dex",
        source = "vasc_modern_pokedex" }, "front", "normal")
    if ok and type(path) == "string" and path ~= "" then
      return path, true, "kasc_crystal"
    end
  end
  return nil
end

local function spritePath(game, species)
  local mode = spriteMode()
  if mode == "kasc_crystal" then
    local path, trueColor, source = crystalPath(game, species)
    if path then return path, trueColor, source end
  elseif mode == "game" then
    local def = game.data and game.data.pokemon and game.data.pokemon[species]
    if def and type(def.spriteFront) == "string" then
      return def.spriteFront, def.trueColor and true or false, "game"
    end
  end
  local path, trueColor = Sprites.path(game.data, species, "front",
    { kind = "dex" })
  return path, trueColor, "auto"
end

local function spriteImage(game, species)
  if not species then return nil end
  local path, trueColor, source = spritePath(game, species)
  if not path then return nil end
  local key = path .. (trueColor and "#t" or "#p")
  if imageCache[key] == nil then
    local ok, image = pcall(Assets.image, path)
    if ok and image and type(image.setFilter) == "function" then
      pcall(image.setFilter, image, "nearest", "nearest")
    end
    imageCache[key] = ok and {
      image = image, trueColor = trueColor, source = source,
    } or false
  end
  return imageCache[key] or nil
end

local function drawSprite(game, species, x, y, w, h, seen)
  fill(C.black, x, y, w, h, 5)
  line(C.cyanDark, x, y, w, h, 5, 2)
  if not seen then
    text("?", x + math.floor(w / 2) - 4, y + math.floor(h / 2) - 4, C.soft)
    return
  end
  local resolved = spriteImage(game, species)
  if not resolved then
    text("?", x + math.floor(w / 2) - 4, y + math.floor(h / 2) - 4, C.soft)
    return
  end
  local image = resolved.image
  local iw, ih = image:getDimensions()
  local scale = math.max(1, math.floor(math.min((w - 12) / math.max(1, iw),
    (h - 12) / math.max(1, ih))))
  local dx = math.floor(x + (w - iw * scale) / 2)
  local dy = math.floor(y + h - 6 - ih * scale)
  if not resolved.trueColor then
    local shader = PaletteFX.keyedShader()
    local colors = PaletteFX.monPal(game.data, species)
    if shader and colors then
      PaletteFX.sendColors(shader, colors)
      love.graphics.setShader(shader)
    end
    color(C.white)
    love.graphics.draw(image, dx, dy, 0, scale, scale)
    if shader and colors then love.graphics.setShader() end
  else
    color(C.white)
    love.graphics.draw(image, dx, dy, 0, scale, scale)
  end
end

local function drawCaughtBall(x, y, scale)
  scale = scale or 1
  local radius = 6 * scale
  color(C.black)
  love.graphics.circle("fill", x, y, radius)
  color(C.red)
  love.graphics.rectangle("fill", x - 4 * scale, y - 4 * scale,
    8 * scale, 4 * scale)
  color(C.white)
  love.graphics.rectangle("fill", x - 4 * scale, y + scale,
    8 * scale, 3 * scale)
  color(C.black)
  love.graphics.rectangle("fill", x - 5 * scale, y - scale,
    10 * scale, 2 * scale)
  love.graphics.circle("fill", x, y, 3 * scale)
  color(C.white)
  love.graphics.circle("fill", x, y, 1.5 * scale)
end

local function isSeen(game, species)
  local dex = game.save.pokedex or {}
  return (dex.seen and dex.seen[species]) or (dex.owned and dex.owned[species])
end

local function isOwned(game, species)
  local dex = game.save.pokedex or {}
  return dex.owned and dex.owned[species]
end

local function dexCatalogue(game)
  local byDex = {}
  for species, def in pairs(game.data.pokemon or {}) do
    if tonumber(def.dex) then byDex[tonumber(def.dex)] = { id = species, def = def } end
  end
  local out = {}
  for number, row in pairs(byDex) do
    row.dex = number
    row.seen = not not isSeen(game, row.id)
    row.owned = not not isOwned(game, row.id)
    out[#out + 1] = row
  end
  table.sort(out, function(a, b) return a.dex < b.dex end)
  return out
end

local MODES = { "number", "alpha", "seen", "owned" }
local REGIONS = {
  { key = "kanto", first = 1, last = 151 },
  { key = "johto", first = 152, last = 251 },
  { key = "hoenn", first = 252, last = 386 },
  { key = "sinnoh", first = 387, last = 493 },
}

local function regionIsUnlocked(all, region)
  if region.key == "kanto" then return true end
  for _, row in ipairs(all) do
    if row.owned and row.dex >= region.first and row.dex <= region.last then
      return true
    end
  end
  return false
end

local function rowsForRegion(all, regionIndex)
  local region = REGIONS[((regionIndex - 1) % #REGIONS) + 1]
  local byDex, highestOwned = {}, nil
  for _, row in ipairs(all) do
    if row.dex >= region.first and row.dex <= region.last then
      byDex[row.dex] = row
      if row.owned and (not highestOwned or row.dex > highestOwned) then
        highestOwned = row.dex
      end
    end
  end

  -- Oak's initial Kanto index ends at 150. Every other extension is earned
  -- by actually owning a species from that region; seen-only data never
  -- exposes a higher number. Sinnoh intentionally stays a sealed preview.
  local last
  if region.key == "kanto" then
    last = math.max(150, highestOwned or 0)
  else
    last = highestOwned
  end
  if not last then
    return { {
      dex = nil, id = nil, def = { name = "???" }, seen = false,
      owned = false, placeholder = true, locked = true,
    } }
  end

  local rows = {}
  for number = region.first, math.min(last, region.last) do
    rows[#rows + 1] = byDex[number] or {
      dex = number, id = nil, def = { dex = number, name = "???" },
      seen = false, owned = false, placeholder = true,
    }
  end
  return rows
end

local function rowsForMode(all, mode)
  if #all == 1 and all[1].locked then return all end
  local rows = {}
  for _, row in ipairs(all) do
    if mode == "number" or (mode == "alpha" and row.seen)
        or (mode == "seen" and row.seen) or (mode == "owned" and row.owned) then
      rows[#rows + 1] = row
    end
  end
  if mode == "alpha" then
    table.sort(rows, function(a, b)
      local an, bn = tostring(a.def.name or a.id), tostring(b.def.name or b.id)
      if an == bn then return a.dex < b.dex end
      return an < bn
    end)
  end
  return rows
end

local function counts(all)
  local seen, owned = 0, 0
  for _, row in ipairs(all) do
    if row.seen then seen = seen + 1 end
    if row.owned then owned = owned + 1 end
  end
  return seen, owned
end

local function play(game, id)
  pcall(Sound.play, game.data, id)
end

local function playCry(game, species)
  if species then pcall(Sound.playCry, game.data, species) end
end

local function drawActionRail(lang, active)
  local entries = {
    { "A", tr(lang, "data") }, { "START", tr(lang, "cry") },
    { "SELECT", tr(lang, "area") }, { "B", tr(lang, "quit") },
  }
  -- Small speaker grille and mixed round/pill controls echo the physical
  -- Pokédex instead of reading like another software menu.
  for i = 0, 4 do
    fill(C.bezelDark, RAIL_X + 72 + i * 8, 174, 5, 2, 1)
  end
  local y = 185
  for i, entry in ipairs(entries) do
    local selected = active == i
    fill(selected and C.cyanDark or C.panel2,
      RAIL_X + 7, y - 5, RAIL_W - 14, 20, 4)
    line(selected and C.cyan or C.black,
      RAIL_X + 7, y - 5, RAIL_W - 14, 20, 4, 1)
    if entry[1] == "A" or entry[1] == "B" then
      color(C.black)
      love.graphics.circle("fill", RAIL_X + 17, y + 4, 7)
      color(selected and C.cyan or C.red)
      love.graphics.circle("fill", RAIL_X + 17, y + 4, 5)
      local keyWidth = Font.width(entry[1])
      text(entry[1], RAIL_X + 17 - math.floor(keyWidth / 2), y,
        selected and C.black or C.white)
    else
      fill(C.black, RAIL_X + 10, y - 1, 31, 11, 5)
      fill(selected and C.cyan or C.redMid,
        RAIL_X + 12, y + 1, 27, 7, 4)
      local icon = selected and C.black or C.white
      if entry[1] == "START" then
        -- Pixel play symbol: an actual keycap image, not a squeezed word.
        fill(icon, RAIL_X + 23, y + 1, 2, 7)
        fill(icon, RAIL_X + 25, y + 2, 2, 5)
        fill(icon, RAIL_X + 27, y + 3, 2, 3)
        fill(icon, RAIL_X + 29, y + 4, 2, 1)
      else
        -- SELECT keycap: two opposing selection cursors.
        fill(icon, RAIL_X + 18, y + 2, 8, 2, 1)
        fill(icon, RAIL_X + 25, y + 1, 2, 4, 1)
        fill(icon, RAIL_X + 26, y + 5, 8, 2, 1)
        fill(icon, RAIL_X + 25, y + 4, 2, 4, 1)
      end
    end
    rightText(entry[2], RAIL_X + 43, y, RAIL_W - 51,
      selected and C.white or C.soft)
    y = y + 24
  end
end

local function drawStats(lang, seen, owned)
  text(tr(lang, "seenShort"), RAIL_X + 10, 152, C.soft)
  rightText(seen, RAIL_X + 55, 152, 53, C.cyan)
  text(tr(lang, "caughtShort"), RAIL_X + 10, 164, C.soft)
  rightText(owned, RAIL_X + 55, 164, 53, C.gold)
end

local function openArea(game, species, lang)
  if not species then return end
  local state = UI.AreaScreen.new(game, species, lang)
  state.screenId = "VascDexArea"
  game.stack:push(state)
end

-- -----------------------------------------------------------------------
-- List: the first screen, with four instant list modes.

local ListScreen = {}
ListScreen.__index = ListScreen
ListScreen.isOpaque = true

function ListScreen.new(game, opts)
  opts = type(opts) == "table" and opts or {}
  local self = setmetatable({ game = game, lang = opts.language or language(),
    modeIndex = tonumber(opts.modeIndex) or 1,
    regionIndex = tonumber(opts.regionIndex) or 1, index = 1, scroll = 0,
    onCancel = opts.onCancel, __vascModernDex = true }, ListScreen)
  self.all = dexCatalogue(game)
  self:applyRegion(self.regionIndex, opts.species)
  return self
end

function ListScreen:uiSize() return W, H end
function ListScreen:sgbPalettes()
  return { { colors = false, x = 0, y = 0, w = W, h = H } }
end

function ListScreen:current()
  return self.rows and self.rows[self.index] or nil
end

function ListScreen:applyMode(index, preserveSpecies)
  local current = self:current()
  preserveSpecies = preserveSpecies or (current and current.id)
  self.modeIndex = ((index - 1) % #MODES) + 1
  self.mode = MODES[self.modeIndex]
  self.rows = rowsForMode(self.regionRows, self.mode)
  self.index = math.max(1, math.min(self.index or 1, math.max(1, #self.rows)))
  if preserveSpecies then
    for i, row in ipairs(self.rows) do
      if row.id == preserveSpecies then self.index = i break end
    end
  end
  self.scroll = math.max(0, math.min(self.scroll or 0,
    math.max(0, #self.rows - ROWS)))
  if self.index <= self.scroll then self.scroll = self.index - 1 end
  if self.index > self.scroll + ROWS then self.scroll = self.index - ROWS end
end

function ListScreen:applyRegion(index, preserveSpecies)
  local current = self:current()
  preserveSpecies = preserveSpecies or (current and current.id)
  self.regionIndex = ((index - 1) % #REGIONS) + 1
  self.region = REGIONS[self.regionIndex]
  self.regionRows = rowsForRegion(self.all, self.regionIndex)
  self.seenCount, self.ownedCount = counts(self.regionRows)
  self.index, self.scroll = 1, 0
  self:applyMode(self.modeIndex, preserveSpecies)
end

function ListScreen:move(delta)
  if #self.rows == 0 then return end
  self.index = ((self.index - 1 + delta) % #self.rows) + 1
  if self.index <= self.scroll then self.scroll = self.index - 1 end
  if self.index > self.scroll + ROWS then self.scroll = self.index - ROWS end
  play(self.game, "Tink")
end

function ListScreen:openData()
  local row = self:current()
  if not (row and row.seen) then return end
  Screens.push(self.game, "DexEntryMenu", {
    species = row.id, modeIndex = self.modeIndex,
    regionIndex = self.regionIndex, language = self.lang,
  })
  play(self.game, "Press_AB")
end

function ListScreen:update()
  local input = self.game.input
  local startHeld = type(input.isDown) == "function" and input:isDown("start")
  if input:wasPressed("up") then self:move(-1)
  elseif input:wasPressed("down") then self:move(1)
  elseif input:wasPressed("left") then
    if startHeld then self:applyRegion(self.regionIndex - 1)
    else self:applyMode(self.modeIndex - 1) end
    play(self.game, "Tink")
  elseif input:wasPressed("right") then
    if startHeld then self:applyRegion(self.regionIndex + 1)
    else self:applyMode(self.modeIndex + 1) end
    play(self.game, "Tink")
  elseif input:wasPressed("a") then self:openData()
  elseif input:wasPressed("start") then
    local row = self:current()
    if row and row.seen then playCry(self.game, row.id) end
  elseif input:wasPressed("select") then
    local row = self:current()
    if row and row.seen then openArea(self.game, row.id, self.lang) end
  elseif input:wasPressed("b") then
    play(self.game, "Press_AB")
    self.game.stack:pop()
    if self.onCancel then self.onCancel() end
  end
end

local function drawRegionTabs(self)
  local x, y = LEFT_X + 10, LEFT_Y + 7
  for i, region in ipairs(REGIONS) do
    local unlocked = regionIsUnlocked(self.all, region)
    local label = unlocked and tr(self.lang, region.key) or "???"
    local width = math.max(55, Font.width(label) + 16)
    if i == self.regionIndex then
      fill(C.redDark, x, y - 3, width, 18, 4)
      line(C.red, x, y - 3, width, 18, 4, 1)
      text(label, x + 8, y, C.white)
    else
      text(label, x + 8, y, unlocked and C.soft or C.gold)
    end
    x = x + width + 3
  end
end

local function drawTabs(self)
  local labels = { tr(self.lang, "number"), tr(self.lang, "alpha"),
    tr(self.lang, "seen"), tr(self.lang, "owned") }
  local x, y = LEFT_X + 10, LEFT_Y + 28
  for i, label in ipairs(labels) do
    local width = math.max(51, Font.width(label) + 18)
    if i == self.modeIndex then
      fill(C.cyanDark, x, y - 3, width, 19, 4)
      line(C.cyan, x, y - 3, width, 19, 4, 1)
      text(label, x + 9, y, C.cyan)
    else
      fill(C.panel2, x, y - 3, width, 19, 4)
      line(C.black, x, y - 3, width, 19, 4, 1)
      text(label, x + 9, y, C.soft)
    end
    x = x + width + 4
  end
end

function ListScreen:draw()
  local regionLabel = regionIsUnlocked(self.all, self.region)
    and tr(self.lang, self.region.key) or "???"
  shell(self.lang, regionLabel .. "/"
    .. tr(self.lang, self.mode))
  drawRegionTabs(self)
  drawTabs(self)
  fill(C.panel2, LEFT_X + 8, LEFT_Y + 50, LEFT_W - 16, 19, 3)
  text("NO.", LEFT_X + 18, LEFT_Y + 55, C.soft)
  text("STATUS", LEFT_X + 65, LEFT_Y + 55, C.soft)
  text("POKéMON", LEFT_X + 122, LEFT_Y + 55, C.soft)

  if #self.rows == 0 then
    text("-", LEFT_X + 22, LEFT_Y + 91, C.soft)
    text(tr(self.lang, "noRegion"), LEFT_X + 52, LEFT_Y + 91, C.soft)
  end
  for visible = 1, ROWS do
    local rowIndex = self.scroll + visible
    local row = self.rows[rowIndex]
    if not row then break end
    local y = LEFT_Y + 75 + (visible - 1) * 17
    if rowIndex == self.index then
      fill(C.cyanDark, LEFT_X + 8, y - 4, LEFT_W - 16, 17, 3)
      fill(C.cyan, LEFT_X + 8, y - 4, 3, 17, 1)
    end
    local digits = (self.game.data.constants or {}).dexDigits or 3
    local numberText = row.dex and (("%0" .. digits .. "d"):format(row.dex))
      or "???"
    text(numberText, LEFT_X + 18, y,
      rowIndex == self.index and C.white or C.soft)
    if row.locked then
      text("?", LEFT_X + 70, y, C.gold)
    elseif row.owned then
      drawCaughtBall(LEFT_X + 73, y + 5, 1)
    elseif row.seen then
      fill(C.cyan, LEFT_X + 70, y + 3, 7, 3, 2)
    else
      line(C.soft, LEFT_X + 70, y + 2, 7, 7, 4, 1)
    end
    local name = row.placeholder and "???"
      or (row.seen and (row.def.name or row.id) or "----------")
    text(fit(name, 196), LEFT_X + 122, y,
      row.seen and (rowIndex == self.index and C.white or C.cream) or C.soft)
  end

  local current = self:current()
  drawSprite(self.game, current and current.id,
    RAIL_X + 9, RAIL_Y + 9, RAIL_W - 18, 68, current and current.seen)
  if current then
    text(current.dex and ("No.%03d"):format(current.dex) or "No.???",
      RAIL_X + 10, 128, C.soft)
    local currentName = current.placeholder and "???"
      or (current.seen and (current.def.name or current.id)
        or tr(self.lang, "unknown"))
    text(fit(currentName, RAIL_W - 20), RAIL_X + 10, 140, C.white)
  end
  drawStats(self.lang, self.seenCount, self.ownedCount)
  drawActionRail(self.lang)
  text("L/R ANS.  " .. tr(self.lang, "regionHint"),
    LEFT_X + 12, 258, C.soft)
  rightText(("%d/%d"):format(self.index, #self.rows),
    LEFT_X + 220, 258, 120, C.soft)
  markTrueColor()
end

UI.ListScreen = ListScreen

-- -----------------------------------------------------------------------
-- Full entry reader.  Left/Right stays inside the current list mode.

local EntryScreen = {}
EntryScreen.__index = EntryScreen
EntryScreen.isOpaque = true

local function resolveEntryArgs(value)
  if type(value) == "table" then
    return value.species or value[1], value.forceOwned and true or false,
      tonumber(value.modeIndex) or 1, value.language,
      tonumber(value.regionIndex) or 1
  end
  return value, false, 1, nil, 1
end

local function wrappedDescription(game, def, owned, lang)
  local entry = def.dexEntry or {}
  local raw = owned and entry.text and game.data.text[entry.text]
  if not raw or raw == "" then raw = tr(lang, "noData") end
  raw = tostring(raw):gsub("\v", "\n"):gsub("\f", "\n")
  local lines, current = {}, ""
  local function flush()
    if current ~= "" then lines[#lines + 1], current = current, "" end
  end
  for paragraph in (raw .. "\n"):gmatch("(.-)\n") do
    if paragraph == "" then
      flush()
    else
      for word in paragraph:gmatch("%S+") do
        local candidate = current == "" and word or (current .. " " .. word)
        if current ~= "" and Font.width(candidate) > 318 then
          flush(); current = word
        else
          current = candidate
        end
      end
      flush()
    end
  end
  local pages = {}
  for first = 1, math.max(1, #lines), 10 do
    local page = {}
    for i = first, math.min(first + 9, #lines) do page[#page + 1] = lines[i] end
    pages[#pages + 1] = page
  end
  return #pages > 0 and pages or { { tr(lang, "noData") } }
end

function EntryScreen.new(game, speciesOrOpts)
  local species, forceOwned, modeIndex, requestedLanguage, regionIndex =
    resolveEntryArgs(speciesOrOpts)
  local all = dexCatalogue(game)
  local mode = MODES[((modeIndex - 1) % #MODES) + 1]
  local regionRows = rowsForRegion(all, regionIndex)
  local rows = rowsForMode(regionRows, mode)
  local position = 1
  for i, row in ipairs(rows) do if row.id == species then position = i break end end
  local self = setmetatable({ game = game, lang = requestedLanguage or language(), all = all,
    modeIndex = modeIndex, mode = mode, regionIndex = regionIndex,
    region = REGIONS[((regionIndex - 1) % #REGIONS) + 1],
    rows = rows, position = position,
    species = species, forceOwned = forceOwned, page = 1,
    __vascModernDexEntry = true }, EntryScreen)
  self:setSpecies(species, true)
  return self
end

function EntryScreen:uiSize() return W, H end
function EntryScreen:sgbPalettes()
  return { { colors = false, x = 0, y = 0, w = W, h = H } }
end

function EntryScreen:setSpecies(species, silent)
  local def = self.game.data.pokemon[species]
  if not def then return false end
  self.species, self.def, self.page = species, def, 1
  self.owned = self.forceOwned or not not isOwned(self.game, species)
  self.seen = self.forceOwned or not not isSeen(self.game, species)
  self.pages = wrappedDescription(self.game, def, self.owned, self.lang)
  for i, row in ipairs(self.rows) do if row.id == species then self.position = i break end end
  if not silent then play(self.game, "Tink") end
  return true
end

function EntryScreen:moveSpecies(delta)
  if #self.rows == 0 then return end
  self.position = ((self.position - 1 + delta) % #self.rows) + 1
  self:setSpecies(self.rows[self.position].id)
end

function EntryScreen:update()
  local input = self.game.input
  if input:wasPressed("left") then self:moveSpecies(-1)
  elseif input:wasPressed("right") then self:moveSpecies(1)
  elseif input:wasPressed("a") then
    if self.page < #self.pages then
      self.page = self.page + 1; play(self.game, "Tink")
    else
      self.page = 1
    end
  elseif input:wasPressed("start") then playCry(self.game, self.species)
  elseif input:wasPressed("select") then openArea(self.game, self.species, self.lang)
  elseif input:wasPressed("b") then
    play(self.game, "Press_AB"); self.game.stack:pop()
  end
end

local function metric(lang, label, value, x, y, w)
  text(label, x, y, C.soft)
  rightText(value, x + 66, y, w - 66, C.cream)
end

function EntryScreen:draw()
  local def, entry = self.def, self.def.dexEntry or {}
  shell(self.lang, tr(self.lang, "data"))
  text(("No.%03d"):format(def.dex or 0), LEFT_X + 14, LEFT_Y + 13, C.cyan)
  text(fit(def.name or self.species, 236), LEFT_X + 84, LEFT_Y + 13, C.white)
  if self.owned then
    drawCaughtBall(LEFT_X + LEFT_W - 29, LEFT_Y + 16, 1)
  end
  fill(C.panel2, LEFT_X + 10, LEFT_Y + 35, LEFT_W - 20, 48, 4)
  metric(self.lang, tr(self.lang, "kind"), entry.kind or "?",
    LEFT_X + 20, LEFT_Y + 46, 145)
  local height = entry.heightM and
    (("%.1f m"):format(entry.heightM):gsub("(%d)%.(%d)", "%1,%2"))
    or (entry.heightFt and ("%d'%02d\""):format(entry.heightFt,
      entry.heightIn or 0) or "-")
  local weight = entry.weightKg and
    (("%.1f kg"):format(entry.weightKg):gsub("(%d)%.(%d)", "%1,%2"))
    or (entry.weight and ("%.1f lb"):format(entry.weight / 10) or "-")
  metric(self.lang, tr(self.lang, "height"), self.owned and height or "-",
    LEFT_X + 183, LEFT_Y + 46, 139)
  metric(self.lang, tr(self.lang, "weight"), self.owned and weight or "-",
    LEFT_X + 183, LEFT_Y + 64, 139)

  fill(C.bg, LEFT_X + 10, LEFT_Y + 92, LEFT_W - 20, 112, 4)
  local y = LEFT_Y + 104
  for _, row in ipairs(self.pages[self.page] or {}) do
    text(row, LEFT_X + 20, y, self.owned and C.cream or C.soft)
    y = y + 10
  end
  text(tr(self.lang, "entryHint"), LEFT_X + 14, 258, C.soft)
  rightText(("%s %d/%d"):format(tr(self.lang, "page"), self.page, #self.pages),
    LEFT_X + 218, 258, 120, C.soft)

  drawSprite(self.game, self.species,
    RAIL_X + 9, RAIL_Y + 9, RAIL_W - 18, 94, self.seen)
  text(fit(def.name or self.species, RAIL_W - 20), RAIL_X + 10, 153, C.white)
  drawActionRail(self.lang)
  markTrueColor()
end

UI.EntryScreen = EntryScreen

-- -----------------------------------------------------------------------
-- AREA uses the optional VASC Kanto map provider when installed.  The
-- provider owns artwork, coordinates and encounter-to-location mapping; the
-- native engine renderer remains the safe fallback for standalone installs.

local AreaScreen = {}
AreaScreen.__index = AreaScreen
AreaScreen.isOpaque = true

local function providerArea(handle, game, species)
  local exports = handle and handle.exports
  local provider = exports and exports.pokedexAreaProvider
  if not (exports and exports.active == true and type(provider) == "table"
      and tonumber(provider.apiVersion) == 1
      and type(provider.resolve) == "function") then
    return nil
  end
  local ok, result = pcall(provider.resolve, game, species, {
    consumer = "vasc_modern_pokedex", widescreen = true,
  })
  if not (ok and type(result) == "table" and result.image
      and tonumber(result.width) and tonumber(result.height)
      and type(result.markers) == "table") then
    return nil
  end
  return result
end

local function encounterHasSpecies(encounter, species)
  if type(encounter) ~= "table" then return false end
  for _, group in pairs(encounter) do
    if type(group) == "table" then
      for _, slot in ipairs(group.slots or {}) do
        if slot.species == species then return true end
      end
    end
  end
  return false
end

-- Compatibility for already-installed releases predating the provider API.
-- Their public screen id supplies the exact active map image and their public
-- locations supply the coordinates; encounter ownership remains game data.
local function legacyArea(handle, game, species)
  local exports = handle and handle.exports
  if not (exports and exports.active == true
      and type(exports.screenId) == "string"
      and type(exports.locations) == "table") then return nil end
  local okFactory, factory = pcall(Screens.get, game, exports.screenId)
  if not (okFactory and factory and type(factory.new) == "function") then
    return nil
  end
  local okScreen, screen = pcall(factory.new, game, {})
  if not (okScreen and screen and screen.image) then return nil end

  local logicalWidth, logicalHeight = 288, 230
  local coordinateScale = 288 / 160
  local markers, marked = {}, {}
  for mapId, encounter in pairs(game.data.encounters or {}) do
    if encounterHasSpecies(encounter, species) then
      for index, location in ipairs(exports.locations) do
        if not marked[index] then
          for _, candidate in ipairs(location.maps or {}) do
            if candidate == mapId then
              marked[index] = true
              markers[#markers + 1] = {
                id = location.id,
                x = (tonumber(location.x) or 0) * coordinateScale,
                y = (tonumber(location.y) or 0) * coordinateScale,
                locationIndex = index,
              }
              break
            end
          end
        end
      end
    end
  end
  table.sort(markers, function(a, b)
    return a.locationIndex < b.locationIndex
  end)
  return {
    image = screen.image,
    width = logicalWidth,
    height = logicalHeight,
    markers = markers,
    species = species,
    source = handle.id,
    compatibility = true,
  }
end

local function externalArea(game, species)
  if type(mod.find) ~= "function" then return nil end
  local okHandle, handle = pcall(mod.find, "vasc_kanto_fly_map")
  if okHandle and handle then
    return providerArea(handle, game, species)
      or legacyArea(handle, game, species)
  end
  return nil
end

function AreaScreen.new(game, species, lang)
  local mapArea = externalArea(game, species)
  local native
  if not mapArea then
    native = require("src.ui.TownMap").new(game, { nestSpecies = species })
  end
  return setmetatable({ game = game, species = species, lang = lang or language(),
    native = native, mapArea = mapArea, pulse = 0,
    mapSource = mapArea and mapArea.source or "engine",
    __vascModernDexArea = true }, AreaScreen)
end

function AreaScreen:uiSize() return W, H end
function AreaScreen:sgbPalettes()
  return { { colors = false, x = 0, y = 0, w = W, h = H } }
end

function AreaScreen:update(dt)
  self.pulse = (self.pulse + (tonumber(dt) or 0)) % 1
  if self.native then self.native.blink = (self.native.blink + 1) % 32 end
  local input = self.game.input
  if input:wasPressed("b") or input:wasPressed("a") then
    play(self.game, "Press_AB")
    self.game.stack:pop()
  elseif input:wasPressed("start") then
    playCry(self.game, self.species)
  end
end

function AreaScreen:draw()
  local def = self.game.data.pokemon[self.species] or {}
  header(self.lang, tr(self.lang, "area"), C.cyan)
  fill(C.bezelDark, 7, 43, 170, 238, 9)
  fill(C.bezel, 9, 45, 166, 234, 8)
  fill(C.panel, 12, 48, 160, 228, 7)
  line(C.black, 12, 48, 160, 228, 7, 2)
  drawSprite(self.game, self.species, 24, 62, 136, 112, true)
  text(("No.%03d"):format(def.dex or 0), 24, 188, C.cyan)
  text(fit(def.name or self.species, 136), 24, 202, C.white)
  text("START " .. tr(self.lang, "cry"), 24, 244, C.gold)
  text("A/B " .. tr(self.lang, "back"), 24, 258, C.soft)

  fill(C.bezelDark, 175, 43, 330, 238, 9)
  fill(C.bezel, 177, 45, 326, 234, 8)
  fill(C.black, 180, 48, 320, 228, 7)
  love.graphics.push()
  love.graphics.setScissor(180, 48, 320, 228)
  if self.mapArea then
    local sourceW = math.max(1, tonumber(self.mapArea.width) or 288)
    local sourceH = math.max(1, tonumber(self.mapArea.height) or 230)
    local scale = math.min(312 / sourceW, 220 / sourceH)
    local mapX = 180 + (320 - sourceW * scale) / 2
    local mapY = 48 + (228 - sourceH * scale) / 2
    local imageW, imageH = self.mapArea.image:getDimensions()
    color(C.white)
    love.graphics.draw(self.mapArea.image, mapX, mapY, 0,
      sourceW * scale / imageW, sourceH * scale / imageH)
    for _, marker in ipairs(self.mapArea.markers) do
      local x = mapX + (tonumber(marker.x) or 0) * scale
      local y = mapY + (tonumber(marker.y) or 0) * scale
      local ring = 5 + self.pulse * 5
      color(C.black, 0.82)
      love.graphics.circle("fill", x, y, 5)
      color(C.gold)
      love.graphics.circle("fill", x, y, 3)
      color(C.white)
      love.graphics.circle("fill", x, y, 1)
      color(C.cyan, 0.85 - self.pulse * 0.55)
      love.graphics.setLineWidth(2)
      love.graphics.circle("line", x, y, ring)
      love.graphics.setLineWidth(1)
    end
    if #self.mapArea.markers == 0 then
      fill(C.black, 232, 145, 216, 28, 5, 0.78)
      text(tr(self.lang, "areaUnknown"), 248, 155, C.soft)
    end
    fill(C.black, 388, 253, 102, 15, 3, 0.78)
    text("VASC KANTO", 398, 257, C.cyan)
  else
    -- 160x144 at 1.5x is 240x216: a complete native map with breathing room.
    love.graphics.translate(220, 54)
    love.graphics.scale(1.5, 1.5)
    self.native:draw()
  end
  love.graphics.pop()
  love.graphics.setScissor()
  line(C.black, 180, 48, 320, 228, 7, 2)
  markTrueColor()
end

UI.AreaScreen = AreaScreen
UI.WIDTH, UI.HEIGHT = W, H
UI.MODES = MODES
UI.REGIONS = REGIONS
UI._dexCatalogue = dexCatalogue
UI._rowsForMode = rowsForMode
UI._rowsForRegion = rowsForRegion
UI._regionIsUnlocked = regionIsUnlocked
UI._spritePath = spritePath
UI._externalArea = externalArea

return UI
