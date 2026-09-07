-- Shared full-surface title/main-menu presentation for all six cartridges.
--
-- Generation adapters provide only a disposable view model.  This module
-- never owns title navigation, save loading, options, callbacks or input.

local V = ... or {}
local mod = V.mod
local M = {
  apiVersion=1,
  schema="vasc.shared.title-menu-presentation/v1",
  width=512,
  height=288,
}

local Font = require("src.render.Font")
local okAssets, Assets = pcall(require, "src.render.Assets")
if not okAssets then Assets = nil end
local okSprites, Sprites = pcall(require, "src.pokemon.Sprites")
if not okSprites then Sprites = nil end
-- Red/Blue/Yellow used to bypass the clean menu-front catalogue that Crystal
-- already consumes, so their four title-card Pokemon could come from mixed
-- low-resolution engine sources.  Reuse that optional read-only resolver for
-- Gen 1 only; it never owns battle animation and every missing entry still
-- falls through to the live engine and packaged follower art below.
local CrystalFronts
if type(V.require) == "function" then
  local ok, value = pcall(V.require, "Gen2CrystalFronts")
  if ok and type(value) == "table" then CrystalFronts = value end
end
local solidTextShader
local imageCache = {}
local TITLE_ART_MAX_BYTES = 8 * 1024 * 1024

local PALETTES = {
  red={label="ROT", accent={0.90,0.20,0.18}, glow={1.00,0.48,0.34},
    dark={0.16,0.025,0.035}, panel={0.25,0.045,0.055}},
  blue={label="BLAU", accent={0.16,0.45,0.92}, glow={0.25,0.78,1.00},
    dark={0.02,0.06,0.16}, panel={0.035,0.105,0.25}},
  yellow={label="GELB", accent={0.98,0.76,0.08}, glow={1.00,0.92,0.32},
    dark={0.13,0.095,0.015}, panel={0.22,0.16,0.025}},
  gold={label="GOLD", accent={0.78,0.56,0.12}, glow={1.00,0.78,0.27},
    dark={0.12,0.075,0.018}, panel={0.22,0.14,0.035}},
  silver={label="SILBER", accent={0.58,0.65,0.74}, glow={0.85,0.91,0.98},
    dark={0.055,0.07,0.10}, panel={0.11,0.14,0.19}},
  crystal={label="KRISTALL", accent={0.16,0.72,0.80}, glow={0.48,0.95,1.00},
    dark={0.015,0.075,0.12}, panel={0.025,0.14,0.20}},
}
local ORDER = {"red", "blue", "yellow", "gold", "silver", "crystal"}
local WHITE = {0.97,0.99,1.00}
local PAPER = {1.00,0.985,0.92}
local INK = {0.025,0.055,0.12}

-- Optional transparent title art. Pokémon resolve through the live engine
-- seam first, so active edition/mod replacements stay authoritative. The
-- small packaged follower frame is only a fallback. Every image may fail
-- independently without blocking the title menu.
local ART = {
  gen1={
    pokemon={
      {"CHARIZARD", "assets/enhanced_overworld/poke_followers/follower_006_normal.png"},
      {"VENUSAUR", "assets/enhanced_overworld/poke_followers/follower_003_normal.png"},
      {"BLASTOISE", "assets/enhanced_overworld/poke_followers/follower_009_normal.png"},
      {"PIKACHU", "assets/enhanced_overworld/poke_followers/follower_025_normal.png"},
    },
    heroes={
      "assets/ui/title_hub/gen1/red_front_hd.png",
      "assets/ui/title_hub/gen1/green_front_hd.png",
      "assets/ui/title_hub/gen1/blue_front_hd.png",
    },
  },
  gen2={
    pokemon={
      {"LUGIA", "assets/enhanced_overworld/poke_followers/follower_249_normal.png"},
      {"HO_OH", "assets/enhanced_overworld/poke_followers/follower_250_normal.png"},
      {"SUICUNE", "assets/enhanced_overworld/poke_followers/follower_245_normal.png"},
      {"CELEBI", "assets/enhanced_overworld/poke_followers/follower_251_normal.png"},
    },
    heroes={
      "assets/trainers/gen2/players/gold_front_hd.png",
      "assets/trainers/gen2/players/kris_front_hd.png",
      "assets/trainers/gen2/players/silver_front_hd.png",
    },
  },
}

local function normalizedEdition(value)
  value = tostring(value or ""):lower()
    :gsub("pokémon", "pokemon"):gsub("pokemon", "")
    :gsub("version", ""):gsub("edition", "")
    :gsub("[%s_%-]", "")
  for _, id in ipairs(ORDER) do if value == id then return id end end
  return "red"
end

function M.palette(value)
  local id = normalizedEdition(value)
  return PALETTES[id], id
end

local function setColor(color, alpha)
  love.graphics.setColor(color[1], color[2], color[3], alpha or color[4] or 1)
end

local function rounded(color, x, y, width, height, radius, alpha)
  setColor(color, alpha)
  love.graphics.rectangle("fill", x, y, width, height, radius, radius)
end

local function outline(color, x, y, width, height, radius, lineWidth)
  setColor(color)
  love.graphics.setLineWidth(lineWidth or 1)
  love.graphics.rectangle("line", x + .5, y + .5, width - 1, height - 1,
    radius, radius)
  love.graphics.setLineWidth(1)
end

local function shaderFor(color)
  local g = love.graphics
  if type(g.newShader) ~= "function" or type(g.setShader) ~= "function" then
    return nil
  end
  if solidTextShader == nil then
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
  if not solidTextShader then return nil end
  local ok = pcall(solidTextShader.send, solidTextShader, "ink", {
    color[1], color[2], color[3], color[4] or 1,
  })
  if not ok then solidTextShader = false return nil end
  return solidTextShader
end

local function drawText(value, x, y, color, scale)
  local g = love.graphics
  value, color, scale = tostring(value or ""), color or WHITE, scale or 1
  local previous
  if type(g.getShader) == "function" then
    local ok, shader = pcall(g.getShader)
    if ok then previous = shader end
  end
  local shader = shaderFor(color)
  if shader then g.setShader(shader); setColor(WHITE) else setColor(color) end
  g.push()
  g.translate(math.floor(x), math.floor(y))
  g.scale(scale, scale)
  Font.draw(value, 0, 0)
  g.pop()
  if shader then
    if previous ~= nil then g.setShader(previous) else g.setShader() end
  end
end

local function width(value, scale)
  if type(Font.width) == "function" then
    local ok, result = pcall(Font.width, tostring(value or ""))
    if ok and tonumber(result) then return result * (scale or 1) end
  end
  return #tostring(value or "") * 8 * (scale or 1)
end

local function fit(value, maxWidth, scale)
  value, scale = tostring(value or ""), scale or 1
  if width(value, scale) <= maxWidth then return value end
  while #value > 1 and width(value .. "…", scale) > maxWidth do
    value = value:sub(1, -2)
  end
  return value .. "…"
end

local function language(spec)
  return spec.language == "en" and "en" or "de"
end

local LABELS = {
  de={
    CONTINUE="WEITER", ["NEW GAME"]="NEUES SPIEL", OPTION="OPTIONEN",
    OPTIONS="OPTIONEN", ["EXIT GAME"]="SPIEL BEENDEN", QUIT="SPIEL BEENDEN",
    BADGES="ORDEN", ["PLAY TIME"]="SPIELZEIT",
  },
  en={
    CONTINUE="CONTINUE", ["NEW GAME"]="NEW GAME", OPTION="OPTIONS",
    OPTIONS="OPTIONS", ["EXIT GAME"]="EXIT GAME", QUIT="EXIT GAME",
    WEITER="CONTINUE", ["NEUES SPIEL"]="NEW GAME", OPTIONEN="OPTIONS",
    ["SPIEL BEENDEN"]="EXIT GAME",
    ORDEN="BADGES", SPIELZEIT="PLAY TIME",
  },
}

local HELP = {
  de={
    WEITER="Lädt deinen Spielstand.",
    ["NEUES SPIEL"]="Beginnt ein neues Abenteuer.",
    OPTIONEN="Öffnet die Spieloptionen.",
    ["SPIEL BEENDEN"]="Beendet das Spiel sicher.",
    TRAINER="Aktiver Trainer dieses Spielstands.",
    ORDEN="Bisher erhaltene Orden.",
    ["POKéDEX"]="Bisher gefangene Pokémon.",
    SPIELZEIT="Gesamte Spielzeit dieses Spielstands.",
  },
  en={
    CONTINUE="Continue your save.",
    ["NEW GAME"]="Begin a new adventure.",
    OPTIONS="Open the game options.",
    ["EXIT GAME"]="Exit the game safely.",
    TRAINER="The active trainer for this save file.",
    BADGES="Badges earned so far.",
    ["POKéDEX"]="Pokémon caught so far.",
    ["PLAY TIME"]="Total play time for this save file.",
  },
}

local function clean(value)
  return tostring(value or ""):gsub("<PO><KE>", "POKé")
    :gsub("<PK><MN>", "POKéMON"):gsub("%s+", " ")
    :gsub("^%s+", ""):gsub("%s+$", "")
end

function M.label(value, lang)
  lang = lang == "en" and "en" or "de"
  local original = clean(value)
  return LABELS[lang][original:upper()] or original
end

local function pokeball(x, y, palette, radius)
  local g = love.graphics
  radius = radius or 14
  local lineWidth = radius <= 7 and 1 or 3
  local buttonRadius = math.max(2, math.floor(radius * .36))
  setColor(PAPER); g.circle("fill", x, y, radius)
  setColor(palette.accent); g.arc("fill", "open", x, y, radius,
    math.pi, math.pi * 2)
  setColor(INK); g.setLineWidth(lineWidth); g.circle("line", x, y, radius)
  g.line(x - radius + 1, y, x + radius - 1, y)
  setColor(PAPER); g.circle("fill", x, y, buttonRadius)
  setColor(INK); g.circle("line", x, y, buttonRadius); g.setLineWidth(1)
end

local function assetPath(relative)
  local assets = mod and mod.assets
  if not (assets and type(assets.path) == "function") then return relative end
  local ok, path = pcall(assets.path, assets, relative)
  if not ok then ok, path = pcall(assets.path, relative) end
  return ok and type(path) == "string" and path ~= "" and path or relative
end

local function filtered(image)
  if image and type(image.setFilter) == "function" then
    pcall(image.setFilter, image, "nearest", "nearest")
  end
  return image
end

local function callAsset(method, assets, ...)
  local ok, result = pcall(method, assets, ...)
  if not ok then ok, result = pcall(method, ...) end
  return ok and result or nil
end

local function imageAt(path)
  if type(path) ~= "string" or path == "" then return nil end
  if imageCache[path] ~= nil then return imageCache[path] or nil end
  local g = love and love.graphics
  if not (g and type(g.newImage) == "function") then
    imageCache[path] = false
    return nil
  end
  local ok, image
  if Assets and type(Assets.image) == "function" then
    ok, image = pcall(Assets.image, path)
  end
  if not ok or not image then ok, image = pcall(g.newImage, path) end
  imageCache[path] = ok and filtered(image) or false
  return imageCache[path] or nil
end

-- Packaged title art belongs to this mod, not to the engine's generated
-- asset namespace.  Ask the bounded mod facade for an Image first.  This is
-- important for installed ZIPs: mod.assets:path() returns a virtual mod path
-- and may look like an absolute host path in development, neither of which is
-- a portable filename for love.graphics.newImage().
--
-- Older compatible hosts expose read/path but not image.  In that case make
-- a FileData from the facade's bounded byte read and hand that to LÖVE.  No
-- io/open or host filesystem access is used by production code.  A final
-- path attempt retains the previous fail-open behaviour for legacy engines.
local function packagedImage(relative)
  if type(relative) ~= "string" or relative == "" then return nil end
  local key = "packaged:" .. relative
  if imageCache[key] ~= nil then return imageCache[key] or nil end
  local g = love and love.graphics
  if not (g and type(g.newImage) == "function") then
    imageCache[key] = false
    return nil
  end

  local assets = mod and mod.assets
  local image
  if assets and type(assets.image) == "function" then
    image = callAsset(assets.image, assets, relative)
  end

  if not image and assets and type(assets.read) == "function" then
    local payload = callAsset(assets.read, assets, relative,
      TITLE_ART_MAX_BYTES)
    local fs = love and love.filesystem
    if type(payload) == "string" and #payload > 0
        and #payload <= TITLE_ART_MAX_BYTES and fs
        and type(fs.newFileData) == "function" then
      local filename = relative:match("([^/]+)$") or "title-art.png"
      local okData, fileData = pcall(fs.newFileData, payload, filename)
      if okData and fileData then
        local okImage, decoded = pcall(g.newImage, fileData)
        if okImage then image = decoded end
      end
    end
  end

  if not image then image = imageAt(assetPath(relative)) end
  imageCache[key] = filtered(image) or false
  return imageCache[key] or nil
end

local function imageDimensions(image)
  if not image then return nil, nil end
  local okW, iw = pcall(image.getWidth, image)
  local okH, ih = pcall(image.getHeight, image)
  if okW and okH and tonumber(iw) and tonumber(ih) and iw > 0 and ih > 0 then
    return iw, ih
  end
end

local function pokemonEntry(spec, row, preferCrystalFront)
  local image
  local game = type(spec.game) == "table" and spec.game or nil
  if preferCrystalFront and game and type(CrystalFronts) == "table"
      and type(CrystalFronts.resolve) == "function" then
    local ok, result = pcall(CrystalFronts.resolve, game,
      {species=row[1]}, {kind="title", shiny=false})
    if ok and type(result) == "table"
        and type(result.path) == "string" and result.path ~= "" then
      -- The shared resolver returns a mod-qualified path for the native menu
      -- presenters.  TitleHub also runs before the world from an installed
      -- ZIP, so decode the matching relative member through the bounded asset
      -- facade when possible instead of assuming host-path visibility.
      local relative = result.path:match(
        "(assets/crystal_fronts/[^/]+/%d+%.png)$")
      image = relative and packagedImage(relative) or imageAt(result.path)
      if image then
        return {image=image, source=result.source or "vasc_crystal_front",
          path=result.path, relative=relative}
      end
    end
  end
  if Sprites and type(Sprites.path) == "function" and game
      and type(game.data) == "table" then
    local ok, path = pcall(Sprites.path, game.data, row[1], "front", {
      kind="title", generation=spec.generation,
    })
    if ok and path then image = imageAt(path) end
  end
  if image then return {image=image, source="game"} end
  image = packagedImage(row[2])
  local iw, ih = imageDimensions(image)
  local g = love and love.graphics
  if image and iw and ih and ih >= iw and g and type(g.newQuad) == "function" then
    local ok, quad = pcall(g.newQuad, 0, 0, iw, iw, iw, ih)
    if ok and quad then
      return {image=image, quad=quad, width=iw, height=iw,
        source="packaged"}
    end
  end
end

local function heroEntry(path)
  local image = packagedImage(path)
  return image and {image=image} or nil
end

local function artworkEntries(spec, edition)
  if spec.showArtwork == false then
    return {pokemon={}, heroes={}}, 0
  end
  local family = (edition == "gold" or edition == "silver"
    or edition == "crystal") and ART.gen2 or ART.gen1
  local preferCrystalFront = family == ART.gen1
  local entries = {pokemon={}, heroes={}}
  for _, row in ipairs(family.pokemon) do
    local entry = pokemonEntry(spec, row, preferCrystalFront)
    if entry then entries.pokemon[#entries.pokemon + 1] = entry end
  end
  for _, path in ipairs(family.heroes) do
    local entry = heroEntry(path)
    if entry then entries.heroes[#entries.heroes + 1] = entry end
  end
  return entries, #entries.pokemon + #entries.heroes
end

local function drawContained(entry, centerX, centerY, box)
  local g = love.graphics
  local iw, ih = entry.width, entry.height
  if not iw then iw, ih = imageDimensions(entry.image) end
  if not (iw and ih and type(g.draw) == "function") then return false end
  local scale = math.min(box / iw, box / ih)
  local x, y = centerX - iw * scale / 2, centerY - ih * scale / 2
  setColor(WHITE)
  if entry.quad then g.draw(entry.image, entry.quad, x, y, 0, scale, scale)
  else g.draw(entry.image, x, y, 0, scale, scale) end
  return true
end

local function drawArtwork(entries)
  local pokemonX = {347, 382, 417, 452}
  local heroX = {365, 401, 437}
  local drawn = 0
  for index, entry in ipairs(entries.pokemon) do
    if drawContained(entry, pokemonX[index] or 452, 170, 26) then
      drawn = drawn + 1
    end
  end
  for index, entry in ipairs(entries.heroes) do
    if drawContained(entry, heroX[index] or 437, 189, 34) then
      drawn = drawn + 1
    end
  end
  return drawn
end

local function drawLogical(spec)
  local g = love and love.graphics
  if not (g and type(g.rectangle) == "function" and type(g.push) == "function"
      and type(g.circle) == "function" and type(g.arc) == "function"
      and type(g.line) == "function" and type(Font.draw) == "function") then
    return false, "title-hub-renderer-unavailable"
  end
  local palette, edition = M.palette(spec.edition)
  local lang = language(spec)
  if type(g.setShader) == "function" then g.setShader() end
  if type(g.setScissor) == "function" then g.setScissor() end

  rounded(palette.dark, 0, 0, M.width, M.height, 0)
  rounded(palette.panel, 12, 10, 488, 268, 12)
  outline(palette.glow, 12, 10, 488, 268, 12, 3)
  outline(palette.accent, 17, 15, 478, 258, 9, 1)

  rounded(palette.accent, 24, 21, 464, 39, 8)
  rounded(palette.dark, 29, 26, 454, 29, 6)
  pokeball(47, 40, palette)
  drawText(lang == "de" and "SPIEL STARTEN" or "START GAME",
    70, 29, WHITE, 2)
  local editionLabel = (lang == "de" and palette.label) or edition:upper()
  local right = "VOXEL ASCENDANT / " .. editionLabel
  drawText(right, 474 - width(right, 1), 37, palette.glow, 1)

  rounded(palette.dark, 24, 69, 286, 166, 8)
  outline(palette.glow, 24, 69, 286, 166, 8, 2)
  rounded(PAPER, 316, 69, 172, 166, 8)
  outline(palette.accent, 316, 69, 172, 166, 8, 2)

  local items = type(spec.items) == "table" and spec.items or {}
  local selected = math.max(1, math.min(#items > 0 and #items or 1,
    math.floor(tonumber(spec.index) or 1)))
  for index, item in ipairs(items) do
    item = type(item) == "table" and item or {label=item}
    local label = M.label(item.label or item.value, lang)
    local y = 80 + (index - 1) * 36
    if index == selected then
      rounded(palette.accent, 32, y, 270, 30, 5)
      outline(palette.glow, 32, y, 270, 30, 5, 1)
      pokeball(45, y + 15, palette, 6)
    else
      rounded(palette.panel, 32, y, 270, 30, 5, .78)
    end
    drawText(fit(label, 220, 2), 60, y + 3, WHITE, 2)
    if item.right ~= nil then
      local right = fit(item.right, 72, 1)
      drawText(right, 294 - width(right, 1), y + 8, WHITE, 1)
    end
  end

  local active = items[selected]
  active = type(active) == "table" and active or {label=active}
  local activeLabel = M.label(active.label or active.value, lang)
  drawText(fit(activeLabel, 140, 2), 330, 79, INK, 2)
  setColor(palette.accent); g.rectangle("fill", 330, 107, 142, 3)
  local artwork, artworkCount = artworkEntries(spec, edition)
  local help = clean(active.help)
  if help == "" then help = HELP[lang][activeLabel] or "" end
  local words, lines, line = {}, {}, ""
  for word in help:gmatch("%S+") do words[#words + 1] = word end
  for _, word in ipairs(words) do
    local candidate = line == "" and word or (line .. " " .. word)
    if width(candidate, 1) > 142 and line ~= "" then
      lines[#lines + 1], line = line, word
    else line = candidate end
  end
  if line ~= "" then lines[#lines + 1] = line end
  local helpLines = artworkCount > 0 and 2 or 5
  for index = 1, math.min(helpLines, #lines) do
    drawText(fit(lines[index], 142, 1), 330, 121 + (index - 1) * 17,
      INK, 1)
  end
  if artworkCount > 0 then drawArtwork(artwork) end
  drawText(lang == "de" and "EDITION" or "EDITION", 330, 207, INK, 1)
  drawText(editionLabel, 472 - width(editionLabel, 1), 207,
    palette.accent, 1)

  rounded(palette.accent, 24, 243, 464, 25, 6)
  rounded(palette.dark, 28, 247, 456, 17, 4)
  drawText(spec.footer or (lang == "de"
    and "STEUERKREUZ: AUSWAHL   A: BESTÄTIGEN   B: ZURÜCK"
    or "D-PAD: SELECT   A: CONFIRM   B: BACK"), 38, 248, WHITE, 1)
  setColor(WHITE)
  return true
end

function M.draw(spec)
  spec = type(spec) == "table" and spec or {}
  return drawLogical(spec)
end

-- Gen1 desktop still composites its ordinary UI through a 512x288 Canvas.
-- Repaint only the artwork in the exact engine UI rectangle after that blit;
-- borders, text, layout, letterboxing and every native menu remain untouched.
function M.drawArtworkPhysical(spec, rect)
  if not rect or not tonumber(rect.Ux) or not tonumber(rect.Uy)
      or rect.Ux <= 0 or rect.Uy <= 0 then return false end
  local _, edition = M.palette(spec and spec.edition)
  local entries, count = artworkEntries(spec or {}, edition)
  if count ~= 7 then return false end -- keep the complete existing fallback
  local g = love.graphics
  g.push("all")
  local ok, err = pcall(function()
    g.origin(); g.setShader()
    g.setScissor(rect.uox + 330*rect.Ux, rect.uoy + 151*rect.Uy,
      142*rect.Ux, 55*rect.Uy)
    g.translate(rect.uox, rect.uoy); g.scale(rect.Ux, rect.Uy)
    g.setBlendMode("alpha", "alphamultiply")
    setColor(PAPER); g.rectangle("fill", 330, 151, 142, 55)
    drawArtwork(entries)
  end)
  g.pop()
  if not ok then return false, tostring(err) end
  return true
end

function M.drawPhysical(spec, windowWidth, windowHeight)
  local g = love and love.graphics
  windowWidth, windowHeight = tonumber(windowWidth), tonumber(windowHeight)
  if not (g and windowWidth and windowHeight and windowWidth > 0
      and windowHeight > 0 and type(g.origin) == "function") then
    return drawLogical(spec or {})
  end
  local scale = math.min(windowWidth / M.width, windowHeight / M.height)
  local x = math.floor((windowWidth - M.width * scale) / 2)
  local y = math.floor((windowHeight - M.height * scale) / 2)
  local palette = M.palette(spec and spec.edition)
  g.push("all"); g.origin(); setColor(palette.dark)
  g.rectangle("fill", 0, 0, windowWidth, windowHeight)
  g.translate(x, y); g.scale(scale, scale)
  local ok, reason = drawLogical(spec or {})
  g.pop()
  return ok, reason
end

M.editions = ORDER
M.palettes = PALETTES
M.artworkForQA = artworkEntries
M.resetArtworkCacheForQA = function() imageCache = {} end

return M
