-- High-resolution ORAS-inspired presentation for VASC's native PartyMenu skin.
-- Integrated from the reviewed VASC: ORAS Storage UI 0.5.3 presentation.
-- All chrome and scenery are procedural; Pokemon art is resolved from the
-- active game so compatible full-colour sprite mods remain visible. Native
-- PartyMenu instances and immutable PokemonUi storage snapshots share this one
-- visual implementation; only their behavior/ownership adapters differ.

local V = ...
local Party = require("src.pokemon.Party")
local Model = {
  PARTY_CAPACITY = Party.MAX or 6,
  -- The Host-v1 adapter below builds a presentation-only sparse proxy.  It
  -- never receives or mutates the authoritative save arrays.
  BOX_CAPACITY = 20,
}

function Model.monAt(save, kind, index, boxIndex)
  if type(save) ~= "table" then return nil end
  if kind == "party" then
    return type(save.party) == "table" and save.party[index] or nil
  end
  boxIndex = tonumber(boxIndex) or tonumber(save.currentBox) or 1
  local box = type(save.boxes) == "table" and save.boxes[boxIndex]
  return type(box) == "table" and box[index] or nil
end
local mod = V.mod

local function findMod(id)
  if not (mod and type(mod.find) == "function") then return nil end
  local ok, handle = pcall(mod.find, id)
  if not ok then ok, handle = pcall(mod.find, mod, id) end
  return ok and handle or nil
end

local function activeLanguage(game)
  if type(V.language) == "function" then
    local ok, value = pcall(V.language, game)
    if ok and (value == "de" or value == "en") then return value end
  elseif V.language == "de" or V.language == "en" then
    return V.language
  end
  local universal = findMod("translation-german-universal")
  local boot = universal and universal.exports
    and universal.exports.bootLanguage
  if boot == "de" or boot == "en" then return boot end
  local ascendant = findMod("kanto_ascendant")
  local language = ascendant and ascendant.exports
    and ascendant.exports.language
  if type(language) == "function" then
    local ok, value = pcall(language)
    if ok and (value == "de" or value == "en") then return value end
  end
  for _, id in ipairs({ "deutsch", "deutsch-blau", "deutsch-gelb" }) do
    if findMod(id) then return "de" end
  end
  local direct = type(game) == "table" and game.language or nil
  return direct == "de" and "de" or "en"
end

local Assets = require("src.render.Assets")
local Font = require("src.render.Font")
local PaletteFX = require("src.render.PaletteFX")
local Sprites = require("src.pokemon.Sprites")
local Stats = require("src.pokemon.Stats")
local ItemEffects = require("src.inventory.ItemEffects")
local TypeChart = require("src.battle.TypeChart")
-- Gen 2 already uses VASC's bundled, menu-only Crystal fronts as its first
-- choice.  Load the same optional service for Gen 1 so Team/Box/Summary no
-- longer fall through to edition-dependent low-resolution engine sprites.
-- pcall keeps older compatible hosts fail-open; the ordinary sprite seam
-- remains the final fallback for species outside the bundled catalogue.
local Gen2CrystalFronts
if type(V.require) == "function" then
  local ok, value = pcall(V.require, "Gen2CrystalFronts")
  if ok and type(value) == "table" then Gen2CrystalFronts = value end
end
local MobileMenuPresentation
do
  local ok, value = pcall(V.require, "MobileMenuPresentation")
  if ok and type(value) == "table" then MobileMenuPresentation = value end
end

local P = {}
P.WIDTH = 512
P.HEIGHT = 288

local C = {
  navy = { 12 / 255, 37 / 255, 84 / 255 },
  navy2 = { 5 / 255, 24 / 255, 61 / 255 },
  blue = { 23 / 255, 75 / 255, 142 / 255 },
  orange = { 244 / 255, 91 / 255, 12 / 255 },
  orange2 = { 1, 145 / 255, 22 / 255 },
  gold = { 1, 194 / 255, 44 / 255 },
  shinyOutline = { 33 / 255, 27 / 255, 15 / 255 },
  shinyGold = { 240 / 255, 197 / 255, 71 / 255 },
  shinyHighlight = { 1, 243 / 255, 166 / 255 },
  cream = { 1, 247 / 255, 218 / 255 },
  paper = { 1, 252 / 255, 236 / 255 },
  shell = { 236 / 255, 229 / 255, 205 / 255 },
  shellDark = { 147 / 255, 151 / 255, 148 / 255 },
  glass = { 158 / 255, 215 / 255, 244 / 255 },
  glass2 = { 202 / 255, 238 / 255, 251 / 255 },
  glassDark = { 104 / 255, 177 / 255, 218 / 255 },
  sky = { 31 / 255, 158 / 255, 219 / 255 },
  skyLight = { 100 / 255, 207 / 255, 240 / 255 },
  sea = { 5 / 255, 113 / 255, 183 / 255 },
  seaLight = { 30 / 255, 171 / 255, 219 / 255 },
  green = { 45 / 255, 184 / 255, 69 / 255 },
  red = { 234 / 255, 68 / 255, 37 / 255 },
  purple = { 132 / 255, 82 / 255, 187 / 255 },
  gray = { 117 / 255, 135 / 255, 148 / 255 },
  white = { 1, 1, 1 },
  black = { 20 / 255, 23 / 255, 25 / 255 },
}

-- One palette owns Box badges, Team-card rails and the mini-Team strip. Keep
-- every canonical Gen-I/II type visually distinct; in particular Poison's
-- violet must never collapse onto Psychic's magenta again.
local TYPE_ACCENT = {
  NORMAL = { 151 / 255, 154 / 255, 137 / 255 },
  FIGHTING = { 191 / 255, 48 / 255, 40 / 255 },
  FLYING = { 135 / 255, 160 / 255, 232 / 255 },
  POISON = { 157 / 255, 72 / 255, 181 / 255 },
  GROUND = { 196 / 255, 151 / 255, 77 / 255 },
  ROCK = { 165 / 255, 138 / 255, 61 / 255 },
  BUG = { 135 / 255, 172 / 255, 49 / 255 },
  GHOST = { 104 / 255, 81 / 255, 139 / 255 },
  STEEL = { 148 / 255, 160 / 255, 178 / 255 },
  FIRE = { 232 / 255, 82 / 255, 40 / 255 },
  WATER = { 65 / 255, 126 / 255, 214 / 255 },
  GRASS = { 73 / 255, 166 / 255, 76 / 255 },
  ELECTRIC = C.gold,
  PSYCHIC_TYPE = { 220 / 255, 83 / 255, 133 / 255 },
  ICE = { 74 / 255, 176 / 255, 196 / 255 },
  DRAGON = { 93 / 255, 75 / 255, 190 / 255 },
  DARK = { 92 / 255, 74 / 255, 64 / 255 },
  FAIRY = { 232 / 255, 122 / 255, 184 / 255 },
}

-- TypeChart deliberately owns the engine's language-neutral names.  The
-- Party/Box card, however, is a mod-owned fullscreen surface and therefore
-- needs an explicit German vocabulary just like the adjacent Summary card.
-- Keeping it here also prevents a missing translation mod from producing a
-- German chrome with English type pills.
local TYPE_NAME_DE = {
  NORMAL = "NORMAL", FIGHTING = "KAMPF", FLYING = "FLUG",
  POISON = "GIFT", GROUND = "BODEN", ROCK = "GESTEIN",
  BUG = "KÄFER", GHOST = "GEIST", STEEL = "STAHL",
  FIRE = "FEUER", WATER = "WASSER", GRASS = "PFLANZE",
  ELECTRIC = "ELEKTRO", PSYCHIC_TYPE = "PSYCHO", ICE = "EIS",
  DRAGON = "DRACHE", DARK = "UNLICHT", FAIRY = "FEE",
}
local TYPE_NAME_EN = {
  NORMAL = "NORMAL", FIGHTING = "FIGHTING", FLYING = "FLYING",
  POISON = "POISON", GROUND = "GROUND", ROCK = "ROCK",
  BUG = "BUG", GHOST = "GHOST", STEEL = "STEEL",
  FIRE = "FIRE", WATER = "WATER", GRASS = "GRASS",
  ELECTRIC = "ELECTRIC", PSYCHIC_TYPE = "PSYCHIC", ICE = "ICE",
  DRAGON = "DRAGON", DARK = "DARK", FAIRY = "FAIRY",
}

local imageCache = {}
local solidShader

-- Standalone targets before the shared engine predicate use the same species
-- tmhm scan as ItemEffects.use. Prefer the engine helper when it exists; this
-- fallback is pure and presentation-only.
local function canLearnMachine(data, mon, machine)
  if type(ItemEffects.canLearnMachine) == "function" then
    return ItemEffects.canLearnMachine(data, mon, machine)
  end
  if type(data) ~= "table" or type(mon) ~= "table"
      or mon.isEgg == true or mon.egg == true or mon.is_egg == true
      or tostring(mon.status or ""):upper() == "EGG" then
    return false
  end
  local move = type(machine) == "table" and machine.move or nil
  if move == nil or (type(move) ~= "string" and type(move) ~= "number")
      or (type(move) == "string" and move == "") then return false end
  local catalog = data.pokemon
  if type(catalog) ~= "table" then return false end
  local species = catalog[mon.species]
  if type(species) ~= "table" then return false end
  local speciesId = tostring(mon.species or ""):upper()
  if speciesId == "EGG" or speciesId == "POKEMON_EGG" then return false end
  if type(species.tmhm) ~= "table" then return false end
  for _, id in ipairs(species.tmhm) do
    if id == move then return true end
  end
  return false
end

-- Crystal fronts are authored at 40, 48 or 56 pixels. Team/Detail preserve
-- those authored classes and Strip uses an exact half-size ratio. The Box
-- target belongs to the selected grid: the honest Gen-I 5x4 layout reaches
-- 40px while the decorative ORAS 6x5 layout retains its compact 24px target.
local CRYSTAL_ROLE_SCALE = {
  team = 1,
  detail = 1,
  strip = 0.5,
}

-- Gen I really stores twenty Pokemon per Box. The detailed layout therefore
-- uses five by four larger cells and can retain the smallest Crystal canvas
-- at native 40x40. The 6x5 variant remains available for the characteristic
-- ORAS density, with its final ten positions visibly reserved and locked.
local BOX_LAYOUTS = {
  detail_20 = {
    id = "detail_20",
    columns = 5,
    slots = 20,
    originX = 38,
    originY = 62,
    stepX = 57,
    stepY = 44,
    cellWidth = 55,
    cellHeight = 42,
    spriteInsetX = 3,
    spriteInsetY = 1,
    spriteWidth = 43,
    spriteHeight = 40,
    spriteTarget = 40,
    markerOffsetX = 50,
    markerOffsetY = 6,
  },
  oras_30 = {
    id = "oras_30",
    columns = 6,
    slots = 30,
    originX = 39,
    originY = 67,
    stepX = 47,
    stepY = 33,
    cellWidth = 45,
    cellHeight = 31,
    spriteInsetX = 3,
    spriteInsetY = 1,
    spriteWidth = 39,
    spriteHeight = 29,
    spriteTarget = 24,
    markerOffsetX = 38,
    markerOffsetY = 7,
  },
}

local function boxGridMode()
  local options = mod and mod.options
  -- VASC exposes the reviewed prototype's grid as `ascBoxDensity`; retain the
  -- standalone 0.5.3 key as a compatibility fallback for imported configs.
  local mode = options and options.get and
    (options:get("ascBoxDensity") or options:get("box_grid_layout"))
  return mode == "oras_30" and "oras_30" or "detail_20"
end

local function activeBoxLayout()
  return BOX_LAYOUTS[boxGridMode()]
end

if type(Assets.register) == "function" then
  Assets.register(function() imageCache = {} end)
end

local function setColor(color, alpha)
  love.graphics.setColor(color[1], color[2], color[3], alpha or 1)
end

local function rect(color, x, y, w, h, alpha)
  setColor(color, alpha)
  love.graphics.rectangle("fill", x, y, w, h)
end

local function rounded(color, x, y, w, h, radius, alpha)
  setColor(color, alpha)
  love.graphics.rectangle("fill", x, y, w, h, radius or 4, radius or 4)
end

local function outline(color, x, y, w, h, radius, width, alpha)
  local g = love.graphics
  setColor(color, alpha)
  g.setLineWidth(width or 1)
  g.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1,
    radius or 3, radius or 3)
  g.setLineWidth(1)
end

local function shaderFor(color)
  if solidShader == nil then
    local ok, shader = pcall(love.graphics.newShader, [[
      extern vec4 tone;
      vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
        vec4 px = Texel(tex, tc);
        return vec4(tone.rgb, px.a * tone.a);
      }
    ]])
    solidShader = ok and shader or false
  end
  if solidShader then
    solidShader:send("tone", { color[1], color[2], color[3], color[4] or 1 })
    return solidShader
  end
end

local function drawText(value, x, y, color, scale)
  local g = love.graphics
  color, scale = color or C.black, scale or 1
  local shader = shaderFor(color)
  if shader then g.setShader(shader); setColor(C.white) else setColor(color) end
  g.push()
  g.translate(math.floor(x), math.floor(y))
  g.scale(scale, scale)
  Font.draw(tostring(value or ""), 0, 0)
  g.pop()
  if shader then g.setShader() end
end

local function drawBoldText(value, x, y, color, scale)
  scale = scale or 1
  drawText(value, x, y, color, scale)
  drawText(value, x + math.max(1, math.floor(scale / 2)), y, color, scale)
end

local function textWidth(value, scale)
  return Font.width(tostring(value or "")) * (scale or 1)
end

local function centeredText(value, x, y, w, color, scale)
  drawText(value, x + math.floor((w - textWidth(value, scale)) / 2), y,
    color, scale)
end

local function rightText(value, right, y, color, scale)
  drawText(value, right - textWidth(value, scale), y, color, scale)
end

local function fitText(value, width, scale)
  value, scale = tostring(value or ""), scale or 1
  if textWidth(value, scale) <= width then return value end
  local spans = Font.split(value)
  local allowed = math.floor(width / scale)
  local count = Font.spansFitting(spans, math.max(0, allowed - Font.width(".")))
  local pieces = {}
  for i = 1, count do pieces[#pieces + 1] = value:sub(spans[i].from, spans[i].to) end
  return table.concat(pieces) .. "."
end

local function drawBackground()
  local g = love.graphics
  -- Sky gradient in crisp horizontal bands.
  for y = 0, 152, 4 do
    local t = y / 152
    setColor({
      C.sky[1] * (1 - t) + C.skyLight[1] * t,
      C.sky[2] * (1 - t) + C.skyLight[2] * t,
      C.sky[3] * (1 - t) + C.skyLight[3] * t,
    })
    g.rectangle("fill", 0, y, P.WIDTH, 4)
  end

  -- Distant cloud banks.
  setColor(C.white, 0.92)
  local clouds = {
    { 0, 26, 48, 14 }, { 12, 17, 34, 19 }, { 32, 27, 41, 14 },
    { 342, 38, 66, 13 }, { 356, 28, 37, 19 }, { 386, 36, 39, 15 },
    { 466, 23, 50, 15 }, { 482, 13, 31, 20 },
  }
  for _, c in ipairs(clouds) do
    g.ellipse("fill", c[1] + c[3] / 2, c[2] + c[4] / 2, c[3] / 2, c[4] / 2)
  end
  setColor(C.cream, 0.52)
  g.rectangle("fill", 0, 40, 82, 5)
  g.rectangle("fill", 337, 47, 91, 5)
  g.rectangle("fill", 457, 36, 55, 5)

  -- Island horizon and ocean.
  rect(C.sea, 0, 145, P.WIDTH, 107)
  setColor({ 24 / 255, 109 / 255, 150 / 255 }, 0.72)
  g.polygon("fill", 0, 166, 38, 143, 78, 153, 115, 136, 159, 160,
    205, 149, 256, 162, 304, 143, 351, 155, 401, 135, 455, 158, 512, 140,
    512, 178, 0, 178)
  setColor({ 44 / 255, 137 / 255, 104 / 255 }, 0.72)
  g.polygon("fill", 0, 169, 47, 151, 82, 164, 131, 147, 174, 170,
    241, 157, 286, 173, 347, 151, 397, 164, 454, 148, 512, 166,
    512, 184, 0, 184)
  rect(C.seaLight, 0, 180, P.WIDTH, 72, 0.38)
  setColor(C.white, 0.75)
  for y = 184, 246, 13 do
    local offset = (math.floor(y / 13) % 2) * 11
    for x = -12 + offset, 512, 39 do
      g.line(x, y, x + 15, y - 2, x + 26, y)
    end
  end

  -- Hoenn-tech circuit motif.
  setColor(C.glass2, 0.27)
  g.setLineWidth(2)
  g.line(414, 5, 453, 5, 453, 16, 475, 16, 475, 29)
  g.line(431, 23, 458, 23, 458, 35, 489, 35, 489, 48)
  g.line(474, 0, 474, 9, 493, 9, 493, 20, 511, 20)
  g.rectangle("line", 405.5, 0.5, 14, 9)
  g.circle("line", 490, 49, 4)
  g.setLineWidth(1)
end

local function shellPanel(x, y, w, h, radius)
  radius = radius or 8
  -- A restrained two-pixel shadow keeps adjacent panels visually separate
  -- without spilling into the strip or footer below.
  rounded(C.navy2, x + 2, y + 2, w, h, radius, 0.58)
  rounded(C.shellDark, x, y, w, h, radius)
  rounded(C.cream, x + 2, y + 2, w - 4, h - 4, radius - 1)
  rounded(C.white, x + 5, y + 5, w - 10, h - 10, radius - 2)
  outline(C.navy, x, y, w, h, radius, 2)
  outline(C.shellDark, x + 4, y + 4, w - 8, h - 8, radius - 2, 1, 0.85)
end

local function drawHeader(self)
  local g = love.graphics
  -- Raised orange top shelf, joined to the header instead of floating above it.
  setColor(C.navy2, 0.45)
  g.polygon("fill", 108, 24, 123, 14, 255, 14, 266, 24)
  setColor(C.orange2)
  g.polygon("fill", 102, 22, 119, 11, 256, 11, 270, 22)
  setColor(C.gold, 0.9)
  g.polygon("fill", 121, 13, 245, 13, 252, 18, 129, 18)

  rounded(C.navy2, 48, 25, 276, 34, 10, 0.65)
  rounded(C.orange, 46, 22, 276, 34, 10)
  rounded(C.cream, 49, 25, 270, 28, 8)
  rounded(C.navy, 52, 28, 264, 22, 6)
  for sy = 30, 47, 3 do rect(C.blue, 56, sy, 256, 1, 0.24) end
  outline(C.blue, 55, 30, 258, 18, 5, 1, 0.8)
  -- Team and battle-team are single views.  Decorative page arrows there
  -- promised navigation that cannot exist; reserve them for the actual box
  -- view, whose box number can be changed.
  if self.view == "box" then
    setColor(self.boxHeaderFocus and C.white or C.gold)
    g.polygon("fill", 65, 39, 76, 31, 76, 47)
    g.polygon("fill", 303, 39, 292, 31, 292, 47)
    setColor(C.orange2)
    g.polygon("fill", 66, 39, 73, 34, 73, 44)
    g.polygon("fill", 302, 39, 295, 34, 295, 44)
  end
  local title
  if self.context == "battle" then
    title = self.language == "de" and "KAMPFTEAM" or "BATTLE TEAM"
  elseif self.view == "box" then
    title = ("BOX %02d"):format(self.game.save.currentBox)
  else
    title = "TEAM"
  end
  local titleX = 52 + math.floor((264 - textWidth(title, 2)) / 2)
  drawBoldText(title, titleX, 31, C.white, 2)
  if self.view == "box" and self.boxHeaderFocus then
    -- The arrows are an actual focus target: UP reaches them from the first
    -- grid row and LEFT/RIGHT changes boxes even while carrying a Pokemon.
    outline(C.gold, 54, 29, 260, 20, 5, 2)
    rect(C.white, 61, 37, 5, 4, 0.9)
    rect(C.white, 302, 37, 5, 4, 0.9)
  end
  if self.view == "box" and type(self.search) == "table" then
    rounded(C.navy2, 326, 14, 178, 40, 6, .72)
    outline(C.glass2, 326, 14, 178, 40, 6, 1, .9)
    local de = self.language == "de"
    local mode = tostring(self.search.mode or "name"):upper()
    drawText((de and "SUCHE " or "SEARCH ") .. mode, 334, 18, C.white, 1)
    local query = tostring(self.search.query or "")
    local composition = self.search.editing
      and tostring(self.search.composition or "") or ""
    local visibleQuery = query .. composition
    drawText(visibleQuery == "" and (de and "TIPPE..." or "TYPE...")
      or fitText(visibleQuery, 112, 1), 334, 31,
      (self.search.active or self.search.editing) and C.gold or C.glass2, 1)
    if self.search.editing then
      rounded(C.orange, 442, 16, 58, 14, 4)
      outline(C.gold, 442, 16, 58, 14, 4, 1, .9)
      drawText(de and "X FERTIG" or "X DONE", de and 447 or 453, 19,
        C.white, 1)
    end
    local count = #(self.search.results or {})
    local index = math.max(0, math.min(count, tonumber(self.search.index) or 0))
    rightText(("%d/%d"):format(index, count), 496, 31, C.gold, 1)
    local tabW = 178 / 3
    for index, id in ipairs({ "N", "T", "G" }) do
      local x = 326 + (index - 1) * tabW
      if id == mode:sub(1, 1) then rect(C.orange, x, 51, tabW, 3) end
      drawText(id, x + math.floor(tabW / 2) - 3, 51, C.white, 1)
    end
  end
end

local function monDef(game, mon)
  return mon and game.data.pokemon[mon.species] or nil
end

local function isEgg(mon)
  if type(mon) ~= "table" then return false end
  if mon.isEgg == true or mon.egg == true or mon.is_egg == true then
    return true
  end
  if tostring(mon.status or ""):upper() == "EGG" then return true end
  local species = tostring(mon.species or ""):upper()
  return species == "EGG" or species == "POKEMON_EGG"
end

local function monName(game, mon)
  if isEgg(mon) then return mon.nickname or "EGG" end
  local def = monDef(game, mon)
  return mon and (mon.nickname or (def and def.name) or mon.species) or ""
end

local function ensureStats(game, mon)
  if mon and type(mon.stats) == "table" then return mon.stats end
  local def = monDef(game, mon)
  if mon and def then pcall(Stats.ensure, def, mon) end
  return mon and mon.stats or nil
end

local function hpRatio(game, mon)
  local stats = ensureStats(game, mon)
  if not stats then return 0 end
  return math.max(0, math.min(1,
    (tonumber(mon.hp) or 0) / math.max(1, tonumber(stats.hp) or 1)))
end

local function eggProgress(mon)
  local remaining = math.max(0, tonumber(mon and
    (mon.eggStepsRemaining or mon.eggSteps)) or 0)
  local total = math.max(1, tonumber(mon and
    (mon.eggTotalSteps or mon.eggTotal)) or remaining or 1)
  return math.max(0, math.min(1, (total - remaining) / total)), remaining
end

local function partyFor(self)
  return self.party or self.game.save.party or {}
end

local function isShiny(mon)
  if type(mon) ~= "table" then return false end
  -- Eggs do not reveal the future hatchling's shiny state in Gen II.
  if isEgg(mon) then return false end
  if mon.shiny == true or Stats.isShiny(mon.dvs) then return true end
  if mod and type(mod.find) == "function" then
    local ok, handle = pcall(mod.find, "kanto_ascendant")
    local shiny = ok and handle and handle.exports and handle.exports.shinySystem
    if type(shiny) == "table" and type(shiny.isShiny) == "function" then
      local called, value = pcall(shiny.isShiny, mon)
      if called then return value and true or false end
    end
  end
  return false
end

local function isActive(self, mon)
  local player = self.context == "battle" and self.battle
    and self.battle.player or nil
  return player ~= nil and ((type(player) == "table" and player.mon) or player) == mon
end

local function canonicalType(kind)
  kind = tostring(kind or ""):upper():gsub("[%s%-]+", "_")
  if kind == "PSYCHIC" then return "PSYCHIC_TYPE" end
  return kind
end

local function typeAccentFor(kind)
  return TYPE_ACCENT[canonicalType(kind)] or C.blue
end

local function typeList(game, mon)
  local out = {}
  local function append(value)
    if type(value) == "table" then
      value = value.id or value.name or value.key or value.type
    end
    if type(value) ~= "string" or value == "" then return end
    value = canonicalType(value)
    if value ~= out[1] and value ~= out[2] and #out < 2 then
      out[#out + 1] = value
    end
  end
  local function appendSource(source)
    if type(source) == "table" then
      for _, value in ipairs(source) do append(value) end
      append(source.primary)
      append(source.secondary)
      append(source.type1)
      append(source.type2)
    else
      append(source)
    end
  end
  if type(mon) == "table" then
    appendSource(mon.types)
    append(mon.type1)
    append(mon.type2)
    append(mon.type)
  end
  local def = monDef(game, mon)
  if #out < 2 and type(def) == "table" then
    appendSource(def.types)
    append(def.type1)
    append(def.type2)
    append(def.type)
  end
  return out
end

local function typeAccent(game, mon)
  if isEgg(mon) then return C.gold end
  return typeAccentFor(typeList(game, mon)[1])
end

local function primaryType(game, mon)
  return typeList(game, mon)[1] or "NORMAL"
end

local function monTypes(game, mon)
  local out = {}
  for _, kind in ipairs(typeList(game, mon)) do
    if type(kind) == "string" and kind ~= "" and kind ~= out[1] then
      out[#out + 1] = kind
      if #out == 2 then break end
    end
  end
  if #out == 0 then out[1] = "NORMAL" end
  return out
end

local function namedValue(value)
  if type(value) == "string" and value ~= "" then return value end
  if type(value) ~= "table" then return nil end
  for _, key in ipairs({ "name", "label", "id", "key" }) do
    local candidate = value[key]
    if type(candidate) == "string" and candidate ~= "" then return candidate end
  end
  return nil
end

-- Gen I records have no Ability field. Hoenn-aware data packs can expose one
-- on the individual mon or species definition without requiring another UI
-- rewrite; until then the reserved row deliberately renders a neutral dash.
local function abilityName(game, mon)
  -- KASC eggs deliberately retain their future species internally. Never
  -- consult either the individual or species record from an egg-facing UI.
  if isEgg(mon) then return "---" end
  local direct = namedValue(mon and (mon.ability or mon.abilityId))
  if direct then return direct:gsub("_", " ") end
  local def = monDef(game, mon)
  direct = namedValue(def and (def.ability or def.abilityId))
  if direct then return direct:gsub("_", " ") end
  local abilities = def and def.abilities
  if type(abilities) == "table" then
    direct = namedValue(abilities)
    if not direct then
      for _, value in ipairs(abilities) do
        direct = namedValue(value)
        if direct then break end
      end
    end
  end
  return direct and direct:gsub("_", " ") or "---"
end

-- Held items are not part of the Gen-I save object, but Johto-aware data can
-- fill any of these common seams without another presentation rewrite.
local function itemName(game, mon)
  if isEgg(mon) then return "---" end
  local direct
  for _, key in ipairs({
    "item", "heldItem", "held_item", "itemId",
    "heldItemId", "held_item_id",
  }) do
    local raw = mon and mon[key]
    if raw ~= false and raw ~= 0 and raw ~= "" then
      direct = namedValue(raw)
      if direct then break end
    end
  end
  if not direct then return "---" end
  local item = game and game.data and game.data.items
    and game.data.items[direct]
  local resolved = namedValue(item) or direct
  return tostring(resolved):gsub("_", " ")
end

local function localizedTypeName(kind, language)
  local canonical = canonicalType(kind)
  if language == "de" and TYPE_NAME_DE[canonical] then
    return TYPE_NAME_DE[canonical]
  end
  if language == "en" and TYPE_NAME_EN[canonical] then
    return TYPE_NAME_EN[canonical]
  end
  return TypeChart.displayName(canonical) or tostring(canonical or "---")
end

local function drawTypePill(kind, x, y, w, language)
  local accent = typeAccentFor(kind)
  local label = localizedTypeName(kind, language)
  rounded(accent, x, y, w, 13, 3)
  outline(C.navy, x, y, w, 13, 3, 1, 0.65)
  -- Seven-letter names such as PFLANZE/GESTEIN are exactly 56 authored
  -- pixels.  A 61px dual pill can retain them whole with two-pixel side
  -- breathing room; the former six-pixel fit budget truncated them needlessly.
  centeredText(fitText(label, w - 4), x + 2, y + 3, w - 4,
    accent == C.gold and C.navy2 or C.white)
end

local genderResolver, genderResolverTried
local function resolvedGender(game, mon)
  if not genderResolverTried then
    genderResolverTried = true
    if type(V.require) == "function" then
      local ok, service = pcall(V.require, "BattleHudExtras")
      if ok and type(service) == "table"
          and type(service.presentationGender) == "function" then
        genderResolver = service.presentationGender
      end
    end
  end
  if genderResolver then
    local ok, value = pcall(genderResolver, mon, game)
    if ok and type(value) == "string" and value ~= "" then return value end
  end
  return mon and (mon.gender or mon.sex) or "GENDERLESS"
end

local function genderValue(game, mon)
  local value = tostring(resolvedGender(game, mon) or ""):upper()
  if value == "MALE" or value == "M" or value == "♂" then
    return "♂", C.glassDark
  end
  if value == "FEMALE" or value == "F" or value == "♀" then
    return "♀", TYPE_ACCENT.PSYCHIC_TYPE
  end
  return "-", C.gray
end

local function partyCardGender(game, mon, displayName)
  -- Team cards have a quiet seat beside the level, unlike the dense Box
  -- raster and 27px mini-Team strip. Eggs and genderless species must not
  -- acquire a made-up dash here. Nidoran's canonical name already carries
  -- its sex, so suppress only names that visibly encode it; a nicknamed
  -- Nidoran still benefits from the ordinary card marker.
  if isEgg(mon) then return nil end
  local symbol, accent = genderValue(game, mon)
  if symbol == "-" then return nil end
  local name = tostring(displayName or "")
  if name:find("♂", 1, true) or name:find("♀", 1, true) then return nil end
  local compact = name:upper():gsub("[^%w]", "")
  if compact == "NIDORANM" or compact == "NIDORANF" then return nil end
  return symbol, accent
end

local function drawPartyGenderSymbol(game, mon, displayName, x, y)
  local symbol, accent = partyCardGender(game, mon, displayName)
  if not symbol then return end
  -- Party gender is text only. In particular, do not restore the opaque
  -- paper/outline badge that covered the Team artwork in rc.10.
  centeredText(symbol, x, y, 17, accent)
end

local function drawTypeGlyph(kind, cx, cy, s)
  local g = love.graphics
  kind = canonicalType(kind)
  setColor(C.white)
  g.setLineWidth(math.max(1, s * 0.1))
  if kind == "FIRE" then
    g.polygon("fill", cx, cy - s * .45, cx + s * .30, cy - s * .05,
      cx + s * .20, cy + s * .38, cx, cy + s * .48,
      cx - s * .28, cy + s * .18, cx - s * .13, cy - s * .08)
    setColor(typeAccentFor(kind)); g.polygon("fill", cx, cy - s * .05,
      cx + s * .10, cy + s * .29, cx - s * .10, cy + s * .31)
  elseif kind == "WATER" then
    g.polygon("fill", cx, cy - s * .48, cx + s * .30, cy + s * .12,
      cx + s * .18, cy + s * .40, cx - s * .18, cy + s * .40,
      cx - s * .30, cy + s * .12)
  elseif kind == "GRASS" then
    g.polygon("fill", cx - s*.32, cy + s*.30, cx - s*.18, cy - s*.18,
      cx + s*.34, cy - s*.36, cx + s*.20, cy + s*.16)
    g.line(cx - s * .28, cy + s * .36, cx + s * .20, cy - s * .30)
  elseif kind == "ELECTRIC" then
    g.polygon("fill", cx + s * .08, cy - s * .48, cx - s * .25, cy + s * .05,
      cx - s * .02, cy + s * .03, cx - s * .12, cy + s * .48,
      cx + s * .30, cy - s * .12, cx + s * .06, cy - s * .08)
  elseif kind == "ICE" then
    for i = 0, 2 do
      local a = i * math.pi / 3
      g.line(cx - math.cos(a) * s * .42, cy - math.sin(a) * s * .42,
        cx + math.cos(a) * s * .42, cy + math.sin(a) * s * .42)
    end
  elseif kind == "PSYCHIC" or kind == "PSYCHIC_TYPE" then
    g.ellipse("line", cx, cy, s * .40, s * .25)
    g.circle("fill", cx, cy, s * .10)
  elseif kind == "POISON" then
    g.circle("fill", cx, cy - s * .08, s * .25)
    g.circle("fill", cx - s * .25, cy + s * .26, s * .11)
    g.circle("fill", cx + s * .25, cy + s * .26, s * .11)
  elseif kind == "FLYING" then
    g.polygon("fill", cx - s * .40, cy + s * .25, cx + s * .40, cy - s * .37,
      cx + s * .16, cy + s * .28, cx - s * .05, cy + s * .05)
    setColor(typeAccentFor(kind)); g.line(cx - s * .15, cy + s * .18,
      cx + s * .22, cy - s * .12)
  elseif kind == "BUG" then
    g.ellipse("fill", cx, cy + s * .08, s * .27, s * .35)
    g.line(cx - s * .12, cy - s * .20, cx - s * .30, cy - s * .42,
      cx + s * .12, cy - s * .20, cx + s * .30, cy - s * .42)
  elseif kind == "GHOST" then
    g.polygon("fill", cx - s * .34, cy + s * .38, cx - s * .34, cy,
      cx - s * .20, cy - s * .34, cx + s * .20, cy - s * .34,
      cx + s * .34, cy, cx + s * .34, cy + s * .38,
      cx + s * .16, cy + s * .20, cx, cy + s * .38,
      cx - s * .16, cy + s * .20)
  elseif kind == "GROUND" then
    g.polygon("fill", cx - s * .45, cy + s * .35, cx - s * .08, cy - s * .35,
      cx + s * .12, cy, cx + s * .26, cy - s * .18, cx + s * .45, cy + s * .35)
  elseif kind == "ROCK" then
    g.polygon("fill", cx - s * .38, cy + s * .28, cx - s * .26, cy - s * .28,
      cx + s * .10, cy - s * .43, cx + s * .40, cy - s * .05,
      cx + s * .22, cy + s * .38)
  elseif kind == "STEEL" then
    g.polygon("line", cx - s * .38, cy, cx - s * .19, cy - s * .34,
      cx + s * .19, cy - s * .34, cx + s * .38, cy,
      cx + s * .19, cy + s * .34, cx - s * .19, cy + s * .34)
    g.circle("fill", cx, cy, s * .12)
  elseif kind == "FIGHTING" then
    g.rectangle("fill", cx - s * .31, cy - s * .08, s * .62, s * .35, s*.08)
    for i = 0, 3 do
      g.rectangle("fill", cx - s * .34 + i*s*.18, cy - s*.36,
        s*.15, s*.30, s*.04)
    end
  elseif kind == "DRAGON" then
    g.polygon("fill", cx - s*.38, cy - s*.25, cx, cy - s*.05,
      cx + s*.38, cy - s*.25, cx + s*.16, cy + s*.38,
      cx, cy + s*.16, cx - s*.16, cy + s*.38)
  elseif kind == "DARK" then
    g.circle("fill", cx, cy, s*.40)
    setColor(typeAccentFor(kind)); g.circle("fill", cx + s*.19, cy - s*.10, s*.34)
  elseif kind == "FAIRY" then
    g.polygon("fill", cx, cy - s*.46, cx + s*.12, cy - s*.12,
      cx + s*.43, cy, cx + s*.12, cy + s*.12,
      cx, cy + s*.46, cx - s*.12, cy + s*.12,
      cx - s*.43, cy, cx - s*.12, cy - s*.12)
  else
    g.circle("line", cx, cy, s * .36)
    g.circle("fill", cx, cy, s * .10)
  end
  g.setLineWidth(1)
end

local function drawTypeIcon(kind, x, y, size)
  local accent = typeAccentFor(kind)
  -- A small offset shadow plus a restrained top sheen makes the icon read as
  -- one deliberate card element instead of a loose coloured pixel button.
  -- All dimensions stay in the shared 512x288 logical space, so the same
  -- authored geometry is preserved by desktop and mobile presenters.
  rounded(C.navy2, x + 1, y + 2, size, size,
    math.max(3, size * .22), 0.24)
  rounded(accent, x, y, size, size, math.max(3, size * .22))
  rect(C.white, x + 4, y + 3, math.max(1, size - 8),
    math.max(1, math.floor(size * .08)), 0.18)
  outline(C.navy, x, y, size, size, math.max(3, size * .22),
    size >= 24 and 1.5 or 1, .82)
  drawTypeGlyph(kind, x + size / 2, y + size / 2, size * .66)
end

local function drawTypeBadge(game, mon, x, y, size)
  local kinds = monTypes(game, mon)
  if kinds[2] then
    -- `size` is the single-type reference box, not a total budget to split.
    -- The previous split turned a 30px reference into two 14px mini-buttons.
    -- Two 24px cards now share the same vertical centre as the 30px single
    -- card, matching the clean Crystal single-icon scale without covering the
    -- portrait.  The detail renderer reserves the resulting 50px footprint.
    local dualSize = math.max(16, math.floor(size * .8 + .5))
    local offsetY = math.floor((size - dualSize) / 2)
    local gap = 2
    drawTypeIcon(kinds[1], x, y + offsetY, dualSize)
    drawTypeIcon(kinds[2], x + dualSize + gap, y + offsetY, dualSize)
    return dualSize * 2 + gap, size
  end
  drawTypeIcon(kinds[1], x, y, size)
  return size, size
end

local function spriteMode()
  local options = mod and mod.options
  -- The reviewed 0.5.3 storage skin defaulted to KASC Crystal artwork and
  -- only fell through when the public provider was absent.  VASC does not
  -- expose a duplicate setting, so an unknown/nil value must retain that
  -- contract rather than silently selecting the non-shiny cartridge palette.
  local mode = options and options.get and options:get("sprite_source")
  if mode == nil or mode == "" then return "kasc_crystal" end
  if mode ~= "kasc_crystal" and mode ~= "game" then return "auto" end
  return mode
end

local function kascCrystalPath(game, mon, kind)
  if not (mon and not mon._ascMegaForm and not mon.ascMegaForm) then return nil end
  if type(Gen2CrystalFronts) == "table"
      and type(Gen2CrystalFronts.resolve) == "function" then
    local ok, result = pcall(Gen2CrystalFronts.resolve, game, mon,
      { kind=kind or "summary" })
    if ok and type(result) == "table"
        and type(result.path) == "string" and result.path ~= "" then
      return result.path, result.trueColor ~= false,
        result.source or "vasc_crystal_front"
    end
  end
  if not (mod and type(mod.find) == "function") then return nil end
  local okHandle, handle = pcall(mod.find, "kanto_ascendant")
  if not (okHandle and handle and type(handle.exports) == "table") then return nil end
  local exports = handle.exports
  local ctx = { data = game.data, species = mon.species, mon = mon,
    kind = kind or "summary", source = "vasc_oras_storage_ui" }

  -- Preferred public KASC seam (6.5+ integration builds).
  local provider = exports.crystalSpriteProvider
  if type(provider) == "table" and tonumber(provider.apiVersion) == 1
      and type(provider.resolveFront) == "function" then
    local ok, resolved = pcall(provider.resolveFront, game.data, mon,
      { kind = ctx.kind, source = ctx.source })
    if ok and type(resolved) == "table"
        and type(resolved.path) == "string" and resolved.path ~= "" then
      return resolved.path, resolved.trueColor ~= false, "kasc_crystal"
    end
  end

  -- Backward-compatible bridge for stock Kanto Ascendant 6.5.0, whose
  -- exported static seam is already option-independent.
  local animation = exports.crystalAnimation
  if not (type(animation) == "table"
      and type(animation.staticFrameOne) == "function") then return nil end
  local shiny = false
  local shinySystem = exports.shinySystem
  if type(shinySystem) == "table" and type(shinySystem.isShiny) == "function" then
    local okShiny, value = pcall(shinySystem.isShiny, mon)
    shiny = okShiny and value and true or false
  end
  local ok, path = pcall(animation.staticFrameOne, ctx, "front",
    shiny and "shiny" or "normal")
  if ok and type(path) == "string" and path ~= "" then
    return path, true, "kasc_crystal"
  end
  return nil
end

local function resolveSpritePath(game, mon, kind)
  if not mon then return nil end
  kind = kind or "summary"
  local mode = spriteMode()
  if mode == "kasc_crystal" then
    local path, trueColor, source = kascCrystalPath(game, mon, kind)
    if path then return path, trueColor, source end
  elseif mode == "game" then
    local def = game.data and game.data.pokemon and game.data.pokemon[mon.species]
    if def and type(def.spriteFront) == "string" then
      return def.spriteFront, def.trueColor and true or false, "game"
    end
  end
  local path, trueColor = Sprites.path(game.data, mon.species, "front",
    { mon = mon, kind = kind })
  return path, trueColor, "auto"
end

local function resolveImage(game, mon, kind)
  if not mon then return nil end
  local path, trueColor, source = resolveSpritePath(game, mon, kind)
  if not path then return nil end
  local key = path .. (trueColor and "#true" or "#pal")
    .. "#" .. tostring(source or "auto")
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

-- Standalone Johto-ready Egg art.  It is authored as a tiny raster mask so
-- every Box/Team/Detail/strip surface gets the same crisp sprite without
-- shipping or copying ROM-derived artwork.
local EGG_PIXEL_ROWS = {
  ".......NNN.......",
  ".....NNWWWNN.....",
  "....NWWWHWWWN....",
  "...NWWWHHWWWWN...",
  "..NWWWBBWWWWWWN..",
  "..NWWBBBBWWGWWN..",
  ".NWWWBBWWGGGWWWN.",
  ".NWWWWWWWGGWWWWN.",
  "NWWWWWWWWWWWWWWWN",
  "NWWWWGWWWWBBBWWWN",
  "NWWWGGGWWBBBBWWWN",
  "NWWWWGWWWWBBWWWWN",
  ".NWWWWWWWWWWWWWN.",
  ".NWWWWBBBWWWWWWN.",
  "..NWWBBBBWWWWWN..",
  "..NWWWBBWWWWWNN..",
  "...NWWWWWWWWN....",
  "....NNWWWWWNN....",
  "......NNNNN......",
  ".....SSSSSSS.....",
}

local function eggPixelColor(symbol)
  if symbol == "N" then return C.navy2, 1 end
  if symbol == "W" then return C.cream, 1 end
  if symbol == "H" then return C.white, 1 end
  if symbol == "B" then return C.glassDark, 1 end
  if symbol == "G" then return C.gold, 1 end
  if symbol == "S" then return C.navy2, 0.28 end
end

local function drawEggSprite(x, y, w, h, role)
  local sourceWidth, sourceHeight = 17, #EGG_PIXEL_ROWS
  local scale = math.max(1, math.floor(math.min(
    w / sourceWidth, h / sourceHeight)))
  local outputWidth, outputHeight = sourceWidth * scale, sourceHeight * scale
  local dx = math.floor(x + (w - outputWidth) / 2)
  local dy
  if role == "detail" or role == "team" then
    dy = math.floor(y + h - outputHeight)
  else
    dy = math.floor(y + (h - outputHeight) / 2)
  end
  local g = love.graphics
  for rowIndex, row in ipairs(EGG_PIXEL_ROWS) do
    local column = 1
    while column <= sourceWidth do
      local symbol = row:sub(column, column)
      if symbol == "." then
        column = column + 1
      else
        local first = column
        repeat column = column + 1
        until column > sourceWidth or row:sub(column, column) ~= symbol
        local color, alpha = eggPixelColor(symbol)
        if color then
          setColor(color, alpha)
          g.rectangle("fill", dx + (first - 1) * scale,
            dy + (rowIndex - 1) * scale,
            (column - first) * scale, scale)
        end
      end
    end
  end
end

local function resolveMonPalette(data, mon)
  if type(mon) == "table" then
    if type(mon.palette) == "table" then return mon.palette end
    if mon.palette ~= nil and type(PaletteFX.pal) == "function" then
      local ok, colors = pcall(PaletteFX.pal, data, mon.palette)
      if ok and colors then return colors end
    end
  end
  return PaletteFX.monPal(data, mon and mon.species)
end

local function drawMon(game, mon, x, y, w, h, kind, role)
  if isEgg(mon) then
    drawEggSprite(x, y, w, h, role)
    return
  end
  local resolved = resolveImage(game, mon, kind)
  if not resolved then
    if mon then centeredText("?", x, y + math.floor(h / 2) - 4, w, C.navy) end
    return
  end
  local g, image = love.graphics, resolved.image
  local iw, ih = image:getDimensions()
  local fitScale = math.min(w / math.max(1, iw), h / math.max(1, ih))
  local scale = fitScale
  if resolved.source == "kasc_crystal" then
    if role == "box" then
      -- KASC uses 40/48/56px canvases for art classes. Normalize the selected
      -- grid to one target: 40px in the detailed 5x4 view, 24px in 6x5.
      scale = math.min(fitScale,
        activeBoxLayout().spriteTarget / math.max(1, iw, ih))
    else
      local roleScale = CRYSTAL_ROLE_SCALE[role or ""]
      if roleScale then scale = math.min(fitScale, roleScale) end
    end
  end
  local dx = math.floor(x + (w - iw * scale) / 2)
  local dy
  if resolved.source == "kasc_crystal" and role == "detail" then
    dy = math.floor(y + h - ih * scale)
  else
    dy = math.floor(y + (h - ih * scale) / 2)
  end
  local shader
  if not resolved.trueColor then
    shader = PaletteFX.keyedShader()
    local colors = resolveMonPalette(game.data, mon)
    if shader and colors then PaletteFX.sendColors(shader, colors); g.setShader(shader) end
  end
  setColor(C.white)
  g.draw(image, dx, dy, 0, scale, scale)
  if shader then g.setShader() end
end

local function drawCursor(x, y, w, h, color)
  local g = love.graphics
  color = color or C.orange
  setColor(C.navy2, 0.5)
  g.setLineWidth(3)
  g.rectangle("line", x + 1.5, y + 2.5, w - 3, h - 3, 5, 5)
  setColor(color)
  g.setLineWidth(3)
  local n = 9
  g.line(x, y + n, x, y, x + n, y)
  g.line(x + w - n, y, x + w, y, x + w, y + n)
  g.line(x, y + h - n, x, y + h, x + n, y + h)
  g.line(x + w - n, y + h, x + w, y + h, x + w, y + h - n)
  g.setLineWidth(1)
end

local function isHeldSource(self, kind, index, box)
  local held = self.held
  return held and held.kind == kind and held.index == index
    and (kind ~= "box" or held.box == box)
end

local drawStar

local function glassCell(x, y, w, h, reserve)
  rounded(C.glassDark, x, y, w, h, 5, reserve and 0.5 or 0.9)
  rounded(C.glass, x + 2, y + 2, w - 4, h - 5, 4, reserve and 0.42 or 0.94)
  rect(C.glass2, x + 5, y + 3, w - 10, 3, reserve and 0.35 or 0.82)
  rect(C.white, x + 5, y + 3, 10, 2, reserve and 0.28 or 0.72)
  rect(C.glassDark, x + 3, y + h - 5, w - 6, 3, reserve and 0.38 or 0.62)
  rect(C.white, x + w - 4, y + 7, 1, h - 13, reserve and 0.16 or 0.42)
  outline(C.white, x + 1, y + 1, w - 2, h - 2, 5, 1, reserve and 0.25 or 0.65)
end

local function drawCarriedStar(cx, cy)
  -- Busy Crystal silhouettes can swallow even the exact outlined marker.
  -- Give only the carried marker a tiny paper tab: the star mask itself stays
  -- identical, while its ownership remains legible over any target sprite.
  rounded(C.navy2, cx - 8, cy - 7, 16, 16, 3, 0.35)
  rounded(C.paper, cx - 8, cy - 8, 16, 16, 3, 0.96)
  outline(C.gold, cx - 8, cy - 8, 16, 16, 3, 1, 0.9)
  drawStar(cx, cy, 5, 2)
end

local function drawBoxGrid(self)
  shellPanel(28, 52, 301, 192, 9)
  rounded(C.glass2, 35, 60, 287, 177, 5, 0.75)
  local boxIndex = self.game.save.currentBox
  local layout = activeBoxLayout()
  for index = 1, layout.slots do
    local col = (index - 1) % layout.columns
    local row = math.floor((index - 1) / layout.columns)
    local x = layout.originX + col * layout.stepX
    local y = layout.originY + row * layout.stepY
    local reserve = index > Model.BOX_CAPACITY
    local mon = Model.monAt(self.game.save, "box", index, boxIndex)
    local heldSource = isHeldSource(self, "box", index,
      boxIndex)
    glassCell(x, y, layout.cellWidth, layout.cellHeight, reserve)
    -- Picking a Pokemon up leaves its original seat visibly empty.  The
    -- carried portrait is drawn later at the current cursor, so it can cross
    -- the SELECT boundary into Team without an FRLG-style hand cursor.
    if mon and not heldSource then
      drawMon(self.game, mon,
        x + layout.spriteInsetX, y + layout.spriteInsetY,
        layout.spriteWidth, layout.spriteHeight, "box", "box")
      -- Keep the miniature marker in the clear glass corner instead of over
      -- the sprite's feet/tail, where yellow species could swallow it.
      if isShiny(mon)
          and not (self.held and not self.stripFocus
            and self.boxCursor == index) then
        drawStar(x + layout.markerOffsetX,
          y + layout.markerOffsetY, 4, 1)
      end
    end
    if heldSource then
      rounded(C.gold, x + 2, y + 2,
        layout.cellWidth - 4, layout.cellHeight - 4, 4, 0.23)
      drawCursor(x, y, layout.cellWidth, layout.cellHeight, C.gold)
    end

    if self.held and not self.stripFocus and self.boxCursor == index then
      -- A small shadow and a seven-pixel lift make the moving layer readable
      -- while the occupied target remains underneath for swap decisions.
      setColor(C.navy2, 0.28)
      love.graphics.ellipse("fill",
        x + math.floor(layout.cellWidth / 2),
        y + layout.cellHeight - 4, 14, 3)
      drawMon(self.game, self.held.mon,
        x + layout.spriteInsetX, y + layout.spriteInsetY - 7,
        layout.spriteWidth, layout.spriteHeight, "box", "box")
      if isShiny(self.held.mon) then
        -- The carried marker owns the cell's clear upper-right seat; a shiny
        -- target remains identified by the independent detail-card star.
        drawCarriedStar(x + layout.cellWidth - 9, y + 9)
      end
    end
    if not self.stripFocus and not self.boxHeaderFocus
        and self.boxCursor == index then
      drawCursor(x - 1, y - 1,
        layout.cellWidth + 2, layout.cellHeight + 2, C.orange)
    end
  end
end

local function drawBar(x, y, w, ratio, color, h)
  h = h or 6
  rounded(C.navy2, x, y, w, h, 2)
  rounded(C.cream, x + 1, y + 1, w - 2, h - 2, 1)
  local inner = math.floor((w - 4) * math.max(0, math.min(1, ratio or 0)))
  if inner > 0 then rounded(color or C.green, x + 2, y + 2, inner, h - 4, 1) end
end

local function drawTeamView(self)
  shellPanel(28, 52, 301, 192, 9)
  rounded(C.glass2, 35, 60, 287, 177, 5, 0.72)
  local party = partyFor(self)
  -- Three 58px rows give 56px Crystal fronts their native 1x canvas.  The
  -- former 0.75 scale was the source of the visibly uneven/muddy pixels.
  local ox, oy, cw, ch = 40, 62, 144, 58
  for index = 1, Model.PARTY_CAPACITY do
    local col, row = (index - 1) % 2, math.floor((index - 1) / 2)
    local x, y = ox + col * cw, oy + row * ch
    local mon = party[index]
    local heldSource = isHeldSource(self, "party", index)
    rounded(C.navy, x + 2, y + 3, 138, 55, 6, 0.4)
    rounded(C.paper, x, y, 138, 55, 6)
    rounded(mon and typeAccent(self.game, mon) or C.glassDark,
      x + 3, y + 3, 8, 49, 4, mon and 0.95 or 0.45)
    outline(C.white, x + 1, y + 1, 136, 53, 5, 1, 0.8)
    if mon then
      local egg = isEgg(mon)
      local shiny = isShiny(mon)
      if not heldSource then
        drawMon(self.game, mon, x + 3, y, 56, 56, "summary", "team")
      end
      local nameX = shiny and x + 68 or x + 63
      local cardName = egg and (self.language == "de" and "EI" or "EGG")
        or monName(self.game, mon)
      drawBoldText(fitText(cardName, shiny and 67 or 72),
        nameX, y + 8, C.navy2)
      if egg then
        local progress, remaining = eggProgress(mon)
        drawText(remaining > 0
          and ((self.language == "de" and "%d SCHR." or "%d STEPS")
            :format(remaining))
          or (self.language == "de" and "BALD!" or "SOON!"),
          x + 63, y + 23, C.navy)
        if self.tmhm then
          drawBoldText(self.language == "de" and "NICHT OK" or "NOT OK",
            x + 63, y + 32, C.red)
        end
        drawBar(x + 63, y + 43, 65, progress, C.gold, 6)
      else
        drawText(("Lv.%d"):format(tonumber(mon.level) or 0),
          x + 63, y + 23, C.navy)
        local gender, genderAccent = partyCardGender(
          self.game, mon, cardName)
        if gender then
          -- The real cartridge font advances eight pixels per glyph. Lv.100
          -- therefore ends at x+111; this right-edge seat starts at x+128.
          -- Battle status owns the separate row below, never these pixels.
          drawBoldText(gender, x + 128, y + 23, genderAccent)
        end
        if self.tmhm then
          local canLearn = canLearnMachine(
            self.game and self.game.data, mon, self.tmhm)
          drawBoldText(canLearn and "OK"
            or (self.language == "de" and "NICHT OK" or "NOT OK"),
            x + 63, y + 32, canLearn and C.green or C.red)
        else
          drawBar(x + 63, y + 43, 65, hpRatio(self.game, mon),
            hpRatio(self.game, mon) < 0.25 and C.red or C.green, 6)
        end
      end
      if shiny and not heldSource
          and not (self.held and self.partyCursor == index) then
        drawStar(x + 59, y + 12, 5, 2)
      end
      if not self.tmhm and not egg and isActive(self, mon) then
        outline(C.gold, x, y, 138, 55, 6, 1)
        -- Status sits between the eight-pixel level row and the HP bar.
        -- Keeping it off y+23 also leaves the gender seat collision-free.
        rounded(C.green, x + 105, y + 32, 29, 10, 3)
        centeredText(self.language == "de" and "AKT" or "IN",
          x + 105, y + 33, 29, C.white)
      elseif not egg and (tonumber(mon.hp) or 0) <= 0
          and self.context == "battle" then
        rounded(C.red, x + 3, y + 3, 132, 49, 4, 0.08)
        rightText("K.O.", x + 129, y + 33, C.red)
      end
    else
      setColor(C.glassDark, 0.45)
      love.graphics.circle("line", x + 32, y + 27, 12)
      love.graphics.line(x + 20, y + 27, x + 44, y + 27)
      drawText(self.language == "de" and "LEER" or "EMPTY",
        x + 66, y + 23, C.gray)
    end
    if heldSource then
      rounded(C.gold, x + 2, y + 2, 134, 51, 5, 0.2)
      drawCursor(x, y, 138, 55, C.gold)
    end
    if self.held and self.partyCursor == index then
      setColor(C.navy2, 0.28)
      love.graphics.ellipse("fill", x + 31, y + 49, 16, 3)
      drawMon(self.game, self.held.mon, x + 3, y - 7, 56, 56,
        "summary", "team")
      if isShiny(self.held.mon) then
        drawCarriedStar(x + 52, y + 10)
      end
    end
    if self.partyCursor == index then
      drawCursor(x - 1, y - 1, 140, 57, C.orange)
    end
  end
end

local function selectedTargetMon(self)
  if self.view == "party" or (self.view == "box" and self.stripFocus) then
    local cursor = self.partyCursor
    return partyFor(self)[cursor]
  end
  return Model.monAt(self.game.save, "box", self.boxCursor,
    self.game.save.currentBox)
end

local function selectedMon(self)
  return selectedTargetMon(self) or (self.held and self.held.mon)
end

local function moveActionLabel(self)
  local held = self.held and self.held.mon
  if not held then return nil end
  if self.view == "box" and not self.stripFocus
      and self.boxCursor > Model.BOX_CAPACITY then
    return self.language == "de" and "GESPERRT" or "LOCKED"
  end
  local target = selectedTargetMon(self)
  if target == held then
    return self.language == "de" and "ABBRUCH" or "CANCEL"
  elseif target then
    return self.language == "de" and "TAUSCH" or "SWAP"
  end
  return self.language == "de" and "ABLEGEN" or "DROP"
end

local function displayType(game, mon)
  local def = monDef(game, mon)
  local id = def and def.types and def.types[1]
  return id and TypeChart.displayName(id) or "---"
end

-- Fixed pixel silhouettes model the compact outlined gold star from the
-- supplied reference.  A trigonometric polygon loses its side arms after
-- rounding at Box size and can look like a diamond; these three masks keep a
-- single top point, two wide arms and two separated lower points at every UI
-- size. `N`, `G` and `H` are respectively the closed dark outline, gold fill
-- and cream highlight sampled from that icon; `.` remains transparent.
local SHINY_STAR_MASKS = {
  small = {
    rows = {
      "....N....",
      "...NHN...",
      "...NGN...",
      "NNNGGGNNN",
      ".NGHGGGN.",
      "..NGGGN..",
      "..NGNGN..",
      ".NGN.NGN.",
      ".NN...NN.",
    },
  },
  medium = {
    rows = {
      "......N......",
      ".....NHN.....",
      ".....NGN.....",
      "....NHGGN....",
      "NNNNGHGGGNNNN",
      ".NGGHHGGGGGN.",
      "..NGGGGGGGN..",
      "...NGGGGGN...",
      "...NGGGGGN...",
      "..NGGGNGGGN..",
      "..NGNN.NNGN..",
      ".NGN.....NGN.",
      ".NN.......NN.",
    },
  },
  large = {
    rows = {
      "........N........",
      ".......NHN.......",
      ".......NGN.......",
      "......NHGGN......",
      "......NHGGN......",
      "NNNNNNHGGGGNNNNNN",
      ".NGGGHHGGGGGGGGN.",
      "..NGGGHGGGGGGGN..",
      "...NGGGGGGGGGN...",
      "....NGGGGGGGN....",
      "....NGGGGGGGN....",
      "...NGGGGNGGGGN...",
      "...NGGGN.NGGGN...",
      "..NGGGN...NGGGN..",
      "..NGGN.....NGGN..",
      ".NGGN.......NGGN.",
      ".NNN.........NNN.",
    },
  },
}

for _, mask in pairs(SHINY_STAR_MASKS) do
  mask.height = #mask.rows
  mask.width = #mask.rows[1]
end

local function starMaskPixel(mask, x, y, symbol)
  local row = mask.rows[y]
  return row ~= nil and row:sub(x, x) == symbol
end

local function drawStarMaskRuns(mask, originX, originY, symbol)
  local g = love.graphics
  for y = 1, mask.height do
    local x = 1
    while x <= mask.width do
      if starMaskPixel(mask, x, y, symbol) then
        local from = x
        repeat x = x + 1
        until x > mask.width or not starMaskPixel(mask, x, y, symbol)
        g.rectangle("fill", originX + from - 1, originY + y - 1,
          x - from, 1)
      else
        x = x + 1
      end
    end
  end
end

local function shinyStarMask(outer)
  outer = math.floor((tonumber(outer) or 8) + 0.5)
  if outer <= 4 then return SHINY_STAR_MASKS.small end
  if outer <= 6 then return SHINY_STAR_MASKS.medium end
  return SHINY_STAR_MASKS.large
end

drawStar = function(cx, cy, outer)
  local g = love.graphics
  local mask = shinyStarMask(outer)
  local originX = math.floor(cx + 0.5) - math.floor(mask.width / 2)
  local originY = math.floor(cy + 0.5) - math.floor(mask.height / 2)

  setColor(C.shinyOutline)
  drawStarMaskRuns(mask, originX, originY, "N")
  setColor(C.shinyGold)
  drawStarMaskRuns(mask, originX, originY, "G")
  setColor(C.shinyHighlight)
  drawStarMaskRuns(mask, originX, originY, "H")
end

local function drawPartyMetadata(self, mon, x, y)
  rounded(C.paper, x + 8, y + 147, 135, 40, 3)
  outline(C.navy, x + 8, y + 147, 135, 40, 3, 1)
  local pillX = x + 13
  local available = x + 138 - pillX
  if isEgg(mon) then
    rounded(C.gold, pillX, y + 149, available, 13, 3)
    outline(C.navy, pillX, y + 149, available, 13, 3, 1, 0.65)
    centeredText(self.language == "de" and "POKéMON-EI" or "POKEMON EGG",
      pillX + 2, y + 152, available - 4, C.navy2)
  else
    local types = monTypes(self.game, mon)
    if types[2] then
      local pillWidth = math.floor((available - 3) / 2)
      drawTypePill(types[1], pillX, y + 149, pillWidth, self.language)
      drawTypePill(types[2], pillX + pillWidth + 3, y + 149,
        pillWidth, self.language)
    else
      drawTypePill(types[1], pillX, y + 149, available, self.language)
    end
  end

  local leftX, rightX, fieldWidth = x + 13, x + 78, 60
  rect(C.shellDark, x + 74, y + 164, 1, 20, 0.55)
  drawText(self.language == "de" and "FÄH." or "ABIL.",
    leftX, y + 165, C.navy)
  drawText(self.language == "de" and "GEGENST." or "ITEM",
    rightX, y + 165, C.navy)
  drawBoldText(fitText(abilityName(self.game, mon), fieldWidth),
    leftX, y + 176, C.navy2)
  drawBoldText(fitText(itemName(self.game, mon), fieldWidth),
    rightX, y + 176, C.navy2)
end

local function drawDetail(self)
  local partyDetail = self.view == "party"
  local x, y, w, h = 334, 54, 151, partyDetail and 191 or 148
  shellPanel(x, y, w, h, 7)
  local mon = selectedMon(self)
  local reserved = self.view == "box" and not self.stripFocus
    and self.boxCursor > Model.BOX_CAPACITY
  if not mon then
    drawBoldText(reserved and "RESERVE" or
      (self.language == "de" and "LEER" or "EMPTY"), x + 12, y + 16, C.navy2)
    setColor(C.glassDark, 0.5)
    love.graphics.circle("line", x + 73, y + 68, 22)
    love.graphics.line(x + 51, y + 68, x + 95, y + 68)
    centeredText(reserved and (self.language == "de"
        and "GEN-I: 20 PLÄTZE" or "GEN I: 20 SLOTS") or
      (self.language == "de" and "PLATZ WÄHLEN" or "CHOOSE SLOT"),
      x + 8, y + 103, w - 16, C.gray)
    return
  end

  local egg = isEgg(mon)
  local stats = ensureStats(self.game, mon) or {}
  local shiny = isShiny(mon)
  local displayName = egg and (self.language == "de" and "EI" or "EGG")
    or monName(self.game, mon)
  -- Keep gender and shiny as fixed header badges instead of painting either
  -- over the portrait or level row. Eggs retain the wider private-data title.
  drawBoldText(fitText(displayName, egg and 104 or 82),
    x + 12, y + 13, C.navy2)
  if egg then
    drawText(self.language == "de" and "WIRD AUSGEBRÜTET" or "INCUBATING",
      x + 12, y + 29, C.navy)
  else
    drawText(("Lv. %d"):format(tonumber(mon.level) or 0),
      x + 12, y + 29, C.navy)
  end
  if shiny then
    -- A single unobstructed emblem leaves the full nickname readable.  The
    -- old SHINY word and star occupied the same pixels ("SHIN...").
    drawStar(x + w - 19, y + 18, 8, 3)
  end
  if egg then
    drawEggSprite(x + 13, y + 48, 24, 24, "strip")
  else
    drawTypeBadge(self.game, mon, x + 10, y + 45, 30, self.language)
  end
  local dualType = not egg and monTypes(self.game, mon)[2] ~= nil
  -- A dual badge owns 50px beside the portrait.  Moving only the portrait's
  -- left bound keeps its right and vertical bounds unchanged; 56px Crystal
  -- art therefore remains native-size while neither icon is occluded.
  local portraitX = dualType and x + 64 or x + 45
  drawMon(self.game, mon, portraitX, y + 28, x + 135 - portraitX, 56,
    (self.view == "box" and not self.stripFocus) and "box" or "summary",
    "detail")
  -- Dense Box cells deliberately omit gender, but the selected Pokemon's
  -- roomy detail card is not part of that raster. Keep the same transparent
  -- one-glyph treatment used by Team detail here as requested; no badge or
  -- opaque backing is painted behind it.
  if not egg then
    drawPartyGenderSymbol(self.game, mon, displayName,
      x + w - 48, y + 14)
  end

  rounded(C.paper, x + 8, y + 84, 135, 61, 3)
  outline(C.navy, x + 8, y + 84, 135, 61, 3, 1)
  if egg then
    local progress, remaining = eggProgress(mon)
    drawBoldText(self.language == "de" and "EI-STATUS" or "EGG STATUS",
      x + 14, y + 89, C.navy2)
    drawText(self.language == "de" and "SCHRITTE" or "STEPS",
      x + 14, y + 107, C.navy)
    rightText(("%d"):format(remaining), x + 138, y + 107, C.navy2)
    drawBar(x + 14, y + 118, 124, progress, C.gold, 6)
    centeredText(fitText(mon.eggOrigin
        or (self.language == "de" and "WARM HALTEN" or "KEEP IT WARM"), 120),
      x + 14, y + 131, 124, C.gray)
  else
    local maxHP = math.max(1, tonumber(stats.hp) or 1)
    -- Values get their own text row and every meter gets the same full width.
    -- This avoids squeezing a seven-glyph current/max HP value into the bar.
    drawText(self.language == "de" and "KP" or "HP", x + 14, y + 88, C.navy2)
    local hpValue = ("%d/%d"):format(math.max(0, tonumber(mon.hp) or 0), maxHP)
    rightText(hpValue, x + 138, y + 88, C.navy2)
    drawBar(x + 14, y + 98, 124, (tonumber(mon.hp) or 0) / maxHP,
      hpRatio(self.game, mon) < 0.25 and C.red or C.green, 6)
    drawText(self.language == "de" and "ANG" or "ATK", x + 14, y + 107, C.navy2)
    local attack = tonumber(stats.attack)
    rightText(attack and ("%d"):format(math.max(0, math.floor(attack)))
      or "---", x + 138, y + 107, C.navy2)
    drawBar(x + 14, y + 117, 124,
      math.min(1, math.max(0, attack or 0) / 200), C.orange, 6)
    drawText(self.language == "de" and "VER" or "DEF", x + 14, y + 126, C.navy2)
    local defense = tonumber(stats.defense)
    rightText(defense and ("%d"):format(math.max(0, math.floor(defense)))
      or "---", x + 138, y + 126, C.navy2)
    drawBar(x + 14, y + 136, 124,
      math.min(1, math.max(0, defense or 0) / 200), C.glassDark, 6)
  end

  if partyDetail then
    drawPartyMetadata(self, mon, x, y)
  end
end

local function drawPartyStrip(self)
  local x, y, w, h = 331, 205, 177, 40
  shellPanel(x, y, w, h, 9)
  local party = partyFor(self)
  for index = 1, Model.PARTY_CAPACITY do
    local cellX, cellY = x + 4 + (index - 1) * 28, y + 4
    local mon = party[index]
    local heldSource = isHeldSource(self, "party", index)
    rounded(C.navy2, cellX + 1, cellY + 2, 27, 32, 4, 0.28)
    rounded(C.paper, cellX, cellY, 27, 31, 4)
    outline(C.glassDark, cellX, cellY, 27, 31, 4, 1, 0.65)
    rect(mon and typeAccent(self.game, mon) or C.glassDark,
      cellX + 3, cellY + 27, 21, 2, mon and 0.9 or 0.4)
    local liftedTarget = self.stripFocus and self.held
      and self.partyCursor == index
    if mon and not heldSource and not liftedTarget then
      -- Keep KASC's exact half-scale 20/24/28px Crystal classes for shiny
      -- colour fidelity, but seat them on quiet rectangular cells instead of
      -- saturated circles that swallowed their silhouettes.
      drawMon(self.game, mon, cellX, cellY - 1, 28, 30,
        "summary", "strip")
    else
      setColor(C.cream, 0.8)
      love.graphics.circle("line", cellX + 14, cellY + 14, 7)
      love.graphics.line(cellX + 7, cellY + 14, cellX + 21, cellY + 14)
    end
    if heldSource then
      rounded(C.gold, cellX + 1, cellY + 1, 25, 29, 3, 0.2)
      drawCursor(cellX, cellY, 27, 31, C.gold)
    end
    if self.stripFocus and self.held and self.partyCursor == index then
      setColor(C.navy2, 0.28)
      love.graphics.ellipse("fill", cellX + 14, cellY + 27, 9, 2)
      drawMon(self.game, self.held.mon, cellX, cellY - 5, 28, 30,
        "summary", "strip")
    end
    if self.stripFocus and self.partyCursor == index then
      drawCursor(cellX - 1, cellY - 1, 29, 33, C.orange)
    end
    -- Draw markers last so neither the portrait nor the focus corners can
    -- turn the exact star back into an unreadable coloured speck.
    local marked
    if self.stripFocus and self.held and self.partyCursor == index then
      marked = self.held.mon
    elseif not heldSource then
      marked = mon
    end
    if marked and isShiny(marked) then
      rounded(C.paper, cellX + 15, cellY, 12, 12, 3, 0.96)
      drawStar(cellX + 21, cellY + 6, 4, 1)
    end
  end
  if self.stripFocus then
    -- A whole-panel focus ring makes it unmistakable that the small portraits
    -- are live Team targets rather than a decorative duplicate strip.
    outline(C.orange, x - 1, y - 1, w + 2, h + 2, 10, 2)
  else
    local layout = activeBoxLayout()
    if not self.boxHeaderFocus and self.boxCursor == layout.slots then
      -- Spatial continuation marker: RIGHT from the bottom-right Box slot
      -- enters the immediately adjacent Team strip.
      setColor(C.orange)
      love.graphics.polygon("fill", x - 5, y + 16, x + 1, y + 20,
        x - 5, y + 24)
    end
  end
end

local function drawKey(cx, cy, letter, label)
  setColor(C.navy2, 0.55); love.graphics.circle("fill", cx + 2, cy + 2, 13)
  setColor(C.orange); love.graphics.circle("fill", cx, cy, 13)
  setColor(C.cream); love.graphics.circle("fill", cx, cy, 9)
  outline(C.navy2, cx - 13, cy - 13, 26, 26, 13, 2)
  centeredText(letter, cx - 8, cy - 4, 16, C.navy2)
  drawBoldText(label, cx + 19, cy - 4, C.navy2)
end

local function helperChip(x, y, key, label)
  local keyWidth = textWidth(key) + 8
  rounded(C.navy, x, y, keyWidth, 15, 3)
  centeredText(key, x, y + 4, keyWidth, C.white)
  drawBoldText(label, x + keyWidth + 6, y + 4, C.navy2)
end

local function drawFooter(self)
  local g = love.graphics
  rect(C.navy, 0, 249, P.WIDTH, 39)
  rect(C.orange, 0, 253, P.WIDTH, 32)
  setColor(C.cream)
  g.polygon("fill", 4, 257, 466, 257, 478, 269, 466, 281, 4, 281)
  setColor(C.orange2)
  g.polygon("fill", 466, 257, 512, 257, 512, 285, 466, 285, 480, 271)
  setColor(C.gold, 0.45)
  g.circle("line", 491, 270, 10); g.circle("line", 491, 270, 4)
  g.line(477, 270, 505, 270)

  local function storageHelpers()
    if self.view == "box" and self.boxHeaderFocus then
      helperChip(245, 262, "L/R", "BOX")
    elseif self.view == "box" and self.stripFocus
        and self.partyCursor == 1 then
      helperChip(245, 262, "LEFT", "BOX")
    elseif self.view == "box" and not self.stripFocus
        and self.boxCursor == activeBoxLayout().slots then
      helperChip(245, 262, "RIGHT", "TEAM")
    else
      local selectLabel = self.view == "box"
        and (self.stripFocus and "BOX" or "TEAM") or "BOX"
      helperChip(245, 262, "SELECT", selectLabel)
    end
    helperChip(365, 262, "START", self.language == "de" and "SUCHE" or "SEARCH")
  end

  -- A rejected storage drop intentionally keeps the carried Pokemon so the
  -- player can choose a different target.  The rejection reason must win the
  -- footer for its bounded lifetime; otherwise carry mode hides the only
  -- explanation and makes the failed action look like lost input.
  if self.toast and self.toast.timer > 0 then
    centeredText(fitText(self.toast.text, 355), 55, 266, 355, C.navy2)
    drawKey(440, 269, "B", "")
    return
  end

  if self.held then
    -- Carry mode must remain fully operable after SELECT moves the cursor to
    -- Team.  Keep every relevant action visible here instead of replacing
    -- the Box's useful party navigator with a second information card.
    drawKey(28, 269, "A", self.boxHeaderFocus
      and (self.language == "de" and "RASTER" or "GRID")
      or moveActionLabel(self))
    drawKey(128, 269, "B", self.language == "de" and "ABBRUCH" or "CANCEL")
    storageHelpers()
    return
  end

  if self.context == "battle" then
    drawKey(28, 269, "A", self.language == "de" and "WÄHLEN" or "SELECT")
    drawKey(145, 269, "B", self.language == "de" and "ZURÜCK" or "BACK")
    if self.forceSwitch then
      helperChip(345, 262, "!", self.language == "de" and "WECHSEL" or "SWITCH")
    end
    return
  elseif self.context == "start" then
    drawKey(28, 269, "A", self.language == "de" and "WÄHLEN" or "SELECT")
    drawKey(145, 269, "B", self.language == "de" and "ZURÜCK" or "BACK")
    return
  end
  local idleAction
  if self.boxHeaderFocus then
    idleAction = self.language == "de" and "RASTER" or "GRID"
  elseif selectedTargetMon(self) then
    idleAction = self.language == "de" and "NEHMEN" or "PICK UP"
  else
    idleAction = self.language == "de" and "LEER" or "EMPTY"
  end
  drawKey(28, 269, "A", idleAction)
  drawKey(145, 269, "B", self.boxHeaderFocus
    and (self.language == "de" and "RASTER" or "GRID")
    or (self.language == "de" and "ZURÜCK" or "BACK"))
  storageHelpers()
end

local function partySubmenuState(self)
  if not self.submenu then return nil, nil end
  if type(self.subItems) == "table" then
    return self.subItems, tonumber(self.subIndex) or 1
  end
  -- Gold/Silver/Crystal keeps the native action menu as an object, while the
  -- Gen-I owner exposes the two fields directly.  Presentation must accept
  -- both shapes without moving action/update ownership out of the engine.
  if type(self.submenu) == "table" and type(self.submenu.items) == "table" then
    return self.submenu.items, tonumber(self.submenu.index) or 1
  end
  return nil, nil
end

local function drawPartySubmenu(self)
  local subItems, subIndex = partySubmenuState(self)
  if type(subItems) ~= "table" then return end
  local count = #subItems
  if count == 0 then return end
  local visible = math.min(6, count)
  local first = math.max(1, math.min(
    subIndex - math.floor(visible / 2), count - visible + 1))
  -- Own the complete detail card so no name, type or sprite fragments show
  -- around a short native submenu.  Longer injected menus scroll six rows.
  local x, y, w = 334, 54, 151
  local h = self.view == "party" and 191 or 148
  shellPanel(x, y, w, h, 7)
  local firstRowY = y + math.floor((h - visible * 20) / 2)
  for row = 1, visible do
    local index = first + row - 1
    local entry = subItems[index] or {}
    local label = tostring(entry.label or entry.action or "---")
    if self.language == "de" then
      label = ({
        SWITCH = "WECHSEL",
        STATS = "STATUS",
        CANCEL = "ZURÜCK",
      })[label] or label
    end
    local ry = firstRowY + (row - 1) * 20
    if subIndex == index then
      rounded(C.orange, x + 8, ry - 3, w - 16, 18, 4)
      drawBoldText(fitText(label, w - 37), x + 18, ry + 1, C.navy2)
      setColor(C.gold)
      love.graphics.polygon("fill", x + 12, ry + 5,
        x + 17, ry + 1, x + 17, ry + 9)
    else
      drawBoldText(fitText(label, w - 37), x + 18, ry + 1, C.navy2)
    end
  end
  if first > 1 then drawText("^", x + w - 18, y + 8, C.orange) end
  if first + visible - 1 < count then
    drawText("v", x + w - 18, y + h - 14, C.orange)
  end
end

-- Convert PokemonUi Host Contract v1's immutable descriptors into a private
-- drawing snapshot.  The renderer intentionally receives neither Game nor a
-- live save object: sparse visual seats exist only in this throw-away proxy,
-- while all moves/swaps/saves continue through the authoritative host action
-- dispatcher in PokemonUiGen1Hosts.
local function hostDescriptorMon(descriptor)
  if type(descriptor) ~= "table" then return nil end
  local maxHP = math.max(1,
    tonumber(descriptor.maxHp) or tonumber(descriptor.hp) or 1)
  local mon = {
    species=descriptor.species,
    form=descriptor.form,
    gender=descriptor.gender,
    shiny=descriptor.shiny == true,
    egg=descriptor.egg == true,
    isEgg=descriptor.egg == true,
    nickname=descriptor.nickname,
    level=math.max(0, tonumber(descriptor.level) or 0),
    hp=math.max(0, tonumber(descriptor.hp) or 0),
    status=descriptor.status,
    ability=descriptor.ability,
    item=descriptor.item,
    palette=descriptor.palette,
    types={},
    -- Host v1 exposes immutable presentation-safe calculated values. Preserve
    -- absence as nil so the detail panel shows `---` rather than a fabricated
    -- zero and never reaches back into the authoritative save.
    stats={ hp=maxHP },
    dvs={},
  }
  for _, key in ipairs({ "attack", "defense", "speed", "special" }) do
    local value = tonumber(descriptor[key])
    if value then mon.stats[key] = math.max(0, math.floor(value)) end
  end
  for _, kind in ipairs(type(descriptor.types) == "table"
      and descriptor.types or {}) do
    if type(kind) == "string" and kind ~= "" and #mon.types < 2
        and kind ~= mon.types[1] then
      mon.types[#mon.types + 1] = kind
    end
  end
  return mon
end

local function hostZoneSlots(zone)
  local slots = {}
  for _, entry in ipairs(type(zone) == "table" and zone.entries or {}) do
    local slot = tonumber(entry.slot)
    if slot and slot == math.floor(slot) and slot >= 1 then
      slots[slot] = hostDescriptorMon(entry.pokemon)
    end
  end
  return slots
end

local function hostStorageScreen(model, state)
  if type(model) ~= "table" or model.surface ~= "pc_box" then return nil end
  state = type(state) == "table" and state or {}
  local currentBox = math.max(1, math.floor(tonumber(
    model.surfaceData and model.surfaceData.currentBox) or 1))
  local currentBoxSlots = hostZoneSlots(model.zones and model.zones.box)
  local box = currentBoxSlots
  local party = hostZoneSlots(model.zones and model.zones.party)
  local focus = type(model.focus) == "table" and model.focus or {}
  local stripFocus = focus.zone == "party"
  local boxCursor = stripFocus and tonumber(state.boxCursor)
    or tonumber(focus.slot) or tonumber(state.boxCursor) or 1
  local partyCursor = stripFocus and tonumber(focus.slot)
    or tonumber(state.partyCursor) or 1

  local data = state.data
  if type(data) ~= "table" or type(data.pokemon) ~= "table" then
    data = { pokemon={}, items={} }
  end

  local search = type(model.search) == "table" and model.search or nil
  local searchOpen = state.searchOpen == true
  local searchEditing = searchOpen and state.searchEditing == true
  local searchQuery = search and tostring(search.query or "") or ""
  local searchResults = search and type(search.results) == "table"
    and search.results or {}
  local virtualSearch = searchOpen and searchQuery ~= ""
  if virtualSearch then
    local count = #searchResults
    local selected = count > 0 and math.max(1, math.min(count,
      math.floor(tonumber(state.searchIndex) or 1))) or 0
    local pageStart = selected > 0
      and math.floor((selected - 1) / Model.BOX_CAPACITY) * Model.BOX_CAPACITY + 1
      or 1
    box = {}
    for resultIndex = pageStart,
        math.min(count, pageStart + Model.BOX_CAPACITY - 1) do
      box[#box + 1] = hostDescriptorMon(searchResults[resultIndex].pokemon)
    end
    boxCursor = selected > 0 and selected - pageStart + 1 or 1
    stripFocus = false
  end

  local held
  if type(state.carry) == "table" then
    local kind = state.carry.zone == "party" and "party" or "box"
    local index = math.max(1, math.floor(tonumber(state.carry.slot) or 1))
    local source = kind == "party" and party[index]
      or tonumber(state.carry.box) == currentBox and currentBoxSlots[index] or nil
    held = {
      kind=kind,
      index=index,
      box=kind == "box" and (tonumber(state.carry.box) or currentBox) or nil,
      mon=source or hostDescriptorMon(state.carryPokemon),
    }
    if not held.mon then held = nil end
  end

  local subItems
  if type(state.menuLabels) == "table" then
    subItems = {}
    for _, label in ipairs(state.menuLabels) do
      subItems[#subItems + 1] = { label=tostring(label) }
    end
  end

  local toast
  if type(state.toast) == "table" and type(state.toast.text) == "string"
      and tonumber(state.toast.timer) and tonumber(state.toast.timer) > 0 then
    toast = {
      text=state.toast.text,
      timer=math.min(5, tonumber(state.toast.timer)),
      severity=state.toast.severity,
    }
  end

  return {
    game={ data=data, save={
      currentBox=currentBox,
      boxes={ [currentBox]=box },
      party=party,
    } },
    view="box",
    context="storage",
    language=model.locale == "de" and "de" or "en",
    boxCursor=math.max(1, math.floor(boxCursor)),
    partyCursor=math.max(1, math.floor(partyCursor)),
    stripFocus=stripFocus,
    boxHeaderFocus=state.boxHeaderFocus == true,
    held=held,
    submenu=subItems ~= nil,
    subItems=subItems,
    subIndex=math.max(1, math.floor(tonumber(state.menuIndex) or 1)),
    search=search and {
      active=search.active == true, editing=searchEditing,
      virtual=virtualSearch, composition=state.searchComposition,
      mode=search.mode, query=search.query, results=search.results,
      index=tonumber(state.searchIndex) or 0,
    } or nil,
    toast=toast,
    isOpaque=true,
    letterboxWhite=true,
  }
end

function P.hostStorageScreen(model, state)
  return hostStorageScreen(model, state)
end

function P.drawHostStorage(model, state)
  local screen = hostStorageScreen(model, state)
  if not screen then return false end
  P.draw(screen)
  return true
end

function P.draw(self)
  drawBackground()
  drawHeader(self)
  if self.view == "box" then drawBoxGrid(self) else drawTeamView(self) end
  drawDetail(self)
  -- The six portraits already exist as full cards in Team/Battle views. Keep
  -- this navigator only beside the Box, where it communicates the other
  -- container instead of duplicating the screen's main content.
  if self.view == "box" then
    drawPartyStrip(self)
  end
  drawPartySubmenu(self)
  drawFooter(self)
  setColor(C.white)
end

-- Game2 invokes a widescreen owner directly in physical window coordinates;
-- it does not install the logical 512x288 transform used by the Gen1 UI
-- renderer. Keep P.draw() unchanged for that original path and provide the
-- missing physical presenter only on drawWidescreen(winW, winH).
function P.drawWidescreen(self, winW, winH)
  local G = love and love.graphics
  if not (G and type(G.push) == "function" and type(G.pop) == "function"
      and type(G.translate) == "function" and type(G.scale) == "function") then
    return P.draw(self)
  end
  winW, winH = tonumber(winW), tonumber(winH)
  if not (winW and winH and winW > 0 and winH > 0) then return P.draw(self) end

  local scale = math.min(winW / P.WIDTH, winH / P.HEIGHT)
  local x = math.floor((winW - P.WIDTH * scale) / 2)
  local y = math.floor((winH - P.HEIGHT * scale) / 2)
  G.push("all")
  local ok, err = pcall(function()
    if type(G.origin) == "function" then G.origin() end
    if type(G.setColor) == "function" and type(G.rectangle) == "function" then
      setColor(C.navy2)
      G.rectangle("fill", 0, 0, winW, winH)
    end
    G.translate(x, y)
    G.scale(scale, scale)
    P.draw(self)
  end)
  local okPop, popErr = pcall(G.pop)
  if not ok then error(err, 0) end
  if not okPop then error(popErr, 0) end
end

local function packed(...)
  return { n = select("#", ...), ... }
end

local function unpacked(values)
  return unpack(values, 1, values.n)
end

-- PartyMenu's native list is one-dimensional, while this presentation is a
-- real two-column grid:
--
--     1  2
--     3  4
--     5  6
--
-- Keep the movement policy pure so both engine-backed tests and downstream
-- integrations can verify incomplete parties without constructing a screen.
local function partyGridMove(index, direction, count)
  count = math.max(0, math.floor(tonumber(count) or 0))
  if count == 0 then return 1 end
  index = math.max(1, math.min(count, math.floor(tonumber(index) or 1)))
  local column = (index - 1) % 2

  if direction == "left" then
    return column == 1 and index - 1 or index
  elseif direction == "right" then
    return column == 0 and index + 1 <= count and index + 1 or index
  elseif direction == "up" then
    if index - 2 >= 1 then return index - 2 end
    local last = count
    if (last - 1) % 2 ~= column then last = last - 1 end
    return last >= 1 and last or index
  elseif direction == "down" then
    if index + 2 <= count then return index + 2 end
    local first = column + 1
    return first <= count and first or index
  end
  return index
end

-- Run the untouched native PartyMenu update after masking this frame's grid
-- input.  A/B are masked on a movement frame too, preserving the native
-- priority where a direction never also opens/closes a menu.  Callbacks,
-- submenu logic, item targets and field moves remain entirely native.  The
-- temporary method is restored even if another mod's wrapper raises an error.
local function updatePartyGrid(menu, nativeUpdate, ...)
  local input = menu.game and menu.game.input
  local party = menu.party or (menu.game and menu.game.save
    and menu.game.save.party) or {}
  local direction
  if not menu.submenu and not menu.heal and input
      and type(input.wasPressed) == "function" then
    for _, button in ipairs({ "up", "down", "left", "right" }) do
      if input:wasPressed(button) then
        direction = button
        break
      end
    end
    if direction then
      menu.index = partyGridMove(menu.index, direction, #party)
      -- Gold/Silver/Crystal owns a WRAM-style cursor on the Game instance.
      -- Because this adapter consumes the directional frame before the native
      -- update sees it, explicitly invoke the native cursor receipt when that
      -- host exposes one. Gen-I PartyMenu has no such method, so its behavior
      -- remains unchanged.
      if type(menu.storeCursor) == "function" then menu:storeCursor() end
    end
  end

  -- Host-v1's forced replacement surface never accepts B. The 0.5.3 view
  -- delegates the rest of PartyMenu behavior to the engine, but consumes this
  -- one forbidden frame so a forced picker cannot briefly close/reopen or run
  -- an onCancel callback while the battle is waiting for a valid replacement.
  local forcedCancel = not direction and menu.context == "battle"
    and menu.forceSwitch == true and input
    and type(input.wasPressed) == "function" and input:wasPressed("b")

  if not direction and not forcedCancel then
    return packed(nativeUpdate(menu, ...))
  end

  local previous = rawget(input, "wasPressed")
  local original = input.wasPressed
  input.wasPressed = function(self, button, ...)
    if button == "up" or button == "down"
        or button == "left" or button == "right"
        or button == "a" or button == "b" then
      return false
    end
    return original(self, button, ...)
  end
  local args = packed(...)
  local ok, values = pcall(function()
    return packed(nativeUpdate(menu, unpacked(args)))
  end)
  input.wasPressed = previous
  if not ok then error(values, 0) end
  return values
end

local function releaseFloatingBattleOwner(menu, battle)
  if not battle then return end
  if battle._floatingBattlePartyMenu == menu then
    battle._floatingBattlePartyMenu = nil
  end
  battle._floatingBattlePartyPending = nil
  battle._floatingBattleChoicePartyPending = nil
  menu.__floatingBattleParty = nil
  menu.__floatingBattlePartyClaimed = nil
end

-- Preserve PartyMenu as the sole input/callback authority and replace only
-- the concrete instance's presentation.  This keeps field moves, item target
-- pickers, link-party copies and all battle switch validation in engine code.
function P.decoratePartyMenu(menu, opts)
  if type(menu) ~= "table" then return menu end
  opts = type(opts) == "table" and opts or {}
  local context = opts.context == "battle" and "battle" or "start"
  local battle = opts.battle or menu.battle
  local language = (opts.language == "de" or opts.language == "en")
    and opts.language or activeLanguage(menu.game)

  if menu.__vascOrasPartyDecorated then
    menu.context = context
    menu.language = language
    menu.battle = battle
    releaseFloatingBattleOwner(menu, battle)
    return menu
  end

  menu.__vascOrasPartyDecorated = true
  menu.__vascOrasBattleParty = context == "battle"
  menu.__vascOrasStartParty = context == "start"
  menu.context = context
  menu.language = language
  menu.view = "party"
  menu.partyCursor = tonumber(menu.index) or 1
  menu.battle = battle
  menu.held = nil
  menu.toast = nil
  menu.isOpaque = true
  menu.letterboxWhite = true

  releaseFloatingBattleOwner(menu, battle)

  -- VASC's ORAS HUD recognizes forced replacement pickers by the exact
  -- PartyMenu metatable.  A transparent proxy keeps every native method but
  -- prevents the old compact battle panel from reclaiming this one instance.
  local baseMeta = getmetatable(menu)
  if baseMeta and context == "battle" then
    menu.__vascOrasPartyBaseMeta = baseMeta
    setmetatable(menu, { __index = baseMeta.__index or baseMeta })
  end

  local nativeUpdate = menu.update
  if type(nativeUpdate) == "function" then
    menu.update = function(self, ...)
      local values = updatePartyGrid(self, nativeUpdate, ...)
      -- Gen-II owns switching through switchFrom.  Mirror that native state
      -- into the presenter's carry marker only after update; A/B and the
      -- actual party swap continue to run exclusively in PartyMenu.lua.
      if self.switchFrom then
        self.held = {
          kind="party", index=self.switchFrom,
          mon=type(self.party) == "table" and self.party[self.switchFrom] or nil,
          __vascNativeSwitch=true,
        }
      elseif self.held and self.held.__vascNativeSwitch then
        self.held = nil
      end
      self.partyCursor = tonumber(self.index) or self.partyCursor or 1
      self.isOpaque = true
      releaseFloatingBattleOwner(self, self.battle)
      return unpacked(values)
    end
  end

  menu.uiSize = function() return P.WIDTH, P.HEIGHT end
  menu.isWideBattleLayout = function(self)
    return self.context == "battle"
  end
  menu.sgbPalettes = function()
    return { { colors = false, x = 0, y = 0, w = P.WIDTH, h = P.HEIGHT } }
  end
  menu.drawsWidescreen = function() return true end
  menu.wantsFillScale = function() return true end
  menu.draw = function(self)
    self.partyCursor = tonumber(self.index) or self.partyCursor or 1
    self.isOpaque = true
    releaseFloatingBattleOwner(self, self.battle)
    P.draw(self)
  end
  menu.drawWidescreen = function(self, winW, winH)
    self.partyCursor = tonumber(self.index) or self.partyCursor or 1
    self.isOpaque = true
    releaseFloatingBattleOwner(self, self.battle)
    return P.drawWidescreen(self, winW, winH)
  end
  if MobileMenuPresentation
      and type(MobileMenuPresentation.attach) == "function" then
    MobileMenuPresentation.attach(menu, {
      owner=context == "battle" and "battle_team" or "team",
      logicalW=P.WIDTH,
      logicalH=P.HEIGHT,
      backdrop=C.navy2,
    })
  end
  return menu
end

P.drawBackground = drawBackground
P.activeLanguage = activeLanguage
P.partySubmenuState = partySubmenuState
P.drawTypeGlyphForQa = drawTypeGlyph
P.drawTypeBadgeForQa = drawTypeBadge
P.typeNameForQa = localizedTypeName
P.drawBoxGrid = drawBoxGrid
P.drawTeamView = drawTeamView
P.drawDetail = drawDetail
P.resolveSpritePath = resolveSpritePath
P.partyGridMove = partyGridMove
P.isActive = isActive
P.drawShinyStar = drawStar
P.shinyStarMasks = SHINY_STAR_MASKS
P.boxLayout = BOX_LAYOUTS.detail_20
P.boxLayouts = BOX_LAYOUTS
P.boxGridMode = boxGridMode
P.boxGridSpec = activeBoxLayout
P.abilityName = abilityName
P.itemName = itemName
P.monTypes = monTypes
P.typeAccentFor = function(kind)
  local color = typeAccentFor(kind)
  return { color[1], color[2], color[3], color[4] }
end
P.genderSymbol = function(game, mon)
  local symbol = genderValue(game, mon)
  return symbol
end
P.partyCardGender = partyCardGender
P.resolveMonPalette = resolveMonPalette
P.isEgg = isEgg
P.isShiny = isShiny
P.drawEggSprite = drawEggSprite

return P
