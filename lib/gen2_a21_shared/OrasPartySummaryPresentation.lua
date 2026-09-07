-- 512x288 ORAS-inspired presentation for the native SummaryMenu.
-- Integrated from the reviewed VASC: ORAS Storage UI 0.5.3 presentation.
--
-- This module deliberately keeps the native SummaryMenu authoritative.
-- decorateSummaryMenu() replaces presentation methods on one concrete
-- instance and wraps its captured native/KASC update only to add LEFT/RIGHT
-- page cycling when that update did not already change the page or stack.
-- Native A/B navigation therefore keeps priority, while Kanto Ascendant's
-- existing summary-insights bridge may expose page 3 through the same field.

local V = ... or {}
local mod = V.mod
local sharedPresentation = V.PartyPresentation
if type(sharedPresentation) ~= "table" and type(V.require) == "function" then
  sharedPresentation = V.require("OrasPartyPresentation")
end

local Assets = require("src.render.Assets")
local Font = require("src.render.Font")
local Growth = require("src.pokemon.Growth")
local PaletteFX = require("src.render.PaletteFX")
local Sprites = require("src.pokemon.Sprites")
local Stats = require("src.pokemon.Stats")
local TypeChart = require("src.battle.TypeChart")
local Gen2CrystalFronts = V.require("Gen2CrystalFronts")

local P = {
  WIDTH = 512,
  HEIGHT = 288,
}

local C = {
  navy = { 12 / 255, 37 / 255, 84 / 255 },
  navy2 = { 5 / 255, 24 / 255, 61 / 255 },
  blue = { 23 / 255, 75 / 255, 142 / 255 },
  sky = { 31 / 255, 158 / 255, 219 / 255 },
  skyLight = { 104 / 255, 211 / 255, 242 / 255 },
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
  green = { 45 / 255, 184 / 255, 69 / 255 },
  red = { 234 / 255, 68 / 255, 37 / 255 },
  purple = { 132 / 255, 82 / 255, 187 / 255 },
  yellow = { 244 / 255, 203 / 255, 46 / 255 },
  gray = { 117 / 255, 135 / 255, 148 / 255 },
  white = { 1, 1, 1 },
  black = { 20 / 255, 23 / 255, 25 / 255 },
}

local function validChromeColor(value)
  return type(value) == "table"
    and tonumber(value[1]) ~= nil
    and tonumber(value[2]) ~= nil
    and tonumber(value[3]) ~= nil
end

-- Gen 1 retains the reviewed ORAS orange. Gen 2 may supply an edition-local
-- Gold/Silver/Crystal accent on the concrete SummaryMenu instance, matching
-- the shared Team presenter without creating a second renderer.
local function normalizeChromeAccent(value)
  if type(value) ~= "table" then return nil end
  local primary = value.primary or value
  if not validChromeColor(primary) then return nil end
  local bright = validChromeColor(value.bright) and value.bright or primary
  return primary, bright
end

local LABELS = {
  en = {
    pages = { "STATUS", "MOVES", "TRAINING" },
    hp = "HP", attack = "ATK", defense = "DEF", speed = "SPD",
    special = "SPC", status = "STATUS", type = "TYPE",
    trainer = "TRAINER", id = "ID", exp = "EXP. POINTS",
    next = "TO NEXT LEVEL", pp = "PP", power = "PWR",
    stat = "STAT", dviv = "DV/IV", statexp = "STAT-EXP/EV",
    continue = "CONTINUE", back = "BACK", level = "Lv.",
    none = "---", max = "MAX", page = "PAGE",
  },
  de = {
    pages = { "STATUS", "ATTACKEN", "WERTE" },
    hp = "KP", attack = "ANG", defense = "VER", speed = "INI",
    special = "SPE", status = "STATUS", type = "TYP",
    trainer = "TRAINER", id = "ID", exp = "E.-PUNKTE",
    next = "BIS LEVELAUFSTIEG", pp = "AP", power = "STÄRKE",
    stat = "STAT", dviv = "DV/IV", statexp = "STAT-EP/EV",
    continue = "WEITER", back = "ZURÜCK", level = "Lv.",
    none = "---", max = "MAX", page = "SEITE",
  },
}

local TYPE_DE = {
  NORMAL = "NORMAL", FIGHTING = "KAMPF", FLYING = "FLUG",
  POISON = "GIFT", GROUND = "BODEN", ROCK = "GESTEIN",
  BUG = "KÄFER", GHOST = "GEIST", FIRE = "FEUER", WATER = "WASSER",
  GRASS = "PFLANZE", ELECTRIC = "ELEKTRO", PSYCHIC_TYPE = "PSYCHO",
  ICE = "EIS", DRAGON = "DRACHE",
}

local STATUS = {
  en = {
    OK = "OK", PSN = "POISON", TOX = "POISON", BRN = "BURN",
    PAR = "PARALYSIS", FRZ = "FROZEN", SLP = "ASLEEP", FNT = "FAINTED",
  },
  de = {
    OK = "OK", PSN = "GIFT", TOX = "GIFT", BRN = "BRAND",
    PAR = "PARALYSE", FRZ = "FROST", SLP = "SCHLAF", FNT = "K.O.",
  },
}

local TYPE_COLOR = {
  NORMAL = { 151 / 255, 154 / 255, 137 / 255 },
  FIGHTING = { 191 / 255, 48 / 255, 40 / 255 },
  FLYING = { 135 / 255, 160 / 255, 232 / 255 },
  POISON = { 157 / 255, 72 / 255, 181 / 255 },
  GROUND = { 196 / 255, 151 / 255, 77 / 255 },
  ROCK = { 165 / 255, 138 / 255, 61 / 255 },
  BUG = { 135 / 255, 172 / 255, 49 / 255 },
  GHOST = { 104 / 255, 81 / 255, 139 / 255 },
  FIRE = { 232 / 255, 82 / 255, 40 / 255 },
  WATER = { 65 / 255, 126 / 255, 214 / 255 },
  GRASS = { 73 / 255, 166 / 255, 76 / 255 },
  ELECTRIC = { 232 / 255, 183 / 255, 35 / 255 },
  PSYCHIC_TYPE = { 220 / 255, 83 / 255, 133 / 255 },
  ICE = { 74 / 255, 176 / 255, 196 / 255 },
  DRAGON = { 93 / 255, 75 / 255, 190 / 255 },
}

local imageCache = {}
local solidShader

if type(Assets.register) == "function" then
  Assets.register(function() imageCache = {} end)
end

local function clamp(value, low, high)
  value = tonumber(value) or low
  return math.max(low, math.min(high, value))
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
  value, color, scale = tostring(value or ""), color or C.black, scale or 1
  local shader = shaderFor(color)
  if shader then g.setShader(shader); setColor(C.white) else setColor(color) end
  g.push()
  g.translate(math.floor(x), math.floor(y))
  g.scale(scale, scale)
  Font.draw(value, 0, 0)
  g.pop()
  if shader then g.setShader() end
end

local function textWidth(value, scale)
  return Font.width(tostring(value or "")) * (scale or 1)
end

local function fitText(value, width, scale)
  value, scale = tostring(value or ""), scale or 1
  if textWidth(value, scale) <= width then return value end
  local spans = Font.split(value)
  local budget = math.max(0, math.floor(width / scale) - Font.width("."))
  local count = Font.spansFitting(spans, budget)
  local out = {}
  for index = 1, count do
    out[#out + 1] = value:sub(spans[index].from, spans[index].to)
  end
  return table.concat(out) .. "."
end

local function centeredText(value, x, y, w, color, scale)
  drawText(value, x + math.floor((w - textWidth(value, scale)) / 2), y,
    color, scale)
end

local function rightText(value, right, y, color, scale)
  drawText(value, right - textWidth(value, scale), y, color, scale)
end

local function shellPanel(x, y, w, h, radius)
  radius = radius or 8
  rounded(C.navy2, x + 3, y + 3, w, h, radius, 0.55)
  rounded(C.shellDark, x, y, w, h, radius)
  rounded(C.cream, x + 2, y + 2, w - 4, h - 4, radius - 1)
  rounded(C.white, x + 5, y + 5, w - 10, h - 10, radius - 2)
  outline(C.navy, x, y, w, h, radius, 2)
  outline(C.shellDark, x + 4, y + 4, w - 8, h - 8,
    math.max(1, radius - 2), 1, 0.82)
end

local function glassPanel(x, y, w, h, radius)
  rounded(C.glassDark, x, y, w, h, radius or 5, 0.92)
  rounded(C.glass2, x + 2, y + 2, w - 4, h - 4,
    math.max(1, (radius or 5) - 1), 0.96)
  rect(C.white, x + 5, y + 3, math.max(1, w - 10), 2, 0.68)
  outline(C.white, x + 1, y + 1, w - 2, h - 2, radius or 5, 1, 0.66)
end

local function drawBackdrop()
  local g = love.graphics
  for y = 0, 250, 5 do
    local t = y / 250
    setColor({
      C.sky[1] * (1 - t) + C.skyLight[1] * t,
      C.sky[2] * (1 - t) + C.skyLight[2] * t,
      C.sky[3] * (1 - t) + C.skyLight[3] * t,
    })
    g.rectangle("fill", 0, y, P.WIDTH, 5)
  end

  -- Crisp cloud bank and a restrained Hoenn circuit motif remain visible in
  -- the gutters without competing with the information panels.
  setColor(C.white, 0.82)
  g.ellipse("fill", 48, 48, 41, 18)
  g.ellipse("fill", 84, 45, 34, 15)
  g.ellipse("fill", 460, 60, 47, 19)
  rect(C.cream, 0, 59, 125, 5, 0.54)
  rect(C.cream, 401, 72, 111, 5, 0.47)

  setColor(C.glass2, 0.25)
  g.setLineWidth(2)
  g.line(386, 5, 430, 5, 430, 17, 456, 17, 456, 29)
  g.line(403, 27, 444, 27, 444, 39, 485, 39, 485, 52)
  g.rectangle("line", 469.5, 2.5, 15, 10)
  g.circle("line", 486, 53, 4)
  g.setLineWidth(1)

  rect(C.blue, 0, 232, P.WIDTH, 20, 0.35)
  setColor(C.white, 0.35)
  for x = -12, 512, 42 do g.line(x, 240, x + 20, 236) end
end

local function languageOf(screen)
  local direct = screen and (screen.language or screen.__vascOrasLanguage)
  if direct == "de" or direct == "en" then return direct end
  if type(V.language) == "function" then
    local ok, value = pcall(V.language, screen and screen.game)
    if ok and (value == "de" or value == "en") then return value end
  elseif V.language == "de" or V.language == "en" then
    return V.language
  end
  if mod and type(mod.find) == "function" then
    local ok, ascendant = pcall(mod.find, "kanto_ascendant")
    local fn = ok and ascendant and ascendant.exports and ascendant.exports.language
    if type(fn) == "function" then
      local called, value = pcall(fn)
      if called and (value == "de" or value == "en") then return value end
    end
    for _, id in ipairs({ "translation-german-universal", "deutsch",
        "deutsch-blau", "deutsch-gelb" }) do
      local found, handle = pcall(mod.find, id)
      if found and handle then return "de" end
    end
  end
  return "en"
end

local function labelsFor(screen)
  local language = languageOf(screen)
  return LABELS[language], language
end

local function monDef(screen)
  local game, mon = screen.game, screen.mon
  return game and game.data and game.data.pokemon
    and game.data.pokemon[mon and mon.species] or {}
end

local function isEgg(mon)
  if type(mon) ~= "table" then return false end
  if type(sharedPresentation) == "table"
      and type(sharedPresentation.isEgg) == "function" then
    local ok, value = pcall(sharedPresentation.isEgg, mon)
    if ok then return value and true or false end
  end
  if mon.isEgg == true or mon.egg == true or mon.is_egg == true then
    return true
  end
  if tostring(mon.status or ""):upper() == "EGG" then return true end
  local species = tostring(mon.species or ""):upper()
  return species == "EGG" or species == "POKEMON_EGG"
end

local function monName(screen)
  local mon, def = screen.mon or {}, monDef(screen)
  if isEgg(mon) then return languageOf(screen) == "de" and "EI" or "EGG" end
  return mon.nickname or def.name or mon.species or "---"
end

local function ensureStats(screen)
  local mon, def = screen.mon, monDef(screen)
  if isEgg(mon) then return mon and mon.stats or {} end
  if mon and def then pcall(Stats.ensure, def, mon) end
  return mon and mon.stats or {}
end

local function isShiny(mon)
  if type(mon) ~= "table" then return false end
  if isEgg(mon) then return false end
  if type(V.isShiny) == "function" then
    local ok, value = pcall(V.isShiny, mon)
    if ok then return value and true or false end
  end
  if type(sharedPresentation) == "table"
      and type(sharedPresentation.isShiny) == "function" then
    local ok, value = pcall(sharedPresentation.isShiny, mon)
    if ok then return value and true or false end
  end
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

local function spriteMode()
  local options = mod and mod.options
  local mode = options and type(options.get) == "function"
    and options:get("sprite_source") or "kasc_crystal"
  if mode ~= "kasc_crystal" and mode ~= "game" and mode ~= "auto" then
    return "kasc_crystal"
  end
  return mode
end

local function kascCrystalPath(game, mon, kind)
  if not (game and mon and not mon._ascMegaForm and not mon.ascMegaForm) then
    return nil
  end
  if type(Gen2CrystalFronts) == "table"
      and type(Gen2CrystalFronts.resolve) == "function" then
    local ok, result = pcall(Gen2CrystalFronts.resolve, game, mon,
      { kind=kind or "summary" })
    if ok and type(result) == "table" and type(result.path) == "string" then
      return result.path, true, result.source
    end
  end
  if not (mod and type(mod.find) == "function") then return nil end
  local okHandle, handle = pcall(mod.find, "kanto_ascendant")
  if not (okHandle and handle and type(handle.exports) == "table") then return nil end
  local exports = handle.exports
  local provider = exports.crystalSpriteProvider
  if type(provider) == "table" and tonumber(provider.apiVersion) == 1
      and type(provider.resolveFront) == "function" then
    local ok, resolved = pcall(provider.resolveFront, game.data, mon, {
      kind = kind or "summary", source = "vasc_oras_storage_ui.summary",
    })
    if ok and type(resolved) == "table"
        and type(resolved.path) == "string" and resolved.path ~= "" then
      return resolved.path, resolved.trueColor ~= false,
        resolved.source or "kasc_crystal"
    end
  end

  -- Compatibility with the public static seam shipped before provider/v1.
  local animation = exports.crystalAnimation
  if not (type(animation) == "table"
      and type(animation.staticFrameOne) == "function") then return nil end
  local context = {
    data = game.data, species = mon.species, mon = mon,
    kind = kind or "summary", source = "vasc_oras_storage_ui.summary",
  }
  local variant = isShiny(mon) and "shiny" or "normal"
  local ok, path = pcall(animation.staticFrameOne,
    context, "front", variant)
  if ok and type(path) == "string" and path ~= "" then
    return path, true, "kasc_crystal"
  end
  return nil
end

local function injectedResolver()
  if type(V.resolveSpritePath) == "function" then return V.resolveSpritePath end
  if type(sharedPresentation) == "table"
      and type(sharedPresentation.resolveSpritePath) == "function" then
    return sharedPresentation.resolveSpritePath
  end
end

local function resolveSpritePath(game, mon, kind)
  if not (game and mon) then return nil end
  if isEgg(mon) then return nil end
  kind = kind or "summary"

  -- Reuse the storage presentation's public resolver whenever integration
  -- supplies it.  This keeps option semantics and future providers in one
  -- place instead of binding SummaryMenu to KASC internals.
  local resolver = injectedResolver()
  if resolver then
    local ok, path, trueColor, source = pcall(resolver, game, mon, kind)
    if ok and type(path) == "string" and path ~= "" then
      return path, trueColor and true or false, source or "shared"
    end
  end

  local mode = spriteMode()
  if mode == "kasc_crystal" then
    local path, trueColor, source = kascCrystalPath(game, mon, kind)
    if path then return path, trueColor, source end
  elseif mode == "game" then
    local def = game.data and game.data.pokemon
      and game.data.pokemon[mon.species]
    if def and type(def.spriteFront) == "string" then
      return def.spriteFront, def.trueColor and true or false, "game"
    end
  end

  local path, trueColor = Sprites.path(game.data, mon.species, "front", {
    mon = mon, kind = kind,
  })
  return path, trueColor and true or false, "auto"
end

local function resolveImage(game, mon)
  local path, trueColor, source = resolveSpritePath(game, mon, "summary")
  if not path then return nil end
  local key = table.concat({ path, trueColor and "true" or "pal",
    tostring(source or "auto") }, "#")
  if imageCache[key] == nil then
    local ok, image = pcall(Assets.image, path)
    if ok and image and type(image.setFilter) == "function" then
      pcall(image.setFilter, image, "nearest", "nearest")
    end
    imageCache[key] = ok and image and {
      image = image, trueColor = trueColor, source = source,
    } or false
  end
  return imageCache[key] or nil
end

local function drawMon(screen, x, y, w, h)
  if isEgg(screen.mon) and type(sharedPresentation) == "table"
      and type(sharedPresentation.drawEggSprite) == "function" then
    sharedPresentation.drawEggSprite(x, y, w, h, "detail")
    return
  end
  local resolved = resolveImage(screen.game, screen.mon)
  if not resolved then
    centeredText("?", x, y + math.floor(h / 2) - 8, w, C.navy, 2)
    return
  end
  local g, image = love.graphics, resolved.image
  local iw, ih = image:getDimensions()
  local fit = math.min(w / math.max(1, iw), h / math.max(1, ih))
  local scale
  if fit >= 1 then
    -- Whole-number sprite pixels survive both the 512x288 canvas and the
    -- renderer's final integer window scale.  KASC Crystal fronts stay at
    -- their authored 40/48/56px scale, as in the storage detail card.
    scale = resolved.source == "kasc_crystal" and 1
      or math.max(1, math.min(2, math.floor(fit)))
  else
    scale = fit
  end
  local dx = math.floor(x + (w - iw * scale) / 2)
  local dy = math.floor(y + h - ih * scale)
  local shader
  if not resolved.trueColor then
    shader = PaletteFX.keyedShader()
    local data = screen.game.data
    local colors
    if data and data.gen2Palettes then
      local ok, Palettes = pcall(require, "src.world.gen2.Palettes")
      if ok and Palettes and type(Palettes.monColors) == "function" then
        colors = Palettes.monColors(data.gen2Palettes, screen.mon.species,
          screen.mon.shiny and true or false)
      end
    end
    colors = colors or PaletteFX.monPal(data, screen.mon.species)
    if shader and colors then
      PaletteFX.sendColors(shader, colors)
      g.setShader(shader)
    else
      shader = nil
    end
  end
  setColor(C.white)
  g.draw(image, dx, dy, 0, scale, scale)
  if shader then g.setShader() end
end

local function typeIdFor(screen, index)
  local def = monDef(screen)
  return def.types and def.types[index or 1]
end

local function typeName(typeId, language)
  if not typeId then return "---" end
  if language == "de" and TYPE_DE[typeId] then return TYPE_DE[typeId] end
  return TypeChart.displayName(typeId) or typeId
end

local function drawTypeBadge(typeId, language, x, y, w)
  local color = TYPE_COLOR[typeId] or C.gray
  rounded(C.navy2, x + 1, y + 1, w, 16, 4, 0.34)
  rounded(color, x, y, w, 16, 4)
  outline(C.navy, x, y, w, 16, 4, 1, 0.74)
  centeredText(fitText(typeName(typeId, language), w - 8),
    x, y + 4, w, typeId == "ELECTRIC" and C.navy2 or C.white)
end

local FALLBACK_SHINY_STAR = {
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
}

local function fallbackStarPixel(rows, x, y, symbol)
  local row = rows[y]
  return row ~= nil and row:sub(x, x) == symbol
end

local function drawFallbackStarRuns(rows, originX, originY, symbol)
  for y = 1, #rows do
    local x = 1
    while x <= #rows[y] do
      if fallbackStarPixel(rows, x, y, symbol) then
        local from = x
        repeat x = x + 1
        until x > #rows[y] or not fallbackStarPixel(rows, x, y, symbol)
        love.graphics.rectangle("fill", originX + from - 1,
          originY + y - 1, x - from, 1)
      else
        x = x + 1
      end
    end
  end
end

local function drawShinyStar(cx, cy, outer, inner)
  -- Use the exact same exported marker as Box/Party whenever the summary is
  -- integrated normally.  The local fallback keeps this presentation usable
  -- by renderer harnesses without creating a second visual language.
  if type(sharedPresentation) == "table"
      and type(sharedPresentation.drawShinyStar) == "function" then
    return sharedPresentation.drawShinyStar(cx, cy, outer, inner)
  end
  local width, height = #FALLBACK_SHINY_STAR[1], #FALLBACK_SHINY_STAR
  local originX = math.floor(cx + 0.5) - math.floor(width / 2)
  local originY = math.floor(cy + 0.5) - math.floor(height / 2)
  setColor(C.shinyOutline)
  drawFallbackStarRuns(FALLBACK_SHINY_STAR, originX, originY, "N")
  setColor(C.shinyGold)
  drawFallbackStarRuns(FALLBACK_SHINY_STAR, originX, originY, "G")
  setColor(C.shinyHighlight)
  drawFallbackStarRuns(FALLBACK_SHINY_STAR, originX, originY, "H")
end

local function drawBar(x, y, w, ratio, color, height)
  height = height or 7
  ratio = clamp(ratio, 0, 1)
  rounded(C.navy2, x, y, w, height, 2)
  rounded(C.paper, x + 2, y + 2, w - 4, height - 4, 1)
  local fill = math.floor((w - 4) * ratio)
  if fill > 0 then rounded(color or C.green, x + 2, y + 2,
    fill, height - 4, 1) end
end

local function pageCount(screen)
  if isEgg(screen and screen.mon) then return 2 end
  if tonumber(screen.__vascOrasPageCount) then
    return clamp(screen.__vascOrasPageCount, 2, 3)
  end
  local ok, SummaryMenu = pcall(require, "src.ui.SummaryMenu")
  local bridge = ok and SummaryMenu and SummaryMenu._ascendantInsightsBridge
  if bridge and type(bridge.valuesMode) == "function" then
    local called, mode = pcall(bridge.valuesMode, screen.game)
    if called and mode ~= nil and mode ~= "off" then return 3 end
  end
  return tonumber(screen.page) == 3 and 3 or 2
end

local function pageOf(screen)
  return clamp(math.floor(tonumber(screen.page) or 1), 1, 3)
end

local function drawHeader(screen, labels)
  local page, count = pageOf(screen), pageCount(screen)
  local g = love.graphics

  setColor(C.navy2, 0.45)
  g.polygon("fill", 142, 21, 158, 10, 353, 10, 369, 21)
  setColor(C.orange2)
  g.polygon("fill", 136, 20, 155, 7, 354, 7, 374, 20)
  setColor(C.gold, 0.92)
  g.polygon("fill", 158, 9, 347, 9, 356, 15, 167, 15)

  rounded(C.navy2, 91, 20, 330, 37, 10, 0.55)
  rounded(C.orange, 88, 17, 330, 37, 10)
  rounded(C.cream, 91, 20, 324, 31, 8)
  rounded(C.navy, 95, 24, 316, 23, 6)
  for y = 27, 44, 4 do rect(C.blue, 99, y, 308, 1, 0.25) end
  outline(C.blue, 98, 26, 310, 19, 5, 1, 0.82)

  setColor(C.gold)
  g.polygon("fill", 108, 35, 119, 27, 119, 43)
  g.polygon("fill", 398, 35, 387, 27, 387, 43)
  centeredText(labels.pages[page] or labels.pages[1],
    125, 28, 256, C.white, 2)

  rounded(C.paper, 430, 25, 61, 20, 5, 0.95)
  outline(C.navy, 430, 25, 61, 20, 5, 1)
  centeredText(("%d/%d"):format(page, count), 430, 31, 61, C.navy2)
end

local function displayStatus(mon, language)
  local status = tostring(mon.status or ((tonumber(mon.hp) or 0) <= 0 and "FNT") or "OK")
  return (STATUS[language] and STATUS[language][status]) or status
end

local function eggProgress(mon)
  local remaining = math.max(0, tonumber(mon and
    (mon.eggStepsRemaining or mon.eggSteps)) or 0)
  local total = math.max(1, tonumber(mon and
    (mon.eggTotalSteps or mon.eggTotal)) or remaining or 1)
  return clamp((total - remaining) / total, 0, 1), remaining, total
end

local function drawEggIdentity(screen, language)
  local mon = screen.mon
  shellPanel(20, 56, 176, 188, 8)
  rounded(C.paper, 27, 63, 162, 174, 5)
  drawText(language == "de" and "EI" or "EGG", 32, 68, C.navy2)
  drawText(language == "de" and "WIRD AUSGEBRÜTET" or "BEING HATCHED",
    32, 83, C.navy)
  glassPanel(32, 96, 152, 91, 5)
  drawMon(screen, 47, 99, 122, 83)
  rounded(C.gold, 43, 193, 130, 17, 4)
  outline(C.navy, 43, 193, 130, 17, 4, 1, 0.65)
  centeredText(language == "de" and "POKéMON-EI" or "POKEMON EGG",
    45, 198, 126, C.navy2)
  drawText(language == "de" and "INHALT" or "CONTENTS", 32, 218, C.gray)
  rightText(language == "de" and "GEHEIM" or "UNKNOWN", 181, 218, C.navy2)
end

local function drawEggPage(screen, language)
  local mon, page = screen.mon, pageOf(screen)
  local progress, remaining, total = eggProgress(mon)
  shellPanel(204, 56, 288, 188, 8)
  rounded(C.paper, 211, 63, 274, 174, 5)
  rounded(C.navy, 216, 67, 264, 20, 4)
  drawText(page == 1
      and (language == "de" and "EI-STATUS" or "EGG STATUS")
      or (language == "de" and "PFLEGE" or "CARE"),
    225, 73, C.white)

  if page == 1 then
    drawText(language == "de" and "SCHRITTE" or "STEPS", 225, 101, C.gray)
    rightText(tostring(remaining), 470, 101, C.navy2)
    drawBar(225, 119, 245, progress, C.gold, 9)
    drawText(language == "de" and "FORTSCHRITT" or "PROGRESS",
      225, 138, C.gray)
    rightText(("%d/100"):format(math.floor(progress * 100 + 0.5)),
      470, 138, C.navy2)
    centeredText(language == "de"
        and "DAS EI MUSS NOCH GETRAGEN WERDEN."
        or "KEEP THE EGG IN YOUR PARTY.",
      220, 172, 256, C.navy2)
    centeredText((language == "de" and "GESAMT: %d" or "TOTAL: %d")
        :format(total), 220, 194, 256, C.gray)
  else
    drawText(language == "de" and "FUNDORT" or "ORIGIN", 225, 101, C.gray)
    drawText(fitText(mon.eggOrigin or (language == "de"
        and "UNBEKANNT" or "UNKNOWN"), 245), 225, 118, C.navy2)
    rect(C.glassDark, 225, 139, 245, 1, 0.6)
    centeredText(language == "de"
        and "WELCHES POKéMON SCHLÜPFT,"
        or "THE POKEMON INSIDE",
      220, 158, 256, C.navy2)
    centeredText(language == "de"
        and "BLEIBT BIS DAHIN GEHEIM."
        or "STAYS SECRET UNTIL HATCHING.",
      220, 177, 256, C.navy2)
  end
end

local function drawIdentity(screen, labels, language)
  local mon, def, stats = screen.mon, monDef(screen), ensureStats(screen)
  shellPanel(20, 56, 176, 188, 8)
  rounded(C.paper, 27, 63, 162, 174, 5)

  local nameWidth = isShiny(mon) and 126 or 148
  drawText(fitText(monName(screen), nameWidth), 32, 68, C.navy2)
  if isShiny(mon) then drawShinyStar(174, 72, 8, 3) end
  drawText(("%s %d"):format(labels.level, tonumber(mon.level) or 0),
    32, 83, C.navy)
  rightText(("No.%03d"):format(tonumber(def.dex) or 0), 184, 83, C.navy)

  glassPanel(32, 96, 152, 78, 5)
  rect(TYPE_COLOR[typeIdFor(screen, 1)] or C.blue, 36, 100, 7, 70, 3, 0.92)
  drawMon(screen, 47, 100, 131, 69)

  local type1, type2 = typeIdFor(screen, 1), typeIdFor(screen, 2)
  if type2 and type2 ~= type1 then
    drawTypeBadge(type1, language, 32, 179, 72)
    drawTypeBadge(type2, language, 109, 179, 72)
  else
    drawTypeBadge(type1, language, 55, 179, 104)
  end

  local status = displayStatus(mon, language)
  drawText(labels.status, 32, 201, C.gray)
  local statusColor = status == "OK" and C.green or C.red
  rightText(fitText(status, 80), 181, 201, statusColor)

  local trainer = mon.ot or (screen.game.save and screen.game.save.player
    and screen.game.save.player.name) or "RED"
  local trainerId = tonumber(mon.otId) or (screen.game.save and screen.game.save.player
    and tonumber(screen.game.save.player.id)) or 0
  drawText(labels.trainer, 32, 216, C.gray)
  rightText(fitText(trainer, 72), 181, 216, C.navy2)
  drawText(labels.id, 32, 228, C.gray)
  rightText(("%05d"):format(trainerId), 181, 228, C.navy2)
end

local function statRows(labels, mon, stats)
  return {
    { labels.hp, tonumber(mon.hp) or 0, tonumber(stats.hp) or 1, "hp" },
    { labels.attack, tonumber(stats.attack) or 0, nil, "attack" },
    { labels.defense, tonumber(stats.defense) or 0, nil, "defense" },
    { labels.speed, tonumber(stats.speed) or 0, nil, "speed" },
    { labels.special, tonumber(stats.special) or 0, nil, "special" },
  }
end

local function drawStatsPage(screen, labels)
  local mon, stats = screen.mon, ensureStats(screen)
  shellPanel(204, 56, 288, 188, 8)
  rounded(C.paper, 211, 63, 274, 174, 5)
  rounded(C.navy, 216, 67, 264, 20, 4)
  drawText(labels.pages[1], 225, 73, C.white)
  rightText(("%d/%d"):format(tonumber(mon.hp) or 0,
    math.max(1, tonumber(stats.hp) or 1)), 472, 73, C.white)

  local rows = statRows(labels, mon, stats)
  local statMax = math.max(1, tonumber(stats.attack) or 0,
    tonumber(stats.defense) or 0, tonumber(stats.speed) or 0,
    tonumber(stats.special) or 0)
  for index, row in ipairs(rows) do
    local y = 92 + (index - 1) * 28
    if index % 2 == 0 then rounded(C.glass2, 216, y - 2, 264, 25, 3, 0.62) end
    rounded(TYPE_COLOR[typeIdFor(screen, 1)] or C.blue,
      219, y + 2, 4, 18, 2, 0.86)
    drawText(row[1], 231, y + 6, C.navy2)
    local ratio
    if row[4] == "hp" then
      ratio = row[2] / math.max(1, row[3])
    else
      ratio = row[2] / statMax
    end
    local color = row[4] == "hp" and (ratio < 0.25 and C.red or C.green)
      or C.glassDark
    drawBar(281, y + 9, 125, ratio, color, 8)
    if row[3] then
      rightText(("%d/%d"):format(row[2], row[3]), 470, y + 6, C.navy2)
    else
      rightText(tostring(row[2]), 470, y + 6, C.navy2)
    end
  end
end

local function expProgress(screen, def)
  local mon = screen.mon
  if (tonumber(mon.level) or 1) >= 100 then return 1, 0, 0 end
  local level = math.max(1, tonumber(mon.level) or 1)
  local current = math.max(0, tonumber(mon.exp) or 0)
  local okBase, base = pcall(Growth.expForLevel, def.growthRate, level)
  local okNext, nextAt = pcall(Growth.expForLevel, def.growthRate, level + 1)
  base = okBase and tonumber(base) or current
  nextAt = okNext and tonumber(nextAt) or current
  local span = math.max(1, nextAt - base)
  return clamp((current - base) / span, 0, 1), math.max(0, nextAt - current), nextAt
end

local function drawMoveRow(screen, labels, language, index, x, y, w)
  local move = screen.mon.moves and screen.mon.moves[index]
  local mdef = move and screen.game.data.moves and screen.game.data.moves[move.id]
  local typeId = mdef and mdef.type
  local accent = TYPE_COLOR[typeId] or C.gray
  rounded(C.navy2, x + 2, y + 2, w, 28, 5, 0.34)
  rounded(C.paper, x, y, w, 28, 5)
  rounded(accent, x + 3, y + 3, 6, 22, 3)
  outline(C.glassDark, x, y, w, 28, 5, 1, 0.75)
  if not (move and mdef) then
    drawText("-", x + 17, y + 9, C.gray)
    rightText("--", x + w - 10, y + 9, C.gray)
    return
  end

  drawText(fitText(mdef.name or move.id, 122), x + 17, y + 5, C.navy2)
  drawText(fitText(typeName(typeId, language), 74), x + 17, y + 16, accent)
  local pp = math.max(0, tonumber(move.pp) or 0)
  local maxPP = math.max(1, tonumber(mdef.pp) or 1)
  drawText(labels.pp, x + 172, y + 5, C.gray)
  rightText(("%d/%d"):format(pp, maxPP), x + w - 10, y + 5, C.navy2)
  drawBar(x + 172, y + 18, 82, pp / maxPP,
    pp <= math.max(1, math.floor(maxPP / 4)) and C.red or C.orange2, 6)
end

local function drawMovesPage(screen, labels, language)
  local mon, def = screen.mon, monDef(screen)
  shellPanel(204, 56, 288, 188, 8)
  rounded(C.paper, 211, 63, 274, 174, 5)

  local progress, nextExp = expProgress(screen, def)
  rounded(C.navy, 216, 67, 264, 37, 4)
  drawText(labels.exp, 225, 72, C.white)
  rightText(tostring(math.max(0, tonumber(mon.exp) or 0)), 470, 72, C.white)
  drawText(labels.next, 225, 87, C.glass2)
  rightText((tonumber(mon.level) or 1) >= 100 and labels.max or tostring(nextExp),
    470, 87, C.glass2)
  drawBar(216, 107, 264, progress, C.gold, 7)

  for index = 1, 4 do
    drawMoveRow(screen, labels, language, index,
      216, 119 + (index - 1) * 29, 264)
  end
end

local VALUE_ROWS = {
  { "hp", "hp" }, { "attack", "attack" }, { "defense", "defense" },
  { "speed", "speed" }, { "special", "special" },
}

local function derivedHPDV(dvs)
  if tonumber(dvs.hp) then return clamp(math.floor(dvs.hp), 0, 15) end
  return ((tonumber(dvs.attack) or 0) % 2) * 8
    + ((tonumber(dvs.defense) or 0) % 2) * 4
    + ((tonumber(dvs.speed) or 0) % 2) * 2
    + ((tonumber(dvs.special) or 0) % 2)
end

local function drawValuesPage(screen, labels)
  local mon, dvs, statExp = screen.mon, screen.mon.dvs or {}, screen.mon.statExp or {}
  shellPanel(204, 56, 288, 188, 8)
  rounded(C.paper, 211, 63, 274, 174, 5)
  rounded(C.navy, 216, 67, 264, 20, 4)
  drawText(labels.stat, 225, 73, C.white)
  centeredText(labels.dviv, 270, 73, 85, C.white)
  rightText(labels.statexp, 470, 73, C.white)

  local display = {
    hp = labels.hp, attack = labels.attack, defense = labels.defense,
    speed = labels.speed, special = labels.special,
  }
  for index, row in ipairs(VALUE_ROWS) do
    local key = row[2]
    local y = 92 + (index - 1) * 28
    if index % 2 == 0 then rounded(C.glass2, 216, y - 2, 264, 25, 3, 0.62) end
    local dv = key == "hp" and derivedHPDV(dvs)
      or clamp(math.floor(tonumber(dvs[key]) or 0), 0, 15)
    local exp = clamp(math.floor(tonumber(statExp[key]) or 0), 0, 65535)
    rounded((isShiny(mon) and dv == 10) and C.gold or C.glassDark,
      219, y + 2, 4, 18, 2, 0.9)
    drawText(display[key], 231, y + 6, C.navy2)
    centeredText(("%d/15"):format(dv), 270, y + 6, 85, C.navy2)
    rightText(tostring(exp), 470, y + 2, C.navy2)
    drawBar(362, y + 15, 108, exp / 65535, C.orange2, 6)
  end
end

local function drawKey(x, y, key, label, color)
  color = color or C.orange
  rounded(C.navy2, x + 2, y + 2, 30, 22, 6, 0.52)
  rounded(color, x, y, 30, 22, 6)
  outline(C.navy, x, y, 30, 22, 6, 2)
  centeredText(key, x, y + 5, 30, C.white)
  drawText(label, x + 38, y + 6, C.navy2)
end

local function drawFooter(screen, labels)
  local page, count = pageOf(screen), pageCount(screen)
  rect(C.navy2, 0, 249, 512, 39)
  rect(C.orange, 4, 252, 504, 33)
  rounded(C.cream, 8, 255, 496, 27, 3)
  local action = page < count and labels.continue or labels.back
  drawKey(20, 258, "A", action, C.orange2)
  drawKey(151, 258, "B", action, C.orange)

  drawText(labels.page, 345, 264, C.gray)
  for index = 1, count do
    local x = 416 + (index - 1) * 22
    setColor(index == page and C.orange or C.glassDark)
    love.graphics.circle("fill", x, 269, 7)
    setColor(C.navy)
    love.graphics.circle("line", x, 269, 7)
    if index == page then
      setColor(C.paper)
      love.graphics.circle("fill", x, 269, 2)
    end
  end
end

local function drawPresentation(screen)
  if type(screen) ~= "table" or type(screen.mon) ~= "table"
      or type(screen.game) ~= "table" then return end
  local labels, language = labelsFor(screen)
  drawBackdrop()
  if isEgg(screen.mon) then
    local eggLabels = {}
    for key, value in pairs(labels) do eggLabels[key] = value end
    eggLabels.pages = language == "de"
      and { "EI-STATUS", "PFLEGE" } or { "EGG STATUS", "CARE" }
    drawHeader(screen, eggLabels)
    drawEggIdentity(screen, language)
    drawEggPage(screen, language)
    drawFooter(screen, eggLabels)
    if type(PaletteFX.markTrueColor) == "function" then
      PaletteFX.markTrueColor(0, 0, P.WIDTH, P.HEIGHT)
    end
    love.graphics.setShader()
    setColor(C.white)
    return
  end
  drawHeader(screen, labels)
  drawIdentity(screen, labels, language)
  local page = pageOf(screen)
  if page == 1 then
    drawStatsPage(screen, labels)
  elseif page == 2 then
    drawMovesPage(screen, labels, language)
  else
    drawValuesPage(screen, labels)
  end
  drawFooter(screen, labels)
  if type(PaletteFX.markTrueColor) == "function" then
    PaletteFX.markTrueColor(0, 0, P.WIDTH, P.HEIGHT)
  end
  love.graphics.setShader()
  setColor(C.white)
end

function P.draw(screen)
  local primary, bright = normalizeChromeAccent(
    type(screen) == "table" and screen.__vascOrasSummaryChromeAccent or nil)
  if not primary then return drawPresentation(screen) end

  local nativeOrange, nativeOrange2 = C.orange, C.orange2
  C.orange, C.orange2 = primary, bright
  local ok, err = pcall(drawPresentation, screen)
  C.orange, C.orange2 = nativeOrange, nativeOrange2
  if not ok then error(err, 0) end
end

-- Game2 calls widescreen owners in physical window coordinates.  Match the
-- reviewed Team presenter: keep the authored 512x288 pixels intact, scale by
-- a whole number where possible and centre them over a navy letterbox.  The
-- plain draw() path remains unchanged for Gen 1's logical UI canvas.
function P.drawWidescreen(screen, winW, winH)
  local G = love and love.graphics
  if not (G and type(G.push) == "function" and type(G.pop) == "function"
      and type(G.translate) == "function" and type(G.scale) == "function") then
    return P.draw(screen)
  end
  winW, winH = tonumber(winW), tonumber(winH)
  if not (winW and winH and winW > 0 and winH > 0) then
    return P.draw(screen)
  end

  local scale = math.min(winW / P.WIDTH, winH / P.HEIGHT)
  if scale >= 1 then scale = math.max(1, math.floor(scale)) end
  local x = math.floor((winW - P.WIDTH * scale) / 2)
  local y = math.floor((winH - P.HEIGHT * scale) / 2)
  G.push("all")
  local ok, err = pcall(function()
    if type(G.origin) == "function" then G.origin() end
    setColor(C.navy2)
    G.rectangle("fill", 0, 0, winW, winH)
    G.translate(x, y)
    G.scale(scale, scale)
    P.draw(screen)
  end)
  local okPop, popErr = pcall(G.pop)
  if not ok then error(err, 0) end
  if not okPop then error(popErr, 0) end
end

local unpacked = table.unpack or unpack

local function packed(...)
  return { n = select("#", ...), ... }
end

local function stackContains(screen)
  local states = screen and screen.game and screen.game.stack
    and screen.game.stack.states
  if type(states) ~= "table" then return false, false end
  for index = #states, 1, -1 do
    if states[index] == screen then return true, true end
  end
  return true, false
end

-- Decorate one already-created native SummaryMenu.  Keeping this instance
-- level is important: the captured native/KASC update remains authoritative
-- for A/B, page 3 and stack navigation.  The small wrapper below acts only
-- when that update left both the page and stack membership unchanged, then
-- adds the ORAS header's LEFT/RIGHT page carousel.
function P.decorateSummaryMenu(menu, opts)
  if type(menu) ~= "table" then return menu end
  opts = type(opts) == "table" and opts or {}
  if opts.language == "de" or opts.language == "en" then
    menu.language = opts.language
    menu.__vascOrasLanguage = opts.language
  end
  if tonumber(opts.pageCount) then
    menu.__vascOrasPageCount = clamp(opts.pageCount, 2, 3)
  end
  if normalizeChromeAccent(opts.chromeAccent) then
    menu.__vascOrasSummaryChromeAccent = opts.chromeAccent
  end
  if isEgg(menu.mon) then menu.__vascOrasPageCount = 2 end
  menu.__vascOrasSummaryDecorated = true
  menu.isOpaque = true
  menu.letterboxWhite = true
  menu.uiSize = function() return P.WIDTH, P.HEIGHT end
  menu.sgbPalettes = function()
    return { { colors = false, x = 0, y = 0, w = P.WIDTH, h = P.HEIGHT } }
  end
  menu.drawsWidescreen = function() return true end
  -- Summary may be pushed while the wide ORAS BattleState remains directly
  -- below it.  Advertise ownership of the same 512px battle canvas so Game
  -- does not center this instance as a legacy 160px overlay.
  menu.isWideBattleLayout = function() return true end
  menu.wantsFillScale = function() return true end
  menu.draw = function(self) return P.draw(self) end
  menu.drawWidescreen = function(self, winW, winH)
    return P.drawWidescreen(self, winW, winH)
  end
  if isEgg(menu.mon) then
    -- KASC intentionally keeps its future species in the Egg record.  A
    -- dedicated two-page update avoids its optional values page and never
    -- invokes any native drawing/sound path that could reveal that species.
    menu.__vascOrasSummaryDirectionalUpdate = true
    menu.update = function(self)
      local input = self.game and self.game.input
      if not (input and type(input.wasPressed) == "function") then return end
      if input:wasPressed("a") or input:wasPressed("b") then
        if pageOf(self) == 1 then self.page = 2 else self.game.stack:pop() end
      elseif input:wasPressed("left") then
        self.page = pageOf(self) == 1 and 2 or 1
      elseif input:wasPressed("right") then
        self.page = pageOf(self) == 2 and 1 or 2
      end
    end
  elseif not menu.__vascOrasSummaryDirectionalUpdate
      and type(menu.update) == "function" then
    local nativeUpdate = menu.update
    menu.__vascOrasNativeUpdate = nativeUpdate
    menu.__vascOrasSummaryDirectionalUpdate = true
    menu.update = function(self, ...)
      local pageBefore = pageOf(self)
      local hadStack, wasOnStack = stackContains(self)
      local values = packed(nativeUpdate(self, ...))

      -- Native A/B either advances a page or pops the state.  In both cases
      -- it wins this frame, including an unlikely simultaneous direction.
      if pageOf(self) ~= pageBefore then
        return unpacked(values, 1, values.n)
      end
      if hadStack and wasOnStack then
        local _, stillOnStack = stackContains(self)
        if not stillOnStack then return unpacked(values, 1, values.n) end
      end

      local input = self.game and self.game.input
      if input and type(input.wasPressed) == "function" then
        local direction
        if input:wasPressed("left") then
          direction = -1
        elseif input:wasPressed("right") then
          direction = 1
        end
        if direction then
          local count = pageCount(self)
          local page = pageOf(self)
          self.page = ((page - 1 + direction) % count) + 1
        end
      end
      return unpacked(values, 1, values.n)
    end
  end
  return menu
end

P.pageCount = pageCount
P.resolveSpritePath = resolveSpritePath
P.isShiny = isShiny
P.isEgg = isEgg

return P
